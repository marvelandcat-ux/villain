class_name PauseButton
extends CanvasLayer

## 화면 왼쪽 위에 늘 떠 있는 **일시정지 버튼**.
##
## (2026-09-15 피드백) 일시정지가 ESC로만 열려서 **처음 하는 사람은 멈출 방법을 모른다**는 지적을 받았다.
## 눈에 보이는 버튼을 하나 놓아 마우스로도 멈출 수 있게 한 것이다. ESC는 그대로 같이 동작한다.
##
## 그림 파일 없이 **버튼 안에 막대 두 개(Panel)를 넣어** ⏸ 모양을 만든다 — 아이콘을 따로 뽑을 필요가 없고
## 색·크기를 인스펙터에서 바로 바꿀 수 있다.
##
## `CanvasLayer`라서 씬 내용이 Control이든 Node2D든 **항상 그 위에** 그려진다.
## 스토리 장면은 `StoryFadeScene`이 시작할 때 자동으로 하나 붙여 주므로 씬마다 놓을 필요가 없다.
##
## **포커스를 안 받는다(`FOCUS_NONE`)** — 받으면 스페이스로 대사를 넘길 때 이 버튼이 눌려 버린다.
## 키보드로 멈추는 길은 ESC가 담당한다.
## 일시정지 중에는 트리가 멈춰서(`get_tree().paused`) 이 버튼도 입력을 안 받는다 — 두 번 열리지 않는다.

## 일시정지 화면 (이 버튼을 누르면 띄운다)
const PAUSE_MENU_SCENE := "res://ui/PauseMenu.tscn"

## 화면 왼쪽 위 모서리에서 떨어지는 거리(px)
@export var margin: Vector2 = Vector2(22.0, 18.0):
	set(value):
		margin = value
		if _button:
			_button.position = margin
## 버튼 한 변의 크기(px)
@export var button_size: float = 54.0
## 버튼 바탕색 / 커서를 올렸을 때 색
@export var back_color: Color = Color(0.09, 0.07, 0.13, 0.72)
@export var back_color_hover: Color = Color(0.72, 0.18, 0.28, 0.92)
## 바탕 모서리 둥글기(px)와 테두리
@export var corner_radius: int = 10
@export var border_color: Color = Color(0.86, 0.82, 0.92, 0.55)
@export var border_width: int = 2

## 켜면 일시정지 화면에서 **오른쪽 에피소드 목록을 감춘다** ("진행 중인 스토리"는 남는다).
## 대전 중에 쓰는 값이다 — 싸우다 멈춘 사람에게 다른 에피소드 목록까지 보여줄 이유가 없다
@export var hide_story_list: bool = false
## 켜면 일시정지 화면에서 **왼쪽 "일시정지" 제목을 감춘다**. 이것도 대전 중에 쓰는 값이다
@export var hide_title: bool = false

@export_group("일시정지 표시")
## 막대 두 개의 색
@export var bar_color: Color = Color(0.95, 0.93, 0.98)
## 버튼 크기 대비 막대 하나의 가로/세로 비율
@export_range(0.05, 0.4, 0.01) var bar_width_ratio: float = 0.16
@export_range(0.2, 0.9, 0.01) var bar_height_ratio: float = 0.5
## 두 막대 사이 간격 (버튼 크기 대비)
@export_range(0.02, 0.4, 0.01) var bar_gap_ratio: float = 0.14

var _button: Button

func _ready() -> void:
	# 다른 UI(대화창 등)보다 위에 오도록 레이어를 한 칸 올린다
	layer = 10
	_button = Button.new()
	_button.focus_mode = Control.FOCUS_NONE   # 스페이스로 대사 넘길 때 눌리면 안 된다
	_button.custom_minimum_size = Vector2(button_size, button_size)
	_button.size = Vector2(button_size, button_size)
	_button.position = margin
	_button.tooltip_text = "일시정지 (ESC)"
	_button.add_theme_stylebox_override("normal", _make_style(back_color))
	_button.add_theme_stylebox_override("hover", _make_style(back_color_hover))
	_button.add_theme_stylebox_override("pressed", _make_style(back_color_hover))
	_button.pressed.connect(_on_pressed)
	add_child(_button)
	_add_bars()

## 바탕 상자 하나 만들기 (색만 다르고 나머지는 같다)
func _make_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	return style

## ⏸ 모양 — 둥근 막대 두 개를 버튼 가운데에 나란히 놓는다
func _add_bars() -> void:
	var bar_size := Vector2(button_size * bar_width_ratio, button_size * bar_height_ratio)
	var gap: float = button_size * bar_gap_ratio
	var left: float = (button_size - bar_size.x * 2.0 - gap) * 0.5
	var top: float = (button_size - bar_size.y) * 0.5
	for i in range(2):
		var bar := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = bar_color
		var round_px: int = int(bar_size.x * 0.35)
		style.corner_radius_top_left = round_px
		style.corner_radius_top_right = round_px
		style.corner_radius_bottom_left = round_px
		style.corner_radius_bottom_right = round_px
		bar.add_theme_stylebox_override("panel", style)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 클릭은 버튼이 받아야 한다
		bar.position = Vector2(left + (bar_size.x + gap) * float(i), top)
		bar.size = bar_size
		_button.add_child(bar)

## 누르면 일시정지 화면을 띄운다. **이 버튼이 아니라 부모(장면 루트)에 붙인다** —
## 이 CanvasLayer가 사라져도 일시정지 화면은 남아 있어야 하고, 씬 구조도 Stage/스토리와 같아진다
func _on_pressed() -> void:
	if not ResourceLoader.exists(PAUSE_MENU_SCENE):
		push_warning("PauseButton: 일시정지 화면을 못 찾았다 — %s" % PAUSE_MENU_SCENE)
		return
	var host: Node = get_parent()
	if host == null:
		return
	var menu: Node = load(PAUSE_MENU_SCENE).instantiate()
	# add_child 전에 꺼야 _ready에서 목록을 안 만들고 제목도 안 띄운다
	if hide_story_list:
		menu.show_story_list = false
	if hide_title:
		menu.show_title = false
	host.add_child(menu)
