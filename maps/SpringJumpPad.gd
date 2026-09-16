class_name SpringJumpPad
extends Area2D

## 어린이용 스프링 시소를 **트램폴린**처럼 쓰는 기믹.
## 좌석에 닿는 순간 위로 튕겨 올라간다 — 점프 버튼과 무관하게 착지 자체가 반동이 된다.
## 세게 떨어질수록 더 높이 튕기고(bounce_restitution), 그냥 걸어 올라와도 최소 bounce_velocity만큼은 튕긴다.
##
## 판정 위치가 좌석 바로 위(y 176~216)라 좌석에 올라선 캐릭터만 걸리고,
## 좌석 밑(지면 y 220~280)으로 지나가는 캐릭터는 반응하지 않는다.

## 최소 튕김 속도(px/초). 중력 1150 기준 700이면 약 213px 튀어오른다
@export var bounce_velocity: float = 700.0
## 떨어진 속도에 이 값을 곱해서 튕긴다 — 높은 곳에서 떨어질수록 더 높이 튀어오른다
@export var bounce_restitution: float = 1.15
## 아무리 세게 떨어져도 이 속도를 넘지 않는다 (화면 밖으로 날아가는 걸 막는다)
@export var max_bounce_velocity: float = 1100.0
## 튕길 때 스프링 그림이 눌리는 정도(0이면 연출 없음)
@export var squash: float = 0.12
## 눌리는 스프링 그림. 지면 높이에 놓인 노드를 지정해야 아래에서 눌리는 것처럼 보인다
@export var spring_visual: NodePath

## 캐릭터별로 직전 프레임의 낙하 속도 {Fighter: float} — 착지 순간에는 이미 0이 되어 있어서
## 충돌 직전 속도를 따로 기억해둬야 "세게 떨어질수록 높이"를 계산할 수 있다
var _prev_fall: Dictionary = {}
var _spring: Node2D
var _spring_base_scale := Vector2.ONE
## 이번 프레임에 누가 튕겼는지 (연출용)
var _bounced: bool = false

func _ready() -> void:
	if spring_visual != NodePath():
		_spring = get_node_or_null(spring_visual)
		if _spring:
			_spring_base_scale = _spring.scale

## area_entered 신호 대신 매 프레임 겹친 목록을 훑는다 — 캐릭터가 판정 안에서
## 사라지거나 순간이동하면 신호가 안 오는 경우가 있어서, "지금 겹쳐 있는가"를 다시 보는 쪽이 확실하다
func _physics_process(_delta: float) -> void:
	var standing: Dictionary = {}
	_bounced = false
	for area in get_overlapping_areas():
		if not (area is Hurtbox):
			continue
		# Hurtbox 주인이 Fighter가 아닐 수 있다(일진 패거리) — as로 받으면 아니면 null이라 아래에서 걸러진다
		var fighter := area.fighter as Fighter
		if fighter == null or not is_instance_valid(fighter):
			continue
		standing[fighter] = true
		if fighter.is_on_floor():
			var fall: float = _prev_fall.get(fighter, 0.0)
			fighter.velocity.y = -clampf(maxf(bounce_velocity, fall * bounce_restitution), 0.0, max_bounce_velocity)
			_bounced = true
		# 튕긴 직후에는 velocity.y가 음수라 0으로 기록되고, 다음 착지까지 다시 쌓인다
		_prev_fall[fighter] = maxf(fighter.velocity.y, 0.0)

	for fighter in _prev_fall.keys():
		if not standing.has(fighter):
			_prev_fall.erase(fighter)

	_update_spring_visual(_bounced)

## 튕기는 순간 스프링을 눌렀다가 서서히 펴지게 한다
func _update_spring_visual(pressed: bool) -> void:
	if _spring == null:
		return
	var target: Vector2 = _spring_base_scale
	if pressed:
		target = Vector2(_spring_base_scale.x * (1.0 + squash * 0.5), _spring_base_scale.y * (1.0 - squash))
	_spring.scale = _spring.scale.lerp(target, 0.35)
