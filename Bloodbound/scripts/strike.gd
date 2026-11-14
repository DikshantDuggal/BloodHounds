extends RefCounted

var box: Rect2
var damage: float
var direction: float
var parryable: bool
var source: String
var id: int
var knockback := 264.0

func _init(area: Rect2, strength: float, facing: float, can_parry: bool, tag: String, token: int) -> void:
	box = area
	damage = strength
	direction = facing
	parryable = can_parry
	source = tag
	id = token

func hit_channel() -> String:
	return source if source in ["sever","echo","reversal","counter"] else "melee"

static func forward(origin: Vector2, facing: float, reach: float, height: float, behind: float = 20.0) -> Rect2:
	var x := origin.x - behind if facing > 0 else origin.x - reach
	return Rect2(x, origin.y - height, reach + behind, height + 8.0)
