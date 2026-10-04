class_name VacuumSkill
extends Skill

## 청소기 흡입 — 전방 상대를 잠깐 끌어당긴다 (쓰는 캐릭터 없음 — 옛 층간소음 청년 스킬2였다)
@export var range: float = 110.0
@export var damage: int = 4
@export var pull_strength: float = 300.0
@export var active_duration: float = 0.3

@onready var hitbox: Hitbox = $Hitbox

func _execute(fighter: Fighter) -> void:
	hitbox.damage = fighter.compute_damage(damage)
	hitbox.source_fighter = fighter
	hitbox.pull_to_source = true
	hitbox.pull_strength = pull_strength
	hitbox.global_position = fighter.global_position + Vector2(fighter.facing * range * 0.6, 0)
	hitbox.monitoring = true
	hitbox.monitorable = true
	await get_tree().create_timer(active_duration).timeout
	hitbox.monitoring = false
	hitbox.monitorable = false
