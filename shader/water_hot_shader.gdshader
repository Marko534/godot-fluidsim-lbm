shader_type spatial;
render_mode specular_toon, cull_back;

// Wave parameters
uniform float wave_frequency : hint_range(0.1, 2.0) = 0.6;
uniform float wave_height_div : hint_range(1.0, 5.0) = 2.5;
uniform float wave_weight_scale : hint_range(0.5, 1.0) = 0.8;
uniform float wave_freq_scale : hint_range(1.0, 2.0) = 1.2;
uniform float wave_time_scale : hint_range(1.0, 1.5) = 1.095;
uniform float wave_rotation : hint_range(0.5, 2.0) = 1.21;
uniform float wave_drag : hint_range(0.5, 1.0) = 0.9;
uniform float scroll_speed : hint_range(0.5, 3.0) = 1.5;
uniform vec2 scroll_dir = vec2(1.0, 1.0);
uniform float horizontal_scale : hint_range(0.5, 2.0) = 1.1;
uniform float occlusion_speed : hint_range(0.5, 2.0) = 1.4;

// Rendering parameters
uniform float spec_offset : hint_range(0.0, 1.0) = 0.13;
uniform vec4 water_color : source_color = vec4(0.01, 0.03, 0.05, 1.0);
uniform vec4 sky_color : source_color = vec4(0.4, 0.7, 1.0, 1.0);
uniform vec4 sun_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);
uniform vec4 depth_color : source_color = vec4(0.0, 0.15, 0.25, 1.0);
uniform float fresnel_power : hint_range(1.0, 10.0) = 5.0;
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.9;
uniform float refraction_strength : hint_range(0.0, 5.0) = 2.5;
uniform vec2 sun_rotation = vec2(-0.3, -0.25);

const int WAVE_ITERS = 9;

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a);
    float s = sin(a);
    return mat2(vec2(c, s), vec2(-s, c));
}

// Color palette function
vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
    return a + b * cos(2.0 * PI * (c * t + d));
}

vec3 spectrum_color(float n, float bright) {
    return palette(n, vec3(bright), vec3(0.5), vec3(1.0), vec3(0.0, 0.33, 0.67));
}

// Wave calculation
float calculate_wave(vec2 wave_pos, int iters, float time) {
    float wav = 0.0;
    vec2 wave_dir = vec2(1.0, 0.0);
    float wave_weight = 1.0;
    
    wave_pos += time * scroll_speed * scroll_dir;
    wave_pos *= horizontal_scale;
    
    float wav_freq = wave_frequency;
    float wav_time = occlusion_speed * time;
    
    for(int i = 0; i < iters; i++) {
        wave_dir = rot(wave_rotation) * wave_dir;
        float x = dot(wave_dir, wave_pos) * wav_freq + wav_time;
        float wave = exp(sin(x) - 1.0) * wave_weight;
        wav += wave;
        
        wav_freq *= wave_freq_scale;
        wav_time *= wave_time_scale;
        wave_pos -= wave_dir * wave * wave_drag * cos(x);
        wave_weight *= wave_weight_scale;
    }
    
    float wave_sum = -(pow(wave_weight_scale, float(iters)) - 1.0) * wave_height_div;
    return wav / wave_sum;
}

// Wave derivative for normals
vec2 wave_derivative(vec2 wave_pos, int iters, float time) {
    vec2 dx = vec2(0.0);
    vec2 wave_dir = vec2(1.0, 0.0);
    float wave_weight = 1.0;
    
    wave_pos += time * scroll_speed * scroll_dir;
    wave_pos *= horizontal_scale;
    
    float wav_freq = wave_frequency;
    float wav_time = occlusion_speed * time;
    
    for(int i = 0; i < iters; i++) {
        wave_dir = rot(wave_rotation) * wave_dir;
        float x = dot(wave_dir, wave_pos) * wav_freq + wav_time;
        float result = exp(sin(x) - 1.0) * cos(x);
        result *= wave_weight;
        dx += result * wave_dir / pow(wave_weight, 0.65);
        
        wav_freq *= wave_freq_scale;
        wav_time *= wave_time_scale;
        wave_pos -= wave_dir * result * wave_drag;
        wave_weight *= wave_weight_scale;
    }
    
    float wave_sum = -(pow(wave_weight_scale, float(iters)) - 1.0) * wave_height_div;
    return dx / pow(wave_sum, 0.35);
}

void vertex() {
    vec2 pos = VERTEX.xz;
    float wave_height = calculate_wave(pos, WAVE_ITERS, TIME);
    VERTEX.y = wave_height;
    
    // Calculate normal from wave derivatives
    vec2 wav_dx = -wave_derivative(pos, WAVE_ITERS, TIME);
    NORMAL = normalize(vec3(wav_dx.x, 1.0, wav_dx.y));
}

void fragment() {
    // Fresnel effect
    float fresnel = clamp(pow(1.0 - max(0.0, dot(NORMAL, VIEW)), fresnel_power), 0.0, 1.0);
    
    // Reflection
    vec3 reflection = sky_color.rgb * fresnel * reflection_strength;
    
    // Refraction glow (subsurface scattering approximation)
    vec3 refract_color = sun_color.rgb * refraction_strength;
    
    // Water depth color
    vec3 depth_col = depth_color.rgb * 0.4;
    
    // Combine all components
    ALBEDO = water_color.rgb + depth_col * 0.17 + reflection;
    ALBEDO += refract_color * fresnel * 0.1;
    
    // Material properties
    METALLIC = 0.0;
    ROUGHNESS = 0.01 * (1.0 - fresnel);
    RIM = 0.2;
    SPECULAR = 0.5;
    
    // Add slight transparency for deeper water feel
    ALPHA = 0.95 + fresnel * 0.05;
}