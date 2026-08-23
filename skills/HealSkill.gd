class_name HealSkill
extends Skill

## 자신의 HP를 회복하는 스킬 (잼민이 궁극기 "엄마가 부르면 집 가서 밥 먹고 옴")
## 회복량/쿨타임은 밸런스 미확정 임시값 (오픈 이슈)
@export var heal_amount: int = 30

func _execute(fighter: Fighter) -> void:
	fighter.heal(heal_amount)
