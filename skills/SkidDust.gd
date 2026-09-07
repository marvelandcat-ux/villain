class_name SkidDust
extends Node2D

## 자전거 뒷바퀴가 바닥에 마찰되며 튀는 먼지 한 조각 (순수 장식). 바닥 색으로 칠해 뒤로 흩날리며 사라진다.
## DashSkill이 돌진 중 뒷바퀴 위치에서 주기적으로 스폰하고 setup(색, 진행방향)으로 값을 넘긴다.

## 뒤로 흩어지는 거리(px)
@export var drift: float = 22.0
## 사라지는 데 걸리는 시간(초)
@export var lifetime: float = 0.35

@onready var _puff: Polygon2D = $Puff

## 바닥 색으로 칠하고, 진행 방향의 반대(뒤)로 살짝 위로 흩날리며 커졌다 사라진다
func setup(color: Color, direction: float) -> void:
	_puff.color = color
	rotation = randf_range(-0.3, 0.3)
	var s: float = randf_range(0.7, 1.2)
	scale = Vector2(s, s)
	# 진행 반대쪽으로 흩어지며 살짝 떠오른다
	var target: Vector2 = position + Vector2(-direction * drift * randf_range(0.6, 1.2), -randf_range(4.0, 12.0))
	var tween := create_tween()
	tween.tween_property(self, "position", target, lifetime).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", scale * 1.6, lifetime)
	tween.parallel().tween_property(self, "modulate:a", 0.0, lifetime)
	tween.tween_callback(queue_free)
