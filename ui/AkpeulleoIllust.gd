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
##  - `Shotgun/Ready` : 주먹을 번쩍 든 자세 (`샷건준비악플러.png`)
##  - `Shotgun/Hit`   : 내리친 자세 (`샷건악플러_0001_레이어-1.png`). 표정도 다르다
##
## 흐름은 **타자·낄낄(type_seconds) -> 주먹 들기(windup_time) -> 쾅 -> 씩씩거리기(pant_seconds)
## -> 다시 타자** 로 돈다. 들기와 내리치기는 **그려진 두 장을 갈아 끼우는 2프레임 애니메이션**이다.
##
## (2026-09-14) 처음엔 팔 파츠 한 장을 잘라서 코드로 들어 올렸는데, 어깨 단면이 몸에서 떨어져 나와
## 어색했다(사용자 지적). 주먹 든 자세 그림을 새로 받아서 **자세를 통째로 교체**하는 방식으로 바꿨고,
## 관절 문제가 사라졌다. 잘라 쓰던 팔 조각(`샷건팔_어깨/전완`)과 메운 밑그림은 더 안 쓴다.
##
## **평소 자세의 손가락은 아래로만 누른다.** 파츠들이 `Typing/Base`와 100% 겹쳐 있어서(밑그림이 파츠를
## 지운 판이 아니다), 손가락을 위로 들면 밑그림의 손가락이 남아 **손가락이 두 개로 보인다**.
## 아래로 내리면 위쪽 빈자리를 밑그림의 같은 그림이 메워줘 이음매가 안 보인다.
##
## 두 샷건 자세에는 각각 **상반신만 잘라낸 판(`*_상반신.png`, 원본 y=500에서 자름)** 을 원본 위에
## 똑같이 겹쳐 뒀다. 이걸 `pant_pivot_y`를 축으로 세로로 늘이면 **책상·다리는 그대로 있고 어깨·머리만**
## 오르내린다. 축에서 변위가 0이라 잘라낸 줄에 이음매가 안 생긴다.
##
## 파츠는 centered = false(회전축이 캔버스 왼쪽 위)라 **회전은 쓰지 않는다** — 돌리면 엉뚱한 데서 돈다.

enum Phase { TYPE, WINDUP, PANT }

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
## 1초에 몇 번 떠는지. 높이면 "낄낄" 잔웃음, 낮추면 여유롭게 어깨 들썩이는 느낌이 된다
@export var laugh_speed: float = 5.0
## 몸도 같이 떠는 비율 (0 = 머리만, 1 = 머리와 같은 폭)
@export_range(0.0, 1.0, 0.05) var laugh_body_ratio: float = 0.25

@export_group("샷건")
## 타자·낄낄대기를 몇 초 하고 샷건으로 넘어가는지
@export var type_seconds: float = 4.5
## 주먹을 든 자세로 버티는 시간(초). 이 동안 상반신이 조금 더 솟아오른다
@export var windup_time: float = 0.34
## 버티는 동안 상반신이 위로 솟는 비율 (0.018 = 1.8%)
@export var windup_stretch: float = 0.018
## 내리치는 순간 그림 전체가 흔들리는 크기(px)·잦아드는 시간(초)·1초당 진동 수
@export var shake_amount: float = 11.0
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
@onready var _ready_pose: Node2D = $Shotgun/Ready
@onready var _hit_pose: Node2D = $Shotgun/Hit
@onready var _ready_upper: Sprite2D = $Shotgun/Ready/Upper
@onready var _hit_upper: Sprite2D = $Shotgun/Hit/Upper

var _time: float = 0.0
var _phase: int = Phase.TYPE
var _phase_time: float = 0.0
var _fingers: Array[Sprite2D] = []
var _finger_rest: Array[Vector2] = []
var _finger_timer: Array[float] = []
var _finger_down: Array[bool] = []
var _head_rest: Vector2 = Vector2.ZERO
var _body_rest: Vector2 = Vector2.ZERO
var _ready_upper_rest: Vector2 = Vector2.ZERO
var _hit_upper_rest: Vector2 = Vector2.ZERO
## 흔들림은 이 노드 자체를 밀어서 만든다 — 씬에 저장된 자리를 기준으로 되돌린다
var _root_rest: Vector2 = Vector2.ZERO
var _shake_left: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = seed_value
	_root_rest = position
	_head_rest = _head.position
	_body_rest = _body.position
	_ready_upper_rest = _ready_upper.position
	_hit_upper_rest = _hit_upper.position
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
			# 주먹 든 자세로 버틴다 — 상반신이 조금씩 더 솟아오르며 힘을 모은다
			var up: float = clampf(_phase_time / maxf(windup_time, 0.01), 0.0, 1.0)
			_stretch(_ready_upper, _ready_upper_rest, windup_stretch * up)
			if _phase_time >= windup_time:
				_impact()
		Phase.PANT:
			# 천천히 크게 들이쉬고 내쉰다 — 상반신만 위로 늘었다 제자리로
			var breath: float = 0.5 - 0.5 * cos(_phase_time * TAU / maxf(pant_period, 0.01))
			_stretch(_hit_upper, _hit_upper_rest, pant_stretch * breath)
			if _phase_time >= pant_seconds:
				_enter_typing()

## 타자 자세로 (되)돌아간다
func _enter_typing() -> void:
	_phase = Phase.TYPE
	_phase_time = 0.0
	_typing.visible = true
	_shotgun.visible = false
	_reset_poses()

## 주먹 든 자세로 갈아 끼운다 — 표정까지 통째로 다른 그림이다
func _enter_shotgun() -> void:
	_phase = Phase.WINDUP
	_phase_time = 0.0
	_typing.visible = false
	_shotgun.visible = true
	_reset_poses()
	_ready_pose.visible = true
	_hit_pose.visible = false

## 내리치는 순간 — 그림을 내리친 자세로 바꾸고, 화면이 흔들리고, 씩씩거리기로 넘어간다.
## **자세 교체가 곧 타격 프레임**이라 중간 보간 없이 툭 바뀌는 게 맞다
func _impact() -> void:
	_phase = Phase.PANT
	_phase_time = 0.0
	_ready_pose.visible = false
	_hit_pose.visible = true
	_shake_left = shake_time

func _reset_poses() -> void:
	_stretch(_ready_upper, _ready_upper_rest, 0.0)
	_stretch(_hit_upper, _hit_upper_rest, 0.0)

## 상반신 판을 pant_pivot_y를 축으로 세로로 늘인다 (amount = 늘어나는 비율).
## 통째로 위아래로 옮기면 책상·다리까지 같이 떠서 화면이 흔들리는 것처럼 보인다(사용자 지적).
## 축에서는 전혀 안 움직이고 위로 갈수록 많이 움직여서, 잘라낸 줄에 이음매가 생기지 않는다
func _stretch(part: Sprite2D, rest: Vector2, amount: float) -> void:
	var factor: float = 1.0 + maxf(amount, 0.0)
	part.scale.y = factor
	part.position.y = rest.y + pant_pivot_y * (1.0 - factor)

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
