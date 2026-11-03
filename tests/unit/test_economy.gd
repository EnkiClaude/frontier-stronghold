extends TestCase
## Stockpile, material costs, recipes, storage, recycler, pump (ADR-007).


func _item(sim: GameSim, id: StringName) -> int:
	return sim.reg.item_index(id)


func test_every_resource_has_a_use() -> void:
	var reg := DataRegistry.load_default()
	var used := {}
	for def: BuildingDef in reg.buildings_by_id.values():
		for id in def.material_cost:
			used[StringName(id)] = true
		for r in def.recipes:
			for id in r.inputs:
				used[StringName(id)] = true
		if def.fuel_item != &"":
			used[def.fuel_item] = true
		if def.tower != null and def.tower.ammo_item != &"":
			used[def.tower.ammo_item] = true
	for def in reg.items:
		assert_true(used.has(def.id), "%s is produced but never used" % def.id)


func test_start_stockpile_in_core() -> void:
	var sim := SimHelpers.open_sim()
	assert_eq(sim.stock(_item(sim, &"iron_plate")), 20)
	assert_eq(sim.stock(_item(sim, &"copper_plate")), 10)


func test_material_costs_are_charged_and_refunded() -> void:
	var sim := SimHelpers.open_sim()
	sim.credits = 10000
	var copper := _item(sim, &"copper_plate")
	assert_eq(sim.place(&"icy_blast", Vector2i(30, 4)), "")
	assert_eq(sim.stock(copper), 0, "10 copper plates used")
	assert_eq(sim.place(&"icy_blast", Vector2i(34, 4)), GameSim.ERR_MATERIALS)
	assert_true(sim.missing_materials(sim.reg.buildings_by_id[&"icy_blast"]).contains("10 Copper Plate"))
	SimHelpers.run(sim, sim.rules.undo_window + 1.0)
	sim.sell(sim.building_at(Vector2i(30, 4)).id)
	assert_eq(sim.stock(copper), 8, "85% of materials refunded")


func test_recipe_switch_returns_inputs() -> void:
	var sim := SimHelpers.open_sim()
	sim.place(&"smelter", Vector2i(20, 4))
	SimHelpers.finish_construction(sim)
	var smelter := sim.building_at(Vector2i(20, 4))
	var ore := _item(sim, &"iron_ore")
	smelter.inv_in[ore] = 3
	assert_eq(sim.set_recipe(smelter.id, 1), "")
	assert_eq(smelter.recipe().id, &"copper_plate")
	assert_eq(sim.stock(ore), 3, "buffered iron ore returned to the Core")
	smelter.inv_in[_item(sim, &"copper_ore")] = 2
	SimHelpers.run(sim, 4.0)
	assert_eq(smelter.inv_out.get(_item(sim, &"copper_plate"), 0), 2)


func test_steel_needs_plates_and_coal() -> void:
	var sim := SimHelpers.open_sim()
	sim.place(&"smelter", Vector2i(20, 4))
	SimHelpers.finish_construction(sim)
	var smelter := sim.building_at(Vector2i(20, 4))
	sim.set_recipe(smelter.id, 3)
	var fac := sim.factory
	assert_true(fac.accepts(smelter, _item(sim, &"coal")))
	assert_true(fac.accepts(smelter, _item(sim, &"iron_plate")))
	assert_false(fac.accepts(smelter, _item(sim, &"iron_ore")))
	smelter.inv_in[_item(sim, &"iron_plate")] = 2
	smelter.inv_in[_item(sim, &"coal")] = 1
	SimHelpers.run(sim, 4.5)
	assert_eq(smelter.inv_out.get(_item(sim, &"steel"), 0), 1)


func test_storage_buffers_items_through_arms() -> void:
	var sim := SimHelpers.open_sim()
	# Belt -> arm -> storage -> arm -> belt.
	sim.place(&"conveyor_belt", Vector2i(20, 4), 0)
	sim.place(&"inserter", Vector2i(21, 4), 0)
	sim.place(&"storage", Vector2i(22, 4))
	sim.place(&"inserter", Vector2i(24, 4), 0)
	for x in range(25, 28):
		sim.place(&"conveyor_belt", Vector2i(x, 4), 0)
	SimHelpers.finish_construction(sim)
	var plate := _item(sim, &"iron_plate")
	sim.belts.insert_at_tile(sim.grid.idx(20, 4), plate)
	sim.belts.insert_at_tile(sim.grid.idx(20, 4), plate, 0.1)
	var stock_before := sim.stock(plate)
	SimHelpers.run(sim, 1.2)
	assert_true(sim.stock(plate) >= stock_before, "items in storage count towards the stockpile")
	SimHelpers.run(sim, 6.0)
	assert_eq(sim.belts.item_count(), 2, "both plates passed through storage onto the far belt")


func test_recycler_pays_item_value() -> void:
	var sim := SimHelpers.open_sim()
	sim.place(&"conveyor_belt", Vector2i(20, 4), 0)
	sim.place(&"inserter", Vector2i(21, 4), 0)
	sim.place(&"recycler", Vector2i(22, 4))
	SimHelpers.finish_construction(sim)
	var credits := sim.credits
	sim.belts.insert_at_tile(sim.grid.idx(20, 4), _item(sim, &"steel"))
	SimHelpers.run(sim, 3.0)
	assert_eq(sim.credits, credits + 9, "steel is worth 9 credits")
	assert_eq(sim.factory.recycled_total, 9)


func test_pump_needs_water_and_pumps() -> void:
	var sim := SimHelpers.open_sim()
	assert_eq(sim.place(&"pump", Vector2i(20, 4), 0), GameSim.ERR_NEEDS_WATER)
	var water := sim.reg.terrain_code(&"water")
	sim.grid.set_terrain(19, 4, water)
	sim.path.terrain_changed(sim.grid.idx(19, 4))
	assert_eq(sim.place(&"pump", Vector2i(20, 4), 0), "")
	for x in range(22, 25):
		sim.place(&"conveyor_belt", Vector2i(x, 4), 0)
	SimHelpers.run(sim, 8.0)
	assert_true(sim.belts.item_count() >= 4)
	assert_eq(sim.belts.lines[0].items[0], _item(sim, &"water"))


func test_excavation_yields_stone() -> void:
	var sim := SimHelpers.open_sim()
	sim.grid.set_terrain(30, 5, sim.reg.terrain_code(&"rock"))
	sim.path.terrain_changed(sim.grid.idx(30, 5))
	sim.excavate(Vector2i(30, 5))
	SimHelpers.run(sim, sim.rules.excavate_time + 0.2)
	assert_eq(sim.stock(_item(sim, &"stone")), sim.rules.excavate_stone)


func test_toolbar_tabs_cover_all_buildings() -> void:
	var reg := DataRegistry.load_default()
	var total := 0
	for cat in DataRegistry.CATEGORIES:
		var defs := reg.toolbar_buildings(cat)
		assert_true(defs.size() >= 2, "tab %s" % cat)
		assert_true(defs.size() <= 9, "tab %s fits hotkeys 1-9" % cat)
		total += defs.size()
	var auto_only := 0
	for def: BuildingDef in reg.buildings_by_id.values():
		if def.kind == &"core" or def.kind == &"tunnel":
			auto_only += 1
	assert_eq(total, reg.buildings_by_id.size() - auto_only, "every building except Core/tunnels is on the toolbar")
