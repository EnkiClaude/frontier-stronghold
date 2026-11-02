class_name DataRegistry
extends RefCounted
## Loads and validates all game definitions from res://data.
##
## Definitions are Godot Resources (.tres) so they are typed, editable in the
## inspector and diff-friendly. Lookup tables (LUTs) indexed by terrain code are
## precomputed here so hot loops never touch Resource objects.

const TERRAIN_DIR := "res://data/terrain"

## Index = terrain code. Gaps are null.
var terrain_by_code: Array[TerrainDef] = []
var terrain_by_id: Dictionary = {}
## code -> 1 if walkable by enemies, else 0.
var walkable_lut := PackedByteArray()
## code -> 1 if structures can be placed, else 0.
var buildable_lut := PackedByteArray()
## Validation problems found while loading. Empty when everything is fine.
var errors := PackedStringArray()


static func load_default() -> DataRegistry:
	var reg := DataRegistry.new()
	reg.load_terrain(TERRAIN_DIR)
	return reg


func load_terrain(dir: String) -> void:
	var defs: Array[TerrainDef] = []
	for res in load_resources_in(dir):
		if res is TerrainDef:
			defs.append(res)
		else:
			errors.append("%s: not a TerrainDef" % res.resource_path)
	var max_code := -1
	for def in defs:
		if def.id == &"":
			errors.append("%s: missing id" % def.resource_path)
			continue
		if terrain_by_id.has(def.id):
			errors.append("Duplicate terrain id '%s'" % def.id)
			continue
		terrain_by_id[def.id] = def
		max_code = maxi(max_code, def.code)
	terrain_by_code.resize(max_code + 1)
	walkable_lut.resize(256)
	buildable_lut.resize(256)
	walkable_lut.fill(0)
	buildable_lut.fill(0)
	for def: TerrainDef in terrain_by_id.values():
		if terrain_by_code[def.code] != null:
			errors.append("Terrain code %d used by '%s' and '%s'" % [def.code, terrain_by_code[def.code].id, def.id])
			continue
		terrain_by_code[def.code] = def
		walkable_lut[def.code] = 1 if def.walkable else 0
		buildable_lut[def.code] = 1 if def.buildable else 0
	for def: TerrainDef in terrain_by_id.values():
		if def.becomes != &"" and not terrain_by_id.has(def.becomes):
			errors.append("Terrain '%s' becomes unknown terrain '%s'" % [def.id, def.becomes])


## Returns the grid code for a terrain id, or -1 (with an error) if unknown.
func terrain_code(id: StringName) -> int:
	var def: TerrainDef = terrain_by_id.get(id)
	if def == null:
		push_error("Unknown terrain id '%s'" % id)
		return -1
	return def.code


## Loads every resource in [param dir], sorted by file name for determinism.
## Handles the ".remap" suffix that exported builds give to converted resources.
static func load_resources_in(dir: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var names: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		var name := f.trim_suffix(".remap")
		if name.ends_with(".tres") or name.ends_with(".res"):
			if not names.has(name):
				names.append(name)
	names.sort()
	for name in names:
		var res := load(dir.path_join(name))
		if res != null:
			out.append(res)
	return out
