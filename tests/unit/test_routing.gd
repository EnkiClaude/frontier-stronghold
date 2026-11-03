extends TestCase
## Belt-to-building delivery, splitters, tunnels and auto-tunnelling (ADR-008).


func _item(sim: GameSim, id: StringName) -> int:
	return sim.reg.item_index(id)


func test_belt_delivers_into_building_it_points_at() -> void:
	var sim := SimHelpers.open_sim()
	for x in range(20, 24):
		sim.place(&"conveyor_belt", Vector2i(x, 4), 0)
	sim.place(&"storage", Vector2i(24, 4))
	SimHelpers.finish_construction(sim)
	var plate := _item(sim, &"iron_plate")
	var before := sim.stock(plate)
	for k in 3:
		sim.belts.insert_at_tile(sim.grid.idx(20 + k, 4), plate)
	SimHelpers.run(sim, 4.0)
	assert_eq(sim.belts.item_count(), 0, "belt emptied into the storage")
	assert_eq(sim.stock(plate), before + 3)


func test_belt_into_tower_loads_ammo() -> void:
	var sim := SimHelpers.open_sim()
	for x in range(20, 24):
		sim.place(&"conveyor_belt", Vector2i(x, 4), 0)
	sim.place(&"chain_gun", Vector2i(24, 4))
	SimHelpers.finish_construction(sim)
	var gun := sim.building_at(Vector2i(24, 4))
	gun.ammo = 0
	sim.belts.insert_at_tile(sim.grid.idx(21, 4), _item(sim, &"ammo_magazine"))
	SimHelpers.run(sim, 3.0)
	assert_eq(gun.ammo, 10)


func test_splitter_alternates_outputs() -> void:
	var sim := SimHelpers.open_sim()
	# Feed belt east into a splitter at (22,8); outputs north (22,7), east (23,8), south (22,9).
	sim.place(&"conveyor_belt", Vector2i(20, 8), 0)
	sim.place(&"conveyor_belt", Vector2i(21, 8), 0)
	sim.place(&"splitter", Vector2i(22, 8), 0)
	for k in 3:
		sim.place(&"conveyor_belt", Vector2i(22, 7 - k), 3)
		sim.place(&"conveyor_belt", Vector2i(23 + k, 8), 0)
		sim.place(&"conveyor_belt", Vector2i(22, 9 + k), 1)
	SimHelpers.finish_construction(sim)
	var ore := _item(sim, &"iron_ore")
	for k in 6:
		sim.belts.insert_at_tile(sim.grid.idx(20 + k / 4, 8), ore, 0.1 + 0.25 * (k % 4))
	SimHelpers.run(sim, 10.0)
	var counts := []
	for start: Vector2i in [Vector2i(22, 7), Vector2i(23, 8), Vector2i(22, 9)]:
		var line := sim.belts.lines[sim.belts.line_at[sim.grid.idx(start.x, start.y)]]
		counts.append(line.items.size())
	assert_eq(counts, [2, 2, 2], "even round-robin split")


func test_tunnel_carries_items_under_a_crossing_belt() -> void:
	var sim := SimHelpers.open_sim()
	# Vertical belt at x=24 (southwards), our line goes east along y=6 under it.
	for y in range(2, 11):
		sim.place(&"conveyor_belt", Vector2i(24, y), 1)
	sim.place(&"conveyor_belt", Vector2i(21, 6), 0)
	sim.place(&"conveyor_belt", Vector2i(22, 6), 0)
	sim.place(&"belt_tunnel", Vector2i(23, 6), 0, 0)
	sim.place(&"belt_tunnel", Vector2i(25, 6), 0, 1)
	for x in range(26, 29):
		sim.place(&"conveyor_belt", Vector2i(x, 6), 0)
	SimHelpers.finish_construction(sim)
	assert_eq(sim.belts.tunnel_exit(sim.grid.idx(23, 6)), sim.grid.idx(25, 6))
	assert_eq(sim.building_at(Vector2i(24, 6)).rotation, 1, "crossing belt untouched")
	var coal := _item(sim, &"coal")
	sim.belts.insert_at_tile(sim.grid.idx(21, 6), coal)
	sim.belts.insert_at_tile(sim.grid.idx(24, 3), _item(sim, &"stone"))
	SimHelpers.run(sim, 6.0)
	var east := sim.belts.lines[sim.belts.line_at[sim.grid.idx(28, 6)]]
	assert_true(east.items.has(coal), "coal crossed under to the far side")
	var south := sim.belts.lines[sim.belts.line_at[sim.grid.idx(24, 10)]]
	assert_eq(south.items.size(), 1, "the crossing belt still carries its own item")


func test_drag_across_belt_auto_tunnels() -> void:
	var sim := SimHelpers.open_sim()
	for y in range(2, 11):
		sim.place(&"conveyor_belt", Vector2i(24, y), 1)
	SimHelpers.finish_construction(sim)
	var c := BuildController.new()
	c.sim = sim
	c.select_build(sim.reg.buildings_by_id[&"conveyor_belt"])
	c.mouse_override = Vector2(20.5, 6.5)
	c._process(0.016)
	c._on_primary_pressed()
	c.mouse_override = Vector2(28.5, 6.5)
	c._process(0.016)
	c._commit_drag()
	assert_eq(sim.building_at(Vector2i(23, 6)).def.id, &"belt_tunnel")
	assert_eq(sim.building_at(Vector2i(23, 6)).variant, 0, "entrance before the crossing")
	assert_eq(sim.building_at(Vector2i(25, 6)).variant, 1, "exit after it")
	assert_eq(sim.building_at(Vector2i(24, 6)).rotation, 1, "crossed belt not re-oriented")
	assert_eq(sim.building_at(Vector2i(28, 6)).def.id, &"conveyor_belt")
	c.free()


func test_drones_supply_towers_from_storage() -> void:
	var sim := SimHelpers.open_sim(130, 24)
	sim.place(&"chain_gun", Vector2i(30, 4))
	sim.place(&"storage", Vector2i(36, 4))
	sim.place(&"chain_gun", Vector2i(95, 20))  # ~60 tiles from any stockpile: out of range.
	SimHelpers.finish_construction(sim)
	var gun := sim.building_at(Vector2i(30, 4))
	var far := sim.building_at(Vector2i(95, 20))
	gun.ammo = 0
	far.ammo = 0
	var storage := sim.building_at(Vector2i(36, 4))
	storage.inv_out[_item(sim, &"ammo_magazine")] = 30
	SimHelpers.run(sim, 0.6)
	assert_eq(sim.supply.drones.size(), 1, "one drone for the near tower")
	assert_eq(storage.inv_out[_item(sim, &"ammo_magazine")], 25, "5 magazines reserved")
	SimHelpers.run(sim, 5.0)
	assert_eq(gun.ammo, 100, "refilled to a full magazine")
	assert_eq(far.ammo, 0, "out of supply range")
	assert_true(sim.supply.deliveries >= 2)


func test_drone_returns_items_if_tower_sold() -> void:
	var sim := SimHelpers.open_sim(80, 24)
	sim.place(&"chain_gun", Vector2i(40, 4))
	SimHelpers.finish_construction(sim)
	var gun := sim.building_at(Vector2i(40, 4))
	gun.ammo = 0
	var mag := _item(sim, &"ammo_magazine")
	sim.add_to_core(mag, 5)
	SimHelpers.run(sim, 0.6)
	assert_eq(sim.supply.drones.size(), 1)
	SimHelpers.run(sim, sim.rules.undo_window + 1.0)
	gun = sim.building_at(Vector2i(40, 4))
	# Tower was refilled; now empty it again, launch, and sell mid-flight.
	gun.ammo = 0
	sim.add_to_core(mag, 5)
	SimHelpers.run(sim, 0.6)
	sim.sell(gun.id)
	SimHelpers.run(sim, 6.0)
	assert_eq(sim.stock(mag), 5, "in-flight magazines returned to the Core")
