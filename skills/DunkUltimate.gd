class_name DunkUltimate
extends Skill

## 농구공 덩크 — 상대 쪽으로 짧게 도약한 뒤 착지 지점에 큰 데미지의 범위 공격을 낸다 (층간소음 청년 궁극기)
@export var leap_speed: float = 500.0
@export var leap_duration: float = 0.35
@export var jump_velocity: float = -450.0
@export var damage: int = 20
@export var slam_active_duration: float = 0.15

var _time_left: float = 0.0
var _direction: float = 1.0

@onready var hitbox: Hitbox = $Hitbox

func _execute(fighter: Fighter) -> void:
	_time_left = leap_duration
	_direction = fighter.facing
	fighter.velocity.y = jump_velocity
	fighter.movement_override = self

func get_move_velocity_x() -> float:
	return _direction * leap_speed

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
