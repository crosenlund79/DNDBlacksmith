// Light-breeze sway for flowers, bushes and tree crowns. The top of the sprite (UV.y = 0) moves,
// the base stays rooted. Phase comes from the world position, so neighbours never sway in step.
// Seasons (canonical v1.6 §11, visual only): `snow` (0 = none, the unchanged look) lays patchy `snow_col` on the
// lighter, upper parts of the plant — snow in winter, blossom (a pale pink) on flowering trees in spring. The texture
// itself (template or a creator's own art) is never altered.
shader_type canvas_item;

uniform float strength = 2.5;
uniform float speed = 1.4;
uniform float snow = 0.0;
uniform vec3 snow_col = vec3(0.9, 0.93, 0.98);

varying vec2 wp;

// one shared, seamless noise texture (SeasonDressing.noise_texture), sampled at world scale: cheap per pixel
uniform sampler2D noise_tex : repeat_enable, filter_linear;

float vnoise(vec2 p) {
	return texture(noise_tex, p / 16.0).r;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float phase = wp.x * 0.011 + wp.y * 0.017;
	float gust = 0.65 + 0.35 * sin(TIME * 0.31 + wp.x * 0.002);
	float w = 1.0 - UV.y;
	VERTEX.x += sin(TIME * speed + phase) * strength * gust * w * w;
	VERTEX.y += cos(TIME * speed * 1.3 + phase) * strength * 0.25 * gust * w;
}

void fragment() {
	vec4 c = COLOR;
	if (snow > 0.001) {
		float n = vnoise(wp * 0.09) * 0.6 + vnoise(wp * 0.023) * 0.4;
		float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
		float top = 1.0 - smoothstep(0.35, 0.95, UV.y);
		float m = snow * smoothstep(0.32, 0.62, n + snow * 0.25) * (0.45 + 0.55 * smoothstep(0.12, 0.45, lum)) * (0.55 + 0.45 * top);
		c.rgb = mix(c.rgb, snow_col * (0.86 + 0.14 * n), clamp(m, 0.0, 0.88));
	}
	COLOR = c;
}
