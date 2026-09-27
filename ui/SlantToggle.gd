@tool
class_name SlantToggle
extends Button

## 평행사변형 켜기/끄기 스위치 (설정 화면 전체화면 항목).
##
## **흰 칸이 움직이는 커서고, 그 밑에 핑크/회색 바탕이 깔려 있다.**
## 커서가 왼쪽 끝에 있으면 핑크가 다 가려져서 **꺼짐**, 오른쪽 끝으로 밀려가면 가려졌던
## 핑크가 왼쪽부터 드러나면서 **켜짐**이 된다. 끄면 커서가 되돌아오면서 핑크를 다시 덮는다.
## 상태 글자(켜짐/꺼짐)는 커서 위에 적혀서 커서와 같이 움직인다.
##
## 그려지는 모습은 늘 세 토막이다 —
##   [ 핑크: 드러난 만큼 ][ 흰색: 커서 ][ 회색: 아직 안 지나간 만큼 ]
## 볼륨 막대(SlantSlider)와 **똑같은 구조**다. 회색도 같은 값을 쓴다 — 설정 화면 안에서 회색이 둘이면 따로 논다.
##
## 평행사변형은 높이에 따라 좌우가 밀리는 모양이라, 토막을 나눌 때도 같은 기울기를 따라야
## 경계선이 변과 나란해진다. 그래서 x를 직접 쓰지 않고 `_edge_x(y)`로 그 높이의 왼쪽 변을 구해서 더한다

## 상태가 바뀌었을 때 알린다 (Button의 toggled와 이름이 겹치지 않게 따로 둔다)
signal state_changed(on: bool)

## 기울기(px) — 위쪽 변이 이만큼 오른쪽으로 밀린다
@export var lean: float = 38.0:
	set(value):
		lean = value
		queue_redraw()
## 커서가 지나간 자리에 드러나는 색(핑크) / 아직 안 지나간 자리에 깔린 색(회색)
@export var fill_color: Color = Color(0.83, 0.22, 0.31, 1.0):
	set(value):
		fill_color = value
		queue_redraw()
@export var rest_color: Color = Color(0.72, 0.72, 0.75, 1.0):
	set(value):
		rest_color = value
		queue_redraw()
## 움직이는 커서 색 (러프의 흰 평행사변형)
@export var knob_color: Color = Color(0.95, 0.94, 0.97, 1.0):
	set(value):
		knob_color = value
		queue_redraw()
## 커서가 칸의 몇 %를 차지하는지 (0.5면 반반)
@export_range(0.2, 0.9, 0.05) var knob_ratio: float = 0.5:
	set(value):
		knob_ratio = value
		queue_redraw()
@export var outline_color: Color = Color(0.15, 0.13, 0.19, 1.0)
@export var outline_width: float = 3.0
## 켜짐/꺼짐이 바뀔 때 커서가 미끄러지는 시간(초)
@export var anim_time: float = 0.18
## 커서 위에 적는 글자 (비우면 아무것도 안 쓴다)
@export var on_text: String = "켜짐"
@export var off_text: String = "꺼짐"
@export var text_size: int = 18
## 커서가 흰색이라 글자는 어둡게 쓴다
@export var text_color: Color = Color(0.22, 0.19, 0.27, 1.0)

## 지금 켜져 있는지
var is_on: bool = false:
	set(value):
		if is_on == value:
			return
		is_on = value
		set_process(true)

## 커서 위치 0(꺼짐, 왼쪽 끝) ~ 1(켜짐, 오른쪽 끝). 목표로 서서히 간다
var _t: float = 0.0

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	flat = true
	_t = 1.0 if is_on else 0.0
	if not Engine.is_editor_hint():
		pressed.connect(_on_pressed)
	queue_redraw()

func _on_pressed() -> void:
	is_on = not is_on
	state_changed.emit(is_on)

## 연출 없이 지금 상태로 맞춘다 (화면을 처음 열 때 저장된 값을 반영하는 용도)
func set_on_instant(on: bool) -> void:
	is_on = on
	_t = 1.0 if on else 0.0
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	var target: float = 1.0 if is_on else 0.0
	var step: float = delta / maxf(anim_time, 0.001)
	_t = move_toward(_t, target, step)
	queue_redraw()
	if is_equal_approx(_t, target):
		set_process(false)

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
	# 커서는 칸 안에서만 움직인다 — 꺼짐이면 왼쪽 끝, 켜짐이면 오른쪽 끝에 딱 붙는다
	var knob_start: float = _t * (1.0 - knob_ratio)
	var knob_end: float = knob_start + knob_ratio
	if knob_start > 0.0:
		draw_colored_polygon(_slice(0.0, knob_start), fill_color)
	if knob_end < 1.0:
		draw_colored_polygon(_slice(knob_end, 1.0), rest_color)
	draw_colored_polygon(_slice(knob_start, knob_end), knob_color)
	# 테두리는 맨 위에 — 토막이 테두리를 덮으면 칸이 번져 보인다
	var full: PackedVector2Array = _slice(0.0, 1.0)
	var closed: PackedVector2Array = full.duplicate()
	closed.append(full[0])
	draw_polyline(closed, outline_color, outline_width)
	# 커서 양옆 경계선도 변과 나란하게 그어준다
	var knob: PackedVector2Array = _slice(knob_start, knob_end)
	draw_line(knob[0], knob[3], outline_color, outline_width * 0.7)
	draw_line(knob[1], knob[2], outline_color, outline_width * 0.7)
	_draw_state_text(knob_start)

## 상태 글자는 **커서 위에** 적어서 커서와 같이 움직인다
func _draw_state_text(knob_start: float) -> void:
	var text: String = on_text if is_on else off_text
	if text == "":
		return
	var font: Font = get_theme_font("font")
	if font == null:
		return
	var w: float = maxf(size.x - lean, 1.0)
	var center_ratio: float = knob_start + knob_ratio * 0.5
	var y: float = size.y * 0.5
	var pos := Vector2(_edge_x(y) + center_ratio * w, y)
	var text_size_px: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size)
	draw_string(font, pos - Vector2(text_size_px.x * 0.5, -text_size_px.y * 0.32), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, text_color)
