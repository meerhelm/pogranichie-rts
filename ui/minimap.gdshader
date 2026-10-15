// Minimap ground (M6): terrain colours darkened by the local player's fog of war. `fog` has one
// texel per map cell like the terrain texture (VisionGrid.shade: 0, ~0.5, 1).
shader_type canvas_item;

uniform sampler2D fog : filter_linear;

void fragment() {
	vec4 ground = texture(TEXTURE, UV);
	float v = texture(fog, UV).r;
	float light = v < 0.5 ? v : mix(0.5, 1.0, (v - 0.5) * 2.0);
	COLOR = vec4(ground.rgb * light, ground.a);
}
