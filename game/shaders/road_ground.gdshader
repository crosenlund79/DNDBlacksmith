// Roads worn into the ground (iteration 010). Drawn once over the whole map from a low-resolution road mask that
// VillageGround renders at start-up: R = road bed, G = trampled verges / doorsteps / junction wear, B = wheel ruts.
// The mask is blurred and its edges broken up with noise, so the paths feather into the grass instead of sitting on
// it as hard polygons. The square's cobbles fray into packed earth at their rim. Textures are sampled in world space.
shader_type canvas_item;

uniform sampler2D dirt_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D cobble_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D mask_tex : filter_linear;
uniform vec2 world_origin;
uniform vec2 world_size;
uniform vec2 mask_texel;          // 1 / mask size in pixels
uniform vec2 sq_center;
uniform vec2 sq_radius;
uniform float has_square = 1.0;

varying vec2 wpos;

void vertex() {
	wpos = world_origin + UV * world_size;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return s;
}

vec3 mask_at(vec2 uv, float r) {
	// soft disc blur: centre + two rings of taps
	vec3 acc = texture(mask_tex, uv).rgb * 0.16;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7853982;
		vec2 d = vec2(cos(a), sin(a)) * mask_texel;
		acc += texture(mask_tex, uv + d * r * 0.5).rgb * 0.06;
		acc += texture(mask_tex, uv + d * r).rgb * 0.045;
	}
	return acc;
}

void fragment() {
	float n_big = fbm(wpos / 140.0);
	float n_mid = fbm(wpos / 46.0 + 13.0);
	float n_fine = vnoise(wpos / 9.0 + 31.0);
	// wobble the lookup so straight road edges become ragged
	vec2 jit = (vec2(fbm(wpos / 70.0 + 3.0), fbm(wpos / 70.0 + 17.0)) - 0.5) * 7.0 * mask_texel;
	vec3 m = mask_at(UV + jit, 3.2);
	float core = smoothstep(0.30 + 0.22 * (n_mid - 0.5), 0.78, m.r);
	float verge = smoothstep(0.04, 0.75, m.g + m.r * 0.4) * (0.45 + 0.55 * n_big);
	float rut = smoothstep(0.18, 0.75, m.b) * (0.55 + 0.45 * n_mid);

	vec3 dirt = texture(dirt_tex, wpos / 256.0).rgb;
	// trampled verge: thin, patchy earth over the grass, a little darker and greener
	vec3 vcol = mix(dirt * vec3(0.8, 0.72, 0.56), vec3(0.42, 0.36, 0.24), 0.3);
	vec3 col = vcol;
	float a = verge * (0.5 + 0.32 * n_fine);
	// the road bed: packed earth, wheel ruts pressed into it, a worn darker lip where it meets the verge
	vec3 ccol = dirt * vec3(1.04, 1.0, 0.93) * (0.97 + 0.12 * (n_big - 0.5));
	ccol *= 1.0 - 0.4 * rut;
	ccol = mix(ccol, vec3(0.32, 0.24, 0.16), 0.22 * rut * n_fine);
	float lip = clamp(core * (1.0 - core) * 4.0, 0.0, 1.0);
	ccol = mix(ccol, vec3(0.36, 0.27, 0.17), 0.3 * lip);
	col = mix(col, ccol, core);
	a = max(a, core * 0.98);
	// the square: cobbles that fray into packed earth and loose stones at the rim
	if (has_square > 0.5) {
		vec2 q = (wpos - sq_center) / sq_radius;
		float e = length(q) + 0.1 * (n_mid - 0.5) + 0.05 * (n_big - 0.5);
		float sq = 1.0 - smoothstep(0.86, 1.0, e);
		float earth = 1.0 - smoothstep(0.92, 1.12, e);
		vec3 cob = texture(cobble_tex, wpos / 256.0).rgb;
		float cm = sq * smoothstep(0.25, 0.6, n_fine * 0.5 + sq * 0.7);
		col = mix(col, dirt * 0.9, earth * (1.0 - core) * 0.85);
		a = max(a, earth * 0.9);
		col = mix(col, cob, cm);
	}
	COLOR = vec4(col, a);
}
