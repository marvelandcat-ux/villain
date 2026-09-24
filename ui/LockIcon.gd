@tool
class_name LockIcon
extends Control

## 코드로 그리는 자물쇠 — 그림 파일 없이 `_draw()`로 고리 + 몸통 + 열쇠 구멍을 그린다.
##
## 일시정지 화면의 스토리 목록에서 **아직 한 번도 클리어하지 못한 에피소드의 이름 자리**에 들어간다.
## 그림을 안 쓴 이유는 두 가지다 — ① 자물쇠 스프라이트가 아직 없고 ② 주아체를 비롯한 프로젝트 폰트에
## 자물쇠 기호(🔒) 글리프가 없어서 글자로 넣으면 두부(□)로 나온다.
##
## 크기는 이 노드의 `size`를 그대로 따르므로, 쓰는 쪽에서 네모 크기만 잡아 주면 그 안에 꽉 차게 그려진다.
## 나중에 자물쇠 그림을 받으면 이 노드를 TextureRect로 바꾸기만 하면 된다.

## 자물쇠 색 (잠긴 느낌이 나도록 보통은 글자색보다 어둡게 준다)
@export var lock_color: Color = Color(0.86, 0.82, 0.92, 0.5):
	set(value):
		lock_color = value
		queue_redraw()
## 열쇠 구멍 색 — 몸통을 뚫은 것처럼 보이게 몸통보다 어두운 색을 준다
@export var hole_color: Color = Color(0.09, 0.07, 0.13, 0.9):
	set(value):
		hole_color = value
		queue_redraw()
## 고리(위쪽 반원)의 굵기(px)
@export var line_width: float = 3.0:
	set(value):
		line_width = value
		queue_redraw()

func _ready() -> void:
	# 자물쇠는 보여주기만 하는 그림이라 클릭을 먹으면 안 된다
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return
	# 몸통은 아래쪽 절반, 고리는 그 위 반원 — 둘의 폭 비율이 자물쇠로 읽히는 핵심이다
	var body_w: float = w * 0.74
	var body_h: float = h * 0.5
	var body := Rect2(Vector2((w - body_w) * 0.5, h - body_h), Vector2(body_w, body_h))
	var radius: float = body_w * 0.33
	var top := Vector2(w * 0.5, body.position.y)
	draw_arc(top, radius, PI, TAU, 24, lock_color, line_width, true)
	# 반원만 그리면 고리 양끝이 몸통에 안 닿아서 떠 보인다 — 몸통 안쪽까지 조금 내려 잇는다
	draw_line(top + Vector2(-radius, 0.0), top + Vector2(-radius, line_width), lock_color, line_width, true)
	draw_line(top + Vector2(radius, 0.0), top + Vector2(radius, line_width), lock_color, line_width, true)
	draw_rect(body, lock_color, true)
	var hole: Vector2 = body.position + Vector2(body_w * 0.5, body_h * 0.42)
	draw_circle(hole, body_h * 0.17, hole_color)
	draw_rect(Rect2(hole - Vector2(body_h * 0.07, 0.0), Vector2(body_h * 0.14, body_h * 0.3)), hole_color, true)
