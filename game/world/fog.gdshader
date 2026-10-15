// Fog of war over the isometric map (M6). TEXTURE holds one texel per map cell: 0 unexplored,
// about 0.5 explored, 1 in sight (VisionGrid.shade). Linear filtering softens the edges.
shader_type canvas_item;

uniform vec4 fog_color : source_color = vec4(0.02, 0.02, 0.04, 1.0);
// Darkness over ground that was seen once but is not in sight now.
uniform float explored_alpha = 0.55;

void fragment() {
	float v = texture(TEXTURE, UV).r;
	float a = v < 0.5
		? mix(1.0, explored_alpha, v * 2.0)
		: mix(explored_alpha, 0.0, (v - 0.5) * 2.0);
	COLOR = vec4(fog_color.rgb, fog_color.a * a);
}
