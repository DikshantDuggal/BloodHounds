extends Control
## A separate startup scene keeps the movie out of retries and menu returns.

const MENU_SCENE := "res://scenes/Throne.tscn"
const OPENING_VIDEO := "res://assets/video/opening.ogv"

@onready var video: VideoStreamPlayer = $AspectRatio/Video
@onready var skip: Button = $Skip
var leaving := false

func _ready() -> void:
	skip.pressed.connect(finish)
	video.finished.connect(finish)
	if "--skip-intro" in OS.get_cmdline_user_args() or not ResourceLoader.exists(OPENING_VIDEO):
		finish()
		return
	video.stream = load(OPENING_VIDEO) as VideoStream
	if video.stream == null:
		finish()
		return
	video.play()
	if not video.is_playing():
		finish()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_SPACE]:
			get_viewport().set_input_as_handled()
			finish()

func finish() -> void:
	if leaving:
		return
	leaving = true
	video.stop()
	skip.disabled = true
	# Change scenes after the skip input has finished propagating.
	call_deferred("open_menu")

func open_menu() -> void:
	var error := get_tree().change_scene_to_file(MENU_SCENE)
	if error != OK:
		push_error("Could not open the main menu (%s)" % error)
