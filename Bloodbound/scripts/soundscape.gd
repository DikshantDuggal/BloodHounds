extends Node

const TRACKS := ["main_menu", "prologue", "clan_massacre", "ashen_path", "clan_memorial", "boss_intro",
	"boss_phase_1", "boss_phase_2", "boss_final_phase", "opening_duel", "sovereign_duel", "shrine", "underworld", "frozen", "boss_transform", "epilogue", "first_death", "afterlife_celestial",
	"afterlife_abyss", "resurrection", "final_flash", "victory", "credits", "werewolves"]
const CUES := ["heartbeat", "swing", "hit", "parry", "dash", "tell", "slam", "death",
	"awakening", "phase", "buildup", "final", "shatter", "confirm", "wolf", "gate", "draw", "land", "jump", "wolf_attack", "wolf_death"]
var profile
var music := AudioStreamPlayer.new()
var sfx: Array[AudioStreamPlayer] = []
var bank := {}
var track := ""
var goal_db := -17.0
var music_volume := 0.8
var effects_volume := 0.8
var effect_cursor := 0
var fade_rate := 38.0

func setup(config) -> void:
	profile = config
	fade_rate = maxf(1.0, float(profile.get_value("music_settings", "fade_db_per_second", 38.0)))
	for bus: String in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus) == -1:
			var id := AudioServer.bus_count
			AudioServer.add_bus()
			AudioServer.set_bus_name(id, bus)
	music.bus = &"Music"
	music.volume_db = -55
	add_child(music)
	for i in 8:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		sfx.append(voice)
	for key: String in TRACKS + CUES + ["ambience"]:
		var audio: AudioStream = profile.optional("audio", key, "AudioStream")
		bank[key] = audio.duplicate() if audio and key in TRACKS else audio
	if DisplayServer.get_name() == "headless":
		return
	set_music_volume(music_volume)
	set_effects_volume(effects_volume)

func stop_all() -> void:
	music.stop()
	music.stream = null
	track = ""
	goal_db = -55.0
	music.volume_db = goal_db
	effect_cursor = 0
	for voice in sfx:
		voice.stop()
		voice.stream = null

func tick(dt: float) -> void:
	music.volume_db = move_toward(music.volume_db, goal_db, dt * fade_rate)

func set_music_volume(value: float) -> void:
	music_volume = value
	set_bus_volume("Music",value)

func set_effects_volume(value: float) -> void:
	effects_volume = value
	set_bus_volume("SFX",value)
	set_bus_volume("UI",value)

func set_bus_volume(bus: String, value: float) -> void:
	var id := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(id,linear_to_db(maxf(.001,value)))
	AudioServer.set_bus_mute(id,value <= 0.0)

func play_track(key: String, fallback: String = "") -> void:
	var selected := key
	if not bank.get(key) and not key.is_empty():
		selected = fallback
	if selected.is_empty() or (not bank.get(selected)):
		goal_db = -65
		music.stop()
		track = ""
		return
	goal_db = float(profile.get_value("music_db",key,-16.0))
	if DisplayServer.get_name() == "headless" or (selected == track and music.playing):
		return
	track = selected
	music.stream = bank[selected]
	if music.stream is AudioStreamMP3:
		music.stream.loop = true
	music.volume_db = -45
	var start := float(profile.get_value("music_start", key, 0.0))
	music.play(clampf(start, 0.0, maxf(0.0, music.stream.get_length() - .01)))

func cue(key: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var stream: AudioStream = bank.get(key)
	if not stream:
		return
	var voice := sfx[effect_cursor % sfx.size()]
	effect_cursor += 1
	voice.bus = &"UI" if key == "confirm" else &"SFX"
	voice.volume_db = -12.0 if key in ["tell", "dash", "confirm", "swing"] else -7.0
	voice.stream = stream
	voice.play()
