class_name Swing
extends Node2D

## 놀이터 그네 — **항상 좌우로 흔들리고, 닿으면 팅~ 하고 튕겨낸다.**
##
## (2026-09-12 변경) 예전엔 좌석에 닿으면 올라타서, 반대쪽으로 당겼다 놔야만 날아가며 내릴 수 있었다.
## 맵 한가운데 있다 보니 지나가다 걸리면 못 빠져나가는 "감옥"이 돼서, 이제는 아예 타지 않는다.
##
##  - 줄에 매달린 좌석이 진자처럼 계속 왕복한다. sin 곡선이라 바닥 근처에서 가장 빠르고 양 끝에서 멈칫한다
##  - 좌석에 닿으면 **닿기 직전에 오던 방향의 반대쪽으로** 튕겨나가며 살짝 뜬다.
##    정확히는 "좌석에 대한 상대 속도"의 반대다 — 걸어서 부딪히면 걸어온 반대쪽으로 튕기고,
##    가만히 서 있다가 좌석에 맞으면 좌석이 가던 방향으로 밀려나고, 도망가다 뒤에서 좌석에 따라잡혀도
##    앞으로 밀려난다. 플레이어 속도만 보면 가만히 있을 땐 방향이 안 정해지고, 뒤에서 따라잡힐 땐
##    좌석 쪽으로 도로 튕겨 좌석을 파고드는 이상한 그림이 된다
##  - 튕긴 뒤엔 짧게 경직(`Fighter.apply_hitstun`)을 건다. 안 걸면 방향키를 누르고 있는 한 다음 프레임에
##    걷기 속도가 튕긴 속도를 덮어써서 아무 일도 없던 것처럼 된다. 경직 중엔 넉백처럼 마찰로 미끄러지다 멈춘다
##  - **데미지는 없다** — 피해 0이라 `Fighter.damaged`가 안 나가서 왕관도 안 벗겨진다
##  - 같은 사람은 튕긴 직후 `rebounce_delay` 동안 다시 안 튕긴다 — 좌석과 겹친 채로 매 프레임 튕기는 걸 막는다

## 누군가 튕겨나간 순간 (연출·소리를 붙일 자리). direction은 튕겨나간 가로 방향(+1 오른쪽)
signal bounced(fighter: Fighter, direction: float)

@export_group("흔들기")
## 양쪽으로 기우는 최대 각도(도)
@export var swing_deg: float = 38.0
## 한 번 왕복하는 시간(초). 줄 길이 136px·중력 1150이면 실제 진자 주기가 약 2.2초라 그 근처가 자연스럽다
@export var swing_period: float = 2.2

@export_group("튕기기")
## 튕겨나가는 기본 가로 속도(px/초)
@export var bounce_speed: float = 520.0
## 좌석이 빠르게 지나갈 때 더 세게 튕기도록, 좌석의 가로 속도에 이 비율을 곱해 더한다
## (좌석 최고 속도는 약 230px/초라 0.5면 최대 +115)
@export var seat_speed_bonus: float = 0.5
## 튕길 때 같이 뜨는 세로 속도(px/초, 음수가 위) — "팅" 하고 살짝 뜨는 맛
@export var bounce_lift: float = -300.0
## 튕긴 뒤 조작이 막히는 최대 시간(초). 마찰로 다 멈추는 시간보다 길면 여기서 끊는다
@export var bounce_stun_max: float = 0.45
## 같은 사람이 다시 튕기기까지 걸리는 시간(초)
@export var rebounce_delay: float = 0.35
## 좌석과의 상대 속도가 이보다 작으면(둘 다 거의 멈춰 있음) 방향 대신 좌석 중심에서 먼 쪽으로 밀어낸다
@export var min_relative_speed: float = 20.0

@onready var _arm: Node2D = $Arm
@onready var _seat: Area2D = $Arm/Seat

var _time: float = 0.0
## 좌석의 지난 프레임 위치와 지금 속도 — 튕길 방향·세기 계산에 쓴다
var _seat_prev: Vector2 = Vector2.ZERO
var _seat_vel: Vector2 = Vector2.ZERO
## 캐릭터 instance_id -> 다시 튕길 수 있기까지 남은 시간(초)
var _cooldowns: Dictionary = {}

func _ready() -> void:
	_seat_prev = _seat.global_position

func _physics_process(delta: float) -> void:
	_time += delta
	_arm.rotation = deg_to_rad(swing_deg) * sin(_time * TAU / maxf(swing_period, 0.01))
	var p: Vector2 = _seat.global_position
	if delta > 0.0:
		_seat_vel = (p - _seat_prev) / delta
	_seat_prev = p

	for id in _cooldowns.keys():
		_cooldowns[id] -= delta
		if _cooldowns[id] <= 0.0:
			_cooldowns.erase(id)

	# 신호(area_entered) 대신 매 프레임 겹친 목록을 훑는다 — 라운드 리셋·순간이동으로 신호가 안 오는 경우가 있어서
	# 이 프로젝트의 다른 판정들(SandPit·Crown)도 같은 방식이다
	for area in _seat.get_overlapping_areas():
		if not (area is Hurtbox):
			continue
		var fighter: Fighter = area.fighter
		if fighter == null or not is_instance_valid(fighter) or fighter.current_hp <= 0 or fighter.is_grabbed:
			continue
		var id: int = fighter.get_instance_id()
		if _cooldowns.has(id):
			continue
		_bounce(fighter)
		_cooldowns[id] = rebounce_delay

## 좌석에 대한 상대 속도의 반대쪽으로 튕겨낸다
func _bounce(fighter: Fighter) -> void:
	var rel: float = fighter.velocity.x - _seat_vel.x
	var dir: float = -signf(rel)
	if absf(rel) < min_relative_speed:
		dir = signf(fighter.global_position.x - _seat.global_position.x)
	if dir == 0.0:
		dir = 1.0
	var speed: float = bounce_speed + absf(_seat_vel.x) * seat_speed_bonus
	fighter.velocity = Vector2(dir * speed, bounce_lift)
	# 경직 길이 = 마찰로 멈추는 데 걸리는 시간(넉백과 같은 계산). 너무 길면 조작을 오래 뺏으니 bounce_stun_max에서 끊는다
	fighter.apply_hitstun(clampf(speed / Fighter.HITSTUN_FRICTION, 0.1, bounce_stun_max))
	bounced.emit(fighter, dir)
