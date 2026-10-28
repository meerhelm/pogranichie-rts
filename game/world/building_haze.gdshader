shader_type canvas_item;
// A building faded by CoverFade over the player's unit: its colours go a little toward white,
// so the see-through building reads as a pale veil over the man behind it, not as a hole.

// 0 for none, 1 for white.
uniform float haze = 0.0;

void fragment() {
	// COLOR comes in as the texture times the modulate already.
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), haze);
}
