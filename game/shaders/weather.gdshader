// Seasons (canonical v1.6 §11, visual only): the weather's particles and fog over the village. While the smith is
// inside a building the weather stays outside it: `hole` is that building's rectangle in screen UV (x, y, w, h), and
// nothing of the weather is drawn there — the street around it still shows the rain or snow.
shader_type canvas_item;

uniform vec4 hole = vec4(0.0);
uniform float hole_on = 0.0;

void fragment() {
	vec4 c = COLOR;
	if (hole_on > 0.5) {
		vec2 p = SCREEN_UV;
		if (p.x > hole.x && p.y > hole.y && p.x < hole.x + hole.z && p.y < hole.y + hole.w) {
			c.a = 0.0;
		}
	}
	COLOR = c;
}
