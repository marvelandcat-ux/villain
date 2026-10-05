@tool
class_name RoomTabBar
extends Control

## **큰 평행사변형 위쪽을 선으로 나눈 탭 줄** (방 설정 화면).
##
## 탭을 따로 떼어낸 도형으로 두지 않는다 — 판과 **똑같은 평행사변형** 안에 가로선 하나와
## 세로 구분선 몇 개를 긋고, 고른 칸만 색으로 채운다(2026-10-05 사용자 스케치).
## 그래서 이 노드는 **판과 같은 자리·같은 크기·같은 기울기**로 놓아야 한다.
##
## 평행사변형은 높이에 따라 좌우 변이 밀리므로, 선을 그을 때도 그 기울기를 따라야
## 구분선이 변과 나란해진다. 그래서 x를 직접 쓰지 않고 `_left_x(y)`/`_right_x(y)`로
## 그 높이의 변을 구해서 비율로 나눈다.
##
## 클릭도 같은 식으로 받는다 — 누른 높이에서의 좌우 변을 구해 몇 번째 칸인지 센다

## 어느 칸을 눌렀는지 알린다
signal tab_pressed(index: int)

## 칸 이름들
@export var tabs: PackedStringArray = PackedStringArray(["표준", "난장판", "사용자 설정"]):
	set(value):
		tabs = value
		queue_redraw()
## **판과 같은 기울기**(px) — 위쪽 변이 이만큼 오른쪽으로 밀린다
@export var lean: float = 44.0:
	set(value):
		lean = value
		queue_redraw()
## 탭 줄의 높이(px). 이 아래가 상세 설정 칸이다
@export var tab_height: float = 58.0:
	set(value):
		tab_height = value
		queue_redraw()
## 지금 고른 칸
@export var selected: int = 0:
	set(value):
		selected = value
		queue_redraw()

@export_group("색")
## 고른 칸을 채우는 색
@export var select_color: Color = Color(0.72, 0.18, 0.28, 0.95):
	set(value):
		select_color = value
		queue_redraw()
## 구분선 색과 굵기
@export var line_color: Color = Color(0.72, 0.18, 0.28, 0.95):
	set(value):
		line_color = value
		queue_redraw()
@export var line_width: float = 3.0:
	set(value):
		line_width = value
		queue_redraw()
## 글자 색(고른 칸 / 안 고른 칸)
@export var text_on_color: Color = Color(1, 1, 1, 1):
	set(value):
		text_on_color = value
		queue_redraw()
@export var text_off_color: Color = Color(0.86, 0.84, 0.92, 1):
	set(value):
		text_off_color = value
		queue_redraw()

@export_group("글씨")
@export var font: Font:
	set(value):
		font = value
		queue_redraw()
@export var font_size: int = 26:
	set(value):
		font_size = value
		queue_redraw()

func _ready() -> void:
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

## 그 높이에서 평행사변형의 **왼쪽 변** x. 위가 오른쪽으로 밀려 있으므로 내려갈수록 왼쪽으로 간다
func _left_x(y: float) -> float:
	var l: float = clampf(lean, 0.0, size.x * 0.5)
	return l * (1.0 - y / maxf(size.y, 1.0))

## 그 높이에서 평행사변형의 **오른쪽 변** x
func _right_x(y: float) -> float:
	var l: float = clampf(lean, 0.0, size.x * 0.5)
	return size.x - l * (y / maxf(size.y, 1.0))

## 그 높이에서 i번째 경계가 놓이는 x (0 = 왼쪽 끝, count = 오른쪽 끝)
func _edge_x(y: float, i: int, count: int) -> float:
	var left: float = _left_x(y)
	var right: float = _right_x(y)
	return left + (right - left) * float(i) / float(maxi(count, 1))

func _draw() -> void:
	var count: int = maxi(tabs.size(), 1)
	var th: float = clampf(tab_height, 4.0, size.y)
	# 고른 칸을 먼저 채운다 — 선이 그 위에 올라가야 테두리가 안 묻힌다
	if selected >= 0 and selected < count:
		draw_colored_polygon(PackedVector2Array([
			Vector2(_edge_x(0.0, selected, count), 0.0),
			Vector2(_edge_x(0.0, selected + 1, count), 0.0),
			Vector2(_edge_x(th, selected + 1, count), th),
			Vector2(_edge_x(th, selected, count), th),
		]), select_color)
	# 탭 줄 **아래 가로선** — 고른 칸 밑으로는 긋지 않아 본문과 한 덩어리로 이어진다
	for i in count:
		if i == selected:
			continue
		draw_line(Vector2(_edge_x(th, i, count), th), Vector2(_edge_x(th, i + 1, count), th),
			line_color, line_width)
	# 칸 사이 **세로 구분선** — 평행사변형 변과 같은 기울기로 눕는다
	for i in range(1, count):
		draw_line(Vector2(_edge_x(0.0, i, count), 0.0), Vector2(_edge_x(th, i, count), th),
			line_color, line_width)
	_draw_labels(count, th)

## 칸마다 이름을 가운데에 쓴다
func _draw_labels(count: int, th: float) -> void:
	var use_font: Font = font if font != null else ThemeDB.fallback_font
	if use_font == null:
		return
	for i in count:
		var text: String = tabs[i] if i < tabs.size() else ""
		if text == "":
			continue
		# 칸의 가운데 — 위·아래 경계의 한가운데라 기울기를 따라 같이 밀린다
		var mid: float = (_edge_x(0.0, i, count) + _edge_x(0.0, i + 1, count)
			+ _edge_x(th, i, count) + _edge_x(th, i + 1, count)) * 0.25
		var width: float = use_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var baseline: float = th * 0.5 + float(font_size) * 0.35
		draw_string(use_font, Vector2(mid - width * 0.5, baseline), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			text_on_color if i == selected else text_off_color)

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var index: int = tab_at(mb.position)
	if index >= 0:
		tab_pressed.emit(index)

## 누른 자리가 몇 번째 칸인지 — 탭 줄 밖이면 -1
func tab_at(point: Vector2) -> int:
	var th: float = clampf(tab_height, 4.0, size.y)
	if point.y < 0.0 or point.y > th:
		return -1
	var count: int = maxi(tabs.size(), 1)
	for i in count:
		if point.x >= _edge_x(point.y, i, count) and point.x <= _edge_x(point.y, i + 1, count):
			return i
	return -1
