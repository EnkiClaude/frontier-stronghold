extends TestCase
## View caching (ADR-009): static buildings are drawn into cached chunks,
## everything else every frame; chunks only rebuild when their contents change.


func _renderer(sim: GameSim) -> BuildingRenderer:
	var r := BuildingRenderer.new()
	r.sim = sim
	(Engine.get_main_loop() as SceneTree).root.add_child(r)
	return r


func test_static_buildings_go_to_chunks() -> void:
	var sim := SimHelpers.open_sim(160, 40)
	sim.credits = 100000
	assert_eq(sim.place(&"wall", Vector2i(40, 20)), "")
	assert_eq(sim.place(&"chain_gun", Vector2i(44, 20)), "")
	var r := _renderer(sim)
	r._process(0.0)
	# Both still under construction: drawn every frame (progress bars).
	assert_eq(r.chunk_count(), 0)
	SimHelpers.finish_construction(sim)
	r._process(0.0)
	assert_eq(r.chunk_count(), 1, "the finished wall is cached")
	var dyn_ids: Array = r._dynamic.map(func(b: Building) -> int: return b.id)
	assert_true(dyn_ids.has(sim.building_at(Vector2i(44, 20)).id), "towers stay per-frame (aim, ammo)")
	assert_false(dyn_ids.has(sim.building_at(Vector2i(40, 20)).id))
	sim.sell(sim.building_at(Vector2i(40, 20)).id)
	r._process(0.0)
	assert_eq(r.chunk_count(), 0, "empty chunks are removed")
	r.queue_free()


func test_unchanged_chunks_are_not_redrawn() -> void:
	var sim := SimHelpers.open_sim(160, 40)
	sim.credits = 100000
	sim.place(&"wall", Vector2i(40, 20))
	sim.place(&"wall", Vector2i(100, 20))
	SimHelpers.finish_construction(sim)
	var r := _renderer(sim)
	r._process(0.0)
	assert_eq(r.chunk_count(), 2)
	var sig_far: int = r._chunk_sigs[Vector2i(100 / BuildingRenderer.CHUNK, 0)]
	sim.place(&"wall", Vector2i(41, 20))
	SimHelpers.finish_construction(sim)
	r._process(0.0)
	assert_eq(r._chunk_sigs[Vector2i(100 / BuildingRenderer.CHUNK, 0)], sig_far, "other chunks keep their cache")
	r.queue_free()
