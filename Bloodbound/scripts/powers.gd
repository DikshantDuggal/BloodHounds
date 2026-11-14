extends RefCounted

const Strike = preload("res://scripts/strike.gd")
const LABELS := {"resurrection":"Ancestral Resurrection","phantom":"Phantom Step","sever":"Soul Sever",
	"reversal":"Death Reversal","echo":"Ancestral Echo","flash":"One Flash"}
const KEYS := {"phantom":"E","sever":"U","reversal":"Q","echo":"I","flash":"F"}
const COLORS := {"resurrection":Color("#fa5379"),"phantom":Color("#8fe6ed"),"sever":Color("#cd9ef9"),
	"reversal":Color("#ff7790"),"echo":Color("#ffcf83"),"flash":Color("#fff6e0")}

var cooldowns: Dictionary = {}
var waves: Array[Dictionary] = []
var echoes: Array[Dictionary] = []
var echo_armed := false

# Pending attacks never survive a change of encounter or a cinematic.
func clear_attacks() -> void:
	waves.clear()
	echoes.clear()
	echo_armed = false

func reset() -> void:
	clear_attacks()
	cooldowns.clear()

func ready(hero, ability: String) -> bool:
	var stats = hero.progression
	return stats.has(ability) and float(cooldowns.get(ability,0.0)) <= 0.0 and hero.energy >= cost(stats,ability)

func cost(stats, ability: String) -> float:
	match ability:
		"phantom": return stats.phantom_cost
		"sever": return stats.sever_cost
		"echo": return stats.echo_cost
		"reversal": return stats.energy_limit
	return 0.0

func use(game, ability: String) -> void:
	var hero = game.hero
	var stats = hero.progression
	if not ready(hero,ability) or hero.health <= 0:
		return
	match ability:
		"phantom":
			if not hero.activate_phantom():
				return
			cooldowns[ability] = stats.phantom_cooldown
		"sever":
			if hero.mode != hero.Mode.FREE:
				return
			hero.begin_attack("sever")
			cooldowns[ability] = stats.sever_cooldown
		"echo":
			if echo_armed or hero.mode not in [hero.Mode.FREE,hero.Mode.ATTACK]:
				return
			echo_armed = true
			cooldowns[ability] = stats.echo_cooldown
			game.effects.ghost(hero.position,hero.facing,COLORS.echo)
			game.effects.blade_echo(game.hero_art.weapon_pivot.global_transform,COLORS.echo,Vector2(-hero.facing*34,0))
			game.sound.cue("buildup")
	hero.energy -= cost(stats,ability)

func launch_sever(hero) -> void:
	var stats = hero.progression
	hero.strike_id += 1
	waves.append({"at":hero.position+Vector2(hero.facing*44,-41),"facing":hero.facing,
		"power":stats.attack_power(1.45),"id":hero.strike_id,"life":stats.sever_duration})

func capture_echo(hero, strike) -> void:
	if echo_armed and strike.source not in ["sever","echo","reversal"]:
		echo_armed = false
		echoes.append({"strike":Strike.new(strike.box,strike.damage*.7,strike.direction,false,"echo",strike.id),
			"at":hero.position,"life":hero.progression.echo_delay})

func tick(game,dt:float) -> void:
	for ability: String in cooldowns:
		cooldowns[ability] = maxf(0,float(cooldowns[ability])-dt)
	var previous_state: int = game.state
	for index in range(waves.size()-1,-1,-1):
		var wave := waves[index]
		var old: Vector2 = wave.at
		wave.at += Vector2(game.hero.progression.sever_speed*wave.facing*dt,0)
		wave.life -= dt
		if wave.life <= 0.0 or wave.at.x < 80.0 or wave.at.x > game.arena.area_width-80.0:
			waves.remove_at(index)
			continue
		var box := Rect2(minf(old.x,wave.at.x)-20,old.y-35,absf(old.x-wave.at.x)+40,70)
		game.hero_strike(Strike.new(box,wave.power,wave.facing,false,"sever",wave.id))
		if game.state != previous_state:
			return
	for index in range(echoes.size()-1,-1,-1):
		var echo := echoes[index]
		echo.life -= dt
		if echo.life <= 0.0:
			echoes.remove_at(index)
			game.effects.ghost(echo.at,echo.strike.direction,COLORS.echo,1.12)
			game.effects.blade_echo(game.hero_art.weapon_pivot.global_transform,COLORS.echo,echo.at-game.hero.position-Vector2(echo.strike.direction*24,0))
			game.effects.arc(echo.at+Vector2(0,-40),echo.strike.direction,90,COLORS.echo)
			game.hero_strike(echo.strike)
			if game.state != previous_state:
				return
