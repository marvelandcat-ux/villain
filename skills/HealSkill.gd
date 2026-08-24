class_name HealSkill
extends Skill

## 자신의 HP를 회복하는 스킬 (잼민이 궁극기 "엄마가 부르면 집 가서 밥 먹고 옴")
## 회복량/쿨타임은 밸런스 미확정 임시값 (오픈 이슈)
@export var heal_amount: int = 30
## 밥 먹으러 집에 다녀오는 연출 — 그 사이엔 무적 (오픈 이슈였던 "궁극기 중 무적 여부"를 무적으로 확정)
@export var invincible_duration: float = 1.0

func _execute(fighter: Fighter) -> void:
	fighter.heal(heal_amount)
	fighter.grant_invincibility(invincible_duration)
	# 무적인 동안 초록빛으로 빛나서 "지금은 못 맞는다"는 걸 눈으로 알 수 있게 함
	fighter.set_tint("heal_glow", Color(0.6, 1.0, 0.6), invincible_duration)
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual:
		var tween := fighter.create_tween()
		tween.tween_property(visual, "scale", Vector2(1.3, 1.3), 0.15)
		tween.tween_property(visual, "scale", Vector2(1, 1), 0.25)
