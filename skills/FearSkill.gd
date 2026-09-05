class_name FearSkill
extends Skill

## 공포 단소 — 단소로 때리는 척을 해서 전방 범위의 상대를 공포 상태로 만든다(기본공격/스킬 사용 불가) (지하철 아저씨 스킬2)
@export var range: float = 150.0
@export var duration: float = 2.5

func _execute(fighter: Fighter) -> void:
	var opponent := fighter.find_opponent()
	if opponent == null:
		return
	var dx: float = opponent.global_position.x - fighter.global_position.x
	if absf(dx) <= range and signf(dx) == fighter.facing:
		opponent.apply_fear(duration)
