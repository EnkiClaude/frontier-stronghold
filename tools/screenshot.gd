extends SceneTree
## Launches the main scene, waits a few frames and saves a screenshot.
##   godot --path . -s res://tools/screenshot.gd -- out.png [zoom]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://screenshot.png"
	var zoom := float(args[1]) if args.size() > 1 else -1.0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	if zoom > 0.0:
		var cam: Camera2D = main.get("camera")
		cam.zoom = Vector2(zoom, zoom)
		cam.position = Vector2(main.get("grid").width, main.get("grid").height) * WorldGrid.TILE_PX * 0.5
		cam.clamp_to_world()
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit(0)
