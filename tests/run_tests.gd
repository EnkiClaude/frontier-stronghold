extends SceneTree
## Headless test runner.
##
##   godot --headless --path . -s res://tests/run_tests.gd [-- <name filter>]
##
## Runs every test_*.gd in res://tests/unit. Exit code 0 = all passed.

const UNIT_DIR := "res://tests/unit"


func _initialize() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]
	var files := Array(DirAccess.get_files_at(UNIT_DIR))
	files.sort()
	var passed := 0
	var failed := 0
	var t0 := Time.get_ticks_msec()
	for f: String in files:
		if not (f.begins_with("test_") and f.ends_with(".gd")):
			continue
		var script: GDScript = load(UNIT_DIR.path_join(f))
		for m in script.get_script_method_list():
			var method: String = m["name"]
			if not method.begins_with("test_"):
				continue
			if filter != "" and not (f + ":" + method).contains(filter):
				continue
			var suite: TestCase = script.new()
			suite.current_test = "%s:%s" % [f.get_basename(), method]
			suite.call(method)
			if suite.failures.is_empty():
				passed += 1
				print("  PASS  ", suite.current_test)
			else:
				failed += 1
				print("  FAIL  ", suite.current_test)
				for msg in suite.failures:
					print("        ", msg)
	print("\n%d passed, %d failed (%d ms)" % [passed, failed, Time.get_ticks_msec() - t0])
	quit(1 if failed > 0 or passed == 0 else 0)
