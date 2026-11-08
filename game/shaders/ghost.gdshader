// A friendly ghost: the miniature washed pale blue-white, translucent, with a slow shimmer running up
// through it and a faint sideways drift. Used for hirelings who visit the workshop after their death.
shader_type canvas_item;

uniform float opacity = 0.62;
uniform vec4 tint : source_color = vec4(0.66, 0.82, 1.0, 1.0);

void vertex() {
	VERTEX.x += sin(TIME * 1.7 + VERTEX.y * 0.05) * 1.6;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = dot(c.rgb, vec3(0.3, 0.55, 0.15));
	vec3 pale = mix(c.rgb, vec3(lum), 0.55) * tint.rgb * 1.25 + vec3(0.10, 0.13, 0.18);
	float band = 0.5 + 0.5 * sin(TIME * 2.4 - UV.y * 90.0);
	float a = c.a * opacity * (0.78 + 0.22 * band);
	COLOR = vec4(min(pale + band * 0.06, vec3(1.0)), a);
}
