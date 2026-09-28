class_name PoliceMouth
extends Node2D

## 경찰 궁극기 컷인에서 **말하는 입**.
##
## 얼굴 그림(`경찰정면.png`)은 입을 벌린 한 장뿐이라, 입 다문 얼굴을 따로 받는 대신
## **원래 입을 피부색 판으로 덮고 그 위에 입을 직접 그린다.** 입 주변이 단색 피부라 덮은 티가 안 난다.
##
## 이 노드는 **Head의 자식**이라 좌표·크기가 전부 그림(원본 png) 픽셀 기준이다 —
## 머리 배율을 바꿔도 입이 따라서 같이 커지고, 위치도 안 어긋난다.
## 숫자는 실제 그림에서 재서 넣었다(입 안 x 290~420 / y 466~518, 턱선 y 542, 그림 762x582).

## 원래 입을 덮는 피부색 판의 반지름(px). **턱선(입 아래 20px)까지 먹지 않게** 세로를 너무 키우지 말 것
@export var patch_radius: Vector2 = Vector2(75.0, 40.0):
	set(value):
		patch_radius = value
		queue_redraw()
## 덮개 색 — 입 주변 피부에서 그대로 뽑은 값
@export var skin_color: Color = Color(0.996, 0.863, 0.729):
	set(value):
		skin_color = value
		queue_redraw()
## 그려 넣는 입의 가로 반지름과, 다물었을 때/벌렸을 때의 세로 반지름(px)
@export var mouth_radius_x: float = 66.0:
	set(value):
		mouth_radius_x = value
		queue_redraw()
@export var mouth_closed_y: float = 5.0:
	set(value):
		mouth_closed_y = value
		queue_redraw()
@export var mouth_open_y: float = 28.0:
	set(value):
		mouth_open_y = value
		queue_redraw()
## 입 안 색 — 원래 그림에서 뽑은 값
@export var mouth_color: Color = Color(0.678, 0.286, 0.29):
	set(value):
		mouth_color = value
		queue_redraw()
@export var outline_color: Color = Color(0.05, 0.05, 0.05, 1.0)
@export var outline_width: float = 8.0:
	set(value):
		outline_width = value
		queue_redraw()
## 타원을 몇 조각으로 쪼개 그릴지 (많을수록 매끄럽다)
@export var segments: int = 28

## 0이면 다문 입, 1이면 벌린 입. 컷인 스크립트가 여기를 바꾼다
var openness: float = 0.0:
	set(value):
		openness = clampf(value, 0.0, 1.0)
		queue_redraw()

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	# 1) 원래 그려져 있던 입을 피부색으로 덮는다
	draw_colored_polygon(_ellipse(patch_radius), skin_color)
	# 2) 그 위에 지금 벌린 만큼의 입을 그린다
	var ry: float = lerpf(mouth_closed_y, mouth_open_y, openness)
	var shape: PackedVector2Array = _ellipse(Vector2(mouth_radius_x, ry))
	draw_colored_polygon(shape, mouth_color)
	var loop: PackedVector2Array = shape.duplicate()
	loop.append(shape[0])
	draw_polyline(loop, outline_color, outline_width)

func _ellipse(radius: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count: int = maxi(segments, 8)
	for i in range(count):
		var angle: float = TAU * float(i) / float(count)
		points.append(Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points
