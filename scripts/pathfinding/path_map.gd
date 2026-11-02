class_name PathMap
extends RefCounted
## Enemy pathing state: passability layers, the shared flow field and route
## validation. See docs/decisions/ADR-004-flow-field-and-route-validation.md.
##
## All per-tile layers are column-major packed arrays matching [WorldGrid].
## Note: in Godot 4 packed arrays are shared by reference, so local aliases
## below write straight into the members.

## Ring around a tile in circular order (N, NE, E, SE, S, SW, W, NW).
## Consecutive entries are 4-adjacent, which the simple-tile test relies on.
const RING := [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]

var grid: WorldGrid
var walkable_lut: PackedByteArray

## 1 where a completed blocking structure stands.
var blocked := PackedByteArray()
## 1 where a blocking structure is pending (construction / relocation target).
var reserved := PackedByteArray()
## 1 where nothing may be built (Core, nests and their buffers).
var protected := PackedByteArray()
## Derived: enemies can walk here now.
var passable := PackedByteArray()
## Derived: passable once all pending structures complete.
var plan_passable := PackedByteArray()

## Tiles enemies are trying to reach (Core footprint).
var goal_cells := PackedInt32Array()
## Tiles enemies spawn on (nest footprints). Must always reach a goal.
var spawn_cells := PackedInt32Array()

## Current flow field: BFS steps to the nearest goal tile, -1 = unreachable.
var dist := PackedInt32Array()
## Increments every time a new flow field is swapped in.
var version: int = 0
## Tiles processed per tick by the background recompute.
var nodes_per_tick: int = 12000

var _dirty := false
var _job_running := false
var _job_dist := PackedInt32Array()
var _job_queue := PackedInt32Array()
var _job_head := 0
var _job_tail := 0


func _init(world: WorldGrid, lut: PackedByteArray) -> void:
	grid = world
	walkable_lut = lut
	var n := grid.size()
	blocked.resize(n)
	blocked.fill(0)
	reserved.resize(n)
	reserved.fill(0)
	protected.resize(n)
	protected.fill(0)
	passable.resize(n)
	plan_passable.resize(n)
	for i in n:
		refresh_cell(i)


# --- Layer updates -----------------------------------------------------------

## Recomputes the derived layers of one tile. Call after any change to
## terrain, [member blocked] or [member reserved] at that tile.
func refresh_cell(i: int) -> void:
	var p := 1 if walkable_lut[grid.terrain[i]] == 1 and blocked[i] == 0 else 0
	passable[i] = p
	plan_passable[i] = 1 if p == 1 and reserved[i] == 0 else 0


func set_blocked(i: int, value: bool) -> void:
	blocked[i] = 1 if value else 0
	refresh_cell(i)
	_dirty = true


func set_reserved(i: int, value: bool) -> void:
	reserved[i] = 1 if value else 0
	refresh_cell(i)


## Terrain at [param i] changed (e.g. excavation).
func terrain_changed(i: int) -> void:
	refresh_cell(i)
	_dirty = true


## Marks a rectangle (clamped to the map) as protected.
func protect_rect(rect: Rect2i) -> void:
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			if grid.in_bounds(x, y):
				protected[grid.idx(x, y)] = 1


# --- Flow field --------------------------------------------------------------

## Computes the flow field synchronously (startup, tests).
func rebuild_now() -> void:
	_start_job()
	while _job_running:
		_step_job(1 << 30)
	_dirty = false


func mark_dirty() -> void:
	_dirty = true


func is_updating() -> bool:
	return _dirty or _job_running


## Advances a pending recompute by [member nodes_per_tick] tiles. Call once per tick.
func tick() -> void:
	if not _job_running:
		if not _dirty:
			return
		_dirty = false
		_start_job()
	_step_job(nodes_per_tick)


func _start_job() -> void:
	var n := grid.size()
	_job_dist.resize(n)
	_job_dist.fill(-1)
	_job_queue.resize(n)
	_job_head = 0
	_job_tail = 0
	for g in goal_cells:
		if _job_dist[g] == -1:
			_job_dist[g] = 0
			_job_queue[_job_tail] = g
			_job_tail += 1
	_job_running = true


func _step_job(budget: int) -> void:
	var h := grid.height
	var n := grid.size()
	var pass_arr := passable
	var d := _job_dist
	var q := _job_queue
	var head := _job_head
	var tail := _job_tail
	var stop := mini(head + budget, n)
	while head < tail and head < stop:
		var c := q[head]
		head += 1
		var nd := d[c] + 1
		var y := c % h
		var nb := c - 1
		if y > 0 and d[nb] == -1 and pass_arr[nb] == 1:
			d[nb] = nd
			q[tail] = nb
			tail += 1
		nb = c + 1
		if y < h - 1 and d[nb] == -1 and pass_arr[nb] == 1:
			d[nb] = nd
			q[tail] = nb
			tail += 1
		nb = c - h
		if nb >= 0 and d[nb] == -1 and pass_arr[nb] == 1:
			d[nb] = nd
			q[tail] = nb
			tail += 1
		nb = c + h
		if nb < n and d[nb] == -1 and pass_arr[nb] == 1:
			d[nb] = nd
			q[tail] = nb
			tail += 1
	_job_head = head
	_job_tail = tail
	if head >= tail:
		_job_running = false
		# Swap: the finished buffer becomes the live field, the old one is reused.
		var old := dist
		dist = _job_dist
		_job_dist = old
		version += 1


## Best next tile from [param c] following [param field] (8-directional, no
## corner cutting). Returns -1 if [param c] is unreachable or a goal.
func next_cell(c: int, field: PackedInt32Array = dist) -> int:
	var h := grid.height
	var n := grid.size()
	var here := field[c]
	if here <= 0:
		return -1
	var y := c % h
	var best := -1
	var best_d := here
	# Orthogonal neighbours; remember which are open for the diagonal check.
	var up := y > 0 and passable[c - 1] == 1
	var down := y < h - 1 and passable[c + 1] == 1
	var left := c - h >= 0 and passable[c - h] == 1
	var right := c + h < n and passable[c + h] == 1
	if up and field[c - 1] >= 0 and field[c - 1] < best_d:
		best = c - 1
		best_d = field[best]
	if down and field[c + 1] >= 0 and field[c + 1] < best_d:
		best = c + 1
		best_d = field[best]
	if left and field[c - h] >= 0 and field[c - h] < best_d:
		best = c - h
		best_d = field[best]
	if right and field[c + h] >= 0 and field[c + h] < best_d:
		best = c + h
		best_d = field[best]
	# Diagonals only when both adjacent orthogonals are open, and only if they
	# save a step (distance drops by 2) - keeps movement smooth along walls.
	var diag := PackedInt32Array()
	if up and left:
		diag.append(c - h - 1)
	if up and right:
		diag.append(c + h - 1)
	if down and left:
		diag.append(c - h + 1)
	if down and right:
		diag.append(c + h + 1)
	for nb in diag:
		if passable[nb] == 1 and field[nb] >= 0 and field[nb] <= here - 2 and field[nb] < best_d:
			best = nb
			best_d = field[nb]
	return best


## Follows [param field] from [param start] to a goal. Returns tile indices
## (start first). Stops after [param max_steps] or at a dead end.
func trace(start: int, field: PackedInt32Array = dist, max_steps: int = 4096) -> PackedInt32Array:
	var out := PackedInt32Array()
	var c := start
	if c < 0 or field[c] < 0:
		return out
	out.append(c)
	for i in max_steps:
		c = next_cell(c, field)
		if c < 0:
			break
		out.append(c)
	return out


# --- Route validation --------------------------------------------------------

## True if blocking all [param cells] keeps every spawn tile and every tile in
## [param must_reach] connected to a goal. [param freed] tiles are treated as
## open (for relocation, where the old footprint is vacated). Uses the fast
## local test when possible, otherwise a full BFS on [member plan_passable].
func can_block(cells: PackedInt32Array, must_reach: PackedInt32Array = PackedInt32Array(), freed: PackedInt32Array = PackedInt32Array()) -> bool:
	for c in cells:
		if goal_cells.has(c) or spawn_cells.has(c):
			return false
	var pp := plan_passable
	# Temporarily apply the change.
	var saved_freed := PackedByteArray()
	for f in freed:
		saved_freed.append(pp[f])
		pp[f] = walkable_lut[grid.terrain[f]]
	var saved_cells := PackedByteArray()
	for c in cells:
		saved_cells.append(pp[c])
	var ok := true
	var need_full := freed.size() > 0
	if not need_full:
		for c in cells:
			if pp[c] == 1 and not _is_simple(c):
				need_full = true
				break
			pp[c] = 0
	else:
		for c in cells:
			pp[c] = 0
	if need_full:
		for c in cells:
			pp[c] = 0
		ok = _all_reach_goal(pp, must_reach)
	# Restore.
	for k in cells.size():
		pp[cells[k]] = saved_cells[k]
	for k in freed.size():
		pp[freed[k]] = saved_freed[k]
	return ok


## Distance field over [member plan_passable] with [param cells] blocked
## (used for the "what if" path preview). Does not modify any layer.
func preview_field(cells: PackedInt32Array) -> PackedInt32Array:
	var pp := plan_passable.duplicate()
	for c in cells:
		pp[c] = 0
	return _bfs(pp)


## The local "simple tile" test: blocking [param c] cannot disconnect anything
## if all its open orthogonal neighbours are linked through the open ring.
func _is_simple(c: int) -> bool:
	var cell := grid.cell_of(c)
	var open: Array[bool] = []
	var any_open := false
	for off: Vector2i in RING:
		var x := cell.x + off.x
		var y := cell.y + off.y
		var o := grid.in_bounds(x, y) and plan_passable[grid.idx(x, y)] == 1
		open.append(o)
		any_open = any_open or o
	if not any_open:
		return true
	# Rotate so we start right after a closed tile; then count runs.
	var start := open.find(false)
	if start == -1:
		return true  # Fully open ring: trivially connected.
	var runs_with_orthogonal := 0
	var in_run := false
	var run_has_orth := false
	for k in range(1, 9):
		var j := (start + k) % 8
		if open[j]:
			if not in_run:
				in_run = true
				run_has_orth = false
			if j % 2 == 0:
				run_has_orth = true
		elif in_run:
			in_run = false
			if run_has_orth:
				runs_with_orthogonal += 1
	if in_run and run_has_orth:
		runs_with_orthogonal += 1
	return runs_with_orthogonal <= 1


func _all_reach_goal(pp: PackedByteArray, must_reach: PackedInt32Array) -> bool:
	var d := _bfs(pp)
	for s in spawn_cells:
		if d[s] < 0:
			return false
	for t in must_reach:
		if d[t] < 0:
			return false
	return true


func _bfs(pp: PackedByteArray) -> PackedInt32Array:
	var h := grid.height
	var n := grid.size()
	var d := PackedInt32Array()
	d.resize(n)
	d.fill(-1)
	var q := PackedInt32Array()
	q.resize(n)
	var head := 0
	var tail := 0
	for g in goal_cells:
		if d[g] == -1:
			d[g] = 0
			q[tail] = g
			tail += 1
	while head < tail:
		var c := q[head]
		head += 1
		var nd := d[c] + 1
		var y := c % h
		var nb := c - 1
		if y > 0 and d[nb] == -1 and pp[nb] == 1:
			d[nb] = nd
			q[tail] = nb
			tail += 1
		nb = c + 1
		if y < h - 1 and d[nb] == -1 and pp[nb] == 1:
			d[nb] = nd
			q[tail] = nb
			tail += 1
		nb = c - h
		if nb >= 0 and d[nb] == -1 and pp[nb] == 1:
			d[nb] = nd
			q[tail] = nb
			tail += 1
		nb = c + h
		if nb < n and d[nb] == -1 and pp[nb] == 1:
			d[nb] = nd
			q[tail] = nb
			tail += 1
	return d
