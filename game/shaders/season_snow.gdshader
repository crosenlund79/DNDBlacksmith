// Seasons (canonical v1.6 §11, visual only): patchy snow on a roof (or any sprite) in winter. `snow` 0 = the
// unchanged look. Works on top of whatever texture the sprite has — a template or a creator's own art — and keeps the
// sprite's modulate (a roof still fades when the smith steps inside).
shader_type canvas_item;

uniform float snow = 0.0;

varying vec2 wp;

// one shared, seamless noise texture (SeasonDressing.noise_texture), sampled at world scale: cheap per pixel
uniform sampler2D noise_tex : repeat_enable, filter_linear;

float vnoise(vec2 p) {
	return texture(noise_tex, p / 16.0).r;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = COLOR;
	if (snow > 0.001) {
		float n = vnoise(wp * 0.05) * 0.55 + vnoise(wp * 0.013) * 0.45;
		float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
		float m = snow * smoothstep(0.22, 0.5, n + snow * 0.3) * (0.7 + 0.3 * smoothstep(0.1, 0.4, lum));
		c.rgb = mix(c.rgb, vec3(0.91, 0.93, 0.98) * (0.84 + 0.16 * n), clamp(m, 0.0, 0.9));
	}
	COLOR = c;
}
