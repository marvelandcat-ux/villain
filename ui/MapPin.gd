extends Button

## 맵 선택 지구본 위의 핀 하나(임시 그림 — `_draw()`). **동그라미 가운데**가 지도 위 그 맵 자리다(2026-10-06 사용자 요청: 물방울 꼭지가 어색).
## 자리는 MapSelect가 매 프레임 `place_tip()`으로 옮긴다. 마우스를 올리거나 키보드로 고르면 커지고 흰 테두리
## 이름표는 위·아래·오른쪽·왼쪽 중 한쪽에 붙는다 — 어느 쪽인지는 MapSelect가 이름표끼리 안 겹치게 골라 준다(`set_label_side()`)

const PIN_SIZE := Vector2(22, 22)
enum LabelSide { ABOVE, BELOW, RIGHT, LEFT }
## 동그라미와 이름표 사이 틈(px) — 위·아래는 글자 외곽선이 있어 살짝 겹쳐도 붙어 보인다
const LABEL_GAP := 2.0
@export var pin_color: Color = Color(0.95, 0.3, 0.35)

var map_name: String = ""
var label_side: LabelSide = LabelSide.ABOVE
var _label: Label = null

func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = PIN_SIZE
	size = PIN_SIZE
	pivot_offset = PIN_SIZE * 0.5
	_label = Label.new()
	_label.text = map_name
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.25))
	add_child(_label)
	set_label_side(label_side)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

## 동그라미 가운데를 tip(부모 좌표)에 맞춘다
func place_tip(tip: Vector2) -> void:
	position = tip - PIN_SIZE * 0.5

## side 쪽에 이름표를 달았을 때 그 이름표가 차지하는 칸(부모 좌표, 커지는 연출은 뺀 크기)
func label_rect(side: LabelSide) -> Rect2:
	return Rect2(position + _label_offset(side), _label_size())

func set_label_side(side: LabelSide) -> void:
	label_side = side
	if _label:
		_label.size = _label_size()
		_label.position = _label_offset(side)

func _label_size() -> Vector2:
	return _label.get_combined_minimum_size() if _label else Vector2.ZERO

func _label_offset(side: LabelSide) -> Vector2:
	var s: Vector2 = _label_size()
	match side:
		LabelSide.BELOW:
			return Vector2((PIN_SIZE.x - s.x) * 0.5, PIN_SIZE.y - LABEL_GAP)
		LabelSide.RIGHT:
			return Vector2(PIN_SIZE.x + LABEL_GAP, (PIN_SIZE.y - s.y) * 0.5)
		LabelSide.LEFT:
			return Vector2(-s.x - LABEL_GAP, (PIN_SIZE.y - s.y) * 0.5)
	return Vector2((PIN_SIZE.x - s.x) * 0.5, -s.y + LABEL_GAP)

func is_highlighted() -> bool:
	return is_hovered() or has_focus()

func _process(_delta: float) -> void:
	var target: float = 1.3 if is_highlighted() else 1.0
	scale = scale.lerp(Vector2.ONE * target, 0.3)

func _draw() -> void:
	var c: Vector2 = PIN_SIZE * 0.5
	var r: float = PIN_SIZE.x * 0.5 - 2.0
	var outline: Color = Color.WHITE if is_highlighted() else Color(0.15, 0.05, 0.2)
	# 테두리 → 몸 → 가운데 흰 점
	draw_circle(c, r + 2.0, outline)
	draw_circle(c, r, pin_color)
	draw_circle(c, r * 0.38, Color.WHITE)
