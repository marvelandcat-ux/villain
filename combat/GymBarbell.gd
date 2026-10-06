@tool
class_name GymBarbell
extends Sprite2D

## **손에 드는 바벨** — 헬스장 바벨 컬을 할 때 캐릭터의 두 손 사이에 끼워 넣는 봉이다.
##
## 그림이 아직 없어서 `_draw()`로 그린다(봉 하나 + 양쪽 원판 둘).
## **`texture`를 꽂으면 그림을 대신 쓴다** — 그때는 원점이 봉의 한가운데다.
##
## 자리·각도는 `BodyRig._pose_curl()`이 매 프레임 넣어 준다. 두 손을 잇는 선 위에 놓이므로
## 손만 제대로 움직이면 바벨은 저절로 따라 기울어진다.
##
## 맵에 **놓여 있는** 기구(거치대)는 `maps/GymMachine.gd`가 따로 그린다 — 이건 드는 쪽이다.
##
## **Sprite2D인 이유**: 포즈 씬에 보기용으로 놓고 **에디터에서 네모 핸들을 끌어 크기를 맞추려고** 그렇다.
## Node2D였을 땐 뷰포트에 핸들이 안 생겨서 인스펙터에 숫자를 쳐 넣는 수밖에 없었다(2026-10-05).
## 크기는 그냥 **노드의 Scale**이다 — 게임도 그 값을 그대로 읽어 쓴다.
## `@tool`은 그림 없이 도형으로 그릴 때도 에디터에 보이라고 붙였다

## 봉의 길이(px)와 굵기(px). 리그가 70px짜리라 봉도 그만큼 작다
@export var bar_length: float = 62.0:
	set(value):
		bar_length = value
		queue_redraw()
@export var bar_width: float = 2.6:
	set(value):
		bar_width = value
		queue_redraw()
## 양 끝 원판의 반지름(px)과 두께(px)
@export var plate_radius: float = 6.0:
	set(value):
		plate_radius = value
		queue_redraw()
@export var plate_width: float = 3.4:
	set(value):
		plate_width = value
		queue_redraw()
## 원판이 봉 끝에서 안쪽으로 들어오는 거리(px) — 0이면 끝에 딱 붙는다
@export var plate_inset: float = 3.0:
	set(value):
		plate_inset = value
		queue_redraw()

@export_group("색")
@export var bar_color: Color = Color(0.72, 0.75, 0.82, 1.0):
	set(value):
		bar_color = value
		queue_redraw()
@export var plate_color: Color = Color(0.16, 0.16, 0.19, 1.0):
	set(value):
		plate_color = value
		queue_redraw()
@export var line_color: Color = Color(0.85, 0.87, 0.92, 1.0):
	set(value):
		line_color = value
		queue_redraw()
@export var line_width: float = 1.2:
	set(value):
		line_width = value
		queue_redraw()

## 그림이 꽂혀 있으면 Sprite2D가 알아서 그린다 — 여기서는 **그림이 없을 때만** 도형을 그린다.
## 도형은 노드 Scale 1 기준으로 그려져 있으니, 도형을 쓸 거면 Scale은 1로 두는 게 맞다
func _draw() -> void:
	if texture != null:
		return
	var half: float = bar_length * 0.5
	# 봉 — 가로로 눕힌 한 줄
	draw_line(Vector2(-half, 0.0), Vector2(half, 0.0), bar_color, bar_width, true)
	# 양 끝 원판 — 가로로 납작하게 눌러 "옆에서 본 원판"으로 보이게 한다
	for side in [-1.0, 1.0]:
		var x: float = (half - plate_inset) * side
		_plate(Vector2(x, 0.0))

## 원판 하나 — 세로로 긴 타원이라 눌러 그린다
func _plate(at: Vector2) -> void:
	draw_set_transform(at, 0.0, Vector2(plate_width / maxf(plate_radius, 0.01), 1.0))
	draw_circle(Vector2.ZERO, plate_radius, plate_color)
	draw_arc(Vector2.ZERO, plate_radius, 0.0, TAU, 20, line_color, line_width / maxf(plate_width / maxf(plate_radius, 0.01), 0.01), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
