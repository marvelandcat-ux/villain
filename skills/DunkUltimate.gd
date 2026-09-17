class_name DunkUltimate
extends Skill

## 농구공 덩크 — 상대 쪽으로 짧게 도약한 뒤 착지 지점에 큰 데미지의 범위 공격을 낸다 (층간소음 청년 궁극기)
## 도약 중 가로로 나아가는 속도(px/초)
@export var leap_speed: float = 500.0
## 도약이 유지되는 시간(초) — 이 시간이 지나면 착지해 내리찍는다
@export var leap_duration: float = 0.35
## 도약 시작 순간 위로 튀는 속도(px/초, 음수가 위쪽)
@export var jump_velocity: float = -450.0
## 착지 지점 범위 공격 데미지
@export var damage: int = 20
## 착지 판정이 켜져 있는 시간(초)
@export var slam_active_duration: float = 0.15

var _time_left: float = 0.0
var _direction: float = 1.0

## 착지 지점에서 켰다 끄는 범위 공격 판정
@onready var hitbox: Hitbox = $Hitbox

func _execute(fighter: Fighter) -> void:
	_time_left = leap_duration
	_direction = fighter.facing
	fighter.velocity.y = jump_velocity
	fighter.movement_override = self

## `Fighter.movement_override` 인터페이스 — 도약 중 가로 이동 속도를 이 스킬이 대신 정한다
func get_move_velocity_x() -> float:
	return _direction * leap_speed

## `Fighter.movement_override` 인터페이스 — 매 물리 프레임 끝에 호출된다. 도약 시간이 다 되면 착지 처리로 넘어간다
func after_physics(fighter: Fighter, delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		fighter.movement_override = null
		_slam(fighter)

func _slam(fighter: Fighter) -> void:
	hitbox.damage = fighter.compute_damage(damage)
	hitbox.source_fighter = fighter
	hitbox.global_position = fighter.global_position
	hitbox.monitoring = true
	hitbox.monitorable = true
	await get_tree().create_timer(slam_active_duration).timeout
	hitbox.monitoring = false
	hitbox.monitorable = false
