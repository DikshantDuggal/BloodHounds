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
	snapshot_dir = OS.get_environment("BLOODBOUND_QA_DIR")
	game = WORLD.instantiate()
	root.add_child(game)
	await process_frame
	expect(game.state == game.State.TITLE,"Title opens")
	await check_frame("title")
	game.begin()
	await check_frame("opening")
	game.reveal()
	game.start_prologue()
	game.begin_doom()
	game.begin_departure()
	game.start_awakening()
	game.clock = 4.0
	await check_frame("ancestral-vision")
	game.skip_cinematic()
	await check_frame("awakening-skip")
	game.enter_duel()
	game.start_resurrection(false)
	game.clock = .49 * game.resurrection_duration()
	await check_frame("resurrection-vision")
	game.skip_cinematic()
	await process_frame
	await physics_frame
	await check_frame("resurrection-skip")
	game.pulse("white",Color("#fff5e5"))
	expect(game.flash_level > .8,"One Flash still starts with a bright pulse")
	await create_timer(.34).timeout
	expect(game.flash_level < .01,"White flash naturally expires")
	await check_frame("after-white-flash")
	game.pulse("white",Color.WHITE)
	game.set_paused(true)
	expect(game.flash_level == 0.0,"Pausing cannot freeze the white flash")
	game.command("title")
	await check_frame("return-to-title")
	game.begin()
	await check_frame("fresh-run")
	game.sound.stop_all()
	await create_timer(.15).timeout
	game.queue_free()
	await process_frame
	quit(errors)

func check_frame(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	var sampled := 0
	var pale := 0
	for x in range(20,frame.get_width()-20,19):
		for y in range(20,frame.get_height()-20,19):
			var pixel := frame.get_pixel(x,y)
			if minf(pixel.r,minf(pixel.g,pixel.b)) > .68:
				pale += 1
			sampled += 1
	expect(float(pale)/float(sampled) < .22,label+" keeps the scene visible")
	if not snapshot_dir.is_empty():
		expect(frame.save_png(snapshot_dir.path_join(label+".png")) == OK,label+" capture")
