shader_type spatial;
render_mode unshaded, fog_disabled;

uniform sampler2D tex : source_color;

vec2 rotate2d(in vec2 v, in float r) {
	float c = cos(r);
	float s = sin(r);
	mat2 m;
	m[0] = vec2(c, s);
	m[1] = vec2(-s, c);
	return m * v;
}

void vertex() {
	VERTEX.xz = rotate2d(VERTEX.xz, TIME * 0.25);
	VERTEX.xy = rotate2d(VERTEX.xy, TIME * 0.25);
}

void fragment() {
	ALBEDO = texture(tex, UV).rgb;
}
