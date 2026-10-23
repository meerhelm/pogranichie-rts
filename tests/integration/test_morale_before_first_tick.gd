extends GutTest
## Regression: the map draws every unit (wavering, the card's morale) as soon as the scene is
## ready, before the first sim tick, and the mission briefing keeps the game paused there. The
## Crown's tactics got the unit defs only in the first combat step, so asking for morale then
## read past the end of an empty list (crash at the start of «ВКЛ 1» in the editor).

const MISSIONS: Array[String] = [
	"gdl_01",
	"gdl_02",
	"gdl_03",
	"gdl_04",
	"gdl_05",
	"gdl_06",
	"gdl_07",
	"gdl_08",
	"crown_01",
	"crown_02",
	"crown_03",
	"crown_04",
	"crown_05",
	"crown_06",
]

var _db: CatalogDB


func before_all() -> void:
	_db = CatalogDB.load_prototype()


func test_morale_of_every_unit_before_the_first_tick() -> void:
	for id: String in MISSIONS:
		var sim := MissionSetup.new_simulation(id, 1, _db, "normal")
		assert_not_null(sim, id)
		if sim == null:
			continue
		assert_eq(sim.tick, 0, id)
		var seen := 0
		for uid: int in sim.entities.alive_ids:
			var slot := uid - 1
			var morale := sim.combat.effective_morale(slot)
			assert_true(morale >= 0, "%s unit %d" % [id, uid])
			sim.combat.wavering(slot)
			seen += 1
		assert_gt(seen, 0, id)
	assert_engine_error_count(0)


func test_skirmish_morale_before_the_first_tick() -> void:
	var sim := SkirmishSetup.new_simulation(1, _db)
	for uid: int in sim.entities.alive_ids:
		sim.combat.effective_morale(uid - 1)
	assert_engine_error_count(0)
