class_name PauseMenu
extends Control
## In-game menu (Esc with nothing to cancel, or F10): pauses the game; resume, settings, back to
## the main menu, quit. Runs while the scene tree is paused.

signal resumed

const MENU_SCENE := "res://ui/main_menu.tscn"

var _title := Label.new()
var _resume := Button.new()
var _settings_button := Button.new()
var _to_menu := Button.new()
var _quit := Button.new()
var _menu := VBoxContainer.new()
var _settings := SettingsPanel.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var stack := VBoxContainer.new()
	center.add_child(stack)
	var panel := PanelContainer.new()
	panel.add_child(_menu)
	stack.add_child(panel)
	_menu.add_theme_constant_override("separation", 10)
	_title.add_theme_font_size_override("font_size", 32)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(_title)
	for b: Button in [_resume, _settings_button, _to_menu, _quit]:
		b.custom_minimum_size = Vector2(300, 44)
		_menu.add_child(b)
	_resume.pressed.connect(close)
	_settings_button.pressed.connect(_show_settings.bind(true))
	_to_menu.pressed.connect(_on_main_menu)
	_quit.pressed.connect(func() -> void: get_tree().quit())
	_settings.visible = false
	_settings.closed.connect(_show_settings.bind(false))
	stack.add_child(_settings)
	visible = false
	_retranslate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_retranslate()


func _retranslate() -> void:
	_title.text = tr("Paused")
	_resume.text = tr("Resume")
	_settings_button.text = tr("Settings")
	_to_menu.text = tr("Main menu")
	_quit.text = tr("Quit")


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if visible and key != null and key.pressed and not key.echo:
		if key.physical_keycode == KEY_ESCAPE or key.physical_keycode == KEY_F10:
			if _settings.visible:
				_show_settings(false)
			else:
				close()
			get_viewport().set_input_as_handled()


func open() -> void:
	_show_settings(false)
	visible = true
	get_tree().paused = true
	_resume.grab_focus.call_deferred()


func close() -> void:
	visible = false
	get_tree().paused = false
	resumed.emit()


func _show_settings(on: bool) -> void:
	_menu.get_parent().visible = not on
	_settings.visible = on


func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
