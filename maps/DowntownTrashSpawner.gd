extends Node2D

## 번화가 쓰레기 기믹(2026-10-08). `interval`초마다 자식 쓰레기통(`DowntownTrashCan`) 중
## **하나를 랜덤으로** 골라 쓰레기를 `min_count`~`max_count`개 뱉게 한다.
## 나온 쓰레기는 이 노드의 자식으로 붙어 **안 주우면 계속 쌓인다**(사용자 결정).
## 트리가 멈추면(클래시 팝업 등) 같이 멈춘다 — `_process`로 센다

@export var interval: float = 10.0
@export var min_count: int = 3
@export var max_count: int = 5

var _time_left: float

func _ready() -> void:
	_time_left = interval

func _process(delta: float) -> void:
	_time_left -= minf(delta, 0.05)
	if _time_left > 0.0:
		return
	_time_left = interval
	var cans: Array[Node] = []
	for child in get_children():
		if child.has_method("burst"):
			cans.append(child)
	if cans.is_empty():
		return
	cans.pick_random().burst(randi_range(min_count, max_count))
