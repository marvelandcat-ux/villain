@tool
class_name PoliceSearch
extends Node2D

## **쓰레기장을 뒤지는 경찰** — 한 장짜리 일러를 레이어로 쪼개서 숨만 쉬게 만든 컷신 (2026-10-08 사용자 자료).
##
## 레이어는 전부 **같은 1672x941 캔버스로 뽑혀 있다**. 그래서 제자리(0,0)에 겹쳐 놓기만 하면
## 원본 그림이 그대로 복원된다 — 자리를 맞출 필요가 없다.
##
## 배경은 psd 안의 `_0004_Layer-0`이 **아니라** `경찰없는배경.png`를 쓴다(사용자 지시).
##
## 움직임은 셋뿐이다:
##  - **몸통** — 숨쉬기. 허리를 중심으로 아주 조금 커졌다 작아진다
##  - **팔** — 어깨를 중심으로 도는 것이라, 손전등 끝이 **반원을 그리며** 움직인다
##  - **얼굴** — 좌우로 뒤집으며 두리번거린다. 뒤집을 때 가로로 납작해졌다 펴져서 "고개를 돌린다"로 읽힌다
##
## 다리는 안 움직인다(전신을 맞추려고 가져온 레이어다).
##
## ⚠️ **머리·팔은 몸통의 자식이다.** 따로 두면 숨 쉴 때 몸만 올라가고 머리가 제자리에 남아 목이 늘어난다.
##
## 회전 중심(`*_pivot`)은 전부 **원본 그림 좌표(px)**다. 인스펙터에서 끌어 맞추면 에디터에서 바로 보인다.

## 그림 원본 크기(px) — 레이어가 전부 이 캔버스로 뽑혀 있다
const CANVAS := Vector2(1672.0, 941.0)

## 켜면 화면을 **꽉 채우도록** 통째로 키운다(남는 쪽은 잘린다). 끄면 씬에 적힌 scale 그대로
@export var fit_to_screen: bool = true

@export_group("회전 중심")
## 숨쉬기의 중심 — **허리**. 여기를 붙잡고 가슴이 부푼다
@export var body_pivot: Vector2 = Vector2(1075.0, 769.0):
	set(value):
		body_pivot = value
		_apply_pivots()
## 팔이 도는 중심 — **어깨**
@export var arm_pivot: Vector2 = Vector2(812.0, 366.0):
	set(value):
		arm_pivot = value
		_apply_pivots()
## 고개가 도는 중심 — **목**
@export var face_pivot: Vector2 = Vector2(1126.0, 214.0):
	set(value):
		face_pivot = value
		_apply_pivots()

@export_group("숨쉬기")
## 한 번 들이쉬고 내쉬는 데 걸리는 시간(초)
@export var breath_period: float = 3.6
## 몸통이 늘어나는 비율. 0.01이면 1%다 — **이 이상 주면 숨이 아니라 펌프질로 보인다**
@export var breath_amount: float = 0.011
## 숨 쉴 때 몸이 같이 오르내리는 거리(px)
@export var breath_lift: float = 2.5

@export_group("팔")
## 팔이 한 번 갔다 오는 데 걸리는 시간(초)
@export var arm_period: float = 5.2
## 어깨에서 도는 각도(도). 손전등이 그리는 반원의 크기다
@export var arm_swing: float = 2.6
## 숨쉬기와 **박자를 어긋내는 양**(0~1). 둘이 딱 맞으면 기계처럼 보인다
@export_range(0.0, 1.0, 0.05) var arm_offbeat: float = 0.35

@export_group("두리번")
## 한쪽을 보고 있는 시간(초)
@export var look_hold: float = 2.4
## 고개를 돌리는 데 걸리는 시간(초)
@export var look_turn: float = 0.34
## 돌아간 쪽에서 고개가 갸웃하는 각도(도)
@export var look_tilt: float = 2.0
## 돌아갈 때 목이 그쪽으로 밀리는 거리(px)
@export var look_shift: float = 6.0
## 돌아가는 중에 얼굴이 가장 납작해지는 정도(0이면 완전히 0폭까지 눌린다)
@export_range(0.0, 1.0, 0.05) var look_squash: float = 0.0

@onready var _body: Node2D = $BodyPivot
@onready var _body_sprite: Sprite2D = $BodyPivot/Body
@onready var _arm: Node2D = $BodyPivot/ArmPivot
@onready var _arm_sprite: Sprite2D = $BodyPivot/ArmPivot/Arm
@onready var _face: Node2D = $BodyPivot/FacePivot
@onready var _face_sprite: Sprite2D = $BodyPivot/FacePivot/Face

var _time: float = 0.0

func _ready() -> void:
	_apply_pivots()
	if fit_to_screen:
		_fit()
	if Engine.is_editor_hint():
		set_process(false)

## 회전 중심을 실제 노드 자리로 옮긴다.
## **스프라이트는 반대로 밀어 둔다** — 그래야 중심을 어디로 옮기든 그림은 늘 원본 자리(0,0)에 선다.
## 팔·얼굴 중심은 몸통 중심 기준의 상대 좌표라 한 번 빼 준다
func _apply_pivots() -> void:
	if not is_node_ready():
		return
	_body.position = body_pivot
	_body_sprite.position = -body_pivot
	_arm.position = arm_pivot - body_pivot
	_arm_sprite.position = -arm_pivot
	_face.position = face_pivot - body_pivot
	_face_sprite.position = -face_pivot

## 그림이 화면을 덮도록 키운다. 캔버스가 16:9라 가로·세로 배율이 거의 같다
func _fit() -> void:
	var screen: Vector2 = get_viewport_rect().size
	scale = Vector2.ONE * maxf(screen.x / CANVAS.x, screen.y / CANVAS.y)

func _process(delta: float) -> void:
	_time += delta
	_breathe()
	_swing_arm()
	_look_around()

## 허리를 붙잡고 가슴이 부푼다. 가로는 세로보다 덜 늘어난다 — 사람 가슴이 그렇게 움직인다
func _breathe() -> void:
	var s: float = sin(_time * TAU / maxf(breath_period, 0.05))
	_body.scale = Vector2(1.0 + s * breath_amount * 0.4, 1.0 + s * breath_amount)
	_body.position = body_pivot + Vector2(0.0, -s * breath_lift)

## 어깨에서 도니까 손전등 끝이 **반원을 그린다**
func _swing_arm() -> void:
	var t: float = _time * TAU / maxf(arm_period, 0.05) + arm_offbeat * TAU
	_arm.rotation = deg_to_rad(arm_swing) * sin(t)

## 좌우로 뒤집으며 두리번거린다.
## 뒤집는 **순간**에 가로를 납작하게 눌렀다 펴서, 툭 바뀌는 게 아니라 고개가 돌아가는 것처럼 보인다
func _look_around() -> void:
	var cycle: float = maxf(look_hold + look_turn, 0.05) * 2.0
	var t: float = fmod(_time, cycle)
	var half: float = cycle * 0.5
	# 지금 어느 쪽을 보고 있나(1 = 원래 방향, -1 = 뒤집힌 방향)
	var side: float = 1.0 if t < half else -1.0
	var in_half: float = t if t < half else t - half
	var width: float = 1.0
	if in_half >= look_hold:
		# 돌아가는 중 — 1 -> look_squash -> 1 로 눌렸다 펴진다
		var k: float = (in_half - look_hold) / maxf(look_turn, 0.001)
		width = lerpf(1.0, look_squash, 1.0 - absf(k * 2.0 - 1.0))
		# 절반을 넘기는 순간 반대쪽 얼굴로 바뀐다
		if k > 0.5:
			side = -side
	_face.scale = Vector2(side * width, 1.0)
	_face.rotation = deg_to_rad(look_tilt) * (1.0 if side < 0.0 else 0.0)
	_face.position = face_pivot - body_pivot + Vector2(look_shift * (1.0 if side < 0.0 else 0.0), 0.0)
