extends TestCase
## Loads every script and scene so parse/compile errors in code that unit
## tests don't exercise (views, UI, tools) still fail the test run.

const ROOTS := ["res://scripts", "res://scenes", "res://tools"]


func test_everything_loads() -> void:
	var files := PackedStringArray()
	for root in ROOTS:
		_collect(root, files)
	assert_true(files.size() > 20, "found %d files" % files.size())
	for f in files:
		var res := load(f)
		assert_true(res != null, "failed to load " + f)
		if res is GDScript:
			assert_true((res as GDScript).can_instantiate(), "does not compile: " + f)


func test_main_scene_instantiates() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var node := scene.instantiate()
	assert_true(node != null)
	node.free()


func _collect(dir: String, out: PackedStringArray) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(d), out)
