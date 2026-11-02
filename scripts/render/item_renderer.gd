class_name ItemRenderer
extends Node2D
## Draws items travelling on belts with one MultiMesh. Lives in tile space.
## (Belt items move at a constant speed, so no tick interpolation is needed
## for readability at 30 Hz.)

const ITEM_SIZE := 0.24

var sim: GameSim
var _mm := MultiMeshInstance2D.new()
var _buf := PackedFloat32Array()


func _ready() -> void:
	_mm.multimesh = EnemyRenderer.make_multimesh()
	add_child(_mm)


func _process(_delta: float) -> void:
	if sim == null:
		return
	var belts := sim.belts
	belts.ensure_built()
	var n := belts.item_count()
	EnemyRenderer.ensure_capacity(_mm.multimesh, n, _buf)
	var colors: Array[Color] = []
	for def in sim.reg.items:
		colors.append(def.color)
	var k := 0
	for line in belts.lines:
		for i in line.items.size():
			var p := belts.item_position(line, i)
			EnemyRenderer.write_instance(_buf, k, p.x, p.y, ITEM_SIZE, ITEM_SIZE, colors[line.items[i]])
			k += 1
	_mm.multimesh.buffer = _buf
	_mm.multimesh.visible_instance_count = k
