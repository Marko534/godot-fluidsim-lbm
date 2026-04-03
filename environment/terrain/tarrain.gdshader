shader_type spatial;
render_mode wireframe, unshaded;

uniform sampler2D heightmap;
uniform sampler2D heightmap_normal : hint_normal;

varying vec2 uv_coord;

void vertex() {
    uv_coord    = UV;
    VERTEX.y = texture(heightmap, UV).r;
}

void fragment() {
    //ALBEDO = vec3(texture(heightmap, uv_coord).r, 0.0, 0.0);  // visualize height as gray
	//float h = texture(heightmap, uv_coord).r;
//
	//vec3 low = vec3(0.0); // red
	//vec3 high = vec3(0.2); // red
	//
	//ALBEDO = mix(low, high, h);
	ALBEDO = texture(heightmap, UV).rgb;
}