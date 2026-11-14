extends SceneTree
## Drives normal input and the live encounter at fixed time. Run with --fixed-fps 60.
const WORLD = preload("res://scenes/Throne.tscn")
const Strike = preload("res://scripts/strike.gd")
var game
var failures := 0
var seen_attacks := {}
var attacks := {}
var queued_keys := {}
var render_output := ""

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		push_error("FAIL " + label)

func input_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func wait_ticks(count: int) -> void:
	for frame in count:
		await physics_frame

func press(key: Key) -> void:
	input_key(key, true)
	await wait_ticks(2)
	input_key(key, false)
	await wait_ticks(1)

func until_state(value: int, frames: int) -> bool:
	for i in frames:
		if game.state == value:
			return true
		await physics_frame
	return game.state == value

func run() -> void:
	render_output = OS.get_environment("BLOODBOUND_QA_DIR")
	game = WORLD.instantiate()
	var fallback := "--no-art" in OS.get_cmdline_user_args()
	if fallback:
		game.get_node("Sovereign").profile.data.set_value("visual","frames","res://missing/sovereign_frames.tres")
	root.add_child(game)
	await wait_ticks(5)
	verify(game.state == game.State.TITLE and (game.boss_art.imported == null) == fallback, "Title and optional sprite fallback")
	verify(game.hero.profile.get_value("identity","weapon") == "Honjō Masamune", "Sword identity retains the macron")
	check_stats()
	if "--base-duel" in OS.get_cmdline_user_args():
		game.ui.show_panel("")
		game.enter_duel()
		verify(await play_duel(),"Base damage and health can finish the final duel without Death Reversal")
		if failures == 0:
			verify(await until_state(game.State.FLASH_OPEN,155),"Base build reaches One Flash")
			await press(KEY_F)
			verify(await until_state(game.State.VICTORY,1830),"Base build reaches victory")
		quit(failures)
		return
	await capture("title")
	await press(KEY_ENTER)
	verify(game.state == game.State.REVEAL, "Begin opens the real-time courtyard scene")
	await wait_ticks(101)
	await capture("hero-closeup")
	await wait_ticks(89)
	await capture("opening-clash")
	verify(await until_state(game.State.PROLOGUE, 2810), "Choreographed opening leads to the courtyard duel")
	verify(game.arena.area == "courtyard" and game.boss.visible, "First villain encounter takes place in the Fallen Courtyard")
	input_key(KEY_D,true)
	await wait_ticks(21)
	input_key(KEY_D,false)
	await press(KEY_SPACE)
	verify(game.hero.position.y < 572, "Movement and jump are live in the opening duel")
	await press(KEY_ESCAPE)
	var paused_time: float = game.clock
	await wait_ticks(10)
	verify(game.paused and game.clock == paused_time, "Pause stops the encounter clock")
	await press(KEY_ESCAPE)
	verify(await until_state(game.State.DEPARTURE, 2900), "The first duel ends in scripted death")
	verify(game.hero.health == 0 and not game.hero.awakened and game.boss.visible, "Hero falls while the villain remains on screen")
	var origin: float = game.boss.position.x
	await wait_ticks(195)
	verify(game.boss.position.x > origin + 70 and game.boss.visible, "The Sovereign walks toward the exit")
	await capture("departure")
	verify(await until_state(game.State.AWAKEN, 300), "Sovereign leaves and the gate closes before awakening")
	verify(not game.boss.visible and game.arena.gate_closed == 1.0, "The villain is absent before the soul rises")
	await wait_ticks(575)
	await capture("afterlife")
	verify(await until_state(game.State.APPROACH, 1430), "First resurrection restores control")
	verify(game.arena.area == "courtyard" and not game.boss.visible and game.hero.resurrection_level == 1
		and game.resurrection_charges == 3, "The heir wakes in the empty courtyard with three charges")
	await walk_until("road", 320)
	await capture("ashen-road")
	verify(game.journey.enemy_count() == 3, "Ashen Road has two shadow remnants and the Warden")
	var road_won := await play_route("shrine")
	verify(road_won, "Keyboard combat defeats the Warden and reaches the shrine")
	if not road_won:
		quit(1)
		return
	verify(game.journey.defeated.has("warden") and game.hero.progression.has("phantom") and game.hero.maximum == 160, "Warden unlocks Phantom Step and the next level grants 160 HP")
	await capture("shrine")
	var shrine_won := await play_route("memory")
	verify(shrine_won, "Keyboard combat defeats the Veiled Spirit and triggers clan memory")
	if not shrine_won:
		quit(1)
		return
	verify(game.journey.checkpoint_area == "shrine" and game.journey.checkpoint_x >= 1440, "Shrine checkpoint is active")
	verify(not game.journey.reversal_unlocked, "Death Reversal stays locked during clan memory")
	await wait_ticks(155)
	await capture("clan-memory")
	verify(await until_state(game.State.APPROACH,2280), "Clan memory returns control")
	verify(game.hero.progression.has("sever") and not game.journey.reversal_unlocked, "Spirit unlocks Soul Sever before the Underworld Gate")
	await check_powers()
	verify(await play_route("frozen"),"Underworld Guardian is defeated and Frozen Oath opens")
	if game.arena.area != "frozen":
		quit(1)
		return
	verify(game.journey.reversal_unlocked and game.hero.maximum == 200,"Death Reversal is earned and Frozen Oath grants 200 HP")
	await capture("frozen")
	verify(await play_route("throne"),"Frozen Rival is defeated and the final arena opens")
	if game.arena.area != "throne":
		quit(1)
		return
	verify(game.hero.progression.has("echo"),"Ancestral Echo unlocks after the Frozen Rival")
	verify(game.state == game.State.FINAL_REVEAL and game.boss.visible, "The Sovereign returns in the Throne of the Eclipse")
	verify(await until_state(game.State.FIGHT, 350), "Reunion dialogue begins the final duel")
	verify(game.hero.maximum == 220 and game.boss.maximum == 800,"Final arena starts with the configured HP totals")
	game.boss.telegraph.connect(func(name: String) -> void: seen_attacks[name] = true)
	if "--no-art" not in OS.get_cmdline_user_args():
		await check_echo()
		await check_phase_queue()
		await check_resurrections()
	var level: int = game.hero.resurrection_level
	var combat_result: bool = await play_duel()
	verify(combat_result, "The upgraded heir crosses the final boss phases with keyboard combat")
	if not combat_result:
		quit(1)
		return
	verify(attacks.has(2) and attacks.has(3), "Both later boss phases were playable")
	verify(await until_state(game.State.FLASH_OPEN, 155), "One Flash timing window opens")
	await capture("one-flash")
	verify(await until_state(game.State.LAST_CHANCE,115), "Missing One Flash gives another chance")
	verify(await until_state(game.State.FLASH_OPEN,310), "One Flash reopens after the shockwave")
	await press(KEY_F)
	verify(game.state == game.State.EXECUTE, "F triggers the finishing strike")
	await wait_ticks(33)
	await capture("execution")
	verify(await until_state(game.State.EPILOGUE, 320), "The final strike leads to the ink epilogue")
	verify(game.boss.health == 0 and game.hero_art.white_blade, "The Sovereign is defeated and the blade stays white")
	verify(await until_state(game.State.VICTORY, 1570), "Epilogue reaches the victory menu")
	await capture("victory")
	print("Simulated full route seconds (including resurrection checks and retry): ",game.elapsed)
	await press(KEY_R)
	verify(game.state == game.State.FIGHT and game.hero.resurrection_level >= level
		and game.journey.reversal_unlocked, "Retry preserves earned abilities at the final checkpoint")
	game.command("title")
	await press(KEY_ENTER)
	verify(game.state == game.State.REVEAL, "New game restarts the courtyard introduction")
	await press(KEY_ENTER)
	verify(game.state == game.State.PROLOGUE, "Enter safely skips the courtyard introduction")
	game.begin_doom()
	await press(KEY_ENTER)
	await press(KEY_ENTER)
	await press(KEY_ENTER)
	await press(KEY_ENTER)
	verify(game.state == game.State.APPROACH and not game.boss.visible, "Skipping death, departure, and afterlife leaves a playable empty courtyard")
	print("Observed final boss telegraphs: ", seen_attacks.keys())
	print("BLOODBOUND smoke complete. Failures: ", failures)
	game.sound.stop_all()
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)

func walk_until(area: String, frames: int) -> void:
	input_key(KEY_D,true)
	for i in frames:
		if game.arena.area == area:
			break
		await physics_frame
	input_key(KEY_D,false)

func play_route(destination: String) -> bool:
	for i in 7200:
		if game.arena.area == destination or (destination == "memory" and game.state == game.State.MEMORIAL):
			set_keys([])
			return true
		if game.state == game.State.DEFEAT:
			break
		var desired: Array[int] = [KEY_D]
		if game.state != game.State.APPROACH:
			desired.clear()
		else:
			var h = game.hero
			var nearest: Node2D
			for enemy in game.journey.enemies:
				if not enemy.dead and (nearest == null or absf(enemy.position.x-h.position.x) < absf(nearest.position.x-h.position.x)):
					nearest = enemy
			if nearest:
				var enemy = nearest
				var distance: float = enemy.position.x-h.position.x
				var side := KEY_D if distance > 0 else KEY_A
				desired.clear()
				if absf(distance) > 102 or signf(distance) != h.facing:
					desired.append(side)
				if enemy.mode == enemy.Mode.WIND and enemy.clock > float(enemy.stats.wind)-.085:
					desired.append(KEY_SPACE if enemy.attack in ["wave","orb"] else KEY_L)
				elif enemy.mode == enemy.Mode.ACTIVE and enemy.attack == "wave":
					desired.append(KEY_SPACE)
				elif absf(distance) < 120 and i % 4 == 0:
					desired.append(KEY_J)
		if KEY_D in desired:
			for obstacle: float in game.arena.OBSTACLES.get(game.arena.area,[]):
				if game.hero.position.x > obstacle-75.0 and game.hero.position.x < obstacle+32.0:
					desired.erase(KEY_J)
					desired.append(KEY_SPACE)
		set_keys(desired)
		await physics_frame
	set_keys([])
	print("Route stalled at ",game.arena.area," hero ",game.hero.position," enemies ",game.journey.enemy_count())
	return false

func check_stats() -> void:
	var stats = game.hero.progression.duplicate()
	stats.reset()
	verify(stats.maximum == 120 and stats.health == 120 and stats.base_attack == 20
		and stats.energy == 0.0 and stats.charges == 3,"New game uses the configured starting stats")
	stats.health = -18
	verify(stats.health == 0,"Player health clamps at zero")
	stats.health = 400
	verify(stats.health == 120,"Player health clamps at maximum")
	for level in range(2,7):
		stats.enter_level(level)
		verify(stats.health == 100+level*20 and stats.maximum == stats.health,"Level %d grants its full health tier" % level)
	for i in 8:
		stats.resurrect()
	verify(stats.soul_level == 5 and is_equal_approx(stats.attack_power(1.0),45.0)
		and is_equal_approx(stats.attack_power(1.0,true,true),121.5),"Soul power caps at +50% before heavy and critical multipliers")

func check_powers() -> void:
	var h = game.hero
	var stats = h.progression
	verify(stats.has("phantom") and stats.has("sever"),"Both route powers are unlocked after the shrine")
	var before: Vector2 = h.position
	var energy: float = h.energy
	await press(KEY_E)
	verify(h.phantom and h.iframe > 0.0 and h.energy == energy-stats.phantom_cost,"Phantom Step spends energy and gives brief invulnerability")
	await wait_ticks(18)
	verify(absf(h.position.x-before.x) > 160.0 and not h.phantom,"Phantom Step travels farther than a regular dodge and ends")
	if h.position.x > game.arena.exit_x-50.0:
		h.position.x = game.arena.exit_x-250.0
	await press(KEY_U)
	await wait_ticks(12)
	verify(game.powers.waves.size() == 1,"Soul Sever launches once on the animation impact")
	await capture("soul-sever")
	h.energy = stats.energy_limit

func check_echo() -> void:
	var h = game.hero
	var b = game.boss
	h.position.x = b.position.x - 98.0
	h.facing = 1.0
	b.mode = b.Mode.RECOVER
	b.stats = {"recover":9.0}
	b.clock = 0.0
	var before: int = b.health
	h.energy = 100.0
	await press(KEY_I)
	verify(game.powers.echo_armed and h.energy == 75.0,"Ancestral Echo arms one repeat")
	await press(KEY_J)
	await wait_ticks(10)
	var after_slash: int = b.health
	verify(after_slash == before-roundi(h.progression.attack_power(1.0)),"Repeated active hitboxes register one melee hit")
	await wait_ticks(24)
	verify(after_slash < before and b.health < after_slash and not game.powers.echo_armed
		and game.powers.echoes.is_empty(),"Echo deals one delayed hit after the original slash")

func check_phase_queue() -> void:
	var b = game.boss
	var transitions: Array[int] = []
	var record := func(state: int) -> void:
		if state == game.State.TRANSITION:
			transitions.append(game.next_stage)
	game.state_changed.connect(record)
	b.health = 560
	game.hero_strike(Strike.new(b.hurtbox(),4000,1,false,"test",game.hero.strike_id+1))
	verify(b.health == 40 and game.state == game.State.TRANSITION and game.next_stage == 2,"Large hit stops at 40 HP and starts phase two")
	var rejected: bool = b.receive(Strike.new(b.hurtbox(),9000,1,false,"test",game.hero.strike_id+2))
	verify(not rejected and b.health == 40,"Damage is blocked during the transformation")
	await press(KEY_ENTER)
	verify(game.state == game.State.TRANSITION and game.next_stage == 3,"Phase three follows phase two")
	await press(KEY_ENTER)
	verify(game.state == game.State.FLASH_PREP and transitions == [2,3],"Both transitions fire once before One Flash")
	game.state_changed.disconnect(record)
	game.command("retry")
	await wait_ticks(3)

func check_resurrections() -> void:
	var h = game.hero
	var b = game.boss
	b.health = 510
	verify(await until_state(game.State.TRANSITION, 20), "Phase threshold triggers the transformation")
	await press(KEY_ENTER)
	verify(game.state == game.State.FIGHT and b.stage == 2, "Phase transition skips safely")
	var charges: int = game.resurrection_charges
	var level: int = h.resurrection_level
	h.position.x = b.position.x - 103.0
	h.health = 30
	game.hero.energy = game.hero.progression.energy_limit
	await press(KEY_Q)
	verify(game.state == game.State.RESURRECTING and game.reversal and game.resurrection_charges == charges-1
		and game.reversal_meter == 0.0, "Q spends one charge and the full meter")
	await press(KEY_Q)
	verify(game.resurrection_charges == charges-1, "Death Reversal cannot overlap itself")
	await capture("death-reversal")
	verify(await until_state(game.State.FIGHT,90), "Death Reversal returns to the fight")
	verify(h.health == h.maximum and h.resurrection_level == level+1 and b.health < 510 and b.stage == 2,
		"Death Reversal heals, grows power, and hits the nearby boss")
	var boss_hp: int = b.health
	game.reversal_meter = 100.0
	await press(KEY_Q)
	verify(game.state == game.State.FIGHT and game.resurrection_charges == charges-1, "Cooldown prevents an immediate second reversal")
	game.morality_score = -1
	verify(game.realm() == "abyss", "Negative morality selects the Abyss")
	for i in charges-1:
		h.iframe = 0
		game.boss_strike(Strike.new(h.hurtbox(), h.maximum, -1, false, "test_lethal", 8100+i))
		verify(game.state == game.State.RESURRECTING and game.resurrection_charges == charges-2-i, "Fatal hit spends one automatic charge")
		verify(await until_state(game.State.FIGHT,90), "Automatic resurrection resumes combat")
		verify(b.health == boss_hp and b.stage == 2 and h.iframe > .9, "Automatic resurrection preserves boss HP and phase")
	h.iframe = 0
	game.boss_strike(Strike.new(h.hurtbox(), h.maximum, -1, false, "test_lethal", 8199))
	verify(game.state == game.State.DEFEAT, "Death with zero charges opens game over")
	await press(KEY_R)
	verify(game.state == game.State.FIGHT and b.health == b.maximum and game.resurrection_charges == 3
		and h.resurrection_level == level and h.maximum == 220, "Retry restores checkpoint soul level, abilities, health and charges")

func play_duel() -> bool:
	var wait_after_stage := 0
	var last_stage: int = game.boss.stage
	var attack_count := 0
	var previous_attack := ""
	for i in 11000:
		if game.state in [game.State.FLASH_PREP, game.State.DEFEAT]:
			break
		if game.state != game.State.FIGHT:
			set_keys([])
			await physics_frame
			continue
		var h = game.hero
		var b = game.boss
		var distance: float = b.position.x - h.position.x
		var desired: Array[int] = []
		if b.stage != last_stage:
			last_stage = b.stage
			wait_after_stage = i + 570
		if b.mode == b.Mode.WIND and b.attack != previous_attack:
			attack_count += 1
			previous_attack = b.attack
		elif b.mode == b.Mode.IDLE:
			previous_attack = ""
		var toward := KEY_D if distance > 0 else KEY_A
		var avoid := KEY_A if distance > 0 else KEY_D
		var harmful := false
		if h.health < 57 and game.reversal_ready():
			desired.append(KEY_Q)
		if b.mode == b.Mode.WIND:
			var remaining: float = b.wind_time() - b.clock
			match b.attack:
				"cleave", "rush", "teleport":
					if remaining > .016 and remaining < .10 and (absf(distance) <= 244 or b.attack in ["rush","teleport"]):
						desired.append(KEY_L if h.parry_cd <= 0 else KEY_SHIFT)
						harmful = true
				"slam":
					if remaining < .12 and remaining > .015 and absf(distance) < 220:
						desired.append(KEY_SPACE)
						harmful = true
				"ruin":
					for mark: float in b.marks:
						if absf(mark - h.position.x) < 67:
							desired.append(avoid if h.position.x > 150 and h.position.x < 1130 else (KEY_D if h.position.x < 640 else KEY_A))
							harmful = true
							break
				"throne":
					if absf(distance) < 275:
						desired.append(avoid)
						harmful = true
		elif b.mode == b.Mode.ACTIVE:
			harmful = true
			if b.attack == "throne":
				desired.append(avoid)
				if b.clock > 1.29 and b.clock < 1.35 and absf(distance) < 245:
					desired.append(KEY_L)
			elif b.attack == "slam" and h.position.y < 572 and h.velocity.y < 0 and b.clock < .27:
				desired.append(KEY_SPACE)
			elif b.attack == "rush" and h.parry_cd <= 0 and absf(distance) < 140:
				desired.append(KEY_L)
		if not harmful:
			if absf(distance) > 102 or signf(distance) != h.facing:
				desired.append(toward)
			if i > wait_after_stage and absf(distance) < 118 and h.facing == signf(distance):
				var ready: bool = h.mode == h.Mode.FREE or (h.mode == h.Mode.ATTACK and h.clock > .14 and h.swing_buffer <= 0)
				if ready and i % 3 == 0:
					desired.append(KEY_J)
			elif b.mode == b.Mode.STAGGER and absf(distance) < 135 and i % 3 == 0:
				desired.append(KEY_J)
		if b.stage == 1 and attack_count < 3 and b.health < 385:
			desired.erase(KEY_J)
		attacks[b.stage] = true
		set_keys(desired)
		await physics_frame
	set_keys([])
	print("Duel result: state ", game.state, ", stage ", game.boss.stage, ", boss HP ", game.boss.health,
		", hero HP ", game.hero.health, ", parries ", game.parries, ", seconds ", game.fight_time)
	return game.state == game.State.FLASH_PREP

func set_keys(desired: Array[int]) -> void:
	for key: int in queued_keys.keys():
		if key not in desired:
			input_key(key, false)
			queued_keys.erase(key)
	for key: int in desired:
		if not queued_keys.has(key):
			input_key(key, true)
			queued_keys[key] = true

func capture(label: String) -> void:
	if render_output.is_empty():
		return
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	var result := frame.save_png(render_output.path_join(label + ".png"))
	verify(result == OK, "Captured " + label)
