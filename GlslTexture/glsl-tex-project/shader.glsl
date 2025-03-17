#[vertex]
#version 460

vec2 positions[3] = vec2[](
    vec2(0., -3.),
    vec2(3., 3.),
    vec2(-3., 3.)
);

void main() {
    gl_Position = vec4(positions[gl_VertexIndex], 0.0, 1.0);
}

#[fragment]
#version 460
#define PI 3.14159265359

layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 0, std140) uniform uniform_buffer {
    float px_size;
} u_buffer;

float random(in vec2 st) {
    vec3 p3  = fract(vec3(st.xyx) * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

mat2 rotate2d(const in float r){
    float c = cos(r);
    float s = sin(r);
    return mat2(c, s, -s, c);
}

void main() {
	vec2 st = gl_FragCoord.xy * u_buffer.px_size; st.y = 1. - st.y;
    st.x *= 1.5;
    st *= 10.;

    vec2 i = floor(st);
    vec2 f = fract(st);
    f -= 0.5;
    float rand = random(i);;
    rand = floor(rand * 4.) * 0.5 * PI + 0.25 * PI;
    f = rotate2d(rand) * f;
    float pct = sign(-f.x);
    FragColor = vec4(vec3(pct) * 0.5, 1.0);
}