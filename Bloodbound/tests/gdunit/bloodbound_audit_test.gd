extends GdUnitTestSuite

const WORLD = preload("res://scenes/Throne.tscn")
const ENEMY = preload("res://scenes/Enemy.tscn")
const DAMAGE = preload("res://scripts/damage.gd")
const STRIKE = preload("res://scripts/strike.gd")
const STATS = preload("res://resources/player_progression.tres")


func test_damage_boundaries() -> void:
	assert_int(DAMAGE.remaining(10, 0)).is_equal(10)
	assert_int(DAMAGE.remaining(10, 1)).is_equal(9)
	assert_int(DAMAGE.remaining(10, 10)).is_equal(0)
	assert_int(DAMAGE.remaining(10, 11)).is_equal(0)
	assert_int(DAMAGE.remaining(800, 10000, 1.0, 40)).is_equal(40)


func test_progression_clamps_and_checkpoints() -> void:
	var stats = STATS.duplicate()
	stats.reset()
	assert_int(stats.health).is_equal(120)
	stats.enter_level(3)
	stats.health = 200
	assert_int(stats.health).is_equal(160)
	assert_str(stats.unlock_for(3)).is_equal("sever")
	assert_str(stats.unlock_for(3)).is_empty()
	for i in 8:
		stats.resurrect()
	assert_int(stats.soul_level).is_equal(5)
	var saved: Dictionary = stats.snapshot()
	stats.reset()
	stats.restore(saved)
	assert_int(stats.health).is_equal(160)
	assert_that(stats.unlocked).is_equal(PackedStringArray(["sever"]))
	assert_float(stats.attack_power(1.0, true, true)).is_equal_approx(97.2, 0.001)


func test_boss_threshold_boundaries() -> void:
	var game = make_game()
	for phase in [
		[1, 520, game.State.TRANSITION],
		[2, 200, game.State.TRANSITION],
		[3, 40, game.State.FLASH_PREP]
	]:
		for offset in [1, 0, -1]:
			game.enter_duel()
			game.boss.stage = phase[0]
			game.boss.health = phase[1] + offset
			game.resolve_boss_phase()
			assert_int(game.state).is_equal(game.State.FIGHT if offset > 0 else phase[2])


func test_first_wolf_parry_deals_damage_once() -> void:
	var wolf = auto_free(ENEMY.instantiate())
	add_child(wolf)
	wolf.setup("hunter")
	wolf.cursor = 1
	wolf.repelled()
	assert_int(wolf.health).is_equal(136)
	wolf.repelled()
	assert_int(wolf.health).is_equal(136)
	var fatal := STRIKE.new(wolf.hurtbox(), 1000, 1, false, "sever", 4)
	assert_bool(wolf.receive(fatal)).is_true()
	assert_bool(wolf.dead).is_true()
	assert_bool(wolf.receive(fatal)).is_false()


func test_resurrection_rejects_invalid_requests() -> void:
	var game = make_game()
	game.enter_duel()
	game.start_resurrection(false)
	assert_int(game.state).is_equal(game.State.FIGHT)
	game.enter_duel()
	game.start_resurrection(true)
	assert_int(game.state).is_equal(game.State.FIGHT)
	game.enter_duel()
	game.hero.health = 0
	game.hero.progression.charges = 0
	game.start_resurrection(false)
	assert_int(game.state).is_equal(game.State.FIGHT)


func test_skip_applies_curse_and_new_game_cleans_up() -> void:
	var game = make_game()
	game.enter_duel()
	game.boss.health = 0
	game.transition_to(game.State.EXECUTE)
	game.finish()
	game.skip_cinematic()
	assert_int(game.state).is_equal(game.State.VICTORY)
	assert_bool(game.curse_active).is_true()
	assert_float(game.arena.oath_stone).is_greater(0.0)
	assert_bool(game.hero_art.weapon_sprite.is_visible_in_tree()).is_true()
	game.set_paused(true)
	game.to_title()
	game.begin()
	assert_int(game.state).is_equal(game.State.VILLAGE)
	assert_bool(game.paused or game.curse_active).is_false()
	assert_int(game.hero.health).is_equal(120)
	assert_bool(game.hero.progression.unlocked.is_empty()).is_true()
	assert_float(game.arena.oath_stone).is_zero()


func test_checkpoint_restores_defeated_pack_and_gate() -> void:
	var game = make_game()
	game.begin()
	game.journey.enter("frozen", 600.0)
	for wolf in game.journey.enemies:
		wolf.receive(STRIKE.new(wolf.hurtbox(), 1000, 1, false, "sever", 1))
	game.journey.tick_pack(1.1)
	assert_bool(game.hero.progression.has("reversal")).is_true()
	var checkpoint_x: float = game.journey.checkpoint_x
	game.journey.retry()
	assert_str(game.arena.area).is_equal("frozen")
	assert_float(game.hero.position.x).is_equal(checkpoint_x)
	assert_int(game.journey.enemy_count()).is_equal(0)
	assert_bool(game.arena.exit_open).is_true()


func test_title_resets_side_boss_and_game_over() -> void:
	var game = make_game()
	game.begin()
	game.journey.enter("shrine", 720.0)
	game.show_side_boss()
	game.start_side_fight()
	game.boss.health = 0
	game.resolve_boss_phase()
	assert_int(game.state).is_equal(game.State.MEMORIAL)
	game.to_title()
	game.begin()
	assert_int(game.sovereign.health).is_equal(game.sovereign.maximum)
	assert_bool(game.journey.defeated.is_empty()).is_true()
	game.enter_duel()
	game.hero.health = 0
	game.hero.progression.charges = 0
	game.hero_died()
	assert_int(game.state).is_equal(game.State.DEFEAT)
	game.to_title()
	game.begin()
	assert_int(game.state).is_equal(game.State.VILLAGE)
	assert_int(game.hero.progression.charges).is_equal(3)
	assert_int(game.hero.health).is_equal(120)


func make_game():
	var game = auto_free(WORLD.instantiate())
	add_child(game)
	return game
