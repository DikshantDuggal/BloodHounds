extends CharacterBody2D

signal swung(strike)
signal action(name: String, where: Vector2)
signal died

const Profile = preload("res://scripts/profile.gd")
const Strike = preload("res://scripts/strike.gd")
enum Mode { FREE, ATTACK, DASH, PARRY, CHARGE, HURT, SCRIPT }

var profile := Profile.new("res://resources/heir.cfg")
var mode := Mode.SCRIPT
const Damage = preload("res://scripts/damage.gd")
const PROGRESSION = preload("res://resources/player_progression.tres")

var progression = PROGRESSION.duplicate()
var health: int:
	get: return progression.health
	set(value): progression.health = value
var maximum: int:
	get: return progression.maximum
var resurrection_level: int:
	get: return progression.soul_level
	set(value): progression.soul_level = value
var energy: float:
	get: return progression.energy
	set(value): progression.energy = value
var phantom := false
var facing := 1.0
var awakened := false
var pose := "idle"
var phase := 0.0
var clock := 0.0
var dash_cd := 0.0
var parry_cd := 0.0
var iframe := 0.0
var coyote := 0.0
var leap_buffer := 0.0
var swing_buffer := 0.0
var combo := 0
var strike_data: Dictionary
var strike_id := 0
var parry_success := false
var body_size: Vector2
var visual_time := 0.0
var landing := 0.0
var queued: Dictionary = {}
var swing_started := false

func _ready() -> void:
	body_size = profile.get_value("body", "size", Vector2(30, 64))
	$Shape.shape = RectangleShape2D.new()
	$Shape.shape.size = body_size
	$Shape.position.y = -body_size.y * 0.5
	reset()

func reset() -> void:
	progression.reset()
	phantom = false
	awakened = false
	velocity = Vector2.ZERO
	dash_cd = 0.0
	parry_cd = 0.0
	iframe = 0.0
	facing = 1.0
	script_pose("idle")

func activate_phantom() -> bool:
	if mode not in [Mode.FREE,Mode.ATTACK,Mode.CHARGE] or health <= 0:
		return false
	var axis := Input.get_axis("left","right")
	if not is_zero_approx(axis):
		facing = signf(axis)
	phantom = true
	mode = Mode.DASH
	clock = 0.0
	swing_buffer = 0.0
	iframe = maxf(iframe,float(progression.phantom_duration) + .04)
	action.emit("phantom",position)
	return true

func script_pose(name: String, progress: float = 0.0) -> void:
	mode = Mode.SCRIPT
	velocity = Vector2.ZERO
	pose = name
	phase = progress
	clock = 0.0
	swing_buffer = 0.0
	leap_buffer = 0.0
	coyote = 0.0
	landing = 0.0
	queued.clear()
	phantom = false

func enable() -> void:
	phantom = false
	mode = Mode.FREE
	pose = "idle"
	clock = 0.0
	parry_success = false

func hurtbox() -> Rect2:
	return Rect2(global_position - Vector2(body_size.x * 0.5, body_size.y), body_size)

func defend(strike) -> String:
	if mode == Mode.SCRIPT or health <= 0 or not hurtbox().intersects(strike.box):
		return ""
	if mode == Mode.PARRY and not parry_success and clock <= number("combat", "parry_active") and strike.parryable:
		var perfect := clock <= number("combat","perfect_window")
		parry_success = true
		clock = 0.0
		energy += 27.0
		iframe = 0.39
		action.emit("parry", position + Vector2(22.0 * facing, -46))
		return "perfect_parry" if perfect else "parry"
	if iframe > 0:
		return "evade"
	health = Damage.remaining(health,strike.damage)
	iframe = 0.76
	velocity = Vector2(strike.direction * 264, -152)
	mode = Mode.HURT
	clock = 0.0
	swing_buffer = 0.0
	action.emit("hurt", position + Vector2(0, -40))
	if health == 0:
		died.emit()
	return "hurt"

func number(section: String, key: String) -> float:
	return float(profile.get_value(section, key, 0.0))

func read_controls(dt: float) -> void:
	for key: String in queued.keys():
		queued[key] = float(queued[key]) - dt
		if queued[key] <= 0.0:
			queued.erase(key)
	for key: String in ["light", "heavy", "dash", "parry", "leap"]:
		if Input.is_action_just_pressed(key):
			queued[key] = .10

func take_input(key: String) -> bool:
	return queued.erase(key)

func simulate(dt: float) -> void:
	visual_time += dt
	if mode == Mode.SCRIPT:
		return
	var grounded := is_on_floor()
	var axis := Input.get_axis("left", "right")
	dash_cd = maxf(0, dash_cd - dt)
	parry_cd = maxf(0, parry_cd - dt)
	iframe = maxf(0, iframe - dt)
	clock += dt
	landing = maxf(0, landing - dt)
	coyote = number("movement", "coyote") if grounded else maxf(0, coyote - dt)
	leap_buffer = number("movement", "buffer") if take_input("leap") else maxf(0, leap_buffer - dt)
	swing_buffer = maxf(0, swing_buffer - dt)
	var pressed := take_input("light")
	if pressed and mode == Mode.ATTACK:
		swing_buffer = number("combat", "combo_buffer")
	if mode != Mode.HURT and mode != Mode.DASH:
		if dash_cd <= 0 and take_input("dash"):
			if not is_zero_approx(axis):
				facing = signf(axis)
			mode = Mode.DASH
			clock = 0
			dash_cd = number("movement", "dash_cooldown")
			iframe = maxf(iframe, number("movement", "dash_time") + 0.02)
			swing_buffer = 0
			action.emit("dash", position)
		elif parry_cd <= 0 and mode != Mode.PARRY and take_input("parry"):
			mode = Mode.PARRY
			clock = 0
			parry_cd = number("combat", "parry_cooldown")
			parry_success = false
			swing_buffer = 0
			action.emit("guard", position + Vector2(26 * facing, -48))
	if mode == Mode.FREE:
		if not is_zero_approx(axis):
			facing = signf(axis)
		if pressed:
			combo = 1 if grounded else 0
			begin_attack("light_1" if grounded else "air")
		elif take_input("heavy"):
			mode = Mode.CHARGE
			clock = 0
	if mode != Mode.DASH:
		velocity.y += number("movement", "gravity") * dt
		if Input.is_action_just_released("leap") and velocity.y < -150.0:
			velocity.y *= 0.42
	match mode:
		Mode.FREE:
			var acceleration := 2450.0 if grounded else 1520.0
			velocity.x = move_toward(velocity.x, axis * number("movement", "speed"), dt * acceleration)
			if leap_buffer > 0 and coyote > 0:
				velocity.y = number("movement", "jump")
				leap_buffer = 0
				coyote = 0
				action.emit("jump", position)
			pose = "run" if absf(velocity.x) > 42.0 else "idle"
			if not grounded or velocity.y < 0:
				pose = "jump_start" if velocity.y < -414 else ("rise" if velocity.y < 0 else "fall")
			elif landing > 0:
				pose = "land"
			phase = visual_time
		Mode.DASH:
			pose = "dash" if phantom or not is_zero_approx(axis) else "dodge"
			var duration := float(progression.phantom_duration) if phantom else number("movement","dash_time")
			var speed := float(progression.phantom_speed) if phantom else number("movement","dash_speed")
			phase = clock / duration
			velocity = Vector2(facing * speed, 0)
			if phase >= 1:
				enable()
		Mode.PARRY:
			pose = "parry_success" if parry_success else "parry"
			phase = clock / number("combat", "parry_total")
			velocity.x = move_toward(velocity.x, 0, 2200 * dt)
			if phase >= 1:
				enable()
		Mode.CHARGE:
			pose = "charge"
			phase = minf(1, clock / number("combat", "charge_full"))
			velocity.x = move_toward(velocity.x, axis * 75, dt * 950)
			if not Input.is_action_pressed("heavy"):
				combo = 0
				var fully_charged := phase >= 1.0 and energy >= 25.0
				if fully_charged:
					energy -= 25.0
				begin_attack("charged" if fully_charged else "heavy")
		Mode.ATTACK:
			var start: float = strike_data.start
			var end: float = strike_data.end
			var total: float = strike_data.total
			pose = strike_data.name
			phase = clock / total
			var active := clock >= start and (clock <= end or not swing_started)
			velocity.x = move_toward(velocity.x, facing * 142.0 if active else axis * 63.0, 1620 * dt)
			if active and pose != "sever":
				if not swing_started:
					swing_started = true
					action.emit("swing", position + Vector2(31 * facing, -43))
				var amount: float = progression.attack_power(float(strike_data.multiplier),pose=="heavy")
				var shift: Vector2 = strike_data.get("offset", Vector2.ZERO)
				var pivot := global_position + Vector2(shift.x * facing, shift.y)
				var box := Strike.forward(pivot, facing, strike_data.reach, strike_data.height, 23.0)
				swung.emit(Strike.new(box, amount, facing, false, pose, strike_id))
				if mode != Mode.ATTACK:
					return
			elif active and not swing_started:
				swing_started = true
				action.emit("sever", position + Vector2(31 * facing, -43))
			if clock >= total:
				if swing_buffer > 0 and combo > 0 and grounded:
					combo = combo % 3 + 1
					begin_attack("light_%d" % combo)
				else:
					enable()
		Mode.HURT:
			pose = "hurt" if clock < 0.09 else "knockback"
			phase = clock / 0.29
			velocity.x = move_toward(velocity.x, 0, dt * 620)
			if phase >= 1:
				enable()
	if mode == Mode.SCRIPT:
		return
	var falling_speed := velocity.y
	move_and_slide()
	if not grounded and is_on_floor() and falling_speed > 100:
		landing = 0.12
		action.emit("land", position)

func begin_attack(key: String) -> void:
	if key == "sever":
		combo = 0
	strike_data = profile.get_value("combat", key)
	mode = Mode.ATTACK
	clock = 0.0
	swing_buffer = 0.0
	strike_id += 1
	swing_started = false
