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
