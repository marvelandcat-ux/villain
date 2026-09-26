@tool
class_name SwirlEye
extends Node2D

## 소용돌이 눈이 빙글빙글 돈다 — 주정뱅이의 눈 깜빡임 대신(2026-09-26 사용자 요청).
## 그림에 그려진 소용돌이를 흰 원으로 덮고, 그 위에 코드로 그린 소용돌이를 천천히 돌린다(가끔 빨라졌다 느려진다).
## **리그의 `Head` 스프라이트 자식으로 달고, 노드 위치를 눈 한가운데에 둔다.** 좌표·크기는 머리 그림 픽셀 단위.
## 흰 원은 눈 테두리(검은 선) **안쪽**에 맞춰야 원래 테두리가 남는다. 머리 그림이 처음 것(기본 얼굴)일 때만 그린다 —
## 취한·토하는·아픈 얼굴은 눈 자리가 달라서 덮으면 어긋난다(그땐 그림 그대로 보인다)

## 흰 원(눈 흰자) 크기 — 머리 그림 픽셀
@export var eye_size: Vector2 = Vector2(180, 180)
## 흰자 색과 소용돌이 선 색
@export var fill_color: Color = Color(1.0, 1.0, 1.0)
@export var line_color: Color = Color(0.05, 0.04, 0.04)
## 소용돌이 선 굵기(머리 그림 픽셀)와 감긴 바퀴 수, 바깥 끝 반지름(흰 원 반지름 대비)
@export var line_width: float = 20.0
@export var turns: float = 2.4
@export var spiral_radius: float = 0.8
## 도는 빠르기(초당 바퀴) — 가끔 빨라졌다 느려져 술기운에 핑핑 도는 느낌을 낸다(surge: 최대 몇 배까지 빨라지는지)
@export var spin_speed: float = 0.45
@export var surge: float = 2.5

const SEGMENTS: int = 72

var _base_texture: Texture2D
var _angle: float = 0.0
var _clock: float = 0.0

func _ready() -> void:
	var head := get_parent() as Sprite2D
	if head:
		_base_texture = head.texture
	_clock = randf() * 10.0

func _process(delta: float) -> void:
	_clock += delta
	# 느리게 돌다가 몇 초에 한 번 확 빨라진다(두 사인을 곱해 규칙적으로 안 보이게)
	var boost: float = maxf(0.0, sin(_clock * 0.9) * sin(_clock * 0.37 + 1.1))
	_angle += delta * TAU * spin_speed * (1.0 + surge * boost)
	queue_redraw()

func _can_show() -> bool:
	if Engine.is_editor_hint():
		return true
	var head := get_parent() as Sprite2D
	if head == null or head.texture != _base_texture:
		return false
	var rig := head.get_parent()
	return rig != null and rig.has_method("play_attack_swing")

func _draw() -> void:
	if not _can_show():
		return
	var a: float = eye_size.x * 0.5
	var b: float = eye_size.y * 0.5
	var disk := PackedVector2Array()
	for i in 40:
		var ang: float = TAU * i / 40.0
		disk.append(Vector2(cos(ang) * a, sin(ang) * b))
	draw_colored_polygon(disk, fill_color)
	# 가운데에서 바깥으로 감기는 아르키메데스 나선 — 반지름이 각도에 비례해 커진다
	var pts := PackedVector2Array()
	for i in SEGMENTS + 1:
		var t: float = float(i) / SEGMENTS
		var ang2: float = t * turns * TAU + _angle
		pts.append(Vector2(cos(ang2) * a, sin(ang2) * b) * t * spiral_radius)
	draw_polyline(pts, line_color, line_width, true)
