extends Node2D

signal state_changed(state: int)

const Profile = preload("res://scripts/profile.gd")
const Bindings = preload("res://scripts/bindings.gd")
const Strike = preload("res://scripts/strike.gd")
const Art = preload("res://scripts/fighter_art.gd")
const Effects = preload("res://scripts/effects.gd")
const Camera = preload("res://scripts/camera_director.gd")
const Interface = preload("res://scripts/interface.gd")
const Sound = preload("res://scripts/soundscape.gd")
const Story = preload("res://scripts/story.gd")
const Journey = preload("res://scripts/journey.gd")
const Powers = preload("res://scripts/powers.gd")

const DUEL_TRACKS := ["", "boss_phase_1", "boss_phase_2", "boss_final_phase"]

enum State { TITLE, REVEAL, PROLOGUE, DOOM, AWAKEN, FIGHT, TRANSITION,
	FLASH_PREP, FLASH_OPEN, LAST_CHANCE, EXECUTE, VICTORY, DEFEAT,
	APPROACH, MEMORIAL, RESURRECTING, DEPARTURE, FINAL_REVEAL, EPILOGUE, UNLOCK, CHALLENGER, VILLAGE }

@onready var hero = $Heir
@onready var sovereign = $Sovereign
@onready var overlord = $DemonOverlord
@onready var boss = overlord
@onready var arena = $Arena

var profile := Profile.new("res://resources/encounter.cfg")
var hero_art := Art.new()
var sovereign_art := Art.new()
var overlord_art := Art.new()
var boss_art := overlord_art
var effects := Effects.new()
var camera := Camera.new()
var ui := Interface.new()
var sound := Sound.new()
var story := Story.new()
var journey := Journey.new()
var departure_origin := 0.0
var doom_origin := 0.0
var doom_hero_x := 0.0
var story_movie_attempted := false
var story_movie_elapsed := 0.0
var resume_state := State.APPROACH
var reversal := false
var powers := Powers.new()
var unlock_ability := ""
var unlock_origin := Vector2.ZERO
var unlock_impact := false
var low_health := false
var heartbeat := 0.0
var low_health_seen := false
var parry_notice := 0.0
var curse_active := false
var resurrection_flash_pending := false
var flash_tween: Tween
var state := State.TITLE
var next_stage := 0
var clock := 0.0
var elapsed := 0.0
var fight_time := 0.0
var parries := 0
var flash_level := 0.0
var flash_color := Color.WHITE
var paused := false
var quitting := false
var debug_enabled := false
var stop_time := 0.0
var shatter_played := false
var slash_played := false
var awakening_played := false
var missed_wave := false
var execute_from := Vector2.ZERO
var execute_to := Vector2.ZERO
var fallen_from := Vector2.ZERO
var fallen_weapon := Transform2D.IDENTITY
var released_from := Transform2D.IDENTITY
var desired_mood := 0.0
var ghost_clock := 0.0
var side_finish_from := Vector2.ZERO
var side_finish_to := Vector2.ZERO
const CURSE_START := 7.9
const HERO_GONE := 12.4
const SWORD_LANDS := 14.9
const NEXT_HEIR := 19.5
const ENDING_BLACK := 24.5
const BETWEEN_OPEN := .30
const BETWEEN_CLOSE := .60
var ending_weapon := Transform2D.IDENTITY

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Bindings.install()
	for node: Node in [hero_art,sovereign_art,overlord_art,sound]:
		node.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().auto_accept_quit = false
	debug_enabled = OS.is_debug_build() and (profile.get_value("debug", "enabled", false)
		or "--dev" in OS.get_cmdline_user_args())
	add_child(camera)
	camera.make_current()
	camera.position = Vector2(640, 360)
	add_child(effects)
	effects.hero = hero
	effects.boss = boss
	effects.director = self
	hero.add_child(hero_art)
	hero_art.setup(hero, false)
	sovereign.add_child(sovereign_art)
	sovereign_art.setup(sovereign,true)
	overlord.add_child(overlord_art)
	overlord_art.setup(overlord,true)
	add_child(sound)
	sound.setup(profile)
	var boss_frames: SpriteFrames = overlord_art.imported.sprite_frames if overlord_art.imported else null
	story.setup(profile, sound, boss_frames)
	arena.set_profile(profile)
	add_child(journey)
	journey.game = self
	story.animation_requested.connect(func(pose: String) -> void: hero.script_pose(pose))
	add_child(ui)
	ui.setup(self)
	hero.swung.connect(hero_strike)
	hero.action.connect(hero_cue)
	hero.died.connect(hero_died)
	for actor in [sovereign,overlord]:
		actor.swung.connect(boss_strike.bind(actor))
		actor.telegraph.connect(boss_warning)
		actor.impact.connect(boss_impact)
	ui.requested.connect(command)
	to_title()

func select_boss(actor) -> void:
	sovereign.hide()
	overlord.hide()
	boss = actor
	boss_art = sovereign_art if actor == sovereign else overlord_art
	effects.boss = boss

func side_encounter() -> bool:
	return boss == sovereign and arena.area == "shrine"

func clear_flash() -> void:
	if flash_tween and flash_tween.is_valid():
		flash_tween.kill()
	flash_level = 0.0

func pulse(name: StringName, color: Color) -> void:
	clear_flash()
	var spec: Vector2 = {
		&"crimson":Vector2(.63,.63), &"white":Vector2(.26,.87),
		&"violet":Vector2(.55,.35), &"dust":Vector2(.55,.26)
	}[name]
	flash_color = color
	flash_level = spec.y
	flash_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	flash_tween.tween_property(self,"flash_level",0.0,spec.x).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func timing(key: String) -> float:
	return float(profile.get_value("timing", key, 0.0))

func transition_to(value: State) -> void:
	if state != value and state in [State.APPROACH, State.FIGHT]:
		powers.clear_attacks()
		if state == State.APPROACH:
			journey.interrupt()
	if state != value and state in [State.AWAKEN, State.RESURRECTING, State.EXECUTE, State.EPILOGUE]:
		clear_flash()
	state = value
	clock = 0
	stop_time = 0
	state_changed.emit(state)

func is_fight() -> bool:
	return state in [State.PROLOGUE, State.FIGHT]

func shows_hud() -> bool:
	return state in [State.PROLOGUE, State.FIGHT, State.LAST_CHANCE, State.APPROACH, State.VILLAGE]

func to_title() -> void:
	set_paused(false)
	clean()
	transition_to(State.TITLE)
	hero.position = Vector2(724, 572)
	boss.position = Vector2(985, 572)
	hero.script_pose("idle")
	boss.script_pose("idle")
	boss_art.modulate = Color("#524957")
	camera.position = Vector2(640, 360)
	camera.zoom = Vector2.ONE
	arena.mood = 0.0
	arena.shade = .32
	desired_mood = 0.0
	sound.play_track("main_menu")
	ui.show_panel("title")

func clean() -> void:
	hero.reset()
	hero_art.set_body_opacity(1.0)
	hero_art.released_weapon = false
	sovereign.reset()
	overlord.reset()
	overlord_art.modulate = Color.WHITE
	select_boss(overlord)
	story.stop()
	sound.stop_all()
	effects.clear()
	clear_flash()
	parries = 0
	fight_time = 0
	journey.reset()
	reset_powers()
	unlock_ability = ""
	resume_state = State.APPROACH
	resurrection_flash_pending = false
	unlock_origin = Vector2.ZERO
	unlock_impact = false
	low_health_seen = false
	parry_notice = 0
	reversal = false
	curse_active = false
	arena.set_area("courtyard")
	arena.heir_preview = null
	arena.time = 0.0
	arena.backdrop_time = 0.0
	arena.shade = 0.0
	arena.mood = 0.0
	desired_mood = 0.0
	boss.show()
	awakening_played = false
	story_movie_attempted = false
	story_movie_elapsed = 0.0
	ui.stop_story_movie()
	overlord_art.rotation = 0.0
	overlord_art.position = Vector2.ZERO
	shatter_played = false
	slash_played = false
	missed_wave = false
	next_stage = 0
	camera.snap_path(640,1280)
	camera.rumble = 0.0
	arena.parallax = 0.0
	flash_color = Color.WHITE
	elapsed = 0.0
	ghost_clock = 0.0
	ui.reset_hud()
	hero_art.reset_animation()
	sovereign_art.reset_animation()
	overlord_art.reset_animation()

func begin() -> void:
	set_paused(false)
	clean()
	ui.show_panel("")
	hero.position = Vector2(110,572)
	hero.enable()
	desired_mood = .45
	boss.hide()
	sound.play_track("ashen_path")
	transition_to(State.VILLAGE)

func wake_in_courtyard() -> void:
	ui.stop_story_movie()
	hero.progression.resurrect()
	hero.awakened = true
	hero.energy = 26.0
	var wake_x := clampf(fallen_from.x,174.0,720.0)
	hero_art.released_weapon = false
	journey.enter("courtyard",wake_x)
	level_reward(1,"courtyard",wake_x)

func reset_powers() -> void:
	powers.reset()
	low_health = false
	heartbeat = 0.0

func update_health_cues(dt: float) -> void:
	var threatened: bool = hero.health > 0 and hero.health <= hero.maximum * .30
	if threatened and not low_health_seen:
		low_health_seen = true
		pulse("dust",Color("#9c2c4d"))
	low_health = threatened
	if low_health:
		heartbeat -= dt
		if heartbeat <= 0.0:
			heartbeat = .86
			if sound.bank.get("heartbeat"):
				sound.cue("heartbeat")
	else:
		heartbeat = 0.0

func level_reward(level: int, area: String, x: float) -> void:
	var ability: String = hero.progression.unlock_for(level)
	hero.progression.refill()
	if ability in ["sever","reversal"]:
		hero.energy = hero.progression.energy_limit
	journey.save_checkpoint(area,x)
	if ability.is_empty():
		hero.enable()
		transition_to(State.APPROACH)
		return
	unlock_ability = ability
	unlock_origin = hero.position
	unlock_impact = false
	hero.script_pose("final_prepare")
	sound.cue("buildup")
	transition_to(State.UNLOCK)

func tick_unlock(dt: float) -> void:
	var p := clampf(clock / 1.75,0,1)
	var tint: Color = Powers.COLORS[unlock_ability]
	hero.visual_time += dt
	hero.phase = p
	if p >= .30 and not unlock_impact:
		unlock_impact = true
		sound.cue("awakening")
		pulse("dust",tint)
		effects.burst(hero.position + Vector2(0,-37),tint,42,220,-34,.60)
		effects.ghost(hero.position,hero.facing,tint)
		effects.arc(hero.position+Vector2(0,-40),hero.facing,92,tint)
	if p >= .30:
		match unlock_ability:
			"phantom":
				hero.pose = "final_dash" if p < .54 else "finish"
				var move_by: float = hero.facing * 114.0
				var end := clampf(unlock_origin.x+move_by,103,arena.exit_x-25)
				hero.position.x = lerpf(unlock_origin.x,end,smoothstep(.30,.54,p))
			"sever":
				hero.pose = "sever" if p < .68 else "finish"
			"reversal":
				hero.pose = "reversal" if p < .58 else "resurrect"
				hero.phase = smoothstep(.58,1.0,p) if p >= .58 else smoothstep(.30,.58,p)
			_:
				hero.pose = "resurrect" if p < .66 else "idle"
	if p >= 1.0:
		finish_unlock()

func finish_unlock() -> void:
	if state != State.UNLOCK:
		return
	if unlock_ability == "phantom":
		hero.position.x = clampf(unlock_origin.x+hero.facing*114,103,arena.exit_x-25)
	hero.enable()
	hero.iframe = maxf(hero.iframe,.50)
	if unlock_ability == "reversal":
		journey.announce("Q  DEATH REVERSAL READY",5.2)
	transition_to(State.APPROACH)

func show_side_boss() -> void:
	select_boss(sovereign)
	boss.reset()
	boss.position = Vector2(1310,572)
	boss.limits = Vector2(625,arena.exit_x-80)
	boss.encounter_floor = 0
	boss.damage_scale = .72
	boss.phase_damage = 0
	boss.show()
	hero.script_pose("idle")
	sound.play_track("sovereign_duel","")
	transition_to(State.CHALLENGER)

func start_side_fight() -> void:
	hero.enable()
	boss.enter_stage(1)
	transition_to(State.FIGHT)

func defeat_side_boss() -> void:
	journey.defeated["sovereign"] = true
	side_finish_from = hero.position
	side_finish_to = Vector2(hero.position.x,572)
	var side: float = 1.0 if boss.position.x >= hero.position.x else -1.0
	side_finish_to.x = clampf(boss.position.x+side*72,boss.limits.x,boss.limits.y)
	hero.facing = side
	hero.script_pose("final_prepare")
	boss.script_pose("execution_hit")
	sound.play_track("clan_memorial","")
	transition_to(State.MEMORIAL)

func tick_side_defeat(dt: float) -> void:
	hero.visual_time += dt
	var slash := .34
	var end := .64
	hero.position = side_finish_from.lerp(side_finish_to,smoothstep(slash,end,clock))
	if clock < slash:
		hero.phase = smoothstep(0.0,slash,clock)
	elif clock < end:
		hero.pose = "final_strike"
		hero.phase = smoothstep(slash,end,clock)
	else:
		hero.pose = "finish"
		hero.phase = smoothstep(end,1.8,clock)
	if clock >= slash and clock-dt < slash:
		sound.cue("shatter")
		camera.kick(4)
		effects.arc(hero.position+Vector2(30*hero.facing,-47),hero.facing,115,Color("#ffbf98"))
	if clock >= slash:
		boss.pose = "dissolve"
		boss.phase = smoothstep(slash,1.72,clock)
	if clock >= 3.0:
		finish_side_defeat()

func finish_side_defeat() -> void:
	hero.position = side_finish_to
	boss.hide()
	arena.set_exit_open(true)
	arena.show_sever_target = true
	story.stop()
	hero.progression.enter_level(3)
	level_reward(3,"shrine",arena.exit_x-220.0)
	sound.play_track("shrine","")

func resurrection_duration() -> float:
	return maxf(.35, float(profile.get_value("resurrection", "duration", 1.20)))

func reveal() -> void:
	select_boss(overlord)
	boss.reset()
	boss_art.modulate = Color.WHITE
	boss.show()
	boss.position = Vector2(964, 572)
	boss.facing = -1
	hero.position = Vector2(338, 572)
	boss.script_pose("idle")
	hero.script_pose("run")
	transition_to(State.REVEAL)
	sound.play_track("boss_intro")

func start_prologue() -> void:
	arena.set_area("courtyard")
	if boss != overlord:
		select_boss(overlord)
		boss.reset()
		boss.position = Vector2(964,572)
	boss.visible = true
	hero.position = Vector2(286,572)
	hero.enable()
	boss.enter_stage(0)
	boss.encounter_floor = roundi(boss.maximum*.86)
	boss.damage_scale = .63
	transition_to(State.PROLOGUE)
	sound.play_track("opening_duel","")

func begin_doom() -> void:
	if state != State.PROLOGUE:
		return
	transition_to(State.DOOM)
	floor_fighters()
	hero.position.x = clampf(hero.position.x,145.0,1135.0)
	doom_origin = boss.position.x
	doom_hero_x = hero.position.x
	hero.facing = -1.0 if boss.position.x < hero.position.x else 1.0
	hero.script_pose("parry")
	boss.facing = -hero.facing
	boss.script_pose("cleave_wind")
	sound.play_track("")
	sound.cue("buildup")

func begin_departure() -> void:
	var fall_phase: float = hero.phase if hero.pose == "death" else 0.0
	boss_art.rotation = 0.0
	boss_art.position = Vector2.ZERO
	transition_to(State.DEPARTURE)
	departure_origin = boss.position.x
	hero.health = 0
	fallen_from = hero.position
	released_from = hero_art.weapon_pivot.transform if hero_art.released_weapon else hero_art.hand_transform()
	fallen_weapon = Transform2D(0,Vector2(hero.facing,1)*hero_art.weapon_scale,0,Vector2(85*hero.facing,563-fallen_from.y)) * Transform2D(deg_to_rad(85.0),Vector2.ZERO)
	hero_art.released_weapon = true
	hero.script_pose("death",fall_phase)
	boss.script_pose("cleave_recover")
	awakening_played = false
	sound.play_track("first_death", "")
	sound.cue("death")

func tick_doom(dt: float) -> void:
	var contact := timing("doom_wind")
	var strike_ground := contact+.64
	boss.visual_time += dt
	hero.visual_time += dt
	boss.position.x = lerpf(doom_origin,doom_hero_x+hero.facing*106.0,smoothstep(.12,contact-.18,clock))
	if clock < contact:
		boss.phase = smoothstep(0,contact,clock)
		hero.phase = smoothstep(.22,contact-.12,clock)
		return
	if clock-dt < contact:
		sound.cue("hit")
		camera.kick(4.5)
		effects.burst(hero.position+Vector2(0,-49),Color("#bd4f68"),14,141,-33,.32)
	# Hold the contact cell before the recoil and the follow-through.
	boss.pose = "cleave" if clock < strike_ground+.18 else "cleave_recover"
	boss.phase = smoothstep(strike_ground+.18,contact+1.16,clock) if boss.pose == "cleave_recover" else 0.0
	hero.position.x = doom_hero_x-hero.facing*48.0*smoothstep(contact+.13,strike_ground,clock)
	hero.pose = "fatal_recoil" if clock < contact+.33 else "death"
	hero.phase = smoothstep(contact+.12,contact+.31,clock) if hero.pose == "fatal_recoil" \
		else smoothstep(contact+.33,contact+.97,clock)
	var lean := smoothstep(contact+.27,strike_ground,clock)*(1.0-smoothstep(strike_ground+.18,contact+1.16,clock))
	var planted_foot := Vector2(boss.facing*40.0,0)
	boss_art.rotation = boss.facing*.42*lean
	boss_art.position = planted_foot-planted_foot.rotated(boss_art.rotation)
	if clock >= strike_ground and clock-dt < strike_ground:
		arena.fatal_impact = Vector2(doom_hero_x-8.0*hero.facing,arena.FLOOR-2.0)
		sound.cue("shatter")
		camera.kick(6.4)
		effects.burst(arena.fatal_impact-Vector2(0,7),Color("#776671"),26,154,151,.64)
	if clock >= contact+.51:
		if not hero_art.released_weapon:
			released_from = hero_art.weapon_pivot.transform
			hero_art.released_weapon = true
		var slipping := smoothstep(contact+.51,contact+.96,clock)
		hero_art.weapon_pivot.transform = released_from.rotated_local(hero.facing*.23*slipping)
		hero_art.weapon_pivot.position += Vector2(9.0*hero.facing,17.0)*slipping
	if clock >= contact+1.16:
		begin_departure()

func start_awakening() -> void:
	boss.hide()
	boss.script_pose("idle")
	arena.gate_closed = 1.0
	sound.play_track("")
	transition_to(State.AWAKEN)

func reveal_final() -> void:
	journey.clear_enemies()
	arena.set_area("throne")
	select_boss(overlord)
	boss.reset()
	story.renderer.monster = overlord_art.imported.sprite_frames.get_frame_texture("idle",0) if overlord_art.imported else null
	boss.show()
	hero.position = Vector2(320,572)
	boss.position = Vector2(1135,572)
	boss.script_pose("walk")
	hero.script_pose("idle")
	camera.snap_path(640,1280)
	transition_to(State.FINAL_REVEAL)
	sound.play_track("boss_intro")

func enter_duel() -> void:
	journey.clear_enemies()
	arena.set_area("throne")
	select_boss(overlord)
	boss.reset()
	boss.show()
	hero.position = Vector2(436, 572)
	hero.velocity = Vector2.ZERO
	boss.position = Vector2(716, 572)
	hero.facing = 1.0
	boss.facing = -1.0
	hero.awakened = true
	hero.progression.refill()
	hero.iframe = 0.55
	desired_mood = 1.0
	enter_stage(1)

func enter_stage(stage: int) -> void:
	hero.enable()
	boss.enter_stage(stage)
	sound.play_track(DUEL_TRACKS[stage])
	desired_mood = [0.0,1.0,2.0,2.65][stage]
	transition_to(State.FIGHT)
	resolve_boss_phase()

func start_transition(stage: int) -> void:
	next_stage = stage
	boss.stage = stage
	hero.script_pose("idle")
	boss.script_pose("crown_break" if stage == 2 else "desperate")
	sound.cue("phase")
	pulse("violet", Color("#9764df"))
	camera.kick(5.0 if stage == 2 else 7.0)
	effects.burst(boss.position + Vector2(0,-152), Color("#c49af6"), 76, 222, 91, 1.23)
	desired_mood = 2.0 if stage == 2 else 2.65
	floor_fighters()
	sound.play_track("boss_transform", "boss_phase_2")
	transition_to(State.TRANSITION)

func begin_flash() -> void:
	if boss != overlord:
		return
	hero.progression.unlock_for(6)
	transition_to(State.FLASH_PREP)
	floor_fighters()
	hero.position.x = 398
	boss.position.x = 798
	hero.facing = 1.0
	boss.facing = -1.0
	hero.script_pose("final_prepare")
	boss.script_pose("final_attack")
	sound.play_track("final_flash", "")
	sound.cue("buildup")

func start_last_chance() -> void:
	transition_to(State.LAST_CHANCE)
	hero.enable()
	boss.script_pose("slam_wind")
	missed_wave = false
	sound.cue("tell")

func start_execution() -> void:
	if state != State.FLASH_OPEN or boss != overlord:
		return
	transition_to(State.EXECUTE)
	execute_from = hero.position
	execute_to = Vector2(boss.position.x + 167, 572)
	hero.script_pose("final_prepare", 1)
	boss.script_pose("final_attack", 1)
	slash_played = false
	shatter_played = false
	sound.play_track("")

func finish() -> void:
	if state != State.EXECUTE or boss != overlord or boss.health > 0 or curse_active:
		return
	curse_active = true
	ghost_clock = 0
	hero.script_pose("finish", 0.0)
	hero_art.released_weapon = false
	boss.script_pose("dissolve", 1.0)
	desired_mood = 3
	transition_to(State.EPILOGUE)
	story.begin(profile.get_value("story","ending",[]))

func soul_erasure() -> float:
	return 1.0 if state == State.VICTORY else smoothstep(CURSE_START+.55,HERO_GONE,clock)

func show_victory() -> void:
	story.stop()
	boss.hide()
	hero_art.set_body_opacity(0.0)
	hero_art.released_weapon = true
	arena.oath_stone = hero.position.x-32.0
	hero_art.weapon_pivot.transform = embedded_weapon_pose()
	arena.ending = true
	arena.fortress_fall = 1.0
	arena.dawn = .70
	transition_to(State.VICTORY)
	sound.play_track("victory")
	ui.show_panel("victory")

func tick_ending(dt: float) -> void:
	var previous := clock-dt
	arena.fortress_fall = smoothstep(.32,4.85,clock)
	for beat: Vector2 in [Vector2(.64,203),Vector2(1.69,1044),Vector2(2.77,645)]:
		if previous < beat.x and clock >= beat.x:
			sound.cue("shatter" if beat.x < 1.0 else "hit")
			camera.kick(3.4)
			effects.burst(Vector2(beat.y,543),Color("#827681"),23,138,-35,1.05)
	hero.visual_time += dt
	if clock < CURSE_START:
		hero.phase = smoothstep(.25,2.2,clock)
		if clock < 2.5:
			ghost_clock += dt
			if ghost_clock >= .16:
				ghost_clock = 0
				effects.burst(hero_art.weapon_pivot.global_position,Color("#ffca94"),3,23,-38,.55)
	else:
		if previous < CURSE_START:
			hero_art.released_weapon = true
			ending_weapon = hero_art.weapon_pivot.transform
			arena.oath_stone = hero.position.x-32.0
			sound.cue("awakening")
		var remaining := 1.0-smoothstep(CURSE_START,HERO_GONE,clock)
		hero_art.set_body_opacity(remaining)
		var entering_stone := smoothstep(HERO_GONE,SWORD_LANDS,clock)
		var lifted := ending_weapon
		lifted.origin.y = lerpf(ending_weapon.origin.y,-155.0,smoothstep(CURSE_START,HERO_GONE,clock))
		hero_art.weapon_pivot.transform = blend_weapon_pose(lifted,embedded_weapon_pose(),entering_stone)
		ghost_clock += dt
		if remaining > 0 and ghost_clock >= .095:
			ghost_clock = 0
			effects.burst(hero.position+Vector2(sin(clock*23.0)*29,-45),Color("#ffcc9b"),5,42,-18,.35)
	if clock >= SWORD_LANDS and previous < SWORD_LANDS:
		sound.cue("hit")
		camera.kick(2.2)
		effects.burst(Vector2(arena.oath_stone,540),Color("#a78c7d"),18,100,-29,.55)
	arena.dawn = smoothstep(SWORD_LANDS,NEXT_HEIR,clock)*.70
	if clock >= NEXT_HEIR:
		boss.hide()
		arena.ending = true
		if hero_art.imported:
			arena.heir_preview = hero_art.imported.sprite_frames
		arena.heir_progress = clock-NEXT_HEIR
	if story.advance(dt):
		show_victory()

func embedded_weapon_pose() -> Transform2D:
	var grip := Vector2(arena.oath_stone-hero.position.x,arena.oath_grip_y-hero.position.y)
	return Transform2D(0,Vector2(hero.facing,1)*hero_art.weapon_scale,0,grip)*Transform2D(PI,Vector2.ZERO)

func hero_died() -> void:
	if state == State.PROLOGUE:
		begin_doom()
	elif state in [State.APPROACH,State.FIGHT]:
		if not start_resurrection(false):
			transition_to(State.DEFEAT)
			hero.script_pose("death")
			boss.script_pose("idle")
			ui.show_panel("defeat")
			sound.cue("death")
			sound.play_track("")

func reversal_ready() -> bool:
	return can_resurrect(true)

func can_resurrect(voluntary: bool) -> bool:
	if curse_active or state not in [State.APPROACH, State.FIGHT] or hero.progression.charges <= 0:
		return false
	if voluntary:
		return hero.health > 0 and powers.ready(hero,"reversal")
	return hero.health == 0 and hero.progression.has("resurrection")

func start_resurrection(voluntary: bool) -> bool:
	if not can_resurrect(voluntary):
		return false
	resume_state = state
	reversal = voluntary
	hero.progression.charges -= 1
	if reversal:
		hero.energy = 0
		powers.cooldowns["reversal"] = float(profile.get_value("resurrection","reversal_cooldown",25.0))
	transition_to(State.RESURRECTING)
	fallen_from = hero.position
	hero.health = 0
	hero.script_pose("reversal" if reversal else "death")
	if is_instance_valid(boss) and boss.visible:
		boss.script_pose("idle")
	effects.clear()
	resurrection_flash_pending = true
	sound.cue("buildup" if reversal else "death")
	sound.play_track("resurrection", "")
	return true

func release_reversal() -> void:
	var radius := float(profile.get_value("resurrection","reversal_radius",190.0))
	var damage := int(profile.get_value("resurrection","reversal_damage",48))
	var box := Rect2(hero.position-Vector2(radius,116),Vector2(radius*2,124))
	hero.strike_id += 1
	var strike = Strike.new(box,damage,hero.facing,false,"reversal",hero.strike_id)
	if resume_state == State.APPROACH:
		journey.strike_enemies(strike)
	elif boss.hurtbox().intersects(box):
		strike.direction = signf(boss.position.x - hero.position.x)
		boss.receive(strike)
		if state == State.FIGHT:
			boss.position.x = clampf(boss.position.x + strike.direction*116.0,boss.limits.x,boss.limits.y)
			boss.staggered()
	camera.kick(9.0)
	effects.burst(hero.position+Vector2(0,-44),Color("#ffecdf"),93,382,23,1.15)

func tick_resurrection() -> void:
	var duration := resurrection_duration()
	var progress := clampf(clock / duration,0,1)
	hero.position.y = lerpf(fallen_from.y,572,smoothstep(0.0,.48,progress))
	hero.phase = smoothstep(0,.31,progress)
	var restore_at := clampf(float(profile.get_value("resurrection", "return_time", .78)) / duration, .54, .87)
	if progress >= restore_at:
		if resurrection_flash_pending:
			resurrection_flash_pending = false
			pulse("white" if reversal else "crimson", Color("#fff5db") if reversal else Color("#ff5979"))
			sound.cue("awakening")
			effects.burst(hero.position + Vector2(0,-20),Color("#ff6284"),46,205,-5,.67)
		hero.pose = "resurrect"
		hero.phase = smoothstep(restore_at,1,progress)
	if progress >= 1.0:
		hero.progression.resurrect()
		hero.iframe = maxf(0, float(profile.get_value("resurrection", "invulnerability", 1.25)))
		hero.dash_cd = 0
		hero.parry_cd = 0
		hero.enable()
		boss.idle()
		boss.clock = -.26
		transition_to(resume_state)
		if reversal:
			release_reversal()
		resolve_boss_phase()
		if state == State.FIGHT:
			sound.play_track("sovereign_duel" if side_encounter() else DUEL_TRACKS[boss.stage])
		elif state == State.APPROACH:
			sound.play_track(journey.music_encounter if not journey.music_encounter.is_empty() else journey.MUSIC[arena.area],"")

func set_paused(value: bool) -> void:
	paused = value
	get_tree().paused = value
	ui.story_movie.paused = value
	if value:
		clear_flash()
		ui.show_panel("pause")
	elif ui.menu_name in ["pause", "audio"]:
		ui.show_panel("")

func command(action: String) -> void:
	match action:
		"begin":
			begin()
		"controls", "audio":
			ui.show_panel(action)
		"pause":
			set_paused(true)
		"resume":
			set_paused(false)
		"title":
			to_title()
		"retry":
			if curse_active:
				return
			set_paused(false)
			if journey.checkpoint_area.is_empty():
				begin()
			else:
				ui.show_panel("")
				story.stop()
				clear_flash()
				effects.clear()
				hero_art.set_body_opacity(1.0)
				hero_art.released_weapon = false
				journey.retry()
		"quit":
			quit_game()
	sound.cue("confirm")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()

func quit_game() -> void:
	if quitting:
		return
	quitting = true
	story.stop()
	sound.stop_all()
	# Let the audio mixer release stopped streams before engine shutdown.
	await get_tree().create_timer(.10,true).timeout
	get_tree().quit()

func _input(event: InputEvent) -> void:
	if not is_node_ready() or quitting:
		return
	if event.is_action_pressed("pause", false):
		if ui.menu_name == "controls":
			ui.show_panel("title")
		elif ui.menu_name == "audio":
			ui.show_panel("title" if state == State.TITLE else "pause")
		elif paused:
			set_paused(false)
		elif state not in [State.TITLE, State.DEFEAT, State.VICTORY]:
			set_paused(true)
		get_viewport().set_input_as_handled()
		return
	if paused or (state == State.TITLE and not debug_enabled):
		return
	if event.is_action_pressed("retry", false) and state == State.DEFEAT:
		command("retry")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("confirm", false) and skip_cinematic():
		get_viewport().set_input_as_handled()
		return
	if state in [State.APPROACH,State.FIGHT]:
		for ability: String in ["phantom","sever"]:
			if event.is_action_pressed(ability,false):
				powers.use(self,ability)
	if event.is_action_pressed("reversal", false):
		start_resurrection(true)
	if event.is_action_pressed("flash", false) and state == State.FLASH_OPEN:
		start_execution()
	if debug_enabled and event is InputEventKey and event.pressed and not event.echo:
		debug_key(event.physical_keycode)

func skip_cinematic() -> bool:
	match state:
		State.MEMORIAL:
			finish_side_defeat()
		State.UNLOCK:
			finish_unlock()
		State.CHALLENGER:
			start_side_fight()
		State.VILLAGE:
			reveal()
		State.REVEAL:
			start_prologue()
		State.DOOM:
			begin_departure()
		State.DEPARTURE:
			start_awakening()
		State.AWAKEN:
			wake_in_courtyard()
		State.FINAL_REVEAL:
			enter_duel()
		State.EPILOGUE:
			show_victory()
		State.TRANSITION:
			enter_stage(next_stage)
		State.RESURRECTING:
			clock = resurrection_duration()
		State.EXECUTE:
			clock = timing("final_victory")
		_:
			return false
	return true

func _physics_process(dt: float) -> void:
	if paused:
		return
	clock += dt
	parry_notice = maxf(0,parry_notice-dt)
	match state:
		State.TITLE:
			hero.visual_time += dt
			boss.visual_time += dt
		State.PROLOGUE, State.APPROACH, State.FIGHT:
			tick_play(dt)
		State.VILLAGE:
			hero.read_controls(dt)
			hero.simulate(dt)
			if hero.position.x >= 338:
				reveal()
		State.UNLOCK:
			tick_unlock(dt)
		State.CHALLENGER:
			hero.visual_time += dt
			boss.visual_time += dt
			if clock >= 2.8:
				start_side_fight()
		State.MEMORIAL:
			tick_side_defeat(dt)
		State.REVEAL:
			tick_reveal(dt)
		State.FINAL_REVEAL:
			boss.visual_time += dt
			boss.position.x = lerpf(1135,850,smoothstep(.22,2.2,clock))
			if clock >= 2.2:
				boss.pose = "cleave_wind"
				boss.phase = smoothstep(3.3,5.2,clock)
				hero.pose = "draw_blade"
				hero.phase = smoothstep(3.0,4.9,clock)
			if clock >= 3.0 and clock-dt < 3.0:
				sound.cue("draw")
			if clock >= 5.2:
				enter_duel()
		State.EPILOGUE:
			tick_ending(dt)
		State.DOOM:
			tick_doom(dt)
		State.DEPARTURE:
			hero.phase = maxf(hero.phase,clampf(clock / .63,0,1))
			if clock <= 1.65:
				boss.phase = smoothstep(0,.45,clock)
			hero.position.y = lerpf(fallen_from.y,572,smoothstep(0,.58,clock))
			tick_falling_weapon()
			boss.visual_time += dt
			var leave := clampf((clock - 1.65) / timing("walk_away"),0,1)
			if leave > 0.0:
				boss.pose = "walk"
				boss.facing = 1.0
				boss.position.x = lerpf(departure_origin,arena.area_width + 75.0,leave)
			if leave >= 1.0:
				boss.hide()
				arena.gate_closed = smoothstep(0,.65,clock - 1.65 - timing("walk_away"))
			if leave >= 1.0 and arena.gate_closed >= 1.0:
				start_awakening()
		State.AWAKEN:
			tick_awakening(dt)
		State.RESURRECTING:
			tick_resurrection()
		State.TRANSITION:
			boss.phase = clampf(clock / timing("transition"),0,1)
			hero.visual_time += dt
			boss.visual_time += dt
			if clock >= timing("transition"):
				enter_stage(next_stage)
		State.FLASH_PREP:
			hero.visual_time += dt
			boss.visual_time += dt * .23
			hero.phase = clampf(clock / timing("final_anticipation"),0,1)
			boss.phase = hero.phase * .87
			if clock >= timing("final_anticipation"):
				transition_to(State.FLASH_OPEN)
				sound.cue("tell")
		State.FLASH_OPEN:
			var p := clampf(clock / timing("final_window"),0,1)
			boss.position.x = lerpf(798, 704, p)
			boss.pose = "rush"
			boss.phase = .87 + .13 * p
			hero.visual_time += dt
			if p >= 1.0:
				start_last_chance()
		State.LAST_CHANCE:
			tick_last_chance(dt)
		State.EXECUTE:
			tick_execution(dt)
		State.VICTORY:
			hero.visual_time += dt
		State.DEFEAT:
			hero.phase = clampf(clock / .63,0,1)
			boss.visual_time += dt

func tick_reveal(dt: float) -> void:
	hero.visual_time += dt
	boss.visual_time += dt
	if clock < 1.25:
		hero.position.x = lerpf(338,410,smoothstep(0,1.25,clock))
		hero.pose = "run"
	elif clock < 2.65:
		hero.pose = "draw_blade"
		hero.phase = smoothstep(1.3,2.65,clock)
		if clock-dt < 1.3 and clock >= 1.3:
			sound.cue("draw")
		boss.pose = "cleave_wind"
		boss.phase = hero.phase
	elif clock < 3.46:
		hero.pose = "intro_slash"
		hero.phase = smoothstep(2.65,3.37,clock)
		boss.pose = "cleave"
		boss.phase = hero.phase
		var lunge := smoothstep(2.65,3.23,clock)
		hero.position.x = lerpf(410,567,lunge)
		boss.position.x = lerpf(964,724,lunge)
		if clock-dt < 3.23 and clock >= 3.23:
			camera.kick(7.0)
			effects.arc(hero.position+Vector2(30,-44),1,115,Color("#fff1c9"))
			pulse("white",Color("#ffe8c6"))
			effects.burst(Vector2(628,503),Color("#ffe8a2"),40,295,181,.49)
			sound.cue("parry")
	else:
		hero.pose = "knockback" if clock < 4.08 else "idle"
		hero.phase = smoothstep(3.46,4.08,clock)
		boss.pose = "cleave_recover"
		boss.phase = smoothstep(3.45,4.55,clock)
		hero.position.x = lerpf(567,286,smoothstep(3.46,4.10,clock))
		boss.position.x = lerpf(724,964,smoothstep(3.46,4.24,clock))
	if clock >= 5.4:
		start_prologue()

func tick_play(dt: float) -> void:
	update_health_cues(dt)
	var active := state
	if active != State.PROLOGUE and stop_time <= 0.0:
		powers.tick(self,dt)
		if state != active:
			return
	hero.read_controls(dt)
	if active == State.FIGHT:
		fight_time += dt
	if stop_time > 0:
		stop_time -= dt
		return
	hero.simulate(dt)
	if state != active:
		return
	if active == State.APPROACH:
		journey.tick(dt)
		return
	boss.simulate(dt, hero.position)
	if state != active:
		return
	separate_fighters(dt)
	if state == State.PROLOGUE and (hero.health <= hero.maximum * .30 or boss.health <= boss.encounter_floor):
		begin_doom()
	resolve_boss_phase()

func resolve_boss_phase() -> void:
	if state != State.FIGHT:
		return
	if side_encounter():
		if boss.health == 0:
			defeat_side_boss()
		return
	if boss != overlord:
		return
	var ratio: float = float(boss.health) / boss.maximum
	if boss.stage == 1 and ratio <= float(boss.profile.get_value("phases", "two")):
		start_transition(2)
	elif boss.stage == 2 and ratio <= float(boss.profile.get_value("phases", "three")):
		start_transition(3)
	elif boss.stage == 3 and boss.health <= boss.execution_health():
		begin_flash()

func separate_fighters(dt: float) -> void:
	if hero.mode == hero.Mode.DASH or (boss.attack == "rush" and boss.mode == boss.Mode.ACTIVE):
		return
	var x: float = hero.position.x - boss.position.x
	if absf(x) >= 44.0 or hero.position.y + 2.0 < boss.position.y - boss.body_size.y:
		return
	var side: float = signf(x) if absf(x) > .5 else -boss.facing
	var free := clampf(boss.position.x + side*44.0,boss.limits.x-14,boss.limits.y+14)
	hero.position.x = move_toward(hero.position.x, free, dt * 480)
	if absf(free - boss.position.x) < 40.0:
		boss.position.x = move_toward(boss.position.x, free - side * 46.0, dt * 300)

func floor_fighters() -> void:
	hero.position.y = 572
	boss.position.y = 572

func blend_weapon_pose(from: Transform2D, to: Transform2D, amount: float) -> Transform2D:
	var side: float = hero.facing
	var mirror := Transform2D(0,Vector2(side,1),0,Vector2.ZERO)
	return mirror*((mirror*from).interpolate_with(mirror*to,amount))

func tick_falling_weapon() -> void:
	var fall := clampf(clock/.53,0.0,1.0)
	var target := fallen_weapon
	target.origin.y = 563.0-hero.position.y
	hero_art.weapon_pivot.transform = blend_weapon_pose(released_from,target,fall)
	hero_art.weapon_pivot.position.y -= sin(fall*PI)*15.0

func tick_awakening(dt: float) -> void:
	var flash_at := timing("awakening_flash")
	var departure := timing("soul_departure")
	if clock >= departure and not story_movie_attempted:
		story_movie_attempted = true
		if ui.play_story_movie():
			clock = departure
			return
	if ui.story_movie_backdrop.visible:
		story_movie_elapsed += dt
		# Some Theora files hold their last frame without emitting finished.
		if ui.story_movie.stream_position >= timing("story_video_end") \
				or story_movie_elapsed >= timing("story_video_timeout"):
			ui.stop_story_movie()
		clock = departure
		return
	if clock >= departure and clock - dt <= departure:
		sound.play_track("between","")
	if clock >= timing("soul_return") and clock - dt < timing("soul_return"):
		sound.play_track("resurrection", "")
	hero.phase = clampf(clock / .63,0,1)
	boss.phase = clampf(clock / .95,0,1)
	hero.position.y = lerpf(fallen_from.y, 572, smoothstep(0.0, .58, clock))
	if clock >= flash_at:
		if not awakening_played:
			awakening_played = true
			hero.awakened = true
			hero.health = hero.maximum
			pulse("crimson",Color("#ff5979"))
			sound.cue("awakening")
			effects.burst(hero.position + Vector2(0,-18),Color("#ff547b"),119,365,-20,1.47)
			camera.kick(8.6)
			desired_mood = 1
		hero.pose = "resurrect"
		hero.phase = smoothstep(flash_at, flash_at + 1.38, clock)
	if clock >= timing("awakening_total"):
		wake_in_courtyard()

func tick_last_chance(dt: float) -> void:
	fight_time += dt
	hero.read_controls(dt)
	hero.simulate(dt)
	boss.phase = clampf(clock / .80,0,1)
	if clock >= .8:
		boss.pose = "slam"
		boss.phase = smoothstep(.8, 1.2, clock)
		var x: float = boss.position.x - (clock - .8) * 482
		if clock - dt < .8:
			sound.cue("slam")
			camera.kick(4.5)
			effects.burst(boss.position,Color("#be8df9"),25,175)
		if not missed_wave and clock < timing("final_retry") - .35:
			var wave := Strike.new(Rect2(x-27,545,54,32), mini(11,hero.health-1), -1,false, "last_chance",-1)
			if wave.damage > 0 and not hero.defend(wave).is_empty():
				missed_wave = true
	if clock >= timing("final_retry"):
		begin_flash()

func tick_execution(dt: float) -> void:
	var release := timing("final_freeze")
	var slash := timing("final_slash")
	var shatter := timing("final_shatter")
	if clock >= release and not slash_played:
		slash_played = true
		sound.cue("final")
		pulse("white", Color("#fff4e8"))
	if clock >= release and clock < slash:
		hero.pose = "final_dash"
		hero.phase = clampf((clock - release) / (slash - release),0,1)
		hero.position = execute_from.lerp(execute_to,hero.phase)
		effects.ghost(hero.position, 1, Color("#fff2e3"),1.4)
	elif clock >= slash:
		hero.position = execute_to
		hero.facing = -1
		hero.pose = "final_strike" if clock < slash + .09 else "finish"
		hero.phase = .75 if hero.pose == "final_strike" else smoothstep(shatter + .6, shatter + 2.6, clock)
		boss.pose = "execution_hit"
		boss.phase = 0.1
	if clock >= shatter:
		boss.pose = "dissolve"
		boss.phase = clampf((clock - shatter) / .8,0,1)
		if not shatter_played:
			shatter_played = true
			boss.health = 0
			sound.cue("shatter")
			camera.kick(timing("final_shake"))
			pulse("dust",Color("#fbd3f4"))
			effects.burst(boss.position + Vector2(0,-98), Color("#826797"), 161, 395, 72, 1.84)
			effects.burst(boss.position + Vector2(0,-83), Color("#ffe2cf"), 90, 277, -142, 2.0)
			desired_mood = 3
		ghost_clock += dt
		if ghost_clock >= .11:
			ghost_clock = 0
			effects.burst(boss.position + Vector2(sin(clock*28)*52,-90),Color("#ffd6b9"),3,72,-145,1.27)
	if clock >= timing("final_victory"):
		finish()

func _process(dt: float) -> void:
	if paused:
		return
	ui.refresh(dt)
	elapsed += dt
	effects.tick(dt)
	sound.tick(dt)
	var focus := 640.0
	var zoom_level := 1.0
	var shade := 0.0
	match state:
		State.TITLE:
			shade = .32
		State.AWAKEN:
			focus = hero.position.x
			zoom_level = 1.10
			shade = .45 * smoothstep(.55, 2.3, clock) * (1.0-smoothstep(4.6,5.4,clock))
		State.TRANSITION:
			focus = boss.position.x
			zoom_level = 1.0 + .095*sin(clampf(clock/timing("transition"),0,1)*PI)
		State.FLASH_PREP, State.FLASH_OPEN:
			zoom_level = timing("final_zoom")
			shade = .68
		State.EXECUTE:
			focus = (hero.position.x + boss.position.x) * .5
			zoom_level = lerpf(timing("final_zoom"),1.0,smoothstep(1.4,3.8,clock))
			shade = .69 * (1.0-smoothstep(1.4,2.6,clock))
		State.VICTORY:
			focus = hero.position.x
			zoom_level = 1.065
	if state == State.FLASH_PREP and clock < 1.02:
		camera.focus_actor(dt,hero.position+Vector2(10,-74),2.85)
	elif state == State.MEMORIAL:
		camera.focus_actor(dt,hero.position+Vector2(34,-64),1.28)
	elif state == State.EPILOGUE:
		var close := smoothstep(4.0,9.5,clock)*(1.0-smoothstep(15.2,21.5,clock))
		camera.focus_actor(dt,Vector2(hero.position.x-26,479),1.1+close*.59)
	elif state == State.DOOM:
		camera.focus_actor(dt,(hero.position+boss.position)*.5+Vector2(0,-72),1.37)
	elif state == State.CHALLENGER:
		camera.focus_actor(dt,boss.position+Vector2(-95,-95),1.22)
	elif side_encounter() and state in [State.FIGHT,State.RESURRECTING,State.DEFEAT]:
		camera.follow_path(dt,(hero.position.x+boss.position.x)*.5-145,arena.area_width)
	elif state == State.UNLOCK:
		camera.focus_actor(dt,hero.position+Vector2(0,-40),1.0+.72*sin(clampf(clock/1.75,0,1)*PI))
	elif state in [State.APPROACH, State.VILLAGE] or (state == State.RESURRECTING and resume_state == State.APPROACH):
		camera.follow_path(dt, hero.position.x, arena.area_width)
	elif state == State.REVEAL:
		if clock >= 1.25 and clock < 1.97:
			camera.focus_actor(dt,hero.position+Vector2(17,-76),2.12)
		elif clock >= 1.97 and clock < 2.65:
			camera.focus_actor(dt,boss.position+Vector2(-42,-66),1.58)
		else:
			camera.update_frame(dt,hero.position,boss.position,640.0,1.0,0.0)
	else:
		camera.update_frame(dt, hero.position, boss.position, focus, zoom_level, hero.velocity.x * .12)
	arena.mood = move_toward(arena.mood, desired_mood, dt * .78)
	arena.shade = move_toward(arena.shade, shade, dt * 1.42)
	arena.time += dt * (.28 if state in [State.FLASH_PREP, State.FLASH_OPEN] else 1.0)
	arena.parallax = camera.position.x - 640.0
	arena.queue_redraw()
	hero_art.redraw()
	if state == State.AWAKEN and hero_art.released_weapon:
		if clock >= timing("awakening_flash")+1.08:
			hero_art.released_weapon = false
			hero_art.weapon_pivot.transform = hero_art.hand_transform()
		else:
			var returning := smoothstep(timing("awakening_flash")-.46,timing("awakening_flash")+1.08,clock)
			var resting := fallen_weapon
			resting.origin.y = 563.0-hero.position.y
			hero_art.weapon_pivot.transform = blend_weapon_pose(resting,hero_art.hand_transform(),returning)
	if boss.visible:
		boss_art.redraw()
	if is_fight():
		ghost_clock += dt
		if ghost_clock >= .045:
			ghost_clock = 0
			if hero.mode == hero.Mode.DASH:
				effects.ghost(hero.position, hero.facing, hero_art.palette.awakened if hero.awakened else Color("#9faccd"))
			if boss.mode == boss.Mode.ACTIVE and boss.attack == "rush":
				effects.ghost(boss.position, boss.facing, Color("#9669ed"), 2.2)
			if boss.stage >= 2:
				effects.burst(boss.position + Vector2(sin(elapsed*15)*31,-96),Color("#b38eec"),2,56,-85,.68)

func hero_strike(strike) -> void:
	effects.show_box(strike.box)
	powers.capture_echo(hero,strike)
	if state == State.APPROACH:
		journey.strike_enemies(strike)
	elif is_fight() and boss.receive(strike):
		land_player_hit(boss.position,strike)
		resolve_boss_phase()

func land_player_hit(at: Vector2,strike) -> void:
	if strike.source != "reversal":
		hero.energy += 10.0 if hero.resurrection_level >= 4 else 8.0
		stop_time = .045 if strike.damage > 29 else .030
	if strike.source != "reversal":
		effects.bleed(at+Vector2(0,-51),strike.direction)
	var color := Color("#ffa2b0") if hero.awakened else Color("#d0c0ee")
	effects.burst(at + Vector2(-strike.direction * 19,-58),color,20,235)
	sound.cue("hit")

func reward_parry(perfect: bool = false) -> void:
	parries += 1
	if perfect:
		parry_notice = .75
	stop_time = .10 if perfect else .07
	camera.kick(4)
	pulse("dust",Color("#ffd092"))

func boss_strike(strike, attacker = null) -> void:
	if is_fight() and (attacker == null or attacker == boss):
		enemy_strike(strike,boss)
		resolve_boss_phase()

func enemy_strike(strike, attacker) -> void:
	if attacker.consumed_strike == strike.id:
		return
	effects.show_box(strike.box)
	if state == State.PROLOGUE:
		strike.damage = minf(strike.damage, hero.health - 1)
	if strike.damage <= 0.0:
		return
	var result: String = hero.defend(strike)
	if result.is_empty():
		return
	attacker.consumed_strike = strike.id
	if result in ["parry","perfect_parry"]:
		var perfect := result == "perfect_parry"
		reward_parry(perfect)
		attacker.repelled(hero.progression.critical_multiplier if perfect else 1.0)

func hero_cue(name: String, at: Vector2) -> void:
	match name:
		"sever":
			powers.launch_sever(hero)
			sound.cue("swing")
			effects.arc(at,hero.facing,86,Powers.COLORS.sever)
		"phantom":
			sound.cue("dash")
			var crimson := Color("#f34c68")
			effects.ghost(at,hero.facing,crimson,1.2)
			effects.blade_echo(hero_art.weapon_pivot.global_transform,crimson,Vector2(-hero.facing*16,0))
			effects.burst(at+Vector2(0,-30),crimson,24,135,28,.44)
		"swing":
			sound.cue("swing")
			var color: Color = hero_art.palette.awakened if hero.awakened else Color("#b4bbd6")
			if hero.resurrection_level >= 5:
				effects.burst(at,Color("#ffd3c9"),10,122,-35,.42)
			var attack: Dictionary = hero.strike_data
			effects.arc(at,hero.facing,float(attack.reach)-31.0,color,attack.name == "light_2",hero.awakened)
		"dash":
			sound.cue("dash")
			effects.ghost(at,hero.facing,Color("#db81a0"))
			effects.burst(at,Color("#8d748b"),11,145,70)
		"parry":
			sound.cue("parry")
			effects.burst(at,Color("#ffdcab"),43,275,290,.66)
			effects.arc(at,hero.facing,53,Color("#ffe5b3"),false,hero.awakened)
		"guard":
			effects.burst(at,Color("#efcaa7"),8,120,213,.24)
		"hurt":
			sound.cue("hit")
			effects.burst(at,Color("#e46e91"),17,190)
			camera.kick(2.4)
		"jump","land":
			sound.cue(name)
			effects.burst(at+Vector2(0,-3),Color("#8b738f"),8 if name=="jump" else 14,102,92,.33)

func boss_warning(_name: String) -> void:
	sound.cue("tell")

func boss_impact(name: String, at: Vector2) -> void:
	var color := Color("#ff854d") if boss == overlord else Color("#b68cf3")
	if name in ["throne", "cleave", "rush", "teleport"]:
		if boss_art.animation_for(name).is_empty():
			effects.arc(at+Vector2(22*boss.facing,-83),boss.facing,141 if name == "throne" else 124,color,boss.emitted==1)
		else:
			effects.burst(at+Vector2(100*boss.facing,-81),color,11,162,55,.3)
		sound.cue("swing")
		camera.kick(3.7 if name == "throne" else 2.6)
	else:
		sound.cue("phase" if boss == overlord else "hit")
		camera.kick(5.4 if name=="slam" else 3.1)
		if name=="ruin":
			for x: float in boss.marks:
				effects.burst(Vector2(x,565),color,13,212,138,.52)
		else:
			effects.burst(at-Vector2(0,6),color,37,172,129,.66)

func debug_key(key: int) -> void:
	match key:
		KEY_F1:
			if state in [State.TITLE, State.VILLAGE, State.REVEAL, State.APPROACH, State.MEMORIAL]:
				clean()
				ui.show_panel("")
				start_prologue()
		KEY_F2:
			clean()
			ui.show_panel("")
			hero.position = Vector2(436,572)
			boss.position = Vector2(797,572)
			begin_departure()
		KEY_F3, KEY_F4, KEY_F6:
			ui.show_panel("")
			story.stop()
			powers.clear_attacks()
			journey.save_checkpoint("throne",270,true)
			enter_duel()
			if key == KEY_F6:
				boss.stage = 3
				boss.health = boss.execution_health()
				begin_flash()
			else:
				var phase_key := "two" if key == KEY_F3 else "three"
				boss.health = floori(boss.maximum * float(boss.profile.get_value("phases",phase_key)))
				start_transition(2 if key == KEY_F3 else 3)
		KEY_F5:
			hero.energy = hero.progression.energy_limit
		KEY_F7:
			hero.health = hero.maximum if hero.health == 1 else 1
		KEY_F8:
			boss.health = boss.maximum if boss.health == 1 else 1
		KEY_F9:
			effects.debug = not effects.debug
