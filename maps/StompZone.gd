class_name StompZone
extends Node2D

## 위층에서 뛰어내려 세게 착지하면 착지 지점 주변에 충격파를 일으키는 층간소음 맵 기믹.
## 착지 순간(방금까지 공중에 있다가 바닥에 닿음)의 낙하 속도가 기준치를 넘으면 발동한다
@export var fall_speed_threshold: float = 280.0
@export var damage: int = 12
@export var radius: float = 90.0

var _was_on_floor: Dictionary = {}
var _last_velocity_y: Dictionary = {}

func _process(_delta: float) -> void:
	for f in get_tree().get_nodes_in_group("fighters"):
		var prev_on_floor: bool = _was_on_floor.get(f, true)
		var prev_vy: float = _last_velocity_y.get(f, 0.0)
		if f.is_on_floor() and not prev_on_floor and prev_vy > fall_speed_threshold:
			_shockwave(f)
		_was_on_floor[f] = f.is_on_floor()
		_last_velocity_y[f] = f.velocity.y

func _shockwave(source: Fighter) -> void:
	for f in get_tree().get_nodes_in_group("fighters"):
		if f == source or not is_instance_valid(f):
			continue
		if f.global_position.distance_to(source.global_position) <= radius:
			# 맵 기믹이라 방어로 못 막는다 (마지막 인자 ignore_guard)
			f.take_map_damage(damage, Vector2(0, -150))
