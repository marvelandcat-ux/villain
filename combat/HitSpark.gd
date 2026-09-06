class_name HitSpark
extends Node2D

## 타격 순간 잠깐 커졌다 사라지는 히트 이펙트 (텍스처 없이 도형만으로 구현)
@onready var visual: Polygon2D = $Visual

func _ready() -> void:
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector2(2.2, 2.2), 0.15)
	tween.parallel().tween_property(visual, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)

## 맞은 방향(넉백 방향)으로 스파크가 짧게 튀어나가게 한다. Hitbox가 명중 시 호출한다
func launch(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	var t := create_tween()
	t.tween_property(self, "position", position + direction.normalized() * 20.0, 0.15)
