extends TestCase


func _powered_setup(sim: GameSim, coal: int) -> Building:
	sim.credits = 100000
	sim.add_to_core(sim.reg.item_index(&"copper_plate"), 100)
	sim.add_to_core(sim.reg.item_index(&"steel"), 100)
	sim.add_to_core(sim.reg.item_index(&"brick"), 100)
	assert_eq(sim.place(&"tesla_coil", Vector2i(20, 8)), "")
	assert_eq(sim.place(&"power_node", Vector2i(23, 8)), "")
	assert_eq(sim.place(&"generator", Vector2i(24, 9)), "")
	SimHelpers.finish_construction(sim)
	var gen := sim.building_at(Vector2i(24, 9))
	gen.inv_in[sim.reg.item_index(&"coal")] = coal
	return sim.building_at(Vector2i(20, 8))


func test_tesla_without_power_does_not_fire() -> void:
	var sim := SimHelpers.open_sim(40, 16)
	var tesla := _powered_setup(sim, 0)
	SimHelpers.spawn_at(sim, &"swarm", 21, 11)
	SimHelpers.run(sim, 2.0)
	assert_eq(tesla.rounds_fired, 0)
	assert_eq(tesla.power_satisfaction, 0.0)


func test_tesla_with_power_pulses_and_stuns() -> void:
	var sim := SimHelpers.open_sim(40, 16)
	var tesla := _powered_setup(sim, 5)
	SimHelpers.spawn_at(sim, &"swarm", 21, 11, 1000.0)
	SimHelpers.spawn_at(sim, &"swarm", 20, 11, 1000.0)
	SimHelpers.run(sim, 0.2)  # Stun lasts 0.35 s.
	assert_eq(tesla.power_satisfaction, 1.0)
	assert_true(tesla.rounds_fired >= 1, "fired")
	assert_true(sim.enemies.hp[0] < 1000.0 and sim.enemies.hp[1] < 1000.0, "pulse hits everything in range")
	assert_true(sim.enemies.stun_t[0] > 0.0 and sim.enemies.stun_t[1] > 0.0, "both stunned")


func test_generator_only_burns_with_demand() -> void:
	var sim := SimHelpers.open_sim(40, 16)
	_powered_setup(sim, 5)
	var gen := sim.building_at(Vector2i(24, 9))
	SimHelpers.run(sim, 10.0)
	assert_eq(gen.inv_in[sim.reg.item_index(&"coal")], 5, "no enemies near the tesla: no coal burned")


func test_partial_power_slows_recharge() -> void:
	var sim := SimHelpers.open_sim(60, 16)
	sim.credits = 100000
	sim.add_to_core(sim.reg.item_index(&"copper_plate"), 200)
	sim.add_to_core(sim.reg.item_index(&"steel"), 200)
	sim.add_to_core(sim.reg.item_index(&"brick"), 100)
	for k in 3:
		sim.place(&"lightning_tower", Vector2i(20 + k * 3, 2))
	sim.place(&"power_node", Vector2i(24, 5))
	sim.place(&"generator", Vector2i(26, 6))
	SimHelpers.finish_construction(sim)
	sim.building_at(Vector2i(26, 6)).inv_in[sim.reg.item_index(&"coal")] = 10
	SimHelpers.spawn_at(sim, &"armoured", 24, 9, 100000.0)
	SimHelpers.run(sim, 0.5)
	var tower := sim.building_at(Vector2i(20, 2))
	assert_true(absf(tower.power_satisfaction - 120.0 / 180.0) < 0.01, "120 supply / 180 demand")
	assert_true(sim.power.links.is_empty(), "single node: no links")


func test_nodes_link_into_one_network() -> void:
	var sim := SimHelpers.open_sim(60, 16)
	sim.add_to_core(sim.reg.item_index(&"copper_plate"), 100)
	sim.place(&"power_node", Vector2i(20, 5))
	sim.place(&"power_node", Vector2i(28, 5))
	sim.place(&"power_node", Vector2i(45, 5))
	SimHelpers.finish_construction(sim)
	sim.tick()
	var a := sim.building_at(Vector2i(20, 5))
	var b := sim.building_at(Vector2i(28, 5))
	var c := sim.building_at(Vector2i(45, 5))
	assert_eq(a.network, b.network, "8 tiles apart: linked")
	assert_ne(a.network, c.network, "17 tiles apart: separate")
	assert_eq(sim.power.links.size(), 1)
