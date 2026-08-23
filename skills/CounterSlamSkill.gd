class_name CounterSlamSkill
extends Skill

## 팻말 가드로 흡수한 데미지에 비례해 위에서 아래로 내려찍는 반격기 (예수천국 불신지옥 천사 스킬2)
@export var range: float = 50.0
@export var counter_ratio: float = 1.5
@export var min_damage: int = 5
@export var active_duration: float = 0.2

@onready var hitbox: Hitbox = $Hitbox

func _execute(fighter: Fighter) -> void:
	var absorbed: int = fighter.custom_data.get("guard_absorbed", 0)
	var raw_damage: int = maxi(min_damage, int(round(absorbed * counter_ratio)))
	fighter.custom_data["guard_absorbed"] = 0

	hitbox.damage = fighter.compute_damage(raw_damage)
	hitbox.source_fighter = fighter
	hitbox.position.x = range * fighter.facing
	hitbox.monitoring = true
	hitbox.monitorable = true
	await get_tree().create_timer(active_duration).timeout
	hitbox.monitoring = false
	hitbox.monitorable = false
