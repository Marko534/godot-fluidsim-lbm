shader_type spatial;

uniform sampler2D heightmap;
uniform sampler2D heightmap_normal : hint_normal;

varying vec2 uv_coord;

void vertex() {
    uv_coord    = UV;
    VERTEX.y = texture(heightmap, UV).r;
}

void fragment() {
    ALBEDO = vec3(texture(heightmap, uv_coord).r, 0.0, 0.0);  // visualize height as gray
}