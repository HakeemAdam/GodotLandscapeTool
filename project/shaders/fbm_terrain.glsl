#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(rgba32f, set = 0, binding = 0) uniform writeonly image2D output_heightmap;

layout(push_constant, std430) uniform Parameters {
        float noise_seed;
        float time;
        float pan_direction_x;
        float pan_direction_y;
        float pan_speed;
        float scale;
        float detail;
        float manual_pan_x;
        float manual_pan_y;
} params;

float random(vec2 uv) {
        ivec2 src = ivec2(uv);
        int n = src.x + src.y * 57 + int(params.noise_seed * 131.0);
        n = (n << 13) ^ n;
        int nn = (n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff;
        return float(nn) / 2147483647.0;
}

float noise(vec2 uv) {
        vec2 i = floor(uv);
        vec2 f = fract(uv);

        float a = random(i);
        float b = random(i + vec2(1.0, 0.0));
        float c = random(i + vec2(0.0, 1.0));
        float d = random(i + vec2(1.0, 1.0));

        vec2 u = f * f * (3.0 - 2.0 * f);
        return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

#define OCTAVES 6
float fbm(vec2 uv) {
        float value = 0.0;
        float amplitude = 0.5;
        float frequency = 1.0;

        for (int i = 0; i < OCTAVES; i++) {
                value += amplitude * noise(uv);
                uv *= 2.0;
                amplitude *= 0.5;
        }
        return value;
}

float get_height(vec2 uv) {
        vec2 warp = vec2(noise(uv * 1.5), noise(uv * 1.5 + vec2(9.2, 1.3)));
        return 1.0 - fbm(uv + warp * 0.4);
}

void main() {
        ivec2 pixel_cord = ivec2(gl_GlobalInvocationID.xy);
        ivec2 size = imageSize(output_heightmap);

        if (pixel_cord.x >= size.x || pixel_cord.y >= size.y) return;

        vec2 uv = vec2(pixel_cord) / vec2(size);
        vec2 manual = vec2(params.manual_pan_x, params.manual_pan_y);
        vec2 direction = vec2(params.pan_direction_x, params.pan_direction_y);

        vec2 offset = (uv * params.detail) + direction * mod(params.time, 100) * params.pan_speed + manual;

        float height = get_height(offset) * params.scale;
        vec4 color = vec4(vec3(height), 1.0);
        imageStore(output_heightmap, pixel_cord, color);
}
