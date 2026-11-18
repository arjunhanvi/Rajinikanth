// Eye occlusion: a shell just outside the eyeball, fixed to the head. Multiplies the eye darker
// under the upper lid and in the corners (where the lids and lashes shade it), wherever the eye looks.
shader_type spatial;
render_mode blend_mul, unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform vec3 shade : source_color = vec3(0.32, 0.26, 0.24);

void fragment() {
	ALBEDO = mix(vec3(1.0), shade, COLOR.a);
}
