shader_type canvas_item;
// Large soft patches of colour over the ground, so a field of one terrain is not one flat
// colour: here the grass is darker and lusher, there lighter and drier. Value noise in world
// space (a patch is some 10-20 cells), stepped into a few levels with an ordered dither, so the
// ground stays pixel art.

uniform float strength = 1.0;
// World pixels per noise lattice step.
uniform float scale = 520.0;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float bayer4(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[q.y * 4 + q.x]) + 0.5) / 16.0;
}

void fragment() {
	vec4 c = COLOR; // already the texture times the vertex colour
	vec2 px = floor(world);
	// Iso world: squash x so patches look round on the ground.
	vec2 p = vec2(px.x * 0.5, px.y) / scale;
	float n = value_noise(p) * 0.65 + value_noise(p * 2.7 + 17.0) * 0.35;
	// Four levels, dithered between neighbours.
	float level = n * 3.0;
	float step_ = floor(level) + step(bayer4(px), fract(level));
	float t = step_ / 3.0 * 2.0 - 1.0; // -1 lush .. +1 dry
	vec3 lush = c.rgb * vec3(0.80, 0.90, 0.78);
	vec3 dry = c.rgb * vec3(1.15, 1.10, 0.86);
	vec3 rgb = t < 0.0 ? mix(c.rgb, lush, -t) : mix(c.rgb, dry, t);
	COLOR = vec4(mix(c.rgb, rgb, strength), c.a);
}
