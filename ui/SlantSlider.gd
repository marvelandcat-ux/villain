@tool
class_name SlantSlider
extends Control

## 평행사변형 볼륨 막대 (설정 화면 오디오 탭).
##
## 러프 그대로 **세 토막**으로 그린다 —
##   [ 빨강: 채워진 만큼 ][ 흰색: 손잡이 ][ 회색: 남은 만큼 ]
## 볼륨이 0이면 빨강이 없고 손잡이가 맨 왼쪽에, 1이면 회색이 없고 손잡이가 맨 오른쪽에 붙는다.
##
## 평행사변형은 높이에 따라 좌우가 밀리는 모양이라, 토막을 나눌 때도 같은 기울기를 따라야
## 경계선이 변과 나란해진다. 그래서 x를 직접 쓰지 않고 `_edge_x(y)`로 그 높이의 왼쪽 변을 구해서 더한다.
## SlantToggle과 같은 방식이다

## 값이 바뀔 때마다 알린다 (끌고 있는 동안에도 계속 나온다 — 소리는 즉시 반영돼야 하니까)
signal value_changed(value: float)

## 기울기(px) — 위쪽 변이 이만큼 오른쪽으로 밀린다
@export var lean: float = 46.0:
	set(v):
		lean = v
		queue_redraw()
## 0~1. 채워진 비율
@export_range(0.0, 1.0, 0.01) var value: float = 1.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
## 한 칸씩 움직이는 단위 (방향키로 조절할 때). 0이면 연속
@export var step: float = 0.05
## 채워진 쪽 / 남은 쪽 / 손잡이 색
@export var fill_color: Color = Color(0.83, 0.22, 0.31, 1.0)
@export var rest_color: Color = Color(0.72, 0.72, 0.75, 1.0)
@export var handle_color: Color = Color(0.95, 0.94, 0.97, 1.0)
## 손잡이가 막대의 몇 %를 차지하는지
@export_range(0.03, 0.3, 0.01) var handle_ratio: float = 0.14
@export var outline_color: Color = Color(0.15, 0.13, 0.19, 1.0)
@export var outline_width: float = 3.0
## 못 만지는 상태(빌드 음소거 등)면 통째로 흐려진다
@export var editable: bool = true:
	set(v):
		editable = v
		modulate.a = 1.0 if v else 0.45
		queue_redraw()

var _dragging: bool = false

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	modulate.a = 1.0 if editable else 0.45

## 그 높이(y)에서 평행사변형의 왼쪽 변이 어디인지
func _edge_x(y: float) -> float:
	var h: float = maxf(size.y, 1.0)
	return lean * (1.0 - y / h)

## a~b 구간(0~1)을 같은 기울기로 잘라낸 네 점
func _slice(a: float, b: float) -> PackedVector2Array:
	var h: float = size.y
	var w: float = maxf(size.x - lean, 1.0)
	var lo: float = minf(a, b)
	var hi: float = maxf(a, b)
	return PackedVector2Array([
		Vector2(_edge_x(0.0) + lo * w, 0.0),
		Vector2(_edge_x(0.0) + hi * w, 0.0),
		Vector2(_edge_x(h) + hi * w, h),
		Vector2(_edge_x(h) + lo * w, h),
	])

func _draw() -> void:
	# 손잡이는 막대 안에서만 움직인다 — 0일 때 왼쪽 끝, 1일 때 오른쪽 끝에 딱 붙는다
	var handle_start: float = value * (1.0 - handle_ratio)
	var handle_end: float = handle_start + handle_ratio
	if handle_start > 0.0:
		draw_colored_polygon(_slice(0.0, handle_start), fill_color)
	if handle_end < 1.0:
		draw_colored_polygon(_slice(handle_end, 1.0), rest_color)
	draw_colored_polygon(_slice(handle_start, handle_end), handle_color)
	# 테두리는 맨 위에 — 토막이 테두리를 덮으면 칸이 번져 보인다
	var full: PackedVector2Array = _slice(0.0, 1.0)
	var closed: PackedVector2Array = full.duplicate()
	closed.append(full[0])
	draw_polyline(closed, outline_color, outline_width)
	# 손잡이 양옆 경계선도 변과 나란하게 그어준다
	var handle: PackedVector2Array = _slice(handle_start, handle_end)
	draw_line(handle[0], handle[3], outline_color, outline_width * 0.7)
	draw_line(handle[1], handle[2], outline_color, outline_width * 0.7)

## 마우스 x를 0~1 값으로 바꾼다. 기울기 때문에 높이마다 왼쪽 변이 달라서 그 높이를 기준으로 잰다
func _value_at(local: Vector2) -> float:
	var w: float = maxf(size.x - lean, 1.0)
	var raw: float = (local.x - _edge_x(clampf(local.y, 0.0, size.y))) / w
	# 손잡이 가운데를 커서에 맞춘다 — 안 맞추면 끝으로 갈수록 손가락과 어긋난다
	raw = (raw - handle_ratio * 0.5) / maxf(1.0 - handle_ratio, 0.001)
	return clampf(raw, 0.0, 1.0)

func _set_value_from(local: Vector2) -> void:
	var v: float = _value_at(local)
	if step > 0.0:
		v = snappedf(v, step)
	if is_equal_approx(v, value):
		return
	value = v
	value_changed.emit(value)

func _gui_input(event: InputEvent) -> void:
	if not editable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			grab_focus()
			_set_value_from(event.position)
		else:
			_dragging = false
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_value_from(event.position)
		accept_event()

## 방향키로도 조절되게 한다 (패드·키보드만으로 설정을 다 만질 수 있어야 한다)
func _unhandled_key_input(event: InputEvent) -> void:
	if not editable or not has_focus() or not event.pressed:
		return
	var delta: float = 0.0
	if event.is_action("ui_right"):
		delta = maxf(step, 0.05)
	elif event.is_action("ui_left"):
		delta = -maxf(step, 0.05)
	if is_zero_approx(delta):
		return
	value = clampf(value + delta, 0.0, 1.0)
	value_changed.emit(value)
	get_viewport().set_input_as_handled()
