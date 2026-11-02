class_name Reachability
extends RefCounted
## Breadth-first search over the world grid (4-neighbour, uniform cost).
##
## This is the foundation of the Phase 1 flow field: a BFS distance field from
## the Core is exactly the integration field enemies will walk down.

## Returns the step distance from the nearest source for every tile, or -1 for
## tiles that are unreachable or not walkable. [param walkable_lut] maps terrain
## code -> 1/0.
static func distance_field(grid: WorldGrid, walkable_lut: PackedByteArray, sources: PackedInt32Array) -> PackedInt32Array:
	var n := grid.size()
	var h := grid.height
	var terrain := grid.terrain
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(-1)
	var queue := PackedInt32Array()
	queue.resize(n)
	var head := 0
	var tail := 0
	for s in sources:
		if s >= 0 and s < n and dist[s] == -1 and walkable_lut[terrain[s]] == 1:
			dist[s] = 0
			queue[tail] = s
			tail += 1
	while head < tail:
		var c := queue[head]
		head += 1
		var nd := dist[c] + 1
		var y := c % h
		var nb := 0
		if y > 0:
			nb = c - 1
			if dist[nb] == -1 and walkable_lut[terrain[nb]] == 1:
				dist[nb] = nd
				queue[tail] = nb
				tail += 1
		if y < h - 1:
			nb = c + 1
			if dist[nb] == -1 and walkable_lut[terrain[nb]] == 1:
				dist[nb] = nd
				queue[tail] = nb
				tail += 1
		if c >= h:
			nb = c - h
			if dist[nb] == -1 and walkable_lut[terrain[nb]] == 1:
				dist[nb] = nd
				queue[tail] = nb
				tail += 1
		nb = c + h
		if nb < n and dist[nb] == -1 and walkable_lut[terrain[nb]] == 1:
			dist[nb] = nd
			queue[tail] = nb
			tail += 1
	return dist


## True if every target tile is reachable from at least one source tile.
static func all_reachable(grid: WorldGrid, walkable_lut: PackedByteArray, sources: PackedInt32Array, targets: PackedInt32Array) -> bool:
	var dist := distance_field(grid, walkable_lut, sources)
	for t in targets:
		if dist[t] < 0:
			return false
	return true
