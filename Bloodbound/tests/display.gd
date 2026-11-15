extends SceneTree

const WORLD = preload("res://scenes/Throne.tscn")
var errors := 0
var game
var snapshot_dir := ""

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ",label)
	else:
		errors += 1
		push_error(label)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Display tests require a graphical renderer.")
		quit(1)
		return
	snapshot_dir = OS.get_environment("BLOODBOUND_QA_DIR")
	game = WORLD.instantiate()
	root.add_child(game)
	await process_frame
	expect(game.state == game.State.TITLE,"Title opens")
	game.sound.play_track("missing_music","main_menu")
	var menu_volume: float = game.profile.get_value("music_db","main_menu")
	expect(game.sound.track == "main_menu" and game.sound.goal_db == menu_volume,
		"Missing music uses the fallback track and its configured volume")
	var voices: int = game.sound.effect_cursor
	game.sound.cue("missing_effect")
	expect(game.sound.effect_cursor == voices,"Missing optional effects do not start playback")
	await check_frame("title")
	game.begin()
	await check_frame("opening")
	game.reveal()
	game.start_prologue()
	game.begin_doom()
	game.begin_departure()
	game.start_awakening()
	await check_story_movie()
	game.clock = 5.1
	await check_frame("between-first",true)
	game.skip_cinematic()
	await check_frame("awakening-skip")
	game.enter_duel()
	game.hero.health = 0
	game.start_resurrection(false)
	game.clock = .49 * game.resurrection_duration()
	await check_frame("between-brief",true)
	game.skip_cinematic()
	await process_frame
	await physics_frame
	await check_frame("resurrection-skip")
	game.pulse("white",Color("#fff5e5"))
	expect(game.flash_level > .8,"One Flash still starts with a bright pulse")
	await create_timer(.34).timeout
	expect(game.flash_level < .01,"White flash naturally expires")
	await check_frame("after-white-flash")
	game.boss.health = 0
	game.transition_to(game.State.EXECUTE)
	game.finish()
	await create_timer(10.3).timeout
	await check_frame("curse-dissolution")
	await create_timer(5.5).timeout
	await check_frame("sword-in-stone")
	await create_timer(7.5).timeout
	await check_frame("future-heir")
	game.skip_cinematic()
	expect(game.ui.menu_name == "victory","Ending skip opens credits")
	await check_frame("credits")
	game.pulse("white",Color.WHITE)
	game.set_paused(true)
	expect(game.flash_level == 0.0,"Pausing cannot freeze the white flash")
	game.command("title")
	await check_frame("return-to-title")
	game.begin()
	await check_frame("fresh-run")
	expect(not game.story_movie_attempted and game.story_movie_elapsed == 0.0,
		"New Game clears the first-death video flag")
	game.start_awakening()
	game.clock = game.timing("soul_departure")
	for frame in 4:
		await physics_frame
	expect(game.ui.story_movie.is_playing(),"A second run can start the Oda movie")
	game.to_title()
	expect(not game.ui.story_movie.is_playing() and not game.ui.story_movie_backdrop.visible,
		"Return to Title stops a playing movie")
	game.sound.stop_all()
	await create_timer(.15).timeout
	game.queue_free()
	await process_frame
	quit(errors)

func check_story_movie() -> void:
	var bus := AudioServer.get_bus_index("Music")
	var tap := AudioEffectCapture.new()
	var effect_index := AudioServer.get_bus_effect_count(bus)
	AudioServer.add_bus_effect(bus,tap)
	game.clock = game.timing("soul_departure")-.035
	var peak := 0.0
	var shown := false
	for frame in 850:
		await process_frame
		var available := tap.get_frames_available()
		if available > 0:
			for stereo in tap.get_buffer(available):
				peak = maxf(peak,maxf(absf(stereo.x),absf(stereo.y)))
		if not shown and game.ui.story_movie.stream_position >= 8.8:
			shown = true
			await check_frame("oda-video-end")
		if shown and not game.ui.story_movie_backdrop.visible:
			break
	AudioServer.remove_bus_effect(bus,effect_index)
	expect(shown and game.story_movie_elapsed > 9.9 and not game.ui.story_movie_backdrop.visible,
		"The video reaches its full embedded lore and relinquishes playback")
	expect(peak > .02,"Video audio produces a measurable signal on the Music bus")

func check_frame(label: String, between: bool = false) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	var sampled := 0
	var pale := 0
	var dark := 0
	for x in range(20,frame.get_width()-20,19):
		for y in range(20,frame.get_height()-20,19):
			var pixel := frame.get_pixel(x,y)
			if minf(pixel.r,minf(pixel.g,pixel.b)) > .68:
				pale += 1
			if maxf(pixel.r,maxf(pixel.g,pixel.b)) < .09:
				dark += 1
			sampled += 1
	expect(float(pale)/float(sampled) < .22,label+" keeps the scene visible")
	if between:
		expect(float(dark)/float(sampled) > .92,label+" uses the black Between")
	if not snapshot_dir.is_empty():
		expect(frame.save_png(snapshot_dir.path_join(label+".png")) == OK,label+" capture")
