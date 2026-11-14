extends Node2D

const INK := Color("#100d19")
var actor: Node2D
var profile
var imported: AnimatedSprite2D
var last_imported_pose := ""
var boss := false
var palette: Dictionary
var white_blade := false
var blessing := 0.0
var weapon_texture: Texture2D
var weapon_rect: Rect2
var source_facing: int
var phase_locked: Array
var animation_weights: Dictionary = {}
var face_art: Dictionary = {}

func setup(target: Node2D, large: bool) -> void:
	actor = target
	boss = large
	profile = actor.profile
	for key: String in ["armor", "edge", "accent", "steel", "awakened", "final"]:
		palette[key] = profile.get_value("visual", key, Color.WHITE)
	weapon_texture = profile.optional("weapon", "texture", "Texture2D") as Texture2D
	weapon_rect = profile.get_value("weapon", "rect", Rect2(-8, -8, 67, 16))
	if not boss:
		for expression: String in ["neutral","focused","hurt","returning"]:
			face_art[expression] = profile.optional("faces",expression,"Texture2D")
	var frames := profile.optional("visual", "frames", "SpriteFrames") as SpriteFrames
	if frames:
		imported = AnimatedSprite2D.new()
		imported.sprite_frames = frames
		imported.position = profile.get_value("visual", "offset", Vector2.ZERO)
		imported.scale = profile.get_value("visual", "scale", Vector2.ONE)
		source_facing = profile.get_value("visual", "source_facing", 1)
		phase_locked = profile.get_value("visual", "phase_locked", [])
		if profile.get_value("visual", "filter", "linear") == "nearest":
			imported.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(imported)

func redraw() -> void:
	if imported:
		var name: StringName = profile.get_value("animations", actor.pose, actor.pose)
		var dissolved: bool = boss and actor.pose == "dissolve" and actor.phase >= .27
		imported.visible = not dissolved and imported.sprite_frames.has_animation(name) and imported.sprite_frames.get_frame_count(name) > 0
		if imported.visible:
			imported.flip_h = actor.facing * source_facing < 0
			var speed: float = profile.get_value("animation_speed", actor.pose, profile.get_value("visual", "speed", 1.0))
			var follows_phase: bool = actor.pose in phase_locked
			if last_imported_pose != actor.pose:
				imported.stop()
				imported.speed_scale = speed
				imported.play(name)
				if follows_phase:
					imported.pause()
				last_imported_pose = actor.pose
			if follows_phase:
				sample_pose(name, clampf(actor.phase * speed, 0, 1))
			var tint := Color.WHITE
			if boss:
				tint = Color("#e6dcff") if actor.stage < 2 else Color("#dab5ff")
				if actor.pose == "rush_wind":
					tint.a = 1.0 - clampf(actor.phase, 0, 1) * .55
				if actor.hurt_flash > 0:
					tint = Color("#ffc4d8")
				if actor.pose == "dissolve":
					tint.a = 1.0 - smoothstep(0.0, .27, actor.phase)
			imported.modulate = tint
		elif not last_imported_pose.is_empty():
			imported.stop()
			last_imported_pose = ""
	queue_redraw()

func sample_pose(name: StringName, progress: float) -> void:
	if not animation_weights.has(name):
		var total := 0.0
		var ends := PackedFloat32Array()
		for index in imported.sprite_frames.get_frame_count(name):
			total += imported.sprite_frames.get_frame_duration(name, index)
			ends.append(total)
		animation_weights[name] = ends
	var ends: PackedFloat32Array = animation_weights[name]
	var time := progress * ends[-1]
	var index := mini(ends.size() - 1, ends.bsearch(time, false))
	var start := ends[index - 1] if index > 0 else 0.0
	imported.set_frame_and_progress(index, (time - start) / (ends[index] - start))

func _draw() -> void:
	if not is_instance_valid(actor):
		return
	if boss and actor.pose == "dissolve" and actor.phase >= 0.27:
		return
	draw_set_transform(Vector2.ZERO, 0, Vector2(1.0, 0.20))
	draw_circle(Vector2.ZERO, 55.0 if boss else 31.0, Color(.02, .01, .03, .62))
	if imported and imported.visible:
		return
	var t: float = actor.visual_time
	var p: float = actor.phase
	var state: String = actor.pose
	var face: float = actor.facing
	var armor: Color = palette.armor
	var edge: Color = palette.edge
	var accent: Color = palette.accent
	var blade: Color = palette.steel
	if not boss and actor.awakened:
		blade = palette.awakened
	if blessing > 0.0:
		blade = blade.lerp(Color("#ffd59a"),clampf(blessing,0,1))
	if white_blade:
		blade = palette.final
	var bob := sin(t * (2.5 if boss else 4.6)) * (1.8 if boss else 1.05)
	if not boss and actor.health > 0 and actor.health <= actor.maximum*.30:
		bob += sin(t*10.0)*.83
	var stride := 0.0
	var lean := 0.0
	var crouch := 0.0
	var angle := .36
	var wind := sin(t * 6.8) * 3.0
	var attacking := state in ["light_1", "light_2", "light_3", "air", "heavy", "sever", "intro_slash", "cleave", "slam", "rush", "throne", "final_strike"]
	var charging := state in ["charge", "final_prepare", "doom", "final_attack"] or state.ends_with("_wind") or state == "draw_blade"
	var airborne := state in ["jump_start", "rise", "fall", "air"]
	var dashing := state in ["dash", "dodge", "rush", "final_dash"]
	var fallen := state in ["death", "fallen", "resurrect", "reversal"]
	if state in ["run", "walk"]:
		stride = sin(t * (14.8 if boss else 21.0))
		bob -= absf(stride) * 3.6
		lean = .11
		angle = .84
	elif airborne:
		crouch = -3
		stride = .82 if state != "fall" else -.63
		bob = 0
	elif state == "land":
		crouch = 5.0
	elif dashing:
		lean = .35
		crouch = 6.0
		angle = 1.28
		stride = .76
		wind -= 13.0
	elif state in ["hurt", "knockback", "execution_hit", "stagger"]:
		lean = -.16 - sin(clampf(p, 0, 1) * PI) * .12
		crouch = 5.0
		angle = 0.55
		armor = armor.lightened(.17)
	elif state in ["parry", "parry_success"]:
		angle = -.91
		lean = -.05
		crouch = 4
	elif charging:
		var ease := smoothstep(0.0, 1.0, clampf(p, 0, 1))
		angle = lerpf(.38, -2.08, ease)
		lean = -.13 * ease
		crouch = 3.2 + ease * 4
		if state == "rush_wind":
			lean = .27
		if state in ["final_prepare", "charge"]:
			angle = -.98 + sin(t * 68.0) * .035
			lean = .08
	elif state.ends_with("_recover"):
		angle = lerpf(1.4, .36, clampf(p, 0, 1))
		crouch = 4.8 * (1.0 - p)
	elif state in ["crown_break", "transform", "desperate"]:
		lean = -.14
		angle = -1.54
	elif state in ["finish", "victory"]:
		angle = lerpf(1.19, .42, clampf(p, 0, 1))
		lean = .10 * (1.0 - p)
	if attacking:
		if boss and state == "throne":
			p = fposmod(p * 2.6 + .15, 1.0)
		var swing := smoothstep(.10, .72, clampf(p, 0.0, 1.0))
		var start_angle := -2.18
		var end_angle := 1.72
		if state == "light_2":
			start_angle = 1.78
			end_angle = -1.74
		angle = lerpf(start_angle, end_angle, swing)
		lean = -.12 + swing * .31
		crouch += swing * 3.7
		if boss and state != "throne":
			angle = lerpf(-1.93, 1.71, smoothstep(0.0, .48, p))
	if boss and actor.hurt_flash > 0:
		edge = edge.lerp(Color("#ffcce8"), .77)
	var alpha := 1.0
	if state == "rush_wind":
		alpha *= .95 - p * .57
	if fallen:
		var fall := 1.0 if state == "fallen" else smoothstep(0.0, 1.0, clampf(p, 0, 1))
		if state == "resurrect":
			fall = 1.0 - fall
		lean = -1.37 * fall
		bob = -9.0 * fall
		crouch = 3.5 * fall
	var unit := 2.30 if boss else 1.10
	var pivot := Vector2(0, -34 * unit)
	var root := pivot + Vector2(0, (bob + crouch) * unit)
	draw_set_transform(root, face * lean, Vector2(face * unit, unit))
	var cloth := accent.darkened(.46)
	var cloak := -18.0 + wind
	poly([Vector2(-12,-24), Vector2(12,-22), Vector2(10,1), Vector2(-8,10),
		Vector2(cloak - 1, 27), Vector2(cloak - 16, 33), Vector2(cloak - 14, 7), Vector2(-15,-3)], Color(cloth, alpha))
	line([Vector2(-10,-21), Vector2(-12,0), Vector2(cloak - 5,25)], Color(accent, alpha * .67), 1.2)
	leg(Vector2(-8, 3), -stride, Color(armor.darkened(.37), alpha), Color(edge.darkened(.31), alpha), airborne)
	leg(Vector2(7, 5), stride, Color(armor, alpha), Color(edge, alpha), airborne)
	poly([Vector2(-13,-22), Vector2(7,-24), Vector2(17,-13), Vector2(11,6), Vector2(3,12),
		Vector2(-10,8), Vector2(-15,-4)], Color(armor, alpha))
	line([Vector2(-13,-20), Vector2(6,-22), Vector2(13,-15), Vector2(2,-8),
		Vector2(-10,-13), Vector2(-6,3), Vector2(7,6)], Color(edge, alpha), 1.2)
	poly([Vector2(-11,-2), Vector2(10,1), Vector2(8,6), Vector2(-10,4)], Color(INK,alpha))
	draw_circle(Vector2(2,2), 2.0, Color(accent,alpha), true, -1, true)
	if boss:
		poly([Vector2(-12,-24), Vector2(-5,-36), Vector2(6,-38), Vector2(14,-29), Vector2(14,-19),
			Vector2(6,-15), Vector2(-5,-17)], Color(armor.darkened(.47),alpha))
		poly([Vector2(-11,-25), Vector2(-6,-36), Vector2(5,-37), Vector2(14,-30), Vector2(5,-26),
			Vector2(-2,-20)], Color(armor.lightened(.09), alpha))
		line([Vector2(-8,-31), Vector2(-5,-36), Vector2(4,-38), Vector2(12,-32)], Color(edge, alpha), 1.05)
		draw_line(Vector2(5,-27), Vector2(13,-29), Color(accent.lightened(.55), alpha), 1.35, true)
		crown(t, state, accent, alpha)
	else:
		draw_hero_face(state,t,wind,accent,alpha)
		draw_line(Vector2(3,6),Vector2(-28,20),Color("#211926",alpha),4.8,true)
		draw_line(Vector2(1,7),Vector2(-26,19),Color(edge,.52*alpha),1.05,true)
	if not boss:
		poly([Vector2(7,-23), Vector2(-13,-24), Vector2(-24 + wind,-23),
			Vector2(-36 + wind,-16), Vector2(-23 + wind,-19), Vector2(-13,-18), Vector2(7,-19)], Color(accent.darkened(.27), alpha))
	var shoulder := Vector2(10,-15)
	var hand := Vector2(19, -4) + Vector2.from_angle(angle - 1.4) * 8.6
	if state in ["parry", "parry_success", "charge", "final_prepare"]:
		hand = Vector2(15, -10)
	elif state == "draw_blade":
		hand = Vector2(-8,7).lerp(hand,smoothstep(.12,.75,p))
		angle = lerpf(2.68,angle,smoothstep(.12,.75,p))
	draw_line(shoulder, hand, Color(INK, alpha), 9.5, true)
	draw_line(shoulder, hand, Color(armor.lightened(.14), alpha), 6.4, true)
	draw_line(shoulder.lerp(hand, .4), hand, Color(edge, alpha * .78), 2.2, true)
	poly([shoulder + Vector2(-6,-5), shoulder + Vector2(4,-5), shoulder + Vector2(8,0),
		shoulder + Vector2(1,7), shoulder + Vector2(-5,4)], Color(armor.lightened(.11), alpha))
	if not fallen or state == "resurrect":
		var sword_scale := 1.12 if boss else 1.19
		var glow: bool = white_blade or (not boss and actor.awakened) or blessing > 0.0
		if weapon_texture:
			var body_transform := Transform2D(face * lean, Vector2(face * unit, unit), 0.0, root)
			draw_set_transform_matrix(body_transform * Transform2D(angle, hand))
			var tint := Color.WHITE.lerp(blade, .47) if glow else Color.WHITE
			draw_texture_rect(weapon_texture, weapon_rect, false, Color(tint, alpha))
		else:
			sword(hand, angle, blade, accent, sword_scale, alpha, glow)
	draw_set_transform(Vector2.ZERO)

func draw_hero_face(state: String, time: float, wind: float, accent: Color, alpha: float) -> void:
	var injured := state in ["hurt","knockback","death","reversal"]
	var focused := state in ["draw_blade","final_prepare","intro_slash","parry","sever","light_1","light_2","light_3","heavy"]
	var expression := "hurt" if injured else ("returning" if state == "resurrect" else ("focused" if focused else "neutral"))
	var texture: Texture2D = face_art.get(expression)
	if texture:
		draw_texture_rect(texture,Rect2(-17,-47,34,29),false,Color(1,1,1,alpha))
		return
	var skin := Color("#d5a18d",alpha)
	var shade := Color("#9d6769",alpha)
	var hair := Color("#1b1726",alpha)
	poly([Vector2(-9,-38),Vector2(8,-39),Vector2(13,-34),Vector2(17,-30),Vector2(13,-27),
		Vector2(9,-22),Vector2(3,-19),Vector2(-7,-23),Vector2(-12,-31)],skin)
	poly([Vector2(-9,-32),Vector2(-1,-27),Vector2(9,-23),Vector2(3,-19),Vector2(-7,-23)],shade)
	poly([Vector2(-15,-27),Vector2(-16,-41),Vector2(-7,-43),Vector2(-2,-49),
		Vector2(6,-45),Vector2(16,-45),Vector2(12,-39),Vector2(18,-36),
		Vector2(8,-34),Vector2(4,-29),Vector2(1,-36),Vector2(-6,-28),
		Vector2(-8,-33)],hair)
	poly([Vector2(-12,-38),Vector2(-8,-36),Vector2(-14,-28),
		Vector2(-20+clampf(wind,-5,3)*.62,-23),Vector2(-18,-32)],hair)
	line([Vector2(-7,-43),Vector2(0,-43),Vector2(3,-35)],Color(accent.lightened(.18),alpha),1.65)
	var blink := fposmod(time,3.65) > 3.50
	var eye_height := 0.0 if blink or injured else (1.0 if focused else 1.9)
	var eye := Vector2(9,-31)
	draw_line(eye+Vector2(-4,0),eye+Vector2(4,-eye_height*.7),hair,2.1,true)
	if eye_height > 0:
		draw_line(eye+Vector2(-2,1),eye+Vector2(3,.55),Color("#f0d5c7",alpha),eye_height,true)
		draw_circle(eye+Vector2(1.6,.55),1.1,Color("#8e303d",alpha),true,-1,true)
	draw_line(Vector2(3,-27),Vector2(7,-24),Color("#ad535c",alpha),1.0,true)
	draw_line(Vector2(10,-23),Vector2(13,-24),hair,.8,true)

func leg(hip: Vector2, stride: float, armor: Color, trim: Color, airborne: bool) -> void:
	var knee := hip + Vector2(stride * 11.0, 13.0 if not airborne else 7.0)
	var foot := knee + Vector2(stride * 6.0 - 2.0, 14.0 - absf(stride) * 5.0)
	draw_line(hip, knee, Color(INK, armor.a), 9, true)
	draw_line(hip, knee, armor, 6.8, true)
	draw_line(knee, foot, armor.darkened(.31), 6.2, true)
	draw_line(knee, foot + Vector2(3,-1), trim, 1.3, true)
	poly([foot + Vector2(-4,-4), foot + Vector2(3,-4), foot + Vector2(8,0),
		foot + Vector2(7,3), foot + Vector2(-4,3)], armor.darkened(.23))

func crown(t: float, state: String, accent: Color, alpha: float) -> void:
	var y := -42.0 + sin(t * 3.0) * 1.8
	var fracture := .0 if actor.stage < 2 else .85
	if state == "crown_break":
		fracture = smoothstep(.13,.73,actor.phase)
	for side: float in [-1.0, 1.0]:
		var x := side * (5.0 + fracture * 7.0)
		draw_circle(Vector2(x,y), 6.0, Color(accent, alpha * .10), true, -1, true)
		line([Vector2(x - 4,y+2), Vector2(x-6,y-6), Vector2(x,y-1),
			Vector2(x+3,y-7), Vector2(x+4,y+1), Vector2(x-4,y+2)], Color(accent, alpha * .81), .72)

func sword(hand: Vector2, angle: float, blade: Color, accent: Color, length: float, alpha: float, glow: bool) -> void:
	var d := Vector2.from_angle(angle)
	var n := d.orthogonal()
	var origin := hand + d * 4
	var tip := origin + d * (44.0 * length)
	var shoulder := origin + d * 7
	if glow:
		for width: float in [13, 8, 4]:
			draw_line(origin, tip, Color(accent.lerp(blade,.48), alpha * .12), width, true)
	poly([origin - n*2.6, shoulder - n*3.3, tip, tip - d*7 + n*2.2, origin + n*2.4], Color(blade, alpha))
	draw_line(origin - n * 2.6, tip, Color(blade.lightened(.45), alpha * .92), .8, true)
	draw_line(hand - n*6.5, hand + n*6.5, Color(accent.darkened(.18), alpha), 2.3, true)
	draw_line(hand - d*8, hand, Color(INK, alpha), 3, true)

func poly(points: Array[Vector2], color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func line(points: Array[Vector2], color: Color, width: float) -> void:
	draw_polyline(PackedVector2Array(points), color, width, true)
