class_name ItemRenderer
extends Node2D
## Draws items travelling on belts: one MultiMesh per item type so each type
## can use its icon ([member ItemDef.icon]); falls back to coloured squares.
## Lives in tile space.

const ITEM_SIZE := 0.3
const ICON_SIZE := 0.44
## Items never get smaller than this on screen (pixels).
const MIN_SCREEN_PX := 6.0

var sim: GameSim
var _mms: Array[MultiMeshInstance2D] = []
var _bufs: Array[PackedFloat32Array] = []
var _icon := PackedByteArray()


func _ready() -> void:
	for def in sim.reg.items:
		var mmi := MultiMeshInstance2D.new()
		mmi.multimesh = EnemyRenderer.make_multimesh()
		var icon := DataRegistry.art(def.icon)
		mmi.texture = icon
		_icon.append(1 if icon != null else 0)
		add_child(mmi)
		_mms.append(mmi)
		_bufs.append(PackedFloat32Array())


func _process(_delta: float) -> void:
	if sim == null:
		return
	var belts := sim.belts
	belts.ensure_built()
	var types := sim.reg.items.size()
	var counts := PackedInt32Array()
	counts.resize(types)
	counts.fill(0)
	var min_size := MIN_SCREEN_PX / maxf(get_global_transform_with_canvas().get_scale().x, 0.001)
	for line in belts.lines:
		for item in line.items:
			counts[item] += 1
	for t in types:
		EnemyRenderer.ensure_capacity(_mms[t].multimesh, counts[t], _bufs[t])
	counts.fill(0)
	for line in belts.lines:
		for i in line.items.size():
			var t := line.items[i]
			var p := belts.item_position(line, i)
			var has_icon := _icon[t] == 1
			var s := maxf(ICON_SIZE if has_icon else ITEM_SIZE, min_size)
			EnemyRenderer.write_instance(_bufs[t], counts[t], p.x, p.y, s, s, Color.WHITE if has_icon else sim.reg.items[t].color)
			counts[t] += 1
	for t in types:
		_mms[t].multimesh.buffer = _bufs[t]
		_mms[t].multimesh.visible_instance_count = counts[t]
