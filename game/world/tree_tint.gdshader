shader_type canvas_item;
// A tree's own shade (TreeLayer): brightness and warmth come in the node's modulate, red =
// lighter or darker, green = warmer or cooler, each 0.5 for none; alpha stays the alpha (fading,
// CoverFade). Applied in HSV, so dark pine greens change as much as light birch leaves: hue
// toward yellow or blue (greens only), saturation, and value with a small lift.

// Strength of each shift at full scale (a parameter of 1).
uniform float hue_shift = 0.08;
uniform float sat_shift = 0.3;
uniform float value_scale = 0.45;
uniform float value_lift = 0.08;
// All trees a little darker and greyer, so they sit on the darker PixelLab ground instead of
// glowing over it.
uniform float base_value = 0.86;
uniform float base_sat = 0.85;

varying vec2 shade;

void vertex() {
	shade = COLOR.rg * 2.0 - 1.0;
	COLOR = vec4(1.0, 1.0, 1.0, COLOR.a);
}

vec3 rgb2hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec3 hsv = rgb2hsv(t.rgb);
	float light = shade.x;
	float warm = shade.y;
	// Only greens turn: trunks and yellow leaves keep their hue (no autumn by chance).
	float green = smoothstep(0.16, 0.24, hsv.x) * (1.0 - smoothstep(0.5, 0.6, hsv.x));
	hsv.x = fract(hsv.x - warm * hue_shift * green);
	hsv.y = clamp(hsv.y * (1.0 + warm * sat_shift), 0.0, 1.0);
	hsv.z = clamp(hsv.z * (1.0 + light * value_scale) + light * value_lift * hsv.y, 0.0, 1.0);
	hsv.y *= base_sat;
	hsv.z *= base_value;
	COLOR = vec4(hsv2rgb(hsv), COLOR.a);
}
