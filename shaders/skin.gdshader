// Skin for the GL Compatibility renderer, which has no built-in subsurface scattering.
// Light wraps softly round the form with a warm band at the terminator (light scattered
// under the skin), pores and fine creases come from a tiled micro-normal, the sheen is low
// and varies over the face, and the grazing-angle response follows Fresnel.
shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform sampler2D pores_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rc_tex : hint_default_white, filter_linear_mipmap;     // R: region roughness, G: cavity
uniform bool use_rc = false;
uniform vec3 tint : source_color = vec3(1.0);
uniform float pore_scale = 42.0;
uniform float pore_strength = 0.45;
uniform float wrap = 0.38;
uniform float scatter = 0.09;

void fragment() {
	vec3 a = texture(albedo_tex, UV).rgb * tint;
	// pull the baked albedo's saturation back toward a natural brown
	float l = dot(a, vec3(0.3, 0.59, 0.11));
	a = mix(vec3(l), a, 0.82);
	vec4 rc = texture(rc_tex, UV);
	if (use_rc) {
		a *= mix(1.0, rc.g, 0.8);      // creases and pores hold a little shadow
	}
	ALBEDO = a;
	vec3 n1 = texture(normal_tex, UV).rgb * 2.0 - 1.0;
	vec3 n2 = texture(pores_tex, UV * pore_scale).rgb * 2.0 - 1.0;
	vec3 n = normalize(vec3(n1.xy * 0.8 + n2.xy * pore_strength, max(n1.z, 0.2)));
	NORMAL_MAP = n * 0.5 + 0.5;
	// oilier where the skin is thin and warm (nose, forehead, lips read redder/brighter), drier elsewhere
	float warm = clamp((a.r - a.g) * 3.0, 0.0, 1.0);
	float micro = texture(pores_tex, UV * pore_scale * 0.37).b;
	ROUGHNESS = use_rc ? clamp(rc.r + (micro - 0.5) * 0.1, 0.35, 0.8) : clamp(0.64 - warm * 0.14 + (micro - 0.5) * 0.12, 0.4, 0.78);
	SPECULAR = 0.3;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float d = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
	float band = clamp(1.0 - abs(ndl - 0.08) * 2.6, 0.0, 1.0) * scatter;
	// the shadow side cools slightly; the terminator gets a faint warm bleed, never orange
	vec3 diffuse = vec3(d) * mix(vec3(0.96, 0.92, 0.92), vec3(1.0), d) + vec3(0.85, 0.42, 0.32) * band;
	// shadow maps cut the light off hard; real skin scatters light into the edge of a shadow and
	// fills it slightly. Near the terminator the shadow fades in, and shadows never go fully black.
	float edge = smoothstep(-0.15, 0.3, ndl);
	float sh = mix(1.0, ATTENUATION, edge);
	sh = mix(sh, 1.0, 0.18 * (1.0 - ATTENUATION));
	DIFFUSE_LIGHT += diffuse * sh * LIGHT_COLOR / PI;
	vec3 H = normalize(LIGHT + VIEW);
	float ndh = clamp(dot(NORMAL, H), 0.0, 1.0);
	float r = max(ROUGHNESS, 0.05);
	float pw = clamp(2.0 / (r * r * r * r) - 2.0, 4.0, 160.0);
	float fres = 0.028 + 0.972 * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	float sp = pow(ndh, pw) * (pw + 2.0) / 8.0 * fres;
	SPECULAR_LIGHT += sp * clamp(ndl, 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI * 0.6;
}
