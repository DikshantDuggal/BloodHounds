extends Resource

const Damage = preload("res://scripts/damage.gd")

@export var health_by_level := PackedInt32Array([120,140,160,180,200,220])
@export var attack_by_level := PackedInt32Array([20,22,24,26,28,30])
@export var unlocks := PackedStringArray(["resurrection","phantom","sever","reversal","echo","flash"])
@export var starting_abilities := PackedStringArray()
@export var heavy_multiplier := 1.8
@export var critical_multiplier := 1.5
@export var soul_cap := 5
@export var soul_step := .10
@export var charge_limit := 3
@export var energy_limit := 100.0
@export var phantom_cost := 20.0
@export var phantom_cooldown := 3.5
@export var phantom_speed := 1080.0
@export var phantom_duration := .23
@export var sever_cost := 25.0
@export var sever_cooldown := 2.2
@export var sever_speed := 540.0
@export var sever_duration := .86
@export var echo_cost := 25.0
@export var echo_cooldown := 5.0
@export var echo_delay := .25

var level := 1
var unlocked: PackedStringArray
var soul_level := 0:
	set(value):
		soul_level = clampi(value,0,soul_cap)
var charges := 3:
	set(value):
		charges = clampi(value,0,charge_limit)
var energy := 0.0:
	set(value):
		energy = clampf(value,0,energy_limit)
var health := 120:
	set(value):
		health = Damage.clamp_health(value,maximum)
var maximum: int:
	get:
		return health_by_level[level-1]
var base_attack: int:
	get:
		return attack_by_level[level-1]

func reset() -> void:
	level = 1
	soul_level = 0
	charges = charge_limit
	energy = 0.0
	unlocked = starting_abilities.duplicate()
	heal()

func enter_level(value: int) -> void:
	if value > level:
		level = mini(value,health_by_level.size())
		heal()

func unlock_for(value: int) -> String:
	var ability := unlocks[value-1]
	if has(ability):
		return ""
	unlocked.append(ability)
	return ability

func has(ability: String) -> bool:
	return ability in unlocked

func heal() -> void:
	health = maximum

func refill() -> void:
	heal()
	charges = charge_limit

func resurrect() -> void:
	soul_level += 1
	heal()

func attack_power(multiplier: float, heavy: bool = false, critical: bool = false) -> float:
	var power := float(base_attack) * multiplier * (1.0 + soul_step * soul_level)
	if heavy:
		power *= heavy_multiplier
	if critical:
		power *= critical_multiplier
	return power

func snapshot() -> Dictionary:
	return {"level":level,"soul":soul_level,"unlocked":unlocked.duplicate(),"energy":energy}

func restore(saved: Dictionary) -> void:
	level = saved.level
	soul_level = saved.soul
	unlocked = saved.unlocked.duplicate()
	energy = saved.energy
	refill()
