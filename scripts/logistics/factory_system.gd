class_name FactorySystem
extends RefCounted
## Drills, crafters and inserters (ADR-005). Works on ACTIVE buildings that
## [GameSim] registers; inventories live on the [Building] objects.

var reg: DataRegistry
var grid: WorldGrid
var belts: BeltNetwork
## Shared with GameSim: tile -> building id.
var occupancy: PackedInt32Array
## Shared with GameSim: id -> Building.
var buildings: Dictionary

var drills: Array[Building] = []
var crafters: Array[Building] = []
var inserters: Array[Building] = []

## Lifetime production per item index (mined or crafted).
var produced := PackedInt32Array()

## Recipe resource -> {item index: count} caches.
var _recipe_in: Dictionary = {}
var _recipe_out: Dictionary = {}


func _init(registry: DataRegistry, world: WorldGrid, belt_network: BeltNetwork, occ: PackedInt32Array, all_buildings: Dictionary) -> void:
	reg = registry
	grid = world
	belts = belt_network
	occupancy = occ
	buildings = all_buildings
	produced.resize(reg.items.size())
	produced.fill(0)


func register(b: Building) -> void:
	match b.def.kind:
		&"drill":
			drills.append(b)
		&"crafter":
			crafters.append(b)
		&"inserter":
			inserters.append(b)


func unregister(b: Building) -> void:
	drills.erase(b)
	crafters.erase(b)
	inserters.erase(b)


## Current simulation tick (set by GameSim before [method tick]); used to
## timestamp item transfers for the activity indicators.
var now: int = 0


func tick(dt: float) -> void:
	for b in drills:
		_tick_drill(b, dt)
	for b in crafters:
		_tick_crafter(b, dt)
	for b in inserters:
		_tick_inserter(b, dt)


# --- Drills ------------------------------------------------------------------

## Item index a drill at this footprint would mine, or -1.
func drill_yield(cells: PackedInt32Array) -> int:
	for c in cells:
		if c < 0:
			continue
		var def: TerrainDef = reg.terrain_by_code[grid.terrain[c]]
		if def != null and def.drillable:
			return reg.item_index(def.yield_item)
	return -1


func _tick_drill(b: Building, dt: float) -> void:
	if b.held < 0:
		b.progress += dt / b.def.mining_time
		if b.progress < 1.0:
			return
		b.progress = 0.0
		b.held = drill_yield(b.cells)
		if b.held < 0:
			return
		produced[b.held] += 1
	# Try every tile along the output side, rotating the start for fairness.
	var tiles := front_tiles(b)
	for k in tiles.size():
		var i := (b.output_cursor + k) % tiles.size()
		if output_to_tile(tiles[i], b.held, b):
			b.held = -1
			b.last_out_tick = now
			b.last_out_tile = tiles[i]
			b.output_cursor = (i + 1) % tiles.size()
			return


# --- Crafters ----------------------------------------------------------------

func _tick_crafter(b: Building, dt: float) -> void:
	var recipe := b.def.recipe
	if not b.crafting:
		var outs := _outputs(recipe)
		var held := 0
		for item in b.inv_out:
			held += b.inv_out[item]
		var produce := 0
		for item in outs:
			produce += outs[item]
		if held + produce > b.def.output_limit:
			return
		var ins := _inputs(recipe)
		for item in ins:
			if b.inv_in.get(item, 0) < ins[item]:
				return
		for item in ins:
			b.inv_in[item] -= ins[item]
		b.crafting = true
		b.progress = 0.0
	b.progress += dt / recipe.time
	if b.progress >= 1.0:
		var outs := _outputs(recipe)
		for item in outs:
			b.inv_out[item] = b.inv_out.get(item, 0) + outs[item]
			produced[item] += outs[item]
		b.crafting = false
		b.progress = 0.0


# --- Inserters ---------------------------------------------------------------

func _tick_inserter(b: Building, dt: float) -> void:
	var d := BeltNetwork.DIRS[b.rotation % 4]
	var from_cell := b.origin - d
	var to_cell := b.origin + d
	if not grid.in_bounds(from_cell.x, from_cell.y) or not grid.in_bounds(to_cell.x, to_cell.y):
		return
	var from_tile := grid.idx(from_cell.x, from_cell.y)
	var to_tile := grid.idx(to_cell.x, to_cell.y)
	if b.held >= 0:
		b.progress += dt / b.def.swing_time
		if b.progress >= 1.0:
			b.progress = 1.0
			if output_to_tile(to_tile, b.held, b):
				b.held = -1
				b.progress = 0.0
				b.last_out_tick = now
		return
	var accept := func(item: int) -> bool: return can_accept_at_tile(to_tile, item, b)
	var item := -1
	if belts.has_belt(from_tile):
		item = belts.take_from_tile(from_tile, accept)
	else:
		var src := _building_at(from_tile)
		if src != null and src.is_active():
			item = _take_output(src, accept)
	if item >= 0:
		b.held = item
		b.progress = 0.0
		b.last_in_tick = now


# --- Item transfer -----------------------------------------------------------

## Can [param tile] take [param item] right now? [param from] is excluded so a
## building never feeds itself.
func can_accept_at_tile(tile: int, item: int, from: Building = null) -> bool:
	if belts.has_belt(tile):
		return belts.can_insert_at_tile(tile)
	var b := _building_at(tile)
	return b != null and b != from and accepts(b, item)


## Delivers [param item] to [param tile] (belt or building). Returns false if it can't.
func output_to_tile(tile: int, item: int, from: Building = null) -> bool:
	if tile < 0:
		return false
	if belts.has_belt(tile):
		return belts.insert_at_tile(tile, item)
	var b := _building_at(tile)
	if b == null or b == from or not accepts(b, item):
		return false
	give(b, item)
	return true


func accepts(b: Building, item: int) -> bool:
	if not b.is_active():
		return false
	if b.def.kind == &"crafter":
		var need: int = _inputs(b.def.recipe).get(item, 0)
		return need > 0 and b.inv_in.get(item, 0) + need <= maxi(b.def.input_limit, need)
	if b.def.tower != null:
		var t := b.def.tower
		return reg.item_index(t.ammo_item) == item and b.ammo + t.rounds_per_item <= t.magazine_size
	return false


func give(b: Building, item: int) -> void:
	b.last_in_tick = now
	if b.def.tower != null:
		b.ammo += b.def.tower.rounds_per_item
	else:
		b.inv_in[item] = b.inv_in.get(item, 0) + 1


func _take_output(b: Building, accept: Callable) -> int:
	for item: int in b.inv_out:
		if b.inv_out[item] > 0 and accept.call(item):
			b.inv_out[item] -= 1
			b.last_out_tick = now
			return item
	return -1


func _building_at(tile: int) -> Building:
	if tile < 0:
		return null
	return buildings.get(occupancy[tile])


## All tiles along the output (front) side of a building, e.g. both tiles in
## front of a 2x2 drill. Tiles outside the map are skipped.
func front_tiles(b: Building) -> PackedInt32Array:
	var out := PackedInt32Array()
	var s := b.size()
	var d := BeltNetwork.DIRS[b.rotation % 4]
	var cells: Array[Vector2i] = []
	match b.rotation % 4:
		0:
			for y in s.y:
				cells.append(Vector2i(b.origin.x + s.x, b.origin.y + y))
		1:
			for x in s.x:
				cells.append(Vector2i(b.origin.x + x, b.origin.y + s.y))
		2:
			for y in s.y:
				cells.append(Vector2i(b.origin.x - 1, b.origin.y + y))
		_:
			for x in s.x:
				cells.append(Vector2i(b.origin.x + x, b.origin.y - 1))
	for c in cells:
		if grid.in_bounds(c.x, c.y):
			out.append(grid.idx(c.x, c.y))
	return out


## First tile in front of a building's output side.
func front_tile(b: Building) -> int:
	var s := b.size()
	var c: Vector2i
	match b.rotation % 4:
		0:
			c = Vector2i(b.origin.x + s.x, b.origin.y + (s.y - 1) / 2)
		1:
			c = Vector2i(b.origin.x + (s.x - 1) / 2, b.origin.y + s.y)
		2:
			c = Vector2i(b.origin.x - 1, b.origin.y + (s.y - 1) / 2)
		_:
			c = Vector2i(b.origin.x + (s.x - 1) / 2, b.origin.y - 1)
	return grid.idx(c.x, c.y) if grid.in_bounds(c.x, c.y) else -1


func _inputs(recipe: RecipeDef) -> Dictionary:
	if not _recipe_in.has(recipe):
		_recipe_in[recipe] = _resolve(recipe.inputs)
	return _recipe_in[recipe]


func _outputs(recipe: RecipeDef) -> Dictionary:
	if not _recipe_out.has(recipe):
		_recipe_out[recipe] = _resolve(recipe.outputs)
	return _recipe_out[recipe]


func _resolve(map: Dictionary) -> Dictionary:
	var out := {}
	for id in map:
		out[reg.item_index(StringName(id))] = int(map[id])
	return out
