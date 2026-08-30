class_name DrunkenRageSkill
extends Skill

## 원샷 강화 — 술을 한 번에 들이켜 duration초 동안 받는 피해를 damage_reduction만큼 줄이고,
## 그 사이에 나가는 "다음 공격 한 번"(기본공격이든 다른 스킬이든 상관없이)에 bonus_damage를 더해준다.
## 리그 오브 레전드 그라가스의 W "취기" 모티브 (주정뱅이 스킬1)
## 쓸 때마다 custom_data["cannon_stacks"]가 하나씩 쌓인다 — 스킬2(BloodCannonSkill)가 이 스택 수만큼
## 레이저 길이를 늘리고, 스킬2를 쏘고 나면 스택은 다시 0으로 돌아간다
@export var duration: float = 4.0
@export var damage_reduction: float = 0.3
@export var bonus_damage: int = 14

func _execute(fighter: Fighter) -> void:
	fighter.damage_reduction = damage_reduction
	fighter.custom_data["rage_bonus_damage"] = bonus_damage
	fighter.custom_data["cannon_stacks"] = fighter.custom_data.get("cannon_stacks", 0) + 1
	fighter.set_tint("drunken_rage", Color(1.0, 0.55, 0.55))

	# GuardSkill.gd와 동일한 이유로 이 스킬 노드의 자식 Timer를 쓴다 —
	# fighter가 duration이 끝나기 전에 사라지면(대전 도중 나가기 등) 이 노드도 같이 사라져
	# 이미 없어진 fighter를 건드리려는 에러 없이 콜백 자체가 실행되지 않는다
	var timer := Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(func():
		fighter.damage_reduction = 0.0
		fighter.custom_data["rage_bonus_damage"] = 0
		fighter.clear_tint("drunken_rage")
		timer.queue_free()
	)
	timer.start()
