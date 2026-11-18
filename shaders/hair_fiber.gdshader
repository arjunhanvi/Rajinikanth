// Fine groomed hair (eyebrows, moustache, sideburns, hairline): thin alpha-blended fibres, darker at
// the root, soft tapered tips, light wrapping through the hair and a narrow highlight along the strand.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, depth_prepass_alpha;

uniform sampler2D strands : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float density = 1.0;
uniform float spec_strength = 0.16;

varying float tipw;

void vertex() {
	tipw = COLOR.a;
}

void fragment() {
	vec4 t = texture(strands, UV);
	ALBEDO = COLOR.rgb * tint * mix(0.7, 1.15, t.r) * mix(0.75, 1.0, tipw);
	ALPHA = clamp(t.a * density * (1.0 - 0.35 * tipw), 0.0, 1.0);
	ROUGHNESS = 0.62;
	SPECULAR = 0.2;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float d = clamp((ndl + 0.6) / 1.6, 0.0, 1.0);
	DIFFUSE_LIGHT += d * ATTENUATION * LIGHT_COLOR / PI;
	vec3 H = normalize(LIGHT + VIEW);
	float s = pow(clamp(dot(NORMAL, H), 0.0, 1.0), 26.0) * spec_strength;
	SPECULAR_LIGHT += s * clamp(ndl + 0.3, 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI;
}
