shader_type spatial;

uniform float height_scale = 0.5;
uniform sampler2D noise;
uniform sampler2D normalmap;
uniform sampler2D compute_output;  // fed by compute shader

varying vec2 tex_position;

void vertex() {
    tex_position = VERTEX.xz / 2.0 + 0.5;
    
    // Use compute output for height instead of (or blended with) CPU noise
    float compute_height = texture(compute_output, tex_position).r;
    float height = texture(noise, tex_position).x;
    
    VERTEX.y += (height + compute_height) * height_scale;
}

void fragment() {
    NORMAL_MAP = texture(normalmap, tex_position).xyz;
}