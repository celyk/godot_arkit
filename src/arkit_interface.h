/*************************************************************************/
/*  arkit_interface.h                                                    */
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

#ifndef ARKIT_INTERFACE_H
#define ARKIT_INTERFACE_H

#include <godot_cpp/core/version.hpp>


#include <godot_cpp/classes/xr_interface.hpp>
#include <godot_cpp/classes/xr_interface_extension.hpp>
#include <godot_cpp/classes/xr_positional_tracker.hpp>
#include <godot_cpp/classes/cubemap.hpp>

#include "arkit_anchor_mesh.h"
#include "arkit_anchor_image.h"

typedef PackedByteArray GodotUInt8Vector;

#define GODOT_ARKIT_OVERRIDE override

#include <godot_cpp/classes/camera_feed.hpp>

#include <stdlib.h>

#ifdef __OBJC__
//#import <ARKit/ARKit.h>
//#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#endif

/**
	@author Bastiaan Olij <mux213@gmail.com>

	ARKit interface between iOS and Godot
*/

// forward declaration for some needed objects
class ARKitShader;

#ifdef __OBJC__
typedef NSObject GodotARAnchor;
#else
typedef void GodotARAnchor;
#endif


struct BlitToScreen {
	RID render_target;
	Rect2 src_rect = Rect2(0.0, 0.0, 1.0, 1.0);
	Rect2i dst_rect;

	struct {
		bool use_layer = false;
		uint32_t layer = 0;
	} multi_view;

	struct {
		//lens distorted parameters for VR
		bool apply = false;
		Vector2 eye_center;
		float k1 = 0.0;
		float k2 = 0.0;

		float upscale = 1.0;
		float aspect_ratio = 1.0;
	} lens_distortion;
};

class ARKitInterface : public XRInterfaceExtension {
	GDCLASS(ARKitInterface, XRInterfaceExtension);

private:
	bool initialized;
	bool session_was_started;
	bool plane_detection_is_enabled;
	bool light_estimation_is_enabled;
	bool image_tracking_is_enabled;
	real_t ambient_intensity;
	real_t ambient_color_temperature;
	real_t exposure_offset;

	Ref<XRPositionalTracker> m_head;
	Transform3D transform;
	Projection projection;
	float eye_height, z_near, z_far;

	Ref<CameraFeed> feed;
	size_t image_width[2];
	size_t image_height[2];
	GodotUInt8Vector img_data[2];
	//id<MTLTexture> environment_texture;
	//GodotARAnchor* environment_anchor;
	Ref<Cubemap> environment_map;
	TypedArray<Image> reference_images;
	TypedArray<Vector2> reference_images_physical_width;

	//TypedArray<Image> imgs;

	XRInterface::TrackingStatus tracking_state;

	struct anchor_map {
		Ref<XRPositionalTracker> tracker;
		unsigned char uuid[16];
	};

	///@TODO should use memory map object from Godot?
	unsigned int num_anchors;
	unsigned int max_anchors;
	anchor_map *anchors;
	Ref<XRPositionalTracker> get_anchor_for_uuid(const unsigned char *p_uuid, Ref<XRPositionalTracker> tracker);
	void remove_anchor_for_uuid(const unsigned char *p_uuid);
	void remove_all_anchors();

protected:
	static void _bind_methods();

public:
	void start_session();
	void stop_session();
	bool get_light_estimation_is_enabled() const;
	void set_light_estimation_is_enabled(bool p_enable);

	bool get_image_tracking_is_enabled() const;
	void set_image_tracking_is_enabled(bool p_enable);

	void set_reference_images(TypedArray<Image> images, TypedArray<Vector2> physical_widths);

	real_t get_ambient_intensity() const;
	real_t get_ambient_color_temperature() const;
	real_t get_exposure_offset() const;

	TypedArray<Image> get_image_planes() const;
	void set_image_planes();

	Ref<Cubemap> get_environment_map() const;
	
	/* while Godot has its own raycast logic this takes ARKits camera into account and hits on any ARAnchor */
	Array raycast(Vector2 p_screen_coord);

	virtual StringName _get_name() const GODOT_ARKIT_OVERRIDE;
	virtual uint32_t _get_capabilities() const GODOT_ARKIT_OVERRIDE;

	virtual bool _is_initialized() const GODOT_ARKIT_OVERRIDE;
	virtual bool _initialize() GODOT_ARKIT_OVERRIDE;
	virtual void _uninitialize() GODOT_ARKIT_OVERRIDE;
	//virtual Dictionary _get_system_info() GODOT_ARKIT_OVERRIDE;

 	//virtual PackedStringArray get_suggested_tracker_names() const GODOT_ARKIT_OVERRIDE;
	//virtual PackedStringArray get_suggested_pose_names(const StringName &p_tracker_name) const GODOT_ARKIT_OVERRIDE;

	/** input and output **/
	virtual TrackingStatus _get_tracking_status() const GODOT_ARKIT_OVERRIDE { return tracking_state; };

	//virtual void trigger_haptic_pulse(const String &p_action_name, const StringName &p_tracker_name, double p_frequency, double p_amplitude, double p_duration_sec, double p_delay_sec = 0) GODOT_ARKIT_OVERRIDE; /* trigger a haptic pulse */

	//virtual bool supports_play_area_mode(XRInterface::PlayAreaMode p_mode) GODOT_ARKIT_OVERRIDE;
	//virtual XRInterface::PlayAreaMode get_play_area_mode() const GODOT_ARKIT_OVERRIDE;
	//virtual bool set_play_area_mode(XRInterface::PlayAreaMode p_mode) GODOT_ARKIT_OVERRIDE;
	//virtual PackedVector3Array get_play_area() const GODOT_ARKIT_OVERRIDE;

	/** specific to AR **/
	virtual bool _get_anchor_detection_is_enabled() const GODOT_ARKIT_OVERRIDE;
	virtual void _set_anchor_detection_is_enabled(bool p_enable) GODOT_ARKIT_OVERRIDE;
	virtual int32_t _get_camera_feed_id() const GODOT_ARKIT_OVERRIDE;

	virtual Size2 _get_render_target_size() GODOT_ARKIT_OVERRIDE;
	virtual uint32_t _get_view_count() GODOT_ARKIT_OVERRIDE;
	virtual Transform3D _get_camera_transform() GODOT_ARKIT_OVERRIDE;
	virtual Transform3D _get_transform_for_view(uint32_t p_view, const Transform3D &p_cam_transform) GODOT_ARKIT_OVERRIDE;
	virtual PackedFloat64Array _get_projection_for_view(uint32_t p_view, double p_aspect, double p_z_near, double p_z_far) GODOT_ARKIT_OVERRIDE;

	//virtual RID get_vrs_texture() GODOT_ARKIT_OVERRIDE;
	//virtual RID get_color_texture() GODOT_ARKIT_OVERRIDE;
	//virtual RID get_depth_texture() GODOT_ARKIT_OVERRIDE;
	//virtual RID get_velocity_texture() GODOT_ARKIT_OVERRIDE;

	/** rendering and internal **/

	//virtual Transform3D get_camera_transform() GODOT_ARKIT_OVERRIDE;
	virtual void _process() GODOT_ARKIT_OVERRIDE;
	//virtual void pre_render() GODOT_ARKIT_OVERRIDE;
	//virtual bool pre_draw_viewport(RID p_render_target) GODOT_ARKIT_OVERRIDE;
	virtual void _post_draw_viewport(const RID &p_render_target, const Rect2 &p_screen_rect) GODOT_ARKIT_OVERRIDE;
	//virtual void end_frame() GODOT_ARKIT_OVERRIDE;

	//virtual bool is_passthrough_supported() GODOT_ARKIT_OVERRIDE;
	//virtual bool is_passthrough_enabled() GODOT_ARKIT_OVERRIDE;
	//virtual bool start_passthrough() GODOT_ARKIT_OVERRIDE;
	//virtual void stop_passthrough() GODOT_ARKIT_OVERRIDE;

	//virtual Array get_supported_environment_blend_modes() GODOT_ARKIT_OVERRIDE;
	//virtual bool set_environment_blend_mode(EnvironmentBlendMode mode) GODOT_ARKIT_OVERRIDE;
/*
	virtual Size2 get_render_target_size() GODOT_ARKIT_OVERRIDE;
	virtual uint32_t get_view_count() GODOT_ARKIT_OVERRIDE;
	virtual Transform3D get_transform_for_view(uint32_t p_view, const Transform3D &p_cam_transform) GODOT_ARKIT_OVERRIDE;
	virtual Projection get_projection_for_view(uint32_t p_view, double p_aspect, double p_z_near, double p_z_far) GODOT_ARKIT_OVERRIDE;
	*/

	//virtual Vector<BlitToScreen> post_draw_viewport(RID p_render_target, const Rect2 &p_screen_rect) GODOT_ARKIT_OVERRIDE;

	// called by delegate (void * because C++ and Obj-C don't always mix, should really change all platform/ios/*.cpp files to .mm)
	void _add_or_update_anchor(GodotARAnchor *p_anchor);
	void _remove_anchor(GodotARAnchor *p_anchor);

	ARKitInterface();
	~ARKitInterface();
};

#endif /* !ARKIT_INTERFACE_H */
