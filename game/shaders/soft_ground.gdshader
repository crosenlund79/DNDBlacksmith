// Soft ground transitions (The Living Realm): meadow patches, damp water banks, tilled field soil and grime at the
// foot of walls. VillageGround builds them as Polygon2D meshes whose vertex ALPHA is an edge factor (1 inside,
// 0 at the outer rim); this shader turns that ramp into a feathered, noise-frayed edge so materials blend into the
// grass the way the roads do (road_ground.gdshader), instead of ending on a hard polygon line.
// `peak` is the patch's opacity; with `use_tex` the mesh's texture is sampled in world space (grass, dirt).
shader_type canvas_item;

uniform float peak = 0.5;
uniform float use_tex = 0.0;
uniform float tex_scale = 256.0;
uniform float fray = 0.55;       // how far the noise pushes the edge in and out
uniform float grain = 60.0;      // noise size in world pixels

varying vec2 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
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

void fragment() {
	float n = vnoise(wpos / grain) * 0.65 + vnoise(wpos / (grain * 0.37) + 7.3) * 0.35;
	float e = smoothstep(0.04, 0.96, COLOR.a + (n - 0.5) * fray);
	vec3 col = COLOR.rgb;
	if (use_tex > 0.5) {
		col *= texture(TEXTURE, wpos / tex_scale).rgb;
	}
	COLOR = vec4(col, peak * e);
}
