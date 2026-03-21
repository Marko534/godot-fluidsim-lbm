extends Node3D

var rd: RenderingDevice
var shared_texture_rid: RID
var godot_texture: Texture2DRD
var pipeline: RID
var uniform_set: RID
var time_buffer: RID
var elapsed_time: float = 0.0
const texture_size: int = 512
var save_timer: float = 0.0
const save_interval: float = 2.0
var save_index: int = 0
const max_saves: int = 8

func _ready() -> void:
	rd = RenderingServer.get_rendering_device()
	var tf := RDTextureFormat.new()
	tf.width = texture_size
	tf.height = texture_size
	tf.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	tf.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT  # needed to read back pixels
	)
	shared_texture_rid = rd.texture_create(tf, RDTextureView.new(), [])

	godot_texture = Texture2DRD.new()
	godot_texture.texture_rd_rid = shared_texture_rid
	var mat: ShaderMaterial = $MeshInstance3D.get_active_material(0)
	mat.set_shader_parameter("compute_output", godot_texture)

	_setup_compute()

func _setup_compute() -> void:
	var shader_file := load("res://wind/compute_example.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	var shader := rd.shader_create_from_spirv(shader_spirv)

	time_buffer = rd.uniform_buffer_create(16)

	var tex_uniform := RDUniform.new()
	tex_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	tex_uniform.binding = 0
	tex_uniform.add_id(shared_texture_rid)

	var time_uniform := RDUniform.new()
	time_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	time_uniform.binding = 1
	time_uniform.add_id(time_buffer)

	uniform_set = rd.uniform_set_create([tex_uniform, time_uniform], shader, 0)
	pipeline = rd.compute_pipeline_create(shader)

func _process(delta: float) -> void:
	elapsed_time += delta
	save_timer += delta

	var time_data := PackedFloat32Array([elapsed_time, 0.0, 0.0, 0.0])
	rd.buffer_update(time_buffer, 0, 16, time_data.to_byte_array())

	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, texture_size/8 , texture_size/8, 1)  # 8/8 = 1 workgroup
	rd.compute_list_end()

	# Save PNG once after first frame for debugging
	if save_timer >= save_interval:
		save_timer = 0.0
		var path := "res://debug/compute_debug_%d_%d.png" % [texture_size, save_index % max_saves]		
		save_texture_as_png(path)
		save_index += 1

func save_texture_as_png(path: String) -> void:
	rd.submit()
	rd.sync()
	var raw_bytes := rd.texture_get_data(shared_texture_rid, 0)
	var img := Image.create_from_data(texture_size, texture_size, false, Image.FORMAT_RGBAF, raw_bytes)
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(path)
	print("Saved debug texture to: ", path)
