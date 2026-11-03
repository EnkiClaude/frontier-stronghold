class_name SpawnDirector
extends RefCounted
## Decides when and what enemies spawn ([SpawnConfig], ADR-008):
## preparation -> small waves every `wave_interval` -> periodic assaults, each
## followed by a quiet lull. All pacing after preparation uses "wave time"
## (seconds since preparation ended), so skipping preparation never makes
## enemies stronger or earlier than intended.

var cfg: SpawnConfig
var enemies: Array[EnemyDef]
var rng: SimRng

## Game time at which preparation ends (waves start).
var waves_start: float
## Game time (s) of the next assault and next small wave.
var next_assault_at: float
var next_wave_at: float
## No small waves before this game time (lull after an assault).
var lull_until: float = -1.0

var _wave_number: int = 0
var _wave_remaining: int = 0
var _wave_timer: float = 0.0
var _assault_number: int = 0
var _assault_remaining: int = 0
var _assault_timer: float = 0.0


func _init(config: SpawnConfig, enemy_defs: Array[EnemyDef], random: SimRng) -> void:
	cfg = config
	enemies = enemy_defs
	rng = random
	waves_start = cfg.grace_period
	next_wave_at = waves_start
	next_assault_at = waves_start + cfg.assault_first_at


func in_preparation(time: float) -> bool:
	return time < waves_start


## Ends preparation now (player pressed "Start waves").
func skip_preparation(time: float) -> void:
	if not in_preparation(time):
		return
	var shift := waves_start - time
	waves_start = time
	next_wave_at -= shift
	next_assault_at -= shift


func wave_time(time: float) -> float:
	return maxf(0.0, time - waves_start)


func in_lull(time: float) -> bool:
	return time < lull_until and _assault_remaining == 0


func wave_size(time: float) -> int:
	return cfg.wave_base_size + int(cfg.wave_growth_per_minute * wave_time(time) / 60.0)


## Advances by [param dt] seconds at game time [param time]. Calls
## [param spawn] (func(type_index: int, nest: int, hp_mult: float)) for each spawn.
func update(time: float, dt: float, nest_count: int, spawn: Callable) -> void:
	if in_preparation(time):
		return
	var hp_mult := 1.0 + cfg.hp_growth_per_minute * wave_time(time) / 60.0
	# Assaults have priority; a small wave never starts during one or during a lull.
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
			if _assault_remaining == 0:
				lull_until = time + cfg.lull_after_assault
				next_wave_at = lull_until  # Waves resume right after the lull.
		return
	if _wave_remaining == 0 and time >= next_wave_at and time >= lull_until:
		_wave_number += 1
		_wave_remaining = wave_size(time)
		_wave_timer = 0.0
		next_wave_at = time + cfg.wave_interval
	if _wave_remaining > 0:
		_wave_timer -= dt
		if _wave_timer <= 0.0:
			_wave_timer += cfg.assault_spawn_spacing
			_wave_remaining -= 1
			for nest in nest_count:
				spawn.call(pick_type(time), nest, hp_mult)


func is_assault_active() -> bool:
	return _assault_remaining > 0


func is_wave_active() -> bool:
	return _wave_remaining > 0


func assault_number() -> int:
	return _assault_number


func wave_number() -> int:
	return _wave_number


## Weighted random choice among enemy types unlocked (by wave time) at [param time].
func pick_type(time: float) -> int:
	var wt := wave_time(time)
	var total := 0.0
	for def in enemies:
		if wt >= def.unlock_time:
			total += def.spawn_weight
	var roll := rng.next_float() * total
	for i in enemies.size():
		var def := enemies[i]
		if wt < def.unlock_time:
			continue
		roll -= def.spawn_weight
		if roll <= 0.0:
			return i
	return 0
