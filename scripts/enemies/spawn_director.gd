class_name SpawnDirector
extends RefCounted
## Decides when and what enemies spawn: a continuous trickle from every nest
## plus periodic, announced assaults. Pacing comes from [SpawnConfig].

var cfg: SpawnConfig
var enemies: Array[EnemyDef]
var rng: SimRng

var _trickle_timer: float
var _assault_number: int = 0
var _assault_remaining: int = 0
var _assault_timer: float = 0.0
## Game time (s) of the next assault.
var next_assault_at: float


func _init(config: SpawnConfig, enemy_defs: Array[EnemyDef], random: SimRng) -> void:
	cfg = config
	enemies = enemy_defs
	rng = random
	_trickle_timer = cfg.grace_period
	next_assault_at = cfg.assault_first_at


## Advances by [param dt] seconds at game time [param time]. Calls
## [param spawn] (func(type_index: int, nest: int, hp_mult: float)) for each spawn.
func update(time: float, dt: float, nest_count: int, spawn: Callable) -> void:
	var hp_mult := 1.0 + cfg.hp_growth_per_minute * time / 60.0
	# Trickle.
	_trickle_timer -= dt
	if _trickle_timer <= 0.0:
		_trickle_timer += current_trickle_interval(time)
		for nest in nest_count:
			spawn.call(pick_type(time), nest, hp_mult)
	# Assaults.
	if time >= next_assault_at and _assault_remaining == 0:
		_assault_number += 1
		_assault_remaining = cfg.assault_base_size + cfg.assault_size_growth * (_assault_number - 1)
		_assault_timer = 0.0
		next_assault_at += cfg.assault_interval
	if _assault_remaining > 0:
		_assault_timer -= dt
		if _assault_timer <= 0.0:
			_assault_timer += cfg.assault_spawn_spacing
			_assault_remaining -= 1
			for nest in nest_count:
				spawn.call(pick_type(time), nest, hp_mult)


func current_trickle_interval(time: float) -> float:
	var t := clampf((time - cfg.grace_period) / maxf(1.0, cfg.trickle_ramp_seconds), 0.0, 1.0)
	return lerpf(cfg.trickle_interval_start, cfg.trickle_interval_min, t)


func is_assault_active() -> bool:
	return _assault_remaining > 0


func assault_number() -> int:
	return _assault_number


## Weighted random choice among enemy types unlocked at [param time].
func pick_type(time: float) -> int:
	var total := 0.0
	for def in enemies:
		if time >= def.unlock_time:
			total += def.spawn_weight
	var roll := rng.next_float() * total
	for i in enemies.size():
		var def := enemies[i]
		if time < def.unlock_time:
			continue
		roll -= def.spawn_weight
		if roll <= 0.0:
			return i
	return 0
