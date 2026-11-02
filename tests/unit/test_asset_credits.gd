extends TestCase
## Asset policy enforcement: every pack folder has a licence file and an entry
## in assets/CREDITS.md; every texture referenced by data exists.

const CREDITS := "res://assets/CREDITS.md"


func _credits_text() -> String:
	var f := FileAccess.open(CREDITS, FileAccess.READ)
	return f.get_as_text() if f != null else ""


func test_every_pack_has_licence_and_credit() -> void:
	var credits := _credits_text()
	assert_true(credits != "", "assets/CREDITS.md must exist")
	var packs := 0
	for type in DirAccess.get_directories_at("res://assets"):
		for pack in DirAccess.get_directories_at("res://assets".path_join(type)):
			packs += 1
			var dir := "res://assets".path_join(type).path_join(pack)
			var has_licence := false
			for f in DirAccess.get_files_at(dir):
				var lower := f.to_lower()
				if lower.begins_with("license") or lower.begins_with("licence"):
					has_licence = true
			assert_true(has_licence, "%s has no License/Licence file" % dir)
			assert_true(credits.contains("assets/%s/%s/" % [type, pack]), "%s is missing from assets/CREDITS.md" % dir)
	assert_true(packs >= 1)


func test_data_textures_exist_inside_assets() -> void:
	var reg := DataRegistry.load_default()
	var textures: Array = []
	for def: TerrainDef in reg.terrain_by_id.values():
		textures.append(def.texture)
	for def: BuildingDef in reg.buildings_by_id.values():
		textures.append(def.texture)
		textures.append(def.turret_texture)
	for def in reg.enemies:
		textures.append(def.texture)
	for def in reg.items:
		textures.append(def.icon)
	for t in textures:
		if t == null:
			continue
		var path: String = (t as Texture2D).resource_path
		assert_true(path.begins_with("res://assets/"), "texture outside assets/: %s" % path)
		assert_true((t as Texture2D).get_width() > 0)


func test_tileset_builds_with_and_without_art() -> void:
	var reg := DataRegistry.load_default()
	for enabled in [true, false]:
		DataRegistry.art_enabled = enabled
		var ts := TerrainRenderer.build_tileset(reg)
		var src := ts.get_source(TerrainRenderer.SOURCE_ID) as TileSetAtlasSource
		assert_eq(src.get_tiles_count(), reg.terrain_by_code.size())
		assert_eq(src.get_alternative_tiles_count(Vector2i(0, 0)), TerrainRenderer.VARIANTS)
	DataRegistry.art_enabled = true


func test_credits_markdown_converts() -> void:
	var bb := Hud.credits_bbcode(_credits_text())
	assert_true(bb.contains("selfmade_scifi_placeholders"))
	assert_false(bb.contains("**"), "bold markers converted")
