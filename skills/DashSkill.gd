class_name DashSkill
extends Skill

## 픽시 돌진 — 브레이크 없이 돌진하다가 벽에 부딪히면 자신이 피해를 입는다 (잼민이 스킬1)
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.3
@export var self_damage_on_wall: int = 10  ## 오픈 이슈 임시값

var _time_left: float = 0.0
var _direction: float = 1.0

func _execute(fighter: Fighter) -> void:
	_time_left = dash_duration
	_direction = fighter.facing
	fighter.movement_override = self

## 돌진 중 매 물리 프레임 적용할 수평 속도 (Fighter.apply_physics에서 호출)
func get_move_velocity_x() -> float:
	return _direction * dash_speed

## Fighter.apply_physics가 move_and_slide 직후 매 프레임 호출한다
func after_physics(fighter: Fighter, delta: float) -> void:
	_time_left -= delta
	if fighter.is_on_wall():
		fighter.take_damage(self_damage_on_wall)
		fighter.movement_override = null
	elif _time_left <= 0.0:
		fighter.movement_override = null
