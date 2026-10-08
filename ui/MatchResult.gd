class_name MatchResult
extends CanvasLayer

## 대전 종료 후 승패 결과를 보여주는 오버레이. Stage.gd가 승자를 판정하면 show_result()를 호출한다
@onready var _title_label: Label = $Panel/VBox/TitleLabel
@onready var _retry_button: Button = $Panel/VBox/RetryButton
@onready var _menu_button: Button = $Panel/VBox/MenuButton

@export_group("아래 띠(연행 장면 위)")
## dock_bottom()으로 접었을 때 띠 크기(px)와 화면 아래에서 띄우는 거리.
## 연행 행렬의 발이 화면 y 610~645쯤에서 끝나서, 띠 윗변(720 - 12 - 72 = 636)이 발밑 땅만 덮게 낮고 얇게 잡았다
@export var dock_size: Vector2 = Vector2(860.0, 72.0)
@export var dock_margin: float = 12.0
## 띠가 아래에서 올라오는 시간(초)
@export var dock_slide_time: float = 0.32
## 버튼 바탕(게임 그림처럼 납작한 노랑 + 굵은 검은 테두리)
@export var dock_button_color: Color = Color(1.0, 0.82, 0.18)

const DOCK_FONT := "res://fonts/Jua-Regular.ttf"
const OUTLINE_COLOR := Color(0.06, 0.05, 0.08)

func show_result(p1_won: bool, winner_name: String) -> void:
	# 대전(사람끼리·컴퓨터 상대)은 어느 쪽 편도 아니다 — P2가 이겨도 "패배"가 아니라 누가 이겼는지를 쓴다
	if GameState.game_mode == "pvp":
		_title_label.text = "%s %s 승리!" % ["P1" if p1_won else "P2", winner_name]
		return
	_title_label.text = ("승리! (%s)" if p1_won else "패배... (%s 승)") % winner_name

## 양쪽이 동시에 쓰러졌을 때 (무승부)
func show_draw() -> void:
	_title_label.text = "무승부! 둘 다 쓰러졌습니다"

## 최종 승부가 아직 안 난 라운드 중간 결과 — 버튼 없이 점수만 잠깐 보여주고 Stage.gd가 알아서 다음 라운드로 넘어간다
func show_round_result(p1_won: bool, is_draw: bool, p1_wins: int, p2_wins: int) -> void:
	_retry_button.visible = false
	_menu_button.visible = false
	var round_text: String = "무승부" if is_draw else ("P1 라운드 승!" if p1_won else "P2 라운드 승!")
	_title_label.text = "%s  (%d : %d)" % [round_text, p1_wins, p2_wins]

## 스토리처럼 자동으로 다음 장면으로 이어질 때는 버튼을 숨긴다 — 누를 틈을 주면
## 넘어가는 도중에 재시도가 눌려서 두 장면이 겹칠 수 있다
func hide_buttons() -> void:
	_retry_button.visible = false
	_menu_button.visible = false

## 연행 장면 위에 올릴 때 — 장면을 가리지 않게 **화면 아래 띠 하나**로 접는다(왼쪽 제목, 오른쪽 버튼 둘).
## add_child 뒤에 부른다(노드를 옮겨 담으므로 @onready가 잡힌 뒤여야 한다)
func dock_bottom() -> void:
	var panel: Panel = $Panel
	# 아래쪽 앵커를 먼저 옮겨야 한다 — 위쪽(1.0)을 먼저 넣으면 아래쪽(0.5)에 걸려 도로 깎인다
	panel.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -dock_margin)
	panel.set_anchor_and_offset(SIDE_TOP, 1.0, -dock_margin - dock_size.y)
	panel.set_anchor_and_offset(SIDE_LEFT, 0.5, -dock_size.x * 0.5)
	panel.set_anchor_and_offset(SIDE_RIGHT, 0.5, dock_size.x * 0.5)
	panel.add_theme_stylebox_override("panel", _box(Color(0.1, 0.09, 0.17, 0.94), 4, 16))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	var old_box: Node = $Panel/VBox
	for node in [_title_label, _retry_button, _menu_button]:
		node.reparent(row, false)
	old_box.queue_free()

	var font: Font = load(DOCK_FONT) if ResourceLoader.exists(DOCK_FONT) else null
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title_label.add_theme_font_size_override("font_size", 30)
	if font:
		_title_label.add_theme_font_override("font", font)
	for button in [_retry_button, _menu_button]:
		_style_dock_button(button, font)

	# 아래에서 톡 올라온다
	var rest_y: float = panel.position.y
	panel.position.y = rest_y + dock_size.y + dock_margin + 24.0
	var tw: Tween = panel.create_tween()
	tw.tween_property(panel, "position:y", rest_y, dock_slide_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _style_dock_button(button: Button, font: Font) -> void:
	button.custom_minimum_size = Vector2(168.0, 50.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_stylebox_override("normal", _box(dock_button_color, 4, 12))
	button.add_theme_stylebox_override("hover", _box(dock_button_color.lightened(0.25), 4, 12))
	button.add_theme_stylebox_override("pressed", _box(dock_button_color.darkened(0.18), 4, 12))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, OUTLINE_COLOR)
	button.add_theme_font_size_override("font_size", 24)
	if font:
		button.add_theme_font_override("font", font)

func _box(fill: Color, border: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = OUTLINE_COLOR
	box.set_border_width_all(border)
	box.set_corner_radius_all(radius)
	return box

func _on_retry_pressed() -> void:
	# 최종 승부가 난 뒤라 승수가 그대로면 다시 시작한 첫 라운드부터 바로 판이 끝난다
	GameState.reset_round_wins()
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")
