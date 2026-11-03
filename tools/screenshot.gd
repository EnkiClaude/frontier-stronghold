extends SceneTree
## Launches the game, optionally plays a scripted scenario, saves a screenshot.
##   godot --path . -s res://tools/screenshot.gd -- <out.png> [scenario] [zoom] [sim_seconds]
## Scenarios: start (default), battle (serpentine maze + towers),
## supply (ammo production line feeding Chain Guns), enemy.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://screenshot.png"
	var scenario := args[1] if args.size() > 1 else "start"
	var zoom := float(args[2]) if args.size() > 2 else -1.0
	var seconds := float(args[3]) if args.size() > 3 else 150.0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set("world_seed", 4242)
	root.add_child(main)
	await process_frame
	var sim: GameSim = main.get("sim")
	var cam: CameraController = main.get("camera")
	if scenario == "battle":
		sim.credits = 100000
		MazeScenario.build_serpentine(sim, 9, 4, 5)
		MazeScenario.run(sim, seconds)
		var ctrl: BuildController = main.get("controller")
		ctrl.select_build(sim.reg.buildings_by_id[&"chain_gun"])
		cam.position = Vector2(20, sim.grid.height * 0.5) * WorldGrid.TILE_PX
		# Focus on the enemy closest to the Core along the route.
		var best := -1
		for i in sim.enemies.count:
			if best < 0 or sim.path.dist[sim.enemies.cell[i]] < sim.path.dist[sim.enemies.cell[best]]:
				best = i
		if best >= 0:
			cam.position = Vector2(sim.enemies.x[best], sim.enemies.y[best]) * WorldGrid.TILE_PX
	if scenario == "supply":
		sim.credits = 100000
		var ground := sim.reg.terrain_code(&"ground")
		for x in range(9, 64):
			for y in range(64, 80):
				sim.grid.set_terrain(x, y, ground)
				sim.path.terrain_changed(sim.grid.idx(x, y))
		SupplyScenario.build_defense_line(sim, Vector2i(10, 66), 28, 4)
		MazeScenario.run(sim, seconds)
		cam.position = Vector2(30, 71) * WorldGrid.TILE_PX
		var ctrl: BuildController = main.get("controller")
		var tower := sim.building_at(Vector2i(26, 68))
		if tower != null:
			ctrl._set_selected(tower)
	if scenario == "empty":
		sim.credits = 100000
		var towers := SupplyScenario.build_defense_line(sim, Vector2i(10, 66), 28, 4, false)
		MazeScenario.run(sim, 3.0)
		sim.infinite_ammo = false
		towers[0].ammo = 0
		towers[1].ammo = 8
		cam.position = Vector2(34, 69) * WorldGrid.TILE_PX
	if scenario == "scale":
		GameSettings.get_instance().set_option("ui_scale", 1.5)
	if scenario == "menu":
		var hud: Hud = main.get("hud")
		hud.toggle_menu()
	if scenario == "io":
		sim.credits = 100000
		var ground := sim.reg.terrain_code(&"ground")
		for x in range(9, 64):
			for y in range(64, 80):
				sim.grid.set_terrain(x, y, ground)
				sim.path.terrain_changed(sim.grid.idx(x, y))
		SupplyScenario.build_defense_line(sim, Vector2i(10, 66), 28, 4)
		MazeScenario.run(sim, seconds)
		cam.position = Vector2(22, 69) * WorldGrid.TILE_PX
		var ctrl: BuildController = main.get("controller")
		ctrl.select_build(sim.reg.buildings_by_id[&"mining_drill"])
		ctrl.mouse_override = Vector2(17.0, 73.0)
	if scenario == "arsenal":
		sim.credits = 100000
		for item in [&"copper_plate", &"steel", &"brick", &"coal"]:
			sim.add_to_core(sim.reg.item_index(item), 300)
		var ground := sim.reg.terrain_code(&"ground")
		for x in range(9, 70):
			for y in range(60, 100):
				sim.grid.set_terrain(x, y, ground)
				sim.path.terrain_changed(sim.grid.idx(x, y))
		sim.infinite_ammo = true
		var cy := sim.core.origin.y + 1
		var ids := [&"chain_gun", &"sniper_rifle", &"flamethrower", &"icy_blast", &"tesla_coil", &"lightning_tower"]
		for k in ids.size():
			print(ids[k], " ", sim.place(ids[k], Vector2i(18 + k * 4, cy - 4)))
		sim.place(&"power_node", Vector2i(37, cy - 7))
		sim.place(&"generator", Vector2i(38, cy - 10))
		sim.place(&"storage", Vector2i(14, cy - 10))
		MazeScenario.run(sim, 4.0)
		sim.building_at(Vector2i(38, cy - 10)).inv_in[sim.reg.item_index(&"coal")] = 10
		sim.skip_preparation()
		MazeScenario.run(sim, seconds)
		cam.position = Vector2(30, cy) * WorldGrid.TILE_PX
	if scenario == "logistics":
		sim.credits = 100000
		var ground := sim.reg.terrain_code(&"ground")
		var cy := sim.core.origin.y + 1
		for x in range(9, 70):
			for y in range(cy - 25, cy + 15):
				sim.grid.set_terrain(x, y, ground)
				sim.path.terrain_changed(sim.grid.idx(x, y))
		var mag := sim.reg.item_index(&"ammo_magazine")
		var ore := sim.reg.item_index(&"iron_ore")
		sim.add_to_core(sim.reg.item_index(&"brick"), 50)
		sim.place(&"storage", Vector2i(24, cy - 14))
		for k in 4:
			sim.place(&"chain_gun", Vector2i(36 + k * 5, cy - 6))
		# A vertical belt (south) crossed by an eastward belt via a tunnel, into a splitter.
		for y in range(cy - 22, cy - 13):
			sim.place(&"conveyor_belt", Vector2i(44, y), 1)
		var ctrl: BuildController = main.get("controller")
		ctrl.select_build(sim.reg.buildings_by_id[&"conveyor_belt"])
		ctrl.mouse_override = Vector2(38.5, cy - 18 + 0.5)
		ctrl._process(0.016)
		ctrl._on_primary_pressed()
		ctrl.mouse_override = Vector2(50.5, cy - 18 + 0.5)
		ctrl._process(0.016)
		ctrl._commit_drag()
		sim.place(&"splitter", Vector2i(51, cy - 18), 0)
		for k in 4:
			sim.place(&"conveyor_belt", Vector2i(51, cy - 19 - k), 3)
			sim.place(&"conveyor_belt", Vector2i(52 + k, cy - 18), 0)
			sim.place(&"conveyor_belt", Vector2i(51, cy - 17 + k), 1)
		MazeScenario.run(sim, 4.0)
		sim.building_at(Vector2i(24, cy - 14)).inv_out[mag] = 200
		for k in 4:
			sim.building_at(Vector2i(36 + k * 5, cy - 6)).ammo = 0
		for k in 8:
			sim.belts.insert_at_tile(sim.grid.idx(38 + k / 3, cy - 18), ore, 0.1 + 0.3 * (k % 3))
			sim.belts.insert_at_tile(sim.grid.idx(44, cy - 22 + k / 3), sim.reg.item_index(&"coal"), 0.1 + 0.3 * (k % 3))
		MazeScenario.run(sim, seconds)
		ctrl.cancel()
		cam.position = Vector2(42, cy - 12) * WorldGrid.TILE_PX
	if scenario == "enemy" and sim.enemies.count == 0:
		MazeScenario.run(sim, seconds)
	if scenario == "enemy" and sim.enemies.count > 0:
		cam.position = Vector2(sim.enemies.x[0], sim.enemies.y[0]) * WorldGrid.TILE_PX
	if zoom > 0.0:
		cam.zoom = Vector2(zoom, zoom)
	cam.clamp_to_world()
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(out)
	if scenario == "scale":
		GameSettings.get_instance().set_option("ui_scale", 1.0)  # Don't leave the test value behind.
	print("saved ", out, " | enemies=", sim.enemies.count, " kills=", sim.kills, " leaked=", sim.leaked, " core=", sim.core_hp)
	quit(0)
