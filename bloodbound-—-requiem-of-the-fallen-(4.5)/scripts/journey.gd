extends Node

const ENEMY = preload("res://scenes/Enemy.tscn")
const PLACEMENTS := {
	"road": [["road_ditch", "shadow", 735], ["road_bridge", "shadow", 1430], ["warden", "warden", 2330]],
	"shrine": [["shrine_steps", "shadow", 720], ["spirit", "spirit", 1920]],
	"underworld": [["gate_shadow","shadow",600],["guardian","guardian",1510]],
	"frozen": [["snow_shadow","shadow",635],["rival","rival",1630]]
}
const NAMES := {"courtyard":"THE FALLEN COURTYARD", "road":"THE ASHEN ROAD",
	"shrine":"THE SHRINE OF FADING NAMES","underworld":"THE UNDERWORLD GATE",
	"frozen":"FROZEN OATH", "throne":"THE THRONE OF THE ECLIPSE"}
const AREAS := ["courtyard","road","shrine","underworld","frozen","throne"]
const GATEKEEPERS := {"road":"warden","shrine":"spirit","underworld":"guardian","frozen":"rival"}
const MUSIC := {"courtyard":"ashen_path","road":"ashen_path","shrine":"shrine","underworld":"underworld","frozen":"frozen"}

var game
var enemies: Array[CharacterBody2D] = []
var defeated: Dictionary = {}
var consumed: Dictionary = {}
var checkpoint_area := ""
var checkpoint_x := 0.0
var checkpoint_stats: Dictionary = {}
var checkpoint_defeated: Dictionary = {}
var intro_seen: Dictionary = {}
var reversal_unlocked: bool:
	get: return game.hero.progression.has("reversal")
var notice := ""
var notice_time := 0.0
var tell := ""
var tell_cue := ""
var tell_time := 0.0
var music_encounter := ""

func clear_enemies() -> void:
	for enemy in enemies:
		enemy.hide()
		enemy.queue_free()
	enemies.clear()
	consumed.clear()
	tell_time = 0
	music_encounter = ""

func reset() -> void:
	clear_enemies()
	defeated.clear()
	checkpoint_area = ""
	checkpoint_x = 0
	checkpoint_stats.clear()
	checkpoint_defeated.clear()
	intro_seen.clear()
	notice_time = 0

func enter(area: String, x: float = -1.0) -> void:
	clear_enemies()
	game.arena.set_area(area)
	game.hero.progression.enter_level(AREAS.find(area)+1)
	game.boss.hide()
	game.effects.clear()
	game.hero.position = game.arena.spawn_point if x < 0 else Vector2(x,572)
	game.hero.facing = 1.0
	game.hero.enable()
	game.camera.snap_path(game.hero.position.x, game.arena.area_width)
	game.transition_to(game.State.APPROACH)
	game.desired_mood = .69
	game.sound.play_track(MUSIC[area])
	for placement: Array in PLACEMENTS.get(area, []):
		if defeated.has(placement[0]):
			continue
		var enemy = ENEMY.instantiate()
		enemy.position = Vector2(placement[2],572)
		add_child(enemy)
		enemy.setup(placement[1])
		enemy.route_id = placement[0]
		enemy.limits = Vector2(maxf(110,placement[2]-350), minf(game.arena.exit_x-42,placement[2]+285))
		enemy.swung.connect(on_enemy_strike.bind(enemy))
		enemy.telegraph.connect(on_tell)
		enemy.defeated.connect(on_defeated)
		enemy.transformed.connect(func(unit): game.show_challenger(unit,true))
		enemies.append(enemy)
	game.arena.set_exit_open(enemy_count() == 0)
	if area == "courtyard":
		game.arena.gate_closed = 1.0
	announce(NAMES[area], 3.3)

func announce(value: String, duration: float = 3.4) -> void:
	notice = value
	notice_time = duration

func save_checkpoint(area: String, x: float, refill: bool = false) -> void:
	checkpoint_area = area
	checkpoint_x = x
	if refill:
		game.hero.progression.refill()
	checkpoint_stats = game.hero.progression.snapshot()
	checkpoint_defeated = defeated.duplicate()

func retry() -> void:
	game.hero.progression.restore(checkpoint_stats)
	defeated = checkpoint_defeated.duplicate()
	game.hero.iframe = .85
	game.hero.dash_cd = 0
	game.hero.parry_cd = 0
	game.reset_powers()
	if checkpoint_area == "throne":
		game.enter_duel()
	else:
		enter(checkpoint_area, checkpoint_x)

func enemy_count() -> int:
	var count := 0
	for enemy in enemies:
		if not enemy.dead:
			count += 1
	return count

func miniboss():
	for enemy in enemies:
		if enemy.kind != "shadow" and not enemy.dead and absf(enemy.position.x-game.hero.position.x) < 690:
			return enemy
	return null

func tick(dt: float) -> void:
	notice_time = maxf(0, notice_time-dt)
	tell_time = maxf(0, tell_time-dt)
	for enemy in enemies:
		enemy.simulate(dt, game.hero.position)
		if game.state != game.State.APPROACH:
			return
	if game.arena.area == "courtyard" and game.hero.position.x >= 970.0:
		game.arena.gate_closed = move_toward(game.arena.gate_closed,0.0,dt * 2.3)
	var challenger = miniboss()
	if challenger and music_encounter != challenger.kind:
		music_encounter = challenger.kind
		game.sound.play_track(music_encounter,"boss_phase_1")
		if not intro_seen.has(challenger.route_id):
			intro_seen[challenger.route_id] = true
			game.show_challenger(challenger,false)
			return
	if game.arena.area == "shrine" and game.hero.position.x >= 1440 and checkpoint_x < 1440 and not defeated.has("spirit"):
		save_checkpoint("shrine", 1450, true)
		announce("SHRINE CHECKPOINT")
	if game.hero.position.x < game.arena.exit_x or enemy_count() > 0:
		return
	var next: String = AREAS[AREAS.find(game.arena.area)+1]
	if next == "throne":
		game.hero.progression.enter_level(6)
		save_checkpoint("throne",270,true)
		game.reveal_final()
	else:
		enter(next)
		save_checkpoint(next,180,true)

func strike_enemies(strike) -> void:
	for enemy in enemies:
		if strike.source == "reversal":
			strike.direction = signf(enemy.position.x-game.hero.position.x)
		if enemy.receive(strike):
			game.land_player_hit(enemy.position, strike)
			if game.state not in [game.State.APPROACH, game.State.RESURRECTING]:
				break

func interrupt() -> void:
	for enemy in enemies:
		enemy.interrupt()
	tell_time = 0

func on_enemy_strike(strike, enemy) -> void:
	if game.state != game.State.APPROACH or consumed.get(enemy, -1) == strike.id:
		return
	game.effects.show_box(strike.box)
	var result: String = game.hero.defend(strike)
	if result.is_empty():
		return
	consumed[enemy] = strike.id
	if result in ["parry","perfect_parry"]:
		var perfect := result == "perfect_parry"
		game.reward_parry(perfect)
		enemy.repelled(game.hero.progression.critical_multiplier if perfect else 1.0)

func on_tell(label: String, cue: String) -> void:
	tell = label
	tell_cue = cue
	tell_time = .93
	game.sound.cue("tell")

func on_defeated(enemy) -> void:
	defeated[enemy.route_id] = true
	game.morality_score += 1
	game.effects.burst(enemy.position + Vector2(0,-42),enemy.accent,35,165,31,.69)
	if enemy_count() == 0:
		game.arena.set_exit_open(true)
	if enemy.kind == "spirit":
		interrupt()
		game.show_memorial()
	elif GATEKEEPERS.get(game.arena.area,"") == enemy.kind:
		var area: String = game.arena.area
		game.sound.play_track(MUSIC[area])
		game.level_reward(AREAS.find(area)+1,area,game.arena.exit_x-220.0)

