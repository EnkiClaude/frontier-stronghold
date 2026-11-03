extends TestCase
## Each tower's attack pattern, damage type and status effect (ADR-007).


func _tower(sim: GameSim, id: StringName, at: Vector2i) -> Building:
	sim.credits = 100000
	sim.infinite_ammo = true
	for item in [&"copper_plate", &"steel", &"brick"]:
		sim.add_to_core(sim.reg.item_index(item), 100)
	assert_eq(sim.place(id, at), "")
	SimHelpers.finish_construction(sim)
	return sim.building_at(at)


func test_sniper_ignores_armor() -> void:
	var sim := SimHelpers.open_sim(40, 16)
	_tower(sim, &"sniper_rifle", Vector2i(10, 2))
	SimHelpers.spawn_at(sim, &"armoured", 20, 8, 1000.0)
	sim.tick()
	assert_eq(sim.enemies.hp[0], 1000.0 - 70.0, "full 70 damage through armour 3")


func test_flamethrower_cone_hits_group_and_burns() -> void:
	var sim := SimHelpers.open_sim(40, 16)
	_tower(sim, &"flamethrower", Vector2i(20, 6))
	# A column of enemies straight in front of the nozzle.
	for k in 3:
		SimHelpers.spawn_at(sim, &"swarm", 22 + k, 7, 1000.0)  # Within the 4.5-tile range.
	sim.tick()
	for i in 3:
		assert_true(sim.enemies.hp[i] < 1000.0, "enemy %d in the cone was hit" % i)
		assert_true(sim.enemies.burn_t[i] > 0.0, "enemy %d is burning" % i)
	var hp := sim.enemies.hp[0]
	sim.infinite_ammo = false
	sim.building_at(Vector2i(20, 6)).ammo = 0
	SimHelpers.run(sim, 1.0)
	assert_true(sim.enemies.hp[0] < hp, "burn keeps damaging after the tower stops")


func test_flamethrower_does_not_hit_behind() -> void:
	var sim := SimHelpers.open_sim(40, 16)
	_tower(sim, &"flamethrower", Vector2i(20, 6))
	SimHelpers.spawn_at(sim, &"swarm", 24, 7, 1000.0)
	SimHelpers.spawn_at(sim, &"swarm", 18, 7, 1000.0)  # Opposite side.
	sim.enemies.stun_t[0] = 99.0
	sim.enemies.stun_t[1] = 99.0
	sim.building_at(Vector2i(20, 6)).target_uid = sim.enemies.uid[0]
	sim.tick()
	assert_true(sim.enemies.hp[0] < 1000.0)
	assert_eq(sim.enemies.hp[1], 1000.0, "outside the cone")


func test_icy_blast_slows_group() -> void:
	var sim := SimHelpers.open_sim(40, 16)
	_tower(sim, &"icy_blast", Vector2i(20, 2))
	SimHelpers.spawn_at(sim, &"swarm", 22, 7, 1000.0)
	SimHelpers.spawn_at(sim, &"swarm", 23, 7, 1000.0)
	sim.tick()
	assert_eq(sim.enemies.slow[0], 0.55)
	assert_eq(sim.enemies.slow[1], 0.55, "splash slows neighbours too")
	var x0 := sim.enemies.x[0]
	SimHelpers.run(sim, 1.0)
	var moved := absf(sim.enemies.x[0] - x0) + 0.0
	assert_true(moved < 1.6 * 0.6, "moved %.2f tiles in 1 s at 55%% speed" % moved)


func test_lightning_chains() -> void:
	var sim := SimHelpers.open_sim(40, 16)
	var tower := _tower(sim, &"lightning_tower", Vector2i(10, 2))
	sim.power.unregister(tower)  # Test the attack, not the grid.
	tower.power_satisfaction = 1.0
	for k in 5:
		SimHelpers.spawn_at(sim, &"swarm", 16 + k * 2, 8, 1000.0)
	for i in 5:
		sim.enemies.stun_t[i] = 99.0
	sim.tick()
	var hit := 0
	for i in 5:
		if sim.enemies.hp[i] < 1000.0:
			hit += 1
	assert_eq(hit, 4, "target + 3 chain jumps")


func test_every_tower_can_kill() -> void:
	for id in [&"chain_gun", &"sniper_rifle", &"flamethrower", &"icy_blast", &"tesla_coil", &"lightning_tower"]:
		var sim := SimHelpers.open_sim(40, 16)
		var tower := _tower(sim, id, Vector2i(20, 6))
		if tower.def.tower.power_draw > 0.0:
			sim.power.unregister(tower)
			tower.power_satisfaction = 1.0
		SimHelpers.spawn_at(sim, &"swarm", 22, 9)
		SimHelpers.run(sim, 10.0)
		assert_eq(sim.kills, 1, "%s killed a swarmer" % id)
