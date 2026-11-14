extends Node

const RATE := 22050
const NOTES := [0, 3, 7, 10, 7, 3, 12, 10]
const SCORES := ["prologue", "boss_phase_1", "boss_phase_2", "boss_final_phase", "victory"]
const TRACKS := ["main_menu", "prologue", "clan_massacre", "ashen_path", "clan_memorial", "boss_intro",
	"boss_phase_1", "boss_phase_2", "boss_final_phase", "opening_duel", "warden", "spirit", "guardian", "rival", "shrine", "underworld", "frozen", "boss_transform", "epilogue", "first_death", "afterlife_celestial",
	"afterlife_abyss", "resurrection", "final_flash", "victory", "credits"]
const CUES := ["heartbeat", "swing", "hit", "parry", "dash", "tell", "slam", "death",
	"awakening", "phase", "buildup", "final", "shatter", "confirm"]
var profile
var music := AudioStreamPlayer.new()
var ambience := AudioStreamPlayer.new()
var sfx: Array[AudioStreamPlayer] = []
var bank := {}
var track := ""
var goal_db := -17.0
var volume := 0.8
var effect_cursor := 0
var fade_rate := 38.0

func setup(config) -> void:
	profile = config
	fade_rate = maxf(1.0, float(profile.get_value("music_settings", "fade_db_per_second", 38.0)))
	for bus: String in ["Music", "SFX", "UI", "Ambience"]:
		if AudioServer.get_bus_index(bus) == -1:
			var id := AudioServer.bus_count
			AudioServer.add_bus()
			AudioServer.set_bus_name(id, bus)
	music.bus = &"Music"
	music.volume_db = -55
	add_child(music)
	ambience.bus = &"Ambience"
	ambience.volume_db = -26
	add_child(ambience)
	for i in 8:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		sfx.append(voice)
	for key: String in TRACKS + CUES + ["ambience"]:
		var audio: AudioStream = profile.optional("audio", key, "AudioStream")
		bank[key] = audio
	if DisplayServer.get_name() == "headless":
		return
	for key: String in CUES:
		if not bank[key]:
			bank[key] = synth_hit(key)
	ambience.stream = bank.ambience if bank.ambience else synth_score(43.65, 4.0, 0, true)
	ambience.play()

func stop_all() -> void:
	music.stop()
	ambience.stop()
	for voice in sfx:
		voice.stop()

func tick(dt: float) -> void:
	music.volume_db = move_toward(music.volume_db, goal_db, dt * fade_rate)
	ambience.volume_db = move_toward(ambience.volume_db, -70.0 if goal_db < -45 else -28.0, dt * 37)

func set_volume(value: float) -> void:
	volume = value
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(.001, value)))
	AudioServer.set_bus_mute(0, value <= 0.0)

func play_track(key: String, fallback: String = "prologue") -> void:
	var selected := key
	if not bank.get(key) and key not in SCORES and not key.is_empty():
		selected = fallback
	if selected.is_empty() or (not bank.get(selected) and selected not in SCORES):
		goal_db = -65
		return
	var base := -24.0 if selected == "prologue" else -16.0
	goal_db = float(profile.get_value("music_db", key, base))
	if DisplayServer.get_name() == "headless" or (selected == track and music.playing):
		return
	track = selected
	if not bank.get(selected):
		var index := SCORES.find(selected)
		bank[selected] = synth_score([43.65, 55.0, 51.91, 65.41, 58.27][index],
			[8.0, 8.0, 7.0, 6.4, 9.6][index], index, false)
	music.stream = bank[selected]
	music.volume_db = -45
	var start := float(profile.get_value("music_start", key, 0.0))
	music.play(clampf(start, 0.0, maxf(0.0, music.stream.get_length() - .01)))

func cue(key: String) -> void:
	var stream: AudioStream = bank.get(key)
	if not stream:
		return
	var voice := sfx[effect_cursor % sfx.size()]
	effect_cursor += 1
	voice.bus = &"UI" if key == "confirm" else &"SFX"
	voice.volume_db = -12.0 if key in ["tell", "dash", "confirm", "swing"] else -7.0
	voice.stream = stream
	voice.play()

func synth_hit(key: String) -> AudioStreamWAV:
	var shape: Array = {
		"swing": [.18, 147, 510, .60], "hit": [.27, 64, 151, .42], "parry": [.43, 824, 1230, .14],
		"dash": [.22, 68, 214, .58], "tell": [.33, 285, 290, .06], "slam": [.64, 38, 92, .30],
		"death": [.82, 46, 98, .15], "awakening": [1.10, 197, 92, .13], "phase": [.93, 101, 71, .30],
		"buildup": [1.29, 255, 53, .10], "final": [.32, 530, 1400, .42], "shatter": [1.06, 51, 138, .38],
		"confirm": [.16, 420, 520, .03], "heartbeat": [.30, 43, 25, .035]
	}[key]
	var total := roundi(float(shape[0]) * RATE)
	var bytes := PackedByteArray()
	bytes.resize(total * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(hash(key))
	var smooth := 0.0
	for i in total:
		var t := float(i) / RATE
		var p := float(i) / total
		var wave := t * (float(shape[1]) + float(shape[2]) * exp(-p * 8))
		smooth = lerpf(smooth, rng.randf_range(-1, 1), .3)
		var tone := sin(TAU * wave) * .58 + sin(TAU * wave * 1.505) * .21
		var envelope := minf(1.0, t * 200.0) * pow(1 - p, 2.3)
		var sample := (tone * (1.0 - float(shape[3])) + smooth * float(shape[3])) * envelope
		bytes.encode_s16(i * 2, roundi(sample * 24000))
	return stream_from(bytes, false)

func synth_score(base: float, length: float, variant: int, ambient: bool) -> AudioStreamWAV:
	var total := roundi(length * RATE)
	var bytes := PackedByteArray()
	bytes.resize(total * 2)
	for i in total:
		var t := float(i) / RATE
		var p := float(i) / total
		var pulse := fposmod(p * 16.0, 1.0)
		var step := floori(p * 16.0) % NOTES.size()
		var swell := .53 + .47 * sin(TAU * p - 1.4)
		var fundamental := sin(TAU * base * t) * .23 + sin(TAU * base * 1.5 * t) * .12
		var bell := sin(TAU * base * 4.0 * pow(2.0, float(NOTES[step]) / 12) * t)
		bell *= minf(1.0,pulse*21.0) * exp(-pulse * 4.4)
		var drum := sin(TAU * (42 * pulse + 3 * (1.0 - exp(-pulse * 21)))) * exp(-pulse * 12)
		var melodic := bell * .14 + drum * .095
		if variant in [0, 4]:
			melodic = bell * .09
		if ambient:
			melodic = 0
		var taper := clampf(minf(p, 1.0-p) * 38, 0, 1)
		bytes.encode_s16(i * 2, roundi((fundamental * swell + melodic) * taper * 23500))
	return stream_from(bytes, true)

func stream_from(bytes: PackedByteArray, loop: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = bytes.size() >> 1
	return stream
