class_name GameSim
extends RefCounted
## The complete game simulation. Plain data, no Nodes, fully deterministic for
## a given seed and command sequence, runnable headless (ADR-001).
##
## Views read its state; player input calls the command methods
## ([method place], [method sell], [method relocate], [method excavate]),
## which return "" on success or a human-readable reason on failure.

const NEST_SIZE := Vector2i(2, 2)
const CORE_BUFFER := 2
const NEST_BUFFER := 3

const ERR_UNKNOWN := "Unknown building"
const ERR_BOUNDS := "Outside the map"
const ERR_TERRAIN := "Can't build on this terrain"
const ERR_OCCUPIED := "Space is occupied"
const ERR_PROTECTED := "Too close to the Core or a nest"
const ERR_CREDITS := "Not enough credits"
const ERR_ENEMIES := "Too close to enemies"
const ERR_BLOCKS := "Would block the enemy path"
const ERR_NOT_SELLABLE := "Can't be sold"
const ERR_NOT_MOVABLE := "Can't be moved right now"
const ERR_NOT_DIGGABLE := "Nothing to excavate here"
const ERR_GAME_OVER := "Game over"
const ERR_NEEDS_ORE := "Must be placed on ore"
const ERR_NEEDS_WATER := "Must be placed next to water"
const ERR_MATERIALS := "Not enough materials"

var reg: DataRegistry
var rules: GameRules
var grid: WorldGrid
var path: PathMap
var enemies := EnemyStore.new()
var spatial: SpatialHash
var spawner: SpawnDirector
var belts: BeltNetwork
var factory: FactorySystem
var power: PowerSystem
var rng: SimRng
var _spawn_rng: SimRng

var tick_rate: int
var dt: float
var tick_count: int = 0
## Game time in seconds.
var time: float = 0.0

var credits: int
var core_hp: int
var core: Building
## Top-left tiles of the enemy nests.
var nests: Array[Vector2i] = []
var game_over := false

## id -> Building
var buildings: Dictionary = {}
## Tile -> building id (0 = empty).
var occupancy := PackedInt32Array()
## Tile -> ticks left, for pending excavations.
var excavations: Dictionary = {}
## Incremented whenever buildings or excavations change (views redraw on it).
var structures_version: int = 0
## Towers fire without ammunition when true (GameRules.infinite_ammo).
var infinite_ammo := false

## Attack events since the last [method drain_shots], for effects. Each is a
## Dictionary: {k: kind ("shot", "cone", "splash", "pulse", "chain"),
## from/to: Vector2 (tiles), r: radius, a: angle, w: half-angle, pts: PackedVector2Array}.
var shots: Array = []

# Statistics.
var kills: int = 0
var rounds_fired: int = 0
var leaked: int = 0
var credits_earned: int = 0

var _next_building_id := 1
var _towers: Array[Building] = []
var _pending: Array[Building] = []


func _init(registry: DataRegistry, world: WorldGrid, seed_value: int) -> void:
	reg = registry
	rules = registry.rules
	grid = world
	tick_rate = rules.tick_rate
	dt = 1.0 / float(tick_rate)
	rng = SimRng.new(seed_value)
	_spawn_rng = rng.fork("spawn")
	credits = rules.start_credits
	core_hp = rules.core_hp
	occupancy.resize(grid.size())
	occupancy.fill(0)
	path = PathMap.new(grid, reg.walkable_lut)
	path.nodes_per_tick = rules.flow_nodes_per_tick
	spatial = SpatialHash.new(grid.width, grid.height)
	spawner = SpawnDirector.new(reg.spawning, reg.enemies, rng.fork("spawner"))
	infinite_ammo = rules.infinite_ammo
	belts = BeltNetwork.new(grid)
	factory = FactorySystem.new(reg, grid, belts, occupancy, buildings)
	power = PowerSystem.new(reg)
	_place_core()
	for id in rules.start_items:
		add_to_core(reg.item_index(StringName(id)), int(rules.start_items[id]))
	_place_nests()
	path.rebuild_now()


# --- Setup -------------------------------------------------------------------

func _place_core() -> void:
	var def: BuildingDef = reg.buildings_by_id[&"core"]
	var at := Vector2i(3, grid.height / 2 - def.size.y / 2)
	core = _add_building(def, at, 0)
	core.state = Building.State.ACTIVE
	path.goal_cells = core.cells.duplicate()
	path.protect_rect(Rect2i(at, def.size).grow(CORE_BUFFER))


func _place_nests() -> void:
	var x := grid.nest_column - NEST_SIZE.x / 2 if grid.nest_column >= 0 else grid.width - 5
	var spawn := PackedInt32Array()
	for frac in [1.0 / 3.0, 2.0 / 3.0]:
		var at := Vector2i(x, int(grid.height * frac) - NEST_SIZE.y / 2)
		nests.append(at)
		path.protect_rect(Rect2i(at, NEST_SIZE).grow(NEST_BUFFER))
		for dx in NEST_SIZE.x:
			for dy in NEST_SIZE.y:
				spawn.append(grid.idx(at.x + dx, at.y + dy))
	path.spawn_cells = spawn


# --- Tick --------------------------------------------------------------------

## Advances the simulation by one fixed step.
func tick(_tick: int = 0) -> void:
	if game_over:
		return
	tick_count += 1
	time += dt
	spawner.update(time, dt, nests.size(), _spawn_enemy)
	_update_status()
	_move_enemies()
	spatial.rebuild(enemies)
	_progress_construction()
	_progress_excavation()
	factory.now = tick_count
	factory.tick(dt)
	if factory.recycled_credits > 0:
		credits += factory.recycled_credits
		credits_earned += factory.recycled_credits
		factory.recycled_credits = 0
	belts.tick(dt)
	for c in power.consumers:
		c.wants_power = spatial.query(enemies, c.center().x, c.center().y, c.def.tower.range_tiles).size() > 0
	power.tick(dt)
	_fire_towers()
	_cleanup_enemies()
	spatial.rebuild(enemies)  # Indices changed; keep queries between ticks valid.
	path.tick()
	if core_hp <= 0:
		core_hp = 0
		game_over = true


func _spawn_enemy(type_index: int, nest: int, hp_mult: float) -> void:
	var at := nests[nest]
	var tile := grid.idx(at.x + _spawn_rng.next_int_range(0, NEST_SIZE.x - 1), at.y + _spawn_rng.next_int_range(0, NEST_SIZE.y - 1))
	enemies.spawn(type_index, tile, grid, reg.enemies[type_index].hp * hp_mult, _spawn_rng)


var _reached_core := PackedByteArray()


func _move_enemies() -> void:
	var n := enemies.count
	var h := grid.height
	var ex := enemies.x
	var ey := enemies.y
	var cell := enemies.cell
	var nxt := enemies.next
	var pass_arr := path.passable
	var field := path.dist
	_reached_core.resize(n)
	_reached_core.fill(0)
	for i in n:
		enemies.prev_x[i] = ex[i]
		enemies.prev_y[i] = ey[i]
		if enemies.stun_t[i] > 0.0:
			continue
		var step := reg.enemies[enemies.type[i]].speed * enemies.slow[i] * dt
		# Up to two sub-moves so leftover distance carries into the next tile.
		for sub in 2:
			if field[cell[i]] == 0:
				_reached_core[i] = 1
				break
			var target := nxt[i]
			if target < 0 or pass_arr[target] == 0:
				target = path.next_cell(cell[i])
				nxt[i] = target
				if target < 0:
					break  # No route known yet (field updating): wait.
			var tx := float(target / h) + 0.5 + enemies.off_x[i]
			var ty := float(target % h) + 0.5 + enemies.off_y[i]
			var dx := tx - ex[i]
			var dy := ty - ey[i]
			var d := sqrt(dx * dx + dy * dy)
			if d > step:
				ex[i] += dx / d * step
				ey[i] += dy / d * step
				break
			ex[i] = tx
			ey[i] = ty
			step -= d
			cell[i] = target
			nxt[i] = -1


func _progress_construction() -> void:
	if _pending.is_empty():
		return
	var done: Array[Building] = []
	for b in _pending:
		if b.timer > 0:
			b.timer -= 1
		if b.timer > 0:
			continue
		if b.def.blocks_path and _enemy_on_cells(b.cells):
			continue  # Wait until the footprint is clear.
		if b.def.blocks_path:
			for c in b.cells:
				path.set_reserved(c, false)
				path.set_blocked(c, true)
		b.state = Building.State.ACTIVE
		_activate(b)
		done.append(b)
	for b in done:
		_pending.erase(b)
	if not done.is_empty():
		structures_version += 1


func _progress_excavation() -> void:
	if excavations.is_empty():
		return
	var finished := PackedInt32Array()
	for tile: int in excavations:
		excavations[tile] -= 1
		if excavations[tile] <= 0:
			finished.append(tile)
	for tile in finished:
		excavations.erase(tile)
		var c := grid.cell_of(tile)
		var def: TerrainDef = reg.terrain_by_code[grid.get_terrain(c.x, c.y)]
		grid.set_terrain(c.x, c.y, reg.terrain_code(def.becomes))
		path.terrain_changed(tile)
		if def.yield_item != &"":
			add_to_core(reg.item_index(def.yield_item), rules.excavate_stone)
	if not finished.is_empty():
		structures_version += 1


## Ticks status effects: burn damage and effect timers.
func _update_status() -> void:
	var e := enemies
	for i in e.count:
		if e.burn_t[i] > 0.0:
			e.hp[i] -= e.burn_dps[i] * dt
			e.burn_t[i] -= dt
			if e.burn_t[i] <= 0.0:
				e.burn_dps[i] = 0.0
		if e.slow_t[i] > 0.0:
			e.slow_t[i] -= dt
			if e.slow_t[i] <= 0.0:
				e.slow[i] = 1.0
		if e.stun_t[i] > 0.0:
			e.stun_t[i] -= dt


func _fire_towers() -> void:
	var field := path.dist
	for b in _towers:
		if not b.is_active():
			continue
		var tower := b.def.tower
		var electric := tower.power_draw > 0.0
		# Electric towers recharge at the rate their network can supply.
		b.cooldown -= dt * (b.power_satisfaction if electric else 1.0)
		if b.cooldown > 0.0:
			continue
		if electric and b.power_satisfaction <= 0.0:
			b.cooldown = 0.0
			continue
		var uses_ammo := tower.ammo_item != &"" and not infinite_ammo
		if uses_ammo and b.ammo <= 0:
			b.cooldown = 0.0
			continue
		var center := b.center()
		var r := tower.range_tiles
		var t := enemies.index_of(b.target_uid)
		if t >= 0:
			var dx := enemies.x[t] - center.x
			var dy := enemies.y[t] - center.y
			if enemies.hp[t] <= 0.0 or dx * dx + dy * dy > r * r:
				t = -1
		if t < 0:
			t = _pick_target(center, r, tower.targeting, field)
		if t < 0:
			b.target_uid = -1
			b.cooldown = 0.0
			continue
		b.target_uid = enemies.uid[t]
		var to := Vector2(enemies.x[t], enemies.y[t])
		if tower.attack != &"pulse":
			b.aim_angle = (to - center).angle()
		match tower.attack:
			&"cone":
				var half := deg_to_rad(tower.cone_angle) * 0.5
				for i in spatial.query(enemies, center.x, center.y, r):
					var v := Vector2(enemies.x[i], enemies.y[i]) - center
					if absf(angle_difference(b.aim_angle, v.angle())) <= half:
						_hit(b, i, tower.damage)
				shots.append({"k": "cone", "from": center, "a": b.aim_angle, "w": half, "r": r})
			&"splash":
				for i in spatial.query(enemies, to.x, to.y, tower.splash_radius):
					_hit(b, i, tower.damage)
				shots.append({"k": "splash", "from": center, "to": to, "r": tower.splash_radius})
			&"pulse":
				for i in spatial.query(enemies, center.x, center.y, r):
					_hit(b, i, tower.damage)
				shots.append({"k": "pulse", "from": center, "r": r})
			&"chain":
				var pts := PackedVector2Array([center])
				var hit_uids := PackedInt32Array()
				var cur := t
				var dmg := tower.damage
				for jump in tower.chain_count + 1:
					_hit(b, cur, dmg)
					hit_uids.append(enemies.uid[cur])
					var at := Vector2(enemies.x[cur], enemies.y[cur])
					pts.append(at)
					cur = _nearest_unhit(at, tower.chain_range, hit_uids)
					if cur < 0:
						break
					dmg *= tower.chain_falloff
				shots.append({"k": "chain", "pts": pts})
			_:
				_hit(b, t, tower.damage)
				shots.append({"k": "shot", "from": center, "to": to})
		rounds_fired += 1
		b.rounds_fired += 1
		if uses_ammo:
			b.ammo -= 1
		b.cooldown = maxf(b.cooldown, -dt) + 1.0 / tower.fire_rate


## Applies tower damage and status effects to enemy [param i].
func _hit(b: Building, i: int, amount: float) -> void:
	if enemies.hp[i] <= 0.0:
		return
	var tower := b.def.tower
	var armor := reg.enemies[enemies.type[i]].armor
	var dealt := amount
	match tower.damage_type:
		&"armor_piercing", &"fire":
			pass
		&"electric":
			dealt = maxf(amount - armor * 0.5, amount * 0.2)
		_:
			dealt = maxf(amount - armor, amount * 0.2)
	enemies.hp[i] -= dealt
	if enemies.hp[i] <= 0.0:
		b.kills += 1
		return
	if tower.slow_time > 0.0:
		enemies.slow[i] = minf(enemies.slow[i], tower.slow_factor)
		enemies.slow_t[i] = maxf(enemies.slow_t[i], tower.slow_time)
	if tower.burn_time > 0.0:
		enemies.burn_dps[i] = maxf(enemies.burn_dps[i], tower.burn_dps)
		enemies.burn_t[i] = maxf(enemies.burn_t[i], tower.burn_time)
	if tower.stun_time > 0.0:
		enemies.stun_t[i] = maxf(enemies.stun_t[i], tower.stun_time)


func _nearest_unhit(at: Vector2, radius: float, hit_uids: PackedInt32Array) -> int:
	var best := -1
	var best_d := INF
	for i in spatial.query(enemies, at.x, at.y, radius):
		if enemies.hp[i] <= 0.0 or hit_uids.has(enemies.uid[i]):
			continue
		var d := Vector2(enemies.x[i], enemies.y[i]).distance_squared_to(at)
		if d < best_d:
			best = i
			best_d = d
	return best


func _pick_target(center: Vector2, r: float, priority: StringName, field: PackedInt32Array) -> int:
	var best := -1
	var best_score := INF
	for i in spatial.query(enemies, center.x, center.y, r):
		if enemies.hp[i] <= 0.0:
			continue
		var score: float
		match priority:
			&"last":
				score = -float(field[enemies.cell[i]])
			&"strongest":
				score = -enemies.hp[i]
			&"weakest":
				score = enemies.hp[i]
			&"closest":
				score = Vector2(enemies.x[i], enemies.y[i]).distance_squared_to(center)
			_:  # "first": closest to the Core along the path.
				score = float(field[enemies.cell[i]])
		if score < best_score or (score == best_score and enemies.uid[i] < enemies.uid[best]):
			best = i
			best_score = score
	return best


func _cleanup_enemies() -> void:
	for i in range(enemies.count - 1, -1, -1):
		var def: EnemyDef = reg.enemies[enemies.type[i]]
		if enemies.hp[i] <= 0.0:
			kills += 1
			credits += def.reward
			credits_earned += def.reward
			enemies.remove_at(i)
		elif i < _reached_core.size() and _reached_core[i] == 1:
			leaked += 1
			core_hp -= def.core_damage
			enemies.remove_at(i)


# --- Commands ----------------------------------------------------------------

## Checks whether [param def_id] can be placed at [param at]. Returns "" if OK.
## [param moving] is a building being relocated (its own footprint counts as free).
## [param skip_path] skips the route check (cheap previews of long drag lines).
func check_place(def_id: StringName, at: Vector2i, rot: int = 0, moving: Building = null, skip_path: bool = false) -> String:
	if game_over:
		return ERR_GAME_OVER
	if moving == null and _replaceable(def_id, at) != null:
		return ""  # Free re-orientation (see place()).
	var def: BuildingDef = reg.buildings_by_id.get(def_id)
	if def == null or def.id == &"core":
		return ERR_UNKNOWN
	var cells := Building.footprint_cells(grid, def, at, rot)
	for c in cells:
		if c < 0:
			return ERR_BOUNDS
	for c in cells:
		if path.protected[c] == 1:
			return ERR_PROTECTED
		if reg.buildable_lut[grid.terrain[c]] == 0:
			return ERR_TERRAIN
		if excavations.has(c):
			return ERR_OCCUPIED
		var occ := occupancy[c]
		if occ != 0 and (moving == null or occ != moving.id):
			return ERR_OCCUPIED
	if def.kind == &"drill" and factory.drill_yield(cells) < 0:
		return ERR_NEEDS_ORE
	if def.kind == &"pump" and factory.pump_yield(def, at, rot) < 0:
		return ERR_NEEDS_WATER
	if moving == null and credits < def.cost:
		return ERR_CREDITS
	if moving == null and not has_materials(def.material_cost):
		return ERR_MATERIALS
	if _enemies_near(Rect2(at, Building.footprint_size(def, rot))):
		return ERR_ENEMIES
	if def.blocks_path and not skip_path:
		var freed := PackedInt32Array()
		if moving != null and moving.def.blocks_path:
			for c in moving.cells:
				if not cells.has(c):
					freed.append(c)
		if not path.can_block(cells, _enemy_cells(), freed):
			return ERR_BLOCKS
	return ""


## Places a new structure (pays its cost). Returns "" on success.
## Placing a belt or arm over the same kind re-orients it for free.
func place(def_id: StringName, at: Vector2i, rot: int = 0) -> String:
	var existing := _replaceable(def_id, at)
	if existing != null and not game_over:
		return _reorient(existing, rot)
	var err := check_place(def_id, at, rot)
	if err != "":
		return err
	var def: BuildingDef = reg.buildings_by_id[def_id]
	credits -= def.cost
	take_materials(def.material_cost)
	var b := _add_building(def, at, rot)
	b.invested = def.cost
	b.invested_materials = def.material_cost.duplicate()
	if def.tower != null:
		b.ammo = def.tower.starter_ammo
	b.state = Building.State.CONSTRUCTING
	b.timer = ceili(def.build_time * tick_rate)
	if def.blocks_path:
		for c in b.cells:
			path.set_reserved(c, true)
	_pending.append(b)
	return ""


## Existing 1x1 directional building of the same type at [param at] (belts,
## arms) that a new placement would simply re-orient, or null.
func _replaceable(def_id: StringName, at: Vector2i) -> Building:
	var b := building_at(at)
	if b == null or b.def.id != def_id or not b.def.directional or b.def.size != Vector2i.ONE:
		return null
	return b


func _reorient(b: Building, rot: int) -> String:
	rot = posmod(rot, 4)
	if b.rotation == rot:
		return ""
	b.rotation = rot
	if b.def.kind == &"belt" and b.is_active():
		belts.add_belt(b.cells[0], rot)  # Items on the tile are kept.
	structures_version += 1
	return ""


# --- Stockpile (Core + Storage) ---------------------------------------------

## Buildings whose contents form the stockpile, Core first.
func stockpile_buildings() -> Array[Building]:
	var out: Array[Building] = [core]
	for b: Building in buildings.values():
		if b.def.kind == &"storage" and b.is_active():
			out.append(b)
	return out


## Count of [param item] (index) in the stockpile.
func stock(item: int) -> int:
	var n := 0
	for b in stockpile_buildings():
		n += b.inv_out.get(item, 0)
	return n


func add_to_core(item: int, count: int) -> void:
	if item < 0 or count <= 0:
		return
	core.inv_out[item] = core.inv_out.get(item, 0) + count


## True if the stockpile holds every item in [param cost] (item id -> count).
func has_materials(cost: Dictionary) -> bool:
	for id in cost:
		if stock(reg.item_index(StringName(id))) < int(cost[id]):
			return false
	return true


## Removes [param cost] from the stockpile (Core first). Call has_materials first.
func take_materials(cost: Dictionary) -> void:
	for id in cost:
		var item := reg.item_index(StringName(id))
		var left := int(cost[id])
		for b in stockpile_buildings():
			var have: int = b.inv_out.get(item, 0)
			var take := mini(have, left)
			if take > 0:
				b.inv_out[item] = have - take
				if b.inv_out[item] == 0:
					b.inv_out.erase(item)
				left -= take
			if left == 0:
				break


## Missing materials for [param def] as "3 Steel, 5 Brick" ("" if affordable).
func missing_materials(def: BuildingDef) -> String:
	var parts := PackedStringArray()
	for id in def.material_cost:
		var item := reg.item_index(StringName(id))
		var short := int(def.material_cost[id]) - stock(item)
		if short > 0:
			parts.append("%d %s" % [short, reg.items[item].display_name])
	return ", ".join(parts)


## Switches a crafter's recipe. Buffered inputs go back to the Core.
func set_recipe(id: int, index: int) -> String:
	var b: Building = buildings.get(id)
	if b == null or b.def.recipes.is_empty():
		return ERR_UNKNOWN
	index = posmod(index, b.def.recipes.size())
	if index == b.recipe_index:
		return ""
	for item: int in b.inv_in:
		add_to_core(item, b.inv_in[item])
	b.inv_in.clear()
	b.crafting = false
	b.progress = 0.0
	b.recipe_index = index
	structures_version += 1
	return ""


## Ends the preparation phase now; enemies start spawning immediately.
func skip_preparation() -> void:
	spawner.skip_preparation(time)


func in_preparation() -> bool:
	return spawner.in_preparation(time)


## Credits returned if [param b] is sold now.
func sell_value(b: Building) -> int:
	if tick_count - b.placed_tick <= int(rules.undo_window * tick_rate):
		return b.invested
	return floori(b.invested * rules.sell_refund)


func relocate_fee(b: Building) -> int:
	return ceili(b.invested * rules.relocate_fee)


func sell(id: int) -> String:
	if game_over:
		return ERR_GAME_OVER
	var b: Building = buildings.get(id)
	if b == null or not b.def.sellable:
		return ERR_NOT_SELLABLE
	if _enemies_near(Rect2(b.origin, b.size())):
		return ERR_ENEMIES
	var full := sell_value(b) == b.invested
	credits += sell_value(b)
	for mat in b.invested_materials:
		var n: int = b.invested_materials[mat]
		add_to_core(reg.item_index(StringName(mat)), n if full else floori(n * rules.sell_refund))
	# Contents of storages and crafters go back to the Core instead of vanishing.
	if b.def.kind != &"core":
		for item: int in b.inv_in:
			add_to_core(item, b.inv_in[item])
		for item: int in b.inv_out:
			add_to_core(item, b.inv_out[item])
	_vacate(b)
	buildings.erase(id)
	_towers.erase(b)
	_pending.erase(b)
	structures_version += 1
	return ""


## Moves an active structure to [param at] for a fee; it is offline while it redeploys.
func relocate(id: int, at: Vector2i, rot: int = 0) -> String:
	if game_over:
		return ERR_GAME_OVER
	var b: Building = buildings.get(id)
	if b == null or not b.def.relocatable or not b.is_active():
		return ERR_NOT_MOVABLE
	var fee := relocate_fee(b)
	if credits < fee:
		return ERR_CREDITS
	if _enemies_near(Rect2(b.origin, b.size())):
		return ERR_ENEMIES
	var err := check_place(b.def.id, at, rot, b)
	if err != "":
		return err
	credits -= fee
	_vacate(b)
	b.origin = at
	b.rotation = rot
	b.cells = Building.footprint_cells(grid, b.def, at, rot)
	for c in b.cells:
		occupancy[c] = b.id
		if b.def.blocks_path:
			path.set_reserved(c, true)
	b.state = Building.State.RELOCATING
	b.timer = ceili(rules.relocate_time * tick_rate)
	b.target_uid = -1
	_pending.append(b)
	structures_version += 1
	return ""


func check_excavate(cell: Vector2i) -> String:
	if game_over:
		return ERR_GAME_OVER
	if not grid.in_bounds(cell.x, cell.y):
		return ERR_BOUNDS
	var tile := grid.idx(cell.x, cell.y)
	var def: TerrainDef = reg.terrain_by_code[grid.terrain[tile]]
	if def == null or not def.destructible or excavations.has(tile):
		return ERR_NOT_DIGGABLE
	if credits < rules.excavate_cost:
		return ERR_CREDITS
	if _enemies_near(Rect2(cell, Vector2.ONE)):
		return ERR_ENEMIES
	return ""


## Orders a rock tile to be excavated (opens a new route after a delay).
func excavate(cell: Vector2i) -> String:
	var err := check_excavate(cell)
	if err != "":
		return err
	credits -= rules.excavate_cost
	excavations[grid.idx(cell.x, cell.y)] = ceili(rules.excavate_time * tick_rate)
	structures_version += 1
	return ""


func building_at(cell: Vector2i) -> Building:
	if not grid.in_bounds(cell.x, cell.y):
		return null
	return buildings.get(occupancy[grid.idx(cell.x, cell.y)])


# --- Helpers -----------------------------------------------------------------

func _add_building(def: BuildingDef, at: Vector2i, rot: int) -> Building:
	var b := Building.new()
	b.id = _next_building_id
	_next_building_id += 1
	b.def = def
	b.origin = at
	b.rotation = rot
	b.placed_tick = tick_count
	b.cells = Building.footprint_cells(grid, def, at, rot)
	for c in b.cells:
		occupancy[c] = b.id
	buildings[b.id] = b
	if def.tower != null:
		_towers.append(b)
	structures_version += 1
	return b


## A building finished construction or redeployment and starts working.
func _activate(b: Building) -> void:
	if b.def.kind == &"belt":
		belts.add_belt(b.cells[0], b.rotation)
	factory.register(b)
	power.register(b)


## Frees the footprint of [param b] in occupancy and the path layers.
func _vacate(b: Building) -> void:
	if b.is_active():
		if b.def.kind == &"belt":
			belts.remove_belt(b.cells[0])
		factory.unregister(b)
		power.unregister(b)
	for c in b.cells:
		occupancy[c] = 0
		if b.def.blocks_path:
			if b.state == Building.State.ACTIVE:
				path.set_blocked(c, false)
			else:
				path.set_reserved(c, false)
	_pending.erase(b)


func _enemies_near(rect: Rect2) -> bool:
	if rules.no_build_radius <= 0.0:
		return false
	return spatial.any_near_rect(enemies, rect, rules.no_build_radius)


func _enemy_cells() -> PackedInt32Array:
	var out := enemies.cell.duplicate()
	for c in enemies.next:
		if c >= 0:
			out.append(c)
	return out


func _enemy_on_cells(cells: PackedInt32Array) -> bool:
	for i in enemies.count:
		if cells.has(enemies.cell[i]) or cells.has(enemies.next[i]):
			return true
	return false


## Items currently in the factory (belts, machine buffers, hands), by item index.
func item_totals() -> PackedInt32Array:
	var totals := PackedInt32Array()
	totals.resize(reg.items.size())
	totals.fill(0)
	belts.ensure_built()
	for line in belts.lines:
		for item in line.items:
			totals[item] += 1
	for b: Building in buildings.values():
		for item: int in b.inv_in:
			totals[item] += b.inv_in[item]
		for item: int in b.inv_out:
			totals[item] += b.inv_out[item]
		if b.held >= 0:
			totals[b.held] += 1
	return totals


## Ammo summary over all towers that use ammo: [loaded, capacity, empty, low].
func ammo_summary() -> PackedInt32Array:
	var loaded := 0
	var capacity := 0
	var empty := 0
	var low := 0
	for b in _towers:
		var t := b.def.tower
		if t.ammo_item == &"" or b.state == Building.State.CONSTRUCTING:
			continue
		loaded += b.ammo
		capacity += t.magazine_size
		if b.ammo <= 0:
			empty += 1
		elif b.ammo < t.magazine_size / 4:
			low += 1
	return PackedInt32Array([loaded, capacity, empty, low])


## Collects and clears the attack events since the last call (for effects).
func drain_shots() -> Array:
	var out := shots
	shots = []
	return out


## Seconds until the next assault starts (0 while one is running).
func seconds_to_assault() -> float:
	if spawner.is_assault_active():
		return 0.0
	return maxf(0.0, spawner.next_assault_at - time)


## Compact fingerprint of the simulation state (determinism tests).
func state_hash() -> int:
	return hash([tick_count, credits, core_hp, kills, leaked, enemies.count, enemies.uid, enemies.x, enemies.y, enemies.hp, buildings.size(), path.version])
