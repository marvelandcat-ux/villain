class_name RageBuffSkill
extends Skill

## 열등감 느끼기 — 사용하면 일정 시간 자신의 스킬 쿨타임이 더 빨리 돈다(체감상 공격속도 증가).
## 기획 문서에 발동 조건이 미정이었던 오픈 이슈를 액티브 사용식으로 임의 확정한 것 (악플러 스킬2)
@export var cooldown_rate_multiplier: float = 1.5
@export var duration: float = 5.0

func _execute(fighter: Fighter) -> void:
	fighter.apply_temp_multiplier("cooldown_rate_multiplier", cooldown_rate_multiplier, duration)
