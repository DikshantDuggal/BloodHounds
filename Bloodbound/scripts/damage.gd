extends RefCounted

static func clamp_health(value: int, maximum: int) -> int:
	return clampi(value, 0, maximum)

## Round once, after all modifiers. A positive hit that penetrates defense deals at least 1 HP.
static func amount(power: float, multiplier: float = 1.0) -> int:
	if power <= 0.0 or multiplier <= 0.0:
		return 0
	return maxi(1,roundi(power * multiplier))

static func remaining(health: int, power: float, multiplier: float = 1.0, floor_hp: int = 0) -> int:
	return maxi(mini(health, floor_hp),health - amount(power,multiplier))
