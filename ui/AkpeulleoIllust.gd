class_name AkpeulleoIllust
extends Node2D

## 메인 메뉴에 앉아 있는 악플러 일러스트 — **키보드를 두들기다 낄낄대고, 가끔 샷건을 친다.**
##
## 그림은 전부 **같은 캔버스(1254x1254)** 로 뽑힌 포토샵 레이어라, 각 Sprite2D를 `centered = false`,
## `position = (0, 0)` 으로 두면 원본과 픽셀 단위로 같은 자리에 겹친다. 그래서 씬에는 자리값이 없다 —
## 전체 위치·크기는 MainMenu.tscn에 놓인 이 노드의 position/scale로 잡는다.
##
## 두 벌의 그림을 통째로 갈아 끼운다:
##  - `Typing` : 평소 자세. `Base`(_0010 완성 그림) + `Body`(_0009 상체) + 손가락 8개 + `Head`(_0008)
##  - `Shotgun` : 샷건 치는 자세(표정도 다르다). `Base`(밑그림) + `Arm`(내리치는 팔)
##
## 흐름은 **타자·낄낄(type_seconds) -> 팔 들기 -> 쾅 -> 씩씩거리기(pant_seconds) -> 다시 타자** 로 돈다.
##
## **평소 자세의 손가락은 아래로만 누른다.** 파츠들이 `Typing/Base`와 100% 겹쳐 있어서(밑그림이 파츠를
## 지운 판이 아니다), 손가락을 위로 들면 밑그림의 손가락이 남아 **손가락이 두 개로 보인다**.
## 아래로 내리면 위쪽 빈자리를 밑그림의 같은 그림이 메워줘 이음매가 안 보인다.
##
## **샷건 팔은 위로 든다.** 그래서 `Shotgun/Base`만은 팔을 지우고 메운 판을 따로 만들어 뒀다
## (`샷건악플러_밑그림.png` — 받은 `_0001_레이어-1`에서 팔 알파를 3px 부풀려 지우고, 남은 픽셀 중
##  가장 가까운 색으로 번지게(BFS) 채운 것). 주변이 전부 검은 후드·책상이라 메운 자리가 티가 안 난다.
##
## 파츠는 centered = false(회전축이 캔버스 왼쪽 위)라 **회전은 쓰지 않는다** — 돌리면 엉뚱한 데서 돈다.

enum Phase { TYPE, WINDUP, SLAM, PANT }

@export_group("타자")
## 키를 누를 때 손가락이 내려가는 거리(px, 원본 캔버스 기준)
@export var key_press: float = 6.0
## 눌렀다 떼는 데 걸리는 시간(초). 짧을수록 또각또각
@export var press_min: float = 0.045
@export var press_max: float = 0.085
## 다음에 누르기까지 쉬는 시간(초). 손가락마다 아래 가중치가 곱해진다
@export var gap_min: float = 0.07
@export var gap_max: float = 0.30
## 손가락이 목표 자리로 따라붙는 빠르기. 클수록 딱딱 끊어진다
@export var press_speed: float = 55.0
## 타자 순서가 매번 같지 않게 하는 씨앗
@export var seed_value: int = 20260914

@export_group("숨쉬기")
## 머리가 위아래로 오가는 폭(px)과 한 번 왕복하는 시간(초)
@export var head_bob: float = 3.5
@export var head_period: float = 2.6
## 몸이 위아래로 오가는 폭(px)과 주기(초). 머리와 주기를 다르게 줘야 통짜로 안 보인다
@export var body_bob: float = 2.0
@export var body_period: float = 3.4

@export_group("낄낄대기")
## 머리가 자잘하게 떨리는 폭(px). 0이면 안 떤다
@export var laugh_shake: float = 0.9
## 1초에 몇 번 떠는지 — 12~16쯤이 "낄낄" 웃는 느낌이다
@export var laugh_speed: float = 11.0
## 몸도 같이 떠는 비율 (0 = 머리만, 1 = 머리와 같은 폭)
@export_range(0.0, 1.0, 0.05) var laugh_body_ratio: float = 0.25

@export_group("샷건")
## 타자·낄낄대기를 몇 초 하고 샷건으로 넘어가는지
@export var type_seconds: float = 4.5
## 팔을 위로 드는 데 걸리는 시간(초)과 드는 거리(px)
@export var windup_time: float = 0.28
@export var arm_lift: float = 55.0
## 내리찍는 데 걸리는 시간(초). **짧아야 쾅이 된다**
@export var slam_time: float = 0.07
## 내리찍을 때 제자리보다 더 내려가는 거리(px). 여기서 튕겨 제자리로 돌아온다
@export var arm_overshoot: float = 12.0
## 내리찍은 뒤 팔이 제자리로 돌아오는 시간(초)
@export var settle_time: float = 0.5
## 내리찍는 순간 그림 전체가 흔들리는 크기(px)·잦아드는 시간(초)·1초당 진동 수
@export var shake_amount: float = 9.0
@export var shake_time: float = 0.45
@export var shake_freq: float = 24.0

@export_group("샷건 후 씩씩거리기")
## 샷건 치고 거칠게 숨 쉬는 시간(초). 이 시간이 지나면 다시 타자 자세로 돌아간다
@export var pant_seconds: float = 2.6
## 씩씩거릴 때 **상반신만** 위로 늘어나는 비율 (0.022 = 2.2%). 아래 pant_pivot_y를 축으로 늘어나므로
## 책상·다리는 그대로 있고 어깨·머리만 올라갔다 내려온다
@export var pant_stretch: float = 0.022
## 한 번 들이쉬고 내쉬는 시간(초). 천천히 크게 쉬는 느낌
@export var pant_period: float = 1.1
## 상반신이 늘어나는 기준선(원본 캔버스 y). 여기서는 0px 움직이고 위로 갈수록 많이 움직인다.
## `샷건악플러_상반신.png`을 잘라낸 줄(500)과 같아야 이음매가 안 생긴다
@export var pant_pivot_y: float = 500.0

## 손가락별로 얼마나 자주 치는지 (작을수록 자주). 검지가 제일 바쁘고 새끼가 제일 한가하다.
## 씬의 Finger 노드 순서(왼손 새끼->검지, 오른손 검지->새끼)와 짝이 맞아야 한다
const FINGER_WEIGHT := [2.6, 1.9, 1.3, 1.0, 1.0, 1.3, 1.9, 2.6]

@onready var _typing: Node2D = $Typing
@onready var _shotgun: Node2D = $Shotgun
@onready var _head: Sprite2D = $Typing/Head
@onready var _body: Sprite2D = $Typing/Body
@onready var _arm: Sprite2D = $Shotgun/Arm
@onready var _upper: Sprite2D = $Shotgun/Upper

var _time: float = 0.0
var _phase: int = Phase.TYPE
var _phase_time: float = 0.0
var _fingers: Array[Sprite2D] = []
var _finger_rest: Array[Vector2] = []
var _finger_timer: Array[float] = []
var _finger_down: Array[bool] = []
var _head_rest: Vector2 = Vector2.ZERO
var _body_rest: Vector2 = Vector2.ZERO
var _arm_rest: Vector2 = Vector2.ZERO
var _shotgun_rest: Vector2 = Vector2.ZERO
var _upper_rest: Vector2 = Vector2.ZERO
## 흔들림은 이 노드 자체를 밀어서 만든다 — 씬에 저장된 자리를 기준으로 되돌린다
var _root_rest: Vector2 = Vector2.ZERO
var _shake_left: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = seed_value
	_root_rest = position
	_head_rest = _head.position
	_body_rest = _body.position
	_arm_rest = _arm.position
	_shotgun_rest = _shotgun.position
	_upper_rest = _upper.position
	# 이름이 Finger로 시작하는 자식을 트리 순서대로 모은다 — 씬에서 손가락을 빼거나 더해도 코드는 그대로다
	for child in _typing.get_children():
		if child is Sprite2D and String(child.name).begins_with("Finger"):
			_fingers.append(child)
			_finger_rest.append((child as Sprite2D).position)
			_finger_down.append(false)
			# 처음부터 다 같이 눌리지 않게 시작 시간을 흩뿌린다
			_finger_timer.append(_rng.randf_range(0.0, 0.6))
	_enter_typing()

## MainMenu가 이 일러스트를 다시 보여줄 때 부른다 — 처음(타자 자세)부터 다시 돌린다
func restart() -> void:
	_time = 0.0
	_shake_left = 0.0
	position = _root_rest
	_enter_typing()

func _process(delta: float) -> void:
	_time += delta
	_phase_time += delta
	_update_shake(delta)
	match _phase:
		Phase.TYPE:
			_process_typing(delta)
			if _phase_time >= type_seconds:
				_enter_shotgun()
		Phase.WINDUP:
			# 팔을 들어 올린다 (뒤로 갈수록 느려지게 — 힘을 모으는 느낌)
			var up: float = 1.0 - pow(1.0 - clampf(_phase_time / maxf(windup_time, 0.01), 0.0, 1.0), 2.0)
			_arm.position = _arm_rest + Vector2(0.0, -arm_lift * up)
			_set_upper_stretch(0.0)
			if _phase_time >= windup_time:
				_phase = Phase.SLAM
				_phase_time = 0.0
		Phase.SLAM:
			# 내리찍기 — 뒤로 갈수록 빨라지게(가속) 떨어뜨린다
			var down: float = pow(clampf(_phase_time / maxf(slam_time, 0.01), 0.0, 1.0), 2.0)
			_arm.position = _arm_rest + Vector2(0.0, lerpf(-arm_lift, arm_overshoot, down))
			_set_upper_stretch(0.0)
			if _phase_time >= slam_time:
				_impact()
		Phase.PANT:
			# 팔은 튕긴 자리에서 제자리로 돌아오고, 몸은 크게 헐떡인다
			var back: float = clampf(_phase_time / maxf(settle_time, 0.01), 0.0, 1.0)
			_arm.position = _arm_rest + Vector2(0.0, arm_overshoot * (1.0 - back))
			# 천천히 크게 들이쉬고 내쉰다 — 상반신만 위로 늘었다 제자리로
			_set_upper_stretch(0.5 - 0.5 * cos(_phase_time * TAU / maxf(pant_period, 0.01)))
			if _phase_time >= pant_seconds:
				_enter_typing()

## 타자 자세로 (되)돌아간다
func _enter_typing() -> void:
	_phase = Phase.TYPE
	_phase_time = 0.0
	_typing.visible = true
	_shotgun.visible = false
	_arm.position = _arm_rest
	_set_upper_stretch(0.0)

## 샷건 자세로 갈아 끼운다 — 표정까지 통째로 다른 그림이다
func _enter_shotgun() -> void:
	_phase = Phase.WINDUP
	_phase_time = 0.0
	_typing.visible = false
	_shotgun.visible = true
	_arm.position = _arm_rest
	_set_upper_stretch(0.0)

## 팔이 바닥에 닿은 순간 — 그림 전체가 흔들리고 씩씩거리기로 넘어간다
func _impact() -> void:
	_phase = Phase.PANT
	_phase_time = 0.0
	_shake_left = shake_time

## 샷건 자세의 숨 — **상반신만** pant_pivot_y를 축으로 위로 늘어난다(t = 0 제자리, 1 최대).
## 통째로 위아래로 옮기면 책상·다리까지 같이 떠서 화면이 흔들리는 것처럼 보인다(사용자 지적).
## 축에서는 전혀 안 움직이고 위로 갈수록 많이 움직여서, 잘라낸 줄에 이음매가 생기지 않는다.
## 팔도 같은 변환을 받아야 어깨에서 어긋나지 않는다
func _set_upper_stretch(t: float) -> void:
	var s: float = 1.0 + pant_stretch * clampf(t, 0.0, 1.0)
	var shift: float = pant_pivot_y * (1.0 - s)
	_upper.scale.y = s
	_upper.position.y = _upper_rest.y + shift
	_arm.scale.y = s
	_arm.position.y += shift

## 타자 + 낄낄대기
func _process_typing(delta: float) -> void:
	# 숨쉬기 — 몸과 머리가 서로 다른 주기로 아주 조금 오간다
	var body_offset := Vector2(0.0, sin(_time * TAU / maxf(body_period, 0.01)) * body_bob)
	var head_offset := Vector2(0.0, sin(_time * TAU / maxf(head_period, 0.01) + 0.8) * head_bob)
	# 낄낄대는 잔진동 — 세로가 주고 가로는 조금만 섞어서 한 방향으로만 흔들리지 않게 한다
	var laugh_phase: float = _time * laugh_speed * TAU
	var laugh := Vector2(sin(laugh_phase * 0.73) * 0.35, sin(laugh_phase)) * laugh_shake
	body_offset += laugh * laugh_body_ratio
	_body.position = _body_rest + body_offset
	# 머리는 몸 위에 얹혀 있으므로 몸이 움직인 만큼 같이 옮기고, 거기서 제 몫을 더 움직인다
	_head.position = _head_rest + body_offset + head_offset + laugh

	# 타자 — 손가락마다 따로 눌렀다 뗀다
	var follow: float = 1.0 - exp(-press_speed * delta)
	for i in range(_fingers.size()):
		_finger_timer[i] -= delta
		if _finger_timer[i] <= 0.0:
			_finger_down[i] = not _finger_down[i]
			if _finger_down[i]:
				_finger_timer[i] = _rng.randf_range(press_min, press_max)
			else:
				var weight: float = FINGER_WEIGHT[i] if i < FINGER_WEIGHT.size() else 1.0
				_finger_timer[i] = _rng.randf_range(gap_min, gap_max) * weight
		var target: Vector2 = _finger_rest[i] + body_offset
		if _finger_down[i]:
			target.y += key_press
		_fingers[i].position = _fingers[i].position.lerp(target, follow)

## 쾅 하고 난 뒤의 흔들림 — 처음이 가장 세고 제곱으로 빠르게 잦아든다
func _update_shake(delta: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left -= delta
	if _shake_left <= 0.0:
		_shake_left = 0.0
		position = _root_rest
		return
	var k: float = _shake_left / maxf(shake_time, 0.001)
	var amp: float = shake_amount * k * k
	var phase: float = (shake_time - _shake_left) * shake_freq * TAU
	position = _root_rest + Vector2(sin(phase * 1.23) * amp * 0.5, cos(phase) * amp)
