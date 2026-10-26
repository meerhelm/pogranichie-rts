extends GutTest
## Windows fade in and grow when they open (UiAnim), and close at once.


func test_a_window_fades_in_and_closes_at_once() -> void:
	var help := HelpPanel.create()
	add_child_autofree(help)
	help.open()
	var panel: Control = help.get_node("%Panel")
	assert_lt(help.modulate.a, 0.5, "starts see-through")
	assert_lt(panel.scale.x, 1.0, "and a little smaller")
	await wait_seconds(UiAnim.OPEN_TIME + 0.15)
	assert_eq(help.modulate.a, 1.0, "fully shown")
	assert_eq(panel.scale, Vector2.ONE)
	help.close()
	assert_false(help.visible, "closing is instant")
