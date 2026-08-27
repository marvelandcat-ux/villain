class_name TteokbokkiUltimate
extends Skill

## 떡볶이 국물 흘리기 — 일정 시간 동안 전방으로 이동하며 바닥에 뜨거운 국물 자국(FirePlate 재사용)을 흘린다.
## 기획에는 "궁 키를 누르고 있는 동안 이동"이라고 되어 있으나, 지금 조작 체계는 원샷 입력이라
## 고정 시간 채널로 단순화했다(오픈 이슈) (지하철빌런 궁극기)
@export var channel_duration: float = 2.5
@export var move_speed: float = 150.0
@export var drop_interval: float = 0.3
@export var plate_scene: PackedScene

var _time_left: float = 0.0
var _drop_timer: float = 0.0
var _direction: float = 1.0

func _execute(fighter: Fighter) -> void:
	_time_left = channel_duration
	_drop_timer = 0.0
	_direction = fighter.facing
	fighter.movement_override = self

func get_move_velocity_x() -> float:
	return _direction * move_speed

func after_physics(fighter: Fighter, delta: float) -> void:
	_time_left -= delta
	_drop_timer -= delta
	if _drop_timer <= 0.0:
		_drop_timer = drop_interval
		_drop_broth(fighter)
	if _time_left <= 0.0 or fighter.is_on_wall():
		fighter.movement_override = null

func _drop_broth(fighter: Fighter) -> void:
	if plate_scene == null:
		return
	var plate: FirePlate = plate_scene.instantiate()
	fighter.get_parent().add_child(plate)
	plate.global_position = fighter.global_position + Vector2(0, 30)
	plate.source_fighter = fighter
