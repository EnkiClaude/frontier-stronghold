extends SceneTree
## Frame-time profiler for the views (renderers + HUD) in a late-game state:
## serpentine maze with towers, belts full of items, 2,000 enemies.
## Usage: godot --headless --path . -s tools/profile_frame.gd [-- zoom]
## Reports the average frame time with everything on, then the saving from
## hiding each view component in turn (= its cost).

const FRAMES := 90

var main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var zoom := float(args[0]) if args.size() > 0 else 0.75
	root.size = Vector2i(1920, 1080)
	OS.low_processor_usage_mode_sleep_usec = 0  # Headless sleeps ~6.9 ms per frame by default.
	Engine.max_fps = 0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var sim: GameSim = main.sim
	sim.credits = 1000000
	var placed := MazeScenario.build_serpentine(sim, 9, 4, 5, 6, 10)
	# Belt field near the base: 40 rows of 60 belts, filled with items.
	for y in 40:
		for x in 60:
			sim.place(&"conveyor_belt", Vector2i(30 + x, 10 + y), 0 if y % 2 == 0 else 2)
	MazeScenario.run(sim, 3.0)
	var belts := sim.belts
	belts.ensure_built()
	var added := 0
	for line in belts.lines:
		var p := 0.1
		while p < line.tiles.size() - 0.3:
			line.pos.append(p)
			line.items.append(added % sim.reg.items.size())
			p += BeltNetwork.SPACING + 0.01
			added += 1
	var rng := SimRng.new(1)
	var walkable := PackedInt32Array()
	for i in sim.grid.size():
		if sim.path.dist[i] > 0 and sim.grid.cell_of(i).x > 20:
			walkable.append(i)
	for k in 2000:
		sim.enemies.spawn(k % sim.reg.enemies.size(), walkable[rng.next_int_range(0, walkable.size() - 1)], sim.grid, 1.0e9, rng)
	sim.infinite_ammo = false
	main.clock.paused = true  # Views only; the sim is benchmarked separately.
	var cam: CameraController = main.camera
	cam.zoom = Vector2(zoom, zoom)
	cam.center_on(Vector2(70, 40) * WorldGrid.TILE_PX)
	print("Profile: %d structures, %d belt items, %d enemies, zoom %.2f, view %s" % [sim.buildings.size(), belts.item_count(), sim.enemies.count, cam.zoom.x, root.get_visible_rect().size])
	var base := await _measure()
	print("  %-28s %7.2f ms/frame" % ["All views", base])
	var parts := {
		"Terrain": main.terrain_view,
		"Buildings": main.building_view,
		"Belt items": main.get_node("TileSpace").get_child(1),
		"Routes": main.get_node("TileSpace").get_child(2),
		"Enemies": main.enemy_view,
		"Effects": main.effects_view,
		"Build controller": main.controller,
		"HUD": main.hud,
	}
	for label: String in parts:
		var n: Node = parts[label]
		n.set("visible", false)
		n.set_process(false)
		var t := await _measure()
		n.set("visible", true)
		n.set_process(true)
		print("  %-28s %7.2f ms" % [label, base - t])
	for n: Node in parts.values():
		n.set("visible", false)
		n.set_process(false)
	print("  %-28s %7.2f ms/frame" % ["Floor (all views hidden)", await _measure()])
	quit()


func _measure() -> float:
	for k in 10:
		await process_frame
	var t0 := Time.get_ticks_usec()
	for k in FRAMES:
		await process_frame
	return (Time.get_ticks_usec() - t0) / 1000.0 / FRAMES
