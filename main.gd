extends Node3D

@export var noise: FastNoiseLite

# --- LBM Grid Dimensions ---
const NX: int = 64
const NY: int = 32
const NZ: int = 64
const Q: int = 19

# --- Rendering ---
var rd: RenderingDevice

# --- Buffers ---
var buf_f: RID # distribution functions
var buf_fprop: RID # post-collision
var buf_b: RID # boundary
var buf_rho: RID # density
var buf_v: RID # velocity (vec4 per cell)
var buf_params: RID # SimParams uniform buffer

# --- Pipelines ---
var pipeline_init: RID
var pipeline_collide: RID
var pipeline_stream: RID

# --- Uniform Sets ---
var uset_init: RID
var uset_collide: RID
var uset_stream: RID

# --- Output texture for material ---
var shared_texture_rid: RID
var godot_texture_3d: Texture3DRD = Texture3DRD.new()

# --- State ---
var elapsed_time: float = 0.0
var initialized: bool = false

# --- Slice ---
var pipeline_slice: RID
var uset_slice: RID

# -------------------------------------------------------------------------
func _ready() -> void:
	rd = RenderingServer.get_rendering_device()
	_create_buffers()
	_create_output_texture()
	_setup_pipelines()
	#$MeshInstance3D.scale = Vector3(NX, 1, NZ)
	_run_init()
	initialized = true
	
# -------------------------------------------------------------------------
func _create_buffers() -> void:
	var cell_count := NX * NY * NZ
	var float_bytes := 4

	# F and FPROP: one float per direction per cell
	buf_f = rd.storage_buffer_create(cell_count * Q * float_bytes)
	buf_fprop = rd.storage_buffer_create(cell_count * Q * float_bytes)

	# Boundary: one float per cell ( get from heat map from env)
	var boundary := _create_boundary_from_noise()
	buf_b = rd.storage_buffer_create(cell_count * float_bytes, boundary.to_byte_array())
	
	# Density and velocity
	buf_rho = rd.storage_buffer_create(cell_count * float_bytes)
	buf_v = rd.storage_buffer_create(cell_count * 4 * float_bytes) # vec4

	# SimParams uniform buffer: NX, NY, NZ (ints) + t (float) = 16 bytes
	buf_params = rd.uniform_buffer_create(16)

# -------------------------------------------------------------------------
func _create_output_texture() -> void:
	# 3D texture matching the LBM grid exactly
	var tf := RDTextureFormat.new()
	tf.width = NX
	tf.height = NY
	tf.depth = NZ
	tf.array_layers = 1
	tf.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_3D
	tf.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | # slice shader writes
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | # material reads
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)
	shared_texture_rid = rd.texture_create(tf, RDTextureView.new(), [])

	# Texture3DRD bridges the RD texture to Godot's material system
	godot_texture_3d.texture_rd_rid = shared_texture_rid

	var mesh_pres := load("res://weather/wind/pressure.tres") as Mesh
	var mat_pres := mesh_pres.surface_get_material(0)
	mat_pres.set_shader_parameter("weather", godot_texture_3d)
	
	var mesh_wind := load("res://weather/wind/wind.tres") as Mesh
	var mat_wind := mesh_wind.surface_get_material(0)
	mat_wind.set_shader_parameter("weather", godot_texture_3d)

# -------------------------------------------------------------------------
func _make_uniform_set(shader: RID) -> RID:
	# All shaders share the same buffer layout (bindings 0-5)
	var uniforms: Array[RDUniform] = []

	var bindings = [
		[buf_f, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 0],
		[buf_fprop, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 1],
		[buf_b, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 2],
		[buf_rho, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 3],
		[buf_v, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 4],
		[buf_params, RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER, 5],
	]

	for entry in bindings:
		var u := RDUniform.new()
		u.uniform_type = entry[1]
		u.binding = entry[2]
		u.add_id(entry[0])
		uniforms.append(u)

	return rd.uniform_set_create(uniforms, shader, 0)

# -------------------------------------------------------------------------
func _setup_pipelines() -> void:
	var init_shader := _load_shader("res://weather/wind/LBM/init.glsl")
	var collide_shader := _load_shader("res://weather/wind/LBM/collide.glsl")
	var stream_shader := _load_shader("res://weather/wind/LBM/stream.glsl")
	var slice_shader := _load_shader("res://weather/wind/LBM/slice.glsl")

	pipeline_init = rd.compute_pipeline_create(init_shader)
	pipeline_collide = rd.compute_pipeline_create(collide_shader)
	pipeline_stream = rd.compute_pipeline_create(stream_shader)
	pipeline_slice = rd.compute_pipeline_create(slice_shader)

	uset_init = _make_uniform_set(init_shader)
	uset_collide = _make_uniform_set(collide_shader)
	uset_stream = _make_uniform_set(stream_shader)
	uset_slice = _make_uniform_set_slice(slice_shader)

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
	rd.compute_list_dispatch(compute_list, NX / 16, NY, NZ / 16)
	rd.compute_list_end()

# -------------------------------------------------------------------------
func _process(delta: float) -> void:
	if not initialized:
		return

	elapsed_time += delta
	_update_params()

	var compute_list = rd.compute_list_begin()

	# 1. Collide
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline_collide)
	rd.compute_list_bind_uniform_set(compute_list, uset_collide, 0)
	rd.compute_list_dispatch(compute_list, NX / 16, NY, NZ / 16)

	# 2. Stream
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline_stream)
	rd.compute_list_bind_uniform_set(compute_list, uset_stream, 0)
	rd.compute_list_dispatch(compute_list, NX / 16, NY, NZ / 16)

	# 3. Copy V[] → 3D texture (pure GPU)
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline_slice)
	rd.compute_list_bind_uniform_set(compute_list, uset_slice, 0)
	rd.compute_list_dispatch(compute_list, NX / 16, NY, NZ / 16)

	rd.compute_list_end()
# -------------------------------------------------------------------------
func _update_params() -> void:
	# Pack: NX(int), NY(int), NZ(int), t(float) — all 4 bytes each = 16 bytes
	var data := PackedByteArray()
	data.resize(16)
	data.encode_s32(0, NX)
	data.encode_s32(4, NY)
	data.encode_s32(8, NZ)
	data.encode_float(12, elapsed_time)
	rd.buffer_update(buf_params, 0, 16, data)

func _make_uniform_set_slice(shader: RID) -> RID:
	var uniforms: Array[RDUniform] = []

	var bindings = [
		[buf_f, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 0],
		[buf_fprop, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 1],
		[buf_b, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 2],
		[buf_rho, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 3],
		[buf_v, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 4],
		[buf_params, RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER, 5],
	]
	for entry in bindings:
		var u := RDUniform.new()
		u.uniform_type = entry[1]
		u.binding = entry[2]
		u.add_id(entry[0])
		uniforms.append(u)

	# Texture at binding 6
	var tex_uniform := RDUniform.new()
	tex_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	tex_uniform.binding = 6
	tex_uniform.add_id(shared_texture_rid)
	uniforms.append(tex_uniform)

	return rd.uniform_set_create(uniforms, shader, 0)
	
func _create_boundary_from_noise() -> PackedFloat32Array:
	var boundary := PackedFloat32Array()
	boundary.resize(NX * NY * NZ)

	# Get noise as image (already 64x64)
	var img := noise.get_image(NX, NZ)

	for x in NX:
		for z in NZ:
			# Sample noise pixel — red channel is height 0..1
			var height_norm  := img.get_pixel(x, z).r
			# Map 0..1 height to 0..NY cell height
			var height_cell  := int(height_norm * NY)

			for y in NY:
				var i        := (x * NY + y) * NZ + z
				# Solid below height, fluid above
				boundary[i]  = 1.0 if y < height_cell else 0.0

	return boundary
