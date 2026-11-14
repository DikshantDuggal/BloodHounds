extends Node

const ENEMY = preload("res://scenes/Enemy.tscn")
const Strike = preload("res://scripts/strike.gd")
const PLACEMENTS := {
	"road": [["forest_hunter","hunter",1920]],
	"frozen": [["hunter","hunter",1000],["brute","brute",1320]]
}
const NAMES := {"courtyard":"THE FALLEN COURTYARD","road":"THE ASHEN FOREST",
	"shrine":"THE SHRINE OF FADING NAMES","underworld":"MOONLIT PASS",
	"frozen":"THE WOLVES' GATE","throne":"THE ECLIPSE FORTRESS"}
const AREAS := ["courtyard","road","shrine","underworld","frozen","throne"]
const ACTS := ["I  MORNING  ·  THE FALLEN HEIR","II  AFTERNOON  ·  THE ASHEN HUNT","III  NIGHT  ·  THE ECLIPSE HUNT"]
const MUSIC := {"courtyard":"ashen_path","road":"ashen_path","shrine":"shrine","underworld":"underworld","frozen":"frozen"}
const CHECKPOINTS := {"road":1290.0,"shrine":712.0,"underworld":1175.0}

var game
var enemies: Array[CharacterBody2D] = []
var defeated: Dictionary = {}
var checkpoint_area := ""
var checkpoint_x := 0.0
var checkpoint_stats: Dictionary = {}
var checkpoint_defeated: Dictionary = {}
var intro_seen: Dictionary = {}
var notice := ""
var notice_time := 0.0
var tell := ""
var tell_cue := ""
var tell_time := 0.0
var music_encounter := ""
var pack_attacker: CharacterBody2D
var pack_rest := 0.0
var pack_next := ""
var gate_opening := false

func clear_enemies() -> void:
	for enemy in enemies:
		enemy.hide()
		enemy.queue_free()
	enemies.clear()
	tell_time = 0
	music_encounter = ""
	pack_attacker = null
	pack_rest = 0
	pack_next = ""
	gate_opening = false

func reset() -> void:
	clear_enemies()
	defeated.clear()
	checkpoint_area = ""
	checkpoint_x = 0
	checkpoint_stats.clear()
	checkpoint_defeated.clear()
	intro_seen.clear()
	notice = ""
	notice_time = 0
	tell = ""
	tell_cue = ""

func enter(area: String, x: float = -1.0, backward: bool = false) -> void:
	clear_enemies()
	game.arena.set_area(area)
	if area != "shrine" or defeated.has("sovereign"):
		game.hero.progression.enter_level(AREAS.find(area)+1)
	game.boss.hide()
	game.powers.clear_attacks()
	game.effects.clear()
	game.hero.position = game.arena.spawn_point if x < 0 else Vector2(x,572)
	game.hero.facing = -1.0 if backward else 1.0
	game.hero.velocity = Vector2.ZERO
	game.hero.enable()
	game.camera.snap_path(game.hero.position.x,game.arena.area_width)
	game.desired_mood = .69
	game.sound.play_track(MUSIC[area],"")
	for placement: Array in PLACEMENTS.get(area,[]):
		if defeated.has(placement[0]):
			continue
		var enemy = ENEMY.instantiate()
		enemy.position = Vector2(placement[2],572)
		add_child(enemy)
		enemy.setup(placement[1])
		enemy.route_id = placement[0]
		var roam := 525 if area == "frozen" else 350
		enemy.limits = Vector2(maxf(110,placement[2]-roam),minf(game.arena.exit_x-42,placement[2]+roam))
		enemy.swung.connect(on_enemy_strike.bind(enemy))
		enemy.telegraph.connect(on_tell)
		enemy.defeated.connect(on_defeated)
		enemies.append(enemy)
	gate_opening = area == "frozen" and enemy_count() == 0 and not game.hero.progression.has("echo")
	var side_pending := area == "shrine" and not defeated.has("sovereign")
	game.arena.set_exit_open(enemy_count() == 0 and not gate_opening and not side_pending)
	if area == "courtyard":
		game.arena.gate_closed = 1.0
	elif area == "frozen":
		game.arena.gate_closed = 0.0 if game.arena.exit_open else 1.0
	announce({"road":"OLD STONE BRIDGE","underworld":"MOONLIT PASS"}.get(area,NAMES[area]),3.3)
	game.transition_to(game.State.APPROACH)

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
		enter(checkpoint_area,checkpoint_x)

func enemy_count() -> int:
	var count := 0
	for enemy in enemies:
		if not enemy.dead:
			count += 1
	return count

func act() -> int:
	var index := AREAS.find(game.arena.area)
	return 0 if index == 0 else 1 if index < 3 else 2

func tick(dt: float) -> void:
	notice_time = maxf(0,notice_time-dt)
	tell_time = maxf(0,tell_time-dt)
	var area: String = game.arena.area
	if area == "frozen":
		tick_pack(dt)
		if game.state != game.State.APPROACH:
			return
	for enemy in enemies:
		enemy.simulate(dt,game.hero.position)
		if area == "frozen" and enemy.mode == enemy.Mode.WIND and pack_attacker == null:
			pack_attacker = enemy
			pack_next = "brute" if enemy.kind == "hunter" else "hunter"
			for partner in enemies:
				partner.attack_allowed = partner == enemy
		if game.state != game.State.APPROACH:
			return
	var x: float = game.hero.position.x
	if game.hero.position.y > 760:
		game.hero.health = 0
		game.hero_died()
		return
	if area == "courtyard" and x >= 970.0:
		game.arena.gate_closed = move_toward(game.arena.gate_closed,0.0,dt*2.3)
	if area == "road" and game.arena.FOREST_BRIARS.has_point(game.hero.position-Vector2(0,4)):
		game.hero.defend(Strike.new(game.arena.FOREST_BRIARS,9,-1,false,"briars",-1))
		if game.state != game.State.APPROACH:
			return
	if CHECKPOINTS.has(area) and x >= float(CHECKPOINTS[area])-20 and not intro_seen.has(area):
		intro_seen[area] = true
		if area == "underworld" and not game.hero.progression.has("reversal"):
			game.level_reward(4,area,CHECKPOINTS[area])
			return
		save_checkpoint(area,CHECKPOINTS[area],true)
		announce("%s  ·  CHECKPOINT" % NAMES[area])
	if area == "shrine" and x >= 736.0 and not defeated.has("sovereign"):
		game.show_side_boss()
		return
	traverse(area,x)

func traverse(area: String, x: float) -> void:
	var index := AREAS.find(area)
	if index > 0 and x < 106.0 and Input.get_axis("left","right") < 0.0:
		var previous: String = AREAS[index-1]
		enter(previous,game.arena.WIDTHS[previous]-256.0,true)
		return
	if x < game.arena.exit_x or not game.arena.exit_open:
		return
	var next: String = AREAS[index+1]
	if next == "throne":
		game.hero.progression.enter_level(AREAS.size())
		save_checkpoint("throne",270,true)
		game.reveal_final()
	else:
		var first_visit: bool = AREAS.find(checkpoint_area) < index+1
		enter(next)
		if first_visit:
			save_checkpoint(next,180,true)

func tick_pack(dt: float) -> void:
	if gate_opening:
		game.arena.gate_closed = move_toward(game.arena.gate_closed,0.0,dt)
		if game.arena.gate_closed <= 0.0:
			gate_opening = false
			game.arena.set_exit_open(true)
			game.sound.play_track("frozen","")
			game.level_reward(5,"frozen",game.arena.exit_x-148.0)
		return
	if enemy_count() == 0:
		return
	if music_encounter.is_empty() and game.hero.position.x >= 535.0:
		music_encounter = "werewolves"
		game.sound.cue("wolf")
		game.sound.play_track("werewolves","")
		announce("THE HUNTER  /  THE BRUTE",2.5)
	if is_instance_valid(pack_attacker) and pack_attacker.mode not in [pack_attacker.Mode.WIND,pack_attacker.Mode.ACTIVE]:
		pack_attacker = null
		pack_rest = .52
	pack_rest = maxf(0.0,pack_rest-dt)
	var alternate_ready := false
	for enemy in enemies:
		if enemy.kind == pack_next and not enemy.dead and absf(enemy.position.x-game.hero.position.x) < 330:
			alternate_ready = true
	for enemy in enemies:
		var takes_turn: bool = not alternate_ready or enemy.kind == pack_next
		enemy.attack_allowed = not music_encounter.is_empty() and (enemy == pack_attacker or (pack_attacker == null and pack_rest <= 0.0 and takes_turn))

func strike_enemies(strike) -> void:
	for enemy in enemies:
		if strike.source == "reversal":
			strike.direction = signf(enemy.position.x-game.hero.position.x)
		if enemy.receive(strike):
			game.land_player_hit(enemy.position,strike)
			if game.state not in [game.State.APPROACH,game.State.RESURRECTING]:
				break

func interrupt() -> void:
	for enemy in enemies:
		enemy.interrupt()
	tell_time = 0

func on_enemy_strike(strike, enemy) -> void:
	if game.state == game.State.APPROACH:
		game.enemy_strike(strike,enemy)

func on_tell(label: String, cue: String) -> void:
	tell = label
	tell_cue = cue
	tell_time = .93
	game.sound.cue("wolf_attack")

func on_defeated(enemy) -> void:
	defeated[enemy.route_id] = true
	game.morality_score += 1
	game.sound.cue("wolf_death")
	game.effects.burst(enemy.position+Vector2(0,-42),enemy.accent,35,165,31,.69)
	if enemy_count() != 0:
		return
	if game.arena.area == "frozen":
		gate_opening = true
		announce("THE FORTRESS GATE OPENS")
		game.sound.cue("gate")
		return
	game.arena.set_exit_open(true)

