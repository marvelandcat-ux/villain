class_name TteokbokkiUltimate
extends Skill

## 떡볶이 국물 흘리기 — 일정 시간 동안 전방으로 이동하며 바닥에 뜨거운 국물 자국(FirePlate 재사용)을 흘린다.
## 기획에는 "궁 키를 누르고 있는 동안 이동"이라고 되어 있으나, 지금 조작 체계는 원샷 입력이라
## 고정 시간 채널로 단순화했다(오픈 이슈) (지하철 아저씨 궁극기)
## 전진하며 국물을 흘리는 전체 시간(초)
@export var channel_duration: float = 2.5
## 전진 속도(px/초)
@export var move_speed: float = 150.0
## 국물 자국을 몇 초마다 흘릴지
@export var drop_interval: float = 0.3
## 흘릴 국물 자국(FirePlate 재사용) 씬
@export var plate_scene: PackedScene

var _time_left: float = 0.0
var _drop_timer: float = 0.0
var _direction: float = 1.0

func _execute(fighter: Fighter) -> void:
	_time_left = channel_duration
	_drop_timer = 0.0
	_direction = fighter.facing
	fighter.movement_override = self

## `Fighter.movement_override` 인터페이스 — 채널링 중 가로 이동 속도를 이 스킬이 대신 정한다
func get_move_velocity_x() -> float:
	return _direction * move_speed

## `Fighter.movement_override` 인터페이스 — 매 물리 프레임 끝에 호출된다. 국물을 흘리고, 시간이 다 되거나 벽에 막히면 끝낸다
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
