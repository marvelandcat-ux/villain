@tool
class_name HerePolice
extends Node2D

## **"여기인가" 하고 몸을 돌린 경찰** — 한 장짜리 일러를 레이어로 쪼갠 컷신 (2026-10-08 사용자 자료).
##
## 앞 장면(`소리를들은경찰`)에서 몸을 **휙 돌려** 이 자세가 된 것이라, 장면이 열리자마자
## 돌아온 자취(`trail_*`)를 한 번 그어 준다. 그 뒤로는 숨만 쉰다.
##
## 레이어는 전부 같은 1672x941 캔버스라 제자리(0,0)에 겹치기만 하면 원본이 복원된다.
## 쌓는 순서는 psd 그대로 — 배경 / 얼굴 / 팔 / 몸통 / 머리카락.
##
## 움직임:
##  - **몸통** — 숨쉬기(허리를 축으로 아주 조금)
##  - **머리카락** — 찰랑임(목덜미를 축으로 살랑살랑, 숨쉬기와 박자를 어긋내 둔다)
##  - 팔·얼굴은 몸통을 따라만 간다
##
## ⚠️ 얼굴·팔·머리카락은 **몸통의 자식**이다. 따로 두면 숨 쉴 때 몸만 오르내려서 목이 늘어난다.

const CANVAS := Vector2(1672.0, 941.0)

## 켜면 화면을 꽉 채우도록 통째로 키운다
@export var fit_to_screen: bool = true

@export_group("회전 중심")
## 숨쉬기 중심 — 허리
@export var body_pivot: Vector2 = Vector2(1050.0, 761.0):
	set(value):
		body_pivot = value
		_apply_pivots()
## 머리카락이 흔들리는 중심 — 정수리 뒤쪽(여기를 붙잡고 끝이 살랑인다)
@export var hair_pivot: Vector2 = Vector2(940.0, 70.0):
	set(value):
		hair_pivot = value
		_apply_pivots()

@export_group("숨쉬기")
@export var breath_period: float = 3.4
@export var breath_amount: float = 0.010
@export var breath_lift: float = 2.5

@export_group("머리카락 찰랑")
## 한 번 살랑이는 데 걸리는 시간(초)
@export var hair_period: float = 2.3
## 흔들리는 각도(도)
@export var hair_swing: float = 2.4
## 같이 아래위로 까딱이는 거리(px)
@export var hair_bob: float = 2.0
## 숨쉬기와 박자를 어긋내는 양(0~1). 딱 맞으면 통째로 움직이는 것처럼 보인다
@export_range(0.0, 1.0, 0.05) var hair_offbeat: float = 0.4

@export_group("몸 돌린 자취")
## 장면이 열릴 때 **몸이 휙 돌아온 자취**를 한 번 긋는다
@export var trail_enabled: bool = true
## 몇 초 뒤에 긋는지(0이면 열리자마자)
@export var trail_delay: float = 0.0
## 자취가 사라지는 데 걸리는 시간(초)
@export var trail_time: float = 0.42
## 자취의 **중심**(원본 좌표 px) — 몸이 돈 축. 보통 허리다
@export var trail_center: Vector2 = Vector2(1050.0, 700.0):
	set(value):
		trail_center = value
		_redraw_trail()
## 호가 그려지는 반지름(px). 큰 쪽이 어깨를 지나간다
@export var trail_radius: float = 620.0:
	set(value):
		trail_radius = value
		_redraw_trail()
## 호의 개수 — 안쪽으로 겹겹이 그린다
@export var trail_count: int = 4
## 호 사이 간격(px)
@export var trail_gap: float = 58.0
## 호가 **시작하는 각도**와 **쓸고 온 각도**(도). 0도가 오른쪽, 시계 방향이 +
@export var trail_from_deg: float = -96.0
@export var trail_sweep_deg: float = 42.0
## 선 굵기(px)
@export var trail_width: float = 11.0
@export var trail_color: Color = Color(1.0, 0.98, 0.9, 0.75)
## 켜면 에디터에서도 자취를 띄워 둔다 — 자리를 맞출 때 쓴다
@export var preview_trail: bool = false:
	set(value):
		preview_trail = value
		_redraw_trail()

@onready var _body: Node2D = $BodyPivot
@onready var _body_sprite: Sprite2D = $BodyPivot/Body
@onready var _face_sprite: Sprite2D = $BodyPivot/Face
@onready var _arm_sprite: Sprite2D = $BodyPivot/Arm
@onready var _hair: Node2D = $BodyPivot/HairPivot
@onready var _hair_sprite: Sprite2D = $BodyPivot/HairPivot/Hair
@onready var _trail: Node2D = $Trail

var _time: float = 0.0

func _ready() -> void:
	_apply_pivots()
	if fit_to_screen:
		_fit()
	if Engine.is_editor_hint():
		set_process(false)
	_redraw_trail()

## 회전 중심을 노드 자리로 옮기고 스프라이트는 반대로 밀어, 그림은 늘 원본 자리(0,0)에 선다
func _apply_pivots() -> void:
	if not is_node_ready():
		return
	_body.position = body_pivot
	for part in [_body_sprite, _face_sprite, _arm_sprite]:
		part.position = -body_pivot
	_hair.position = hair_pivot - body_pivot
	_hair_sprite.position = -hair_pivot
	_redraw_trail()

func _fit() -> void:
	var screen: Vector2 = get_viewport_rect().size
	scale = Vector2.ONE * maxf(screen.x / CANVAS.x, screen.y / CANVAS.y)

func _process(delta: float) -> void:
	_time += delta
	_breathe()
	_sway_hair()
	_trail.queue_redraw()

func _breathe() -> void:
	var s: float = sin(_time * TAU / maxf(breath_period, 0.05))
	_body.scale = Vector2(1.0 + s * breath_amount * 0.4, 1.0 + s * breath_amount)
	_body.position = body_pivot + Vector2(0.0, -s * breath_lift)

## 정수리를 붙잡고 끝이 살랑인다
func _sway_hair() -> void:
	var t: float = _time * TAU / maxf(hair_period, 0.05) + hair_offbeat * TAU
	_hair.rotation = deg_to_rad(hair_swing) * sin(t)
	_hair.position = hair_pivot - body_pivot + Vector2(0.0, cos(t) * hair_bob)

func _redraw_trail() -> void:
	if is_node_ready() and _trail != null:
		_trail.queue_redraw()

## 자취가 지금 얼마나 진한지(1 = 막 그어짐, 0 = 다 사라짐)
func _trail_fade() -> float:
	if not trail_enabled:
		return 0.0
	if Engine.is_editor_hint():
		return 1.0 if preview_trail else 0.0
	if trail_time <= 0.0 or _time < trail_delay:
		return 0.0
	return clampf(1.0 - (_time - trail_delay) / trail_time, 0.0, 1.0)

## `Trail` 노드가 이걸 불러 자기 자리에 호를 그린다 — 그리는 쪽과 값은 여기 한 군데에 둔다
func draw_trail(canvas: Node2D) -> void:
	var fade: float = _trail_fade()
	if fade <= 0.001:
		return
	var from: float = deg_to_rad(trail_from_deg)
	var sweep: float = deg_to_rad(trail_sweep_deg)
	for i in maxi(trail_count, 1):
		var r: float = trail_radius - trail_gap * i
		if r <= 1.0:
			continue
		# 안쪽 호일수록 가늘고 흐리다 — 몸통 안쪽은 덜 휩쓸렸다는 뜻
		var taper: float = 1.0 - float(i) / float(maxi(trail_count, 1)) * 0.55
		canvas.draw_arc(trail_center, r, from, from + sweep, 48,
				Color(trail_color.r, trail_color.g, trail_color.b, trail_color.a * fade * taper),
				maxf(trail_width * taper * fade, 1.0), true)
