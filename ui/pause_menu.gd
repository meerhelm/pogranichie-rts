class_name PauseMenu
extends Control
## In-game menu (pause_menu.tscn; Esc with nothing to cancel, or F10): pauses the game;
## resume, settings, back to the main menu, quit. Runs while the scene tree is paused. In a
## mission (M9, can_save) also save the game and load a saved one (the list of saves, newest
## first), and open the mission's briefing again (its goal and objectives).
## In a skirmish (can_resign) also give up; in a network game (keeps_running) the menu does not
## stop the game, which goes on for both players.

signal resumed
signal save_requested
signal load_requested(path: String)
## «How to play» was pressed (the HUD shows the HelpPanel).
signal help_requested
## «Mission» was pressed (the game shows the MissionBriefing over the menu).
signal briefing_requested
## The skirmish hints were turned on or off in the settings.
signal hints_changed
## «Give up» was pressed and confirmed.
signal resign_requested

const MENU_SCENE := "res://ui/main_menu.tscn"
const SCENE := "res://ui/pause_menu.tscn"

## Whether this game can be saved (a mission).
var can_save := false
## Whether the player may give up here (a skirmish, also over the network).
var can_resign := false
## A network game: opening the menu does not pause the game.
var keeps_running := false

var _note := ""
## «Give up»; a second press confirms.
var _resign := Button.new()
var _resign_armed := false

@onready var _title: Label = %Title
@onready var _resume: Button = %Resume
@onready var _briefing: Button = %Briefing
@onready var _settings_button: Button = %SettingsButton
@onready var _help: Button = %Help
@onready var _save: Button = %Save
@onready var _load: Button = %Load
@onready var _saves: VBoxContainer = %Saves
@onready var _to_menu: Button = %ToMenu
@onready var _quit: Button = %Quit
@onready var _menu: VBoxContainer = %Menu
@onready var _settings: SettingsPanel = %Settings


func _ready() -> void:
	_save.pressed.connect(func() -> void: save_requested.emit())
	_load.pressed.connect(_list_saves)
	_resume.pressed.connect(close)
	_briefing.pressed.connect(func() -> void: briefing_requested.emit())
	_help.pressed.connect(func() -> void: help_requested.emit())
	_settings.hints_changed.connect(func() -> void: hints_changed.emit())
	_settings_button.pressed.connect(_show_settings.bind(true))
	_to_menu.pressed.connect(_on_main_menu)
	_quit.pressed.connect(func() -> void: get_tree().quit())
	_settings.closed.connect(_show_settings.bind(false))
	_resign.name = "Resign"  # notr
	_resign.custom_minimum_size = _to_menu.custom_minimum_size
	_resign.pressed.connect(_on_resign)
	_to_menu.add_sibling(_resign)
	_menu.move_child(_resign, _to_menu.get_index())
	_retranslate()


## A new game menu (the scene).
static func create() -> PauseMenu:
	return (load(SCENE) as PackedScene).instantiate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_retranslate()


func _retranslate() -> void:
	var head := tr("Menu: the game goes on") if keeps_running else tr("Paused")
	_title.text = head if _note.is_empty() else _note
	_resign.text = tr("Give up? Press again to confirm") if _resign_armed else tr("Give up")
	_resume.text = tr("Resume")
	_briefing.text = tr("Mission (F2)")
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
	_briefing.visible = can_save
	_save.visible = can_save
	_load.visible = can_save
	_clear_saves()
	_resign_armed = false
	_resign.visible = can_resign
	_retranslate()
	visible = true
	UiAnim.pop_in(self, %Panel as Control)
	if not keeps_running:
		get_tree().paused = true
	_resume.grab_focus.call_deferred()


func close() -> void:
	visible = false
	if not keeps_running:
		get_tree().paused = false
	resumed.emit()


func _on_resign() -> void:
	if not _resign_armed:
		_resign_armed = true
		_retranslate()
		return
	_resign_armed = false
	resign_requested.emit()
	close()


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
		var tick: int = head.get("tick", 0)
		var b := Button.new()
		var when := Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time(path))
		b.text = (
			"%s · %s · %s"
			% [
				tr(str(head.get("title", path.get_file()))),
				UiText.clock(tick),
				when.replace("T", " ")
			]
		)
		b.pressed.connect(func() -> void: load_requested.emit(path))
		_saves.add_child(b)


func _show_settings(on: bool) -> void:
	(_menu.get_parent() as CanvasItem).visible = not on
	_settings.visible = on


func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
