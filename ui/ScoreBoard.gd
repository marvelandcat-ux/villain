@tool
class_name ScoreBoard
extends Control

## 화면 위 **스코어보드** — 세 칸짜리 가로 띠.
##
##  `[ P1 점수 ] / 게임 시간 / [ P2 점수 ]`
##
## 가운데 칸만 **평행사변형**이라 양옆 칸은 자연스럽게 사다리꼴이 된다(사용자 러프).
## 왼쪽은 파랑(P1), 오른쪽은 빨강(P2), 가운데는 어두운 중립색이다.
##
## 글자 세 개(P1 점수 / 시간 / P2 점수)는 자식 Label이라 **에디터에서 폰트·크기·색을 그대로 바꾸면 된다**.
## 자리는 이 스크립트가 세 칸 가운데에 맞춰 준다.
##
## 값은 `set_score(p1, p2)`와 `set_time(초)`로 넣는다. 시간이 0 이하면 가운데 칸 글자를 비운다

@export_group("모양")
## 보드 전체 크기(px). **기본은 (0,0)이라 노드 크기를 그대로 따라간다** —
## 에디터에서 네모를 끌어 키우거나 옮기면 그림·글자 자리가 알아서 따라온다.
## 값을 직접 넣으면 노드 크기와 상관없이 그 크기로 그린다(거의 쓸 일 없다)
@export var board_size: Vector2 = Vector2.ZERO:
	set(value):
		board_size = value
		_refresh()
## 가운데 평행사변형의 **아래쪽 변 너비 ÷ 보드 너비**(0~1).
## px가 아니라 **비율**이라, 보드를 키우거나 줄여도 세 칸 비율이 그대로 유지된다
@export_range(0.05, 0.9, 0.001) var center_ratio: float = 0.327:
	set(value):
		center_ratio = value
		_refresh()
## 비스듬한 정도 **÷ 보드 높이**. 이것도 비율이라 보드 높이가 바뀌어도 기울기가 똑같이 보인다
@export_range(0.0, 2.0, 0.01) var lean_ratio: float = 0.6:
	set(value):
		lean_ratio = value
		_refresh()

@export_group("색")
## 왼쪽 칸(P1) 색과 오른쪽 칸(P2) 색
@export var p1_color: Color = Color(0.16, 0.40, 0.90, 1.0):
	set(value):
		p1_color = value
		_refresh()
@export var p2_color: Color = Color(0.88, 0.17, 0.21, 1.0):
	set(value):
		p2_color = value
		_refresh()
## 가운데(시간) 칸 색
@export var center_color: Color = Color(0.10, 0.10, 0.15, 1.0):
	set(value):
		center_color = value
		_refresh()
## 바깥 테두리와 칸 사이 경계선의 색·두께(px)
@export var border_color: Color = Color(0.08, 0.08, 0.12, 1.0):
	set(value):
		border_color = value
		_refresh()
@export var border_width: float = 5.0:
	set(value):
		border_width = value
		_refresh()
## 칸 사이 경계선 두께(px). 바깥 테두리와 따로 준다
@export var divider_width: float = 5.0:
	set(value):
		divider_width = value
		_refresh()
## 보드 뒤에 깔리는 그림자. 알파 0이면 안 그린다
@export var shadow_color: Color = Color(0.03, 0.03, 0.06, 0.4):
	set(value):
		shadow_color = value
		_refresh()
@export var shadow_offset: Vector2 = Vector2(0, 5):
	set(value):
		shadow_offset = value
		_refresh()

@export_group("글자")
## 세 글자가 각자 칸 가운데에서 비키는 정도(px)
@export var score_offset: Vector2 = Vector2(0, 0):
	set(value):
		score_offset = value
		_refresh()
@export var time_offset: Vector2 = Vector2(0, 0):
	set(value):
		time_offset = value
		_refresh()
## 남은 시간이 이 값 이하로 떨어지면 시간 글자가 **급한 색**으로 바뀐다(초)
@export var hurry_seconds: float = 10.0
@export var hurry_color: Color = Color(1.0, 0.38, 0.33, 1.0)

@export_group("에디터 미리보기")
## 에디터에서 보여 줄 값 — 게임에서는 `set_score`/`set_time`이 덮어쓴다
@export var preview_p1: int = 1:
	set(value):
		preview_p1 = value
		_refresh()
@export var preview_p2: int = 0:
	set(value):
		preview_p2 = value
		_refresh()
@export var preview_time: int = 99:
	set(value):
		preview_time = value
		_refresh()

@onready var _p1_label: Label = get_node_or_null("P1Score")
@onready var _p2_label: Label = get_node_or_null("P2Score")
@onready var _time_label: Label = get_node_or_null("TimeLabel")

## 시간 글자의 원래 색 — 급한 색으로 바꿨다 되돌릴 때 쓴다
var _time_rest_color: Color = Color.WHITE
var _time_rest_saved: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()
	if Engine.is_editor_hint():
		return
	set_score(preview_p1, preview_p2)
	set_time(float(preview_time))

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_refresh()

## 라운드 점수를 넣는다
func set_score(p1: int, p2: int) -> void:
	if _p1_label:
		_p1_label.text = str(p1)
	if _p2_label:
		_p2_label.text = str(p2)

## 남은 시간을 넣는다(초). 0 이하면 가운데 칸을 비운다 — 시간 제한 없는 방
func set_time(seconds: float) -> void:
	if _time_label == null:
		return
	if not _time_rest_saved:
		_time_rest_color = _time_label.get_theme_color("font_color")
		_time_rest_saved = true
	if seconds <= 0.0:
		_time_label.text = ""
		return
	_time_label.text = str(ceili(seconds))
	_time_label.add_theme_color_override("font_color", hurry_color if seconds <= hurry_seconds else _time_rest_color)

## 실제로 쓸 보드 크기 — board_size가 0이면 Control 크기를 쓴다
func _board() -> Vector2:
	return board_size if board_size.x > 1.0 and board_size.y > 1.0 else size

## 지금 보드 크기에서 가운데 칸이 실제로 몇 px인지
func _center_px() -> float:
	return _board().x * clampf(center_ratio, 0.0, 1.0)

## 지금 보드 크기에서 기울기가 실제로 몇 px인지
func _lean_px() -> float:
	return _board().y * lean_ratio

func _refresh() -> void:
	queue_redraw()
	_place_labels()

func _draw() -> void:
	var b: Vector2 = _board()
	var h: float = b.y
	var slant: float = _lean_px() * 0.5
	# 가운데 평행사변형의 아래 변 좌우 x
	var half_center: float = _center_px() * 0.5
	var c0: float = b.x * 0.5 - half_center
	var c1: float = b.x * 0.5 + half_center
	if shadow_color.a > 0.0:
		draw_rect(Rect2(shadow_offset, b), shadow_color, true)
	# 왼쪽 칸(P1) — 위쪽 변이 기울어 사다리꼴이 된다
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 0), Vector2(c0 + slant, 0), Vector2(c0 - slant, h), Vector2(0, h)]), p1_color)
	# 가운데 칸(시간) — 평행사변형
	draw_colored_polygon(PackedVector2Array([
		Vector2(c0 + slant, 0), Vector2(c1 + slant, 0), Vector2(c1 - slant, h), Vector2(c0 - slant, h)]), center_color)
	# 오른쪽 칸(P2)
	draw_colored_polygon(PackedVector2Array([
		Vector2(c1 + slant, 0), Vector2(b.x, 0), Vector2(b.x, h), Vector2(c1 - slant, h)]), p2_color)
	# 칸 사이 경계선
	if divider_width > 0.0:
		draw_line(Vector2(c0 + slant, 0), Vector2(c0 - slant, h), border_color, divider_width)
		draw_line(Vector2(c1 + slant, 0), Vector2(c1 - slant, h), border_color, divider_width)
	# 바깥 테두리
	if border_width > 0.0:
		draw_rect(Rect2(Vector2.ZERO, b), border_color, false, border_width)

## 세 글자를 각 칸 가운데에 놓는다
func _place_labels() -> void:
	var b: Vector2 = _board()
	var half_center: float = _center_px() * 0.5
	var c0: float = b.x * 0.5 - half_center
	var c1: float = b.x * 0.5 + half_center
	_center_label(_p1_label, Vector2(c0 * 0.5, b.y * 0.5) + score_offset)
	_center_label(_time_label, Vector2(b.x * 0.5, b.y * 0.5) + time_offset)
	_center_label(_p2_label, Vector2((c1 + b.x) * 0.5, b.y * 0.5) + score_offset)
	if Engine.is_editor_hint():
		if _p1_label:
			_p1_label.text = str(preview_p1)
		if _p2_label:
			_p2_label.text = str(preview_p2)
		if _time_label:
			_time_label.text = str(preview_time)

func _center_label(label: Label, at: Vector2) -> void:
	if label == null:
		return
	label.position = at - label.size * 0.5
