# LBM Wind Simulation — Godot 4

A real-time 3D wind simulation using the Lattice Boltzmann Method (LBM) implemented entirely on the GPU via Godot's `RenderingDevice` compute shaders. Wind data is stored in a 3D texture and consumed by material shaders and particle systems with no CPU readback.

---

## Architecture

```
Compute Pipeline (GPU)
│
├── init.glsl       — initializes F[] distribution functions once at startup
├── collide.glsl    — TRT collision step, writes velocity+density to Texture3D
└── stream.glsl     — propagates F[] to neighboring cells, applies boundary forces
         │
         ▼
    Texture3D (VRAM)   — rgba32f, NX×NY×NZ
    xyz = velocity, w = density/pressure
         │
         ├── Material Shaders   — sample wind for vertex displacement + visualization
         └── Particle Shader    — advects particles through the wind field
```

---

## File Structure

```
res://weather/wind/
├── main.gd               — GDScript: buffer setup, pipeline dispatch
├── wind.gdshader         — spatial shader: wind velocity visualization
├── pressure.gdshader     — spatial shader: pressure/density visualization
├── particles.gdshader    — particle shader: wind-advected particles
├── wind.tres             — ShaderMaterial resource for wind mesh
├── pressure.tres         — ShaderMaterial resource for pressure mesh
└── LBM/
    ├── lbm.glsli         — shared include: buffers, velocity set, equilibrium
    ├── init.glsl         — initialization compute shader
    ├── collide.glsl      — collision compute shader (TRT method)
    └── stream.glsl       — streaming compute shader
```

---

## LBM Grid

| Parameter | Value |
|---|---|
| Grid size | 64 × 32 × 64 |
| Velocity set | D3Q19 |
| Collision method | TRT (Two-Relaxation-Time) |
| Boundary condition | Wetnode (domain edges), Bounce-back (terrain) |
| Relaxation time τ | 0.56 |
| Workgroup size | 16×1×16 or 32×1×32 |

---

## Buffer Layout

| Binding | Name | Type | Size | Description |
|---|---|---|---|---|
| 0 | `F[]` | SSBO | NX×NY×NZ×19 floats | Distribution functions |
| 1 | `FPROP[]` | SSBO | NX×NY×NZ×19 floats | Post-collision distributions |
| 2 | `B[]` | SSBO | NX×NY×NZ floats | Boundary mask (1=solid, 0=fluid) |
| 3 | `velocity_tex_3d` | image3D rgba32f | NX×NY×NZ | Velocity (xyz) + density (w) |
| 5 | `SimParams` | UBO | 16 bytes | NX, NY, NZ (int), t (float) |

---

## GDScript — Key Constants

```gdscript
const NX: int = 64       # grid width
const NY: int = 32       # grid height
const NZ: int = 64       # grid depth
const Q:  int = 19       # D3Q19 velocity directions
var layout_size: int = 16  # compute shader local_size_x/z
```

---

## Dispatch Pattern

Every frame in `_process()`:

```gdscript
# 1. Collide — writes velocity+density to Texture3D
rd.compute_list_dispatch(compute_list, NX / layout_size, NY, NZ / layout_size)

# 2. Stream — propagates F[], applies wetnode boundary
rd.compute_list_dispatch(compute_list, NX / layout_size, NY, NZ / layout_size)
```

Init runs once at startup.

---

## Texture3D — GPU Bridge

The 3D texture is the only bridge between the compute pipeline and the rendering pipeline. No CPU readback occurs during normal operation.

```gdscript
# Created with:
tf.format    = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
tf.usage_bits = STORAGE_BIT | SAMPLING_BIT | CAN_UPDATE_BIT | CAN_COPY_FROM_BIT

# Bridged to Godot's material system via:
godot_texture_3d.texture_rd_rid = shared_texture_rid
mat.set_shader_parameter("weather", godot_texture_3d)
```

---

## Material Shader Usage

```glsl
uniform sampler3D weather : hint_default_black, repeat_disable;

void vertex() {
	vec3 uvw    = vec3(UV.x, 0.5, UV.y);       // sample at mid-height
	vec4 sample = texture(weather, uvw);
	vec3 wind   = sample.xyz;                   // velocity
	float rho   = sample.w;                     // density/pressure
	VERTEX.y   += wind.y * height_scale;
}
```

---

## Particle Shader Usage

```glsl
uniform sampler3D weather : hint_default_black, repeat_disable;

void process() {
	// Map world position to 0..1 UVW
	vec3 uvw  = vec3(
		(TRANSFORM[3].x + 1.0) / 2.0,
		(TRANSFORM[3].y + 0.5),
		(TRANSFORM[3].z + 1.0) / 2.0
	);
	vec3 wind         = texture(weather, uvw).xyz;
	VELOCITY          = wind * wind_strength;
	TRANSFORM[3].xyz += VELOCITY * DELTA;
}
```

---

## Boundary Conditions

### Terrain (Solid — Bounce-back)
Generated from a `FastNoiseLite` heightmap at startup:
```gdscript
# Cells below noise height = solid (B[i] = 1.0)
# Cells above noise height = fluid (B[i] = 0.0)
boundary[i] = 1.0 if y < height_cell else 0.0
```

### Domain Edges (Wetnode — Driven Flow)
Applied in `stream.glsl` — edges are reset to equilibrium with a time-varying force:
```glsl
vec3 force = 0.1 * vec3(cos(params.t), 0, sin(params.t));
F[ind*Q + q] = equilibrium(q, 1.0, force);
```

---

## Performance Notes

- GTX 1650 Ti (4GB VRAM) runs 64×32×64 grid at 60fps
- Doubling to 128×64×128 increases cell count 8× — expect significant frametime increase
- (TODO) To reduce GPU load: run simulation at 30hz, render at 60hz using a timer in `_process()`
- `buffer_update` for SimParams (16 bytes/frame) has negligible overhead
- Main bottleneck is always dispatch thread count: `NX × NY × NZ × Q` operations per frame

---

## Dependencies

- Godot Engine 4.6 — Forward+ renderer (Vulkan)
- `RenderingDevice` API for compute shaders
- `Texture3DRD` for GPU texture bridging
- `FastNoiseLite` for terrain heightmap generation
