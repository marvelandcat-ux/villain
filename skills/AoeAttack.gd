class_name AoeAttack
extends Skill

## 자기 중심 원형 범위 공격 공용 스킬 — 전방이 아니라 캐릭터 주변 전체에 판정이 생긴다.
## damage/radius/슬로우 효과를 export로 다르게 지정해서 재사용한다 (층간피해빌런 기타 연주 등)
@export var damage: int = 8
@export var radius: float = 70.0
@export var active_duration: float = 0.2
## 맞은 상대의 이동속도를 slow_multiplier로 slow_duration초 동안 늦춘다 (0이면 슬로우 없음)
@export var slow_multiplier: float = 1.0
@export var slow_duration: float = 0.0

@onready var hitbox: Hitbox = $Hitbox

func _execute(fighter: Fighter) -> void:
	hitbox.damage = fighter.compute_damage(damage)
	hitbox.source_fighter = fighter
	hitbox.global_position = fighter.global_position
	hitbox.monitoring = true
	hitbox.monitorable = true
	if slow_duration > 0.0:
		hitbox.area_entered.connect(_on_hit_apply_slow)
	await get_tree().create_timer(active_duration).timeout
	hitbox.monitoring = false
	hitbox.monitorable = false
	if slow_duration > 0.0 and hitbox.area_entered.is_connected(_on_hit_apply_slow):
		hitbox.area_entered.disconnect(_on_hit_apply_slow)

func _on_hit_apply_slow(area: Area2D) -> void:
	if area is Hurtbox and area.fighter != hitbox.source_fighter:
		area.fighter.apply_temp_multiplier("move_speed_multiplier", slow_multiplier, slow_duration)
