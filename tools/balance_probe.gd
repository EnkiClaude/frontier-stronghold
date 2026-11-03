extends SceneTree
## Balance probe: each tower alone next to the enemy route for 3 minutes of waves
## (unlimited ammo/power). Compare kills per 100 credits of total cost.
##   godot --headless --path . -s res://tools/balance_probe.gd
func _initialize() -> void:
	print("%-16s %6s %6s %6s %8s %8s" % ["tower", "kills", "leak", "fired", "cost", "kills/100cr"])
	for id in [&"chain_gun", &"sniper_rifle", &"flamethrower", &"icy_blast", &"tesla_coil", &"lightning_tower"]:
		var reg := DataRegistry.load_default()
		var g := WorldGrid.new(70, 21)
		var bed := reg.terrain_code(&"bedrock")
		for x in 70:
			g.terrain[g.idx(x, 0)] = bed
			g.terrain[g.idx(x, 20)] = bed
		var sim := GameSim.new(reg, g, 7)
		sim.credits = 100000
		sim.infinite_ammo = true
		for item in [&"copper_plate", &"steel", &"brick"]:
			sim.add_to_core(reg.item_index(item), 100)
		# Funnel all enemies through one gap at y=10 next to the tower.
		for y in range(1, 20):
			if y != 10:
				sim.place(&"wall", Vector2i(40, y))
		var err := sim.place(id, Vector2i(37, 7))
		for k in 120:  # Longest build time is 3 s.
			sim.tick()
		var t := sim.building_at(Vector2i(37, 7))
		if t.def.tower.power_draw > 0.0:
			sim.power.unregister(t)
		sim.skip_preparation()
		for k in 180 * 30:
			if t.def.tower.power_draw > 0.0:
				t.power_satisfaction = 1.0
			sim.tick()
		var def := t.def
		var mats := 0
		for m in def.material_cost:
			mats += def.material_cost[m] * reg.items[reg.item_index(StringName(m))].value
		var cost := def.cost + mats
		print("%-16s %6d %6d %6d %8d %8.1f %s" % [id, t.kills, sim.leaked, t.rounds_fired, cost, t.kills * 100.0 / cost, err])
	quit()
