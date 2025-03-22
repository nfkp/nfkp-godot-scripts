extends Node
# By: S. Zarfeen Hossain
var rd: RenderingDevice
var shader_rid: RID
var image_rid: RID
var pipeline: RID

var framebuffer: RID
var index_buffer_rid: RID
var index_array_rid: RID
var vertex_buffer_rid: RID
var vertex_array_rid: RID
var uniform_buffer_rid: RID
var uniform_set_rid: RID

var r_state : RDPipelineRasterizationState
var d_state : RDPipelineDepthStencilState

func load_shader(p_rd: RenderingDevice, path: String) -> RID:
	var shader_file_data: RDShaderFile = load(path)
	var shader_spirv: RDShaderSPIRV = shader_file_data.get_spirv()
	return p_rd.shader_create_from_spirv(shader_spirv)

func init_gpu(resolution: int) -> void:
	rd = RenderingServer.create_local_rendering_device()

	if rd == null:
		OS.alert("""Couldn't create local RenderingDevice on GPU: %s

Note: RenderingDevice is only available in the Forward+ and Mobile rendering methods, not Compatibility.""" % RenderingServer.get_video_adapter_name())
		return
	
	var image_format := RDTextureFormat.new()
	image_format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	image_format.width = resolution
	image_format.height = resolution

	image_format.usage_bits = \
			RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
			RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT + \
			RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT

	image_rid = rd.texture_create(image_format, RDTextureView.new())

	# (Render Pipeline)
	framebuffer = rd.framebuffer_create([image_rid])
	
	r_state = RDPipelineRasterizationState.new()
	r_state.cull_mode = RenderingDevice.POLYGON_CULL_BACK
	d_state = RDPipelineDepthStencilState.new()
	d_state.back_op_compare = RenderingDevice.COMPARE_OP_NEVER


func glsl_write_to_texture(shader_path : String, resolution: int = 512, uniform_data : PackedByteArray = PackedByteArray([])) -> ImageTexture:
	if rd == null:
		init_gpu(resolution)

	if rd == null:
		$CenterContainer/VBoxContainer/PanelContainer2/VBoxContainer/HBoxContainer2/Label2.text = \
			"RenderingDevice is not available on the current rendering driver"
		return

	shader_rid = load_shader(rd, shader_path)
	
	var u_data := PackedFloat32Array([1. / float(resolution)]).to_byte_array()
	u_data.append_array(PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])) # filler for std140
	if uniform_data != PackedByteArray([]):
		u_data = uniform_data
	
	uniform_buffer_rid = rd.uniform_buffer_create(u_data.size(), u_data)
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	uniform.binding = 0
	uniform.add_id(uniform_buffer_rid)
	uniform_set_rid = rd.uniform_set_create([uniform], shader_rid, 0)
	# (Draw list)
	var vertex_data := PackedFloat32Array([-0.5, -0.5, 1., 0.5, -0.5, 1., -0.5, 0.5, 1., 0.5, -0.5, 1., -0.5, 0.5, 1., 0.5, 0.5, 1.]).to_byte_array()
	vertex_buffer_rid = rd.vertex_buffer_create(vertex_data.size(), vertex_data)

	var vertex_attribute := RDVertexAttribute.new()
	vertex_attribute.format = RenderingDevice.DATA_FORMAT_R8G8B8_SNORM
	vertex_attribute.stride = 12
	
	var v_format := rd.vertex_format_create([vertex_attribute])
	
	vertex_array_rid = rd.vertex_array_create(6, v_format, [vertex_buffer_rid])
	
	var blend_attachment = RDPipelineColorBlendStateAttachment.new()
	blend_attachment.write_r = true
	blend_attachment.write_g = true
	blend_attachment.write_b = true
	blend_attachment.write_a = true
	blend_attachment.enable_blend = false
	var c_blend := RDPipelineColorBlendState.new()
	c_blend.attachments = [blend_attachment]
	
	pipeline = rd.render_pipeline_create(shader_rid, rd.framebuffer_get_format(framebuffer), v_format, \
	RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, r_state, RDPipelineMultisampleState.new(), d_state, c_blend)
	
	var clear_colors = PackedColorArray([Color(0., 0., 0., 0)])
	var draw_list = rd.draw_list_begin(framebuffer, RenderingDevice.INITIAL_ACTION_CLEAR, \
	RenderingDevice.FINAL_ACTION_STORE, RenderingDevice.INITIAL_ACTION_CLEAR, RenderingDevice.FINAL_ACTION_DISCARD, clear_colors)
	
	rd.draw_list_bind_vertex_array(draw_list, vertex_array_rid)
	rd.draw_list_bind_uniform_set(draw_list, uniform_set_rid, 0)
	rd.draw_list_bind_render_pipeline(draw_list, pipeline)
	rd.draw_list_draw(draw_list, false, 1)
	rd.draw_list_end()

	rd.submit()
	rd.sync()
	
	var output_bytes := rd.texture_get_data(image_rid, 0)
	
	var island_img := Image.create_from_data(resolution, resolution, false, Image.FORMAT_RGBA8, output_bytes)
	var tex = ImageTexture.create_from_image(island_img)
	
	rd.free_rid(uniform_set_rid)
	uniform_set_rid = RID()
	rd.free_rid(uniform_buffer_rid)
	uniform_buffer_rid = RID()
	rd.free_rid(vertex_array_rid)
	vertex_array_rid = RID()
	rd.free_rid(vertex_buffer_rid)
	vertex_buffer_rid = RID()
	rd.free_rid(shader_rid)
	shader_rid = RID()

	return tex


func cleanup_gpu() -> void:
	if rd == null:
		return
	# All resources must be freed after use to avoid memory leaks.
	
	rd.free_rid(framebuffer)
	framebuffer = RID()
	rd.free_rid(image_rid)
	image_rid = RID()
	
	rd.free()
	rd = null
