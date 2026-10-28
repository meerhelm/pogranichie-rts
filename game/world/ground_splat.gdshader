shader_type canvas_item;
// The ground of the whole map in one pass. For every screen pixel: the point of the square grid
// under it, rounded to the ground textures' pixel (32 per cell, as the tiles were), then which
// ground shows there. Each ground's share around the point is the bilinear blend of the four
// nearest cell centres; the highest ground (MapView.LAYERING) whose share reaches `reach` shows.
// So borders between grounds run as smooth slopes and curves through the cells instead of
// stepping along their edges, a lone cell becomes a rounded patch, and a one-cell road stays
// whole (a higher ground needs less than half to show); noise and an ordered dither fray the
// border into pixel art. Then the large soft colour patches of ground_tint.gdshader.

// Layer index (MapView.LAYERING) of each cell, one texel per cell, value / 255.
uniform sampler2D terrain_map : filter_nearest;
// The top-down texture of each ground in LAYERING order, 8 x 8 cells (256 px) per repeat.
uniform sampler2DArray grounds : filter_nearest, repeat_enable;
uniform vec2 map_size;
// Share a higher ground needs to cover a point: 0.5 puts the border midway between cell
// centres; lower lets it bulge a little into the lower ground.
uniform float reach = 0.40;
// How far the noise pushes the border back and forth (in share).
uniform float fray = 0.22;
// Layers (MapView.LAYERING) the shader treats specially: water and below is open water, the
// road gets an earth bank where it crosses water, reeds are taken from the bog's texture.
uniform int water_top = 1;
uniform int road_layer = 12;
uniform int reed_layer = 4;
// Width of a road's bank into the water, and of the shore where reeds grow (in share).
uniform float bank = 0.36;
uniform float shore = 0.5;
uniform float tint_strength = 1.0;
uniform float tint_scale = 520.0;

const float CELL_PX = 32.0;
const float TEX = 256.0;

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

int layer_at(ivec2 c) {
	c = clamp(c, ivec2(0), ivec2(map_size) - 1);
	return int(texelFetch(terrain_map, c, 0).r * 255.0 + 0.5);
}

void fragment() {
	vec2 px = floor(world) + 0.5;
	// Screen -> cell (Iso.screen_to_cell), then onto the texture's pixel grid.
	float a = px.x / 32.0;
	float b = px.y / 16.0;
	vec2 cell = vec2((a + b) * 0.5, (b - a) * 0.5);
	vec2 texel = floor(cell * CELL_PX);
	vec2 p = (texel + 0.5) / CELL_PX;
	if (p.x < 0.0 || p.y < 0.0 || p.x >= map_size.x || p.y >= map_size.y) {
		discard;
	}
	int own = layer_at(ivec2(floor(p)));
	vec2 f = p - 0.5;
	ivec2 i0 = ivec2(floor(f));
	vec2 w = fract(f);
	int l00 = layer_at(i0);
	int l10 = layer_at(i0 + ivec2(1, 0));
	int l01 = layer_at(i0 + ivec2(0, 1));
	int l11 = layer_at(i0 + ivec2(1, 1));
	float w00 = (1.0 - w.x) * (1.0 - w.y);
	float w10 = w.x * (1.0 - w.y);
	float w01 = (1.0 - w.x) * w.y;
	float w11 = w.x * w.y;
	float n = (value_noise(texel / 7.0) * 0.7 + value_noise(texel / 2.5 + 31.0) * 0.3 - 0.5) * 2.0 * fray
		+ (bayer4(texel) - 0.5) * 0.12;
	// The highest ground whose share reaches; where none does (a point between cells of three
	// or four grounds), the ground with the largest share.
	int shown = -1;
	int most = own;
	float most_share = -1.0;
	int cand[4] = int[](l00, l10, l01, l11);
	for (int k = 0; k < 4; k++) {
		int l = cand[k];
		float share = (l00 == l ? w00 : 0.0) + (l10 == l ? w10 : 0.0) + (l01 == l ? w01 : 0.0)
			+ (l11 == l ? w11 : 0.0);
		if (share + n > reach && l > shown) {
			shown = l;
		}
		if (share > most_share) {
			most_share = share;
			most = l;
		}
	}
	if (shown < 0) {
		shown = most;
	}
	ivec2 t = ivec2(mod(texel, TEX));
	vec3 rgb = texelFetch(grounds, ivec3(t, shown), 0).rgb;
	float road = (l00 == road_layer ? w00 : 0.0) + (l10 == road_layer ? w10 : 0.0)
		+ (l01 == road_layer ? w01 : 0.0) + (l11 == road_layer ? w11 : 0.0);
	float wet = (l00 <= water_top ? w00 : 0.0) + (l10 <= water_top ? w10 : 0.0)
		+ (l01 <= water_top ? w01 : 0.0) + (l11 <= water_top ? w11 : 0.0);
	if (shown <= water_top) {
		vec3 earth = texelFetch(grounds, ivec3(t, road_layer), 0).rgb;
		float edge = road + n * 0.4;
		if (road > 0.0 && edge > reach - bank) {
			// The road's causeway: an earth bank sloping into the water, lit on top, dark and wet
			// at the waterline.
			float down = clamp((reach - edge) / bank, 0.0, 1.0);
			vec3 top = earth * vec3(0.86, 0.80, 0.70);
			vec3 foot = earth * vec3(0.48, 0.46, 0.42);
			rgb = mix(top, foot, step(bayer4(texel), down * 1.2));
			if (down > 0.82) {
				rgb = vec3(0.17, 0.15, 0.12);
			}
		} else {
			// Sparse reeds near a shore: short upright strokes of green and straw in screen
			// pixels, in clumps, thicker by the land.
			float land = 1.0 - wet;
			float dense = smoothstep(0.0, shore, land) * 0.6;
			vec2 sp = floor(world);
			vec2 stalk = vec2(sp.x, floor(sp.y / 4.0));
			float clump = value_noise(sp / 7.0 + 53.0);
			if (land > 0.0 && clump > 0.58 && hash(stalk) < dense * (clump - 0.4) * 2.0) {
				float h = mod(sp.y, 4.0);
				rgb = h < 1.0 ? vec3(0.82, 0.76, 0.42) : (h < 3.0 ? vec3(0.45, 0.58, 0.24) : vec3(0.22, 0.33, 0.16));
			}
		}
	} else if (shown == road_layer && wet > 0.0) {
		// The causeway's top edge: a darker shoulder along the water.
		if (road + n * 0.4 < reach + bank * 0.5) {
			rgb *= 0.84;
		}
	}
	// Large soft patches: lusher here, drier there (as ground_tint.gdshader).
	vec2 wp = floor(world);
	vec2 q = vec2(wp.x * 0.5, wp.y) / tint_scale;
	float tn = value_noise(q) * 0.65 + value_noise(q * 2.7 + 17.0) * 0.35;
	float level = tn * 3.0;
	float step_ = floor(level) + step(bayer4(wp), fract(level));
	float tt = step_ / 3.0 * 2.0 - 1.0;
	vec3 lush = rgb * vec3(0.80, 0.90, 0.78);
	vec3 dry = rgb * vec3(1.15, 1.10, 0.86);
	vec3 tinted = tt < 0.0 ? mix(rgb, lush, -tt) : mix(rgb, dry, tt);
	COLOR = vec4(mix(rgb, tinted, tint_strength), 1.0);
}
