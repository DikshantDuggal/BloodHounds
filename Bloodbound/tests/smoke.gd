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
	var use_movie := "--no-video" not in OS.get_cmdline_user_args()
	root.add_child(game)
	if not use_movie:
		game.ui.story_movie.stream = null
	if fallback:
		for art in [game.sovereign_art,game.overlord_art]:
			art.imported.hide()
			art.imported.queue_free()
			art.imported = null
		game.story.renderer.monster = null
	await wait_ticks(5)
	verify(game.state == game.State.TITLE and (game.boss_art.imported == null) == fallback, "Title and optional sprite fallback")
	verify(game.hero.profile.get_value("identity","weapon") == "Ketsumei", "The approved sword is named Ketsumei")
	check_stats()
	if "--base-duel" in OS.get_cmdline_user_args():
		game.ui.show_panel("")
		game.hero.progression.unlock_for(1)
		game.enter_duel()
		verify(await play_duel(),"The starting stat tier with Ancestral Resurrection can finish the final duel")
		if failures == 0:
			verify(await until_state(game.State.FLASH_OPEN,155),"Base build reaches One Flash")
			await press(KEY_F)
			verify(await until_state(game.State.VICTORY,2250),"Base build reaches credits")
		await exit_test(failures)
		return
	await wait_ticks(52)
	await capture("title")
	await press(KEY_DOWN)
	await press(KEY_DOWN)
	await press(KEY_ENTER)
	verify(game.state == game.State.TITLE and game.ui.menu_name == "audio","Title settings open from the keyboard")
	await press(KEY_ESCAPE)
	verify(game.ui.menu_name == "title","Settings return to the title menu")
	await press(KEY_ENTER)
	verify(game.state == game.State.VILLAGE, "Begin opens the playable ruined village")
	input_key(KEY_D,true)
	verify(await until_state(game.State.REVEAL,125),"Walking out of the village starts the courtyard scene")
	input_key(KEY_D,false)
	await wait_ticks(101)
	await capture("hero-closeup")
	await wait_ticks(89)
	await capture("opening-clash")
	verify(await until_state(game.State.PROLOGUE, 2810), "Choreographed opening leads to the courtyard duel")
	verify(game.arena.area == "courtyard" and game.boss == game.overlord and game.boss.visible and not game.sovereign.visible,
		"The Demon Overlord is the opening villain")
	verify(game.hero.profile.get_value("identity","name") == "Shinegen Oda","Shinegen Oda is named correctly")
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
	verify(await until_state(game.State.DOOM, 2900), "Opening combat triggers the fatal strike")
	verify(game.hero.pose == "parry" and game.hero.position.y == 572,"Shinegen defends while standing")
	await wait_ticks(ceili(game.timing("doom_wind")*60)+4)
	verify(game.hero.pose == "fatal_recoil" and game.hero.health > 0 and not game.hero_art.released_weapon,"The sword connects before Shinegen falls")
	await capture("fatal-strike")
	await wait_ticks(39)
	verify(game.arena.fatal_impact.y == game.arena.FLOOR-2.0 and game.hero.pose == "death",
		"The finishing strike breaks stone at the floor without moving the body through it")
	await capture("ground-impact")
	verify(await until_state(game.State.DEPARTURE, 140), "The first duel ends in scripted death")
	verify(game.hero.health == 0 and not game.hero.awakened and game.boss.visible, "Hero falls while the villain remains on screen")
	var origin: float = game.boss.position.x
	await wait_ticks(195)
	verify(game.boss.position.x > origin + 55 and game.boss.visible, "The demon walks toward the exit")
	verify(game.hero_art.released_weapon and absf(game.hero_art.weapon_pivot.global_position.y-563.0) < 2.0,
		"Ketsumei rests beside Shinegen during the demon's departure")
	await capture("departure")
	verify(await until_state(game.State.AWAKEN, 300), "The demon leaves and the gate closes before awakening")
	verify(not game.boss.visible and game.arena.gate_closed == 1.0, "The villain is absent before the soul rises")
	await wait_ticks(59)
	verify(game.profile.get_value("story","first_death_line") == "Your life has not ended yet."
		and not game.ui.story_movie_backdrop.visible,"The message comes before the video")
	await capture("first-death-line")
	if use_movie:
		for frame in 150:
			if game.ui.story_movie_backdrop.visible:
				break
			await physics_frame
		verify(game.ui.story_movie.is_playing() and not game.boss.visible,"The Oda lore video starts after the demon leaves")
		await wait_ticks(286)
		verify(game.ui.story_movie.stream_position > 3.5,"Godot decodes the Oda video during playback")
		await capture("oda-video")
		for frame in 780:
			if not game.ui.story_movie_backdrop.visible:
				break
			await physics_frame
		verify(not game.ui.story_movie_backdrop.visible and game.story_movie_elapsed >= 9.0
			and game.story_movie_elapsed <= 10.45,"The complete Oda movie exits at its measured duration")
	else:
		await wait_ticks(68)
		verify(game.story_movie_attempted and not game.ui.story_movie_backdrop.visible,
			"Missing video continues into The Between")
	await wait_ticks(165)
	verify(game.state == game.State.AWAKEN and game.clock >= game.timing("soul_departure")
		and game.clock < game.timing("soul_return") and game.sound.bank.has("between"),
		"First resurrection uses The Between")
	if DisplayServer.get_name() != "headless":
		verify(game.sound.track == "between","The first Between scene uses its own cue")
	await capture("between-first")
	await wait_ticks(76)
	await capture("between-oath")
	await wait_ticks(240)
	await capture("sword-return")
	verify(await until_state(game.State.APPROACH, 1430), "First resurrection restores control")
	verify(not game.hero_art.released_weapon and game.hero_art.weapon_sprite.self_modulate == Color.WHITE,
		"First resurrection returns the original sword to the hand")
	verify(game.arena.area == "courtyard" and not game.boss.visible and game.hero.resurrection_level == 1
		and game.hero.progression.charges == 3, "The heir wakes in the empty courtyard with three charges")
	verify(game.hero.progression.unlocked == PackedStringArray(["resurrection"]),"First awakening grants only Ancestral Resurrection")
	await travel(999,KEY_D)
	verify(game.hero.progression.unlocked == PackedStringArray(["resurrection","phantom"]),"Morning training grants Phantom Step as the second power")
	input_key(KEY_D,true)
	await wait_ticks(25)
	input_key(KEY_D,false)
	verify(game.hero.position.x < game.journey.PHANTOM_WARD and not game.journey.defeated.has("phantom_ward"),"Ordinary movement stops at the ward")
	await press(KEY_E)
	await wait_ticks(17)
	verify(game.journey.defeated.has("phantom_ward"),"Phantom Step passes the ward")
	await capture("phantom-ward")
	await walk_until("road",320)
	verify(game.journey.enemy_count() == 1 and game.journey.enemies[0].kind == "hunter" and game.journey.act() == 1,"Afternoon forest replaces archers with one Hunter")
	await travel(825,KEY_D)
	await capture("stone-bridge")
	await travel(1300,KEY_D)
	verify(game.hero.position.y < 574 and game.hero.position.x > 1254,"Walk across the Old Stone Bridge")
	await travel(320,KEY_A)
	verify(game.hero.position.y < 574 and game.hero.position.x < 390,"Old Stone Bridge supports return travel")
	await travel(1280,KEY_D)
	var road_won := await play_route("shrine")
	verify(road_won,"Keyboard combat clears the forest")
	if not road_won:
		await exit_test(1)
		return
	verify(game.journey.enemies.is_empty() and not game.arena.exit_open and game.hero.maximum == 140,"The removed Warden is absent and the shrine awaits the Sovereign")
	await walk_until("road",95,KEY_A)
	verify(game.arena.area == "road" and game.hero.position.x > 2500 and game.journey.enemy_count() == 0,
		"Backtracking enters the far side of the forest and preserves defeated enemies")
	await walk_until("shrine",130)
	verify(game.arena.area == "shrine","Re-entering the shrine spawns at its near side")
	await capture("shrine")
	var shrine_start: float = game.elapsed
	await travel(754,KEY_D)
	verify(await until_state(game.State.FIGHT,250),"The afternoon shrine introduces the Sovereign")
	verify(game.boss == game.sovereign and game.boss.maximum == 350 and game.boss.health == 350,
		"The Skull Guardian takes the 350 HP shrine slot")
	await capture("side-boss")
	var shrine_won := await play_duel(true)
	print("Sovereign test approach and combat seconds: ",game.elapsed-shrine_start)
	verify(shrine_won,"Keyboard combat defeats the Skull Guardian")
	if not shrine_won:
		await exit_test(1)
		return
	verify(game.state == game.State.MEMORIAL and game.journey.defeated.has("sovereign")
		and game.hero.progression.unlocked == PackedStringArray(["resurrection","phantom"]),"The side boss resolves only the shrine milestone")
	await wait_ticks(28)
	await capture("sovereign-finisher")
	await wait_ticks(47)
	await capture("sovereign-defeat")
	verify(await until_state(game.State.APPROACH,320),"The short in-engine victory returns control")
	verify(game.hero.maximum == 160 and game.hero.progression.unlocked == PackedStringArray(["resurrection","phantom","sever"]),
		"Skull Guardian victory raises maximum health and grants only Soul Sever")
	await check_powers()
	await walk_until("underworld",550)
	verify(game.arena.area == "underworld" and game.journey.act() == 2,"Night starts at Moonlit Pass")
	await travel(1165,KEY_D)
	await capture("moonlit-pass")
	await travel(280,KEY_A)
	verify(game.arena.area == "underworld" and game.hero.position.y < 574 and game.hero.position.x < 350,"Moonlit bridge has walkable collision in both directions")
	await travel(1180,KEY_D)
	await until_state(game.State.APPROACH,130)
	verify(not game.hero.progression.has("reversal") and game.hero.maximum == 180,"Moonlit checkpoint raises health before Death Reversal is earned")
	verify(await play_route("frozen"),"Moonlit Pass connects to the wolves' gate")
	verify(game.journey.enemy_count() == 2 and game.journey.enemies[0].maximum == 150
		and game.journey.enemies[1].maximum == 220,"Hunter and Brute spawn together with distinct health")
	await travel(640,KEY_D)
	await capture("werewolves")
	verify(await play_route("gate"),"Keyboard combat defeats both werewolves without overlapping attack turns")
	verify(game.journey.checkpoint_defeated.has("hunter") and game.journey.checkpoint_defeated.has("brute"),
		"Checkpoint records both werewolf defeats")
	game.command("retry")
	await wait_ticks(5)
	verify(game.arena.area == "frozen" and game.journey.enemy_count() == 0 and game.arena.exit_open,
		"Retry keeps both werewolves defeated and the gate open")
	verify(game.hero.progression.unlocked == PackedStringArray(["resurrection","phantom","sever","reversal"]),
		"Defeating both wolves grants the fourth regular power, Death Reversal")
	verify(await play_route("throne"),"The wolves' gate opens the final fortress")
	if game.arena.area != "throne":
		await exit_test(1)
		return
	verify(game.state == game.State.FINAL_REVEAL and game.boss == game.overlord and game.overlord.visible and not game.sovereign.visible,
		"The Demon Overlord is the only boss at the fortress")
	if not fallback:
		verify(game.boss_art.imported.sprite_frames.has_animation("cast_hit") and game.boss_art.imported.sprite_frames.has_animation("death"),
			"The Overlord has its own supplied cast and death animations")
	await wait_ticks(80)
	await capture("overlord-intro")
	verify(await until_state(game.State.FIGHT, 350), "Reunion dialogue begins the final duel")
	verify(game.hero.maximum == 220 and game.boss.maximum == 800,"Final arena starts with the configured HP totals")
	game.boss.telegraph.connect(func(name: String) -> void: seen_attacks[name] = true)
	if "--no-art" not in OS.get_cmdline_user_args():
		check_overlord_damage()
		check_single_hit()
		await check_phase_queue()
		await check_resurrections()
	var combat_result: bool = await play_duel()
	verify(combat_result, "The upgraded heir crosses the final boss phases with keyboard combat")
	if not combat_result:
		await exit_test(1)
		return
	verify(attacks.has(2) and attacks.has(3), "Both later boss phases were playable")
	verify(await until_state(game.State.FLASH_OPEN, 155), "One Flash timing window opens")
	verify(game.hero_art.weapon_sprite.modulate == Color.WHITE,"One Flash anticipation leaves the weapon untinted")
	await capture("one-flash")
	verify(await until_state(game.State.LAST_CHANCE,115), "Missing One Flash gives another chance")
	verify(await until_state(game.State.FLASH_OPEN,310), "One Flash reopens after the shockwave")
	await press(KEY_F)
	verify(game.state == game.State.EXECUTE, "F triggers the finishing strike")
	await wait_ticks(33)
	await capture("execution")
	await wait_ticks(108)
	await capture("overlord-collapse")
	verify(await until_state(game.State.EPILOGUE, 320), "The final strike leads to the epilogue")
	verify(game.boss.health == 0 and game.curse_active and game.hero_art.weapon_sprite.self_modulate == Color.WHITE,
		"One Flash fulfills the oath and activates the curse")
	await wait_ticks(171)
	verify(game.arena.fortress_fall > .3 and game.arena.fortress_fall < 1.0,
		"The fortress collapses after One Flash and before the curse dissolves Shinegen")
	await capture("fortress-collapse")
	await wait_ticks(369)
	var curse_clock: float = game.clock
	var position_before: Vector2 = game.hero.position
	var strike_before: int = game.hero.strike_id
	var charges_before: int = game.hero.progression.charges
	game.finish()
	game.command("retry")
	game.start_resurrection(false)
	await press(KEY_D)
	await press(KEY_J)
	await press(KEY_Q)
	verify(game.state == game.State.EPILOGUE and game.clock > curse_clock and game.hero.position == position_before
		and game.hero.strike_id == strike_before and game.hero.progression.charges == charges_before,
		"The curse plays once and locks movement, attacks, resurrection and retry")
	await wait_ticks(96)
	verify(game.state == game.State.EPILOGUE and game.hero_art.released_weapon and game.hero_art.self_modulate.a < .8,
		"The curse dissolves Shinegen and leaves Ketsumei visible")
	await capture("curse-dissolution")
	await wait_ticks(108)
	var suspended_y: float = game.hero_art.weapon_pivot.global_position.y
	verify(game.soul_erasure() == 1.0 and game.hero_art.self_modulate.a == 0.0,
		"Body and soul disappear before the sword lands")
	await wait_ticks(222)
	verify(game.soul_erasure() == 1.0 and game.arena.oath_stone > 0.0 and game.hero_art.self_modulate.a == 0.0 and
		absf(game.hero_art.weapon_pivot.global_position.x-game.arena.oath_stone) < 1.0
		and game.hero_art.weapon_pivot.global_position.y > suspended_y+20.0,
		"Ketsumei falls into the stone after the soul is fully erased")
	await capture("sword-in-stone")
	await wait_ticks(440)
	verify(game.arena.heir_progress > 3.35 and game.arena.ending,"An unidentified heir approaches Ketsumei")
	await capture("future-heir")
	await wait_ticks(95)
	verify(game.story.presentation().line == "ONE OATH ENDS.","The first sequel title follows the heir teaser")
	await capture("one-oath-ends")
	await wait_ticks(102)
	verify(game.story.presentation().line == "ANOTHER AWAITS.","The second sequel title follows the first")
	verify(await until_state(game.State.VICTORY, 480) and game.ui.menu_name == "victory", "The cursed ending reaches credits")
	await capture("victory")
	print("Simulated full route seconds (including resurrection checks and retry): ",game.elapsed)
	var ended_run = game.hero.progression
	game.pulse("white",Color("#fff5de"))
	game.set_paused(true)
	game.command("title")
	await wait_ticks(2)
	verify(not game.paused and not paused and game.flash_level == 0 and game.state == game.State.TITLE
		and is_equal_approx(game.arena.shade,.32) and not game.arena.ending,"Return to Title clears ending lighting, flashes and pause")
	verify(game.hero.progression != ended_run and game.journey.defeated.is_empty() and game.journey.checkpoint_area.is_empty()
		and game.powers.waves.is_empty() and game.powers.echoes.is_empty() and game.story.panels.is_empty()
		and not game.curse_active and not game.story_movie_attempted and not game.ui.story_movie_backdrop.visible,
		"Return to Title discards the run, checkpoints, and active effects")
	await capture("reset-title")
	var title_run = game.hero.progression
	await press(KEY_ENTER)
	await capture("reset-new-game")
	verify(game.hero.progression != title_run and game.hero.maximum == 120 and game.hero.health == 120
		and game.hero.progression.base_attack == 20 and game.hero.energy == 0.0 and game.hero.progression.level == 1
		and game.hero.progression.unlocked.is_empty() and game.hero.resurrection_level == 0 and game.hero.progression.charges == 3
		and game.sovereign.health == 350 and game.overlord.health == 800 and game.overlord.stage == 0,
		"Begin creates fresh hero and boss state")
	verify(game.state == game.State.VILLAGE, "New game restarts in the ruined village")
	await press(KEY_ENTER)
	verify(game.state == game.State.REVEAL,"Enter skips the village approach")
	await press(KEY_ENTER)
	verify(game.state == game.State.PROLOGUE and game.hero.visible and game.boss == game.overlord and game.arena.oath_stone == 0.0,
		"After credits, the opening restarts with Shinegen alive and the true demon present")
	game.begin_doom()
	await press(KEY_ENTER)
	await press(KEY_ENTER)
	await press(KEY_ENTER)
	await press(KEY_ENTER)
	verify(game.state == game.State.APPROACH and not game.boss.visible, "Skipping death, departure and The Between leaves a playable empty courtyard")
	print("Observed final boss telegraphs: ", seen_attacks.keys())
	print("BLOODBOUND smoke complete. Failures: ", failures)
	await exit_test(failures)

func exit_test(code: int) -> void:
	game.story.stop()
	game.sound.stop_all()
	# Fixed simulation time can advance faster than the audio mixer on Windows.
	var deadline := Time.get_ticks_msec() + 120
	while Time.get_ticks_msec() < deadline:
		await process_frame
	game.queue_free()
	await process_frame
	quit(code)

func walk_until(area: String, frames: int, key: Key = KEY_D) -> void:
	input_key(key,true)
	for i in frames:
		if game.arena.area == area:
			break
		await physics_frame
	input_key(key,false)

func travel(x: float, key: Key) -> void:
	for i in 650:
		if (game.hero.position.x >= x if key == KEY_D else game.hero.position.x <= x):
			break
		var desired: Array[int] = [key]
		if key == KEY_D and game.hero.position.x > 1320 and game.hero.position.x < 1440 and game.arena.area == "road" and i % 48 < 24:
			desired.append(KEY_SPACE)
		set_keys(desired)
		await physics_frame
	set_keys([])

func play_route(destination: String) -> bool:
	for i in 7200:
		if game.arena.area == destination or (destination == "memory" and game.state == game.State.MEMORIAL) \
				or (destination == "gate" and game.hero.progression.has("reversal") and game.state == game.State.APPROACH):
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
			var attacking_wolves := 0
			for enemy in game.journey.enemies:
				if game.arena.area == "frozen" and enemy.mode in [enemy.Mode.WIND,enemy.Mode.ACTIVE]:
					attacking_wolves += 1
				if not enemy.dead and (nearest == null or absf(enemy.position.x-h.position.x) < absf(nearest.position.x-h.position.x)):
					nearest = enemy
			if attacking_wolves > 1:
				verify(false,"Werewolf attacks overlap")
				set_keys([])
				return false
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
			if game.arena.area == "road" and game.hero.position.x > 1630 and game.hero.position.x < 1810 and KEY_SPACE not in desired and i % 45 < 27:
				desired.append(KEY_SPACE)
			for obstacle: float in game.arena.OBSTACLES.get(game.arena.area,[]):
				if game.hero.position.x > obstacle-66.0 and game.hero.position.x < obstacle+32.0 and i % 47 < 27:
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
	if game.arena.area == "shrine":
		h.position.x = game.arena.exit_x-420.0
		h.velocity = Vector2.ZERO
		await press(KEY_D)
	await press(KEY_U)
	await wait_ticks(12)
	verify(game.powers.waves.size() == 1,"Soul Sever launches once on the animation impact")
	await capture("soul-sever")
	await wait_ticks(53)
	verify(game.journey.defeated.has("sever_target"),"Soul Sever breaks the ranged shrine seal")
	h.energy = stats.energy_limit

func check_overlord_damage() -> void:
	var b = game.overlord
	var h = game.hero
	var values := [[1,"cleave",0,18],[1,"rush",0,30],[2,"ruin",0,37],[3,"throne",2,40]]
	for spec: Array in values:
		b.stage = spec[0]
		b.attack = spec[1]
		b.stats = b.profile.get_value("attacks",b.attack)
		b.mode = b.Mode.ACTIVE
		b.serial += 1
		h.enable()
		h.iframe = 0
		h.health = h.maximum
		b.send_strike(h.hurtbox(),false,spec[2])
		verify(h.health == h.maximum-int(spec[3]),"Overlord applies %d damage for %s" % [spec[3],b.attack])
	game.enter_duel()

func check_single_hit() -> void:
	var b = game.boss
	b.mode = b.Mode.RECOVER
	var before: int = b.health
	game.hero.strike_id += 1
	var strike := Strike.new(b.hurtbox(),32,1,false,"light_1",game.hero.strike_id)
	game.hero_strike(strike)
	game.hero_strike(strike)
	verify(before-b.health == 32,"Repeated active hitboxes register one melee hit")

func check_phase_queue() -> void:
	var b = game.boss
	var transitions: Array[int] = []
	var record := func(state: int) -> void:
		if state == game.State.TRANSITION:
			transitions.append(game.next_stage)
	game.state_changed.connect(record)
	b.health = 560
	game.powers.echo_armed = true
	game.hero_strike(Strike.new(b.hurtbox(),4000,1,false,"test",game.hero.strike_id+1))
	verify(b.health == 40 and game.state == game.State.TRANSITION and game.next_stage == 2,"Large hit stops at 40 HP and starts phase two")
	verify(not game.powers.echo_armed and game.powers.echoes.is_empty(),"A threshold cinematic clears the pending Echo")
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
	var charges: int = game.hero.progression.charges
	var level: int = h.resurrection_level
	h.position.x = b.position.x - 103.0
	h.health = 30
	game.hero.energy = game.hero.progression.energy_limit
	await press(KEY_Q)
	verify(game.state == game.State.RESURRECTING and game.reversal and game.hero.progression.charges == charges-1
		and game.hero.energy == 0.0, "Q spends one charge and the full meter")
	await press(KEY_Q)
	verify(game.hero.progression.charges == charges-1, "Death Reversal cannot overlap itself")
	await capture("death-reversal")
	verify(await until_state(game.State.FIGHT,90), "Death Reversal returns to the fight")
	verify(h.health == h.maximum and h.resurrection_level == level+1 and b.health < 510 and b.stage == 2,
		"Death Reversal heals, grows power, and hits the nearby boss")
	var boss_hp: int = b.health
	h.energy = h.progression.energy_limit
	await press(KEY_Q)
	verify(game.state == game.State.FIGHT and game.hero.progression.charges == charges-1, "Cooldown prevents an immediate second reversal")
	h.iframe = 0.0
	var nonlethal := Strike.new(h.hurtbox(),1,-1,false,"test_hit",8099)
	var initial_hp: int = h.health
	game.boss_strike(nonlethal)
	h.iframe = 0.0
	game.boss_strike(nonlethal)
	verify(h.health == initial_hp-1,"One enemy strike cannot damage the player twice")
	for i in charges-1:
		h.iframe = 0
		game.boss_strike(Strike.new(h.hurtbox(), h.maximum, -1, false, "test_lethal", 8100+i))
		verify(game.state == game.State.RESURRECTING and game.hero.progression.charges == charges-2-i, "Fatal hit spends one automatic charge")
		await wait_ticks(ceili(game.resurrection_duration()*game.BETWEEN_OPEN*60)+3)
		verify(game.state == game.State.RESURRECTING and game.clock/game.resurrection_duration() < game.BETWEEN_CLOSE,
			"Automatic resurrection shows the same Between briefly")
		if i == 0:
			await capture("between-brief")
		verify(await until_state(game.State.FIGHT,90), "Automatic resurrection resumes combat")
		verify(b.health == boss_hp and b.stage == 2 and h.iframe > .9, "Automatic resurrection preserves boss HP and phase")
	h.iframe = 0
	game.boss_strike(Strike.new(h.hurtbox(), h.maximum, -1, false, "test_lethal", 8199))
	verify(game.state == game.State.DEFEAT, "Death with zero charges opens game over")
	await press(KEY_R)
	verify(game.state == game.State.FIGHT and b.health == b.maximum and game.hero.progression.charges == 3
		and h.resurrection_level == level and h.maximum == 220, "Retry restores checkpoint soul level, abilities, health and charges")

func play_duel(side_boss: bool = false) -> bool:
	var wait_after_stage := 0
	var last_stage: int = game.boss.stage
	var attack_count := 0
	var previous_attack := ""
	for i in 11000:
		if game.state in [game.State.FLASH_PREP, game.State.DEFEAT, game.State.MEMORIAL]:
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
		if not side_boss and b.stage == 1 and attack_count < 3 and b.health < 385:
			desired.erase(KEY_J)
		attacks[b.stage] = true
		set_keys(desired)
		await physics_frame
	set_keys([])
	print("Duel result: state ", game.state, ", stage ", game.boss.stage, ", boss HP ", game.boss.health,
		", hero HP ", game.hero.health, ", parries ", game.parries, ", seconds ", game.fight_time)
	return game.state == (game.State.MEMORIAL if side_boss else game.State.FLASH_PREP)

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
