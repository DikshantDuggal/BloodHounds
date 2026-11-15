extends SceneTree
## Run without --headless to also capture the video and menu layout.
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures += 1

func press(key: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await process_frame

func capture(label: String) -> void:
	var folder := OS.get_environment("BLOODBOUND_QA_DIR")
	if folder.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	verify(root.get_texture().get_image().save_png(folder.path_join(label + ".png")) == OK, "Capture " + label)

func open_startup() -> void:
	if current_scene and current_scene.has_method("quit_game"):
		current_scene.story.stop()
		current_scene.sound.stop_all()
	verify(change_scene_to_file("res://scenes/Startup.tscn") == OK, "Load startup scene")
	await process_frame
	await process_frame
	if "--skip-intro" in OS.get_cmdline_user_args():
		for frame in 30:
			if current_scene and current_scene.scene_file_path == "res://scenes/Throne.tscn":
				break
			await process_frame

func check_title() -> void:
	if current_scene == null:
		verify(false, "Movie leads to game scene")
		return
	verify(current_scene.scene_file_path == "res://scenes/Throne.tscn", "Movie leads to game scene")
	verify(current_scene.state == current_scene.State.TITLE, "Skip does not also start a new game")
	verify(current_scene.ui.buttons.size() == 3 and current_scene.ui.buttons[0].has_focus(), "Title has three options with Play focused")

func run() -> void:
	verify(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/Startup.tscn", "Project starts with the movie")
	await open_startup()
	if "--skip-intro" not in OS.get_cmdline_user_args():
		verify(current_scene.video.is_playing(), "Movie starts automatically")
		await create_timer(2.0).timeout
		verify(current_scene.video.stream_position > 0.5, "Video frames advance")
		await capture("intro")
		await create_timer(10.0).timeout
	check_title()
	await capture("menu")
	var game = current_scene
	await press(KEY_DOWN)
	verify(game.ui.buttons[1].has_focus(), "Arrow keys select Controls")
	await press(KEY_ENTER)
	verify(game.ui.menu_name == "controls", "Controls opens from keyboard")
	await capture("controls")
	await press(KEY_ESCAPE)
	verify(game.ui.menu_name == "title", "Escape returns to the title")
	await press(KEY_ENTER)
	verify(game.state == game.State.REVEAL, "Play starts the courtyard")
	await press(KEY_ESCAPE)
	verify(game.paused and game.ui.menu_name == "pause", "Escape opens pause")
	await capture("pause")
	game.command("audio")
	verify(game.ui.menu_name == "audio", "Audio is available from pause")
	await capture("audio")
	await press(KEY_ESCAPE)
	verify(game.ui.menu_name == "pause" and game.paused, "Audio returns to pause")
	game.command("title")
	verify(current_scene == game and game.ui.menu_name == "title", "Returning to the menu does not replay the movie")
	if "--skip-intro" not in OS.get_cmdline_user_args():
		for key in [KEY_ENTER, KEY_ESCAPE, KEY_SPACE]:
			await open_startup()
			await press(key)
			check_title()
		await open_startup()
		current_scene.skip.pressed.emit()
		current_scene.finish()
		await process_frame
		await process_frame
		check_title()
	current_scene.sound.stop_all()
	current_scene.story.stop()
	await create_timer(.2).timeout
	print("BLOODBOUND startup/menu checks complete. Failures: ", failures)
	quit(failures)
