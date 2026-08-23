class_name Skill
extends Node

## 모든 스킬의 공용 베이스 — 쿨타임 관리와 use(fighter) 인터페이스를 제공한다.
## 실제 효과는 하위 클래스가 _execute(fighter)를 오버라이드해서 구현한다.
@export var cooldown: float = 1.0

var cooldown_left: float = 0.0

func _process(delta: float) -> void:
	if cooldown_left <= 0.0:
		return
	var fighter := get_parent() as Fighter
	var rate: float = fighter.cooldown_rate_multiplier if fighter else 1.0
	cooldown_left -= delta * rate

func can_use() -> bool:
	return cooldown_left <= 0.0

## 스킬을 사용한다. 쿨타임이 남아있으면 아무 일도 일어나지 않는다
func use(fighter: Fighter) -> void:
	if not can_use():
		return
	cooldown_left = cooldown
	_execute(fighter)

## 하위 클래스가 실제 효과를 구현하는 곳
func _execute(_fighter: Fighter) -> void:
	pass
