extends GutTest
## The mission briefing: every mission has one, it lists the start objectives before the first
## tick and the mission's own ones later, and while it is open before the mission the intro
## cutscene waits.

const MISSIONS: Array[String] = ["gdl_01", "gdl_02", "gdl_03", "gdl_04", "gdl_05", "gdl_06"]

var _db: CatalogDB


func before_all() -> void:
	_db = CatalogDB.load_prototype()


func _briefing(sim: Simulation) -> MissionBriefing:
	var b := MissionBriefing.new()
	add_child_autofree(b)
	b.attach(sim)
	return b


func test_every_mission_has_a_briefing_with_texts_to_translate() -> void:
	for mid in MISSIONS:
		var def := MissionDef.load_id(mid)
		for key: String in ["place", "story", "goal"]:
			assert_false(str(def.briefing.get(key, "")).is_empty(), "%s has %s" % [mid, key])
		assert_false((def.briefing.get("lose", []) as Array).is_empty(), "%s: ways to lose" % mid)
		assert_has(def.texts(), def.briefing["goal"])


func test_before_the_first_tick_it_lists_the_objectives_the_start_sets() -> void:
	var sim := MissionSetup.new_simulation("gdl_01", 1, _db, "normal")
	assert_true(sim.mission.objectives.is_empty())
	var rows := _briefing(sim).objective_rows()
	assert_eq(rows.size(), 1)
	assert_eq(rows[0][0], "• Gather 300 food so the village lives through the summer")
	var page := _briefing(sim).page()
	assert_string_contains(page, "Gather 300 food")
	assert_string_contains(page, "The village burns down")


func test_later_it_shows_the_missions_objectives_with_their_state() -> void:
	var sim := MissionSetup.new_simulation("gdl_03", 1, _db, "normal")
	sim.run(MissionRuntime.CHECK_EVERY + 1)
	var rows := _briefing(sim).objective_rows()
	assert_eq(rows.size(), sim.mission.objectives.size())
	assert_eq(rows[0], MissionPanel.objective_row(sim.mission, sim.mission.objectives[0]))


func test_the_intro_waits_while_the_briefing_is_open() -> void:
	var sim := MissionSetup.new_simulation("gdl_01", 1, _db, "normal")
	var clock := SimClock.new()
	clock.sim = sim
	add_child_autofree(clock)
	var panel := MissionPanel.new()
	add_child_autofree(panel)
	panel.attach(sim, clock, null)
	panel.hold = true
	sim.run(MissionRuntime.CHECK_EVERY + 1)
	panel.poll()
	assert_false(panel.in_cutscene(), "no cutscene while held")
	assert_eq(panel.objective_lines().size(), 2, "the objectives still show")
	panel.release()
	assert_true(panel.in_cutscene(), "the intro starts once released")
	panel.end_cutscene()


func test_open_pauses_and_close_resumes() -> void:
	var sim := MissionSetup.new_simulation("gdl_02", 1, _db, "normal")
	var b := _briefing(sim)
	b.open(true)
	assert_true(get_tree().paused)
	assert_true(b.visible)
	b.close()
	assert_false(get_tree().paused)
	assert_false(b.visible)
