/*************************************************************************/
/*  arkit_interface.mm                                                   */
/*************************************************************************/
/*                       This file is part of:                           */
/*                           GODOT ENGINE                                */
/*                      https://godotengine.org                          */
/*************************************************************************/
/* Copyright (c) 2007-2021 Juan Linietsky, Ariel Manzur.                 */
/* Copyright (c) 2014-2021 Godot Engine contributors (cf. AUTHORS.md).   */
/*                                                                       */
/* Permission is hereby granted, free of charge, to any person obtaining */
/* a copy of this software and associated documentation files (the       */
/* "Software"), to deal in the Software without restriction, including   */
/* without limitation the rights to use, copy, modify, merge, publish,   */
/* distribute, sublicense, and/or sell copies of the Software, and to    */
/* permit persons to whom the Software is furnished to do so, subject to */
/* the following conditions:                                             */
/*                                                                       */
/* The above copyright notice and this permission notice shall be        */
/* included in all copies or substantial portions of the Software.       */
/*                                                                       */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,       */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF    */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.*/
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY  */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,  */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE     */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                */
/*************************************************************************/

#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/core/version.hpp>
#include <godot_cpp/classes/surface_tool.hpp>

#define VERSION_MAJOR GODOT_VERSION_MAJOR
#define VERSION_MINOR GODOT_VERSION_MINOR

#if VERSION_MAJOR >= 4
#include <godot_cpp/classes/input.hpp>
//#include <godot_cpp/servers/rendering/rendering_server_globals.h>
#include <godot_cpp/classes/display_server.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/classes/image.hpp>

#define GODOT_FOCUS_IN_NOTIFICATION DisplayServer::WINDOW_EVENT_FOCUS_IN
#define GODOT_FOCUS_OUT_NOTIFICATION DisplayServer::WINDOW_EVENT_FOCUS_OUT

#define GODOT_MAKE_THREAD_SAFE ;

#define GODOT_AR_STATE_NOT_TRACKING XRInterface::XR_NOT_TRACKING
#define GODOT_AR_STATE_NORMAL_TRACKING XRInterface::XR_NORMAL_TRACKING
#define GODOT_AR_STATE_EXCESSIVE_MOTION XRInterface::XR_EXCESSIVE_MOTION
#define GODOT_AR_STATE_INSUFFICIENT_FEATURES XRInterface::XR_INSUFFICIENT_FEATURES
#define GODOT_AR_STATE_UNKNOWN_TRACKING XRInterface::XR_UNKNOWN_TRACKING

#else

#include <godot_cpp/core/os/input.h>
#include <godot_cpp/servers/visual/visual_server_globals.h>

#define GODOT_FOCUS_IN_NOTIFICATION MainLoop::NOTIFICATION_WM_FOCUS_IN
#define GODOT_FOCUS_OUT_NOTIFICATION MainLoop::NOTIFICATION_WM_FOCUS_OUT

#define GODOT_MAKE_THREAD_SAFE _THREAD_SAFE_METHOD_

#define GODOT_AR_STATE_NOT_TRACKING ARVRInterface::ARVR_NOT_TRACKING
#define GODOT_AR_STATE_NORMAL_TRACKING ARVRInterface::ARVR_NORMAL_TRACKING
#define GODOT_AR_STATE_EXCESSIVE_MOTION ARVRInterface::ARVR_EXCESSIVE_MOTION
#define GODOT_AR_STATE_INSUFFICIENT_FEATURES ARVRInterface::ARVR_INSUFFICIENT_FEATURES
#define GODOT_AR_STATE_UNKNOWN_TRACKING ARVRInterface::ARVR_UNKNOWN_TRACKING
#endif

#import <ARKit/ARKit.h>
#import <UIKit/UIKit.h>

#include <dlfcn.h>

#include "arkit_anchor_mesh.h"
#include "arkit_interface.h"
#include "arkit_session_delegate.h"

//using namespace godot;

// just a dirty workaround for now, declare these as globals. I'll probably encapsulate ARSession and associated logic into an mm object and change ARKitInterface to a normal cpp object that consumes it.
API_AVAILABLE(ios(11.0))
ARSession *ar_session;

ARKitSessionDelegate *ar_delegate;
NSTimeInterval last_timestamp;

/* this is called when we initialize or when we come back from having our app pushed to the background, just (re)start our session */
void ARKitInterface::start_session() {
	// We're active...
	session_was_started = true;

	// Ignore this if we're not initialized...
	if (initialized) {
		print_line("Starting ARKit session");

		if (@available(iOS 11, *)) {
			Class ARWorldTrackingConfigurationClass = NSClassFromString(@"ARWorldTrackingConfiguration");
			ARWorldTrackingConfiguration *configuration = [ARWorldTrackingConfigurationClass new];

			configuration.lightEstimationEnabled = light_estimation_is_enabled;
			if (plane_detection_is_enabled) {
				print_line("Starting plane detection");
				if (@available(iOS 11.3, *)) {
					configuration.planeDetection = ARPlaneDetectionVertical | ARPlaneDetectionHorizontal;
				} else {
					configuration.planeDetection = ARPlaneDetectionHorizontal;
				}
			} else {
				print_line("Plane detection is disabled");
				configuration.planeDetection = 0;
			}

			// make sure our camera is on
			if (feed.is_valid()) {
				feed->set_active(true);
			}

			[ar_session runWithConfiguration:configuration];
		}
	}
}

void ARKitInterface::stop_session() {
	session_was_started = false;

	// Ignore this if we're not initialized...
	if (initialized) {
		// make sure our camera is off
		if (feed.is_valid()) {
			feed->set_active(false);
		}

		if (@available(iOS 11.0, *)) {
			[ar_session pause];
		}
	}
}

bool ARKitInterface::_get_anchor_detection_is_enabled() const {
	return plane_detection_is_enabled;
}

void ARKitInterface::_set_anchor_detection_is_enabled(bool p_enable) {
	if (plane_detection_is_enabled != p_enable) {
		plane_detection_is_enabled = p_enable;

		// Restart our session (this will be ignore if we're not initialised)
		if (session_was_started) {
			start_session();
		}
	}
}

int32_t ARKitInterface::_get_camera_feed_id() const {
	if (feed.is_null()) {
		return 0;
	} else {
		return feed->get_id();
	}
}

bool ARKitInterface::get_light_estimation_is_enabled() const {
	return light_estimation_is_enabled;
}

void ARKitInterface::set_light_estimation_is_enabled(bool p_enable) {
	if (light_estimation_is_enabled != p_enable) {
		light_estimation_is_enabled = p_enable;

		// Restart our session (this will be ignore if we're not initialised)
		if (session_was_started) {
			start_session();
		}
	}
}

real_t ARKitInterface::get_ambient_intensity() const {
	return ambient_intensity;
}

real_t ARKitInterface::get_ambient_color_temperature() const {
	return ambient_color_temperature;
}

real_t ARKitInterface::get_exposure_offset() const {
	return exposure_offset;
}

StringName ARKitInterface::_get_name() const {
	return "ARKit";
}

uint32_t ARKitInterface::_get_capabilities() const {
#if VERSION_MAJOR >= 4
	return XRInterface::XR_MONO | XRInterface::XR_AR;
#else
	return ARKitInterface::ARVR_MONO | ARKitInterface::ARVR_AR;
#endif
}

Array ARKitInterface::raycast(Vector2 p_screen_coord) {
	if (@available(iOS 11, *)) {
		Array arr;
#if VERSION_MAJOR >= 4
		Size2 screen_size = DisplayServer::get_singleton()->screen_get_size();
#else
		Size2 screen_size = OS::get_singleton()->get_window_size();
#endif
		CGPoint point;
		point.x = p_screen_coord.x / screen_size.x;
		point.y = p_screen_coord.y / screen_size.y;

		UIInterfaceOrientation orientation = UIInterfaceOrientationUnknown;

		if (@available(iOS 13, *)) {
			orientation = [UIApplication sharedApplication].delegate.window.windowScene.interfaceOrientation;
		} else {
			orientation = [[UIApplication sharedApplication] statusBarOrientation];
		}

		// This transform takes a point from image space to screen space
		CGAffineTransform affine_transform = [ar_session.currentFrame displayTransformForOrientation:orientation viewportSize:CGSizeMake(screen_size.width, screen_size.height)];
		
		// Invert the transformation, as hitTest expects the point to be in image space
		affine_transform = CGAffineTransformInvert(affine_transform);

		// Transform the point to image space
		point = CGPointApplyAffineTransform(point, affine_transform);

		///@TODO maybe give more options here, for now we're taking just ARAchors into account that were found during plane detection keeping their size into account
		NSArray<ARHitTestResult *> *results = [ar_session.currentFrame hitTest:point types:ARHitTestResultTypeExistingPlaneUsingExtent];

		for (ARHitTestResult *result in results) {
			Transform3D transform;

			matrix_float4x4 m44 = result.worldTransform;
			transform.basis.rows[0].x = m44.columns[0][0];
			transform.basis.rows[1].x = m44.columns[0][1];
			transform.basis.rows[2].x = m44.columns[0][2];
			transform.basis.rows[0].y = m44.columns[1][0];
			transform.basis.rows[1].y = m44.columns[1][1];
			transform.basis.rows[2].y = m44.columns[1][2];
			transform.basis.rows[0].z = m44.columns[2][0];
			transform.basis.rows[1].z = m44.columns[2][1];
			transform.basis.rows[2].z = m44.columns[2][2];
			transform.origin.x = m44.columns[3][0];
			transform.origin.y = m44.columns[3][1];
			transform.origin.z = m44.columns[3][2];

			/* important, NOT scaled to world_scale !! */
			arr.push_back(transform);
		}

		return arr;
	} else {
		return Array();
	}
}

void ARKitInterface::_bind_methods() {
	ClassDB::bind_method(D_METHOD("_notification", "what"), &ARKitInterface::_notification);

	ClassDB::bind_method(D_METHOD("set_light_estimation_is_enabled", "enable"), &ARKitInterface::set_light_estimation_is_enabled);
	ClassDB::bind_method(D_METHOD("get_light_estimation_is_enabled"), &ARKitInterface::get_light_estimation_is_enabled);
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "light_estimation"), "set_light_estimation_is_enabled", "get_light_estimation_is_enabled");

	ClassDB::bind_method(D_METHOD("get_ambient_intensity"), &ARKitInterface::get_ambient_intensity);
	ClassDB::bind_method(D_METHOD("get_ambient_color_temperature"), &ARKitInterface::get_ambient_color_temperature);
	ClassDB::bind_method(D_METHOD("get_exposure_offset"), &ARKitInterface::get_exposure_offset);

	ClassDB::bind_method(D_METHOD("raycast", "screen_coord"), &ARKitInterface::raycast);
}

#if VERSION_MAJOR < 4
bool ARKitInterface::is_stereo() {
	// this is a mono device...
	return false;
}
#endif

bool ARKitInterface::_is_initialized() const {
	return initialized;
}

bool ARKitInterface::_initialize() {
#if VERSION_MAJOR >= 4
	XRServer *ar_server = XRServer::get_singleton();
#else
	ARVRServer *ar_server = ARVRServer::get_singleton();
#endif

	ERR_FAIL_NULL_V(ar_server, false);

	if (@available(iOS 11, *)) {
		if (!initialized) {
			print_line("initializing ARKit");

			// create our ar session and delegate
			Class ARSessionClass = NSClassFromString(@"ARSession");
			if (ARSessionClass == Nil) {
				void *arkit_handle = dlopen("/System/Library/Frameworks/ARKit.framework/ARKit", RTLD_NOW);
				if (arkit_handle) {
					ARSessionClass = NSClassFromString(@"ARSession");
				} else {
					print_line("ARKit init failed");
					return false;
				}
			}
			ar_session = [ARSessionClass new];
			ar_delegate = [ARKitSessionDelegate new];
			ar_delegate.arkit_interface = this;
			ar_session.delegate = ar_delegate;

			// reset our transform
			transform = Transform3D();

			// make this our primary interface
			ar_server->set_primary_interface(this);

			// make sure we have our feed setup
			if (feed.is_null()) {
#if VERSION_MAJOR >= 4
        feed.instantiate();
#else
        feed.instance();
#endif
				feed->set_name("ARKit");

				CameraServer *cs = CameraServer::get_singleton();
				if (cs != NULL) {
					cs->add_feed(feed);
				}
			}
			feed->set_active(true);

			// yeah!
			initialized = true;

			// Start our session...
			start_session();
		}
		
		// The camera operates as a head and we need to create a tracker for that
		m_head.instantiate();
		m_head->set_tracker_type(XRServer::TRACKER_HEAD);
		m_head->set_tracker_name("head");
		m_head->set_tracker_desc("AR Device");
		ar_server->add_tracker(m_head);

		return true;
	} else {
		return false;
	}
}

void ARKitInterface::_uninitialize() {
	if (initialized) {
#if VERSION_MAJOR >= 4
		XRServer *ar_server = XRServer::get_singleton();
#else
		ARVRServer *ar_server = ARVRServer::get_singleton();
#endif
		if (ar_server != NULL) {
			// no longer our primary interface
			ar_server->set_primary_interface(nullptr);
		}

		if (feed.is_valid()) {
			CameraServer *cs = CameraServer::get_singleton();
			if ((cs != NULL)) {
				cs->remove_feed(feed);
			}
			feed.unref();
		}

		remove_all_anchors();

		if (m_head.is_valid()) {
			ar_server->remove_tracker(m_head);
			m_head.unref();
		}

		if (@available(iOS 11.0, *)) {
			ar_session = nil;
		}

		ar_delegate = nil;
		initialized = false;
		session_was_started = false;
	}
}

/*Dictionary ARKitInterface::_get_system_info() {
	Dictionary dict;
	return dict;
}*/

Size2 ARKitInterface::_get_render_target_size() {
	GODOT_MAKE_THREAD_SAFE

#if VERSION_MAJOR >= 4
	Size2 target_size = DisplayServer::get_singleton()->screen_get_size();
#else
	Size2 target_size = OS::get_singleton()->get_window_size();
#endif

	return target_size;
}

uint32_t ARKitInterface::_get_view_count() {
	return 1;
}

Transform3D ARKitInterface::_get_camera_transform() {
	return transform;
}

Transform3D ARKitInterface::_get_transform_for_view(uint32_t p_view, const Transform3D &p_cam_transform) {
	GODOT_MAKE_THREAD_SAFE

	Transform3D transform_for_view;

#if VERSION_MAJOR >= 4
	XRServer *ar_server = XRServer::get_singleton();
#else
	ARVRServer *ar_server = ARVRServer::get_singleton();
#endif

	ERR_FAIL_NULL_V(ar_server, transform_for_view);

	if (initialized) {
		float world_scale = ar_server->get_world_scale();

		// just scale our origin point of our transform, note that we really shouldn't be using world_scale in ARKit but....
		transform_for_view = transform;
		transform_for_view.origin *= world_scale;

		transform_for_view = p_cam_transform * ar_server->get_reference_frame() * transform_for_view;
	} else {
		// huh? well just return what we got....
		transform_for_view = p_cam_transform;
	}

	return transform_for_view;
}

PackedFloat64Array ARKitInterface::_get_projection_for_view(uint32_t p_view, double p_aspect, double p_z_near, double p_z_far) {
	PackedFloat64Array arr;
	arr.resize(16); // 4x4 matrix

	// Remember our near and far, it will be used in process when we obtain our projection from our ARKit session.
	z_near = p_z_near;
	z_far = p_z_far;

	real_t *p = (real_t *)&projection.columns;
	for (int i = 0; i < 16; i++) {
		arr[i] = p[i];
	}

	return arr;
}

void ARKitInterface::_post_draw_viewport(const RID &p_render_target, const Rect2 &p_screen_rect) {
	GODOT_MAKE_THREAD_SAFE

	Rect2 src_rect(0.0f, 0.0f, 1.0f, 1.0f);
	Rect2 dst_rect = p_screen_rect;

	float intraocular_dist = 0.0;
	float display_width = 1.0;
	float oversample = 1.0;
	float aspect = p_screen_rect.size.aspect();
	float k1 = 0.1;
	float k2 = 1.0;

	bool use_layer = false;
	bool apply_lens_distortion = false;

	// halve our width
	/*Vector2 size = dst_rect.get_size();
	size.x = size.x * 0.5;
	dst_rect.size = size;*/

	Vector2 eye_center(((-intraocular_dist / 2.0) + (display_width / 4.0)) / (display_width / 2.0), 0.0);
	eye_center = Vector2();

	//void add_blit(render_target: RID, src_rect: Rect2, dst_rect: Rect2i, use_layer: bool, layer: int, apply_lens_distortion: bool, eye_center: Vector2, k1: float, k2: float, upscale: float, aspect_ratio: float)
	add_blit(p_render_target, src_rect, dst_rect, use_layer, 0, apply_lens_distortion, eye_center, k1, k2, oversample, aspect);

	// move rect
	/*Vector2 pos = dst_rect.get_position();
	pos.x = size.x;
	dst_rect.position = pos;

	eye_center.x = ((intraocular_dist / 2.0) - (display_width / 4.0)) / (display_width / 2.0);
	*/
	//add_blit(p_render_target, src_rect, dst_rect, true, 1, apply_lens_distortion, eye_center, k1, k2, oversample, aspect);
}

Ref<GodotARTracker> ARKitInterface::get_anchor_for_uuid(const unsigned char *p_uuid) {
	if (anchors == NULL) {
		num_anchors = 0;
		max_anchors = 10;
		anchors = (anchor_map *)malloc(sizeof(anchor_map) * max_anchors);
	}

	print_line("get_anchor_for_uuid 0");

	ERR_FAIL_NULL_V(anchors, NULL);

	for (unsigned int i = 0; i < num_anchors; i++) {
		if (memcmp(anchors[i].uuid, p_uuid, 16) == 0) {
			return anchors[i].tracker;
		}
	}

	print_line("get_anchor_for_uuid 1");

	if (num_anchors + 1 == max_anchors) {
		max_anchors += 10;
		anchors = (anchor_map *)realloc(anchors, sizeof(anchor_map) * max_anchors);
		ERR_FAIL_NULL_V(anchors, NULL);
	}

	print_line("get_anchor_for_uuid 2 I'm ready");

#if VERSION_MAJOR == 4
	Ref<ARKitAnchorMesh> new_tracker; // = memnew(ARKitAnchorMesh);
	new_tracker.instantiate();
	
	print_line("get_anchor_for_uuid 3");
	
	new_tracker->set_tracker_type(XRServer::TRACKER_ANCHOR);
#else
	ARVRPositionalTracker *new_tracker = memnew(ARVRPositionalTracker);
	new_tracker->set_type(ARVRServer::TRACKER_ANCHOR);
#endif

	char tracker_name[256];
	sprintf(tracker_name, "Anchor %02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x", p_uuid[0], p_uuid[1], p_uuid[2], p_uuid[3], p_uuid[4], p_uuid[5], p_uuid[6], p_uuid[7], p_uuid[8], p_uuid[9], p_uuid[10], p_uuid[11], p_uuid[12], p_uuid[13], p_uuid[14], p_uuid[15]);


	String name = tracker_name;
	print_line("Adding tracker " + name);
#if VERSION_MAJOR == 4
	new_tracker->set_tracker_name(name);
#else
	new_tracker->set_name(name);
#endif

// add our tracker
#if VERSION_MAJOR == 4
	XRServer::get_singleton()->add_tracker(new_tracker);
#else
	ARVRServer::get_singleton()->add_tracker(new_tracker);
#endif
	anchors[num_anchors].tracker = new_tracker;
	memcpy(anchors[num_anchors].uuid, p_uuid, 16);
	num_anchors++;

	return new_tracker;
}

void ARKitInterface::remove_anchor_for_uuid(const unsigned char *p_uuid) {
	if (anchors != NULL) {
		for (unsigned int i = 0; i < num_anchors; i++) {
			if (memcmp(anchors[i].uuid, p_uuid, 16) == 0) {
// remove our tracker
#if VERSION_MAJOR == 4
				XRServer::get_singleton()->remove_tracker(anchors[i].tracker);
#else
				ARVRServer::get_singleton()->remove_tracker(anchors[i].tracker);
#endif
				// bring remaining forward
				for (unsigned int j = i + 1; j < num_anchors; j++) {
					anchors[j - 1] = anchors[j];
				};

				// decrease count
				num_anchors--;
				return;
			}
		}
	}
}

void ARKitInterface::remove_all_anchors() {
	if (anchors != NULL) {
		for (unsigned int i = 0; i < num_anchors; i++) {
// remove our tracker
#if VERSION_MAJOR == 4
			XRServer::get_singleton()->remove_tracker(anchors[i].tracker);
#else
			ARVRServer::get_singleton()->remove_tracker(anchors[i].tracker);
#endif
		};

		std::free(anchors);
		anchors = NULL;
		num_anchors = 0;
	}
}


void ARKitInterface::_process() {
	GODOT_MAKE_THREAD_SAFE

	if (@available(iOS 11.0, *)) {
		if (initialized) {
			// get our next ARFrame
			ARFrame *current_frame = ar_session.currentFrame;
			if (last_timestamp != current_frame.timestamp) {
				// only process if we have a new frame
				last_timestamp = current_frame.timestamp;

				// get some info about our screen and orientation
#if VERSION_MAJOR >= 4
				Size2 screen_size = DisplayServer::get_singleton()->screen_get_size();
#else
				Size2 screen_size = OS::get_singleton()->get_window_size();
#endif
				UIInterfaceOrientation orientation = UIInterfaceOrientationUnknown;

				if (@available(iOS 13, *)) {
					orientation = [UIApplication sharedApplication].delegate.window.windowScene.interfaceOrientation;
				} else {
					orientation = [[UIApplication sharedApplication] statusBarOrientation];
				}

				// Grab our camera image for our backbuffer
				CVPixelBufferRef pixelBuffer = current_frame.capturedImage;
				if ((CVPixelBufferGetPlaneCount(pixelBuffer) == 2) && (feed != NULL)) {
					// Plane 0 is our Y and Plane 1 is our CbCr buffer

					// ignored, we check each plane separately
					// image_width = CVPixelBufferGetWidth(pixelBuffer);
					// image_height = CVPixelBufferGetHeight(pixelBuffer);

					// printf("Pixel buffer %i - %i\n", image_width, image_height);

					CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

					// get our buffers
					unsigned char *dataY = (unsigned char *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
					unsigned char *dataCbCr = (unsigned char *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);

					if (dataY == NULL) {
						print_line("Couldn't access Y pixel buffer data");
					} else if (dataCbCr == NULL) {
						print_line("Couldn't access CbCr pixel buffer data");
					} else {
						Ref<Image> img[2];
						size_t extraLeft, extraRight, extraTop, extraBottom;

						CVPixelBufferGetExtendedPixels(pixelBuffer, &extraLeft, &extraRight, &extraTop, &extraBottom);

						{
							// do Y
							size_t new_width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
							size_t new_height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
							size_t bytes_per_row = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);

							if ((image_width[0] != new_width) || (image_height[0] != new_height)) {
								printf("- Camera padding l:%lu r:%lu t:%lu b:%lu\n", extraLeft, extraRight, extraTop, extraBottom);
								printf("- Camera Y plane size: %lu, %lu - %lu\n", new_width, new_height, bytes_per_row);

								image_width[0] = new_width;
								image_height[0] = new_height;
								img_data[0].resize(new_width * new_height);
							}

#if VERSION_MAJOR >= 4
							uint8_t *w = img_data[0].ptrw();
#else
							PoolVector<uint8_t>::Write w = img_data[0].write();
#endif

							if (new_width == bytes_per_row) {
#if VERSION_MAJOR >= 4
								memcpy(w, dataY, new_width * new_height);
#else
								memcpy(w.ptr(), dataY, new_width * new_height);
#endif
							} else {
								size_t offset_a = 0;
								size_t offset_b = extraLeft + (extraTop * bytes_per_row);
								for (size_t r = 0; r < new_height; r++) {
#if VERSION_MAJOR >= 4
									memcpy(w + offset_a, dataY + offset_b, new_width);
#else
									memcpy(w.ptr() + offset_a, dataY + offset_b, new_width);
#endif
									offset_a += new_width;
									offset_b += bytes_per_row;
								}
							}

#if VERSION_MAJOR >= 4
							img[0].instantiate();

							PackedByteArray pba_adapter;
							
							//for(int i=0; i<img_data[0])

							img[0]->set_data(new_width, new_height, 0, Image::FORMAT_R8, img_data[0]);
#else
							img[0].instance();
							img[0]->create(new_width, new_height, 0, Image::FORMAT_R8, img_data[0]);
#endif
						}

						{
							// do CbCr
							size_t new_width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
							size_t new_height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
							size_t bytes_per_row = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);

							if ((image_width[1] != new_width) || (image_height[1] != new_height)) {
								printf("- Camera CbCr plane size: %lu, %lu - %lu\n", new_width, new_height, bytes_per_row);

								image_width[1] = new_width;
								image_height[1] = new_height;
								img_data[1].resize(2 * new_width * new_height);
							}

#if VERSION_MAJOR >= 4
							uint8_t *w = img_data[1].ptrw();
#else
							PoolVector<uint8_t>::Write w = img_data[1].write();
#endif

							if ((2 * new_width) == bytes_per_row) {
#if VERSION_MAJOR >= 4
								memcpy(w, dataCbCr, 2 * new_width * new_height);
#else
								memcpy(w.ptr(), dataCbCr, 2 * new_width * new_height);
#endif
							} else {
								size_t offset_a = 0;
								size_t offset_b = extraLeft + (extraTop * bytes_per_row);
								for (size_t r = 0; r < new_height; r++) {
#if VERSION_MAJOR >= 4
									memcpy(w + offset_a, dataCbCr + offset_b, 2 * new_width);
#else
									memcpy(w.ptr() + offset_a, dataCbCr + offset_b, 2 * new_width);
#endif
									offset_a += 2 * new_width;
									offset_b += bytes_per_row;
								}
							}

#if VERSION_MAJOR >= 4
							img[1].instantiate();
							img[1]->set_data(new_width, new_height, 0, Image::FORMAT_RG8, img_data[1]);
#else
							img[1].instance();
							img[1]->create(new_width, new_height, 0, Image::FORMAT_RG8, img_data[1]);
#endif
						}

						// set our texture...
#if (VERSION_MAJOR == 4 && VERSION_MINOR >= 4) || VERSION_MAJOR > 4
						// Workaround...
						feed->set_rgb_image(img[0]);
						feed->set_ycbcr_image(img[1]);
#else
						//feed->set_YCbCr_imgs(img[0], img[1]);
#endif

						// now build our transform to display this as a background image that matches our camera
						// this transform takes a point from image space to screen space
						CGAffineTransform affine_transform = [current_frame displayTransformForOrientation:orientation viewportSize:CGSizeMake(screen_size.width, screen_size.height)];
						
						Transform2D display_transform = Transform2D(
								affine_transform.a, affine_transform.b,
								affine_transform.c, affine_transform.d,
								affine_transform.tx, affine_transform.ty);

						feed->set_transform(display_transform);
					}

					// and unlock
					CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
				}

				// Record light estimation to apply to our scene
				if (light_estimation_is_enabled) {
					ambient_intensity = current_frame.lightEstimate.ambientIntensity;

					///@TODO it's there, but not there.. what to do with this...
					// https://developer.apple.com/documentation/arkit/arlightestimate?language=objc
					ambient_color_temperature = current_frame.lightEstimate.ambientColorTemperature;
				}

				// Process our camera
				ARCamera *camera = current_frame.camera;

				// Record camera exposure
				if (@available(iOS 13, *)) {
					exposure_offset = camera.exposureOffset;
				}

				// strangely enough we have to states, rolling them up into one
				if (camera.trackingState == ARTrackingStateNotAvailable) {
					// no tracking, would be good if we black out the screen or something...
					tracking_state = GODOT_AR_STATE_NOT_TRACKING;
				} else {
					if (camera.trackingState == ARTrackingStateNormal) {
						tracking_state = GODOT_AR_STATE_NOT_TRACKING;
					} else if (camera.trackingStateReason == ARTrackingStateReasonExcessiveMotion) {
						tracking_state = GODOT_AR_STATE_EXCESSIVE_MOTION;
					} else if (camera.trackingStateReason == ARTrackingStateReasonInsufficientFeatures) {
						tracking_state = GODOT_AR_STATE_INSUFFICIENT_FEATURES;
					} else {
						tracking_state = GODOT_AR_STATE_UNKNOWN_TRACKING;
					}

					// copy our current frame transform
					matrix_float4x4 m44 = camera.transform;
					if (orientation == UIInterfaceOrientationLandscapeLeft) {
						transform.basis.rows[0].x = -m44.columns[0][0];
						transform.basis.rows[1].x = -m44.columns[0][1];
						transform.basis.rows[2].x = -m44.columns[0][2];
						transform.basis.rows[0].y = -m44.columns[1][0];
						transform.basis.rows[1].y = -m44.columns[1][1];
						transform.basis.rows[2].y = -m44.columns[1][2];
					} else if (orientation == UIInterfaceOrientationPortrait) {
						transform.basis.rows[0].x = m44.columns[1][0];
						transform.basis.rows[1].x = m44.columns[1][1];
						transform.basis.rows[2].x = m44.columns[1][2];
						transform.basis.rows[0].y = -m44.columns[0][0];
						transform.basis.rows[1].y = -m44.columns[0][1];
						transform.basis.rows[2].y = -m44.columns[0][2];
					} else if (orientation == UIInterfaceOrientationLandscapeRight) {
						transform.basis.rows[0].x = m44.columns[0][0];
						transform.basis.rows[1].x = m44.columns[0][1];
						transform.basis.rows[2].x = m44.columns[0][2];
						transform.basis.rows[0].y = m44.columns[1][0];
						transform.basis.rows[1].y = m44.columns[1][1];
						transform.basis.rows[2].y = m44.columns[1][2];
					} else if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
						transform.basis.rows[0].x = -m44.columns[1][0];
						transform.basis.rows[1].x = -m44.columns[1][1];
						transform.basis.rows[2].x = -m44.columns[1][2];
						transform.basis.rows[0].y = m44.columns[0][0];
						transform.basis.rows[1].y = m44.columns[0][1];
						transform.basis.rows[2].y = m44.columns[0][2];
					}

					transform.basis.rows[0].z = m44.columns[2][0];
					transform.basis.rows[1].z = m44.columns[2][1];
					transform.basis.rows[2].z = m44.columns[2][2];
					transform.origin.x = m44.columns[3][0];
					transform.origin.y = m44.columns[3][1];
					transform.origin.z = m44.columns[3][2];

					if (m_head.is_valid()) {
							// Set our head position, note in real space, reference frame and world scale is applied later
							m_head->set_pose("default", transform, Vector3(), Vector3(), XRPose::XR_TRACKING_CONFIDENCE_HIGH);
					}

					// copy our current frame projection, investigate using projectionMatrixWithViewportSize:orientation:zNear:zFar: so we can set our own near and far
					m44 = [camera projectionMatrixForOrientation:orientation viewportSize:CGSizeMake(screen_size.width, screen_size.height) zNear:z_near zFar:z_far];

					projection.columns[0][0] = m44.columns[0][0];
					projection.columns[1][0] = m44.columns[1][0];
					projection.columns[2][0] = m44.columns[2][0];
					projection.columns[3][0] = m44.columns[3][0];
					projection.columns[0][1] = m44.columns[0][1];
					projection.columns[1][1] = m44.columns[1][1];
					projection.columns[2][1] = m44.columns[2][1];
					projection.columns[3][1] = m44.columns[3][1];
					projection.columns[0][2] = m44.columns[0][2];
					projection.columns[1][2] = m44.columns[1][2];
					projection.columns[2][2] = m44.columns[2][2];
					projection.columns[3][2] = m44.columns[3][2];
					projection.columns[0][3] = m44.columns[0][3];
					projection.columns[1][3] = m44.columns[1][3];
					projection.columns[2][3] = m44.columns[2][3];
					projection.columns[3][3] = m44.columns[3][3];
				}
			}
		}
	}
}

void ARKitInterface::_add_or_update_anchor(GodotARAnchor *p_anchor) {
	GODOT_MAKE_THREAD_SAFE

	if (@available(iOS 11.0, *)) {
		ARAnchor *anchor = (ARAnchor *)p_anchor;

		unsigned char uuid[16];
		[anchor.identifier getUUIDBytes:uuid];

		print_line("About to add an anchor");

#if VERSION_MAJOR >= 4
		Ref<ARKitAnchorMesh> tracker = get_anchor_for_uuid(uuid);
#else
		ARVRPositionalTracker *tracker = get_anchor_for_uuid(uuid);
#endif


		print_line("get_anchor_for_uuid was called");

		if (tracker != NULL) {
			// lets update our mesh! (using Arjens code as is for now)
			// we should also probably limit how often we do this...

			// can we safely cast this?
			ARPlaneAnchor *planeAnchor = (ARPlaneAnchor *)anchor;

			print_line("can we safely cast this?");

			if (@available(iOS 11.3, *)) {
				if (planeAnchor.geometry.triangleCount > 0) {
					Ref<SurfaceTool> surftool;
#if VERSION_MAJOR >= 4
					surftool.instantiate();
#else
					surftool.instance();
#endif
					surftool->begin(Mesh::PRIMITIVE_TRIANGLES);

					for (int j = planeAnchor.geometry.triangleCount * 3 - 1; j >= 0; j--) {
						int16_t index = planeAnchor.geometry.triangleIndices[j];
						simd_float3 vrtx = planeAnchor.geometry.vertices[index];
						simd_float2 textcoord = planeAnchor.geometry.textureCoordinates[index];
#if VERSION_MAJOR >= 4
						surftool->set_uv(Vector2(textcoord[0], textcoord[1]));
						surftool->set_color(Color(0.8, 0.8, 0.8));
#else
						surftool->add_uv(Vector2(textcoord[0], textcoord[1]));
						surftool->add_color(Color(0.8, 0.8, 0.8));
#endif
						surftool->add_vertex(Vector3(vrtx[0], vrtx[1], vrtx[2]));
					}

					surftool->generate_normals();

					tracker->set_mesh(surftool->commit());
				} else {
					Ref<Mesh> nomesh;
					tracker->set_mesh(nomesh);
				}
			} else {
				Ref<Mesh> nomesh;
				tracker->set_mesh(nomesh);
			}

			// Note, this also contains a scale factor which gives us an idea of the size of the anchor
			// We may extract that in our XRAnchor/ARVRAnchor class
			Basis b;
			matrix_float4x4 m44 = anchor.transform;
			b.rows[0].x = m44.columns[0][0];
			b.rows[1].x = m44.columns[0][1];
			b.rows[2].x = m44.columns[0][2];
			b.rows[0].y = m44.columns[1][0];
			b.rows[1].y = m44.columns[1][1];
			b.rows[2].y = m44.columns[1][2];
			b.rows[0].z = m44.columns[2][0];
			b.rows[1].z = m44.columns[2][1];
			b.rows[2].z = m44.columns[2][2];
#if VERSION_MAJOR >= 4
			Transform3D pose = Transform3D(b, Vector3(m44.columns[3][0], m44.columns[3][1], m44.columns[3][2]));
			tracker->set_pose("default", pose, Vector3(), Vector3(), XRPose::XR_TRACKING_CONFIDENCE_HIGH);
#else
			tracker->set_orientation(b);
			tracker->set_rw_position(Vector3(m44.columns[3][0], m44.columns[3][1], m44.columns[3][2]));
#endif

#define SNAME(m_arg) ([]() -> const StringName & { static StringName sname = StringName(m_arg, true); return sname; })()
			XRServer::get_singleton()->emit_signal(SNAME("tracker_updated"), tracker->get_tracker_name(), tracker->get_tracker_type());
		}
	}
}

void ARKitInterface::_remove_anchor(GodotARAnchor *p_anchor) {
	GODOT_MAKE_THREAD_SAFE

	if (@available(iOS 11.0, *)) {
		ARAnchor *anchor = (ARAnchor *)p_anchor;

		unsigned char uuid[16];
		[anchor.identifier getUUIDBytes:uuid];

		remove_anchor_for_uuid(uuid);
	}
}

ARKitInterface::ARKitInterface() {
	initialized = false;
	session_was_started = false;
	plane_detection_is_enabled = false;
	light_estimation_is_enabled = false;
	if (@available(iOS 11.0, *)) {
		ar_session = nil;
	}
	z_near = 0.01;
	z_far = 1000.0;
	projection.set_perspective(60.0, 1.0, z_near, z_far, false);
	anchors = NULL;
	num_anchors = 0;
	ambient_intensity = 1.0;
	ambient_color_temperature = 1.0;
	exposure_offset = 0.0;
	image_width[0] = 0;
	image_width[1] = 0;
	image_height[0] = 0;
	image_height[1] = 0;
}

ARKitInterface::~ARKitInterface() {
	remove_all_anchors();

	// and make sure we cleanup if we haven't already
	if (_is_initialized()) {
		_uninitialize();
	}
}

// Because set_ycbcr_images is not exposed to GDExtension, define it here.
void set_ycbcr_images(Ref<CameraFeed> feed, const Ref<Image> &p_y_img, const Ref<Image> &p_cbcr_img) {
	ERR_FAIL_COND(p_y_img.is_null());
	ERR_FAIL_COND(p_cbcr_img.is_null());
	if (feed->is_active()) {
		///@TODO investigate whether we can use thirdparty/misc/yuv2rgb.h here to convert our YUV data to RGB, our shader approach is potentially faster though..
		// Wondering about including that into multiple projects, may cause issues.
		// That said, if we convert to RGB, we could enable using texture resources again...

		int new_y_width = p_y_img->get_width();
		int new_y_height = p_y_img->get_height();

		/*if ((feed->base_width != new_y_width) || (feed->base_height != new_y_height)) {
			// We're assuming here that our camera image doesn't change around formats etc, allocate the whole lot...
			base_width = new_y_width;
			base_height = new_y_height;
			{
				RID new_texture = RenderingServer::get_singleton()->texture_2d_create(p_y_img);
				RenderingServer::get_singleton()->texture_replace(feed->texture[CameraServer::FEED_Y_IMAGE], new_texture);
			}
			{
				RID new_texture = RenderingServer::get_singleton()->texture_2d_create(p_cbcr_img);
				RenderingServer::get_singleton()->texture_replace(feed->texture[CameraServer::FEED_CBCR_IMAGE], new_texture);
			}

			// Defer `format_changed` signals to ensure they are emitted on Godot's main thread.
			// This also makes sure the datatype of the feed is updated before the emission.
			feed->call_deferred("emit_signal", format_changed_signal_name);
		} else */
		{
			//RenderingServer::get_singleton()->texture_2d_update(feed->get_texture_tex_id(CameraServer::FEED_Y_IMAGE), p_y_img, 0);
			//RenderingServer::get_singleton()->texture_2d_update(feed->get_texture_tex_id(CameraServer::FEED_CBCR_IMAGE), p_cbcr_img, 0);
		}

		//feed->datatype = CameraFeed::FEED_YCBCR_SEP;
		// Most of the time the pixel data of camera devices comes from threads outside Godot.
		// Defer `frame_changed` signals to ensure they are emitted on Godot's main thread.
		//feed->call_deferred("emit_signal", frame_changed_signal_name);
	}
}