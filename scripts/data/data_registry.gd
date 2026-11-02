class_name DataRegistry
extends RefCounted
## Loads and validates all game definitions from res://data.
##
## Definitions are Godot Resources (.tres) so they are typed, editable in the
## inspector and diff-friendly. Lookup tables (LUTs) indexed by terrain code are
## precomputed here so hot loops never touch Resource objects.

const TERRAIN_DIR := "res://data/terrain"
const BUILDING_DIR := "res://data/buildings"
const ENEMY_DIR := "res://data/enemies"
const ITEM_DIR := "res://data/items"
const RULES_PATH := "res://data/rules/default_rules.tres"
const SPAWNING_PATH := "res://data/rules/default_spawning.tres"

## Index = terrain code. Gaps are null.
var terrain_by_code: Array[TerrainDef] = []
var terrain_by_id: Dictionary = {}
## code -> 1 if walkable by enemies, else 0.
var walkable_lut := PackedByteArray()
## code -> 1 if structures can be placed, else 0.
var buildable_lut := PackedByteArray()
var buildings_by_id: Dictionary = {}
## Item definitions; the array index is the item index used in hot code.
var items: Array[ItemDef] = []
var item_index_by_id: Dictionary = {}
## Enemy definitions; the array index is the enemy type index used by the simulation.
var enemies: Array[EnemyDef] = []
var enemies_by_id: Dictionary = {}
var rules: GameRules
var spawning: SpawnConfig
## Validation problems found while loading. Empty when everything is fine.
var errors := PackedStringArray()


static func load_default() -> DataRegistry:
	var reg := DataRegistry.new()
	reg.load_terrain(TERRAIN_DIR)
	reg.load_items(ITEM_DIR)
	reg.load_buildings(BUILDING_DIR)
	reg.load_enemies(ENEMY_DIR)
	reg.rules = load(RULES_PATH) as GameRules
	reg.spawning = load(SPAWNING_PATH) as SpawnConfig
	if reg.rules == null:
		reg.errors.append("Missing or invalid " + RULES_PATH)
	if reg.spawning == null:
		reg.errors.append("Missing or invalid " + SPAWNING_PATH)
	reg.validate_references()
	return reg


func load_items(dir: String) -> void:
	for res in load_resources_in(dir):
		var def := res as ItemDef
		if def == null or def.id == &"":
			errors.append("%s: not a valid ItemDef" % res.resource_path)
		elif item_index_by_id.has(def.id):
			errors.append("Duplicate item id '%s'" % def.id)
		else:
			item_index_by_id[def.id] = items.size()
			items.append(def)


## Index of item [param id], or -1 if unknown.
func item_index(id: StringName) -> int:
	return item_index_by_id.get(id, -1)


## Checks that recipes, towers and ores only reference known items.
func validate_references() -> void:
	for def: BuildingDef in buildings_by_id.values():
		if def.kind == &"crafter":
			if def.recipe == null:
				errors.append("Crafter '%s' has no recipe" % def.id)
				continue
			for item in def.recipe.inputs.keys() + def.recipe.outputs.keys():
				if not item_index_by_id.has(StringName(item)):
					errors.append("Recipe '%s' uses unknown item '%s'" % [def.recipe.id, item])
		if def.tower != null and def.tower.ammo_item != &"" and not item_index_by_id.has(def.tower.ammo_item):
			errors.append("Tower '%s' uses unknown ammo '%s'" % [def.id, def.tower.ammo_item])
	for def: TerrainDef in terrain_by_id.values():
		if def.drillable and not item_index_by_id.has(def.yield_item):
			errors.append("Terrain '%s' yields unknown item '%s'" % [def.id, def.yield_item])


func load_buildings(dir: String) -> void:
	for res in load_resources_in(dir):
		var def := res as BuildingDef
		if def == null or def.id == &"":
			errors.append("%s: not a valid BuildingDef" % res.resource_path)
		elif buildings_by_id.has(def.id):
			errors.append("Duplicate building id '%s'" % def.id)
		elif def.size.x < 1 or def.size.y < 1:
			errors.append("Building '%s' has invalid size" % def.id)
		else:
			buildings_by_id[def.id] = def
	if not buildings_by_id.has(&"core"):
		errors.append("No 'core' building defined")


func load_enemies(dir: String) -> void:
	for res in load_resources_in(dir):
		var def := res as EnemyDef
		if def == null or def.id == &"":
			errors.append("%s: not a valid EnemyDef" % res.resource_path)
		elif enemies_by_id.has(def.id):
			errors.append("Duplicate enemy id '%s'" % def.id)
		elif def.hp <= 0.0 or def.speed <= 0.0:
			errors.append("Enemy '%s' needs positive hp and speed" % def.id)
		else:
			enemies_by_id[def.id] = def
			enemies.append(def)


## Buildings shown in the toolbar, ordered by slot.
func toolbar_buildings() -> Array[BuildingDef]:
	var out: Array[BuildingDef] = []
	for def: BuildingDef in buildings_by_id.values():
		if def.toolbar_slot > 0:
			out.append(def)
	out.sort_custom(func(a: BuildingDef, b: BuildingDef) -> bool: return a.toolbar_slot < b.toolbar_slot)
	return out


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
