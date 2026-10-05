@tool
class_name SquatPlate
extends Sprite2D

## **스쿼트 바벨** — 어깨에 메는 봉이다. **측면에서 보면 봉은 앞뒤로 들어가 안 보이고
## 원판만 큼직하게 보인다**(2026-10-05 사용자 스케치) — 그래서 원 하나만 그린다.
##
## 그림을 꽂으면 Sprite2D가 그 그림을 쓰고, 비어 있으면 `_draw()`가 **검은 원**을 그린다.
## 크기는 노드의 **Scale**이다 — 포즈 씬에서 끌어 키운 그대로 게임이 읽어 쓴다
## (`BodyRig.read_squat_plate`).
##
## `@tool`인 이유: 포즈 씬에 보기용으로 놓여 있어서 **에디터에서도 그려져야** 몸과 대 보면서 맞출 수 있다.
##
## 자리는 `BodyRig._pose_squat()`이 매 프레임 넣어 준다 — 몸통을 따라다닌다

## 원 반지름(px). 그림을 꽂으면 안 쓴다
@export var radius: float = 17.0:
	set(value):
		radius = value
		queue_redraw()
## 원 색과 테두리
@export var plate_color: Color = Color(0.07, 0.07, 0.08, 1.0):
	set(value):
		plate_color = value
		queue_redraw()
@export var line_color: Color = Color(0.0, 0.0, 0.0, 1.0):
	set(value):
		line_color = value
		queue_redraw()
@export var line_width: float = 0.0:
	set(value):
		line_width = value
		queue_redraw()
## 봉이 원판 밖으로 삐져나온 길이(px). 0이면 원만 그린다
@export var stub_length: float = 0.0:
	set(value):
		stub_length = value
		queue_redraw()
@export var stub_width: float = 5.0:
	set(value):
		stub_width = value
		queue_redraw()
@export var stub_color: Color = Color(0.72, 0.75, 0.82, 1.0):
	set(value):
		stub_color = value
		queue_redraw()

## 그림이 꽂혀 있으면 Sprite2D가 알아서 그린다 — 여기서는 **그림이 없을 때만** 원을 그린다
func _draw() -> void:
	if texture != null:
		return
	if stub_length > 0.0:
		# 원판 뒤로 살짝 보이는 봉 — 어깨에 걸친 티를 내고 싶을 때만 쓴다
		draw_line(Vector2(-stub_length, 0.0), Vector2(stub_length, 0.0), stub_color, stub_width, true)
	draw_circle(Vector2.ZERO, radius, plate_color)
	if line_width > 0.0:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, line_color, line_width, true)
