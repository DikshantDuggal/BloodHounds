extends CharacterBody2D

signal swung(strike)
signal telegraph(attack: String)
signal impact(attack: String, where: Vector2)

const Profile = preload("res://scripts/profile.gd")
const Strike = preload("res://scripts/strike.gd")
const Damage = preload("res://scripts/damage.gd")
enum Mode { IDLE, APPROACH, WIND, ACTIVE, RECOVER, STAGGER, SCRIPT }

const FLOOR := 572.0
const LIMITS := Vector2(110, 1170)
const THRONE_BEATS := [0.07, 0.70, 1.37]

@export_file("*.cfg") var profile_path := "res://resources/sovereign.cfg"
var profile
var limits := LIMITS
var encounter_floor := 0
var damage_scale := 1.0
var phase_damage := 2
var parry_damage := 22.0
var guard := .24
var recovery_guard := 1.0
var recovery_scale := 1.0
var walk_speed := 160.0
var authored_death := false
var forward_wave := false
var replay_combo_pose := false
var final_beat_bonus := 6
var mode := Mode.SCRIPT
var stage := 0
var health: int:
	set(value): health = Damage.clamp_health(value,maximum)
var maximum: int
var stagger := 0.0
var stagger_limit: float
var facing := -1.0
var body_size: Vector2
var clock := 0.0
var pose := "intro"
var phase := 0.0
var attack := ""
var stats: Dictionary = {}
var cursor := 0
var aim := 0.0
var origin := 0.0
var marks: Array[float] = []
var serial := 0
var consumed_strike := -1
var emitted := -1
var hit_ids: Dictionary = {}
var hurt_flash := 0.0
var visual_time := 0.0
var wind_bonus := 0.0

func _ready() -> void:
	profile = Profile.new(profile_path)
	authored_death = profile.get_value("visual","authored_death",false)
	replay_combo_pose = profile.get_value("visual","replay_combo_pose",false)
	forward_wave = profile.get_value("attacks","forward_wave",false)
	final_beat_bonus = profile.get_value("attacks","final_beat_bonus",6)
	maximum = profile.get_value("body", "health", 800)
	guard = profile.get_value("body","guard",.24)
	recovery_guard = profile.get_value("body","recovery_guard",1.0)
	recovery_scale = profile.get_value("body","recovery_scale",1.0)
	walk_speed = profile.get_value("body","speed",160.0)
	parry_damage = profile.get_value("body","parry_damage",22.0)
	stagger_limit = profile.get_value("body", "stagger", 100.0)
	body_size = profile.get_value("body", "size", Vector2(64, 145))
	$Shape.shape = RectangleShape2D.new()
	$Shape.shape.size = body_size
	$Shape.position.y = -body_size.y * 0.5
	reset()

func reset() -> void:
	health = maximum
	hurt_flash = 0
	stagger = 0.0
	stage = 0
	limits = LIMITS
	encounter_floor = execution_health()
	damage_scale = 1.0
	phase_damage = 2
	visual_time = 0
	serial = 0
	cursor = 0
	emitted = -1
	stats = {}
	facing = -1
	hit_ids.clear()
	consumed_strike = -1
	script_pose("intro")

func script_pose(name: String, progress: float = 0.0) -> void:
	mode = Mode.SCRIPT
	pose = name
	phase = progress
	clock = 0.0
	attack = ""
	velocity = Vector2.ZERO
	marks.clear()

func enter_stage(value: int) -> void:
	stage = value
	cursor = 0
	stagger = 0
	idle()

func idle() -> void:
	mode = Mode.IDLE
	clock = 0
	attack = ""
	pose = "idle"
	marks.clear()
	velocity.x = 0

func hurtbox() -> Rect2:
	return Rect2(global_position - Vector2(body_size.x * 0.5, body_size.y), body_size)

func receive(strike) -> bool:
	if mode == Mode.SCRIPT or not hurtbox().intersects(strike.box):
		return false
	if not strike.register_hit(hit_ids):
		return false
	var open := stage == 0 or mode in [Mode.RECOVER,Mode.STAGGER]
	var previous := health
	var multiplier := (1.0 if stage == 0 else (recovery_guard if open else guard)) * (1.25 if mode == Mode.STAGGER else 1.0)
	health = Damage.remaining(health,strike.damage,multiplier,encounter_floor)
	var amount := previous-health
	hurt_flash = 0.145
	if stage > 0 and mode != Mode.STAGGER:
		stagger += amount * 0.57
		if stagger >= stagger_limit and mode in [Mode.IDLE, Mode.APPROACH, Mode.RECOVER]:
			staggered()
	return true

func execution_health() -> int:
	return roundi(maximum * float(profile.get_value("phases","execution",.05)))

func repelled(critical: float = 1.0) -> void:
	if stage == 0:
		mode = Mode.RECOVER
		clock = 0
		return
	health = Damage.remaining(health,parry_damage,critical,encounter_floor)
	hurt_flash = 0.17
	stagger += 51.0
	if attack == "throne" or stagger >= stagger_limit:
		staggered()
	else:
		mode = Mode.RECOVER
		clock = 0

func staggered() -> void:
	mode = Mode.STAGGER
	pose = "stagger"
	clock = 0.0
	stagger = 0
	marks.clear()
	impact.emit("stagger", position + Vector2(0, -90))

func simulate(dt: float, target: Vector2) -> void:
	visual_time += dt
	hurt_flash = maxf(0, hurt_flash - dt)
	if mode == Mode.SCRIPT:
		return
	clock += dt
	velocity = Vector2(0, 180)
	var distance := absf(target.x - position.x)
	var side := -1.0 if target.x < position.x else 1.0
	match mode:
		Mode.IDLE:
			pose = "turn" if side != facing and distance > 36 else "idle"
			phase = visual_time
			if distance > 36:
				facing = side
			if clock >= [0.78, 0.61, 0.52, 0.45][stage]:
				next_attack()
		Mode.APPROACH:
			pose = "walk"
			phase = visual_time
			facing = side
			var reach := minf(float(stats.reach)-8.0,147.0) if attack in ["cleave","throne"] else 185.0
			if distance <= reach or clock > 3.15 or attack in ["rush", "ruin", "teleport"]:
				if distance > reach + 65.0 and attack in ["cleave", "throne"]:
					attack = "rush"
					stats = profile.get_value("attacks", attack)
				begin_wind(target)
			else:
				velocity.x = facing * (walk_speed + stage * 22.0)
		Mode.WIND:
			var length := wind_time()
			pose = attack + "_wind"
			phase = minf(1, clock / length)
			if clock >= length:
				mode = Mode.ACTIVE
				clock = 0
				emitted = -1
				origin = position.x
		Mode.ACTIVE:
			pose = attack
			phase = clock / float(stats.active)
			if attack == "throne" and replay_combo_pose:
				var start: float = THRONE_BEATS[0]
				for beat_time: float in THRONE_BEATS:
					if clock >= beat_time-.36:
						start = beat_time
				phase = clampf((clock-start+.36)/.46,0.0,1.0)
			play_attack()
			if mode == Mode.ACTIVE and clock >= float(stats.active):
				mode = Mode.RECOVER
				clock = 0
		Mode.RECOVER:
			pose = attack + "_recover"
			phase = minf(1, clock / recovery_time())
			if clock >= recovery_time():
				if stagger >= stagger_limit:
					staggered()
				else:
					idle()
		Mode.STAGGER:
			pose = "stagger"
			phase = minf(1, clock / 1.65)
			if clock >= 1.65:
				idle()
	if mode == Mode.SCRIPT:
		return
	move_and_slide()
	position.x = clampf(position.x, limits.x, limits.y)

func wind_time() -> float:
	return float(stats.wind) * float([1.14, 1.0, 0.87, 0.78][stage]) + wind_bonus

func recovery_time() -> float:
	return recovery_scale * float(stats.get("recover",0.85)) * float([1.04, 1.0, 0.96, 0.91][stage])

func next_attack() -> void:
	var pattern_name: String = ["one_pattern", "one_pattern", "two_pattern", "three_pattern"][stage]
	var pattern: Array = profile.get_value("phases", pattern_name)
	attack = pattern[cursor % pattern.size()]
	wind_bonus = 0.06 if cursor % 3 == 1 else 0.0
	cursor += 1
	stats = profile.get_value("attacks", attack)
	mode = Mode.APPROACH
	clock = 0

func begin_wind(target: Vector2) -> void:
	mode = Mode.WIND
	clock = 0
	aim = clampf(target.x + facing * 40, limits.x, limits.y)
	marks.clear()
	if attack == "teleport":
		aim = clampf(target.x + facing * 104.0,limits.x,limits.y)
		marks.append(aim)
	if attack == "ruin":
		var center := clampf(target.x,limits.x+80,limits.y-80)
		marks.append(center)
		for offset: float in [-385.0, -190.0, 190.0, 385.0]:
			var mark := center + offset
			if mark >= limits.x+18 and mark <= limits.y-18:
				marks.append(mark)
	telegraph.emit(attack)

func play_attack() -> void:
	var strike_box: Rect2
	match attack:
		"cleave":
			beat(0)
			strike_box = Strike.forward(melee_origin(), facing, stats.reach, stats.height, 41.0)
			send_strike(strike_box, true, 0)
		"rush":
			beat(0)
			var next := lerpf(origin, aim, clampf(phase, 0.0, 1.0))
			var left := minf(position.x, next)
			strike_box = Rect2(left - 51.0, FLOOR - 114.0, absf(next - position.x) + 102.0, 120.0)
			position.x = next
			send_strike(strike_box, true, 0)
		"teleport":
			if emitted < 0:
				position.x = aim
				facing = signf(origin - aim)
				beat(0)
			send_strike(Strike.forward(global_position,facing,stats.reach,stats.height,24),true,0)
		"slam":
			beat(0)
			for side: float in wave_directions():
				var x := origin + side * clock * 620.0
				strike_box = Rect2(x - 32.0, FLOOR - float(stats.height), 64, float(stats.height) + 7.0)
				send_strike(strike_box, false, 0)
		"ruin":
			if clock >= 0.13:
				beat(0)
				for mark in marks:
					strike_box = Rect2(mark - float(stats.reach) * 0.5, FLOOR - float(stats.height), stats.reach, float(stats.height) + 4)
					send_strike(strike_box, false, 0)
		"throne":
			for index in THRONE_BEATS.size():
				var start: float = THRONE_BEATS[index]
				if clock >= start and clock <= start + 0.15:
					beat(index)
					strike_box = Strike.forward(melee_origin(), facing, float(stats.reach) + index * 13, stats.height, 48.0)
					send_strike(strike_box, index == 2, index)

func wave_directions() -> Array:
	return [facing] if forward_wave else [-1.0,1.0]

func melee_origin() -> Vector2:
	var shift: Vector2 = stats.get("offset", Vector2.ZERO)
	return global_position + Vector2(shift.x * facing, shift.y)

func beat(index: int) -> void:
	if index == emitted:
		return
	emitted = index
	serial += 1
	impact.emit(attack, position)

func send_strike(box: Rect2, parryable: bool, beat_index: int) -> void:
	if mode != Mode.ACTIVE:
		return
	var damage := roundi(float(stats.damage)*damage_scale) + maxi(0,stage-1)*phase_damage
	if attack == "throne" and beat_index == 2:
		damage += final_beat_bonus
	swung.emit(Strike.new(box, damage, facing, parryable, attack, serial))
