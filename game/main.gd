extends Node2D
## Skirmish scene: the skirmish map where GDL and Order units move and fight (M3, M4), and from
## M5 each side's town centre and peasants to gather, build and train. From M6 the local player
## sees through the fog of war, with the HUD, minimap and game menu; the main menu opens it.
## From M7 the map has places of power to take and shrines to lay, and casters cast spells.
## From M8 it is a real skirmish: each side starts with a town centre and peasants
## (SkirmishSetup), the second side is played by the AI (SkirmishAi, at
## GameSettings.ai_difficulty), and when one side wins the end screen shows the statistics.
## The menu picks both factions (GameSettings.player_faction, enemy_faction): GDL, the Crown or
## the Order, and the map (GameSettings.skirmish_map, one of SkirmishMaps).
## Left click or drag selects, right click moves or attacks, Ctrl+right click attack-moves;
## Q / E / R pick line, column or wedge; Z / X / C set the stance; with peasants, right click
## gathers or builds and B places a building; a selected building queues with Z X C V B N M
## (see PlayerInput).
## From M9 the same scene plays a campaign mission (GameSettings.mission_id, or a save from
## GameSettings.load_path): no AI, the mission's script (MissionRuntime) runs the Order; the
## MissionPanel shows objectives, hints, dialogues and cutscenes; the game menu saves and loads.
## A new mission opens with its briefing (MissionBriefing: story, goal, objectives), which F2 and
## the game menu show again.

const SEED := 1
const PLAYER := 1
## The side the AI plays (M8).
const AI_PLAYER := 2

var sim: Simulation
## The computer player (null if there is no profile for its faction and difficulty).
var ai: SkirmishAi
var end_screen := EndScreen.new()
## The mission's interface (null in a skirmish).
var mission_panel: MissionPanel
## The mission's briefing (null in a skirmish).
var briefing: MissionBriefing
## Trees on forest cells, among the units.
var trees := TreeLayer.new()

var _ended := false

@onready var _clock: SimClock = $SimClock
@onready var _map: MapView = $World/Map
@onready var _buildings: BuildingLayer = $World/Buildings
@onready var _magic: MagicLayer = $World/Magic
@onready var _units: UnitLayer = $World/Units
@onready var _shots: ShotLayer = $World/Shots
@onready var _camera: RtsCamera = $Camera
@onready var _fog: FogLayer = $World/Fog
@onready var _input: PlayerInput = $UI/PlayerInput
@onready var _hud: Hud = $UI/Hud


func _ready() -> void:
	GameSettings.ensure_loaded()
	var game_name: String = ProjectSettings.get_setting("application/config/name")
	var version: String = ProjectSettings.get_setting("application/config/version")
	var label: Label = $UI/VersionLabel
	label.text = "%s %s" % [game_name, version]
	print("Main scene ready: ", label.text)

	var db := CatalogDB.load_prototype()
	sim = _new_world(db)
	var grid := sim.nav
	if sim.mission == null:
		var faction := SkirmishSetup.faction_of(AI_PLAYER, _factions())
		var profile := SkirmishSetup.ai_profile(faction, GameSettings.ai_difficulty)
		if profile != null:
			ai = SkirmishAi.new()
			ai.setup(sim, AI_PLAYER, profile, SEED)
			add_child(ai)
	_map.build(grid)
	_clock.sim = sim
	_units.local_player = PLAYER
	_units.attach(sim, _clock)
	_shots.attach(sim, _clock, _units)
	_buildings.local_player = PLAYER
	_buildings.depth_layer = _units
	_buildings.attach(sim, _clock)
	trees.local_player = PLAYER
	add_child(trees)
	trees.attach(sim, _clock, _units)
	_magic.local_player = PLAYER
	_magic.attach(sim, _clock)
	if StealthLayer.wanted(sim):
		var stealth := StealthLayer.new()
		stealth.local_player = PLAYER
		_magic.add_sibling(stealth)
		stealth.attach(sim, _clock, _units)
	if SiegeLayer.wanted(sim):
		var siege := SiegeLayer.new()
		siege.local_player = PLAYER
		_magic.add_sibling(siege)
		siege.attach(sim, _clock, _units)
	if BattleLayer.wanted(sim):
		var battle := BattleLayer.new()
		battle.local_player = PLAYER
		_magic.add_sibling(battle)
		battle.attach(sim, _clock)
	if ChojniceLayer.wanted(sim):
		var chojnice := ChojniceLayer.new()
		chojnice.local_player = PLAYER
		_shots.add_sibling(chojnice)
		chojnice.attach(sim, _clock)
	if SwiecinoLayer.wanted(sim):
		var swiecino := SwiecinoLayer.new()
		swiecino.local_player = PLAYER
		_shots.add_sibling(swiecino)
		swiecino.attach(sim, _clock)
	if SilverLayer.wanted(sim):
		var silver := SilverLayer.new()
		silver.local_player = PLAYER
		_shots.add_sibling(silver)
		silver.attach(sim, _clock)
	_fog.attach(sim, _clock, PLAYER)
	_camera.bounds = Iso.map_rect(grid.width, grid.height)
	var home := SkirmishMaps.base(GameSettings.skirmish_map, 0) + Vector2i(2, 4)
	if sim.mission != null:
		home = sim.mission.def.camera
	_camera.look_at_point(Iso.cell_to_screen(Vector2(home)))
	_apply_camera_settings()
	_input.attach(sim, _units, _camera, _buildings)
	_hud.attach(sim, _clock, _input, _camera, PLAYER)
	_hud.menu.resumed.connect(_apply_camera_settings)
	_clock.advanced.connect(func(t: int, _s: int) -> void: _on_ticked(t))
	$UI.add_child(end_screen)
	if sim.mission != null:
		mission_panel = MissionPanel.new()
		$UI.add_child(mission_panel)
		mission_panel.attach(sim, _clock, _camera)
		_hud.menu.can_save = true
		_hud.menu.save_requested.connect(_save_game)
		_hud.menu.load_requested.connect(_load_game)
		briefing = MissionBriefing.new()
		$UI.add_child(briefing)
		briefing.attach(sim)
		_hud.menu.briefing_requested.connect(briefing.open)
		if sim.tick == 0:
			# A new mission waits for the player to read its briefing.
			mission_panel.hold = true
			briefing.closed.connect(mission_panel.release, CONNECT_ONE_SHOT)
			briefing.open(true)
			_answer_marks()
		mission_panel.poll()
	if ai != null:
		# Thinks before the step its orders are for, as a player at the keyboard would.
		_clock.ticked.connect(func(_t: int) -> void: ai.issue())
		ai.issue()


## Корона 2 on: what the campaign remembers of earlier missions (setup.marks) is told to the
## mission as answers to the questions "mark:<mission>:<flag>", so replays carry it.
func _answer_marks() -> void:
	for mark: Array in sim.mission.def.setup.get("marks", []):
		if CampaignProgress.has_mark(str(mark[0]), str(mark[1])):
			var q := StringName("mark:%s:%s" % [mark[0], mark[1]])
			sim.enqueue(SimCommand.choose(sim.tick, PLAYER, q, 0))


## A new skirmish, a new mission or a loaded save, as GameSettings says.
func _new_world(db: CatalogDB) -> Simulation:
	if not GameSettings.load_path.is_empty():
		var path := GameSettings.load_path
		GameSettings.load_path = ""
		var loaded := SimSave.load_file(path, db)
		if loaded != null:
			return loaded
		push_warning("cannot load %s, starting the mission anew" % path)
	if not GameSettings.mission_id.is_empty():
		var started := MissionSetup.new_simulation(
			GameSettings.mission_id, SEED, db, GameSettings.mission_difficulty
		)
		if started != null:
			return started
	return SkirmishSetup.new_simulation(SEED, db, _factions(), GameSettings.skirmish_map)


## The skirmish sides as the menu set them: the player's faction, then the AI's.
static func _factions() -> Array[StringName]:
	return [GameSettings.player_faction, GameSettings.enemy_faction]


func _save_game() -> void:
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := SimSave.DIR.path_join("%s_%s.save" % [sim.mission.def.id, stamp])
	var err := SimSave.save(sim, path)
	_hud.menu.note(tr("Game saved") if err == OK else tr("Could not save the game"))


func _load_game(path: String) -> void:
	GameSettings.load_path = path
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_ticked(_tick: int) -> void:
	_input.sim_ticked_cleanup()
	_map.refresh()
	if sim.victory.is_over() and not _ended:
		_ended = true
		if sim.mission != null and sim.victory.winner == PLAYER:
			var kept := PackedStringArray()
			for flag in sim.mission.def.carry:
				if sim.mission.flags.has(flag):
					kept.append(flag)
			CampaignProgress.mark_won(sim.mission.def.id, kept)
		end_screen.open(sim, PLAYER)


func _apply_camera_settings() -> void:
	_camera.edge_scroll = GameSettings.edge_scroll
	_camera.edge_speed = GameSettings.edge_speed_factor()
