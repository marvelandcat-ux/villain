@tool
class_name SlantToggle
extends Button

## 평행사변형 켜기/끄기 스위치 (설정 화면 전체화면 항목).
## **켜면 빨간 덩이가 왼쪽으로 미끄러져 들어오고, 끄면 회색 덩이가 오른쪽으로 빠진다.**
## 러프 그대로다 — on은 왼쪽이 빨갛게 차고, off는 오른쪽이 회색으로 남는다.
##
## 평행사변형은 "높이에 따라 좌우가 밀리는" 모양이라, 안에 덩이를 그릴 때도 같은 기울기를 따라야
## 모서리가 어긋나지 않는다. 그래서 x를 직접 쓰지 않고 `_edge_x(y)`로 그 높이의 왼쪽 변을 구해서 더한다

## 상태가 바뀌었을 때 알린다 (Button의 toggled와 이름이 겹치지 않게 따로 둔다)
signal state_changed(on: bool)

## 기울기(px) — 위쪽 변이 이만큼 오른쪽으로 밀린다
@export var lean: float = 38.0:
	set(value):
		lean = value
		queue_redraw()
## 안 채워진 바탕색과 테두리
@export var base_color: Color = Color(0.13, 0.11, 0.17, 0.85):
	set(value):
		base_color = value
		queue_redraw()
@export var outline_color: Color = Color(0.62, 0.58, 0.72, 0.85)
@export var outline_width: float = 2.0
## 켰을 때 차오르는 색 / 껐을 때 남는 색
@export var on_color: Color = Color(0.83, 0.22, 0.31, 1.0)
@export var off_color: Color = Color(0.58, 0.58, 0.63, 1.0)
## 덩이가 칸의 몇 %를 차지하는지
@export_range(0.2, 0.9, 0.05) var knob_ratio: float = 0.55
## 켜짐/꺼짐이 바뀔 때 미끄러지는 시간(초)
@export var anim_time: float = 0.18
## 빈 쪽에 작게 적는 글자 (비우면 아무것도 안 쓴다)
@export var on_text: String = "켜짐"
@export var off_text: String = "꺼짐"
@export var text_size: int = 18
@export var text_color: Color = Color(0.86, 0.82, 0.92, 1.0)

## 지금 켜져 있는지
var is_on: bool = false:
	set(value):
		if is_on == value:
			return
		is_on = value
		set_process(true)

## 덩이 위치 0(꺼짐) ~ 1(켜짐). 목표로 서서히 간다
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
	return PackedVector2Array([
		Vector2(_edge_x(0.0) + a * w, 0.0),
		Vector2(_edge_x(0.0) + b * w, 0.0),
		Vector2(_edge_x(h) + b * w, h),
		Vector2(_edge_x(h) + a * w, h),
	])

func _draw() -> void:
	var full: PackedVector2Array = _slice(0.0, 1.0)
	draw_colored_polygon(full, base_color)
	# 덩이 — 꺼짐이면 오른쪽 끝에, 켜짐이면 왼쪽 끝에 붙는다
	var a: float = lerpf(1.0 - knob_ratio, 0.0, _t)
	var knob: PackedVector2Array = _slice(a, a + knob_ratio)
	draw_colored_polygon(knob, off_color.lerp(on_color, _t))
	# 테두리는 맨 위에 — 덩이가 테두리를 덮으면 칸이 번져 보인다
	var closed: PackedVector2Array = full.duplicate()
	closed.append(full[0])
	draw_polyline(closed, outline_color, outline_width)
	_draw_state_text(a)

## 덩이가 없는 쪽에 상태 글자를 적는다
func _draw_state_text(knob_a: float) -> void:
	var text: String = on_text if is_on else off_text
	if text == "":
		return
	var font: Font = get_theme_font("font")
	if font == null:
		return
	var w: float = maxf(size.x - lean, 1.0)
	# 덩이가 왼쪽(켜짐)이면 글자는 오른쪽 빈 곳에, 덩이가 오른쪽(꺼짐)이면 왼쪽 빈 곳에 적는다.
	# **_t로 판단한다** — knob_a로 보면 꺼짐(0.45)도 0.5보다 작아서 글자가 덩이 위에 겹쳐 찍혔다
	var center_ratio: float = (knob_a + knob_ratio + 1.0) * 0.5 if _t > 0.5 else knob_a * 0.5
	var y: float = size.y * 0.5
	var pos := Vector2(_edge_x(y) + center_ratio * w, y)
	var text_size_px: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size)
	draw_string(font, pos - Vector2(text_size_px.x * 0.5, -text_size_px.y * 0.32), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, text_color)
