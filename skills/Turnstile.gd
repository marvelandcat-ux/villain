class_name Turnstile
extends StaticBody2D

## 지하철 아저씨 스킬1이 만드는 개찰구 장애물 — 낮아서 점프로만 넘을 수 있고, 시간이 지나면 사라진다
@export var lifetime: float = 5.0

func _ready() -> void:
	Timers.self_destruct(self, lifetime)
