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
## **고른 칸과 본문을 한 바퀴 두르는 선** 색 — 둘이 한 덩어리임을 보여 준다
@export var line_color: Color = Color(0.92, 0.26, 0.38, 1.0):
	set(value):
		line_color = value
		queue_redraw()
## **안 고른 칸**의 테두리 색(기본 흰색)
@export var idle_line_color: Color = Color(0.95, 0.94, 0.97, 1.0):
	set(value):
		idle_line_color = value
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

@export_group("가운데 선")
## 본문을 좌우로 나누는 **옅은 세로선**이 놓일 자리(0=왼쪽 끝, 1=오른쪽 끝). 0이면 안 그린다.
## 판과 같은 기울기로 눕는다
@export_range(0.0, 1.0, 0.01) var split_ratio: float = 0.0:
	set(value):
		split_ratio = value
		queue_redraw()
## 선 색과 굵기 — **티 안 나게** 아주 옅게 둔다
@export var split_color: Color = Color(1.0, 1.0, 1.0, 0.1):
	set(value):
		split_color = value
		queue_redraw()
@export var split_width: float = 2.0:
	set(value):
		split_width = value
		queue_redraw()
## 선을 위아래로 얼마나 들여 그을지(px) — 끝까지 그으면 테두리에 닿아 지저분하다
@export var split_inset: float = 26.0:
	set(value):
		split_inset = value
		queue_redraw()

## **줄과 줄 사이에 긋는 가로선**들의 높이(이 노드 기준 y). 비워 두면 안 그린다.
## 판이 기울어져 있으므로 선의 좌우 끝도 그 높이의 변에 맞춰 잘린다
@export var row_line_ys: PackedFloat32Array = PackedFloat32Array():
	set(value):
		row_line_ys = value
		queue_redraw()
## 가로선을 좌우에서 얼마나 들여 그을지(px) — 끝까지 그으면 테두리에 닿아 지저분하다
@export var row_line_inset: float = 34.0:
	set(value):
		row_line_inset = value
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
	var sel: int = clampi(selected, 0, count - 1)
	# 고른 칸을 먼저 채운다 — 선이 그 위에 올라가야 테두리가 안 묻힌다
	draw_colored_polygon(PackedVector2Array([
		Vector2(_edge_x(0.0, sel, count), 0.0),
		Vector2(_edge_x(0.0, sel + 1, count), 0.0),
		Vector2(_edge_x(th, sel + 1, count), th),
		Vector2(_edge_x(th, sel, count), th),
	]), select_color)
	_draw_idle_lines(count, th, sel)
	_draw_joined_outline(count, th, sel)
	_draw_split(th)
	_draw_row_lines()
	_draw_labels(count, th)

## 본문 가운데를 가르는 옅은 세로선 — 왼쪽 줄과 오른쪽 줄을 눈으로 갈라 준다
func _draw_split(th: float) -> void:
	if split_ratio <= 0.0 or split_ratio >= 1.0:
		return
	var top: float = th + split_inset
	var bottom: float = size.y - split_inset
	if bottom <= top:
		return
	# 그 높이에서의 좌우 변을 구해 비율로 나눈다 — 그래야 선이 판의 사선 변과 나란해진다
	var a := Vector2(lerpf(_left_x(top), _right_x(top), split_ratio), top)
	var b := Vector2(lerpf(_left_x(bottom), _right_x(bottom), split_ratio), bottom)
	draw_line(a, b, split_color, split_width)

## 줄 사이 가로선 — 가운데 세로선과 같은 색을 쓴다(둘이 따로 놀면 격자가 지저분해진다)
func _draw_row_lines() -> void:
	for y in row_line_ys:
		if y <= 0.0 or y >= size.y:
			continue
		var left: float = _left_x(y) + row_line_inset
		var right: float = _right_x(y) - row_line_inset
		if right <= left:
			continue
		draw_line(Vector2(left, y), Vector2(right, y), split_color, split_width)

## **안 고른 칸**의 테두리 — 위쪽 변과 칸 사이 구분선. 고른 칸에 닿는 선은 아래에서 따로 긋는다
func _draw_idle_lines(count: int, th: float, sel: int) -> void:
	for i in count:
		if i == sel:
			continue
		draw_line(Vector2(_edge_x(0.0, i, count), 0.0), Vector2(_edge_x(0.0, i + 1, count), 0.0),
			idle_line_color, line_width)
	for i in range(1, count):
		if i == sel or i == sel + 1:
			continue
		draw_line(Vector2(_edge_x(0.0, i, count), 0.0), Vector2(_edge_x(th, i, count), th),
			idle_line_color, line_width)

## **고른 칸과 본문을 한 바퀴 두르는 선.**
## 고른 칸 위 -> 오른쪽 사선 -> 탭 아래선(오른쪽 몫) -> 판 오른쪽 변 -> 판 아래변 ->
## 판 왼쪽 변 -> 탭 아래선(왼쪽 몫) -> 고른 칸 왼쪽 사선 으로 닫는다.
## **고른 칸 아래로는 선을 안 긋는다** — 그래야 칸과 본문이 한 덩어리로 보인다
func _draw_joined_outline(count: int, th: float, sel: int) -> void:
	var h: float = size.y
	var path := PackedVector2Array([
		Vector2(_edge_x(0.0, sel, count), 0.0),
		Vector2(_edge_x(0.0, sel + 1, count), 0.0),
		Vector2(_edge_x(th, sel + 1, count), th),
		Vector2(_edge_x(th, count, count), th),
		Vector2(_right_x(h), h),
		Vector2(_left_x(h), h),
		Vector2(_edge_x(th, 0, count), th),
		Vector2(_edge_x(th, sel, count), th),
		Vector2(_edge_x(0.0, sel, count), 0.0),
	])
	draw_polyline(path, line_color, line_width)

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
