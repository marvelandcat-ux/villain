extends Button

## 맵 선택 지구본 위의 핀 하나(임시 그림 — `_draw()`). 바늘 끝(아래 가운데)이 지도 위 그 맵 자리를 가리킨다.
## 자리는 MapSelect가 매 프레임 `place_tip()`으로 옮긴다. 마우스를 올리거나 키보드로 고르면 커지고 흰 테두리

const PIN_SIZE := Vector2(30, 42)
@export var pin_color: Color = Color(0.95, 0.3, 0.35)

var map_name: String = ""
var _label: Label = null

func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = PIN_SIZE
	size = PIN_SIZE
	pivot_offset = Vector2(PIN_SIZE.x * 0.5, PIN_SIZE.y)
	_label = Label.new()
	_label.text = map_name
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.25))
	_label.size = Vector2(140, 24)
	_label.position = Vector2((PIN_SIZE.x - 140.0) * 0.5, -24)
	add_child(_label)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

## 바늘 끝을 tip(부모 좌표)에 맞춘다
func place_tip(tip: Vector2) -> void:
	position = tip - Vector2(PIN_SIZE.x * 0.5, PIN_SIZE.y)

func is_highlighted() -> bool:
	return is_hovered() or has_focus()

func _process(_delta: float) -> void:
	var target: float = 1.3 if is_highlighted() else 1.0
	scale = scale.lerp(Vector2.ONE * target, 0.3)

func _draw() -> void:
	var r: float = PIN_SIZE.x * 0.5 - 2.0
	var head := Vector2(PIN_SIZE.x * 0.5, r + 2.0)
	var tip := Vector2(PIN_SIZE.x * 0.5, PIN_SIZE.y)
	var outline: Color = Color.WHITE if is_highlighted() else Color(0.15, 0.05, 0.2)
	var body := PackedVector2Array([head + Vector2(-r * 0.8, r * 0.55), head + Vector2(r * 0.8, r * 0.55), tip])
	# 테두리 → 몸 → 가운데 흰 점
	draw_circle(head, r + 2.0, outline)
	draw_colored_polygon(PackedVector2Array([body[0] + Vector2(-2, 0), body[1] + Vector2(2, 0), tip + Vector2(0, 2)]), outline)
	draw_circle(head, r, pin_color)
	draw_colored_polygon(body, pin_color)
	draw_circle(head, r * 0.4, Color.WHITE)
