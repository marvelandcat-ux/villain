class_name IgniteSkill
extends Skill

## 팻말에 불붙기 — 전방 범위 안의 상대에게 화상(지속 도트 데미지)을 건다 (예수천국 불신지옥 악마 스킬1)
@export var range: float = 200.0
@export var damage_per_tick: int = 3
@export var tick_interval: float = 1.0
@export var ticks: int = 4

func _execute(fighter: Fighter) -> void:
	var opponent := fighter.find_opponent()
	if opponent == null:
		return
	var dx: float = opponent.global_position.x - fighter.global_position.x
	if absf(dx) <= range and signf(dx) == fighter.facing:
		opponent.apply_dot(fighter.compute_damage(damage_per_tick), tick_interval, ticks)
