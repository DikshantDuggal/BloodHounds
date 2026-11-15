extends RefCounted
## Timed story panels and optional artwork or narration.
signal animation_requested(name: String)

const INK_SCENE = preload("res://scenes/InkCutscene.tscn")
const ART_KEYS := ["clan", "blade", "massacre", "heir", "memorial", "death", "awakening", "memory", "ending", "flash", "defeat"]
var illustrations: Dictionary = {}
var panels: Array = []
var index := 0
var clock := 0.0
var sound
var renderer
var narration: AudioStreamPlayer
var texture_cache: Dictionary = {}

func setup(profile, audio, sovereign_frames: SpriteFrames) -> void:
	sound = audio
	for key: String in ART_KEYS:
		illustrations[key] = profile.optional("illustrations", key, "Texture2D")
	renderer = INK_SCENE.instantiate()
	if sovereign_frames and sovereign_frames.has_animation("idle") and sovereign_frames.get_frame_count("idle") > 0:
		renderer.monster = sovereign_frames.get_frame_texture("idle", 0)
	renderer.visible = false
	sound.add_child(renderer)
	narration = AudioStreamPlayer.new()
	narration.bus = &"UI"
	sound.add_child(narration)

func begin(sequence: Array) -> void:
	panels = sequence
	index = 0
	clock = 0.0
	play_panel()

func stop() -> void:
	panels = []
	index = 0
	clock = 0.0
	narration.stop()

func advance(dt: float) -> bool:
	if index >= panels.size():
		return true
	clock += maxf(dt, 0.0)
	while index < panels.size() and clock >= duration():
		clock -= duration()
		index += 1
		if index >= panels.size():
			stop()
			return true
		play_panel()
	return false

func duration() -> float:
	return maxf(.1, float(panels[index].get("duration", 3.0)))

func play_panel() -> void:
	narration.stop()
	if index >= panels.size():
		return
	var entry: Dictionary = panels[index]
	if entry.has("track"):
		sound.play_track(entry.track)
	if entry.has("cue"):
		sound.cue(entry.cue)
	if entry.has("animation"):
		animation_requested.emit(entry.animation)
	var path: String = entry.get("voice", "")
	if not path.is_empty() and ResourceLoader.exists(path, "AudioStream"):
		narration.stream = load(path) as AudioStream
		narration.volume_db = float(entry.get("voice_db", -5.0))
		narration.play(maxf(0.0, float(entry.get("voice_start", 0.0))))

func presentation() -> Dictionary:
	if index >= panels.size():
		return {"art": "ending", "line": "", "progress": 1.0, "opacity": 0.0}
	var entry: Dictionary = panels[index]
	var length := duration()
	var fade := minf(.45, length * .18)
	return {"art": entry.get("art", "heir"), "line": entry.get("line", ""),
		"progress": clampf(clock / length, 0.0, 1.0),
		"opacity": smoothstep(0.0, fade, clock) * (1.0 - smoothstep(length - fade, length, clock))}

func optional_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not texture_cache.has(path):
		texture_cache[path] = load(path) if ResourceLoader.exists(path, "Texture2D") else null
	return texture_cache[path] as Texture2D

func draw_plate(canvas: CanvasItem, key: String, progress: float) -> void:
	if not is_instance_valid(renderer):
		return
	var options: Dictionary = {}
	if index < panels.size() and panels[index].get("art", "") == key:
		options = panels[index]
	var background: Texture2D = illustrations.get(key)
	if options.has("background"):
		background = optional_texture(options.background)
	var foreground: Texture2D = optional_texture(options.get("foreground", ""))
	var mask: Texture2D = optional_texture(options.get("mask", ""))
	renderer.draw_on(canvas, key, progress, background, foreground, mask, options)
