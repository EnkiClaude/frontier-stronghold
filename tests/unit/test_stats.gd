extends TestCase


func test_tower_kill_and_round_stats() -> void:
	var sim := SimHelpers.open_sim(40, 12)
	sim.place(&"chain_gun", Vector2i(20, 2))
	SimHelpers.finish_construction(sim)
	var tower := sim.building_at(Vector2i(20, 2))
	SimHelpers.spawn_at(sim, &"swarm", 25, 6)
	SimHelpers.run(sim, 6.0)
	assert_eq(tower.kills, 1)
	assert_eq(tower.rounds_fired, 5, "30 HP / 6 damage")
	assert_eq(tower.ammo, 45)


func test_item_totals_and_production() -> void:
	var sim := SimHelpers.open_sim()
	var tower := SupplyScenario.build_chain(sim, Vector2i(14, 4))
	SimHelpers.finish_construction(sim)
	tower.ammo = 0
	SimHelpers.run(sim, 10.0)
	var ore := sim.reg.item_index(&"iron_ore")
	var mags := sim.reg.item_index(&"ammo_magazine")
	assert_true(sim.factory.produced[ore] >= 10, "ore mined: %d" % sim.factory.produced[ore])
	assert_true(sim.factory.produced[mags] >= 2)
	var totals := sim.item_totals()
	assert_true(totals[ore] >= 0)
	var summary := sim.ammo_summary()
	assert_eq(summary[0], tower.ammo)
	assert_eq(summary[1], 100)


func test_start_resources_allow_a_real_maze() -> void:
	var reg := DataRegistry.load_default()
	assert_true(reg.rules.start_credits >= 1000, "player feedback: start credits too low")
	assert_true(reg.spawning.grace_period >= 40.0)
