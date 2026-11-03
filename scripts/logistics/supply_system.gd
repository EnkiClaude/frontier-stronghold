class_name SupplySystem
extends RefCounted
## Supply drones (ADR-008): towers that use ammo are refilled automatically
## from the stockpile (Core + Storage). Each request takes up to
## `supply_max_items` items from the nearest stockpile building within
## `supply_range` that has them; a drone flies them over at `drone_speed`.
## Items are reserved at launch; if the tower is gone on arrival they return
## to the Core.


class Drone:
	extends RefCounted
	var tower_id: int
	var item: int
	var count: int
	var pos: Vector2
	var target: Vector2


var drones: Array[Drone] = []
## Lifetime number of deliveries (stats/tests).
var deliveries: int = 0

var _timer := 0.0
var _in_flight := {}  # tower id -> true


func tick(sim: GameSim, dt: float) -> void:
	_move(sim, dt)
	_timer -= dt
	if _timer > 0.0:
		return
	_timer += sim.rules.supply_interval
	if sim.infinite_ammo:
		return
	for b in sim.towers():
		if not b.is_active() or _in_flight.has(b.id):
			continue
		var t := b.def.tower
		if t.ammo_item == &"" or t.rounds_per_item <= 0:
			continue
		var room := (t.magazine_size - b.ammo) / t.rounds_per_item
		if room <= 0:
			continue
		var item := sim.reg.item_index(t.ammo_item)
		var src := nearest_source(sim, b, item)
		if src == null:
			continue
		var n := mini(mini(room, sim.rules.supply_max_items), src.inv_out[item])
		src.inv_out[item] -= n
		if src.inv_out[item] == 0:
			src.inv_out.erase(item)
		var d := Drone.new()
		d.tower_id = b.id
		d.item = item
		d.count = n
		d.pos = src.center()
		d.target = b.center()
		drones.append(d)
		_in_flight[b.id] = true


## Nearest active Core/Storage within supply range of [param tower] holding [param item].
func nearest_source(sim: GameSim, tower: Building, item: int) -> Building:
	var best: Building = null
	var best_d := sim.rules.supply_range
	for s in sim.stockpile_buildings():
		if not s.is_active() or s.inv_out.get(item, 0) <= 0:
			continue
		var d := s.center().distance_to(tower.center())
		if d <= best_d:
			best = s
			best_d = d
	return best


## Distance (tiles) to the nearest stockpile building of any contents, or INF.
func distance_to_stockpile(sim: GameSim, tower: Building) -> float:
	var best := INF
	for s in sim.stockpile_buildings():
		if s.is_active():
			best = minf(best, s.center().distance_to(tower.center()))
	return best


func is_in_flight(tower_id: int) -> bool:
	return _in_flight.has(tower_id)


func _move(sim: GameSim, dt: float) -> void:
	if drones.is_empty():
		return
	var step := sim.rules.drone_speed * dt
	var arrived: Array[Drone] = []
	for d in drones:
		var tower: Building = sim.buildings.get(d.tower_id)
		if tower != null:
			d.target = tower.center()  # Follow relocated towers.
		var to := d.target - d.pos
		if to.length() <= step:
			d.pos = d.target
			arrived.append(d)
		else:
			d.pos += to.normalized() * step
	for d in arrived:
		drones.erase(d)
		_in_flight.erase(d.tower_id)
		var tower: Building = sim.buildings.get(d.tower_id)
		if tower == null or tower.def.tower == null:
			sim.add_to_core(d.item, d.count)
			continue
		var t := tower.def.tower
		var fit := mini(d.count, maxi(0, (t.magazine_size - tower.ammo) / t.rounds_per_item))
		tower.ammo += fit * t.rounds_per_item
		tower.last_in_tick = sim.tick_count
		sim.add_to_core(d.item, d.count - fit)
		deliveries += 1
