class_name GuardSkill
extends Skill

## 팻말 뒤에 숨어서 가드 — 일정 시간 받는 피해를 크게 줄이고, 흡수한 데미지를 기록해둔다.
## 흡수량은 CounterSlamSkill(천사 스킬2)이 반격 데미지로 사용한다 (예수천국 불신지옥 천사 스킬1)
@export var duration: float = 3.0
@export var damage_reduction: float = 0.7

func _execute(fighter: Fighter) -> void:
	fighter.custom_data["guard_absorbed"] = 0
	fighter.damage_reduction = damage_reduction
	fighter.set_tint("guard", Color(0.55, 0.7, 1.0))
	# 이 스킬 노드 자신의 자식 Timer로 만들어서, fighter가 그 전에 사라지면(씬 정리 등)
	# 이 스킬 노드도 같이 사라져 콜백이 실행되지 않는다 — get_tree().create_timer()는 이미 사라진
	# fighter를 건드리려다 에러가 났었음
	var timer := Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(func():
		fighter.damage_reduction = 0.0
		fighter.clear_tint("guard")
		timer.queue_free()
	)
	timer.start()
