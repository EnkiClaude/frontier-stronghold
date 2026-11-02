extends TestCase
## Phase 1.5 acceptance: towers fed by a working supply chain keep firing,
## while the same towers without supply run dry and the Core takes damage.


func _play(with_supply: bool) -> GameSim:
	var sim := SimHelpers.open_sim(90, 30, 3)
	sim.credits = 100000
	# Funnel: a wall across the map with one gap, so every enemy then walks
	# along row ~14 past the tower line (towers on rows 10-11).
	for y in range(1, 29):
		if y != 14:
			sim.place(&"wall", Vector2i(60, y))
	var towers := SupplyScenario.build_defense_line(sim, Vector2i(14, 8), 28, 4, with_supply)
	assert_eq(towers.size(), 4)
	SimHelpers.run(sim, 360.0)
	return sim


func test_supplied_towers_outlast_unsupplied() -> void:
	var dry := _play(false)
	var fed := _play(true)
	print("        unsupplied: fired %d, kills %d, leaked %d, core %d" % [dry.rounds_fired, dry.kills, dry.leaked, dry.core_hp])
	print("        supplied:   fired %d, kills %d, leaked %d, core %d" % [fed.rounds_fired, fed.kills, fed.leaked, fed.core_hp])
	assert_true(dry.rounds_fired <= 4 * 50, "unsupplied towers only have starter ammo")
	assert_true(fed.rounds_fired > dry.rounds_fired * 2, "supply keeps towers firing")
	assert_true(fed.leaked < dry.leaked, "supply must reduce leaks")
	assert_true(fed.kills > dry.kills)
