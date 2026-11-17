// Card hair: clumps of strands on alpha-cut cards. Light wraps through the hair, a soft
// highlight sits along the strands, roots are darker, and a per-character spring offset
// sways the tips (vertex alpha = 0 at the root .. 1 at the tip), so the hair moves with
// the head without ever leaving it.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D strands : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 sway = vec3(0.0);          // model-space offset of the hair mass (spring lag + wind)
uniform float cut = 0.42;
uniform float spec_strength = 0.22;

varying float tipw;

void vertex() {
	tipw = COLOR.a;
	VERTEX += sway * pow(COLOR.a, 1.6);
}

void fragment() {
	vec4 t = texture(strands, UV);
	ALBEDO = COLOR.rgb * tint * mix(0.75, 1.15, t.r);
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = cut;
	ROUGHNESS = 0.6;
	SPECULAR = 0.25;
	// darker at the root: the light does not get far into the hair
	ALBEDO *= mix(0.62, 1.0, smoothstep(0.0, 0.5, tipw));
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float d = clamp((ndl + 0.55) / 1.55, 0.0, 1.0);
	DIFFUSE_LIGHT += d * ATTENUATION * LIGHT_COLOR / PI;
	vec3 H = normalize(LIGHT + VIEW);
	float s = pow(clamp(dot(NORMAL, H), 0.0, 1.0), 22.0) * spec_strength;
	SPECULAR_LIGHT += s * clamp(ndl + 0.3, 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI;
}
