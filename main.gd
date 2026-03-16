extends Node3D

var rd: RenderingDevice
var shared_texture_rid: RID
var godot_texture: Texture2DRD
var pipeline: RID
var uniform_set: RID
var time_buffer: RID
var elapsed_time: float = 0.0

func _ready() -> void:
	rd = RenderingServer.get_rendering_device()

	var tf := RDTextureFormat.new()
	tf.width = 512
	tf.height = 512
	tf.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	tf.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
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

	# Create time uniform buffer (4 bytes = one float)
	time_buffer = rd.uniform_buffer_create(16)  # std140 needs minimum 16 bytes

	# Texture uniform at binding 0
	var tex_uniform := RDUniform.new()
	tex_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	tex_uniform.binding = 0
	tex_uniform.add_id(shared_texture_rid)

	# Time uniform at binding 1
	var time_uniform := RDUniform.new()
	time_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	time_uniform.binding = 1
	time_uniform.add_id(time_buffer)

	uniform_set = rd.uniform_set_create([tex_uniform, time_uniform], shader, 0)
	pipeline = rd.compute_pipeline_create(shader)

func _process(delta: float) -> void:
	elapsed_time += delta

	# Pack time into bytes and update the buffer
	var time_data := PackedFloat32Array([elapsed_time, 0.0, 0.0, 0.0])  # padded to 16 bytes
	rd.buffer_update(time_buffer, 0, 16, time_data.to_byte_array())

	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, 512 / 8, 512 / 8, 1)
	rd.compute_list_end()
