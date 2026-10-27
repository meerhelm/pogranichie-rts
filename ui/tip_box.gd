class_name TipBox
extends HBoxContainer
## A top bar item (icon and number) with a rich tooltip: `rich_tip` as BBCode, shown when the
## mouse is over the icon or the number; tooltip_text holds the same as plain text.

var rich_tip := ""


func _make_custom_tooltip(for_text: String) -> Object:
	if rich_tip.is_empty() or for_text.is_empty():
		return null
	return Tips.make_label(rich_tip, IconButton.TIP_WIDTH)
