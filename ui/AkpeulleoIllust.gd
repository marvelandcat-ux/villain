class_name AkpeulleoIllust
extends Node2D

## 메인 메뉴에 앉아 있는 악플러 일러스트 — **키보드를 두들기는 느낌**을 코드로 만든다.
##
## 그림은 전부 **같은 캔버스(1254x1254)** 로 뽑힌 포토샵 레이어라, 각 Sprite2D를 `centered = false`,
## `position = (0, 0)` 으로 두면 원본과 픽셀 단위로 같은 자리에 겹친다. 그래서 씬에는 자리값이 없다 —
## 전체 위치·크기는 MainMenu.tscn에 놓인 이 노드의 position/scale로 잡는다.
##
## 레이어 구성 (뒤 -> 앞):
##  - `Base`(_0010) : 책상·의자·다리·손까지 다 그려진 **완성 그림 한 장**
##  - `Body`(_0009) : 후드 상체만 따로 뽑은 것
##  - `Finger*`(_0000~_0007) : 손가락 8개
##  - `Head`(_0008) : 머리
##
## **손가락은 아래로만 누른다.** 파츠들이 `Base`와 100% 겹쳐 있어서(밑그림이 파츠를 지운 판이 아니다),
## 손가락을 위로 들면 밑그림의 손가락이 그대로 남아 **손가락이 두 개로 보인다**. 아래로 내리면
## 위쪽 빈자리를 밑그림의 같은 그림이 메워줘서 이음매가 안 보이고, 끝만 쑥 내려가 "눌렀다"로 읽힌다.
## (지하철 아저씨 때처럼 밑그림에서 파츠를 지우고 메우는 작업을 하면 위로도 들 수 있지만,
##  타자 연출은 누르는 방향이라 그럴 필요가 없었다)
##
## 머리·몸은 아주 조금(2~4px)만 위아래로 오간다. 몸이 움직이면 **손가락도 같이 따라간다** —
## 팔은 `Body`에 붙어 있는데 손가락만 제자리에 있으면 손목에서 어긋난다.

@export_group("타자")
## 키를 누를 때 손가락이 내려가는 거리(px, 원본 캔버스 기준)
@export var key_press: float = 6.0
## 눌렀다 떼는 데 걸리는 시간(초). 짧을수록 또각또각
@export var press_min: float = 0.05
@export var press_max: float = 0.10
## 다음에 누르기까지 쉬는 시간(초). 손가락마다 아래 가중치가 곱해진다
@export var gap_min: float = 0.10
@export var gap_max: float = 0.55
## 손가락이 목표 자리로 따라붙는 빠르기. 클수록 딱딱 끊어진다
@export var press_speed: float = 40.0
## 타자 순서가 매번 같지 않게 하는 씨앗
@export var seed_value: int = 20260914

@export_group("숨쉬기")
## 머리가 위아래로 오가는 폭(px)과 한 번 왕복하는 시간(초)
@export var head_bob: float = 3.5
@export var head_period: float = 2.6
## 몸이 위아래로 오가는 폭(px)과 주기(초). 머리와 주기를 다르게 줘야 통짜로 안 보인다
@export var body_bob: float = 2.0
@export var body_period: float = 3.4

## 손가락별로 얼마나 자주 치는지 (작을수록 자주). 검지가 제일 바쁘고 새끼가 제일 한가하다.
## 씬의 Finger 노드 순서(왼손 새끼->검지, 오른손 검지->새끼)와 짝이 맞아야 한다
const FINGER_WEIGHT := [2.6, 1.9, 1.3, 1.0, 1.0, 1.3, 1.9, 2.6]

@onready var _head: Sprite2D = $Head
@onready var _body: Sprite2D = $Body

var _time: float = 0.0
var _fingers: Array[Sprite2D] = []
var _finger_rest: Array[Vector2] = []
var _finger_timer: Array[float] = []
var _finger_down: Array[bool] = []
var _head_rest: Vector2 = Vector2.ZERO
var _body_rest: Vector2 = Vector2.ZERO
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = seed_value
	_head_rest = _head.position
	_body_rest = _body.position
	# 이름이 Finger로 시작하는 자식을 트리 순서대로 모은다 — 씬에서 손가락을 빼거나 더해도 코드는 그대로다
	for child in get_children():
		if child is Sprite2D and String(child.name).begins_with("Finger"):
			_fingers.append(child)
			_finger_rest.append((child as Sprite2D).position)
			_finger_down.append(false)
			# 처음부터 다 같이 눌리지 않게 시작 시간을 흩뿌린다
			_finger_timer.append(_rng.randf_range(0.0, 0.6))

func _process(delta: float) -> void:
	_time += delta
	# 숨쉬기 — 몸과 머리가 서로 다른 주기로 아주 조금 오간다
	var body_offset := Vector2(0.0, sin(_time * TAU / maxf(body_period, 0.01)) * body_bob)
	var head_offset := Vector2(0.0, sin(_time * TAU / maxf(head_period, 0.01) + 0.8) * head_bob)
	_body.position = _body_rest + body_offset
	# 머리는 몸 위에 얹혀 있으므로 몸이 움직인 만큼 같이 옮기고, 거기서 제 몫을 더 움직인다
	_head.position = _head_rest + body_offset + head_offset

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
