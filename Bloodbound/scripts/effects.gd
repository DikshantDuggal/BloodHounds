extends Node2D

const CAPACITY := 360
const BLOOD_IMPACT = preload("res://assets/last_oath/blood_impact.png")
var impacts: Array[Vector4] = []
var blade_echoes: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var arcs: Array[Dictionary] = []
var ghosts: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var hero
var boss
var director
var debug := false
var latest_boxes: Array[Rect2] = []
var box_life := 0.0
var oath_ramp := preload("res://resources/oath_gradient.tres")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func tick(dt: float) -> void:
	for i in range(blade_echoes.size()-1,-1,-1):
		blade_echoes[i].life -= dt
		if blade_echoes[i].life <= 0:
			blade_echoes.remove_at(i)
	for i in range(impacts.size()-1,-1,-1):
		impacts[i].w += dt
		if impacts[i].w >= .31:
			impacts.remove_at(i)
	for i in range(particles.size() - 1, -1, -1):
		var item := particles[i]
		item.life -= dt
		if item.life <= 0:
			particles.remove_at(i)
			continue
		item.v.y += float(item.gravity) * dt
		item.at += item.v * dt
	for i in range(arcs.size() - 1, -1, -1):
		arcs[i].life -= dt
		if arcs[i].life <= 0:
			arcs.remove_at(i)
	for i in range(ghosts.size() - 1, -1, -1):
		ghosts[i].life -= dt
		if ghosts[i].life <= 0:
			ghosts.remove_at(i)
	box_life -= dt
	if box_life <= 0:
		latest_boxes.clear()
	queue_redraw()

func clear() -> void:
	impacts.clear()
	blade_echoes.clear()
	particles.clear()
	arcs.clear()
	ghosts.clear()
	latest_boxes.clear()

func burst(at: Vector2, color: Color, count: int, speed: float, gravity: float = 280.0, lifespan: float = .52) -> void:
	for i in mini(count, CAPACITY - particles.size()):
		var heading := Vector2.from_angle(rng.randf_range(-PI, PI))
		var life := rng.randf_range(lifespan * .47, lifespan)
		particles.append({"at": at, "v": heading * rng.randf_range(speed * .25, speed),
			"color": color, "life": life, "total": life, "gravity": gravity, "width": rng.randf_range(1.0, 3.5)})

func arc(at: Vector2, facing: float, radius: float, color: Color, reverse: bool = false, oath: bool = false) -> void:
	arcs.append({"at": at, "face": facing, "radius": radius, "color": color,
		"reverse": reverse, "oath": oath, "life": .25, "total": .25})

func ghost(at: Vector2, facing: float, color: Color, size: float = 1.0) -> void:
	if ghosts.size() < 32:
		ghosts.append({"at": at, "face": facing, "color": color, "size": size, "life": .21})

func blade_echo(pose: Transform2D, color: Color, offset: Vector2) -> void:
	if blade_echoes.size() < 8:
		pose.origin += offset
		blade_echoes.append({"pose":pose,"color":color,"life":.25})

func bleed(at: Vector2, direction: float) -> void:
	if impacts.size() < 12:
		impacts.append(Vector4(at.x,at.y,direction,0))

func show_box(box: Rect2) -> void:
	if not debug:
		return
	if latest_boxes.size() >= 12:
		latest_boxes.pop_front()
	latest_boxes.append(box)
	box_life = .07

func _draw() -> void:
	if not is_instance_valid(director):
		return
	draw_boss_cues()
	draw_story()
	draw_weapon_effects()
	for impact in impacts:
		var frame := mini(int(impact.w*33.0),9)
		draw_set_transform(Vector2(impact.x,impact.y),0,Vector2(-impact.z,1))
		draw_texture_rect_region(BLOOD_IMPACT,Rect2(-55,-21,110,41.25),Rect2(frame*64,0,64,24),Color("#ff96a6"))
	draw_set_transform(Vector2.ZERO)
	for wave in director.powers.waves:
		var at: Vector2 = wave.at
		draw_set_transform(at,0,Vector2(wave.facing*.7,1.0))
		draw_arc(Vector2(-16,0),34,-.96,.96,25,Color("#a87aea",.34),12,true)
		draw_arc(Vector2(-16,0),34,-.96,.96,25,Color("#ebcef9"),3.2,true)
		draw_set_transform(Vector2.ZERO)
	for item in ghosts:
		var opacity := float(item.life) / .21
		var at: Vector2 = item.at
		var size: float = item.size
		var facing: float = item.face
		var color: Color = item.color
		draw_line(at + Vector2(-28 * facing, -20) * size, at + Vector2(16 * facing, -49) * size,
			Color(color, opacity * .22), 17 * size, true)
		draw_line(at + Vector2(-51 * facing, -36) * size, at + Vector2(28 * facing, -43) * size,
			Color(color, opacity * .35), 2 * size, true)
	for item in arcs:
		var p := 1.0 - float(item.life) / float(item.total)
		var radius: float = item.radius
		var color: Color = item.color
		var sign := -1.0 if item.reverse else 1.0
		draw_set_transform(item.at, 0, Vector2(item.face, .69))
		var head := sign * lerpf(-1.25, 1.52, minf(1.0, p * 2.8))
		var tail := head - sign * (1.52 + p * .62)
		if item.oath:
			draw_oath_arc(radius, tail, head, p)
		else:
			var ribbon := crescent(radius, tail, head, 8 + radius * .082, 0.0, 1.0)
			if p < .96:
				draw_colored_polygon(ribbon, Color(color, (1-p)*.31))
			draw_polyline(ribbon.slice(0, 25), Color(color.lightened(.35), (1-p)*.94), 1.9, true)
		draw_set_transform(Vector2.ZERO)
	for item in particles:
		var strength := pow(float(item.life) / float(item.total), .7)
		var at: Vector2 = item.at
		var velocity: Vector2 = item.v
		var color: Color = item.color
		draw_line(at, at - velocity * .019, Color(color, strength), float(item.width) * strength, true)
	if debug:
		draw_rect(hero.hurtbox(), Color("#61e5d6"), false, 1)
		draw_rect(boss.hurtbox(), Color("#a394fd"), false, 1)
		for box in latest_boxes:
			draw_rect(box, Color(1, .36, .52, .15))
			draw_rect(box, Color("#f97d91"), false, 1)

func crescent(radius: float, tail: float, head: float, width: float, outer: float, inner: float) -> PackedVector2Array:
	var ribbon := PackedVector2Array()
	for side in [outer, inner]:
		for i in 25:
			var u := i / 24.0
			if side == inner:
				u = 1.0 - u
			var shape := .04 + pow(sin(u * PI), .72) * (0.58 + u * .42)
			ribbon.append(Vector2.from_angle(lerpf(tail, head, u)) * (radius - shape * width * side))
	return ribbon

func draw_oath_arc(radius: float, tail: float, head: float, progress: float) -> void:
	var fade := 1.0 - smoothstep(.17, 1.0, progress)
	var width := (12.0 + radius * .18) * (1 - progress * .48)
	draw_colored_polygon(crescent(radius + 5, tail, head, width + 17, 0.0, 1.0),
		Color(oath_ramp.sample(.66), fade * .19))
	for band in 7:
		var from := band / 7.0
		var to := (band + 1) / 7.0
		draw_colored_polygon(crescent(radius, tail, head, width, from, to),
			Color(oath_ramp.sample(from), fade * (1.0 - from * .22)))
	for i in 4:
		var u := .13 + i * .22
		var head_angle := lerpf(tail, head, u)
		var a := Vector2.from_angle(head_angle)
		draw_line(a * (radius + 3.0), a.rotated(.14) * (radius + 6.0 + i * 1.8),
			Color(oath_ramp.sample(.15), fade * .74), 1.4, true)

func draw_oath_impact(at: Vector2, p: float, length: float) -> void:
	var fade := 1.0 - smoothstep(.25, 1.0, p)
	for i in 12:
		var angle := i * TAU / 12.0 + sin(i * 4.6) * .19
		var d := Vector2.from_angle(angle)
		var n := d.orthogonal()
		var width := (5.0 + i % 4 * 2) * fade
		var radius := length * (.51 + absf(sin(i * 8.2)) * .49) * (.45 + p * .55)
		var a := at + d * radius
		var b := at + d * radius * .40
		draw_colored_polygon(PackedVector2Array([at, b + n * width, a, b - n * width * .6]),
			Color(oath_ramp.sample(.27 + (i % 5) * .11), fade * .80))
	draw_circle(at, 24.0 * fade, Color(oath_ramp.sample(.56), fade * .26))
	draw_circle(at, 7.0 * fade, Color(oath_ramp.sample(0), fade), true, -1.0, true)
	draw_line(at - Vector2(length * 1.15, 0), at + Vector2(length * 1.15, 0),
		Color(oath_ramp.sample(.1), fade * .72), 1.8, true)

func draw_boss_cues() -> void:
	if not boss.visible:
		return
	var purple := Color("#fa7543") if boss == director.overlord else Color("#ba8cf6")
	var gold := Color("#ffcb9e")
	var at: Vector2 = boss.position
	var clock: float = boss.clock
	if boss.mode == boss.Mode.WIND:
		var p: float = boss.phase
		var pulse := .55 + .35 * sin(director.elapsed * 22)
		if boss.attack == "ruin":
			for x: float in boss.marks:
				var warning := Rect2(x - 52, 556, 104, 16)
				draw_rect(warning, Color(purple, .21 + p * .3))
				draw_line(Vector2(x - 52, 569), Vector2(x + 52, 569), Color(purple, pulse), 2, true)
				rune(Vector2(x, 553), 12 + p * 9, Color(purple, pulse))
				if boss == director.overlord:
					draw_line(Vector2(x,471),Vector2(x,560),Color(purple,p*.5),3)
				else:
					draw_ruin_projectile(Vector2(x,280+p*82),62.0,Color(purple,p*.78))
		elif boss.attack in ["rush","teleport"]:
			draw_line(Vector2(at.x, 561), Vector2(boss.aim, 561), Color(purple, .33), 2.0, true)
			rune(Vector2(boss.aim, 550), 15 + p * 12, Color(purple, pulse))
		elif boss.attack == "slam":
			draw_line(Vector2(at.x - 55 * p, 567), Vector2(at.x + 55 * p, 567), Color(gold, pulse), 3, true)
		if p > .42:
			rune(at + Vector2(38 * boss.facing, -145), 8.0 + 10.0 * p, Color(purple.lerp(gold,.43), pulse))
	elif boss.mode == boss.Mode.ACTIVE:
		if boss.attack == "slam":
			for side: float in boss.wave_directions():
				var x: float = boss.origin + side * clock * 620
				var points := PackedVector2Array([Vector2(x - side*31,570), Vector2(x,540), Vector2(x + side*25,570)])
				draw_colored_polygon(points, Color(purple, .30))
				draw_polyline(points, Color("#ead4ff"), 1.8, true)
		if boss.attack == "ruin":
			for x: float in boss.marks:
				if boss == director.overlord:
					var height := 172.0*clampf(clock*7,0,1)
					for width: float in [82,48,19]:
						draw_line(Vector2(x,570),Vector2(x,570-height),Color(purple,.16*(1.0-clock)),width)
				else:
					draw_ruin_projectile(Vector2(x,minf(573.0,368.0+clock*1530)),104.0,Color(purple,1.0-clock))
				draw_line(Vector2(x, 394), Vector2(x, 570), Color(purple, maxf(0, .23 - clock * .42)), 2)
		if boss.attack == "throne":
			var next: float = .70 if clock < .70 else 1.37
			var difference := next - clock
			if difference > 0.0 and difference < .35:
				var final_beat := next > 1.0
				rune(at + Vector2(74 * boss.facing, -110), 22.0 - difference * 30,
					Color(Color("#ffefbf") if final_beat else purple, .86))

func draw_story() -> void:
	var at: Vector2 = hero.position
	var t: float = director.clock
	var red := Color("#ff486d")
	if director.state == director.State.TRANSITION and director.next_stage == 2:
		var crown: Vector2 = boss.position + Vector2(0,-178)
		var p := smoothstep(.52,1.78,t)
		var fade := 1.0 - smoothstep(1.5,2.6,t)
		for side: float in [-1,1]:
			var half := crown + Vector2(side*(10+p*59),-p*25)
			draw_polyline(PackedVector2Array([half+Vector2(-9,5),half+Vector2(-8,-10),
				half+Vector2(0,-3),half+Vector2(8,-13),half+Vector2(10,5)]),Color("#d4a7ff",fade),2,true)
	if director.state == director.State.EXECUTE and t >= director.timing("final_shatter"):
		var p: float = t - director.timing("final_shatter")
		var fade := smoothstep(.34,1.25,p) * (1.0-smoothstep(2.2,3.16,p))
		draw_ancestral_figures(boss.position,fade)
	if director.state == director.State.DOOM and t < director.timing("doom_wind"):
		var p := clampf(t / director.timing("doom_wind"), 0, 1)
		rune(boss.position + Vector2(0,-191), 26 * p, Color(red, .45))
	if director.state == director.State.DOOM:
		var impact: float = t-director.timing("doom_wind")
		if impact >= 0.0 and impact < .41:
			var chest := at+Vector2(5*hero.facing,-48)
			var split := PackedVector2Array([chest+Vector2(-8,-9),chest+Vector2(0,-3),
				chest+Vector2(-3,3),chest+Vector2(8,9)])
			var strength := 1.0-smoothstep(.16,.41,impact)
			draw_polyline(split,Color("#1b1423",strength),4.0)
			draw_polyline(split,Color("#ffc5a3",strength),1.5)
			draw_rect(Rect2(chest+Vector2(8,-8),Vector2(4,3)),Color("#a73c58",strength))
	if director.state == director.State.LAST_CHANCE and t >= .8 and t < director.timing("final_retry") - .35:
		var x: float = boss.position.x - (t - .8) * 482
		var crest := PackedVector2Array([Vector2(x - 27, 570), Vector2(x - 14, 545),
			Vector2(x + 15, 555), Vector2(x + 26, 570)])
		draw_colored_polygon(crest, Color("#9a5fe7", .55))
		draw_polyline(crest, Color("#e8ccff"), 2.1, true)
	if director.state == director.State.RESURRECTING and director.reversal:
		var p := clampf(t / director.resurrection_duration(),0,1)
		if p >= .66:
			var wave := (p-.66)/.34
			draw_set_transform(at + Vector2(0,-25),0,Vector2(1,.36))
			draw_arc(Vector2.ZERO,28+174*wave,0,TAU,70,Color("#fff4d9",1-wave),4,true)
			draw_set_transform(Vector2.ZERO)
	if director.state in [director.State.AWAKEN, director.State.RESURRECTING]:
		draw_soul(at, t, director.state == director.State.RESURRECTING)
	elif director.state == director.State.EPILOGUE and t < director.HERO_GONE:
		var center := at + Vector2(-hero.facing*21,-46)
		var grip: Vector2 = director.hero_art.weapon_pivot.global_position
		var fraying := smoothstep(4.6,director.CURSE_START+2.4,t)
		draw_thread(self,center,grip,t,smoothstep(.5,1.7,t)*(1.0-fraying)*.78,fraying)
		if t >= director.CURSE_START:
			var reveal := smoothstep(director.CURSE_START,director.CURSE_START+.55,t)
			draw_spirit(self,center,.85,reveal,director.soul_erasure())
	if director.state in [director.State.FLASH_PREP, director.State.FLASH_OPEN]:
		var field := at + Vector2(hero.facing * 34, -61)
		var intensity := .46 if director.state == director.State.FLASH_PREP else .89
		for i in 17:
			var angle: float = float(i) * TAU / 17 + director.elapsed * .83
			var distance := fposmod(i * 9.75 - director.elapsed * 51, 106.0)
			var point := field + Vector2.from_angle(angle) * distance
			draw_line(point, point + Vector2.from_angle(angle) * 8, Color(red.lerp(Color.WHITE, 1.0 - distance / 106), intensity), 1.45, true)
		if director.state == director.State.FLASH_OPEN:
			rune(boss.position + Vector2(0,-189), 22 + 9 * sin(t * 8), Color("#fff0e3"))
	if director.state == director.State.EXECUTE and t >= director.timing("final_slash") and t < director.timing("final_shatter") + .36:
		var hit: Vector2 = boss.position + Vector2(0,-85)
		var tail := Vector2(-1.0, .21) * 620
		var slash_at: float = director.timing("final_slash")
		var shatter_at: float = director.timing("final_shatter")
		var power := 1.0 - smoothstep(slash_at + .08, slash_at + .28, t)
		var cut := smoothstep(slash_at + .37, shatter_at, t)
		if power > .01:
			for i in range(6, 0, -1):
				draw_line(hit + tail, hit - tail, Color(oath_ramp.sample(i / 7.0), (.32 - i * .029) * power),
					4.0 + i * 9.0, true)
			draw_line(hit + tail, hit - tail, Color(oath_ramp.sample(0), power), 3.8, true)
			draw_oath_impact(hit, clampf((t - slash_at) / .28, 0, 1), 137.0)
		if cut > 0:
			var growth := smoothstep(shatter_at - .11, shatter_at + .20, t)
			var opacity := cut * (1 - smoothstep(shatter_at+.12, shatter_at+.36,t))
			var length := lerpf(.10, .26, growth)
			draw_line(hit + tail * length, hit - tail * length, Color(red, opacity*.35), 7.0 + growth * 16.0, true)
			draw_line(hit + tail * length, hit - tail * length, Color("#fff5ea", opacity), 1.6 + growth * 5.4, true)

func draw_weapon_effects() -> void:
	var art = director.hero_art
	var pivot: Node2D = art.weapon_pivot
	var blade: Sprite2D = art.weapon_sprite
	if blade.texture == null:
		return
	var box := Rect2(blade.offset,blade.texture.get_size())
	for echo in blade_echoes:
		draw_set_transform_matrix(global_transform.affine_inverse()*echo.pose)
		draw_texture_rect(blade.texture,box,false,Color(echo.color,.46*echo.life/.25))
	draw_set_transform(Vector2.ZERO)
	var s = director.State
	var state: int = director.state
	var t: float = director.clock
	var grip := to_local(pivot.global_position)
	var tip := to_local(pivot.to_global(Vector2(4,-art.weapon_grip.y+2)))
	var strength := 0.0
	var hue := Color("#fb315d")
	if state in [s.DEPARTURE,s.AWAKEN]:
		var start := .50 if state == s.DEPARTURE else 0.0
		var stop: float = director.timing("awakening_flash")
		if t > start and (state == s.DEPARTURE or t < stop):
			var blood := to_local(hero.global_position)+Vector2(4,-5)
			for i in 15:
				var progress := fposmod(i*.113+t*.85,1.0)
				var dot := blood.lerp(tip,progress)
				dot.y -= sin(progress*PI)*(3+i%4)
				draw_circle(dot,1.0+i%3*.45,Color(hue,.61),true,-1,true)
		if state == s.AWAKEN:
			strength = smoothstep(stop-.9,stop+.26,t)*(1.0-smoothstep(stop+1.05,stop+2.3,t))
	elif state == s.RESURRECTING and director.reversal:
		strength = sin(clampf(t/director.resurrection_duration(),0.0,1.0)*PI)
	elif state in [s.FLASH_PREP,s.FLASH_OPEN,s.EXECUTE]:
		hue = Color("#fff2e5")
		match state:
			s.FLASH_PREP: strength = smoothstep(.45,1.63,t)
			s.FLASH_OPEN: strength = 1.0
			s.EXECUTE: strength = 1.0-smoothstep(.48,1.17,t)
	if strength > .01:
		for width: float in [29,17,9]:
			draw_line(grip.lerp(tip,.16),tip,Color(hue,strength*.14),width,true)
		for i in 7:
			var progress := fposmod(i*.261+t*2.3,1.0)
			var mote := grip.lerp(tip,progress)+Vector2.from_angle(i*2.4+t*8)*8.0
			draw_circle(mote,1.6,Color(hue,strength*.64))

func draw_ancestral_figures(hit: Vector2, fade: float) -> void:
	for i in 5:
		var at := Vector2(hit.x - 200 + i * 96.0, 558 - absf(i-2)*11)
		var tone := Color("#ffd9ad", fade*(.22-absf(i-2)*.028))
		draw_circle(at+Vector2(0,-76),10,tone,true,-1,true)
		draw_colored_polygon(PackedVector2Array([at+Vector2(-9,-66),at+Vector2(10,-66),
			at+Vector2(26,-6),at+Vector2(-20,-9)]),tone)
		draw_line(at+Vector2(-8,-75),at+Vector2(7,-77),Color("#ffe9c9",fade*.40),1,true)
		draw_line(at+Vector2(15,-26),at+Vector2(28,-79),tone,2,true)

func draw_soul(at: Vector2, time: float, brief: bool) -> void:
	var duration: float = director.resurrection_duration()
	var depart: float = duration*.08 if brief else .48
	var between_start: float = duration*director.BETWEEN_OPEN if brief else director.timing("soul_departure")
	var between_end: float = duration*director.BETWEEN_CLOSE if brief else director.timing("soul_return")
	var land: float = duration*.79 if brief else director.timing("awakening_flash")
	var rise := smoothstep(depart,between_start,time)
	var fall := smoothstep(between_end,land,time)
	var strength := rise * (1.0-fall)
	if strength <= .01:
		return
	var soul := at + Vector2(-hero.facing*18*strength,-30-(74 if brief else 110)*strength)
	var grip: Vector2 = director.hero_art.weapon_pivot.global_position
	draw_thread(self,soul,grip,time,strength)
	draw_spirit(self,soul,.78,strength,0.0)

func draw_thread(canvas: CanvasItem, spirit: Vector2, grip: Vector2, time: float, alpha: float, fraying := 0.0) -> void:
	if alpha <= .01:
		return
	var points := PackedVector2Array()
	for i in 17:
		var p := i/16.0
		points.append(spirit.lerp(grip,p)+Vector2(0,sin(p*9.0-time*6.0)*10.0*sin(p*PI)))
	var gap := roundi(fraying*6.0)
	var pieces := [points] if gap == 0 else [points.slice(0,9-gap),points.slice(8+gap)]
	for piece: PackedVector2Array in pieces:
		canvas.draw_polyline(piece,Color("#a31443",alpha*.43),6.0,true)
		canvas.draw_polyline(piece,Color("#ff587c",alpha),1.8,true)

func draw_spirit(canvas: CanvasItem, center: Vector2, size: float, alpha: float, erasure: float) -> void:
	if alpha <= .01 or erasure >= 1.0:
		return
	const WIDTHS := [5,7,7,5,11,17,15,13,11,11,13,13,13,13,15,15]
	for row in WIDTHS.size():
		var half: int = WIDTHS[row] >> 1
		for column in range(-half,half+1):
			if row >= 11 and absi(column) < (row-9)*.55:
				continue
			var seed := fposmod(float(column*73+row*137),101.0)/101.0
			var loss := smoothstep(seed*.78,seed*.78+.22,erasure)
			if loss >= 1.0:
				continue
			var offset := Vector2(column*3,(row-8)*4) + Vector2(column*1.6,(row-7)*1.9)*loss
			var cell := (center+offset*size).round()
			var tint := Color("#ffd4ac").lerp(Color("#fff9e7"),seed)
			canvas.draw_rect(Rect2(cell,Vector2(3,4)*size*(1.0-loss*.58)),Color(tint,alpha*(1.0-loss)*.76))

func rune(at: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([at + Vector2(0,-radius), at + Vector2(radius*.63,0),
		at + Vector2(0,radius), at + Vector2(-radius*.63,0), at + Vector2(0,-radius)])
	draw_polyline(points, color, 1.5, true)
	draw_circle(at, radius * .17, color, true, -1.0, true)

func draw_ruin_projectile(at: Vector2, length: float, color: Color) -> void:
	var shape := PackedVector2Array([at, at + Vector2(-8,-length*.56), at + Vector2(-7,-length),
		at + Vector2(7,-length), at + Vector2(8,-length*.56)])
	draw_colored_polygon(shape, Color(color, color.a*.31))
	draw_polyline(shape, color, 1.4, true)
	draw_line(at, at + Vector2(0,-length*1.25), Color(color.lightened(.62), color.a), 1.4, true)
