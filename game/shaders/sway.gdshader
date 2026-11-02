// Light-breeze sway for flowers, bushes and tree crowns. The top of the sprite (UV.y = 0) moves,
// the base stays rooted. Phase comes from the world position, so neighbours never sway in step.
shader_type canvas_item;

uniform float strength = 2.5;
uniform float speed = 1.4;

void vertex() {
	vec2 wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float phase = wp.x * 0.011 + wp.y * 0.017;
	float gust = 0.65 + 0.35 * sin(TIME * 0.31 + wp.x * 0.002);
	float w = 1.0 - UV.y;
	VERTEX.x += sin(TIME * speed + phase) * strength * gust * w * w;
	VERTEX.y += cos(TIME * speed * 1.3 + phase) * strength * 0.25 * gust * w;
}
