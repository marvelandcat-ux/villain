class_name CrashBurst
extends Node2D

## 자전거가 무언가에 부딪힐 때 터지는 듯한 이펙트 (순수 장식). 중앙 섬광이 확 커졌다 사라지고,
## 조각들이 사방으로 튀어나가며 사라진다. DashSkill이 충돌 지점에서 new()로 만들어 add_child한다.

## 사방으로 튀는 조각 수
@export var shard_count: int = 9
## 조각이 튀어나가는 거리(px)
@export var radius: float = 36.0
## 전체 지속시간(초)
@export var duration: float = 0.3
## 폭발 색 (기본은 충격 느낌의 밝은 주황빛)
@export var color: Color = Color(1.0, 0.8, 0.3, 1.0)

func _ready() -> void:
	z_index = 50   # 캐릭터·이펙트 위에 그린다
	_build_flash()
	_build_shards()
	# 정리: self에 붙인 트윈이라 씬이 정리되면 같이 사라진다 (SceneTree 타이머의 해제-콜백 함정 회피)
	var cleanup := create_tween()
	cleanup.tween_interval(duration + 0.05)
	cleanup.tween_callback(queue_free)

## 중앙에서 확 커졌다 사라지는 팔각 섬광
func _build_flash() -> void:
	var flash := Polygon2D.new()
	flash.color = color
	flash.polygon = PackedVector2Array([
		Vector2(0, -10), Vector2(4, -4), Vector2(10, 0), Vector2(4, 4),
		Vector2(0, 10), Vector2(-4, 4), Vector2(-10, 0), Vector2(-4, -4)])
	add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "scale", Vector2(2.8, 2.8), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, duration)

## 사방으로 튀어나가며 작아지고 사라지는 삼각 조각들
func _build_shards() -> void:
	for i in range(shard_count):
		var ang: float = TAU * float(i) / float(shard_count) + randf_range(-0.18, 0.18)
		var shard := Polygon2D.new()
		shard.color = color
		shard.polygon = PackedVector2Array([Vector2(0, -3), Vector2(10, 0), Vector2(0, 3)])
		shard.rotation = ang
		add_child(shard)
		var dist: float = radius * randf_range(0.7, 1.2)
		var target: Vector2 = Vector2(cos(ang), sin(ang)) * dist
		var tween := create_tween()
		tween.tween_property(shard, "position", target, duration).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(shard, "scale", Vector2(0.3, 0.3), duration)
		tween.parallel().tween_property(shard, "modulate:a", 0.0, duration)
