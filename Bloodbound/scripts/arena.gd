extends Node2D
## The connected locations share a floor height and keep art separate from collision.

const FLOOR := 572.0
const ART := "res://assets/last_oath/"
const DAY_LAYERS := ["fond","sun","cloud","m1","m2","m3","m4","m5","m6"]
const NIGHT_SKIES := {"underworld":"01_the_rise","frozen":"03_the_veil","throne":"02_the_vigil"}
const BRIDGES := {"road":Rect2(390,572,864,72),"underworld":Rect2(350,572,800,52)}
const PLATFORMS := {"road":[Rect2(1506,512,158,22),Rect2(1680,454,144,22),Rect2(1860,514,150,22)],"underworld":[Rect2(1300,520,172,22),Rect2(1510,470,140,22)]}
const FOREST_BRIARS := Rect2(1695,550,105,24)
const INK := Color("#17151b")
const PAPER := Color("#c3b8a3")
const BLOOD := Color("#903c4b")
const WIDTHS := {"courtyard": 1280.0, "road": 3000.0, "shrine": 1860.0, "underworld": 2120.0, "frozen": 2240.0, "throne": 1280.0}
# Each prop is anchored to the floor at its x coordinate.
const SCENERY := {
	"courtyard": [
		["house",170,.72,"#8a7385"], ["bell_wall",509,.52,"#766a79"],
		["cherry",828,.64,"#ae8896"], ["rocks",1065,.22,"#796f7b"]],
	"road": [
		["house",105,.53,"#8d777c"], ["maple",328,.51,"#a48780"],
		["ginkgo",1584,.65,"#9b876d"], ["rocks",2022,.29,"#7e7474"],
		["maple",2286,.63,"#a88a85"], ["flowering_tree",2682,.54,"#927a85"]],
	"shrine": [
		["pagoda",93,.43,"#877986"], ["torii",359,.72,"#ae8992"],
		["lantern",504,.24,"#b19a93"], ["cherry",764,.60,"#c19aaa"],
		["rocks",860,.26,"#9b858c"], ["wisteria",1503,.70,"#a78c9d"]],
	"underworld": [
		["pine",142,.61,"#62708c"], ["rocks",1183,.34,"#657087"],
		["lantern",1430,.22,"#808094"], ["pine",1773,.73,"#677993"],
		["bell_wall",2049,.56,"#676981"]],
	"frozen": [
		["rocks",240,.53,"#65768f"], ["pine",504,.65,"#637c9a"],
		["rocks",853,.34,"#63718b"], ["pine",1720,.70,"#61718b"],
		["lantern",1830,.23,"#8b858e"]]
}

var area := "throne"
var area_width := 1280.0
var spawn_point := Vector2(180, FLOOR)
var exit_x := 1140.0
var exit_open := true
var gate_closed := 0.0
var ending := false
var fortress_fall := 0.0
var fatal_impact := Vector2.ZERO
var dawn := 0.0
var oath_stone := 0.0
var oath_grip_y := 471.0
var heir_preview: SpriteFrames
var heir_progress := -1.0
var phantom_ward := 0.0
var show_sever_target := false
var backdrop_time := 0.0
var mood := 0.0
var shade := 0.0
var time := 0.0
var parallax := 0.0
var background: Texture2D
var background_opacity := 1.0
var backgrounds: Dictionary = {}
var floor_shape: CollisionShape2D
var right_wall: CollisionShape2D
var route_barrier: CollisionShape2D
const ROAD_DEBRIS := [1390.0]
const OBSTACLES := {"road":ROAD_DEBRIS,"underworld":[1590.0]}
var debris_shapes: Dictionary = {}
var ridges: Array[PackedVector2Array] = []
var ridge_edges: Array[PackedVector2Array] = []
var ash: Array[Vector3] = []
var campaign_art: Dictionary = {}
var deck_floor: CollisionShape2D
var far_bank: CollisionShape2D
var grain: Array[Vector3] = []

func _ready() -> void:
	var body := StaticBody2D.new()
	body.name = "AreaCollision"
	add_child(body)
	floor_shape = add_wall(body, Vector2(640, FLOOR + 35), Vector2(1600,70))
	deck_floor = add_wall(body,Vector2.ZERO,Vector2(1,1))
	far_bank = add_wall(body,Vector2.ZERO,Vector2(1,1))
	add_wall(body, Vector2(58,260),Vector2(40,624))
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
	for key: String in PLATFORMS:
		for top: Rect2 in PLATFORMS[key]:
			var ledge := add_wall(debris_body,top.get_center(),top.size)
			ledge.one_way_collision = true
			debris_shapes[key].append(ledge)
	for key: String in NIGHT_SKIES.values() + ["04_the_wane","stone_bridge","wood_bridge","rock_platform"]:
		campaign_art[key] = load(ART + key + ".png")
	for key: String in DAY_LAYERS:
		campaign_art[key] = load(ART + "sunset/" + key + ".png")
	for placement: Array in SCENERY.values():
		for prop: Array in placement:
			var key: String = prop[0]
			if not campaign_art.has(key):
				campaign_art[key] = load("res://assets/scenery/" + key + ".png")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	var next_area := name if WIDTHS.has(name) else "courtyard"
	var width_changed: bool = area_width != WIDTHS[next_area] or ridges.is_empty()
	gate_closed = 0.0
	ending = false
	fortress_fall = 0.0
	fatal_impact = Vector2.ZERO
	dawn = 0.0
	oath_stone = 0.0
	heir_progress = -1.0
	phantom_ward = 0.0
	show_sever_target = false
	backdrop_time = time
	set_exit_open(true)
	if next_area == area and not width_changed:
		return
	area = next_area
	area_width = WIDTHS[area]
	exit_x = area_width - 140.0
	for key: String in debris_shapes:
		for collision: CollisionShape2D in debris_shapes[key]:
			collision.set_deferred("disabled",area != key)
	if width_changed:
		ridges.clear()
		ridge_edges.clear()
		for layer in 4:
			var points := PackedVector2Array([Vector2(-600,650)])
			for x in range(-600, int(area_width) + 950, 30):
				var y := 286.0 + layer * 49.0 + sin(x * .0045 + layer * 1.7) * (70.0-layer*10)
				y += sin(x * .018 + layer * 5.1) * (19.0 - layer*2.5)
				points.append(Vector2(x,y))
			points.append(Vector2(area_width+950,650))
			ridges.append(points)
			ridge_edges.append(points.slice(1,-1))
	update_ground_collision()
	right_wall.position.x = area_width - 58
	route_barrier.position.x = exit_x - 15
	queue_redraw()

func update_ground_collision() -> void:
	var bridge: Rect2 = BRIDGES.get(area,Rect2())
	var crossing := bridge.size.x > 0.0
	var left_end := bridge.position.x+1.0 if crossing else area_width+230.0
	floor_shape.shape.size = Vector2(left_end+230.0,70)
	floor_shape.position = Vector2((left_end-230.0)*.5,FLOOR+35)
	deck_floor.set_deferred("disabled",not crossing)
	far_bank.set_deferred("disabled",not crossing)
	if crossing:
		deck_floor.shape.size = Vector2(bridge.size.x,15)
		deck_floor.position = Vector2(bridge.get_center().x,FLOOR+7.5)
		var right_length := area_width+230.0-bridge.end.x+1.0
		far_bank.shape.size = Vector2(right_length,70)
		far_bank.position = Vector2(bridge.end.x-1.0+right_length*.5,FLOOR+35)

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
	if not draw_campaign_sky():
		draw_fallback_sky(tint,sky,final_area)
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
	if fatal_impact != Vector2.ZERO:
		draw_floor_fracture(fatal_impact,1.0)
	if area == "throne" and fortress_fall > .02:
		draw_floor_fracture(Vector2(636,FLOOR-2),smoothstep(.02,.56,fortress_fall))
	draw_crossing(tint)
	for top: Rect2 in PLATFORMS.get(area,[]):
		draw_texture_rect(campaign_art.rock_platform,Rect2(top.position,Vector2(top.size.x,top.size.x*39.0/146.0)),false,Color("#a6a0aa"))
	if area == "road":
		draw_briars()
	if area == "frozen":
		draw_gate_lock(tint)
	var image: Texture2D = backgrounds.get(area)
	if image == null and final_area:
		image = background
	if image:
		draw_texture_rect(image,Rect2(-80,-45,area_width+160,770),false,Color(Color.WHITE,background_opacity))
	draw_mist(tint)
	if phantom_ward > 0.0:
		for i in 4:
			var x := phantom_ward+sin(time*2.2+i)*4
			draw_line(Vector2(x,398+i*15),Vector2(phantom_ward,FLOOR),Color("#86dae4",.16+i*.08),2)
		seal(Vector2(phantom_ward,471),22,Color("#86dae4"))
	if show_sever_target:
		var target := Vector2(1691,525)
		draw_line(target,Vector2(target.x,FLOOR),Color("#524163"),8)
		seal(target,16,Color("#dab6f3"))
	if oath_stone > 0.0:
		draw_oath_stone()
	draw_atmosphere(tint)
	if not exit_open:
		var x := exit_x - 15
		for i in 5:
			var offset := sin(time*2.0+i)*3
			draw_line(Vector2(x+offset,411+i*19),Vector2(x-offset,572),Color(BLOOD,.11+i*.04),1.0,true)
		seal(Vector2(x,483),16,Color("#d6a088"))
	if shade > 0:
		draw_rect(bounds,Color(.022,.016,.025,shade))

func draw_atmosphere(tint: Color) -> void:
	var to_local := get_global_transform_with_canvas().affine_inverse()
	var viewport_rect := get_viewport_rect()
	var top_left := to_local * viewport_rect.position
	var visible := Rect2(top_left, to_local * viewport_rect.end - top_left).grow(48.0)
	var ash_tone := tint.lightened(.32)
	for item in ash:
		var x := fposmod(item.x+time*(10+item.z*8),area_width+240)-120
		if x < visible.position.x or x > visible.end.x:
			continue
		var y := fposmod(item.y-time*(6+item.z*6),610)
		if y >= visible.position.y and y <= visible.end.y:
			draw_circle(Vector2(x,y),item.z*.73,Color(ash_tone,.18+.17*sin(time+item.x)))
	for fleck in grain:
		var at := Vector2(fleck.x,fleck.y)
		if visible.has_point(at):
			draw_line(at,at+Vector2(1.5+fleck.z*2,.4),Color(INK,.033*fleck.z),1)

func draw_oath_stone() -> void:
	var x := oath_stone
	polygon([Vector2(x-48,FLOOR),Vector2(x-39,548),Vector2(x-15,531),Vector2(x+21,526),
		Vector2(x+40,541),Vector2(x+49,FLOOR)],Color("#322b36"))
	draw_line(Vector2(x-34,549),Vector2(x+22,531),Color("#72606d"),3)
	if heir_progress < 0.0:
		return
	for i in 10:
		var root := Vector2(x-66+i*14,FLOOR)
		draw_line(root,root+Vector2(5-i%3*5,-11-i%4*4),Color("#606f57"),3)
	var approach := smoothstep(.35,3.35,heir_progress)
	var at := Vector2(x+lerpf(203,58,approach),FLOOR)
	var clip := &"run" if approach < .99 else &"idle"
	if heir_preview and heir_preview.has_animation(clip) and heir_preview.get_frame_count(clip) > 0:
		var frame := int(heir_progress*10.0)%heir_preview.get_frame_count(clip)
		var texture := heir_preview.get_frame_texture(clip,frame)
		draw_set_transform(at,0,Vector2(-1,1))
		var size := texture.get_size()*1.25
		draw_texture_rect(texture,Rect2(Vector2(-size.x*.5,-151),size),false,Color("#4e405b"))
		draw_set_transform(Vector2.ZERO)
	else:
		polygon([at+Vector2(-17,-70),at+Vector2(8,-80),at+Vector2(24,-52),
			at+Vector2(30,0),at+Vector2(-28,0)],Color("#30263a"))
	var emblem := at+Vector2(-9,-44)
	seal(emblem,5,Color("#d09879"))
	if heir_progress >= 3.35:
		var reaching := smoothstep(3.35,4.9,heir_progress)
		var elbow := at+Vector2(-16,-36)
		var hand := elbow.lerp(Vector2(x+8,oath_grip_y),reaching)
		draw_line(at+Vector2(-8,-47),elbow,Color("#433449"),7)
		draw_line(elbow,hand,Color("#514154"),6)
		draw_rect(Rect2(hand-Vector2(3,3),Vector2(7,7)),Color("#ac826f"))

func draw_fallback_sky(tint: Color, sky: Color, final_area: bool) -> void:
	for band in 54:
		var p := band/53.0
		var light := sin(p*PI*.79)*.62
		draw_rect(Rect2(-360,-55+band*12,area_width+720,12.4),sky.lerp(tint,light))
	draw_sky(tint,final_area)
	for layer in ridges.size():
		draw_set_transform(Vector2(parallax*(.48-layer*.105),0))
		var mountain := Color("#746f72").lerp(INK,layer*.19+.20)
		draw_colored_polygon(ridges[layer],mountain.darkened(.38) if final_area else mountain)
		draw_polyline(ridge_edges[layer],Color(tint,.08),1.5,true)
	draw_set_transform(Vector2.ZERO)

func draw_campaign_sky() -> bool:
	var key: String = "04_the_wane" if ending else NIGHT_SKIES.get(area,"")
	if not key.is_empty() and campaign_art.get(key):
		var x := floorf(parallax * .93 / 6.0)*6.0
		var lighting := Color("#d5cced").lerp(Color("#e68f88"),clampf(mood-1.0,0,1)) if area == "throne" else Color.WHITE
		if area == "throne" and mood > 2.0:
			lighting = lighting.lerp(Color("#fff1c0"),clampf(mood-2.0,0,1))
		draw_texture_rect(campaign_art[key],Rect2(x-128,-86,1536,864),false,lighting)
		if dawn > 0.0 and campaign_art.get("fond"):
			draw_day(dawn,Color("#dfb699"))
		if area == "underworld":
			var fading := 1.0-smoothstep(0.8,7.4,time-backdrop_time)
			draw_day(fading*.76,Color("#858cae"))
		return true
	if campaign_art.get("fond"):
		draw_day(1.0,Color("#dfd6d7") if area == "courtyard" else Color("#beadab"))
		return true
	return false

func draw_day(alpha: float, tone: Color) -> void:
	if alpha < .005:
		return
	for index in DAY_LAYERS.size():
		var key: String = DAY_LAYERS[index]
		var texture: Texture2D = campaign_art.get(key)
		if texture == null:
			continue
		var motion := time*9.0 if key == "cloud" else 0.0
		var anchor := floorf((parallax*(.92-index*.062)-motion)/5.0)*5.0
		var color := Color(tone,alpha)
		if area == "courtyard" and index >= 3:
			var tones := [Color("#d9b6a8"),Color("#bcaba2"),Color("#9f9697"),Color("#989a84"),Color("#98a09a"),Color("#7f8991")]
			color = Color(tones[index-3],alpha)
		elif index >= 3 and area in ["road","shrine"]:
			var tones := [Color("#c6a5a6"),Color("#b5a0ad"),Color("#9d8998"),Color("#ac899e"),Color("#a08997"),Color("#a391a3")]
			color = Color(tones[index-3],alpha)
		var first_tile := floori((parallax-400.0-anchor)/1280)
		for tile in range(first_tile,first_tile+3):
			draw_texture_rect(texture,Rect2(anchor+1280*tile,-60,1280,640),false,color)

func draw_crossing(tint: Color) -> void:
	if not BRIDGES.has(area):
		return
	var bridge: Rect2 = BRIDGES[area]
	draw_rect(Rect2(bridge.position.x,FLOOR,bridge.size.x,340),Color("#171e31"))
	for i in 25:
		var x := bridge.position.x+fposmod(i*73+time*6,bridge.size.x-100.0)
		var y := 655.0+i*17%80
		draw_rect(Rect2(x,y,21+i*3%82,2),Color(tint,.08+i%3*.07))
	var key := "stone_bridge" if area == "road" else "wood_bridge"
	var plate: Texture2D = campaign_art[key]
	var repeat := 4
	var scale_px := bridge.size.x/repeat/plate.get_width()
	draw_rect(Rect2(bridge.position.x,FLOOR,bridge.size.x,12),Color("#403240") if area == "road" else Color("#40332c"))
	for i in repeat:
		var x := bridge.position.x+i*bridge.size.x/repeat
		draw_texture_rect(plate,Rect2(x,FLOOR,bridge.size.x/repeat,plate.get_height()*scale_px),false,Color.WHITE if area=="road" else Color("#96add0"))
	draw_rect(Rect2(bridge.position.x,FLOOR-2,bridge.size.x,3),Color(tint,.58))
	for x: float in [bridge.position.x,bridge.end.x]:
		draw_rect(Rect2(x-7,FLOOR-40,14,43),Color("#372934"))
		draw_rect(Rect2(x-9,FLOOR-43,18,7),Color(tint,.84))

func draw_briars() -> void:
	for i in 13:
		var at := Vector2(FOREST_BRIARS.position.x+i*8,FLOOR)
		polygon([at,at+Vector2(3,-8-i%3*4),at+Vector2(8,0)],Color("#c17b74"))

func draw_gate_lock(tint: Color) -> void:
	if gate_closed <= 0.0:
		return
	var x := exit_x-16
	var slide := 1.0-gate_closed
	for i in 9:
		draw_rect(Rect2(x-54+i*12,360-slide*205,6,207),Color("#634b68"))
	draw_rect(Rect2(x-58,393-slide*205,117,8),Color(tint,.70))

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
	draw_props("courtyard")
	banner(79,352,42,tint)
	gate_art(1148,220,tint)
	if gate_closed > .001:
		var amount := clampf(gate_closed,0,1)
		draw_rect(Rect2(1085,327,126*amount,245),Color("#19161e"))
		seal(Vector2(1148,432),15*amount,Color(BLOOD,amount))

func draw_road(tint: Color) -> void:
	draw_props("road")
	for x: float in ROAD_DEBRIS:
		draw_masonry(x,tint)

func draw_shrine(_tint: Color) -> void:
	draw_props("shrine")

func draw_underworld(tint: Color) -> void:
	draw_props("underworld")
	for x: float in OBSTACLES.underworld:
		draw_masonry(x,tint)

func draw_frozen(tint: Color) -> void:
	draw_props("frozen")
	gate_art(area_width-119,217,tint)

func draw_props(location: String) -> void:
	for prop: Array in SCENERY[location]:
		var sprite: Texture2D = campaign_art[prop[0]]
		var size := (sprite.get_size() * float(prop[2])).round()
		var base := Vector2(prop[1],FLOOR)
		draw_texture_rect(sprite,Rect2((base-Vector2(size.x*.5,size.y)).round(),size),false,Color(prop[3]))

func draw_masonry(x: float, tint: Color) -> void:
	polygon([Vector2(x-19,572),Vector2(x-19,551),Vector2(x-12,545),Vector2(x-2,540),
		Vector2(x+15,543),Vector2(x+19,550),Vector2(x+19,572)],Color("#302930"))
	draw_line(Vector2(x-12,547),Vector2(x+14,545),Color(tint,.48),2.0,true)

func draw_throne(tint: Color) -> void:
	for i in 5:
		var width := 162.0-i*19
		var y := 551.0-i*8
		draw_rect(Rect2(640-width,y,width*2,8),Color("#332b3a").darkened(i*.035))
		draw_line(Vector2(640-width,y),Vector2(640+width,y),Color(tint,.16),1)
	for detail: Array in [[68,58,460,.26,-.58],[214,48,340,.48,.73],[1033,38,271,.58,-.72],[1210,68,475,.37,.61]]:
		var x: float = detail[0]
		var fall := smoothstep(detail[3],1.0,fortress_fall)
		var pivot := Vector2(x,FLOOR)
		var angle: float = detail[4]*fall
		draw_set_transform((pivot-pivot.rotated(angle)+Vector2(0,196*fall*fall)).round(),angle)
		pillar(x,detail[1],detail[2],tint)
		if fortress_fall > .08:
			var y: float = FLOOR-detail[2]*.52
			var crack := PackedVector2Array([Vector2(x-17,y-5),Vector2(x-5,y+8),Vector2(x+4,y-1),Vector2(x+17,y+13)])
			draw_polyline(crack,Color("#090914",smoothstep(.08,.30,fortress_fall)),3)
		draw_set_transform(Vector2.ZERO)
	for side: float in [-1,1]:
		var fall := smoothstep(.19 if side < 0 else .28,1.0,fortress_fall)
		var base := Vector2(640,352)
		draw_set_transform((base+Vector2(side*120*fall,240*fall*fall)).round(),side*fall*.64,Vector2(side,1))
		polygon([Vector2.ZERO,Vector2(73,-27),Vector2(154,-21),Vector2(201,-6),Vector2(257,-11),
			Vector2(234,20),Vector2(149,28),Vector2(80,22),Vector2(11,30)],Color("#272337"))
		draw_polyline(PackedVector2Array([Vector2(1,6),Vector2(73,-18),Vector2(154,-13),
			Vector2(208,2),Vector2(242,-1)]),Color(tint,.25),4)
		draw_set_transform(Vector2.ZERO)
	if fortress_fall < .95:
		polygon([Vector2(603,520),Vector2(603,451),Vector2(624,424),Vector2(659,424),
			Vector2(681,451),Vector2(681,520)],Color("#30283b"))

func draw_floor_fracture(at: Vector2, amount: float) -> void:
	for side: float in [-1,1]:
		var split := PackedVector2Array([at,at+Vector2(side*14,8)*amount,
			at+Vector2(side*26,4)*amount,at+Vector2(side*44,15)*amount,at+Vector2(side*68,16)*amount])
		draw_polyline(split,Color("#0d0b13"),3.0)
		draw_polyline(split,Color("#756276",.56),1.0)

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
		if h > 0.0:
			polygon([Vector2(x,FLOOR),Vector2(x+9,FLOOR-h),Vector2(x+24,FLOOR)],ground)

func draw_mist(tint: Color) -> void:
	for i in int(area_width/205)+4:
		var x := fposmod(time*(6+i%4)+i*217,area_width+380)-170
		var y := 492.0+i*13%73
		draw_set_transform(Vector2(x,y),-.016,Vector2(3.9,.12+i%3*.025))
		draw_circle(Vector2.ZERO,82,Color(tint,.032))
	draw_set_transform(Vector2.ZERO)

func gate_art(x: float, height: float, tint: Color) -> void:
	var top := FLOOR-height
	var tone := Color("#29232b")
	for side: float in [-1,1]:
		draw_line(Vector2(x+side*68,FLOOR),Vector2(x+side*62,top+11),tone,11,true)
		draw_line(Vector2(x+side*65,FLOOR-6),Vector2(x+side*59,top+12),Color(tint,.22),1.1,true)
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



func seal(at: Vector2, radius: float, color: Color) -> void:
	draw_polyline(PackedVector2Array([at+Vector2(0,-radius),at+Vector2(radius*.62,0),at+Vector2(0,radius),
		at+Vector2(-radius*.62,0),at+Vector2(0,-radius)]),color,1.25,true)
	draw_line(at+Vector2(0,-radius*.45),at+Vector2(0,radius*.45),color,1.0,true)

func polygon(points: Array[Vector2], color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points),color)
