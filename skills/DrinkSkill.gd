class_name DrinkSkill
extends Skill

## 술(소주) 마시기 — 마실수록 스택이 쌓여 토하기 위력이 세지고, 자신의 이동속도는 느려진다 (주정뱅이 스킬1)
@export var max_stacks: int = 5
@export var move_speed_penalty_per_stack: float = 0.08

func _execute(fighter: Fighter) -> void:
	var stacks: int = fighter.custom_data.get("drink_stacks", 0)
	stacks = mini(stacks + 1, max_stacks)
	fighter.custom_data["drink_stacks"] = stacks
	fighter.set_modifier("move_speed_multiplier", "drink_stacks", 1.0 - stacks * move_speed_penalty_per_stack)
	# 마실수록 점점 빨개진다 (기획 문서 그대로 구현)
	var redness: float = float(stacks) / float(max_stacks)
	fighter.set_tint("drunk", Color(1.0, 1.0 - redness * 0.6, 1.0 - redness * 0.6))
