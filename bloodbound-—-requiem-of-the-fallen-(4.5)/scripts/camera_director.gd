extends Camera2D

var shake := 0.0
var rumble := 0.0

func update_frame(dt: float, hero: Vector2, boss: Vector2, focus: float, amount: float, lead: float) -> void:
	var midpoint := (hero.x + boss.x) * .5 + lead
	var change := midpoint - 640
	var target := 640.0
	if absf(change) > 56.0:
		target += signf(change) * (absf(change) - 56.0) * .24
	target = lerpf(target, focus, clampf((amount - 1.0) * 6.0, 0, .68))
	target = clampf(target, 576, 704)
	position = position.lerp(Vector2(target, 360 + (amount - 1.0) * 61.0), 1.0 - exp(-dt * 6.5))
	var span := absf(hero.x - boss.x)
	var safe_zoom := minf(amount, 1200.0 / maxf(900.0, span + 230))
	zoom = zoom.lerp(Vector2.ONE * safe_zoom, 1.0 - exp(-dt * 5.2))
	shake = move_toward(shake, 0, dt * 40)
	rumble += dt * 94
	offset = Vector2(sin(rumble * 1.33), cos(rumble * .94) * .65) * shake

func snap_path(x: float, width: float) -> void:
	position = Vector2(clampf(x + 145.0,640.0,width-640.0),360)
	zoom = Vector2.ONE
	offset = Vector2.ZERO

func follow_path(dt: float, x: float, width: float = 1280.0) -> void:
	var center := clampf(x + 145.0,640.0,width-640.0)
	position = position.lerp(Vector2(center,360),1.0 - exp(-dt * 5.7))
	zoom = zoom.lerp(Vector2.ONE,1.0 - exp(-dt * 4.7))
	offset = Vector2.ZERO

func focus_actor(dt: float, at: Vector2, scale: float) -> void:
	position = position.lerp(at,1.0-exp(-dt*6.0))
	zoom = zoom.lerp(Vector2.ONE*scale,1.0-exp(-dt*7.0))
	offset = Vector2.ZERO

func kick(strength: float) -> void:
	shake = maxf(strength, shake)
