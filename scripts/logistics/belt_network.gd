class_name BeltNetwork
extends RefCounted
## All conveyor belts, organised as transport lines (ADR-005).
##
## A line is a chain of belt tiles; its items are stored as ascending positions
## (distance from the line start, in tiles) so the last entry is the front.
## Lines are rebuilt lazily after the belt layout changes; items keep their
## tile and offset across rebuilds.

const SPACING := 0.25
const EPS := 0.0001
## Rotation -> direction (0 = east, 1 = south, 2 = west, 3 = north).
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
## Tunnel roles.
const ROLE_BELT := 0
const ROLE_TUNNEL_IN := 1
const ROLE_TUNNEL_OUT := 2
## Max tiles between a tunnel entrance and its exit.
const TUNNEL_MAX_GAP := 4


class Line:
	extends RefCounted
	## Tile indices, upstream -> downstream.
	var tiles := PackedInt32Array()
	## Item centre positions along the line, ascending (last = front).
	var pos := PackedFloat32Array()
	## Item indices, parallel to [member pos].
	var items := PackedInt32Array()
	## Line that receives items leaving the front (-1 = dead end).
	var out_line: int = -1
	## Position in [member out_line] where items enter.
	var out_offset: float = 0.0
	## Dead-end line pointing into a non-belt tile: items are offered to [member BeltNetwork.sink].
	var sink_tile: int = -1
	## Tile centres and unit directions, parallel to [member tiles], plus the
	## line's bounding box (tile units). Precomputed for drawing.
	var centers := PackedVector2Array()
	var dirs := PackedVector2Array()
	var bounds := Rect2()


var grid: WorldGrid
## Belt speed in tiles per second.
var speed: float = 1.875
## Tile -> rotation of every active belt.
var dir_of: Dictionary = {}
## Tile -> ROLE_TUNNEL_IN / ROLE_TUNNEL_OUT for tunnel tiles (plain belts absent).
var role_of: Dictionary = {}
## Receives items from lines that end pointing into a non-belt tile:
## func(tile: int, item: int) -> bool (true = accepted). Set by GameSim.
var sink: Callable
var lines: Array[Line] = []
## Tile -> index of its line (-1 = no belt).
var line_at := PackedInt32Array()
## Tile -> position of the tile within its line.
var index_at := PackedInt32Array()

var _dirty := false


func _init(world: WorldGrid) -> void:
	grid = world
	line_at.resize(grid.size())
	line_at.fill(-1)
	index_at.resize(grid.size())
	index_at.fill(0)


# --- Layout ------------------------------------------------------------------

func add_belt(tile: int, rotation: int, role: int = ROLE_BELT) -> void:
	dir_of[tile] = rotation % 4
	if role == ROLE_BELT:
		role_of.erase(tile)
	else:
		role_of[tile] = role
	_dirty = true


## Removes a belt; items on that tile are lost.
func remove_belt(tile: int) -> void:
	role_of.erase(tile)
	if dir_of.erase(tile):
		_dirty = true


## Exit tile paired with tunnel entrance [param tile], or -1.
func tunnel_exit(tile: int) -> int:
	if role_of.get(tile, ROLE_BELT) != ROLE_TUNNEL_IN:
		return -1
	var rot: int = dir_of[tile]
	var cur := tile
	for k in TUNNEL_MAX_GAP + 1:
		cur = neighbor(cur, rot)
		if cur < 0:
			return -1
		if dir_of.get(cur, -1) == rot:
			var role: int = role_of.get(cur, ROLE_BELT)
			if role == ROLE_TUNNEL_OUT:
				return cur
			if role == ROLE_TUNNEL_IN:
				return -1
	return -1


func has_belt(tile: int) -> bool:
	return dir_of.has(tile)


func neighbor(tile: int, rotation: int) -> int:
	var c := grid.cell_of(tile) + DIRS[rotation % 4]
	return grid.idx(c.x, c.y) if grid.in_bounds(c.x, c.y) else -1


func ensure_built() -> void:
	if _dirty:
		_rebuild()


func _rebuild() -> void:
	_dirty = false
	# Remember items by tile so they survive the rebuild.
	var saved_tiles := PackedInt32Array()
	var saved_frac := PackedFloat32Array()
	var saved_items := PackedInt32Array()
	for line in lines:
		var count := line.tiles.size()
		for k in line.items.size():
			var ti := clampi(int(line.pos[k]), 0, count - 1)
			var t := line.tiles[ti]
			if dir_of.has(t):
				saved_tiles.append(t)
				saved_frac.append(clampf(line.pos[k] - ti, 0.0, 1.0 - EPS))
				saved_items.append(line.items[k])
		for t in line.tiles:
			line_at[t] = -1
	lines.clear()

	var tiles: Array = dir_of.keys()
	tiles.sort()  # Deterministic line construction.
	var succ: Dictionary = {}
	var feeders: Dictionary = {}
	for t: int in tiles:
		var rot: int = dir_of[t]
		var s := neighbor(t, rot)
		if role_of.get(t, ROLE_BELT) == ROLE_TUNNEL_IN:
			s = tunnel_exit(t)  # Items pass under whatever is in between.
		if s >= 0 and dir_of.has(s) and (int(dir_of[s]) + 2) % 4 != rot:
			succ[t] = s
			if not feeders.has(s):
				feeders[s] = []
			feeders[s].append(t)
	# A belt continues the line of the belt behind it, or of a single side feeder (curve).
	var line_pred: Dictionary = {}
	for t: int in tiles:
		if not feeders.has(t):
			continue
		var f: Array = feeders[t]
		var back := neighbor(t, (int(dir_of[t]) + 2) % 4)
		var tunnel_in := -1
		for src in f:
			if role_of.get(src, ROLE_BELT) == ROLE_TUNNEL_IN:
				tunnel_in = src
		if role_of.get(t, ROLE_BELT) == ROLE_TUNNEL_OUT and tunnel_in >= 0:
			line_pred[t] = tunnel_in
		elif f.has(back):
			line_pred[t] = back
		elif f.size() == 1:
			line_pred[t] = f[0]
	# Walk chains: first from proper starts, then whatever is left (loops).
	var visited: Dictionary = {}
	for pass_index in 2:
		for t: int in tiles:
			if visited.has(t) or (pass_index == 0 and line_pred.has(t)):
				continue
			var line := Line.new()
			var li := lines.size()
			var cur := t
			while true:
				visited[cur] = true
				line_at[cur] = li
				index_at[cur] = line.tiles.size()
				line.tiles.append(cur)
				var nx: int = succ.get(cur, -1)
				if nx < 0 or visited.has(nx) or line_pred.get(nx, -1) != cur:
					break
				cur = nx
			lines.append(line)
	for line in lines:
		_cache_geometry(line)
	# Connect line ends: continuation (loop closure) or side-load.
	for line in lines:
		var last := line.tiles[line.tiles.size() - 1]
		var s: int = succ.get(last, -1)
		if s < 0:
			if role_of.get(last, ROLE_BELT) != ROLE_TUNNEL_IN:
				var front := neighbor(last, int(dir_of[last]))
				if front >= 0 and not dir_of.has(front):
					line.sink_tile = front
			continue
		line.out_line = line_at[s]
		line.out_offset = float(index_at[s]) + (0.0 if line_pred.get(s, -1) == last else 0.5)
	for k in saved_items.size():
		var t := saved_tiles[k]
		_insert(lines[line_at[t]], index_at[t] + saved_frac[k], saved_items[k], true)


func _cache_geometry(line: Line) -> void:
	var n := line.tiles.size()
	line.centers.resize(n)
	line.dirs.resize(n)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for k in n:
		var t := line.tiles[k]
		var c := Vector2(grid.cell_of(t)) + Vector2(0.5, 0.5)
		line.centers[k] = c
		line.dirs[k] = Vector2(DIRS[int(dir_of[t])])
		lo = lo.min(c)
		hi = hi.max(c)
	line.bounds = Rect2(lo, hi - lo).grow(0.5)


# --- Simulation --------------------------------------------------------------

func tick(dt: float) -> void:
	ensure_built()
	var step := speed * dt
	for li in lines.size():
		var line := lines[li]
		var pos := line.pos
		if pos.is_empty():
			continue
		var length := float(line.tiles.size())
		var i := pos.size() - 1
		while i >= 0:
			var q := pos[i] + step
			if i == pos.size() - 1:
				if line.out_line >= 0:
					if q >= length:
						if _transfer_front(line, li, q - length):
							i = pos.size() - 1 if line.out_line == li else i - 1
							continue
						q = length - EPS  # Blocked: wait at the edge.
				else:
					var limit := length - SPACING * 0.5  # Dead end: stop on the belt.
					if q >= limit and line.sink_tile >= 0 and sink.is_valid() and sink.call(line.sink_tile, line.items[i]):
						# Delivered into the building the belt points at.
						pos.resize(i)
						line.items.resize(i)
						i -= 1
						continue
					if q > limit:
						q = maxf(limit, pos[i])
			else:
				var cap := pos[i + 1] - SPACING
				if q > cap:
					q = maxf(cap, pos[i])  # Wait behind the item ahead, never move back.
			pos[i] = q
			i -= 1


func _transfer_front(line: Line, li: int, overflow: float) -> bool:
	var target := lines[line.out_line]
	var p := line.out_offset + overflow
	var last := line.pos.size() - 1
	var item := line.items[last]
	if line.out_line == li:
		# Loop: the item wraps to the start of its own line.
		if not _can_insert(target, p, last):
			return false
		line.pos.resize(last)
		line.items.resize(last)
		return _insert(target, p, item)
	if not _can_insert(target, p):
		return false
	line.pos.resize(last)
	line.items.resize(last)
	return _insert(target, p, item)


# --- Item access (drills, inserters) ----------------------------------------

func can_insert_at_tile(tile: int, frac: float = 0.5) -> bool:
	ensure_built()
	var li := line_at[tile]
	return li >= 0 and _can_insert(lines[li], index_at[tile] + frac)


func insert_at_tile(tile: int, item: int, frac: float = 0.5) -> bool:
	ensure_built()
	var li := line_at[tile]
	return li >= 0 and _insert(lines[li], index_at[tile] + frac, item)


## Removes and returns the front-most item on [param tile] that passes
## [param filter] (func(item: int) -> bool), or -1.
func take_from_tile(tile: int, filter: Callable) -> int:
	ensure_built()
	var li := line_at[tile]
	if li < 0:
		return -1
	var line := lines[li]
	var start := float(index_at[tile])
	var k := line.pos.bsearch(start + 1.0) - 1
	while k >= 0 and line.pos[k] >= start:
		var item := line.items[k]
		if filter.call(item):
			line.pos.remove_at(k)
			line.items.remove_at(k)
			return item
		k -= 1
	return -1


func item_count() -> int:
	var n := 0
	for line in lines:
		n += line.items.size()
	return n


## World position (tile units) of item [param k] in [param line].
func item_position(line: Line, k: int) -> Vector2:
	var p := line.pos[k]
	var ti := clampi(int(p), 0, line.tiles.size() - 1)
	return line.centers[ti] + line.dirs[ti] * (p - ti - 0.5)


## [param ignore_last]: the line's front item is about to leave (loop wrap).
func _can_insert(line: Line, p: float, ignore_last: int = -1) -> bool:
	if p < 0.0 or p > float(line.tiles.size()):
		return false
	var pos := line.pos
	var idx := pos.bsearch(p)
	if idx > 0 and idx - 1 != ignore_last and pos[idx - 1] > p - SPACING + EPS:
		return false
	if idx < pos.size() and idx != ignore_last and pos[idx] < p + SPACING - EPS:
		return false
	return true


func _insert(line: Line, p: float, item: int, force: bool = false) -> bool:
	p = clampf(p, 0.0, float(line.tiles.size()) - EPS)
	if not force and not _can_insert(line, p):
		return false
	var idx := line.pos.bsearch(p)
	line.pos.insert(idx, p)
	line.items.insert(idx, item)
	return true
