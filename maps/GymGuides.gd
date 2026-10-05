@tool
extends Node2D

## **헬스장 맵을 눈으로 맞추기 위한 안내선** — 에디터에서만 보이고 대전에서는 저절로 꺼진다.
##
## 맵에 있는 것들(바닥·벽·2층·기구·배경)은 전부 진짜 노드라 끌어서 옮기면 되는데,
## **캐릭터만은 대전이 시작돼야 생긴다.** 그래서 캐릭터가 설 자리와 키를 여기서 그려 준다.
## 안 그러면 "이 창이 사람 키보다 큰가"를 눈으로 못 본다(2026-10-06 사용자 요청).
##
## 치수를 바꿀 땐 **맵 노드를 먼저 옮기고**, 그 값을 여기에도 적어 준다 —
## 이 스크립트는 그림만 그리지, 맵을 움직이지는 않는다

## 대전 중에도 안내선을 보여줄지. 평소엔 꺼 둔다
@export var show_in_game: bool = false

@export_group("맵 치수")
## 1층 바닥 윗면 y
@export var ground_y: float = 430.0:
	set(value):
		ground_y = value
		queue_redraw()
## 2층 슬래브 윗면 y
@export var upper_y: float = 100.0:
	set(value):
		upper_y = value
		queue_redraw()
## 2층이 걸쳐 있는 좌우 끝과 벽 안쪽 좌우 끝
@export var upper_half_width: float = 320.0:
	set(value):
		upper_half_width = value
		queue_redraw()
@export var wall_half_width: float = 604.0:
	set(value):
		wall_half_width = value
		queue_redraw()

@export_group("캐릭터")
## **캐릭터 키**(px). 이 막대가 창·기구보다 작으면 사람이 작아 보인다는 뜻이다
@export var body_height: float = 125.0:
	set(value):
		body_height = value
		queue_redraw()
@export var body_width: float = 52.0:
	set(value):
		body_width = value
		queue_redraw()
## 세워 볼 자리 — 1층은 선수 시작 자리, 2층은 가운데
@export var body_spots: PackedVector2Array = PackedVector2Array([
	Vector2(-390.0, 430.0), Vector2(390.0, 430.0), Vector2(0.0, 100.0)]):
	set(value):
		body_spots = value
		queue_redraw()

@export_group("색")
@export var body_color: Color = Color(0.95, 0.75, 0.25, 0.45)
@export var line_color: Color = Color(0.4, 0.9, 1.0, 0.7)
@export var text_color: Color = Color(1.0, 1.0, 1.0, 0.85)

func _ready() -> void:
	if not Engine.is_editor_hint() and not show_in_game:
		visible = false

func _draw() -> void:
	if not Engine.is_editor_hint() and not show_in_game:
		return
	_draw_levels()
	_draw_bodies()

## 바닥·2층·벽이 어디인지 — 맵 노드를 옮기면 이 값도 같이 고쳐야 한다
func _draw_levels() -> void:
	var span: float = wall_half_width + 120.0
	draw_line(Vector2(-span, ground_y), Vector2(span, ground_y), line_color, 2.0)
	draw_line(Vector2(-upper_half_width, upper_y), Vector2(upper_half_width, upper_y), line_color, 2.0)
	for x in [-wall_half_width, wall_half_width]:
		draw_line(Vector2(x, ground_y), Vector2(x, ground_y - 700.0), line_color, 2.0)
	var font: Font = ThemeDB.fallback_font
	if font:
		draw_string(font, Vector2(-span + 8.0, ground_y - 8.0),
			"1층 바닥 y=%d" % roundi(ground_y), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, text_color)
		draw_string(font, Vector2(-upper_half_width + 8.0, upper_y - 8.0),
			"2층 y=%d" % roundi(upper_y), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, text_color)

## 캐릭터가 설 자리와 키 — 대전에서야 생기는 몸을 미리 가늠한다
func _draw_bodies() -> void:
	if body_height <= 0.0:
		return
	for spot in body_spots:
		draw_rect(Rect2(spot.x - body_width * 0.5, spot.y - body_height, body_width, body_height),
			body_color)
		draw_line(Vector2(spot.x - body_width, spot.y - body_height),
			Vector2(spot.x + body_width, spot.y - body_height), body_color, 2.0)
