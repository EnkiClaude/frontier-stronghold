class_name TerrainRenderer
extends TileMapLayer
## Draws the terrain layer of a [WorldGrid] using a generated placeholder tileset.
##
## Read-only view: it never changes simulation state. It listens to
## [signal WorldGrid.terrain_changed] for incremental updates.

const SOURCE_ID := 0
## Atlas resolution per tile; the layer is scaled so one tile = WorldGrid.TILE_PX.
const ATLAS_PX := 64
## Alternative tiles (flips) used to break up repetition of textured terrain.
const VARIANTS := 4

var _grid: WorldGrid


func setup(grid: WorldGrid, reg: DataRegistry) -> void:
	_grid = grid
	scale = Vector2.ONE * float(WorldGrid.TILE_PX) / ATLAS_PX
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
			set_cell(Vector2i(x, y), SOURCE_ID, Vector2i(terrain[base + y], 0), _variant(x, y))


func _on_terrain_changed(cell: Vector2i) -> void:
	set_cell(cell, SOURCE_ID, Vector2i(_grid.get_terrain(cell.x, cell.y), 0), _variant(cell.x, cell.y))


## Stable pseudo-random flip variant per tile.
static func _variant(x: int, y: int) -> int:
	return ((x * 73856093) ^ (y * 19349663)) & (VARIANTS - 1)


## Builds a one-row atlas with one tile per terrain code: the terrain's texture
## when available, otherwise a generated coloured tile. Each tile gets flipped
## alternatives (see [constant VARIANTS]).
static func build_tileset(reg: DataRegistry) -> TileSet:
	var px := ATLAS_PX
	var count := maxi(1, reg.terrain_by_code.size())
	var img := Image.create(px * count, px, false, Image.FORMAT_RGBA8)
	for code in count:
		var def: TerrainDef = reg.terrain_by_code[code] if code < reg.terrain_by_code.size() else null
		var ox := code * px
		var tex := DataRegistry.art(def.texture) if def != null else null
		if tex != null:
			var tile := tex.get_image()
			if tile.is_compressed():
				tile.decompress()
			tile.convert(Image.FORMAT_RGBA8)
			tile.clear_mipmaps()
			if tile.get_size() != Vector2i(px, px):
				tile.resize(px, px, Image.INTERPOLATE_LANCZOS)
			img.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i(ox, 0))
			continue
		var col := def.color if def != null else Color.MAGENTA
		# 1px darker border gives a subtle construction grid.
		img.fill_rect(Rect2i(ox, 0, px, px), col.darkened(0.12))
		img.fill_rect(Rect2i(ox + 1, 1, px - 2, px - 2), col)
		if def != null and def.drillable:
			_speckle(img, ox, px, col.lightened(0.35))
		elif def != null and def.destructible:
			_speckle(img, ox, px, col.darkened(0.25))
	img.generate_mipmaps()
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(px, px)
	for code in count:
		var coords := Vector2i(code, 0)
		src.create_tile(coords)
		for v in range(1, VARIANTS):
			var alt := src.create_alternative_tile(coords)
			var data := src.get_tile_data(coords, alt)
			data.flip_h = (v & 1) == 1
			data.flip_v = (v & 2) == 2
	var ts := TileSet.new()
	ts.tile_size = Vector2i(px, px)
	ts.add_source(src, SOURCE_ID)
	return ts


static func _speckle(img: Image, ox: int, px: int, col: Color) -> void:
	var step := px / 4
	for i in 4:
		for j in 4:
			if (i + j) % 2 == 0:
				img.fill_rect(Rect2i(ox + i * step + step / 2 - 3, j * step + step / 2 - 3, 6, 6), col)
