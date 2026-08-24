class_name RageBuffSkill
extends Skill

## 열등감 느끼기 — 사용하면 일정 시간 자신의 스킬 쿨타임이 더 빨리 돈다(체감상 공격속도 증가).
## 기획 문서에 발동 조건이 미정이었던 오픈 이슈를 액티브 사용식으로 임의 확정한 것 (악플러 스킬2)
@export var cooldown_rate_multiplier: float = 1.5
@export var duration: float = 5.0

func _execute(fighter: Fighter) -> void:
	fighter.apply_temp_multiplier("cooldown_rate_multiplier", cooldown_rate_multiplier, duration)
	# 열받아서 씩씩거리는 동안 붉으락푸르락한 오라
	fighter.set_tint("rage", Color(1.0, 0.55, 0.35), duration)
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual:
		var tween := fighter.create_tween()
		tween.set_loops(3)
		tween.tween_property(visual, "scale", Vector2(1.12, 1.12), 0.15)
		tween.tween_property(visual, "scale", Vector2(1, 1), 0.15)
