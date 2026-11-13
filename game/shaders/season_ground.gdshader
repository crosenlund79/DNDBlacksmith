// Seasons (canonical v1.6 §11, visual only): one overlay over the village ground (grass, roads, plazas) under the
// buildings' floors. `snow` 0…1 is the winter cover (patchy as it comes and as it thaws, nearly whole at 1); `wash`
// is a soft seasonal tint in patches (rgb, a = strength): autumn's fallen leaves and dry gold, spring's fresh green.
// Purely an overlay: the ground textures (templates or a creator's own art) are untouched.
shader_type canvas_item;

uniform float snow = 0.0;
uniform vec4 wash = vec4(0.0);

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
	float n = vnoise(wp * 0.004) * 0.5 + vnoise(wp * 0.011) * 0.3 + vnoise(wp * 0.04) * 0.2;
	float fine = vnoise(wp * 0.12);
	// snow: grows from the lowest-noise hollows outwards; at snow = 1 nearly everything is white
	float lim = 1.08 - snow * 1.1;
	float a_snow = snow > 0.001 ? smoothstep(lim, lim + 0.16, 1.0 - n + fine * 0.08) * 0.86 : 0.0;
	vec3 snowc = mix(vec3(0.76, 0.81, 0.89), vec3(0.9, 0.92, 0.96), fine * 0.6 + n * 0.4);
	float a_wash = wash.a * smoothstep(0.3, 0.7, n + (fine - 0.5) * 0.3);
	float a = a_snow + a_wash * (1.0 - a_snow);
	vec3 col = a > 0.0001 ? (snowc * a_snow + wash.rgb * a_wash * (1.0 - a_snow)) / a : vec3(1.0);
	COLOR = vec4(col, a);
}
