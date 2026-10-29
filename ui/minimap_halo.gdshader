// Red glow along the inner edge of the minimap while the player is under attack (MinimapAlerts).
// `size` is the control's size in pixels, `strength` 0..1 follows the blinks.
shader_type canvas_item;

uniform vec2 size = vec2(320.0, 180.0);
uniform float strength = 0.0;
uniform vec4 glow : source_color = vec4(1.0, 0.1, 0.05, 1.0);
uniform float width = 22.0;

void fragment() {
	vec2 px = UV * size;
	float d = min(min(px.x, size.x - px.x), min(px.y, size.y - px.y));
	float a = 1.0 - smoothstep(0.0, width, d);
	COLOR = vec4(glow.rgb, glow.a * a * a * strength * 0.8);
}
