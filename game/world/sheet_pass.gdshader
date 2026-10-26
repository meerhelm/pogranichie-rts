shader_type canvas_item;
// One pass of a rendered sprite sheet drawn over the colour frames: the team mask or the ground
// shadow. Those sheets have the colour sheet's layout, so the frame's UV picks the same spot in
// them. The node's modulate tints it (player colour for the mask, see-through for the shadow).
// No filter hint: the sampler follows the node's texture filter (nearest for pixel art).

uniform sampler2D pass_tex : repeat_disable;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	COLOR = texture(pass_tex, UV) * tint;
}
