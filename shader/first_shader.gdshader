shader_type spatial;

uniform float height_scale = 0.5;
uniform sampler2D noise;
uniform sampler2D normalmap;
uniform sampler2D compute_output;

varying vec2 tex_position;

void vertex() {
    tex_position = VERTEX.xz / 2.0 + 0.5;

    float compute_height = texture(compute_output, tex_position).r;

    VERTEX.y += compute_height * height_scale;
}

void fragment() {
    ALBEDO = texture(compute_output, tex_position).rgb;
}