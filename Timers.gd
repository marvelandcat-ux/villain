class_name Timers
extends RefCounted

## `get_tree().create_timer()` 대신 owner의 자식 Timer로 지연 실행을 예약하는 공용 헬퍼.
## `get_tree().create_timer()`는 SceneTree에 매여서 owner보다 오래 살아남는다 — owner가
## 그 전에 사라지면(대전 도중 나가기·다시하기 등으로 씬이 정리되는 경우) 이미 해제된 노드를
## 건드리려다 "Lambda capture ... was freed" 에러가 난다. owner의 자식으로 만들면 owner가
## 사라질 때 Timer도 같이 사라져서 콜백 자체가 실행되지 않는다(Fighter._after 등 여러 곳이
## 각자 이 코드를 들고 있던 것을 한 곳으로 모음).

## owner의 자식 Timer를 만들어 시작한다. cb를 주면 delay초 뒤 한 번 부르고 타이머 자신을 정리한다.
## cb 없이 반환된 Timer만 받아 `await timer.timeout`처럼 직접 기다려도 된다(그때는 호출자가
## 다 쓴 뒤 timer.queue_free()를 불러줄 것).
## real_time을 켜면 Engine.time_scale(슬로우 연출)과 상관없이 실제 초로 잰다(카운터 슬로우 연출)
static func after(owner: Node, delay: float, cb: Callable = Callable(), real_time: bool = false) -> Timer:
	var timer := Timer.new()
	timer.wait_time = delay
	timer.one_shot = true
	timer.ignore_time_scale = real_time
	owner.add_child(timer)
	if cb.is_valid():
		timer.timeout.connect(func() -> void:
			cb.call()
			timer.queue_free())
	timer.start()
	return timer

## lifetime초 뒤 target을 스스로 지운다(장식 이펙트·투사체 등의 "얼마 지나면 사라진다" 패턴)
static func self_destruct(target: Node, lifetime: float) -> Timer:
	return after(target, lifetime, target.queue_free)
