extends TestCase


func _core_tile(sim: GameSim) -> Vector2i:
	return sim.core.origin


func test_setup_has_core_nests_and_route() -> void:
	var sim := SimHelpers.open_sim()
	assert_eq(sim.nests.size(), 2)
	for s in sim.path.spawn_cells:
		assert_true(sim.path.dist[s] > 0, "nests must reach the core")
	assert_eq(sim.credits, sim.rules.start_credits)


func test_place_wall_costs_and_constructs() -> void:
	var sim := SimHelpers.open_sim()
	var at := Vector2i(30, 5)
	assert_eq(sim.place(&"wall", at), "")
	assert_eq(sim.credits, sim.rules.start_credits - 5)
	var tile := sim.grid.idx(at.x, at.y)
	assert_eq(sim.path.passable[tile], 1, "not blocking while under construction")
	assert_eq(sim.path.plan_passable[tile], 0, "but reserved for validation")
	SimHelpers.finish_construction(sim)
	assert_eq(sim.path.passable[tile], 0, "blocks once complete")
	assert_eq(sim.place(&"wall", at), GameSim.ERR_OCCUPIED)


func test_cannot_wall_off_completely() -> void:
	var sim := SimHelpers.open_sim(40, 12)
	var x := 20
	var placed := 0
	var last_err := ""
	for y in range(1, 11):
		var err := sim.place(&"wall", Vector2i(x, y))
		if err == "":
			placed += 1
		else:
			last_err = err
	assert_eq(placed, 9, "exactly one gap must remain")
	assert_eq(last_err, GameSim.ERR_BLOCKS)


func test_protected_and_terrain_rules() -> void:
	var sim := SimHelpers.open_sim()
	assert_eq(sim.place(&"wall", _core_tile(sim) + Vector2i(4, 0)), GameSim.ERR_PROTECTED)
	assert_eq(sim.place(&"wall", Vector2i(30, 0)), GameSim.ERR_TERRAIN, "bedrock row")
	assert_eq(sim.place(&"wall", Vector2i(-1, 5)), GameSim.ERR_BOUNDS)


func test_not_enough_credits() -> void:
	var sim := SimHelpers.open_sim()
	sim.credits = 50
	assert_eq(sim.place(&"chain_gun", Vector2i(30, 4)), GameSim.ERR_CREDITS)


func test_sell_refund_and_undo_window() -> void:
	var sim := SimHelpers.open_sim()
	sim.place(&"chain_gun", Vector2i(30, 4))
	var id: int = sim.building_at(Vector2i(30, 4)).id
	var before := sim.credits
	assert_eq(sim.sell(id), "")
	assert_eq(sim.credits, before + 100, "full refund inside the undo window")
	sim.place(&"chain_gun", Vector2i(30, 4))
	id = sim.building_at(Vector2i(30, 4)).id
	SimHelpers.run(sim, sim.rules.undo_window + 1.0)
	before = sim.credits
	sim.sell(id)
	assert_eq(sim.credits, before + 85, "85% after the undo window")
	assert_eq(sim.building_at(Vector2i(30, 4)), null)
	assert_eq(sim.path.passable[sim.grid.idx(30, 4)], 1, "path reopened")


func test_core_cannot_be_sold() -> void:
	var sim := SimHelpers.open_sim()
	assert_eq(sim.sell(sim.core.id), GameSim.ERR_NOT_SELLABLE)


func test_relocate_charges_fee_and_goes_offline() -> void:
	var sim := SimHelpers.open_sim()
	sim.place(&"chain_gun", Vector2i(30, 4))
	var b := sim.building_at(Vector2i(30, 4))
	SimHelpers.finish_construction(sim)
	var before := sim.credits
	assert_eq(sim.relocate(b.id, Vector2i(34, 14)), "")
	assert_eq(sim.credits, before - 10)
	assert_eq(b.state, Building.State.RELOCATING)
	assert_eq(sim.building_at(Vector2i(30, 4)), null)
	assert_eq(sim.building_at(Vector2i(35, 15)), b)
	SimHelpers.run(sim, sim.rules.relocate_time + 0.1)
	assert_true(b.is_active())
	assert_eq(b.invested, 100, "fee is not added to the refundable value")


func test_relocate_onto_overlapping_footprint() -> void:
	var sim := SimHelpers.open_sim()
	sim.place(&"chain_gun", Vector2i(30, 4))
	var b := sim.building_at(Vector2i(30, 4))
	SimHelpers.finish_construction(sim)
	assert_eq(sim.relocate(b.id, Vector2i(31, 4)), "", "may overlap its own old footprint")


func _with_radius(sim: GameSim, r: float) -> void:
	sim.rules = sim.rules.duplicate()  # Don't modify the shared resource.
	sim.rules.no_build_radius = r


func test_building_near_enemies_allowed_by_default() -> void:
	var sim := SimHelpers.open_sim()
	assert_eq(sim.rules.no_build_radius, 0.0, "playtest feedback: rule disabled")
	SimHelpers.spawn_at(sim, &"swarm", 30, 12)
	assert_eq(sim.place(&"wall", Vector2i(32, 12)), "")


func test_no_build_near_enemies() -> void:
	var sim := SimHelpers.open_sim()
	_with_radius(sim, 6.0)
	SimHelpers.spawn_at(sim, &"swarm", 30, 12)
	assert_eq(sim.place(&"wall", Vector2i(33, 12)), GameSim.ERR_ENEMIES)
	assert_eq(sim.place(&"wall", Vector2i(30, 3)), "", "far enough away (9 tiles)")


func test_sell_blocked_near_enemies() -> void:
	var sim := SimHelpers.open_sim()
	_with_radius(sim, 6.0)
	sim.place(&"wall", Vector2i(30, 12))
	var id: int = sim.building_at(Vector2i(30, 12)).id
	SimHelpers.spawn_at(sim, &"swarm", 32, 12)
	assert_eq(sim.sell(id), GameSim.ERR_ENEMIES)


func test_enemy_reaches_core_and_damages_it() -> void:
	var sim := SimHelpers.open_sim(40, 12)
	SimHelpers.spawn_at(sim, &"swarm", 20, 6)
	var hp := sim.core_hp
	SimHelpers.run(sim, 20.0)
	assert_eq(sim.leaked, 1)
	assert_eq(sim.core_hp, hp - 1)
	assert_eq(sim.enemies.count, 0)


func test_enemies_follow_the_maze() -> void:
	var sim := SimHelpers.open_sim(40, 12)
	# Wall at x=20 with a single gap at the bottom (y=10).
	for y in range(1, 10):
		assert_eq(sim.place(&"wall", Vector2i(20, y)), "")
	SimHelpers.finish_construction(sim)
	while sim.path.is_updating():
		sim.tick()
	SimHelpers.spawn_at(sim, &"swarm", 30, 2)
	var went_through_gap := false
	for i in 30 * 30:
		sim.tick()
		if sim.enemies.count == 0:
			break
		var x := sim.enemies.x[0]
		var y := sim.enemies.y[0]
		assert_true(sim.path.passable[sim.enemies.cell[0]] == 1, "never inside a wall")
		if x >= 20.0 and x < 21.0:
			went_through_gap = went_through_gap or y >= 10.0
	assert_true(went_through_gap, "must pass the wall through the gap")
	assert_eq(sim.leaked, 1)


func test_wall_waits_for_enemy_to_leave_footprint() -> void:
	var sim := SimHelpers.open_sim(40, 12)
	sim.place(&"wall", Vector2i(20, 3))
	var b := sim.building_at(Vector2i(20, 3))
	# Force an enemy onto the footprint (normally prevented by the no-build radius).
	SimHelpers.spawn_at(sim, &"swarm", 20, 3)
	sim.enemies.next[0] = sim.grid.idx(20, 3)
	b.timer = 1
	sim.tick()
	assert_eq(b.state, Building.State.CONSTRUCTING, "must not complete on top of an enemy")


func test_chain_gun_kills_enemy_in_range() -> void:
	var sim := SimHelpers.open_sim(40, 12)
	sim.place(&"chain_gun", Vector2i(20, 2))
	SimHelpers.finish_construction(sim)
	SimHelpers.spawn_at(sim, &"swarm", 26, 6)
	var credits := sim.credits
	SimHelpers.run(sim, 8.0)
	assert_eq(sim.kills, 1)
	assert_eq(sim.credits, credits + 3)
	assert_true(sim.drain_shots().size() >= 5)


func test_armor_reduces_damage() -> void:
	var sim := SimHelpers.open_sim(40, 12)
	sim.place(&"chain_gun", Vector2i(20, 2))
	SimHelpers.finish_construction(sim)
	SimHelpers.spawn_at(sim, &"armoured", 23, 6, 1000.0)
	sim.tick()
	var lost := 1000.0 - sim.enemies.hp[0]
	assert_eq(lost, 6.0 - 3.0)


func test_excavation_opens_rock() -> void:
	var sim := SimHelpers.open_sim(40, 12)
	var rock := sim.reg.terrain_code(&"rock")
	sim.grid.set_terrain(25, 5, rock)
	sim.path.terrain_changed(sim.grid.idx(25, 5))
	var credits := sim.credits
	assert_eq(sim.excavate(Vector2i(25, 5)), "")
	assert_eq(sim.credits, credits - sim.rules.excavate_cost)
	assert_eq(sim.excavate(Vector2i(25, 5)), GameSim.ERR_NOT_DIGGABLE, "already ordered")
	SimHelpers.run(sim, sim.rules.excavate_time + 0.1)
	assert_eq(sim.grid.get_terrain(25, 5), sim.reg.terrain_code(&"ground"))
	assert_eq(sim.path.passable[sim.grid.idx(25, 5)], 1)
	assert_eq(sim.excavate(Vector2i(26, 5)), GameSim.ERR_NOT_DIGGABLE, "ground is not diggable")


func _spawned(sim: GameSim) -> int:
	return sim.enemies._next_uid - 1


func test_spawning_starts_after_grace_period() -> void:
	var sim := SimHelpers.open_sim()
	SimHelpers.run(sim, sim.reg.spawning.grace_period - 1.0)
	assert_eq(sim.enemies.count, 0)
	SimHelpers.run(sim, 3.0)
	assert_eq(_spawned(sim), 2 * sim.reg.spawning.wave_base_size, "first small wave: 3 per nest")


func test_small_waves_leave_gaps() -> void:
	var sim := SimHelpers.open_sim()
	sim.skip_preparation()
	SimHelpers.run(sim, 3.0)
	var first := _spawned(sim)
	SimHelpers.run(sim, 12.0)
	assert_eq(_spawned(sim), first, "quiet between small waves")
	SimHelpers.run(sim, 7.0)
	assert_true(_spawned(sim) > first, "next wave after 20 s")


func test_lull_after_assault() -> void:
	var sim := SimHelpers.open_sim()
	sim.core_hp = 1000000  # Undefended test map: keep the game running.
	sim.skip_preparation()
	var cfg := sim.reg.spawning
	while sim.spawner.assault_number() == 0 or sim.spawner.is_assault_active():
		sim.tick()
	assert_true(sim.spawner.in_lull(sim.time))
	var after := _spawned(sim)
	SimHelpers.run(sim, cfg.lull_after_assault - 0.5)
	assert_eq(_spawned(sim), after, "no spawns during the lull")
	SimHelpers.run(sim, 3.0)
	assert_true(_spawned(sim) > after, "waves resume after the lull")


func test_game_over_when_core_destroyed() -> void:
	var sim := SimHelpers.open_sim(40, 12)
	sim.core_hp = 1
	SimHelpers.spawn_at(sim, &"swarm", 15, 6)
	SimHelpers.run(sim, 15.0)
	assert_true(sim.game_over)
	assert_eq(sim.place(&"wall", Vector2i(30, 3)), GameSim.ERR_GAME_OVER)


func test_deterministic_runs() -> void:
	var a := SimHelpers.open_sim(60, 24, 9)
	var b := SimHelpers.open_sim(60, 24, 9)
	for sim: GameSim in [a, b]:
		sim.place(&"chain_gun", Vector2i(30, 10))
		sim.place(&"wall", Vector2i(40, 5))
		sim.skip_preparation()
		SimHelpers.run(sim, 60.0)
	assert_true(a.enemies.count > 0 or a.kills > 0, "something happened")
	assert_eq(a.state_hash(), b.state_hash())


func test_preparation_can_be_skipped() -> void:
	var sim := SimHelpers.open_sim()
	assert_true(sim.reg.spawning.grace_period >= 160.0, "playtest feedback: ~2:45 of preparation")
	SimHelpers.run(sim, 10.0)
	assert_true(sim.in_preparation())
	var first_assault := sim.spawner.next_assault_at
	sim.skip_preparation()
	assert_false(sim.in_preparation())
	sim.tick()
	assert_eq(sim.enemies.count, 2, "one enemy per nest right away")
	assert_true(sim.spawner.next_assault_at < first_assault, "assault schedule moves forward too")
	assert_true(absf(sim.spawner.next_assault_at - (sim.time + sim.reg.spawning.assault_first_at)) < 0.1)


func test_enemy_hp_scaling_starts_after_preparation() -> void:
	var sim := SimHelpers.open_sim()
	SimHelpers.run(sim, sim.reg.spawning.grace_period + 0.5)
	assert_true(sim.enemies.count > 0)
	var def: EnemyDef = sim.reg.enemies[sim.enemies.type[0]]
	assert_true(sim.enemies.max_hp[0] < def.hp * 1.05, "prep time must not inflate enemy HP")


func test_belt_overlap_reorients_for_free() -> void:
	var sim := SimHelpers.open_sim()
	sim.place(&"conveyor_belt", Vector2i(20, 4), 0)
	SimHelpers.finish_construction(sim)
	var b := sim.building_at(Vector2i(20, 4))
	sim.belts.insert_at_tile(sim.grid.idx(20, 4), 0)
	var credits := sim.credits
	assert_eq(sim.check_place(&"conveyor_belt", Vector2i(20, 4), 1), "", "ghost shows it as valid")
	assert_eq(sim.place(&"conveyor_belt", Vector2i(20, 4), 1), "")
	assert_eq(sim.credits, credits, "no cost")
	assert_eq(sim.building_at(Vector2i(20, 4)), b, "same belt, not a new one")
	assert_eq(b.rotation, 1)
	assert_eq(sim.belts.dir_of[sim.grid.idx(20, 4)], 1)
	assert_eq(sim.belts.item_count(), 1, "items on it are kept")
	assert_eq(sim.place(&"conveyor_belt", Vector2i(20, 4), 1), "", "same direction: harmless no-op")
	assert_eq(sim.place(&"wall", Vector2i(20, 4)), GameSim.ERR_OCCUPIED, "other buildings still can't overlap")
