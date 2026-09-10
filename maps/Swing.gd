class_name Swing
extends Node2D

## 놀이터 그네 — **가려는 반대쪽으로 당겼다가 놓으면 그쪽으로 날아간다.**
##
## 흐름:
##  1) 좌석에 닿으면 그냥 올라탄다 (조작 키가 전부 차 있어서 탑승 전용 키를 따로 두지 않았다)
##  2) 올라탄 동안은 걷지 못하고 그네에 매달려 있다 — Fighter.movement_override로 이동을 가로챈다
##  3) 가고 싶은 방향의 **반대쪽**을 누르고 있으면 그네가 그쪽으로 당겨지며 힘이 찬다
##  4) 손을 떼면 반대편으로 날아간다. 오래 당길수록 멀리 간다
##
## 아무것도 안 누르고 매달려만 있으면 max_ride_time 뒤에 저절로 떨어져서, 그네를 방패로 쓰지 못한다.
## 날아간 직후 remount_delay 동안은 다시 못 타서, 같은 그네에 계속 붙어 있을 수 없다.

## 누군가 날아간 순간 (연출을 붙일 자리)
signal launched(rider: Fighter, direction: float)

@export_group("당기기")
## 완전히 당기는 데 걸리는 시간(초)
@export var charge_time: float = 0.75
## 최대로 당겼을 때 날아가는 가로 속도(px/초)
@export var launch_speed: float = 900.0
## 최소 보장 속도 — 살짝만 당겼다 놔도 이만큼은 나간다
@export var min_launch_speed: float = 380.0
## 날아갈 때 같이 뜨는 세로 속도(px/초, 음수가 위)
@export var launch_lift: float = -430.0
## 최대로 당겼을 때 그네가 기우는 각도(도)
@export var max_swing_deg: float = 52.0

@export_group("타고 내리기")
## 아무것도 안 누르고 매달려 있을 수 있는 최대 시간(초). 지나면 저절로 떨어진다
@export var max_ride_time: float = 3.0
## 날아간 뒤 다시 탈 수 있게 되기까지(초)
@export var remount_delay: float = 0.8
## 타는 동안 캐릭터가 앉는 자리 (좌석 노드 기준)
@export var seat_offset: Vector2 = Vector2(0.0, -36.0)

@onready var _arm: Node2D = $Arm
@onready var _seat: Area2D = $Arm/Seat

## 지금 타고 있는 사람 (없으면 null)
var _rider: Fighter = null
## 0~1. 얼마나 당겨졌는지
var _charge: float = 0.0
## 당기고 있는 방향(-1/0/1). 놓으면 이 반대로 날아간다
var _pull_dir: float = 0.0
var _ride_time: float = 0.0
var _cooldown: float = 0.0

func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	if is_instance_valid(_rider):
		_update_ride(delta)
	else:
		_rider = null
		_relax(delta)
		if _cooldown <= 0.0:
			_try_mount()

## 좌석에 닿은 사람을 태운다. 이미 타고 있거나 쓰러진 캐릭터는 건너뛴다
func _try_mount() -> void:
	for area in _seat.get_overlapping_areas():
		if not (area is Hurtbox):
			continue
		var fighter: Fighter = area.fighter
		if fighter == null or not is_instance_valid(fighter) or fighter.current_hp <= 0:
			continue
		if fighter.is_in_hitstun():
			continue
		_mount(fighter)
		return

func _mount(fighter: Fighter) -> void:
	_rider = fighter
	_charge = 0.0
	_pull_dir = 0.0
	_ride_time = 0.0
	# 이동을 가로챈다 — 이 동안 걷기 입력은 그네를 당기는 데만 쓰인다
	fighter.movement_override = self
	fighter.velocity = Vector2.ZERO

func _update_ride(delta: float) -> void:
	_ride_time += delta
	var input: float = _rider.move_input

	if input != 0.0:
		# 방향을 바꾸면 당기던 힘이 처음부터 다시 찬다
		if _pull_dir != 0.0 and signf(input) != _pull_dir:
			_charge = 0.0
		_pull_dir = signf(input)
		_charge = minf(_charge + delta / maxf(charge_time, 0.01), 1.0)
	elif _pull_dir != 0.0:
		_launch()
		return

	# 당긴 쪽으로 그네가 기운다.
	# 줄이 축 아래로 늘어져 있어서, 좌석을 왼쪽(-x)으로 보내려면 회전은 양수여야 한다 — 그래서 부호를 뒤집는다
	_arm.rotation = deg_to_rad(max_swing_deg) * _charge * -_pull_dir
	_rider.global_position = _seat.global_position + seat_offset

	if _ride_time >= max_ride_time:
		_dismount()

## 당기던 반대쪽으로 날려보낸다
func _launch() -> void:
	var rider: Fighter = _rider
	var direction: float = -_pull_dir
	var speed: float = lerpf(min_launch_speed, launch_speed, _charge)
	_dismount()
	if not is_instance_valid(rider):
		return
	rider.velocity = Vector2(direction * speed, launch_lift)
	rider.facing = direction
	_cooldown = remount_delay
	launched.emit(rider, direction)

## 그네에서 내려놓는다 (날아가든 시간이 다 되든 공통)
func _dismount() -> void:
	if is_instance_valid(_rider) and _rider.movement_override == self:
		_rider.movement_override = null
	_rider = null
	_charge = 0.0
	_pull_dir = 0.0
	if _cooldown <= 0.0:
		_cooldown = remount_delay * 0.5

## 아무도 안 탄 그네는 천천히 제자리로 돌아온다
func _relax(delta: float) -> void:
	_arm.rotation = lerpf(_arm.rotation, 0.0, clampf(delta * 4.0, 0.0, 1.0))

# --- Fighter.movement_override 규약 ---

## 타는 동안은 걷지 못한다 (좌우 입력은 그네를 당기는 데 쓰인다)
func get_move_velocity_x() -> float:
	return 0.0

## 매 물리 프레임 마지막에 Fighter가 불러준다. 그네에 매달려 있는 동안은 중력도 안 받는다
func after_physics(fighter: Fighter, _delta: float) -> void:
	if fighter == _rider:
		fighter.velocity.y = 0.0
