class_name WeakenAuraUltimate
extends Skill

## 실시간 급상승 — 자신의 이름이 실검에 뜨며 상대가 "나락"을 감, 상대의 모든 계수를 10초간 떨어뜨린다 (악플러 궁극기)
@export var slow_multiplier: float = 0.7
@export var attack_debuff_multiplier: float = 0.7
@export var duration: float = 10.0

func _execute(fighter: Fighter) -> void:
	var opponent := fighter.find_opponent()
	if opponent == null:
		return
	opponent.apply_temp_multiplier("move_speed_multiplier", slow_multiplier, duration)
	opponent.apply_temp_multiplier("attack_debuff_multiplier", attack_debuff_multiplier, duration)
