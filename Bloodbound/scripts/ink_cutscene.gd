extends Control

const KETSUMEI = preload("res://assets/last_oath/heir/ketsumei.png")
const SIZE := Vector2(1280,720)
const PAPER := Color("#e3d6bc")
const INK := Color("#292527")
const CRIMSON := Color("#8e283c")
const GOLD := Color("#9b713c")

var monster: Texture2D
@export var illustration: Texture2D
@export var foreground: Texture2D
@export var reveal_mask: Texture2D
@export_range(0.0,1.0) var progress := 0.0:
	set(value):
		progress = value
		queue_redraw()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _draw() -> void:
	draw_on(self,"clan",progress,illustration,foreground,reveal_mask,{})

func draw_on(canvas: CanvasItem, key: String, p: float, background: Texture2D, layer: Texture2D, mask: Texture2D, options: Dictionary) -> void:
	var abyss := key == "abyss"
	var paper := Color("#a98179") if abyss else PAPER
	canvas.draw_rect(Rect2(Vector2.ZERO,SIZE),paper)
	var reveal := smoothstep(0,.32,p)
	var pan: Vector2 = options.get("pan",Vector2(42,0))
	var zoom := maxf(1.0,float(options.get("zoom",1.05)))
	var center := 640.0 + (.5-p)*pan.x
	if background:
		draw_art(canvas,background,p,pan,zoom,1.0)
	else:
		landscape(canvas,center,p,key)
		match key:
			"clan", "memory", "memorial":
				for i in 5:
					var a := smoothstep(.13+i*.075,.37+i*.075,p)
					warrior(canvas,Vector2(center+(i-2)*102,521+abs(i-2)*6),1.15-abs(i-2)*.12, a, false)
			"blade", "awakening":
				draw_blade(canvas,Vector2(center,362),lerpf(-.26,.33,p),4.25)
			"massacre", "death":
				for i in 7:
					var x := 208.0+i*146.0
					var height := 43.0+(i*35%91)
					var roof := PackedVector2Array([Vector2(x-50,505),Vector2(x-31,505-height),Vector2(x+20,475-height),Vector2(x+61,505-height),Vector2(x+68,505)])
					canvas.draw_colored_polygon(roof,Color(INK,.72))
					canvas.draw_line(Vector2(x-18,496),Vector2(x-31-sin(p*3+i)*17,421-height),Color(CRIMSON,.5),8,true)
				if monster:
					canvas.draw_texture_rect(monster,Rect2(center-306,161,720,400),false,Color("#552d3a"))
				warrior(canvas,Vector2(center-232,539),.64,reveal,false)
				if key == "death":
					draw_blade(canvas,Vector2(center-172,548),1.54,1.55)
			"flash", "defeat":
				var is_flash := key == "flash"
				var warrior_at := Vector2(center-215 if is_flash else center+211,524)
				warrior(canvas,warrior_at,1.46,reveal,not is_flash)
				draw_blade(canvas,warrior_at+Vector2(36,-48),1.37 if is_flash else 1.72,2.4)
				if monster:
					var at := Vector2(center+137,515) if is_flash else Vector2(center-79,512)
					canvas.draw_set_transform(at,0 if is_flash else -.31)
					canvas.draw_texture_rect(monster,Rect2(-332,-338,672,374),false,Color("#211d22",reveal))
					canvas.draw_set_transform(Vector2.ZERO)
				else:
					warrior(canvas,Vector2(center+137 if is_flash else center-79,512),2.3,reveal,not is_flash)
				var slash := smoothstep(.34,.7,p)
				if slash > .03:
					var start := Vector2(127,520)
					var end := start.lerp(Vector2(1160,275),slash)
					var across := (end-start).normalized().orthogonal()
					var brush := PackedVector2Array([start-across*5,start.lerp(end,.44)-across*13,
						end,start.lerp(end,.66)+across*7,start+across*9])
					canvas.draw_colored_polygon(brush,Color(CRIMSON,.83))
					canvas.draw_line(start,end,Color("#f5e3cc",.8),2.1,true)
			"celestial", "abyss":
				var color := CRIMSON if abyss else GOLD
				canvas.draw_arc(Vector2(center,422),114,PI,TAU,60,Color(INK,.65),22,true)
				for side: float in [-1,1]:
					canvas.draw_line(Vector2(center+side*114,421),Vector2(center+side*114,530),Color(INK,.65),22,true)
				var soul := Vector2(center+sin(p*4)*27,513-p*127)
				canvas.draw_circle(soul,24,Color(color,.16),true,-1,true)
				canvas.draw_circle(soul,8,Color("#fff3d9"),true,-1,true)
				if p>.5:
					var thread := PackedVector2Array()
					for i in 22:
						var t := i/21.0
						thread.append(soul.lerp(Vector2(center+232,563),t)+Vector2(0,sin(t*9+p*26)*11*sin(t*PI)))
					canvas.draw_polyline(thread,CRIMSON,2.3,true)
			_:
				warrior(canvas,Vector2(center-67,541),1.65,reveal,key=="ending")
				if key=="ending":
					draw_blade(canvas,Vector2(center-32,434),lerpf(.65,1.83,p),2.55)
	if layer:
		draw_art(canvas,layer,p,pan,zoom,reveal)
	if mask:
		canvas.draw_texture_rect(mask,Rect2(Vector2.ZERO,SIZE),false,Color(paper,(1-reveal)*.28))
	for i in 218:
		var at := Vector2(fposmod(i*153.867,1280),fposmod(i*91.147,720))
		canvas.draw_circle(at,.5+float(i%7)*.24,Color(INK,.07+float(i%5)*.013))
	for band in 19:
		var start := reveal * (1395+sin(band*21.1)*71) - 55
		if start < 1280:
			canvas.draw_rect(Rect2(start,band*39,1280-start,40), paper)
		if reveal > 0 and reveal < .99:
			canvas.draw_line(Vector2(start-39,band*39.0+10),Vector2(start+22,band*39.0+12),Color(INK,.23),2+band%4,true)
	if key=="massacre" or key=="death":
		for i in 38:
			var d := Vector2.from_angle(i*2.39996)
			var at := Vector2(center,371)+d*(20.0+i*4.7)*reveal
			canvas.draw_circle(at,1.4+(i%5)*.73,Color(CRIMSON,reveal*.72))

func draw_art(canvas: CanvasItem, texture: Texture2D, p: float, pan: Vector2, zoom: float, opacity: float) -> void:
	var source := texture.get_size()
	var size := source * (maxf(SIZE.x/source.x,SIZE.y/source.y) * zoom)
	canvas.draw_texture_rect(texture,Rect2((SIZE-size)*.5+pan*(p-.5),size),false,Color(1,1,1,opacity))

func landscape(canvas: CanvasItem, center: float, p: float, key: String) -> void:
	var red := key in ["death","massacre","abyss"]
	var sun := Color(CRIMSON,.54) if red else Color(GOLD,.5)
	canvas.draw_circle(Vector2(center+28,235),97,sun,true,-1,true)
	canvas.draw_arc(Vector2(center+28,235),101,-2.4,1.45,65,Color(INK,.36),2,true)
	for depth in 4:
		var points := PackedVector2Array([Vector2(-80,556)])
		for i in 45:
			var x := -80.0+i*34.0
			var y := 333.0+depth*42+sin(x*.007+depth*1.21)*(64-depth*9)+sin(x*.023+depth)*16
			points.append(Vector2(x,y))
		points.append(Vector2(1450,556))
		canvas.draw_colored_polygon(points,Color(INK,.14+depth*.15))
	for i in 20:
		var x := fposmod(i*163.6+p*62,1600)-160
		var y := 208.0+i*29%280
		canvas.draw_line(Vector2(x,y),Vector2(x+106+i%4*31,y-5),Color(PAPER,.34),float(2+i%8),true)
	canvas.draw_line(Vector2(105,559),Vector2(1172,560),Color(INK,.6),1,true)

func warrior(canvas: CanvasItem, feet: Vector2, scale: float, alpha: float, bowed: bool) -> void:
	canvas.draw_set_transform(feet,.08 if bowed else 0,Vector2.ONE*scale)
	var shade := Color(INK,alpha)
	canvas.draw_circle(Vector2(0,-91),12,shade,true,-1,true)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-13,-79),Vector2(13,-83),Vector2(22,-54),Vector2(41,-11),
		Vector2(13,-23),Vector2(-24,-9),Vector2(-22,-43)]),shade)
	canvas.draw_line(Vector2(-8,-31),Vector2(-18,1),shade,7,true)
	canvas.draw_line(Vector2(9,-30),Vector2(15,0),shade,7,true)
	canvas.draw_line(Vector2(-12,-85),Vector2(18,-89),Color(CRIMSON,alpha*.9),3,true)
	canvas.draw_line(Vector2(13,-72),Vector2(27,-33),shade,7,true)
	canvas.draw_set_transform(Vector2.ZERO)

func draw_blade(canvas: CanvasItem, at: Vector2, angle: float, scale: float) -> void:
	canvas.draw_set_transform(at,angle,Vector2.ONE*scale)
	canvas.draw_texture_rect(KETSUMEI,Rect2(Vector2(-8.5,-52.5),KETSUMEI.get_size()),false)
	canvas.draw_set_transform(Vector2.ZERO)
