class_name ClashKeyHint
extends Node2D

## 스킬 클래시(연타 미니게임)에서 **지금 두드려야 할 키**를 얼굴 아래에 보여주는 안내.
## 키보드 키캡 하나 + 그 아래 "연타!" 글자. 실제로 그 키가 눌릴 때마다 키캡이 꾹 눌렸다 튀어 오른다.
##
## 키 글자는 입력 설정(InputMap)에서 직접 읽는다 — 설정 화면에서 키를 바꾸거나 연타 키 기획이
## 바뀌어도 화면에 뜨는 글자가 저절로 맞는다. 에셋 없이 _draw()로 그려서 화풍에 안 묶인다

## 키캡 한 변 길이(px)
@export var key_size: float = 58.0
## 키캡 아래로 보이는 두께(px) — 눌리면 이만큼 내려앉는다
@export var key_depth: float = 7.0
@export var key_color: Color = Color(0.98, 0.97, 0.95)
@export var key_side_color: Color = Color(0.62, 0.6, 0.66)
@export var key_edge_color: Color = Color(0.06, 0.05, 0.08)
@export var key_edge_width: int = 4
@export var key_font_size: int = 34
## 키캡과 "연타!" 사이 거리(px)
@export var text_gap: float = 34.0
@export var text: String = "연타!"
@export var text_font_size: int = 30
@export var text_color: Color = Color(1, 1, 1)
@export var text_outline_color: Color = Color(0.06, 0.05, 0.08)
@export var text_outline_size: int = 9
## 눌린 느낌이 풀리는 빠르기 (클수록 빨리 튀어 오른다)
@export var release_speed: float = 14.0
## 누를 때 키캡이 납작해지는 정도 (0.2 = 20%)
@export_range(0.0, 0.5, 0.01) var press_squash: float = 0.16

var key_label: String = "F"

## 1이면 방금 눌림, 0이면 다 올라옴
var _pressed: float = 0.0
## "연타!" 글자가 까딱거리는 위상
var _wiggle: float = 0.0

## 이 입력 액션에 묶인 키 이름을 읽어 온다 (예: "p1_basic_attack" → "F")
func set_action(action: String) -> void:
	key_label = "?"
	if action == "" or not InputMap.has_action(action):
		queue_redraw()
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			key_label = OS.get_keycode_string(code)
			break
	queue_redraw()

## 키가 한 번 눌렸다
func press() -> void:
	_pressed = 1.0

func _process(delta: float) -> void:
	_pressed = move_toward(_pressed, 0.0, delta * release_speed * maxf(_pressed, 0.25))
	_wiggle += delta
	queue_redraw()

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var p: float = _pressed
	# 눌리면 윗면이 두께만큼 내려앉고 살짝 납작해진다 — 옆면(두께)은 제자리라 "꾹" 들어간 게 보인다
	var w: float = key_size * (1.0 + press_squash * 0.5 * p)
	var h: float = key_size * (1.0 - press_squash * p)
	var sink: float = key_depth * p
	var base_top: float = -key_size * 0.5

	# 옆면 (눌려도 안 움직이는 아랫단)
	var side := StyleBoxFlat.new()
	side.bg_color = key_side_color
	side.border_color = key_edge_color
	side.set_border_width_all(key_edge_width)
	side.set_corner_radius_all(12)
	draw_style_box(side, Rect2(Vector2(-key_size * 0.5, base_top + key_depth), Vector2(key_size, key_size)))

	# 윗면 (눌리면 내려앉는 부분)
	var top_rect := Rect2(Vector2(-w * 0.5, base_top + sink + (key_size - h)), Vector2(w, h))
	var face := StyleBoxFlat.new()
	face.bg_color = key_color
	face.border_color = key_edge_color
	face.set_border_width_all(key_edge_width)
	face.set_corner_radius_all(12)
	draw_style_box(face, top_rect)

	var ks: Vector2 = font.get_string_size(key_label, HORIZONTAL_ALIGNMENT_LEFT, -1, key_font_size)
	var key_pos: Vector2 = top_rect.get_center() + Vector2(-ks.x * 0.5, key_font_size * 0.36)
	draw_string(font, key_pos, key_label, HORIZONTAL_ALIGNMENT_LEFT, -1, key_font_size, key_edge_color)

	# "연타!" — 계속 까딱거리고, 누를 때마다 살짝 커진다
	var ts: int = int(text_font_size * (1.0 + 0.18 * p))
	var tsz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ts)
	var text_y: float = key_size * 0.5 + key_depth + text_gap
	draw_set_transform(Vector2(0.0, text_y), sin(_wiggle * 12.0) * 0.07, Vector2.ONE)
	var tp := Vector2(-tsz.x * 0.5, ts * 0.36)
	draw_string_outline(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, text_outline_size, text_outline_color)
	draw_string(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, text_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
