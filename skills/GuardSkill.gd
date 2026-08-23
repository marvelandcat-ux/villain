class_name GuardSkill
extends Skill

## 팻말 뒤에 숨어서 가드 — 일정 시간 받는 피해를 크게 줄이고, 흡수한 데미지를 기록해둔다.
## 흡수량은 CounterSlamSkill(천사 스킬2)이 반격 데미지로 사용한다 (예수천국 불신지옥 천사 스킬1)
@export var duration: float = 3.0
@export var damage_reduction: float = 0.7

func _execute(fighter: Fighter) -> void:
	fighter.custom_data["guard_absorbed"] = 0
	fighter.damage_reduction = damage_reduction
	get_tree().create_timer(duration).timeout.connect(func(): fighter.damage_reduction = 0.0)
