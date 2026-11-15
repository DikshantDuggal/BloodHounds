extends CanvasLayer

signal requested(action: String)

const HOT := Color("#f78fa2")
const LIGHT := Color("#f4ded8")
const MUTED := Color("#b9abbf")
const VIOLET := Color("#c1a2f0")
var game
var canvas: Control
var menu: VBoxContainer
var buttons: Array[Button] = []
var display_font: Font
var text_font: Font
var menu_name := ""
var story_movie := VideoStreamPlayer.new()
var story_movie_backdrop := ColorRect.new()
var hud_alpha := 0.0
var shown_health := 1.0
var shown_boss := 1.0
var hud_boss: CharacterBody2D

func setup(director) -> void:
	game = director
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	display_font = SystemFont.new()
	display_font.font_names = PackedStringArray(["Palatino Linotype", "Georgia", "Times New Roman"])
	text_font = SystemFont.new()
	text_font.font_names = PackedStringArray(["Segoe UI", "Arial"])
	story_movie_backdrop.color = Color("#050409")
	story_movie_backdrop.size = Vector2(1280,720)
	story_movie_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	story_movie_backdrop.hide()
	add_child(story_movie_backdrop)
	story_movie.expand = true
	story_movie.size = Vector2(1280,720)
	story_movie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	story_movie.bus = &"Music"
	story_movie.stream = game.profile.optional("visual","story_video","VideoStream") as VideoStream
	story_movie_backdrop.add_child(story_movie)
	story_movie.finished.connect(stop_story_movie)
	canvas = Control.new()
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(paint)
	add_child(canvas)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 9)
	canvas.add_child(menu)

func play_story_movie() -> bool:
	if story_movie.stream == null:
		return false
	story_movie_backdrop.show()
	story_movie.play()
	return true

func stop_story_movie() -> void:
	story_movie.stop()
	story_movie_backdrop.hide()

func refresh(dt: float) -> void:
	hud_alpha = move_toward(hud_alpha, 1.0 if game.shows_hud() else 0.0, dt * 5.2)
	shown_health = move_toward(shown_health, float(game.hero.health) / game.hero.maximum, dt * 1.3)
	if game.boss.visible:
		var ratio: float = float(game.boss.health)/game.boss.maximum
		shown_boss = ratio if game.boss != hud_boss else move_toward(shown_boss,ratio,dt*.9)
		hud_boss = game.boss
	else:
		hud_boss = null
	canvas.queue_redraw()

func reset_hud() -> void:
	hud_alpha = 0
	shown_health = 1
	shown_boss = 1
	hud_boss = null
	canvas.queue_redraw()

func show_panel(name: String) -> void:
	if menu_name == name:
		return
	menu_name = name
	canvas.queue_redraw()
	for child in menu.get_children():
		menu.remove_child(child)
		child.queue_free()
	buttons.clear()
	menu.position = Vector2(105, 415) if name == "title" else Vector2(496, 388)
	match name:
		"title":
			add_button("NEW GAME", "begin")
			add_button("CONTROLS", "controls")
			add_button("SETTINGS", "audio")
			add_button("QUIT", "quit")
		"controls":
			menu.position.y = 559
			add_button("RETURN TO TITLE", "title")
		"pause":
			add_button("RESUME", "resume")
			if not game.curse_active:
				add_button("RETRY", "retry")
			add_button("AUDIO SETTINGS", "audio")
			add_button("RETURN TO TITLE", "title")
		"audio":
			menu.position.y = 343
			var music_slider := add_volume_slider("Music",game.sound.music_volume,game.sound.set_music_volume)
			add_volume_slider("Effects",game.sound.effects_volume,game.sound.set_effects_volume)
			add_button("BACK", "title" if game.state == game.State.TITLE else "pause")
			music_slider.grab_focus()
			return
		"defeat":
			add_button("RESTART BATTLE", "retry")
			add_button("RETURN TO TITLE", "title")
		"victory":
			menu.position.y = 553
			add_button("RETURN TO TITLE", "title")
	if not buttons.is_empty():
		buttons[0].grab_focus()

func add_volume_slider(label: String, value: float, callback: Callable) -> HSlider:
	var row := HBoxContainer.new()
	var caption := Label.new()
	caption.text = label
	caption.custom_minimum_size.x = 62
	row.add_child(caption)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(220,34)
	slider.max_value = 1.0
	slider.step = .05
	slider.value = value
	slider.value_changed.connect(callback)
	row.add_child(slider)
	menu.add_child(row)
	return slider

func add_button(label: String, id: String) -> void:
	var control := Button.new()
	control.text = label
	control.custom_minimum_size = Vector2(248 if menu_name == "title" else 288, 39)
	control.alignment = HORIZONTAL_ALIGNMENT_LEFT if menu_name == "title" else HORIZONTAL_ALIGNMENT_CENTER
	control.add_theme_font_override("font", text_font)
	control.add_theme_font_size_override("font_size", 14)
	control.add_theme_color_override("font_color", LIGHT)
	control.add_theme_color_override("font_focus_color", Color.WHITE)
	control.add_theme_color_override("font_hover_color", Color.WHITE)
	control.add_theme_stylebox_override("normal", style(Color("#241b2c"), Color("#4f394c")))
	control.add_theme_stylebox_override("hover", style(Color("#452639"), HOT))
	control.add_theme_stylebox_override("pressed", style(Color("#622a44"), HOT))
	control.add_theme_stylebox_override("focus", style(Color(0,0,0,0), HOT))
	control.pressed.connect(func() -> void: requested.emit(id))
	control.mouse_entered.connect(func() -> void:
		control.grab_focus()
		game.sound.cue("confirm"))
	menu.add_child(control)
	buttons.append(control)

func style(fill: Color, border: Color) -> StyleBoxFlat:
	var value := StyleBoxFlat.new()
	value.bg_color = fill
	value.border_color = border
	value.border_width_left = 3
	value.border_width_bottom = 1
	value.border_width_right = 1
	value.border_width_top = 1
	value.content_margin_left = 17
	return value

func paint() -> void:
	var state: int = game.state
	var s = game.State
	var t: float = game.clock
	if state == s.TITLE or menu_name == "controls":
		title()
	if hud_alpha > .005:
		hud(hud_alpha)
	if state == s.EPILOGUE:
		story_panel()
	elif state == s.MEMORIAL:
		cinematic_label("THE SKULL GUARDIAN FALLS",game.profile.get_value("story","oda_legend"),LIGHT,smoothstep(0.0,.5,t))
		center("ENTER  Skip",681,13,MUTED)
	elif state == s.APPROACH:
		approach()
	elif state == s.VILLAGE:
		center(game.journey.ACTS[0],107,19,LIGHT,true)
		center("SHINEGEN ODA",138,15,Color(LIGHT,.88))
		center("Follow the ruined village road to the courtyard",619,14,LIGHT)
		center("A / D  Move     SPACE  Jump     J  Attack     SHIFT  Dash     L  Parry",648,14,MUTED)
		panel(Rect2(0,0,1280,720),Color("#100c17",1.0-smoothstep(0,1.04,t)))
	elif state == s.REVEAL:
		var fade := 1.0 - smoothstep(0.0, 1.4, t)
		if fade > 0:
			panel(Rect2(0,0,1280,720), Color(.015,.011,.024,fade))
		if t < 1.25:
			center(game.journey.ACTS[0], 103, 17, Color(LIGHT, smoothstep(.42,1.28,t)))
			center("A / D  Move     SPACE  Jump     J  Attack     K  Heavy     SHIFT  Dash     L  Parry",
				645, 16, Color(LIGHT, smoothstep(.42,1.28,t)))
		if t >= 4.12:
			center("“%s”" % game.profile.get_value("story", "challenge"), 374, 28, LIGHT, true)
		elif t >= 1.25 and t < 2.65:
			letterbox(.9)
		elif t >= 2.75 and t < 3.34:
			draw_speed_lines(smoothstep(2.75,3.20,t)*(1.0-smoothstep(3.23,3.34,t)))
		center("ENTER  Skip", 681, 13, MUTED)
	elif state == s.DEPARTURE:
		letterbox(.85)
		center("“%s”" % game.profile.get_value("story","departure"),306,29,Color(LIGHT,smoothstep(.3,.7,t)*(1.0-smoothstep(2.6,3.5,t))),true)
		center("ENTER  Skip",675,13,MUTED)
	elif state == s.FINAL_REVEAL:
		letterbox(.85)
		center(game.profile.get_value("story","arena"),224,27,LIGHT,true)
		var line_key := "night_warning" if t < 1.6 else ("reunion" if t < 3.3 else "reply")
		var line_text: String = game.profile.get_value("story",line_key)
		center("“%s”" % line_text,330,29,LIGHT,true)
		center("ENTER  Skip",675,13,MUTED)
	elif state == s.DOOM:
		letterbox(.87)
		var opacity := 1.0-smoothstep(.65,game.timing("doom_wind"),t)
		center(game.profile.get_value("story","doom"),218,29,Color(HOT,opacity),true)
		center("ENTER  Skip", 675, 13, MUTED)
	elif state == s.AWAKEN:
		awakening(t)
	elif state == s.RESURRECTING:
		var progress: float = t / game.resurrection_duration()
		if game.reversal and progress < .73:
			panel(Rect2(0,0,1280,720),Color("#f9efd7",.34*sin(progress*PI)))
			cinematic_label("DEATH REVERSAL","",HOT,sin(progress*PI))
		if progress >= game.BETWEEN_OPEN and progress < game.BETWEEN_CLOSE:
			var between_progress: float = inverse_lerp(game.BETWEEN_OPEN,game.BETWEEN_CLOSE,progress)
			draw_between(between_progress,false)
	elif state == s.CHALLENGER:
		cinematic_label("THE SKULL GUARDIAN",game.profile.get_value("story","sovereign_rematch"),VIOLET,smoothstep(0,.32,t))
		center("ENTER  Skip",675,13,MUTED)
	elif state == s.UNLOCK:
		var ability: String = game.unlock_ability
		var title_text: String = game.Powers.LABELS[ability].to_upper()
		var key: String = game.Powers.KEYS.get(ability,"")
		var tint: Color = game.Powers.COLORS[ability]
		var hint: String = {"resurrection":"Return from death while charges remain","phantom":"E  ·  Dash through the ancestral ward","sever":"U  ·  Send a slash toward the shrine seal","reversal":"Q  ·  Spend one charge and full energy to heal and strike"}.get(ability,key)
		var detail := "%s   ·   MAX HP  %d" % [hint,game.hero.maximum]
		cinematic_label(title_text + " UNLOCKED",detail,tint,smoothstep(.16,.55,t))
		diamond(Vector2(640,201),6,Color(tint,smoothstep(.16,.55,t)))
		center("ENTER  Skip",675,13,MUTED)
	elif state == s.TRANSITION:
		var opacity := smoothstep(.14,.48,t) * (1.0 - smoothstep(2.18,2.7,t))
		cinematic_label("THE BROKEN CROWN" if game.next_stage == 2 else "THE FINAL OATH",
			game.profile.get_value("story","phase_two_line" if game.next_stage==2 else "phase_three_line"), VIOLET, opacity)
		center("ENTER  Skip", 675, 13, Color(MUTED,opacity))
	elif state == s.FLASH_PREP:
		var progress: float = t / game.timing("final_anticipation")
		letterbox(.82)
		if progress < .51:
			center("“%s”" % game.profile.get_value("story","final_voice"),614,22,LIGHT,true)
		else:
			cinematic_label("ONE FLASH — THE LAST OATH","Wait for the opening",HOT,smoothstep(.51,.71,progress))
	elif state == s.FLASH_OPEN:
		letterbox(.75)
		center("STRIKE NOW", 319, 16, HOT)
		center("PRESS  F", 382, 53, Color.WHITE, true)
		var left := clampf(1.0 - t / game.timing("final_window"), 0.0, 1.0)
		gauge(Vector2(516, 400), Vector2(248, 3), left, Color("#fff2e7"), HOT, 1.0)
	elif state == s.LAST_CHANCE:
		cinematic_label("THE OATH HOLDS", "JUMP THE SHOCKWAVE", HOT, 1.0)
	elif state == s.EXECUTE:
		letterbox(.87)
		if t > game.timing("final_shatter") + .65:
			var opacity := smoothstep(2.0,2.65,t)
			center(game.profile.get_value("story","victory"), 332, 30, Color(LIGHT,opacity), true)
			center("ENTER  Skip", 671, 13, Color(MUTED,opacity))
	if game.low_health and game.shows_hud():
		draw_health_warning()
	if game.flash_level > 0.005:
		panel(Rect2(0,0,1280,720), Color(game.flash_color, game.flash_level))
	if menu_name in ["controls", "pause", "audio", "defeat", "victory"]:
		modal()

func title() -> void:
	for i in 45:
		var opacity := .045 * pow(1.0 - i / 45.0, 1.8)
		panel(Rect2(0, 0, 445 + i * 14.0, 720), Color(.021,.015,.035,opacity))
	panel(Rect2(0,0,1280,72), Color("#0b0911"))
	panel(Rect2(0,607,1280,113), Color("#0b0911"))
	line(Vector2(104,195),Vector2(168,195),HOT,1)
	diamond(Vector2(178,195), 4, HOT)
	write(Vector2(203,199), game.profile.get_value("story", "arena"), 14, MUTED)
	var reveal := smoothstep(.02,.75,game.clock) if menu_name == "title" else 1.0
	write(Vector2(99,302+floorf((1.0-reveal)*9)), "BLOODBOUND", 94, Color(LIGHT,reveal), true)
	write(Vector2(105,354), "T H E   L A S T   O A T H", 25, Color(HOT,reveal), true)
	line(Vector2(104,381), Vector2(529,381), Color(HOT,.33), 1.0)
	write(Vector2(104,657), "ENTER  Select     ↑ / ↓  Navigate", 14, MUTED)
	write(Vector2(871,650), "SHINEGEN ODA", 16, MUTED, true)
	write(Vector2(871,674), "ART  chierit · CraftPix · Firepious · NYKNCK", 12, MUTED)

func hud(a: float) -> void:
	var h = game.hero
	var stats = h.progression
	var b = game.boss
	var stage: int = b.stage
	var top_name: String = h.profile.get_value("identity", "name", "Shinegen Oda")
	var sword_name: String = h.profile.get_value("identity", "weapon", "")
	write(Vector2(76,49), "%s  ·  %s" % [top_name.to_upper(), sword_name], 16, Color(LIGHT, a))
	gauge(Vector2(76, 61), Vector2(276, 10), shown_health, Color("#f3778b"), Color("#932b57"), a)
	write(Vector2(365,70),"%d / %d" % [h.health,h.maximum],13,Color(LIGHT,a))
	gauge(Vector2(76, 84), Vector2(171, 4), h.energy / stats.energy_limit, Color("#ffbe99"), HOT, a)
	write(Vector2(76, 108), "ABILITY ENERGY", 10, Color(MUTED, a*.87))
	var dash_color := MUTED if h.dash_cd > 0 else LIGHT
	var parry_color := MUTED if h.parry_cd > 0 else LIGHT
	write(Vector2(1058,58), "SHIFT  Dash", 13, Color(dash_color, a * (.42 if h.dash_cd > 0 else .93)))
	write(Vector2(1152,58), "L  Parry", 13, Color(parry_color, a * (.42 if h.parry_cd > 0 else .93)))
	if game.is_fight():
		write(Vector2(882,93),game.journey.ACTS[game.journey.act()],11,Color(LIGHT,a*.82))
	if stats.has("resurrection"):
		for i in stats.charge_limit:
			sword_sigil(Vector2(80+i*20,128),i < stats.charges,a)
		write(Vector2(157,133),"SOUL LV. %d" % h.resurrection_level,12,Color(LIGHT,a))
	write(Vector2(252,107),"LEVEL %d" % stats.level,11,Color(LIGHT,a))
	var index := 0
	for ability: String in ["phantom","sever","reversal"]:
		if stats.has(ability):
			power_icon(Vector2(76+index*48,151),ability,a)
			index += 1
	if game.parry_notice > 0.0:
		center("PERFECT PARRY",118,14,Color("#ffe7ae",minf(a,game.parry_notice*3.0)))
	if not b.visible:
		if game.arena.area == "frozen":
			var wolf_index := 0
			for wolf in game.journey.enemies:
				if not wolf.dead and absf(wolf.position.x-h.position.x) < 820:
					var x := 373.0 + wolf_index*281.0
					write(Vector2(x,644),"%s  %d / %d" % [wolf.display_name,wolf.health,wolf.maximum],13,Color(LIGHT,a))
					gauge(Vector2(x,656),Vector2(228,7),float(wolf.health)/wolf.maximum,wolf.accent,Color("#493748"),a)
					wolf_index += 1
		if game.state == game.State.APPROACH and game.journey.tell_time > 0:
			center(game.journey.tell,137,17,Color(LIGHT,a),true)
			center(game.journey.tell_cue,158,12,Color(LIGHT,a))
		return
	var boss_name: String = b.profile.get_value("identity", "name", "THE DEMON OVERLORD")
	center(boss_name, 632, 22, Color(LIGHT,a), true)
	var phase_name: String = "SHRINE TRIAL" if game.side_encounter() else ["PROLOGUE","THE FURNACE","INFERNAL SEALS","THE FINAL OATH"][stage]
	center(phase_name, 653, 10, Color(VIOLET,a*.92))
	gauge(Vector2(327,666),Vector2(626,9),shown_boss, Color("#ba89e0"), Color("#6d487e"), a)
	write(Vector2(967,676),"%d / %d" % [b.health,b.maximum],13,Color(LIGHT,a))
	if stage > 0 and not game.side_encounter():
		for key: String in ["two", "three"]:
			var threshold: float = b.profile.get_value("phases", key)
			line(Vector2(327+626*threshold,663),Vector2(327+626*threshold,679),Color(LIGHT,a*.58),1)
		gauge(Vector2(501,685),Vector2(278,3),b.stagger/b.stagger_limit,Color("#eac69e"),Color("#b58b64"),a*.78)
	if b.mode == b.Mode.WIND and game.is_fight():
		var info: Dictionary = b.stats
		center(info.label, 143, 17, Color(LIGHT, a), true)
		center(info.cue, 165, 10, Color(VIOLET,a*.86))
	elif stage > 0 and b.mode in [b.Mode.RECOVER,b.Mode.STAGGER] and game.state == game.State.FIGHT:
		center("OPEN TO A COUNTER",157,12,Color("#f8dcba",a*.90))
	elif b.mode == b.Mode.ACTIVE and b.attack == "throne" and game.is_fight():
		var beat: int = 0 if b.clock < .24 else (1 if b.clock < .86 else 2)
		center(["I     DASH", "II     DASH", "III     PARRY"][beat], 158, 16, Color(LIGHT, a))

func power_icon(at: Vector2, ability: String, a: float) -> void:
	var available: bool = game.powers.ready(game.hero,ability)
	if ability == "reversal":
		available = game.reversal_ready()
	elif ability == "flash":
		available = false
	var tint: Color = game.Powers.COLORS[ability]
	var opacity := a if available else a*.52
	var bounds := Rect2(at,Vector2(38,27))
	panel(bounds,Color("#211927",a*.9))
	canvas.draw_rect(bounds,Color(tint,opacity),false,1.0)
	diamond(at+Vector2(9,13.5),3,Color(tint,opacity))
	var cooldown := float(game.powers.cooldowns.get(ability,0.0))
	var label: String = game.Powers.KEYS[ability] if cooldown <= 0.0 else str(ceili(cooldown))
	write(at+Vector2(17,18),label,12,Color(LIGHT,opacity))

func draw_speed_lines(strength: float) -> void:
	for i in 18:
		var y := 62.0+i*37
		var side := -1 if i%2==0 else 1
		var x := 640.0+side*(614-i%4*14)
		line(Vector2(x,y),Vector2(x-side*(65+i%5*17),y+(360-y)*.17),Color("#efe1d0",strength*(.14+i%4*.06)),1.5)

func draw_health_warning() -> void:
	var beat := float(game.heartbeat) / .86
	var alpha := .18 + .37*pow(clampf(beat,0,1),4)
	for band in 9:
		var size := 5.0+band*4
		var tint := Color("#9d1736", alpha*.21*(1.0-band/10.0))
		panel(Rect2(0,0,size,720),tint)
		panel(Rect2(1280-size,0,size,720),tint)
		panel(Rect2(0,0,1280,size),tint)
		panel(Rect2(0,720-size,1280,size),tint)

func story_panel() -> void:
	var shot: Dictionary = game.story.presentation()
	var t: float = game.clock
	if game.story.illustrations.get(shot.art):
		game.story.draw_plate(canvas,shot.art,shot.progress)
	if t >= game.ENDING_BLACK-.45:
		panel(Rect2(0,0,1280,720),Color("#0a0810",smoothstep(game.ENDING_BLACK-.45,game.ENDING_BLACK,t)))
	letterbox(.93)
	line(Vector2(400,641),Vector2(880,641),Color(HOT,.38),1)
	center(shot.line,375 if t >= game.ENDING_BLACK else 618,24,Color(LIGHT,shot.opacity),true)
	center("ENTER  Skip",678,13,MUTED)

func approach() -> void:
	var route = game.journey
	var area_name: String = route.NAMES[game.arena.area]
	write(Vector2(882,93),area_name,13,LIGHT)
	write(Vector2(882,113),route.ACTS[route.act()],10,Color(LIGHT,.8))
	if route.notice_time > 0:
		var alpha := clampf(route.notice_time,0,1)
		center(route.notice,234,25,Color(LIGHT,alpha),true)
	if route.tell_time > 0:
		return
	if game.arena.area == "courtyard":
		var hint := "A / D  Move     SPACE  Jump     →  Old Stone Bridge"
		if route.show_phantom_hint():
			hint = "E  Phantom Step through the ward   ·   Hold →"
		center(hint,638,15,LIGHT)
	elif game.arena.area == "shrine" and game.hero.position.x > 345.0 and game.hero.position.x < 660.0:
		center(game.profile.get_value("story","shrine_inscription"),620,19,LIGHT,true)
	elif game.arena.show_sever_target and game.hero.position.x > 1270.0:
		center("U  Aim Soul Sever at the shrine seal",638,15,LIGHT)
	elif game.hero.position.x > game.arena.exit_x - 260.0:
		center("→  Continue" if route.enemy_count()==0 else "Defeat the remaining enemies to open the gate",630,15,LIGHT)
	elif jump_prompt():
		center("SPACE  Jump the debris",638,15,LIGHT)
	elif game.arena.area == "road" and game.hero.position.x < 340.0:
		center("J  Slash     K  Heavy     SHIFT  Dodge     L  Parry",638,15,LIGHT)

func jump_prompt() -> bool:
	for obstacle: float in game.arena.OBSTACLES.get(game.arena.area,[]):
		if game.hero.position.x >= obstacle-125.0 and game.hero.position.x < obstacle+20.0:
			return true
	return false

func draw_between(p: float, first: bool) -> void:
	var alpha := smoothstep(0.0,.14,p)*(1.0-smoothstep(.84,1.0,p))
	var darkness := 1.0-smoothstep(.84,1.0,p) if first else alpha
	panel(Rect2(0,0,1280,720),Color("#050409",darkness))
	for i in 62:
		var mote := Vector2(fposmod(i*173.77+p*(12+i%4*8),1280),fposmod(i*i*31.37-p*31,720)).round()
		panel(Rect2(mote,Vector2.ONE*(1+i%3)),Color("#e9e2eb",alpha*(.12+i%5*.06)))
	var retreat := smoothstep(.10,.52,p)
	draw_distant_gate(Vector2(640-lerpf(238,146,retreat),lerpf(341,273,retreat)),
		lerpf(104,43,retreat),Color("#f0c17d",alpha))
	draw_distant_gate(Vector2(640+lerpf(254,163,retreat),lerpf(346,282,retreat)),
		lerpf(90,36,retreat),Color("#c84567",alpha*.72))
	var bound := smoothstep(.39,.59,p) if first else smoothstep(.1,.24,p)
	var pull := smoothstep(.72,1.0,p) if first else smoothstep(.46,1.0,p)
	var reach := smoothstep(.16,.48,p) if first else 0.0
	var spirit: Vector2 = Vector2(639-91*reach,455-77*reach+sin(p*39.0)*4.0*reach).lerp(Vector2(953,502),pull)
	var grip := Vector2(953,502)
	var blade: Texture2D = game.hero_art.weapon_sprite.texture
	if blade:
		canvas.draw_texture_rect(blade,Rect2(grip-game.hero_art.weapon_grip*1.3,blade.get_size()*1.3),
			false,Color(Color.WHITE,alpha*bound))
	game.effects.draw_thread(canvas,spirit,grip,p*5.0,alpha*bound)
	game.effects.draw_spirit(canvas,spirit,1.60,alpha*(1.0-pull*.85),0.0)
	if first:
		center("THE BETWEEN",130,24,Color(LIGHT,alpha*.85),true)
		var denial := smoothstep(.24,.32,p)*(1.0-smoothstep(.51,.60,p))
		var oath := smoothstep(.60,.66,p)*(1.0-smoothstep(.84,.93,p))
		center(game.profile.get_value("story","between_denial"),592,27,Color(LIGHT,denial*alpha),true)
		center(game.profile.get_value("story","between_oath"),592,27,Color(LIGHT,oath*alpha),true)

func draw_distant_gate(at: Vector2, radius: float, tint: Color) -> void:
	for ring in 4:
		canvas.draw_circle(at-Vector2(0,radius*.42),radius*(.55+ring*.19),Color(tint,tint.a*.08))
	canvas.draw_arc(at,radius*.48,PI,TAU,28,Color(tint,tint.a*.64),2.0,true)
	for direction in [-1,1]:
		var post := at+Vector2(direction*radius*.48,0)
		line(post,post+Vector2(0,radius*.57),Color(tint,tint.a*.57),2.0)
	line(at+Vector2(-radius*.6,radius*.57),at+Vector2(radius*.6,radius*.57),Color(tint,tint.a*.29),1.0)

func sword_sigil(at: Vector2, charged: bool, opacity: float) -> void:
	var color := Color(HOT if charged else MUTED,opacity*(.95 if charged else .30))
	if charged:
		canvas.draw_circle(at,8,Color(HOT,.13*opacity),true,-1,true)
	line(at+Vector2(0,7),at+Vector2(0,-8),color,1.6)
	line(at+Vector2(-3,3),at+Vector2(3,3),color,1.3)
	diamond(at+Vector2(0,-4),2.1,color)

func awakening(t: float) -> void:
	if story_movie_backdrop.visible:
		return
	var flash_at: float = game.timing("awakening_flash")
	letterbox(.88)
	var depart: float = game.timing("soul_departure")
	var arrive: float = game.timing("soul_return")
	if t < depart:
		panel(Rect2(0,0,1280,720),Color("#050409",smoothstep(0,.55,t)))
		var opacity := smoothstep(.30,.73,t)*(1.0-smoothstep(1.63,depart,t))
		center(game.profile.get_value("story","first_death_line"),364,32,Color(LIGHT,opacity),true)
	elif t < arrive:
		draw_between(inverse_lerp(depart,arrive,t),true)
	elif t >= flash_at:
		var awakened := t > flash_at + 1.14
		var heading := "ANCESTRAL RESURRECTION AWAKENED" if awakened else "THE THREAD PULLS YOU BACK"
		var dialogue := "“%s”" % game.profile.get_value("story","awakening_reaction") if awakened else ""
		cinematic_label(heading, dialogue, HOT, smoothstep(flash_at,flash_at+.5,t))
	center("ENTER  Skip", 675, 13, MUTED)

func cinematic_label(title_text: String, detail: String, color: Color, opacity: float) -> void:
	letterbox(opacity * .78)
	center(title_text, 246, 34, Color(color, opacity), true)
	center(detail, 278, 14, Color(LIGHT, opacity))

func letterbox(a: float) -> void:
	panel(Rect2(0,0,1280,50),Color(.021,.016,.032,a))
	panel(Rect2(0,652,1280,68),Color(.021,.016,.032,a))

func modal() -> void:
	if menu_name == "victory" and game.story.illustrations.get("ending"):
		game.story.draw_plate(canvas,"ending",.75)
	panel(Rect2(0,0,1280,720), Color(.031,.024,.052,.81 if menu_name != "victory" else .53))
	var box := Rect2(440, 174, 400, 418)
	if menu_name == "controls":
		box = Rect2(371,108,538,514)
	panel(box, Color("#171322"))
	canvas.draw_rect(box, Color("#594054"), false, 1)
	line(box.position, Vector2(box.end.x,box.position.y), HOT, 2)
	diamond(Vector2(640,box.position.y+35), 5, HOT)
	match menu_name:
		"controls":
			center("CONTROLS", 199, 32, LIGHT, true)
			var entries := [["A / D   or   ← / →","Move"], ["SPACE   or   ↑","Jump"], ["J","Light attack / combo"],
				["K   Hold / release","Heavy / charged attack"], ["SHIFT","Dodge / dash"], ["L","Parry"],
				["E / U","Phantom Step / Soul Sever"], ["Q","Death Reversal"], ["F","One Flash"], ["ESC   /   R","Pause / retry after defeat"]]
			for i in entries.size():
				var y := 227.0 + i * 30
				write(Vector2(420,y), entries[i][0], 13, HOT)
				write(Vector2(632,y), entries[i][1], 14, LIGHT)
				line(Vector2(419,y+11),Vector2(857,y+11),Color(HOT,.11),1)
		"pause":
			center("PAUSED", 294, 37, LIGHT, true)
		"audio":
			center("AUDIO SETTINGS", 294, 32, LIGHT, true)
		"defeat":
			center("THE HEIR HAS FALLEN", 287, 28, LIGHT, true)
			center("R  Return to the last checkpoint", 328, 14, MUTED)
		"victory":
			center("ANOTHER AWAITS", 252, 33, LIGHT, true)
			center("BLOODBOUND   ·   THE LAST OATH", 312, 16, LIGHT, true)
			center("ART   chierit · CraftPix · Firepious · NYKNCK", 393, 15, MUTED)
			center("FINAL BOSS ART   Demon Overlord 2D Pixel Art", 424, 14, MUTED)
			center("AUDIO   DavidDumaisAudio · Dragon Studio · Pixabay contributors",455,12,MUTED)
			center("PARRIES   %02d     •     TIME   %02d:%02d" % [game.parries, floori(game.fight_time / 60), int(game.fight_time) % 60],
				505, 13, HOT)

func gauge(at: Vector2, size: Vector2, fraction: float, bright: Color, dark: Color, opacity: float) -> void:
	panel(Rect2(at - Vector2.ONE * 2,size + Vector2.ONE * 4), Color("#17101c",opacity*.94))
	panel(Rect2(at,size),Color("#453248",opacity*.88))
	var width := size.x * clampf(fraction,0,1)
	if width > 0:
		panel(Rect2(at,Vector2(width,size.y)),Color(dark,opacity))
		panel(Rect2(at,Vector2(width,maxf(1,size.y*.36))),Color(bright,opacity))
		diamond(at + Vector2(width,size.y*.5), 2.5, Color(bright,opacity))

func center(value: String, y: float, size: int, color: Color, serif: bool = false, shadow: bool = true) -> void:
	var font := display_font if serif else text_font
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	write(Vector2(640-width*.5,y),value,size,color,serif,shadow)

func write(at: Vector2, value: String, size: int, color: Color, serif: bool = false, shadow: bool = true) -> void:
	var font := display_font if serif else text_font
	if shadow:
		canvas.draw_string(font, at+Vector2(1,2), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(.02,.01,.04,color.a*.85))
	canvas.draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func panel(rect: Rect2, color: Color) -> void:
	canvas.draw_rect(rect,color)

func line(a: Vector2,b: Vector2,color: Color,width: float) -> void:
	canvas.draw_line(a,b,color,width,true)

func diamond(at: Vector2, radius: float, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-radius),at+Vector2(radius,0),
		at+Vector2(0,radius),at+Vector2(-radius,0)]),color)
