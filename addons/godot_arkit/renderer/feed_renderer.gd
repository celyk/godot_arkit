extends RefCounted

## FeedRenderer generates an RGB CameraFeed from Y+CBCR images
## Usage [WIP]:

var feed : CameraFeed
var feed_size : Vector2i
var images : Array[Image] = [Image.new(), Image.new()]

func _init() -> void:
	CameraServer.monitoring_feeds = true
	feed = CameraFeed.new()
	feed.set_name("ShaderCameraFeed")
	

func set_feed_size(size:Vector2i):
	feed_size = size

	# Initialize the RGB camera feed the only way we can. Note: feed_is_active has to be enabled for this to work
	feed.feed_is_active = true
	var img := Image.create_empty(feed_size.x, feed_size.y, false, Image.Format.FORMAT_RGBA8)
	feed.set_rgb_image(img)

func initialize() -> void:
	assert(feed_size != Vector2i())
	RenderingServer.call_on_render_thread(_init_render)

func render_feed():
	RenderingServer.call_on_render_thread(_render)

func cleanup() -> void:
	RenderingServer.call_on_render_thread(_cleanup_render)


###############################################################################
# Everything after this point is designed to run on our rendering thread.

var _RD : RenderingDevice
var _p_input_sampler0 : RID
var _p_input_texture0 : RID
var _p_input_sampler1 : RID
var _p_input_texture1 : RID
var _p_output_texture : RID
var _p_shader : RID
var _p_pipeline : RID
var _p_uniform_set : RID
var _p_command_list : RID

func _init_render():
	_RD = RenderingServer.get_rendering_device()
	
	_setup_textures()
	_setup_compute()

func _cleanup_render():
	_RD.free_rid(_p_input_texture0)
	_RD.free_rid(_p_input_texture1)
	_RD.free_rid(_p_shader)

func _render():
	_update_textures()
	
	var compute_list = _RD.compute_list_begin()
	_RD.compute_list_bind_compute_pipeline(compute_list, _p_pipeline)
	_RD.compute_list_bind_uniform_set(compute_list, _p_uniform_set, 0)
	_RD.compute_list_dispatch(compute_list, feed_size.x, feed_size.y, 1)
	_RD.compute_list_end()

func _texture_create_from_image(img : Image):
	assert(img.get_format() == Image.FORMAT_RGB8 || img.get_format() == Image.FORMAT_RGBA8)
	
	var rdformat := RDTextureFormat.new()
	rdformat.format = _RD.DataFormat.DATA_FORMAT_R8G8B8A8_UNORM
	rdformat.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	rdformat.width = img.get_size().x
	rdformat.height = img.get_size().y
	rdformat.depth = 1
	rdformat.array_layers = 1
	rdformat.mipmaps = 1
	rdformat.usage_bits = _RD.TEXTURE_USAGE_STORAGE_BIT | _RD.TEXTURE_USAGE_SAMPLING_BIT | _RD.TEXTURE_USAGE_CAN_UPDATE_BIT
	
	var rdview := RDTextureView.new()
	
	return _RD.texture_create(rdformat, rdview, [img.get_data()])

func _setup_textures():
	var sampler_state := RDSamplerState.new()
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	
	_p_input_sampler0 = _RD.sampler_create(sampler_state)
	_p_input_texture0 = _texture_create_from_image(images[0])
	_p_input_sampler1 = _RD.sampler_create(sampler_state)
	_p_input_texture1 = _texture_create_from_image(images[1])
	
	# Workaround to get an RID for the RGBA camera feed
	_p_output_texture = _RD.texture_create_from_extension(
		_RD.TextureType.TEXTURE_TYPE_2D,
		_RD.DataFormat.DATA_FORMAT_R8G8B8A8_UNORM,
		RenderingDevice.TEXTURE_SAMPLES_1,
		_RD.TEXTURE_USAGE_STORAGE_BIT | _RD.TEXTURE_USAGE_SAMPLING_BIT | _RD.TEXTURE_USAGE_CAN_COPY_TO_BIT,
		feed.get_texture_tex_id(CameraServer.FEED_RGBA_IMAGE),
		feed_size.x,
		feed_size.y,
		1,
		1,
		1)
	
	_RD.texture_clear(_p_output_texture, Color(0, 0, 0.9, 1), 0, 1, 0, 1)

func _update_textures():
	_RD.texture_update(_p_input_texture0, 0, images[0].get_data())
	_RD.texture_update(_p_input_texture1, 0, images[1].get_data())

func _setup_compute():
	_p_shader = _compile_compute_shader()
	
	_p_pipeline = _RD.compute_pipeline_create(_p_shader)
	
	var uniforms = []
	var uniform := RDUniform.new()
	uniform.binding = 0
	uniform.uniform_type = _RD.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.add_id(_p_input_sampler0)
	uniform.add_id(_p_input_texture0)
	uniforms.push_back( uniform )
	
	uniform = RDUniform.new()
	uniform.binding = 1
	uniform.uniform_type = _RD.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.add_id(_p_input_sampler1)
	uniform.add_id(_p_input_texture1)
	uniforms.push_back( uniform )
	
	uniform = RDUniform.new()
	uniform.binding = 2
	uniform.uniform_type = _RD.UNIFORM_TYPE_IMAGE
	uniform.add_id(_p_output_texture)
	uniforms.push_back( uniform )
	
	_p_uniform_set = _RD.uniform_set_create(uniforms, _p_shader, 0)

func _compile_compute_shader(source_compute = _default_source_compute) -> RID:
	var src := RDShaderSource.new()
	src.source_compute = source_compute
	
	var shader_spirv : RDShaderSPIRV = _RD.shader_compile_spirv_from_source(src)
	
	var err = shader_spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE)
	if err: push_error( err )
	
	var p_shader : RID = _RD.shader_create_from_spirv(shader_spirv)
	
	return p_shader

const _default_source_compute = "
		#version 450
		
		// Invocations in the (x, y, z) dimension.
		layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

		layout(set = 0, binding = 0) uniform sampler2D input_image0;
		layout(set = 0, binding = 1) uniform sampler2D input_image1;
		layout(rgba8, set = 0, binding = 2) uniform restrict writeonly image2D output_image;
		
		vec3 ycbcrToRGB(vec3 ycbcr){
			const mat4 ycbcrToRGBTransform = mat4(
				vec4(+1.0000, +1.0000, +1.0000, +0.0000),
				vec4(+0.0000, -0.3441, +1.7720, +0.0000),
				vec4(+1.4020, -0.7141, +0.0000, +0.0000),
				vec4(-0.7010, +0.5291, -0.8860, +1.0000)
			);
			
			return ((ycbcrToRGBTransform) * vec4(ycbcr,1)).rgb;
		}
		
		void main(){
			vec2 resolution = vec2(textureSize(input_image0,0));
			resolution = max(resolution, vec2(textureSize(input_image1,0)) );
			
			vec2 uv = (vec2(gl_GlobalInvocationID.xy) + 0.5) / resolution; // * 100.0;
			
			vec3 ycbcr = vec3(textureLod(input_image0, uv, 0.0).x, textureLod(input_image1, uv, 0.0).xy);
			
			float f = float(gl_GlobalInvocationID.x % 2 == 1);
			f = sin(uv.x*50.0);
			f *= sin(uv.y*50.0);
			//f = 0.0;
			
			vec3 col = textureLod(input_image1, uv, 0.0).rgb;
			//col = vec3(uv,f);
			//col = vec3(uv,0);
			//col.z += step(0.51, col.x);
			
			col = ycbcrToRGB(ycbcr);
			
			/*
			if(uv.x > 0.3){
				col = textureLod(input_image0, uv, 0.0).rgb;
			}
			if(uv.x > 0.6){
				col = textureLod(input_image1, uv, 0.0).rgb;
			}
			*/
			
			//col = vec3(uv,f);
			
			imageStore(output_image, ivec2(gl_GlobalInvocationID.xy), vec4(col,1));
		}
		"
