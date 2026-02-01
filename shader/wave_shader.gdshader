shader_type spatial;
render_mode specular_toon;

uniform float TIME_SCALE = 0.5;
uniform vec3 albedo : source_color = vec3(0.0, 0.322, 0.431);

uniform vec2 wave_dir1 = vec2(1.0, 0.0);
uniform vec2 wave_dir2 = vec2(0.0, 1.0);
uniform vec2 wave_dir3 = vec2(0.7, 0.7);
uniform vec2 wave_dir4 = vec2(-0.3, 0.8);

uniform sampler2D noise;

float wave(vec2 position){
  position += texture(noise, position / 10.0).x * 2.0 - 1.0;
  vec2 wv = 1.0 - abs(sin(position));
  return pow(1.0 - pow(wv.x * wv.y, 0.65), 4.0);
}

float height(vec2 position, float time) {
  float d = wave((position + wave_dir1 * time) * 0.4) * 0.3;
  d += wave((position + wave_dir2 * time) * 0.3) * 0.3;
  d += wave((position + wave_dir3 * time) * 0.5) * 0.2;
  d += wave((position + wave_dir4 * time) * 0.6) * 0.2;
  return d;
}

void vertex() {
  float time_scale = TIME * TIME_SCALE; 
  //world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
  vec2 pos = VERTEX.xz;
  float k = height(pos, time_scale);
  VERTEX.y = k;
  NORMAL = normalize(vec3(k - height(pos + vec2(0.1, 0.0), time_scale), 0.1, k - height(pos + vec2(0.0, 0.1), time_scale)));
}

void fragment() {
  float fresnel = sqrt(1.0 - dot(NORMAL, VIEW));
  RIM = 1.0;
  METALLIC = 0.0;
  ROUGHNESS = 0.01 * (1.0 - fresnel);
  ALBEDO = albedo + (0.05 * fresnel);
}