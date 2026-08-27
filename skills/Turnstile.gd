class_name Turnstile
extends StaticBody2D

## 지하철빌런 스킬1이 만드는 개찰구 장애물 — 낮아서 점프로만 넘을 수 있고, 시간이 지나면 사라진다
@export var lifetime: float = 5.0

func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()
