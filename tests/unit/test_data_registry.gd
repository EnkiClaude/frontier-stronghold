extends TestCase


func test_default_data_loads_without_errors() -> void:
	var reg := DataRegistry.load_default()
	assert_eq(reg.errors.size(), 0, ", ".join(reg.errors))
	for id in [&"ground", &"rock", &"bedrock", &"water", &"ore_iron", &"ore_copper", &"ore_coal", &"ore_stone"]:
		assert_true(reg.terrain_by_id.has(id), "missing terrain %s" % id)


func test_lookup_tables_match_definitions() -> void:
	var reg := DataRegistry.load_default()
	for def: TerrainDef in reg.terrain_by_id.values():
		assert_eq(reg.walkable_lut[def.code], 1 if def.walkable else 0, String(def.id))
		assert_eq(reg.terrain_by_code[def.code], def)
	assert_eq(reg.walkable_lut[reg.terrain_code(&"rock")], 0)
	assert_eq(reg.walkable_lut[reg.terrain_code(&"ground")], 1)


func test_excavation_targets_exist() -> void:
	var reg := DataRegistry.load_default()
	for def: TerrainDef in reg.terrain_by_id.values():
		if def.destructible:
			assert_true(reg.terrain_by_id.has(def.becomes), "%s must become a known terrain" % def.id)
