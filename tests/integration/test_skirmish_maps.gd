extends GutTest
## The skirmish maps (2026-10-19, SkirmishMaps): each loads, starts both sides with a town
## centre and peasants, and is point-symmetric so both sides get the same ground.

var _db: CatalogDB


func before_all() -> void:
	_db = CatalogDB.load_prototype()


func test_the_list_starts_with_the_prototype_map() -> void:
	var ids := SkirmishMaps.ids()
	assert_gt(ids.size(), 10)
	assert_eq(ids[0], SkirmishSetup.MAP_ID)
	assert_true(SkirmishMaps.has("map_sk_orsha"))
	assert_false(SkirmishMaps.has("map_gdl_08"), "mission maps are not skirmish maps")
	assert_eq(SkirmishMaps.find("no_such_map")["id"], SkirmishSetup.MAP_ID)


func test_every_map_starts_a_skirmish() -> void:
	for id in SkirmishMaps.ids():
		var sim := SkirmishSetup.new_simulation(5, _db, SkirmishSetup.DEFAULT_FACTIONS, id)
		sim.run(2)
		var store := sim.economy.buildings
		for i in 2:
			var player: int = SkirmishSetup.BASES[i][0]
			var at := SkirmishMaps.base(id, i)
			var b := store.occupant[sim.nav.cell_at(at.x, at.y)]
			assert_gt(b, 0, "%s: no town centre of player %d at %s" % [id, player, at])
			if b > 0:
				assert_eq(store.owners[b - 1], player)
		assert_eq(sim.entities.alive_ids.size(), SkirmishSetup.START_PEASANTS * 2, id)


func test_new_maps_are_point_symmetric() -> void:
	for id in SkirmishMaps.ids():
		if id == SkirmishSetup.MAP_ID:
			continue
		var nav := MapText.load_map(id, _db)
		var w := nav.width
		var h := nav.height
		var odd := 0
		for y in h:
			for x in w:
				var c := nav.cell_at(x, y)
				var m := nav.cell_at(w - 1 - x, h - 1 - y)
				if nav.terrain[c] != nav.terrain[m] or nav.objects[c] != nav.objects[m]:
					odd += 1
		assert_eq(odd, 0, "%s: cells that differ from their mirror" % id)
		var a := SkirmishMaps.base(id, 0)
		var b := SkirmishMaps.base(id, 1)
		assert_eq(a + b, Vector2i(w - 4, h - 4), "%s: the bases mirror each other" % id)
