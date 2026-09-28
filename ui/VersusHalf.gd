class_name VersusHalf
extends Control

## 스토리 VS 화면의 **사다리꼴 반쪽**. 컨셉아트대로 화면을 비스듬히 자른 모양이다.
##
## 두 장(왼쪽/오른쪽)이 같은 크기로 겹쳐 놓여 있고, 자르는 빗변이 서로의 것과 똑같아서
## 둘이 제자리에 오면 틈 없이 딱 맞물린다. 그래서 양옆에서 날아와 가운데서 부딪히는 연출이 된다.
##
## 빗변은 위쪽이 가운데보다 `lean`만큼 왼쪽, 아래쪽이 `lean`만큼 오른쪽이다("\" 방향).

## true면 오른쪽 조각(빗변 오른쪽을 차지한다)
@export var is_right: bool = false:
	set(value):
		is_right = value
		queue_redraw()
## 빗변이 가운데에서 위아래로 벌어지는 거리(px)
@export var lean: float = 130.0:
	set(value):
		lean = value
		queue_redraw()
@export var fill_color: Color = Color(0.16, 0.2, 0.78, 1.0):
	set(value):
		fill_color = value
		queue_redraw()
## 만화 느낌을 내는 굵은 검은 테두리
@export var edge_color: Color = Color(0.0, 0.0, 0.0, 1.0)
@export var edge_width: float = 7.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

## 이 조각의 네 꼭짓점. 빗변(가운데 두 점)은 양쪽 조각이 완전히 같은 값이라 서로 맞물린다
func corners() -> PackedVector2Array:
	var c: float = size.x * 0.5
	if is_right:
		return PackedVector2Array([
			Vector2(c - lean, 0.0),
			Vector2(size.x, 0.0),
			Vector2(size.x, size.y),
			Vector2(c + lean, size.y),
		])
	return PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(c - lean, 0.0),
		Vector2(c + lean, size.y),
		Vector2(0.0, size.y),
	])

func _draw() -> void:
	var pts: PackedVector2Array = corners()
	draw_colored_polygon(pts, fill_color)
	var loop: PackedVector2Array = pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, edge_color, edge_width)
