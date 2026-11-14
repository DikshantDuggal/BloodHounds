extends SceneTree

const WORLD = preload("res://scenes/Throne.tscn")
const BLADE = preload("res://assets/last_oath/heir/ketsumei.png")
const POSES := ["idle","run","jump_start","rise","fall","land","dash","dodge","parry","parry_success",
	"draw_blade","light_1","light_2","light_3","dash_slash","heavy","air","sever","resurrect","reversal",
	"final_prepare","final_dash","final_strike","finish","victory"]

var game
var failures := 0
var snapshots := ""
var poses_checked := 0

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)

func run() -> void:
	snapshots = OS.get_environment("BLOODBOUND_QA_DIR")
	game = WORLD.instantiate()
	root.add_child(game)
	game.ui.show_panel("")
	game.enter_duel()
	game.transition_to(game.State.TRANSITION)
	game.set_physics_process(false)
	game.hero.position = Vector2(588,572)
	game.boss.hide()
	game.camera.position = Vector2(600,500)
	game.camera.zoom = Vector2(2.75,2.75)
	game.camera.focus_actor(0,Vector2(600,500),2.75)
	game.set_process(false)
	var art = game.hero_art
	var blade: Sprite2D = art.weapon_sprite
	var pixels := BLADE.get_image()
	verify(pixels.get_size() == Vector2i(17,60) and pixels.get_pixel(0,0).a == 0,"Wrong sword dimensions or background")
	for y in [49,52,55]:
		for x in [7,9]:
			var red := pixels.get_pixel(x,y)
			verify(red.r > .5 and red.g < .08 and is_equal_approx(red.a,1.0),"Red grip pixel is missing")
	verify(blade.texture == BLADE and blade.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,"Wrong sword resource or texture filter")
	verify(blade.get_parent() == art.weapon_pivot and blade.offset == -art.weapon_grip,"Wrong grip origin")
	for pose: String in POSES:
		game.hero.facing = 1.0
		game.hero.script_pose(pose,.53)
		art.redraw()
		var right: Transform2D = art.weapon_pivot.transform
		var clip := StringName(art.imported.animation)
		var marker_count: int = art.weapon_tracks.get(pose,art.weapon_tracks.get(String(clip),[])).size()
		verify(art.imported.visible and marker_count == art.imported.sprite_frames.get_frame_count(clip),"Missing hand marker for "+pose)
		if pose == "light_1":
			await capture("combo-right")
		elif pose == "heavy":
			await capture("heavy-active")
		elif pose == "parry_success":
			await capture("perfect-parry")
		elif pose == "final_prepare":
			await capture("one-flash-draw")
		game.hero.facing = -1.0
		art.redraw()
		var left: Transform2D = art.weapon_pivot.transform
		var reflected := Transform2D(0,Vector2(-1,1),0,Vector2.ZERO)*right
		verify(left.is_equal_approx(reflected),"Sword and grip do not mirror together in "+pose)
		verify(blade.texture == BLADE and blade.modulate == Color.WHITE and blade.self_modulate == Color.WHITE,"Sword art changed in "+pose)
		if pose == "light_1":
			await capture("combo-left")
		poses_checked += 1
	for attack: String in ["light_1","light_2","light_3","dash_slash","air","heavy","charged","sever"]:
		var spec: Dictionary = game.hero.profile.get_value("combat",attack)
		game.hero.facing = 1.0
		game.hero.script_pose(spec.name,spec.start/spec.total)
		art.redraw()
		var vector: Vector2 = art.weapon_pivot.transform * Vector2(2,-49) - art.weapon_pivot.position
		verify(vector.x > 30,"Blade must face into the hitbox at the impact of "+attack)
	var hero = game.hero
	hero.enable()
	hero.mode = hero.Mode.DASH
	hero.queued["light"] = .10
	hero.simulate(1.0/60.0)
	verify(hero.mode == hero.Mode.ATTACK and hero.strike_data.name == "dash_slash","Light input during dodge must begin the dash slash")
	print("Checked %d sword poses in both directions and eight strike impact frames. Failures: %d" % [poses_checked,failures])
	game.sound.stop_all()
	var deadline := Time.get_ticks_msec()+120
	while Time.get_ticks_msec() < deadline:
		await process_frame
	game.queue_free()
	await process_frame
	quit(failures)

func capture(label: String) -> void:
	if snapshots.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	verify(frame.save_png(snapshots.path_join(label+".png")) == OK,"Could not save "+label)

