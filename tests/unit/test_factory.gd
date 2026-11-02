extends TestCase


func _ore(sim: GameSim, x: int, y: int) -> void:
	var ore := sim.reg.terrain_code(&"ore_iron")
	for dx in 2:
		for dy in 2:
			sim.grid.set_terrain(x + dx, y + dy, ore)


func test_drill_needs_ore() -> void:
	var sim := SimHelpers.open_sim()
	assert_eq(sim.place(&"mining_drill", Vector2i(20, 4)), GameSim.ERR_NEEDS_ORE)
	_ore(sim, 20, 4)
	assert_eq(sim.place(&"mining_drill", Vector2i(20, 4)), "")


func test_logistics_do_not_block_enemies() -> void:
	var sim := SimHelpers.open_sim()
	sim.place(&"conveyor_belt", Vector2i(20, 4))
	sim.place(&"smelter", Vector2i(22, 4))
	SimHelpers.finish_construction(sim)
	assert_eq(sim.path.passable[sim.grid.idx(20, 4)], 1)
	assert_eq(sim.path.passable[sim.grid.idx(22, 4)], 1)


func test_drill_outputs_onto_belt() -> void:
	var sim := SimHelpers.open_sim()
	_ore(sim, 20, 4)
	sim.place(&"mining_drill", Vector2i(20, 4), 0)
	for x in range(22, 26):
		sim.place(&"conveyor_belt", Vector2i(x, 4), 0)
	SimHelpers.run(sim, 12.0)
	var n := sim.belts.item_count()
	assert_true(n >= 8, "drill produced %d items onto the belt" % n)
	assert_eq(sim.belts.lines[0].items[0], sim.reg.item_index(&"iron_ore"))


func test_drill_stalls_when_output_blocked() -> void:
	var sim := SimHelpers.open_sim()
	_ore(sim, 20, 4)
	sim.place(&"mining_drill", Vector2i(20, 4), 0)
	sim.place(&"conveyor_belt", Vector2i(22, 4), 0)
	SimHelpers.run(sim, 20.0)
	assert_true(sim.belts.item_count() <= 4, "1 tile holds at most 4 items")
	var drill := sim.building_at(Vector2i(20, 4))
	assert_true(drill.held >= 0, "drill holds its item while blocked")


func test_inserter_feeds_smelter_and_smelter_crafts() -> void:
	var sim := SimHelpers.open_sim()
	for x in range(20, 24):
		sim.place(&"conveyor_belt", Vector2i(x, 4), 0)
	sim.place(&"inserter", Vector2i(24, 4), 0)
	sim.place(&"smelter", Vector2i(25, 4))
	SimHelpers.finish_construction(sim)
	var ore := sim.reg.item_index(&"iron_ore")
	for i in 3:
		sim.belts.insert_at_tile(sim.grid.idx(20 + i, 4), ore)
	SimHelpers.run(sim, 12.0)
	var smelter := sim.building_at(Vector2i(25, 4))
	assert_eq(smelter.inv_out.get(sim.reg.item_index(&"iron_plate"), 0), 3)
	assert_eq(sim.belts.item_count(), 0)


func test_inserter_ignores_items_target_cannot_use() -> void:
	var sim := SimHelpers.open_sim()
	sim.place(&"conveyor_belt", Vector2i(20, 4), 0)
	sim.place(&"inserter", Vector2i(21, 4), 0)
	sim.place(&"smelter", Vector2i(22, 4))
	SimHelpers.finish_construction(sim)
	sim.belts.insert_at_tile(sim.grid.idx(20, 4), sim.reg.item_index(&"coal"))
	SimHelpers.run(sim, 3.0)
	assert_eq(sim.belts.item_count(), 1, "coal is not a smelter input")


func test_tower_without_ammo_does_not_fire() -> void:
	var sim := SimHelpers.open_sim(40, 12)
	sim.place(&"chain_gun", Vector2i(20, 2))
	SimHelpers.finish_construction(sim)
	var tower := sim.building_at(Vector2i(20, 2))
	assert_eq(tower.ammo, 50, "starter ammo")
	tower.ammo = 0
	SimHelpers.spawn_at(sim, &"swarm", 23, 6)
	SimHelpers.run(sim, 2.0)
	assert_eq(sim.drain_shots().size(), 0)
	tower.ammo = 3
	SimHelpers.run(sim, 2.0)
	assert_eq(sim.drain_shots().size(), 3, "fires exactly the loaded rounds")
	assert_eq(tower.ammo, 0)


func test_full_supply_chain_loads_tower() -> void:
	var sim := SimHelpers.open_sim()
	var tower := SupplyScenario.build_chain(sim, Vector2i(14, 4))
	assert_true(tower != null)
	SimHelpers.finish_construction(sim)
	tower.ammo = 0
	SimHelpers.run(sim, 15.0)
	assert_true(tower.ammo >= 50, "tower reloaded to %d rounds" % tower.ammo)
	assert_true(tower.ammo <= tower.def.tower.magazine_size)


func test_relocated_crafter_keeps_inventory() -> void:
	var sim := SimHelpers.open_sim()
	sim.place(&"smelter", Vector2i(20, 4))
	SimHelpers.finish_construction(sim)
	var smelter := sim.building_at(Vector2i(20, 4))
	smelter.inv_out[sim.reg.item_index(&"iron_plate")] = 5
	assert_eq(sim.relocate(smelter.id, Vector2i(30, 4)), "")
	SimHelpers.run(sim, 4.0)
	assert_true(smelter.is_active())
	assert_eq(smelter.inv_out[sim.reg.item_index(&"iron_plate")], 5)
	assert_true(sim.factory.crafters.has(smelter))


func test_selling_belt_unregisters_it() -> void:
	var sim := SimHelpers.open_sim()
	sim.place(&"conveyor_belt", Vector2i(20, 4), 0)
	SimHelpers.finish_construction(sim)
	assert_true(sim.belts.has_belt(sim.grid.idx(20, 4)))
	sim.sell(sim.building_at(Vector2i(20, 4)).id)
	assert_false(sim.belts.has_belt(sim.grid.idx(20, 4)))


func test_drill_outputs_to_either_front_tile() -> void:
	var sim := SimHelpers.open_sim()
	_ore(sim, 20, 4)
	sim.place(&"mining_drill", Vector2i(20, 4), 0)
	# Belt only in front of the drill's SECOND row (y = 5), heading east.
	for x in range(22, 26):
		sim.place(&"conveyor_belt", Vector2i(x, 5), 0)
	SimHelpers.run(sim, 8.0)
	assert_true(sim.belts.item_count() >= 5, "drill must use the lower front tile too")


func test_arm_feeds_turret_while_belt_keeps_going() -> void:
	var sim := SimHelpers.open_sim()
	# Belt runs east along y=4 past a turret at (24..25, 6..7); one arm at (24, 5) facing south.
	for x in range(20, 32):
		sim.place(&"conveyor_belt", Vector2i(x, 4), 0)
	sim.place(&"inserter", Vector2i(24, 5), 1)
	sim.place(&"chain_gun", Vector2i(24, 6))
	SimHelpers.finish_construction(sim)
	var tower := sim.building_at(Vector2i(24, 6))
	tower.ammo = 70
	var mag := sim.reg.item_index(&"ammo_magazine")
	for k in 6:
		sim.belts.insert_at_tile(sim.grid.idx(20 + k / 2, 4), mag, 0.1 + 0.5 * (k % 2))
	SimHelpers.run(sim, 12.0)
	assert_eq(tower.ammo, 100, "arm loads exactly what the turret can take (3 magazines)")
	assert_eq(sim.belts.item_count(), 3, "the rest flows past to the end of the belt")
	var line := sim.belts.lines[sim.belts.line_at[sim.grid.idx(31, 4)]]
	assert_true(line.pos[line.pos.size() - 1] > 11.0, "leftovers reached the far end")


func test_transfers_are_timestamped_for_indicators() -> void:
	var sim := SimHelpers.open_sim()
	_ore(sim, 20, 4)
	sim.place(&"mining_drill", Vector2i(20, 4), 0)
	sim.place(&"conveyor_belt", Vector2i(22, 5), 0)
	sim.place(&"conveyor_belt", Vector2i(23, 5), 0)
	sim.place(&"inserter", Vector2i(24, 5), 0)
	sim.place(&"smelter", Vector2i(25, 5))
	SimHelpers.run(sim, 10.0)
	var drill := sim.building_at(Vector2i(20, 4))
	var arm := sim.building_at(Vector2i(24, 5))
	var smelter := sim.building_at(Vector2i(25, 5))
	assert_eq(drill.last_out_tile, sim.grid.idx(22, 5), "drill reports the tile it fed")
	for b: Building in [drill, arm, smelter]:
		assert_true(sim.tick_count - b.last_in_tick < 60 or b == drill, "%s input recent" % b.def.id)
	assert_true(sim.tick_count - arm.last_out_tick < 60)
	assert_true(BuildingRenderer.activity(sim, arm.last_out_tick) > 0.0)
	assert_eq(BuildingRenderer.activity(sim, -100000), 0.0, "never-used = no indicator")
