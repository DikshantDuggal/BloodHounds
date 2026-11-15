extends CharacterBody2D

signal swung(strike)
signal telegraph(label: String, cue: String)
signal defeated(enemy)

const Profile = preload("res://scripts/profile.gd")
const Strike = preload("res://scripts/strike.gd")
const Damage = preload("res://scripts/damage.gd")
enum Mode { IDLE, WIND, ACTIVE, RECOVER, STAGGER, DEAD }

var kind: String
var route_id: String
var display_name: String
var maximum: int
var health: int:
	set(value): health = Damage.clamp_health(value,maximum)
var body_size: Vector2
var limits := Vector2(100, 2800)
var mode := Mode.IDLE
var clock := 0.0
var age := 0.0
var facing := -1.0
var dead := false
var attack := ""
var cursor := 0
var stats: Dictionary
var config := Profile.new("res://resources/enemies.cfg")
var accent: Color
var aim: float
var origin: float
var hit_ids: Dictionary = {}
var consumed_strike := -1
var flashes := 0.0
var recoil := 0.0
var sprite: AnimatedSprite2D
var attack_allowed := true
var sprite_pose: StringName
var sprite_mappings: Dictionary
var sprite_facing := 1
var guard := 1.0
var recovery_guard := 1.0

func setup(type: String) -> void:
	kind = type
	display_name = config.get_value(kind, "name")
	maximum = config.get_value(kind, "health")
	health = maximum
	body_size = config.get_value(kind, "body")
	accent = config.get_value(kind, "accent")
	guard = config.get_value(kind,"guard",1.0)
	recovery_guard = config.get_value(kind,"recovery_guard",1.0)
	var shape := RectangleShape2D.new()
	shape.size = body_size
	$Shape.shape = shape
	$Shape.position.y = -body_size.y * .5
	var frames := config.optional(kind, "frames", "SpriteFrames") as SpriteFrames
	if frames:
		sprite = AnimatedSprite2D.new()
		sprite_mappings = config.get_value(kind,"animations",{})
		sprite_facing = config.get_value(kind,"source_facing",1)
		sprite.sprite_frames = frames
		sprite.position = config.get_value(kind, "offset", Vector2.ZERO)
		sprite.scale = config.get_value(kind, "scale", Vector2.ONE)
		if config.get_value(kind, "filter", "linear") == "nearest":
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)

func hurtbox() -> Rect2:
	return Rect2(position - Vector2(body_size.x * .5, body_size.y), body_size)

func receive(strike) -> bool:
	if dead or not hurtbox().intersects(strike.box) or not strike.register_hit(hit_ids):
		return false
	var multiplier := recovery_guard if mode in [Mode.RECOVER,Mode.STAGGER] else guard
	if strike.source == "counter":
		multiplier = 1.0
	health = Damage.remaining(health,strike.damage,multiplier)
	flashes = .14
	if health == 0:
		dead = true
		change(Mode.DEAD)
		defeated.emit(self)
	elif strike.source == "reversal":
		change(Mode.STAGGER)
		recoil = strike.direction * 290.0
	return true

func repelled(critical: float = 1.0) -> void:
	if dead:
		return
	change(Mode.STAGGER)
	var damage := float(config.get_value(kind,"parry_damage",12))*critical
	receive(Strike.new(hurtbox(), damage, -facing, false, "counter", cursor))

func interrupt() -> void:
	if not dead:
		change(Mode.IDLE)
		clock = -.42
		recoil = 0.0

func change(value: Mode) -> void:
	mode = value
	clock = 0.0

func simulate(dt: float, target: Vector2) -> void:
	clock += dt
	age += dt
	flashes = maxf(0, flashes - dt)
	if dead:
		if clock > .68:
			hide()
		elif sprite:
			update_art()
			sprite.modulate.a = 1.0 - clampf(clock/.68,0,1)
		queue_redraw()
		return
	var distance := absf(target.x - position.x)
	var side := 1.0 if target.x > position.x else -1.0
	velocity = Vector2(0, 180)
	match mode:
		Mode.IDLE:
			if distance <= float(config.get_value(kind,"detection")):
				facing = side
				var pattern: Array = config.get_value(kind,"pattern")
				var next: String = pattern[cursor % pattern.size()]
				var data: Dictionary = config.get_value(kind,next)
				var approach_range := float(data.get("approach",250.0 if next in ["wave","lunge_run"] else float(data.reach)*.8))
				if distance > approach_range:
					velocity.x = side * float(config.get_value(kind,"speed"))
				elif not attack_allowed and distance < 137.0:
					velocity.x = -side * 54.0
				elif attack_allowed and clock >= float(config.get_value(kind,"idle")):
					attack = next
					stats = data
					cursor += 1
					aim = clampf(target.x + facing * (46.0 if next == "lunge_run" else 18.0), limits.x, limits.y)
					change(Mode.WIND)
					telegraph.emit(stats.label,stats.cue)
		Mode.WIND:
			if clock >= float(stats.wind):
				origin = position.x
				change(Mode.ACTIVE)
		Mode.ACTIVE:
			attack_frames()
			if dead or mode == Mode.IDLE:
				update_art()
				return
			if mode == Mode.ACTIVE and clock >= float(stats.active):
				change(Mode.RECOVER)
		Mode.RECOVER:
			if clock >= float(stats.recover):
				change(Mode.IDLE)
		Mode.STAGGER:
			velocity.x = recoil
			recoil = move_toward(recoil,0,dt*660)
			if clock >= float(config.get_value(kind,"stagger")):
				change(Mode.IDLE)
	if not dead:
		move_and_slide()
		position.x = clampf(position.x,limits.x,limits.y)
	update_art()

func attack_frames() -> void:
	var id := cursor
	var reach := float(stats.reach)
	var height := float(stats.height)
	match attack:
		"wave":
			var x := origin + facing * clock * 502.0
			send(Rect2(x-28,572-height,56,height+5),false,id)
		"lunge_run":
			var next := lerpf(origin, aim, minf(1,clock / float(stats.active)))
			var box := Rect2(minf(position.x,next)-32,572-height,absf(position.x-next)+64,height+6)
			position.x = next
			send(box,true,id)
		_:
			send(Strike.forward(position,facing,reach,height,18),true,id)

func send(box: Rect2, parryable: bool, id: int) -> void:
	if mode == Mode.ACTIVE:
		var strike := Strike.new(box,stats.damage,facing,parryable,attack,id)
		strike.knockback = stats.get("knockback",264.0)
		swung.emit(strike)

func update_art() -> void:
	if sprite:
		var pose: String = ["walk" if absf(velocity.x)>10 else "idle",attack+"_wind",attack,attack+"_recover","stagger","death"][mode]
		var animation: StringName = sprite_mappings.get(pose,pose)
		if flashes > 0 and mode not in [Mode.ACTIVE,Mode.DEAD] and sprite.sprite_frames.has_animation("hurt"):
			animation = &"hurt"
		if not sprite.sprite_frames.has_animation(animation) and mode == Mode.RECOVER:
			animation = &"idle"
		sprite.visible = sprite.sprite_frames.has_animation(animation) and sprite.sprite_frames.get_frame_count(animation)>0
		if sprite.visible:
			if animation != sprite_pose:
				sprite.play(animation)
				sprite_pose = animation
			var duration := 0.0
			match mode:
				Mode.WIND: duration = float(stats.wind)
				Mode.ACTIVE: duration = float(stats.active)
				Mode.RECOVER: duration = float(stats.recover)
				Mode.DEAD: duration = .57
			if duration > 0 and not sprite.sprite_frames.get_animation_loop(animation):
				var count := sprite.sprite_frames.get_frame_count(animation)
				var frame := clampf(clock/duration,0.0,.999) * count
				sprite.pause()
				sprite.set_frame_and_progress(int(frame),fposmod(frame,1.0))
			elif not sprite.is_playing() and sprite.sprite_frames.get_animation_loop(animation):
				sprite.play(animation)
			sprite.flip_h = facing * sprite_facing < 0
			sprite.modulate = Color("#ffc5c7") if flashes > 0 else Color.WHITE
	queue_redraw()

func _draw() -> void:
	if maximum <= 0:
		return
	var fade := 1.0 - clampf(clock/.65,0,1) if dead else 1.0
	if fade <= 0.0:
		return
	var height := body_size.y
	var trim := accent.lightened(.48) if flashes > 0 else accent
	var wind := clampf(clock/float(stats.get("wind",1)),0,1) if mode == Mode.WIND else 0.0
	draw_set_transform(Vector2.ZERO,0,Vector2(1,.2))
	draw_circle(Vector2.ZERO,body_size.x*.78,Color("#1a141c",.44*fade))
	if not sprite or not sprite.visible:
		draw_fallback_wolf(fade,wind,trim)
	draw_set_transform(Vector2.ZERO)
	if mode == Mode.WIND:
		var at := Vector2(0,-height-20)
		draw_arc(at,11+wind*11,0,TAU*wind,28,accent,2.8,true)
		if attack == "lunge_run":
			draw_line(Vector2(0,-7),Vector2(aim-position.x,-7),Color(trim,.6),2,true)
			draw_circle(Vector2(aim-position.x,-7),7,trim,false,2,true)
	if mode == Mode.ACTIVE:
		if attack == "wave":
			var at := Vector2(origin-position.x+facing*clock*502,-5)
			draw_arc(at,21,PI,TAU,20,trim,3,true)
		elif not sprite or not sprite.visible:
			var arc_clock := clock
			if arc_clock < .19:
				draw_set_transform(Vector2(0,-height*.50),0,Vector2(facing,.72))
				var radius := minf(float(stats.reach)*.86,136)
				draw_arc(Vector2.ZERO,radius,-1.15,.92,30,Color(trim,1-arc_clock*4),3.4,true)
	draw_set_transform(Vector2.ZERO)


func draw_fallback_wolf(fade: float, wind: float, trim: Color) -> void:
	var scale := body_size.y/91.0
	draw_set_transform(Vector2(0,-body_size.y*.49),facing*(-.18*wind + .75*(1.0-fade)),Vector2(facing,1)*scale)
	var ink := Color("#302932",fade)
	var fur := Color(trim.darkened(.48),fade)
	var stride := sin(age*15.0)*clampf(absf(velocity.x)/150.0,0,1)
	var shoulders := Vector2(15,-15)
	draw_colored_polygon(PackedVector2Array([Vector2(-36,7),Vector2(-22,-14),Vector2(3,-20),shoulders,
		Vector2(27,-1),Vector2(13,22),Vector2(-13,23)]),ink)
	draw_line(Vector2(-19,-3),Vector2(-50,-15),ink,8)
	draw_line(Vector2(-15,13),Vector2(-21-stride*10,45),ink,12)
	draw_line(Vector2(9,13),Vector2(15+stride*10,44),fur,11)
	draw_line(shoulders,Vector2(32,-24),ink,18)
	draw_colored_polygon(PackedVector2Array([Vector2(19,-28),Vector2(23,-45),Vector2(33,-32),
		Vector2(48,-24),Vector2(43,-16),Vector2(25,-16)]),fur)
	draw_rect(Rect2(33,-29,5,2),Color(trim,fade))
