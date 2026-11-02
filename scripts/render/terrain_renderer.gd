class_name TerrainRenderer
extends TileMapLayer
## Draws the terrain layer of a [WorldGrid] using a generated placeholder tileset.
##
## Read-only view: it never changes simulation state. It listens to
## [signal WorldGrid.terrain_changed] for incremental updates.

const SOURCE_ID := 0

var _grid: WorldGrid


func setup(grid: WorldGrid, reg: DataRegistry) -> void:
	_grid = grid
	tile_set = build_tileset(reg)
	if not grid.terrain_changed.is_connected(_on_terrain_changed):
		grid.terrain_changed.connect(_on_terrain_changed)
	redraw_all()


func redraw_all() -> void:
	clear()
	var h := _grid.height
	var terrain := _grid.terrain
	for x in _grid.width:
		var base := x * h
		for y in h:
			set_cell(Vector2i(x, y), SOURCE_ID, Vector2i(terrain[base + y], 0))


func _on_terrain_changed(cell: Vector2i) -> void:
	set_cell(cell, SOURCE_ID, Vector2i(_grid.get_terrain(cell.x, cell.y), 0))


## Builds a one-row atlas with one coloured tile per terrain code.
static func build_tileset(reg: DataRegistry) -> TileSet:
	var px := WorldGrid.TILE_PX
	var count := maxi(1, reg.terrain_by_code.size())
	var img := Image.create(px * count, px, false, Image.FORMAT_RGBA8)
	for code in count:
		var def: TerrainDef = reg.terrain_by_code[code] if code < reg.terrain_by_code.size() else null
		var col := def.color if def != null else Color.MAGENTA
		var ox := code * px
		# 1px darker border gives a subtle construction grid.
		img.fill_rect(Rect2i(ox, 0, px, px), col.darkened(0.12))
		img.fill_rect(Rect2i(ox + 1, 1, px - 2, px - 2), col)
		if def != null and def.drillable:
			_speckle(img, ox, px, col.lightened(0.35))
		elif def != null and def.destructible:
			_speckle(img, ox, px, col.darkened(0.25))
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(px, px)
	for code in count:
		src.create_tile(Vector2i(code, 0))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(px, px)
	ts.add_source(src, SOURCE_ID)
	return ts


static func _speckle(img: Image, ox: int, px: int, col: Color) -> void:
	var step := px / 4
	for i in 4:
		for j in 4:
			if (i + j) % 2 == 0:
				img.fill_rect(Rect2i(ox + i * step + step / 2 - 2, j * step + step / 2 - 2, 4, 4), col)
