extends Node

## 타격 순간 게임 전체를 아주 잠깐 멈춰(Engine.time_scale=0) 타격감을 주는 오토로드 (hit-stop / hit-pause).
## Hitbox가 명중했을 때 hit()을 부른다. 여러 히트가 겹쳐도 가장 늦게 끝나는 시점까지 유지되도록
## "세대(generation)" 번호로 관리한다 — 새 히트가 들어오면 이전 타이머의 복구는 무시된다.

var _gen: int = 0

## duration초 동안 시간을 멈춘다. time_scale=0이라도 실시간으로 흐르는 타이머(ignore_time_scale)로 복구한다
func hit(duration: float = 0.06) -> void:
	Engine.time_scale = 0.0
	_gen += 1
	var my_gen: int = _gen
	# create_timer(시간, process_always, process_in_physics, ignore_time_scale)
	await get_tree().create_timer(duration, true, false, true).timeout
	# 멈춰 있는 사이 새 히트가 없었을 때만 원래 속도로 되돌린다
	if my_gen == _gen:
		Engine.time_scale = 1.0
