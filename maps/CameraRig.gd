class_name CameraRig
extends Camera2D

## 두 파이터의 중간 지점을 부드럽게 따라가는 카메라
@export var follow_speed: float = 4.0
@export var min_y: float = 100.0
@export var max_y: float = 250.0

func _process(delta: float) -> void:
	var fighters := get_tree().get_nodes_in_group("fighters")
	if fighters.size() < 2:
		return
	var mid: Vector2 = (fighters[0].global_position + fighters[1].global_position) / 2.0
	mid.y = clampf(mid.y, min_y, max_y)
	global_position = global_position.lerp(mid, follow_speed * delta)
