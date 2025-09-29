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

#ifndef ARKIT_ANCHOR_IMAGE_H
#define ARKIT_ANCHOR_IMAGE_H

#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/core/version.hpp>
//#include <godot_cpp/classes/surface_tool.hpp>
#include <godot_cpp/classes/image.hpp>

#include <godot_cpp/classes/xr_interface.hpp>
#include <godot_cpp/classes/xr_positional_tracker.hpp>

#include <godot_cpp/core/mutex_lock.hpp>

using namespace godot;

class ARKitAnchorImage : public XRPositionalTracker {
	GDCLASS(ARKitAnchorImage, XRPositionalTracker);
	//_THREAD_SAFE_CLASS_

private:
	Ref<Image> image;

protected:
	static void _bind_methods();

public:
	void set_image(Ref<Image> p_image);
	Ref<Image> get_image() const;

	ARKitAnchorImage();
	~ARKitAnchorImage();
};

#endif /* !ARKIT_ANCHOR_IMAGE_H */