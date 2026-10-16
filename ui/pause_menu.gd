class_name PauseMenu
extends Control
## In-game menu (Esc with nothing to cancel, or F10): pauses the game; resume, settings, back to
## the main menu, quit. Runs while the scene tree is paused. In a mission (M9, can_save) also
## save the game and load a saved one (the list of saves, newest first).

signal resumed
signal save_requested
signal load_requested(path: String)
## «How to play» was pressed (the HUD shows the HelpPanel).
signal help_requested
## The skirmish hints were turned on or off in the settings.
signal hints_changed

const MENU_SCENE := "res://ui/main_menu.tscn"

## Whether this game can be saved (a mission).
var can_save := false

var _title := Label.new()
var _resume := Button.new()
var _settings_button := Button.new()
var _help := Button.new()
var _save := Button.new()
var _load := Button.new()
var _saves := VBoxContainer.new()
var _to_menu := Button.new()
var _quit := Button.new()
var _menu := VBoxContainer.new()
var _settings := SettingsPanel.new()
var _note := ""


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
	_title.theme_type_variation = &"Title"
	_title.add_theme_font_size_override("font_size", 32)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(_title)
	for b: Button in [_resume, _save, _load, _help, _settings_button, _to_menu, _quit]:
		b.custom_minimum_size = Vector2(300, 44)
		_menu.add_child(b)
	_menu.add_child(_saves)
	_save.pressed.connect(func() -> void: save_requested.emit())
	_load.pressed.connect(_list_saves)
	_resume.pressed.connect(close)
	_help.pressed.connect(func() -> void: help_requested.emit())
	_settings.hints_changed.connect(func() -> void: hints_changed.emit())
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
	_title.text = tr("Paused") if _note.is_empty() else _note
	_resume.text = tr("Resume")
	_save.text = tr("Save game")
	_load.text = tr("Load game")
	_settings_button.text = tr("Settings")
	_help.text = tr("How to play (F1)")
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
	_note = ""
	_save.visible = can_save
	_load.visible = can_save
	_clear_saves()
	_retranslate()
	visible = true
	get_tree().paused = true
	_resume.grab_focus.call_deferred()


func close() -> void:
	visible = false
	get_tree().paused = false
	resumed.emit()


## A line in place of the title, already translated ("Game saved").
func note(text: String) -> void:
	_note = text
	_retranslate()


func _clear_saves() -> void:
	for child in _saves.get_children():
		_saves.remove_child(child)
		child.queue_free()


func _list_saves() -> void:
	_clear_saves()
	var paths := SimSave.list()
	if paths.is_empty():
		var none := Label.new()
		none.text = tr("No saved games")
		_saves.add_child(none)
	for path in paths:
		var head := SimSave.read_header(path)
		var b := Button.new()
		var when := Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time(path))
		b.text = (
			"%s · %s · %s"
			% [
				tr(str(head.get("title", path.get_file()))),
				UiText.clock(int(head.get("tick", 0))),
				when.replace("T", " ")
			]
		)
		b.pressed.connect(func() -> void: load_requested.emit(path))
		_saves.add_child(b)


func _show_settings(on: bool) -> void:
	_menu.get_parent().visible = not on
	_settings.visible = on


func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
