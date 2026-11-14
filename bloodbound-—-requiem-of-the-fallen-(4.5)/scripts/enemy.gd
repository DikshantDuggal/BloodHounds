extends CharacterBody2D

signal swung(strike)
signal telegraph(label: String, cue: String)
signal defeated(enemy)
signal transformed(enemy)

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
var home: float
var mode := Mode.IDLE
var clock := 0.0
var age := 0.0
var facing := -1.0
var dead := false
var attack := ""
var cursor := 0
var phase := 1
var stats: Dictionary
var config := Profile.new("res://resources/enemies.cfg")
var accent: Color
var aim: float
var origin: float
var melee_hit := -1
var ability_hits: Dictionary = {}
var counter_hit := -1
var flashes := 0.0
var recoil := 0.0
var sprite: AnimatedSprite2D

func setup(type: String) -> void:
	kind = type
	home = position.x
	display_name = config.get_value(kind, "name")
	maximum = config.get_value(kind, "health")
	health = maximum
	body_size = config.get_value(kind, "body")
	accent = config.get_value(kind, "accent")
	var shape := RectangleShape2D.new()
	shape.size = body_size
	$Shape.shape = shape
	$Shape.position.y = -body_size.y * .5
	var frames := config.optional(kind, "frames", "SpriteFrames") as SpriteFrames
	if frames:
		sprite = AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		sprite.position = config.get_value(kind, "offset", Vector2.ZERO)
		sprite.scale = config.get_value(kind, "scale", Vector2.ONE)
		if config.get_value(kind, "filter", "linear") == "nearest":
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)

func hurtbox() -> Rect2:
	return Rect2(position - Vector2(body_size.x * .5, body_size.y), body_size)

func receive(strike) -> bool:
	if dead or not hurtbox().intersects(strike.box) or already_hit(strike):
		return false
	var guard := float(config.get_value(kind, "guard", 1.0))
	var multiplier := 1.0 if mode in [Mode.RECOVER, Mode.STAGGER] else guard
	var threshold := roundi(maximum * float(config.get_value(kind,"phase_threshold",0.0)))
	var floor_hp := threshold if phase == 1 else 0
	health = Damage.remaining(health,strike.damage,multiplier,floor_hp)
	flashes = .14
	if health == 0:
		dead = true
		change(Mode.DEAD)
		defeated.emit(self)
	elif phase == 1 and threshold > 0 and health <= threshold:
		phase = 2
		cursor = 0
		interrupt()
		transformed.emit(self)
	elif kind == "shadow" or strike.source == "reversal":
		change(Mode.STAGGER)
		recoil = strike.direction * (290.0 if strike.source == "reversal" else 100.0)
	return true

func already_hit(strike) -> bool:
	if strike.source == "counter":
		if counter_hit == strike.id:
			return true
		counter_hit = strike.id
	elif strike.source in ["reversal","sever","echo"]:
		if strike.id <= int(ability_hits.get(strike.source,-1)):
			return true
		ability_hits[strike.source] = strike.id
	else:
		if strike.id <= melee_hit:
			return true
		melee_hit = strike.id
	return false

func repelled(critical: float = 1.0) -> void:
	if dead:
		return
	change(Mode.STAGGER)
	receive(Strike.new(hurtbox(), float(config.get_value(kind,"parry_damage",12))*critical, -facing, false, "counter", -100 - phase * 10000 - cursor))

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
				var pattern: Array = config.get_value(kind,"phase_pattern" if phase == 2 else "pattern")
				var next: String = pattern[cursor % pattern.size()]
				var data: Dictionary = config.get_value(kind,next)
				var approach_range := 250.0 if next in ["orb","teleport","charge","wave"] else float(data.reach) * .8
				if distance > approach_range:
					velocity.x = side * float(config.get_value(kind,"speed"))
				elif clock >= float(config.get_value(kind,"idle")):
					attack = next
					stats = data
					cursor += 1
					aim = clampf(target.x + facing * (-92.0 if next == "teleport" else 18.0), limits.x, limits.y)
					change(Mode.WIND)
					telegraph.emit(stats.label,stats.cue)
			elif kind == "shadow":
				velocity.x = signf(home + sin(age * 1.6) * float(config.get_value(kind,"patrol")) - position.x) * 68.0
				if not is_zero_approx(velocity.x):
					facing = signf(velocity.x)
		Mode.WIND:
			if clock >= float(stats.wind):
				origin = position.x
				change(Mode.ACTIVE)
		Mode.ACTIVE:
			attack_frames()
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
	var id := phase * 10000 + cursor * 10
	var reach := float(stats.reach)
	var height := float(stats.height)
	match attack:
		"wave":
			var x := origin + facing * clock * 502.0
			send(Rect2(x-28,572-height,56,height+5),false,id)
		"orb":
			var x := origin + facing * (34 + clock * 410)
			send(Rect2(x-16,507,32,32),true,id)
		"charge":
			var next := lerpf(origin, aim, minf(1,clock / float(stats.active)))
			var box := Rect2(minf(position.x,next)-32,572-height,absf(position.x-next)+64,height+6)
			position.x = next
			send(box,true,id)
		"teleport":
			if clock <= .035:
				position.x = aim
				facing = signf(origin-aim)
			send(Strike.forward(position,facing,reach,height,24),true,id)
		"triple":
			for i in 3:
				var start := .03 + i * .42
				if clock >= start and clock <= start+.14:
					send(Strike.forward(position,facing,reach,height,24),true,id+i)
		_:
			send(Strike.forward(position,facing,reach,height,18),true,id)

func send(box: Rect2, parryable: bool, id: int) -> void:
	if mode == Mode.ACTIVE:
		swung.emit(Strike.new(box,stats.damage,facing,parryable,attack,id))

func update_art() -> void:
	if sprite:
		var pose: String = ["walk" if absf(velocity.x)>10 else "idle",attack+"_wind",attack,attack+"_recover","stagger","death"][mode]
		var mappings: Dictionary = config.get_value(kind,"animations",{})
		var animation: StringName = mappings.get(pose,pose)
		sprite.visible = sprite.sprite_frames.has_animation(animation) and sprite.sprite_frames.get_frame_count(animation)>0
		if sprite.visible:
			sprite.play(animation)
			sprite.flip_h = facing * int(config.get_value(kind,"source_facing",1)) < 0
			sprite.modulate = Color("#ffc5c7") if flashes > 0 else Color.WHITE
	queue_redraw()

func _draw() -> void:
	if maximum <= 0:
		return
	var fade := 1.0 - clampf(clock/.65,0,1) if dead else 1.0
	if fade <= 0.0:
		return
	var height := body_size.y
	var ink := Color("#211a25") if kind != "spirit" else Color("#b0a089")
	var trim := accent.lightened(.48) if flashes > 0 or phase == 2 else accent
	var wind := clampf(clock/float(stats.get("wind",1)),0,1) if mode == Mode.WIND else 0.0
	var impact := clampf(clock/.15,0,1) if mode == Mode.ACTIVE else 0.0
	draw_set_transform(Vector2.ZERO,0,Vector2(1,.2))
	draw_circle(Vector2.ZERO,body_size.x*.78,Color("#1a141c",.44*fade))
	var step := sin(age*15.0) * clampf(absf(velocity.x)/120.0,0,1)
	var turn := -.12*wind + .22*impact + .7*(1-fade)
	draw_set_transform(Vector2(0,-height*.49), facing*turn, Vector2(facing,1))
	if not sprite or not sprite.visible:
		var scale := height / 96.0
		var robe := PackedVector2Array([Vector2(-16,-30),Vector2(14,-30),Vector2(25,5),Vector2(20+step*10,36),
			Vector2(-1,22),Vector2(-25-step*8,39),Vector2(-21,1)])
		for i in robe.size():
			robe[i] *= scale
		draw_colored_polygon(robe,Color(ink,fade))
		draw_line(Vector2(-8*scale,23*scale),Vector2((-14-step*12)*scale,46*scale),Color(ink,fade),8*scale,true)
		draw_line(Vector2(8*scale,22*scale),Vector2((14+step*12)*scale,46*scale),Color(ink,fade),8*scale,true)
		draw_circle(Vector2(1,-39)*scale,(13 if kind=="warden" else 9)*scale,Color(ink,fade),true,-1,true)
		if kind in ["warden","guardian"]:
			var helmet := PackedVector2Array([Vector2(-19,-43),Vector2(-8,-57),Vector2(16,-52),Vector2(24,-40),Vector2(15,-32),Vector2(-7,-33)])
			for i in helmet.size():
				helmet[i] *= scale
			draw_colored_polygon(helmet,Color("#483039",fade))
			draw_line(Vector2(-21,-27)*scale,Vector2(24,-29)*scale,Color(trim,.83*fade),4.1,true)
		elif kind in ["spirit","rival"]:
			draw_arc(Vector2(0,-42)*scale,17*scale,PI*.86,TAU*1.07,28,Color(trim,.57*fade),1.45,true)
			draw_polyline(PackedVector2Array([Vector2(-10,-42),Vector2(-16,-19),Vector2(-38,-13+step*4)]),Color(trim,.82*fade),2,true)
		draw_line(Vector2(-9,-39)*scale,Vector2(12,-41)*scale,Color(trim,fade),2.5,true)
		draw_line(Vector2(-12,-24)*scale,Vector2(13,3)*scale,Color(trim,.71*fade),2.2,true)
		var hilt := Vector2(19,-14)*scale
		var angle := -.54 - wind*1.65 + impact*1.94
		var tip := hilt + Vector2.from_angle(angle)*(54 if kind=="warden" else 42)*scale
		draw_line(hilt,tip,Color("#25212a",fade),6.5*scale,true)
		draw_line(hilt,tip,Color(trim,fade),2.4*scale,true)
		if kind == "rival":
			var offhand := Vector2(-17,-10)*scale
			draw_line(offhand,offhand+Vector2.from_angle(2.1-angle*.45)*39*scale,Color(trim,.85*fade),3.4,true)
	draw_set_transform(Vector2.ZERO)
	if mode == Mode.WIND:
		var at := Vector2(0,-height-20)
		draw_arc(at,11+wind*11,0,TAU*wind,28,accent,2.8,true)
		if attack in ["teleport","charge"]:
			draw_line(Vector2(0,-7),Vector2(aim-position.x,-7),Color(trim,.6),2,true)
			draw_circle(Vector2(aim-position.x,-7),7,trim,false,2,true)
	if mode == Mode.ACTIVE:
		if attack == "orb":
			var at := Vector2(origin-position.x+facing*(34+clock*410),-49)
			draw_circle(at,17,Color(trim,.55))
			draw_circle(at,8,trim)
		elif attack == "wave":
			var at := Vector2(origin-position.x+facing*clock*502,-5)
			draw_arc(at,21,PI,TAU,20,trim,3,true)
		else:
			var arc_clock := fposmod(clock,.42) if attack=="triple" else clock
			if arc_clock < .19:
				draw_set_transform(Vector2(0,-height*.50),0,Vector2(facing,.72))
				var radius := minf(float(stats.reach)*.86,136)
				draw_arc(Vector2.ZERO,radius,-1.15,.92,30,Color(trim,1-arc_clock*4),3.4,true)
	draw_set_transform(Vector2.ZERO)
