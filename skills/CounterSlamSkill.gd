class_name CounterSlamSkill
extends Skill

## 팻말 가드로 흡수한 데미지에 비례해 위에서 아래로 내려찍는 반격기 (예수천국 불신지옥 천사 스킬2)
@export var range: float = 50.0
@export var counter_ratio: float = 1.5
@export var min_damage: int = 5
@export var active_duration: float = 0.2
## 내려찍기라서 위가 아니라 아래·바깥쪽으로 넉백
@export var knockback: Vector2 = Vector2(180, 120)

@onready var hitbox: Hitbox = $Hitbox

func _execute(fighter: Fighter) -> void:
	var absorbed: int = fighter.custom_data.get("guard_absorbed", 0)
	var raw_damage: int = maxi(min_damage, int(round(absorbed * counter_ratio)))
	fighter.custom_data["guard_absorbed"] = 0

	hitbox.damage = fighter.compute_damage(raw_damage)
	hitbox.knockback = Vector2(knockback.x * fighter.facing, knockback.y)
	hitbox.source_fighter = fighter
	# Hitbox의 부모(CounterSlamSkill)가 Node2D가 아닌 Node라서 position이 아니라 global_position으로 배치
	hitbox.global_position = fighter.global_position + Vector2(range * fighter.facing, 0)
	hitbox.monitoring = true
	hitbox.monitorable = true
	await get_tree().create_timer(active_duration).timeout
	hitbox.monitoring = false
	hitbox.monitorable = false
