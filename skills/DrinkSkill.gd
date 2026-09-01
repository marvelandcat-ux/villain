class_name DrinkSkill
extends Skill

## 술(소주) 마시기 — 마실수록 스택이 쌓여 토하기 위력이 세지고, 자신의 이동속도는 느려진다 (주정뱅이 스킬1)
@export var max_stacks: int = 3
@export var move_speed_penalty_per_stack: float = 0.08
## 최대 스택일 때 얼굴이 빨개지는 세기 (0이면 안 빨개지고, 1이면 새빨개진다)
@export_range(0.0, 1.0, 0.05) var max_redness: float = 0.6

func _execute(fighter: Fighter) -> void:
	# 고개를 젖히고 술병을 입으로 가져가는 동작. 아직 임시 사각형을 쓰는 캐릭터는 이 메서드가 없어서 그냥 넘어간다
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("play_drink_motion"):
		visual.play_drink_motion()

	var stacks: int = fighter.custom_data.get("drink_stacks", 0)
	stacks = mini(stacks + 1, max_stacks)
	fighter.custom_data["drink_stacks"] = stacks
	fighter.set_modifier("move_speed_multiplier", "drink_stacks", 1.0 - stacks * move_speed_penalty_per_stack)
	# 마실수록 점점 빨개진다 (기획 문서 그대로 구현)
	var redness: float = float(stacks) / float(max_stacks)
	fighter.set_tint("drunk", Color(1.0, 1.0 - redness * max_redness, 1.0 - redness * max_redness))
