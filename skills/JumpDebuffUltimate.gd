class_name JumpDebuffUltimate
extends Skill

## 소리지르기 — 상대의 점프력을 일정 시간 낮춘다 (주정뱅이 궁극기)
@export var jump_multiplier: float = 0.6
@export var duration: float = 8.0

func _execute(fighter: Fighter) -> void:
	var opponent := fighter.find_opponent()
	if opponent:
		opponent.apply_temp_multiplier("jump_multiplier", jump_multiplier, duration)
