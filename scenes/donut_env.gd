extends GPUParticles3D # was extends Node3D

enum SimRate {UNCAPPED, HZ_60, HZ_30, HZ_1}
var sim_rate: SimRate
var sim_timer: float = 0.0

# LBM Grid Dimensions
const NX: int = 64
const NY: int = 64
const NZ: int = 64

const Q: int = 15
#const Q: int = 19
#const Q: int = 27

# Rendering
var rd: RenderingDevice
var layout_size: int = 16
var layout_size_y: int = 2

# Buffers
var buf_f: RID
var buf_fprop: RID
var buf_b: RID
var buf_params: RID

# Texture
var shared_texture_rid: RID
var godot_texture_3d: Texture3DRD = Texture3DRD.new()

# Pipelines
var pipeline_init: RID
var pipeline_collide: RID
var pipeline_stream: RID

# Uniform Sets
var uset_init: RID
var uset_collide: RID
var uset_stream: RID

# State
var elapsed_time: float = 0.0

# -------------------------------------------------------------------------
func _ready() -> void:
	var root = get_parent().get_parent()
	sim_rate = root.sim_rate
	root.sim_rate_changed.connect(_on_sim_rate_changed)

	rd = RenderingServer.get_rendering_device()
	_create_buffers()
	_create_output_texture()
	_setup_pipelines()
	_run_init()

func _on_sim_rate_changed(new_rate):
	sim_rate = new_rate

# -------------------------------------------------------------------------
func _create_buffers() -> void:
	var cell_count := NX * NY * NZ
	var float_bytes := 4

	buf_f = rd.storage_buffer_create(cell_count * Q * float_bytes)
	buf_fprop = rd.storage_buffer_create(cell_count * Q * float_bytes)

	var boundary := _create_boundary_from_children(self as GPUParticles3D)
	buf_b = rd.storage_buffer_create(cell_count * float_bytes, boundary.to_byte_array())
	buf_params = rd.uniform_buffer_create(16)

# -------------------------------------------------------------------------
func _create_output_texture() -> void:
	var tf := RDTextureFormat.new()
	tf.width = NX
	tf.height = NY
	tf.depth = NZ
	tf.array_layers = 1
	tf.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_3D
	tf.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)
	shared_texture_rid = rd.texture_create(tf, RDTextureView.new(), [])

	godot_texture_3d.texture_rd_rid = shared_texture_rid

	var mat_sim := load("res://environment/atmosphere/particles_donut.tres") as Material
	mat_sim.set_shader_parameter("weather", godot_texture_3d)

# -------------------------------------------------------------------------
func _make_uniform_set(shader: RID) -> RID:
	var uniforms: Array[RDUniform] = []

	var bindings = [
		[buf_f, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 0],
		[buf_fprop, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 1],
		[buf_b, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 2],
		[buf_params, RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER, 5],
	]
	for entry in bindings:
		var u := RDUniform.new()
		u.uniform_type = entry[1]
		u.binding = entry[2]
		u.add_id(entry[0])
		uniforms.append(u)

	var tex_uniform := RDUniform.new()
	tex_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	tex_uniform.binding = 3
	tex_uniform.add_id(shared_texture_rid)
	uniforms.append(tex_uniform)

	return rd.uniform_set_create(uniforms, shader, 0)

# -------------------------------------------------------------------------
func _setup_pipelines() -> void:
	var init_shader := _load_shader("res://environment/atmosphere/LBM/init.glsl")
	var collide_shader := _load_shader("res://environment/atmosphere/LBM/collide.glsl")
	var stream_shader := _load_shader("res://environment/atmosphere/LBM/stream.glsl")

	pipeline_init = rd.compute_pipeline_create(init_shader)
	pipeline_collide = rd.compute_pipeline_create(collide_shader)
	pipeline_stream = rd.compute_pipeline_create(stream_shader)

	uset_init = _make_uniform_set(init_shader)
	uset_collide = _make_uniform_set(collide_shader)
	uset_stream = _make_uniform_set(stream_shader)

func _load_shader(path: String) -> RID:
	var file: RDShaderFile = load(path)
	var spirv: RDShaderSPIRV = file.get_spirv()
	return rd.shader_create_from_spirv(spirv)

# -------------------------------------------------------------------------
func _run_init() -> void:
	_update_params()
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline_init)
	rd.compute_list_bind_uniform_set(compute_list, uset_init, 0)
	rd.compute_list_dispatch(compute_list, NX / layout_size, NY / layout_size_y, NZ / layout_size)
	rd.compute_list_end()

# -------------------------------------------------------------------------
func _process(delta: float) -> void:
	elapsed_time += delta
	#sim_rate = get_parent().get_parent().sim_rate
	#_update_pardams()
	#_compute_process()
	match sim_rate:
		SimRate.UNCAPPED:
			_update_params()
			_compute_process()
		SimRate.HZ_60:
			sim_timer += delta
			if sim_timer >= 1.0 / 60.0:
				sim_timer = 0.0
				_update_params()
				_compute_process()
		SimRate.HZ_30:
			sim_timer += delta
			if sim_timer >= 1.0 / 30.0:
				sim_timer = 0.0
				_update_params()
				_compute_process()
		SimRate.HZ_1:
			sim_timer += delta
			if sim_timer >= 1.0 / 1.0:
				sim_timer = 0.0
				_update_params()
				_compute_process()

func _compute_process() -> void:
	var compute_list = rd.compute_list_begin()

	rd.compute_list_bind_compute_pipeline(compute_list, pipeline_collide)
	rd.compute_list_bind_uniform_set(compute_list, uset_collide, 0)
	rd.compute_list_dispatch(compute_list, NX / layout_size, NY / layout_size_y, NZ / layout_size)

	rd.compute_list_bind_compute_pipeline(compute_list, pipeline_stream)
	rd.compute_list_bind_uniform_set(compute_list, uset_stream, 0)
	rd.compute_list_dispatch(compute_list, NX / layout_size, NY / layout_size_y, NZ / layout_size)

	rd.compute_list_end()

# -------------------------------------------------------------------------
func _update_params() -> void:
	var data := PackedByteArray()
	data.resize(16)
	data.encode_s32(0, NX)
	data.encode_s32(4, NY)
	data.encode_s32(8, NZ)
	data.encode_float(12, elapsed_time)
	rd.buffer_update(buf_params, 0, 16, data)

# -------------------------------------------------------------------------
func _create_boundary_from_children(particles: GPUParticles3D) -> PackedFloat32Array:
	var boundary := PackedFloat32Array()
	boundary.resize(NX * NY * NZ)

	var sim_transform := particles.global_transform
	var sim_size := Vector3(
		sim_transform.basis.x.length(),
		sim_transform.basis.y.length(),
		sim_transform.basis.z.length()
	)
	var sim_origin := sim_transform.origin

	# Collect all mesh faces from MeshInstance3D children
	var all_faces: Array[Vector3] = []
	for child in particles.get_children():
		if child is MeshInstance3D:
			var faces: PackedVector3Array = child.mesh.get_faces()
			var xform: Transform3D = child.global_transform
			for i in range(0, faces.size(), 3):
				all_faces.append(xform * faces[i])
				all_faces.append(xform * faces[i + 1])
				all_faces.append(xform * faces[i + 2])

	# Voxelize
	for x in NX:
		for z in NZ:
			var height_cell := 0
			var wx := sim_origin.x + (float(x) / NX - 0.5) * sim_size.x * 2.0
			var wz := sim_origin.z + (float(z) / NZ - 0.5) * sim_size.z * 2.0

			for i in range(0, all_faces.size(), 3):
				var a := all_faces[i]
				var b := all_faces[i + 1]
				var c := all_faces[i + 2]

				var min_x: float = min(a.x, min(b.x, c.x))
				var max_x: float = max(a.x, max(b.x, c.x))
				var min_z: float = min(a.z, min(b.z, c.z))
				var max_z: float = max(a.z, max(b.z, c.z))

				if wx >= min_x and wx <= max_x and wz >= min_z and wz <= max_z:
					var avg_y: float = (a.y + b.y + c.y) / 3.0
					var norm_y: float = (avg_y - (sim_origin.y - sim_size.y)) / (sim_size.y * 2.0)
					var cell_y: int = int(norm_y * NY)
					height_cell = max(height_cell, cell_y)

			for y in NY:
				var i := (x * NY + y) * NZ + z
				boundary[i] = 1.0 if y < height_cell else 0.0

	return boundary
