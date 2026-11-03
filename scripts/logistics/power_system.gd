class_name PowerSystem
extends RefCounted
## Power networks (ADR-007): Power Nodes link to each other within
## `link_range` and power every generator/consumer within `supply_radius`.
## Generators burn fuel only while their network has demand. Consumers get
## `satisfaction = min(1, generation / demand)` of their need.

var reg: DataRegistry
var nodes: Array[Building] = []
var generators: Array[Building] = []
var consumers: Array[Building] = []

## Per network id: [generation, demand] from the last tick (for the HUD).
var network_stats: Array[Vector2] = []
## Node pairs that are linked (for drawing power lines).
var links: Array[PackedVector2Array] = []
## Totals over all networks from the last tick.
var total_generation: float = 0.0
var total_demand: float = 0.0

var _dirty := true
var _fuel_item := {}  # BuildingDef -> item index (cache)


func _init(registry: DataRegistry) -> void:
	reg = registry


func register(b: Building) -> void:
	if b.def.kind == &"power_node":
		nodes.append(b)
	elif b.def.kind == &"generator":
		generators.append(b)
	elif b.def.tower != null and b.def.tower.power_draw > 0.0:
		consumers.append(b)
	else:
		return
	_dirty = true


func unregister(b: Building) -> void:
	if nodes.has(b) or generators.has(b) or consumers.has(b):
		nodes.erase(b)
		generators.erase(b)
		consumers.erase(b)
		b.network = -1
		b.power_satisfaction = 0.0
		b.burning = false
		_dirty = true


## Whether a building at [param rect] (tiles) would be inside any node's supply area.
func covers(rect: Rect2) -> bool:
	for n in nodes:
		if _reaches(n, rect):
			return true
	return false


func _reaches(node: Building, rect: Rect2) -> bool:
	var c := node.center()
	var p := Vector2(clampf(c.x, rect.position.x, rect.end.x), clampf(c.y, rect.position.y, rect.end.y))
	return c.distance_to(p) <= node.def.supply_radius


func _rebuild() -> void:
	_dirty = false
	links.clear()
	# Union-find over nodes by link range.
	var parent := PackedInt32Array()
	parent.resize(nodes.size())
	for i in nodes.size():
		parent[i] = i
	for i in nodes.size():
		for j in range(i + 1, nodes.size()):
			var reach := minf(nodes[i].def.link_range, nodes[j].def.link_range)
			if nodes[i].center().distance_to(nodes[j].center()) <= reach:
				links.append(PackedVector2Array([nodes[i].center(), nodes[j].center()]))
				var a := _find(parent, i)
				var b := _find(parent, j)
				if a != b:
					parent[maxi(a, b)] = mini(a, b)
	# Compact root ids into 0..k network ids.
	var ids := {}
	for i in nodes.size():
		var root := _find(parent, i)
		if not ids.has(root):
			ids[root] = ids.size()
		nodes[i].network = ids[root]
	network_stats.resize(ids.size())
	for b in generators + consumers:
		b.network = -1
		var rect := Rect2(b.origin, b.size())
		for n in nodes:
			if _reaches(n, rect):
				b.network = n.network
				break


static func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


func mark_dirty() -> void:
	_dirty = true


## Advances generators and computes satisfaction for every consumer.
func tick(dt: float) -> void:
	if _dirty:
		_rebuild()
	var count := network_stats.size()
	var demand := PackedFloat32Array()
	demand.resize(count)
	demand.fill(0.0)
	for c in consumers:
		if c.network >= 0 and c.is_active() and c.wants_power:
			demand[c.network] += c.def.tower.power_draw
	var supply := PackedFloat32Array()
	supply.resize(count)
	supply.fill(0.0)
	for g in generators:
		g.burning = false
		if g.network < 0 or not g.is_active() or demand[g.network] <= 0.0:
			continue
		if g.fuel_left <= 0.0:
			var fuel := _fuel_index(g.def)
			if g.inv_in.get(fuel, 0) > 0:
				g.inv_in[fuel] -= 1
				g.fuel_left += g.def.fuel_time
		if g.fuel_left > 0.0:
			g.fuel_left -= dt
			g.burning = true
			supply[g.network] += g.def.power_output
	total_generation = 0.0
	total_demand = 0.0
	for n in count:
		network_stats[n] = Vector2(supply[n], demand[n])
		total_generation += minf(supply[n], demand[n])
		total_demand += demand[n]
	for c in consumers:
		if c.network < 0:
			c.power_satisfaction = 0.0
		else:
			var d := demand[c.network]
			c.power_satisfaction = clampf(supply[c.network] / d, 0.0, 1.0) if d > 0.0 else 0.0


func _fuel_index(def: BuildingDef) -> int:
	if not _fuel_item.has(def):
		_fuel_item[def] = reg.item_index(def.fuel_item)
	return _fuel_item[def]
