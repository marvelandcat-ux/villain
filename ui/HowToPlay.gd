class_name HowToPlay
extends Control

## 조작 방법 화면 — 지금 실제로 등록된 키를 보여준다.
## 설정에서 키를 바꿨으면 여기 표시도 같이 바뀌도록, 고정 문자열이 아니라 InputMap에서 읽어온다.
## 키를 바꾸는 건 여기가 아니라 설정 > 조작 탭에서 한다(여기는 읽기 전용)

## 액션 이름 뒷부분(p1_/p2_ 접두사 제외) -> 화면에 보여줄 한국어 라벨
const ACTION_LABELS := {
	"left": "왼쪽 이동", "right": "오른쪽 이동", "jump": "점프", "down": "아래로",
	"basic_attack": "기본공격", "skill_1": "스킬 1", "skill_2": "스킬 2", "ultimate": "궁극기",
}
const ROWS := ["left", "right", "jump", "down", "basic_attack", "skill_1", "skill_2", "ultimate"]

@onready var _p1_column: VBoxContainer = $Center/VBox/Columns/P1Column
@onready var _p2_column: VBoxContainer = $Center/VBox/Columns/P2Column

func _ready() -> void:
	for suffix in ROWS:
		_p1_column.add_child(_make_key_row("p1_" + suffix, ACTION_LABELS[suffix]))
		_p2_column.add_child(_make_key_row("p2_" + suffix, ACTION_LABELS[suffix]))
	# 대시는 전용 키가 없고 이동키를 두 번 누르는 조작이라 InputMap에서 읽을 게 없다 — 문구를 직접 만든다
	_p1_column.add_child(_make_row("대시", "이동키 2번"))
	_p2_column.add_child(_make_row("대시", "이동키 2번"))
	# 방어는 "아래로"와 같은 키지만 누르는 순간 발동하는 별개 조작이라 따로 한 줄 보여준다
	_p1_column.add_child(_make_row("방어(1.2초)", _key_display_text("p1_down")))
	_p2_column.add_child(_make_row("방어(1.2초)", _key_display_text("p2_down")))

func _make_key_row(action: String, label_text: String) -> HBoxContainer:
	return _make_row(label_text, _key_display_text(action))

## 왼쪽에 조작 이름, 오른쪽에 키 문구를 놓은 한 줄
func _make_row(label_text: String, key_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(110, 0)
	row.add_child(name_label)

	var key_label := Label.new()
	key_label.text = key_text
	key_label.custom_minimum_size = Vector2(110, 0)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	row.add_child(key_label)

	return row

## 지금 그 액션에 등록된 첫 번째 키 이름. 설정에서 재배정하면 이 값도 따라 바뀐다
func _key_display_text(action: String) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "(없음)"
	return OS.get_keycode_string((events[0] as InputEventKey).physical_keycode)

## 조작을 바로 해볼 수 있는 훈련장. 상대도 라운드도 없이 캐릭터 하나만 세워둔 방이다
func _on_training_pressed() -> void:
	GameState.game_mode = "training"
	get_tree().change_scene_to_file("res://maps/TrainingGround.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
