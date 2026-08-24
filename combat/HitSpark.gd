class_name HitSpark
extends Node2D

## 타격 순간 잠깐 커졌다 사라지는 히트 이펙트 (텍스처 없이 도형만으로 구현)
@onready var visual: Polygon2D = $Visual

func _ready() -> void:
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector2(2.2, 2.2), 0.15)
	tween.parallel().tween_property(visual, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
