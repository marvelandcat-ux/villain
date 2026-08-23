class_name TauntSkill
extends Skill

## 도발 — 전방 범위 안의 상대를 조롱해서 이동속도를 잠깐 늦춘다.
## 기획 문서에 효과가 미정이었던 오픈 이슈를 임의로 확정한 것 (악플러 스킬1)
@export var range: float = 250.0
@export var slow_multiplier: float = 0.7
@export var duration: float = 3.0

func _execute(fighter: Fighter) -> void:
	var opponent := fighter.find_opponent()
	if opponent == null:
		return
	var dx: float = opponent.global_position.x - fighter.global_position.x
	if absf(dx) <= range and signf(dx) == fighter.facing:
		opponent.apply_temp_multiplier("move_speed_multiplier", slow_multiplier, duration)
