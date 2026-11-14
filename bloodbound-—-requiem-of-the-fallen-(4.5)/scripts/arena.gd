extends Node2D
## Four connected locations share floor height and keep art separate from collision.

const FLOOR := 572.0
const INK := Color("#17151b")
const PAPER := Color("#c3b8a3")
const BLOOD := Color("#903c4b")
const WIDTHS := {"courtyard": 1280.0, "road": 3000.0, "shrine": 2600.0, "underworld": 2120.0, "frozen": 2240.0, "throne": 1280.0}

var area := "throne"
var area_width := 1280.0
var spawn_point := Vector2(180, FLOOR)
var exit_x := 1140.0
var exit_open := true
var gate_closed := 0.0
var mood := 0.0
var shade := 0.0
var time := 0.0
var parallax := 0.0
var background: Texture2D
var background_opacity := 1.0
var backgrounds: Dictionary = {}
var floor_shape: CollisionShape2D
var left_wall: CollisionShape2D
var right_wall: CollisionShape2D
var route_barrier: CollisionShape2D
const ROAD_DEBRIS := [505.0, 1775.0]
const OBSTACLES := {"road":ROAD_DEBRIS,"underworld":[926.0],"frozen":[1105.0,1320.0]}
var debris_shapes: Dictionary = {}
var ridges: Array[PackedVector2Array] = []
var ash: Array[Vector3] = []
var grain: Array[Vector3] = []

func _ready() -> void:
	var body := StaticBody2D.new()
	body.name = "AreaCollision"
	add_child(body)
	floor_shape = add_wall(body, Vector2(640, FLOOR + 35), Vector2(1600,70))
	left_wall = add_wall(body, Vector2(58,260),Vector2(40,624))
	right_wall = add_wall(body, Vector2(1222,260),Vector2(40,624))
	route_barrier = add_wall(body,Vector2(1125,300),Vector2(20,550))
	route_barrier.disabled = true
	var debris_body := StaticBody2D.new()
	debris_body.collision_layer = 2
	add_child(debris_body)
	for key: String in OBSTACLES:
		var obstacles: Array[CollisionShape2D] = []
		for x: float in OBSTACLES[key]:
			var height := 32.0 if key == "road" else 42.0
			obstacles.append(add_wall(debris_body,Vector2(x,FLOOR-height*.5),Vector2(38,height)))
		debris_shapes[key] = obstacles
	var rng := RandomNumberGenerator.new()
	rng.seed = 821781
	for i in 112:
		ash.append(Vector3(rng.randf_range(-200,3400),rng.randf_range(-40,610),rng.randf_range(.3,1.9)))
	for i in 320:
		grain.append(Vector3(rng.randf_range(-260,3400),rng.randf_range(-60,740),rng.randf_range(.1,.9)))
	set_area(area)

func set_profile(profile) -> void:
	for key: String in WIDTHS:
		backgrounds[key] = profile.optional("backgrounds",key,"Texture2D")
	background = profile.optional("visual","background","Texture2D") as Texture2D
	background_opacity = profile.get_value("visual","background_opacity",1.0)

func set_area(name: String) -> void:
	area = name if WIDTHS.has(name) else "courtyard"
	area_width = WIDTHS[area]
	exit_x = area_width - 140.0
	gate_closed = 0.0
	exit_open = true
	for key: String in debris_shapes:
		for collision: CollisionShape2D in debris_shapes[key]:
			collision.set_deferred("disabled",area != key)
	ridges.clear()
	for layer in 4:
		var points := PackedVector2Array([Vector2(-600,650)])
		for x in range(-600, int(area_width) + 950, 30):
			var y := 286.0 + layer * 49.0 + sin(x * .0045 + layer * 1.7) * (70.0-layer*10)
			y += sin(x * .018 + layer * 5.1) * (19.0 - layer*2.5)
			points.append(Vector2(x,y))
		points.append(Vector2(area_width+950,650))
		ridges.append(points)
	if is_instance_valid(floor_shape):
		floor_shape.shape.size = Vector2(area_width + 460,70)
		floor_shape.position = Vector2(area_width*.5,FLOOR+35)
		right_wall.position.x = area_width - 58
		route_barrier.position.x = exit_x - 15
		route_barrier.set_deferred("disabled",true)
	queue_redraw()

func set_exit_open(value: bool) -> void:
	exit_open = value
	if is_instance_valid(route_barrier):
		route_barrier.set_deferred("disabled",value)
	queue_redraw()

func add_wall(parent: StaticBody2D, center: Vector2, size: Vector2) -> CollisionShape2D:
	var collision := CollisionShape2D.new()
	collision.shape = RectangleShape2D.new()
	collision.shape.size = size
	collision.position = center
	parent.add_child(collision)
	return collision

func _draw() -> void:
	var final_area := area == "throne"
	var tint := Color("#ba8a83") if area == "road" else Color("#b9ac93")
	var sky := Color("#6f6970")
	if area == "shrine":
		tint = Color("#b9bcb3")
		sky = Color("#72777a")
	elif area == "underworld":
		tint = Color("#b7654a")
		sky = Color("#36202a")
	elif area == "frozen":
		tint = Color("#97bfd2")
		sky = Color("#334550")
	elif final_area:
		sky = Color("#27232f").lerp(Color("#1b1729"),clampf(mood-1,0,1))
		tint = Color("#d18691").lerp(Color("#a493bf"),clampf(mood-1,0,1))
		tint = tint.lerp(Color("#e5bb87"),clampf(mood-2,0,1))
		sky = sky.lerp(Color("#79665d"),clampf(mood-2,0,1)*.68)
	var bounds := Rect2(-360,-110,area_width+720,960)
	draw_rect(bounds,INK)
	for band in 54:
		var p := band/53.0
		var light := sin(p*PI*.79)*.62
		draw_rect(Rect2(-360,-55+band*12,area_width+720,12.4),sky.lerp(tint,light))
	draw_sky(tint, final_area)
	for layer in ridges.size():
		# Camera compensation gives distant ridges a slower apparent motion.
		draw_set_transform(Vector2(parallax * (.48 - layer*.105),0))
		var mountain := Color("#746f72").lerp(INK,layer*.19+.20)
		if final_area:
			mountain = mountain.darkened(.38)
		draw_colored_polygon(ridges[layer],mountain)
		draw_polyline(ridges[layer].slice(1,-1),Color(tint,.08),1.5,true)
	draw_set_transform(Vector2.ZERO)
	match area:
		"courtyard":
			draw_courtyard(tint)
		"road":
			draw_road(tint)
		"shrine":
			draw_shrine(tint)
		"underworld":
			draw_underworld(tint)
		"frozen":
			draw_frozen(tint)
		"throne":
			draw_throne(tint)
	draw_ground(tint)
	var image: Texture2D = backgrounds.get(area)
	if image == null and final_area:
		image = background
	if image:
		draw_texture_rect(image,Rect2(-80,-45,area_width+160,770),false,Color(Color.WHITE,background_opacity))
	draw_mist(tint)
	for item in ash:
		var x := fposmod(item.x+time*(10+item.z*8),area_width+240)-120
		var y := fposmod(item.y-time*(6+item.z*6),610)
		draw_circle(Vector2(x,y),item.z*.73,Color(tint.lightened(.32),.18+.17*sin(time+item.x)))
	for fleck in grain:
		draw_line(Vector2(fleck.x,fleck.y),Vector2(fleck.x+1.5+fleck.z*2,fleck.y+.4),Color(INK,.033*fleck.z),1)
	if not exit_open:
		var x := exit_x - 15
		for i in 5:
			var offset := sin(time*2.0+i)*3
			draw_line(Vector2(x+offset,411+i*19),Vector2(x-offset,572),Color(BLOOD,.11+i*.04),1.0,true)
		seal(Vector2(x,483),16,Color("#d6a088"))
	if shade > 0:
		draw_rect(bounds,Color(.022,.016,.025,shade))

func draw_sky(tint: Color, eclipse: bool) -> void:
	var center := Vector2(678 + parallax*.70,197)
	if area == "shrine":
		center.x = 1055 + parallax*.65
	for i in range(10,0,-1):
		draw_circle(center,93+i*7,Color(tint,.016))
	draw_circle(center,91,Color(tint.lightened(.30),.84),true,-1,true)
	if eclipse:
		draw_circle(center+Vector2(-3,-3),89.5,Color("#18131f").lerp(tint.darkened(.25),clampf(mood-2,0,1)),true,-1,true)
		draw_arc(center,92,0.1,2.8,64,Color(tint,.90),2,true)
	for i in 9:
		var x := fposmod(i*389.0+time*(3+i%3),area_width+500)-220+parallax*.33
		var y := 154+i*21%130
		draw_set_transform(Vector2(x,y),-.015,Vector2(3.1,.13))
		draw_circle(Vector2.ZERO,90,Color(PAPER,.018 if eclipse else .033))
	draw_set_transform(Vector2.ZERO)
	if eclipse and mood > 1.4:
		var pulse := pow(maxf(0,sin(time*.74)),22)*.17
		var bolt := PackedVector2Array([Vector2(1102,0),Vector2(1050,107),Vector2(1080,111),Vector2(1018,201)])
		draw_polyline(bolt,Color("#e0d7e9",pulse),1.4,true)

func draw_courtyard(tint: Color) -> void:
	for x: float in [140,335,975]:
		banner(x,336 if x<500 else 310,66,tint)
	for i in 9:
		var x := 103+i*127.0
		var height := 54.0+(i*23%48)
		draw_rect(Rect2(x,544-height,63,height),Color("#3b363e"))
		draw_line(Vector2(x,544-height),Vector2(x+63,544-height),Color(tint,.25),1.3)
	for at in [Vector2(125,567),Vector2(281,562),Vector2(523,565),Vector2(830,563)]:
		relic(at,tint)
	gate_art(1148,220,tint,false)
	if gate_closed > .001:
		var amount := clampf(gate_closed,0,1)
		draw_rect(Rect2(1085,327,126*amount,245),Color("#19161e"))
		for i in 5:
			var x := 1094+i*26
			if x < 1085+126*amount:
				draw_line(Vector2(x,331),Vector2(x,570),Color(tint,.19),1.5,true)
		seal(Vector2(1148,432),15*amount,Color(BLOOD,amount))
	pillar(4,77,390,tint)
	pillar(1263,54,334,tint)

func draw_road(tint: Color) -> void:
	for i in 10:
		var x := 160.0+i*289
		var base := 526.0+(i%2)*18
		var height := 91.0+(i*23%51)
		var tone := Color("#393239")
		polygon([Vector2(x-69,base),Vector2(x-65,base-height),Vector2(x-86,base-height),Vector2(x-29,base-height-37),
			Vector2(x+11,base-height-11),Vector2(x+47,base-height-38),Vector2(x+91,base-height),Vector2(x+72,base-height),Vector2(x+76,base)],tone)
		for beam in 4:
			draw_line(Vector2(x-45+beam*33,base-height+7),Vector2(x-48+beam*32,base),Color("#51474c"),2.4,true)
		draw_rect(Rect2(x-9,base-41,26,41),INK)
		draw_line(Vector2(x-65,base-height),Vector2(x+71,base-height),Color(tint,.2),2.1,true)
		if i%3==1:
			for flame in 5:
				var p := fposmod(time*.36+flame*.193+i*.12,1.0)
				var foot := Vector2(x-32+flame*14,base-height+8)
				draw_circle(foot+Vector2(sin(p*7+flame)*8,-p*75),5*(1-p)+1,Color("#d78969",(1-p)*.32))
	for i in 18:
		var x := 35.0+i*171
		if x>1230 and x<1570:
			continue
		tree(Vector2(x,FLOOR),103+(i*31%105),tint)
	for i in 12:
		var x := 290.0+i*219
		draw_colored_polygon(PackedVector2Array([Vector2(x-13,572),Vector2(x-10,541),Vector2(x+3,532),Vector2(x+14,544),Vector2(x+17,572)]),Color("#3b343c"))
		draw_line(Vector2(x-3,546),Vector2(x-1,562),Color(tint,.38),1.2,true)
	# The fallen bridge has a walkable stone bed, with broken timber below it.
	for i in 14:
		var x := 1280.0+i*17
		draw_line(Vector2(x,555),Vector2(x+8,575+(i*13%31)),Color("#453b42"),5,true)
	for x: float in [1263,1535]:
		draw_line(Vector2(x,526),Vector2(x,574),Color("#27232c"),6,true)
	draw_polyline(PackedVector2Array([Vector2(1263,528),Vector2(1328,544),Vector2(1417,563),Vector2(1490,545),Vector2(1535,528)]),Color("#29242b"),2.1,true)
	for point in [Vector2(701,571),Vector2(1744,569),Vector2(2722,572)]:
		relic(point,tint)
	gate_art(area_width-119,187,tint,true)

	for x: float in ROAD_DEBRIS:
		polygon([Vector2(x-19,572),Vector2(x-19,551),Vector2(x-12,545),Vector2(x-2,540),
			Vector2(x+15,543),Vector2(x+19,550),Vector2(x+19,572)],Color("#302930"))
		draw_line(Vector2(x-12,547),Vector2(x+14,545),Color(tint,.56),2.0,true)

func draw_shrine(tint: Color) -> void:
	for i in 3:
		var at := Vector2(415+i*720,544)
		var width := 67.0
		polygon([at+Vector2(-width,0),at+Vector2(-43,-101),at+Vector2(-32,-151),at+Vector2(-17,-185),
			at+Vector2(19,-185),at+Vector2(37,-146),at+Vector2(44,-91),at+Vector2(width,0)],Color("#3c3c43"))
		draw_line(at+Vector2(-13,-160),at+Vector2(20,-162),Color(tint,.25),1.6,true)
		draw_polyline(PackedVector2Array([at+Vector2(-22,-110),at+Vector2(6,-83),at+Vector2(24,-104)]),Color(tint,.18),2,true)
	for i in 4:
		gate_art(243+i*689,170+(i%2)*28,tint,true)
	var water_x := 1398.0 + parallax*.08
	for i in 9:
		var x := water_x+i*8
		draw_line(Vector2(x,266),Vector2(x+4,538),Color(PAPER,.035+(i%3)*.025),7,true)
		var falling := fposmod(time*(79+i*7)+i*31,224)
		draw_line(Vector2(x,285+falling),Vector2(x+3,310+falling),Color(PAPER,.14),1.4,true)
	for i in 16:
		var x := 145.0+i*153
		var y := 400.0+(i*11%37)
		draw_line(Vector2(x,y-42),Vector2(x,y),Color("#34303a"),1.3,true)
		var glow := .12+.035*sin(time*2.1+i)
		draw_circle(Vector2(x,y+11),19,Color("#e4bb80",glow))
		draw_rect(Rect2(x-8,y,16,23),Color("#b19775"))
		draw_line(Vector2(x-11,y),Vector2(x+11,y),INK,2,true)
		draw_line(Vector2(x-10,y+23),Vector2(x+10,y+23),INK,2,true)
	for i in 13:
		relic(Vector2(127+i*192,FLOOR-3),tint)
	for i in 4:
		var width := 205.0-i*34
		draw_rect(Rect2(2020-width*.5,556-i*11,width,11),Color("#45414a").lightened(i*.027))
	seal(Vector2(2020,483),27,Color("#c6aa80",.7))

func draw_underworld(tint: Color) -> void:
	for i in 9:
		var x := 114.0+i*235
		pillar(x,45.0+i%3*5,192.0+i%4*36,tint)
		var ember := Vector2(x+62,482)
		draw_circle(ember,38,Color(tint,.11))
		draw_line(ember+Vector2(0,75),ember+Vector2(0,9),Color("#211920"),8,true)
		for j in 3:
			var angle := sin(time*4.4+j+i)*.25
			draw_line(ember,ember+Vector2(0,-21-j*8).rotated(angle),Color("#ffa460",.75-j*.16),5-j,true)
	gate_art(area_width-120,309,tint,false)
	for x: float in OBSTACLES.underworld:
		draw_rect(Rect2(x-19.0,530,38,42),Color("#372329"))
		draw_line(Vector2(x-17,532),Vector2(x+17,532),Color(tint,.65),2,true)

func draw_frozen(tint: Color) -> void:
	for i in 14:
		var x := 90.0+i*171.0
		var tip := Vector2(x+19.0,365.0+i*47%132)
		polygon([Vector2(x-60,572),Vector2(x-30,510),tip,Vector2(x+44,526),Vector2(x+67,572)],Color("#334958"))
		draw_line(tip,Vector2(x-28,510),Color(tint,.43),2,true)
		if i%3==0:
			tree(Vector2(x+74,572),155.0+i*37%53,tint)
	for i in 110:
		var x := fposmod(i*97.91-time*(13+i%9),area_width)
		var y := fposmod(i*61.3+time*(13+i%15),560.0)
		draw_circle(Vector2(x,y),1.0+i%3*.45,Color("#e1f1fa",.22+i%5*.09))
	for x: float in OBSTACLES.frozen:
		polygon([Vector2(x-19,572),Vector2(x-19,542),Vector2(x-5,530),Vector2(x+19,540),Vector2(x+19,572)],Color("#587789"))
		draw_line(Vector2(x-15,541),Vector2(x-5,531),Color("#c9e5ef"),2,true)
	gate_art(area_width-119,217,tint,true)

func draw_throne(tint: Color) -> void:
	for i in 11:
		var x := 298.0+i*63
		var h := 68.0+(i*23%51)
		polygon([Vector2(x,545),Vector2(x-2,545-h),Vector2(x+12,537-h),Vector2(x+20,545-h),Vector2(x+23,545)],Color("#29232f"))
	for i in 5:
		var width := 174.0-i*23
		var y := 549.0-i*7
		draw_rect(Rect2(640-width,y,width*2,7),Color("#302735").darkened(i*.04))
		draw_line(Vector2(640-width,y),Vector2(640+width,y),Color(tint,.18),1)
	polygon([Vector2(598,518),Vector2(598,439),Vector2(613,409),Vector2(631,427),Vector2(643,392),
		Vector2(658,412),Vector2(671,399),Vector2(680,433),Vector2(685,518)],Color("#342b3b"))
	draw_polyline(PackedVector2Array([Vector2(608,500),Vector2(608,445),Vector2(621,452),Vector2(643,421),
		Vector2(666,455),Vector2(669,499)]),Color(tint,.29),1.3,true)
	draw_rect(Rect2(605,498,73,19),Color("#403447"))
	for detail in [[-10,66,492],[150,59,328],[262,29,193],[1052,32,244],[1146,59,395],[1279,76,490]]:
		pillar(float(detail[0]),float(detail[1]),float(detail[2]),tint)
	for x: float in [202,1021]:
		banner(x,353,43,tint)
	for point in [Vector2(118,571),Vector2(344,568),Vector2(854,566),Vector2(1159,571)]:
		relic(point,tint)

func draw_ground(tint: Color) -> void:
	var ground := Color("#211e27") if area != "throne" else Color("#15121c")
	draw_rect(Rect2(-360,FLOOR,area_width+720,300),ground)
	draw_rect(Rect2(-360,FLOOR,area_width+720,4),Color(tint,.46))
	draw_line(Vector2(-360,FLOOR+9),Vector2(area_width+360,FLOOR+9),Color(tint,.16),1.2)
	for i in int((area_width+460)/25):
		var x := -220+i*25.0
		var y := FLOOR+17+(i*31%129)
		var length := 16.0+i*13%84
		draw_line(Vector2(x,y),Vector2(x+length,y),Color(tint,.08),1+(i%3)*.3)
		if i%5==0:
			draw_polyline(PackedVector2Array([Vector2(x,y),Vector2(x+7,y+3),Vector2(x+12,y+1),Vector2(x+29,y+6)]),Color(INK,.68),2,true)
	for i in int(area_width/38):
		var x := i*38.0
		var h := float(i*17%8)
		polygon([Vector2(x,FLOOR),Vector2(x+9,FLOOR-h),Vector2(x+24,FLOOR)],ground)

func draw_mist(tint: Color) -> void:
	for i in int(area_width/205)+4:
		var x := fposmod(time*(6+i%4)+i*217,area_width+380)-170
		var y := 492.0+i*13%73
		draw_set_transform(Vector2(x,y),-.016,Vector2(3.9,.12+i%3*.025))
		draw_circle(Vector2.ZERO,82,Color(tint,.032))
	draw_set_transform(Vector2.ZERO)

func gate_art(x: float, height: float, tint: Color, shrine: bool) -> void:
	var top := FLOOR-height
	var tone := Color("#29232b")
	for side: float in [-1,1]:
		draw_line(Vector2(x+side*68,FLOOR),Vector2(x+side*62,top+11),tone,11,true)
		draw_line(Vector2(x+side*65,FLOOR-6),Vector2(x+side*59,top+12),Color(tint,.22),1.1,true)
	if shrine:
		draw_polyline(PackedVector2Array([Vector2(x-97,top-8),Vector2(x-71,top),Vector2(x+72,top),Vector2(x+96,top-8)]),tone,12,true)
		draw_line(Vector2(x-83,top+23),Vector2(x+84,top+23),tone,9,true)
		draw_line(Vector2(x,top+2),Vector2(x,top+26),tone,8,true)
	else:
		polygon([Vector2(x-91,top+8),Vector2(x-76,top-18),Vector2(x-49,top-7),Vector2(x-22,top-16),
			Vector2(x+17,top-3),Vector2(x+44,top-22),Vector2(x+91,top+8)],tone)
		draw_rect(Rect2(x-59,top+14,118,height-14),Color("#15111c",.74))

func banner(x: float, top: float, width: float, tint: Color) -> void:
	draw_line(Vector2(x,FLOOR),Vector2(x,top-15),INK,6,true)
	draw_line(Vector2(x-5,top),Vector2(x+width,top),INK,4,true)
	var sway := sin(time*1.7+x)*4.0
	polygon([Vector2(x+4,top+4),Vector2(x+width-3,top+5),Vector2(x+width+sway-8,top+91),
		Vector2(x+width*.57,top+77),Vector2(x+width*.32,top+101),Vector2(x+3,top+84)],BLOOD.darkened(.32))
	seal(Vector2(x+width*.5,top+39),10,Color(tint,.47))

func tree(at: Vector2, height: float, tint: Color) -> void:
	var trunk := PackedVector2Array([at,at+Vector2(-7,-height*.34),at+Vector2(6,-height*.73),at+Vector2(-5,-height)])
	draw_polyline(trunk,Color("#26222b"),7,true)
	for i in 4:
		var side := 1.0 if i%2==0 else -1.0
		var from := at+Vector2(0,-height*(.32+i*.14))
		var tip := from+Vector2(side*(29+i*4),-20-i*8)
		draw_polyline(PackedVector2Array([from,from.lerp(tip,.55)+Vector2(3,-4),tip]),Color("#26222b"),3.0,true)
		draw_line(tip-Vector2(side*12,-3),tip+Vector2(side*11,-14),Color(tint,.14),1.0,true)

func pillar(x: float, width: float, height: float, tint: Color) -> void:
	var y := FLOOR-height
	polygon([Vector2(x-width*.65,FLOOR),Vector2(x-width*.52,FLOOR-23),Vector2(x-width*.41,y+25),
		Vector2(x-width*.52,y+7),Vector2(x-width*.14,y-13),Vector2(x+width*.05,y+10),Vector2(x+width*.39,y-4),
		Vector2(x+width*.42,FLOOR-26),Vector2(x+width*.72,FLOOR)],Color("#1d1923"))
	for i in 5:
		var groove := x+(i-2)*width*.14
		draw_line(Vector2(groove,y+24+i*7%20),Vector2(groove-2,FLOOR-36),Color(tint,.11+i*.016),1,true)
	for i in 4:
		var base := FLOOR-7-i*8
		draw_line(Vector2(x-width*(.67-i*.055),base),Vector2(x+width*(.69-i*.05),base),Color(tint,.16),1,true)

func relic(at: Vector2, tint: Color) -> void:
	draw_set_transform(at,sin(at.x)*.41)
	polygon([Vector2(-3,3),Vector2(-4,-56),Vector2(4,-59),Vector2(5,-1)],Color("#38313b"))
	draw_line(Vector2(2,-56),Vector2(3,-5),Color(tint,.40),1,true)
	draw_line(Vector2(-11,-57),Vector2(12,-57),Color("#29232e"),4,true)
	draw_line(Vector2(0,-58),Vector2(0,-72),Color("#29232e"),3,true)
	draw_set_transform(Vector2.ZERO)

func seal(at: Vector2, radius: float, color: Color) -> void:
	draw_polyline(PackedVector2Array([at+Vector2(0,-radius),at+Vector2(radius*.62,0),at+Vector2(0,radius),
		at+Vector2(-radius*.62,0),at+Vector2(0,-radius)]),color,1.25,true)
	draw_line(at+Vector2(0,-radius*.45),at+Vector2(0,radius*.45),color,1.0,true)

func polygon(points: Array[Vector2], color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points),color)
