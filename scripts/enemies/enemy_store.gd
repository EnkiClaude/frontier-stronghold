class_name EnemyStore
extends RefCounted
## All living enemies in structure-of-arrays form (ADR-001).
##
## Positions are in tile units (tile (x, y) spans x..x+1). Index order is not
## stable: removal swaps the last enemy into the hole. Use [member uid] to keep
## references across ticks.

var count: int = 0
var uid := PackedInt32Array()
var type := PackedInt32Array()
var x := PackedFloat32Array()
var y := PackedFloat32Array()
## Position at the previous tick (render interpolation).
var prev_x := PackedFloat32Array()
var prev_y := PackedFloat32Array()
## Personal offset inside a tile so crowds spread out.
var off_x := PackedFloat32Array()
var off_y := PackedFloat32Array()
var hp := PackedFloat32Array()
var max_hp := PackedFloat32Array()
## Tile the enemy is currently in, and the tile it is walking to.
var cell := PackedInt32Array()
var next := PackedInt32Array()
## Status effects (ADR-007): slow multiplier and timers in seconds.
var slow := PackedFloat32Array()
var slow_t := PackedFloat32Array()
var burn_dps := PackedFloat32Array()
var burn_t := PackedFloat32Array()
var stun_t := PackedFloat32Array()

var _next_uid: int = 1


func spawn(type_index: int, tile: int, grid: WorldGrid, health: float, rng: SimRng) -> int:
	var c := grid.cell_of(tile)
	var ox := rng.next_float_range(-0.22, 0.22)
	var oy := rng.next_float_range(-0.22, 0.22)
	var px := c.x + 0.5 + ox
	var py := c.y + 0.5 + oy
	var id := _next_uid
	_next_uid += 1
	uid.append(id)
	type.append(type_index)
	x.append(px)
	y.append(py)
	prev_x.append(px)
	prev_y.append(py)
	off_x.append(ox)
	off_y.append(oy)
	hp.append(health)
	max_hp.append(health)
	cell.append(tile)
	next.append(-1)
	slow.append(1.0)
	slow_t.append(0.0)
	burn_dps.append(0.0)
	burn_t.append(0.0)
	stun_t.append(0.0)
	count += 1
	return id


## Removes enemy [param i] by moving the last enemy into its slot.
func remove_at(i: int) -> void:
	var last := count - 1
	if i != last:
		uid[i] = uid[last]
		type[i] = type[last]
		x[i] = x[last]
		y[i] = y[last]
		prev_x[i] = prev_x[last]
		prev_y[i] = prev_y[last]
		off_x[i] = off_x[last]
		off_y[i] = off_y[last]
		hp[i] = hp[last]
		max_hp[i] = max_hp[last]
		cell[i] = cell[last]
		next[i] = next[last]
		slow[i] = slow[last]
		slow_t[i] = slow_t[last]
		burn_dps[i] = burn_dps[last]
		burn_t[i] = burn_t[last]
		stun_t[i] = stun_t[last]
	count = last
	uid.resize(last)
	type.resize(last)
	cell.resize(last)
	next.resize(last)
	x.resize(last)
	y.resize(last)
	prev_x.resize(last)
	prev_y.resize(last)
	off_x.resize(last)
	off_y.resize(last)
	hp.resize(last)
	max_hp.resize(last)
	slow.resize(last)
	slow_t.resize(last)
	burn_dps.resize(last)
	burn_t.resize(last)
	stun_t.resize(last)


## Index of the enemy with [param id], or -1. [param hint] is checked first.
func index_of(id: int, hint: int = -1) -> int:
	if hint >= 0 and hint < count and uid[hint] == id:
		return hint
	return uid.find(id)
