class_name Settings
extends Control

## 설정 화면 — 위쪽 3개 탭 버튼(그래픽/오디오/조작)을 누르면 그 아래 내용 영역이 바뀐다.
## 그래픽·오디오는 GameState가 즉시 적용 + 저장하고, 조작키는 여기서 바로 재배정 가능(GameState.rebind_action)

## 액션 이름 뒷부분(p1_/p2_ 접두사 제외) -> 화면에 보여줄 한국어 라벨
const ACTION_LABELS := {
	"left": "왼쪽", "right": "오른쪽", "jump": "점프", "down": "아래",
	"basic_attack": "기본공격", "skill_1": "스킬1", "skill_2": "스킬2", "ultimate": "궁극기",
}
const ROWS := ["left", "right", "jump", "down", "basic_attack", "skill_1", "skill_2", "ultimate"]

@onready var tab_buttons := {
	"graphics": $HeaderCenter/HeaderVBox/TabRow/GraphicsTabButton,
	"audio": $HeaderCenter/HeaderVBox/TabRow/AudioTabButton,
	"controls": $HeaderCenter/HeaderVBox/TabRow/ControlsTabButton,
}
@onready var panels := {
	"graphics": $BodyCenter/BodyVBox/GraphicsPanel,
	"audio": $BodyCenter/BodyVBox/AudioPanel,
	"controls": $BodyCenter/BodyVBox/ControlsPanel,
}

@onready var fullscreen_check: CheckButton = $BodyCenter/BodyVBox/GraphicsPanel/FullscreenRow/FullscreenCheck
@onready var resolution_option: OptionButton = $BodyCenter/BodyVBox/GraphicsPanel/ResolutionRow/ResolutionOption
@onready var volume_slider: HSlider = $BodyCenter/BodyVBox/AudioPanel/VolumeRow/VolumeSlider
@onready var volume_value_label: Label = $BodyCenter/BodyVBox/AudioPanel/VolumeRow/VolumeValueLabel
@onready var p1_column: VBoxContainer = $BodyCenter/BodyVBox/ControlsPanel/Columns/P1Column
@onready var p2_column: VBoxContainer = $BodyCenter/BodyVBox/ControlsPanel/Columns/P2Column

## 지금 새 키 입력을 기다리고 있는 액션 이름. 빈 문자열이면 대기 중이 아님
var _listening_action: String = ""
var _key_buttons: Dictionary = {}  # {action: Button}

func _ready() -> void:
	for suffix in ROWS:
		p1_column.add_child(_make_key_row("p1_" + suffix, ACTION_LABELS[suffix]))
	for suffix in ROWS:
		p2_column.add_child(_make_key_row("p2_" + suffix, ACTION_LABELS[suffix]))
	_setup_graphics_audio_controls()
	_show_tab("graphics")

## 탭 버튼을 누르면 그 탭의 패널만 보이고 나머지는 숨긴다. 버튼 자체도 선택된 탭만 밝게 눌린 느낌으로 표시한다
func _show_tab(tab_name: String) -> void:
	for name in panels:
		panels[name].visible = (name == tab_name)
	for name in tab_buttons:
		tab_buttons[name].button_pressed = (name == tab_name)

## 그래픽/오디오 컨트롤을 GameState에 저장된 현재 값으로 채운다(전체화면 여부, 해상도, 볼륨)
func _setup_graphics_audio_controls() -> void:
	for size in GameState.RESOLUTIONS:
		resolution_option.add_item("%dx%d" % [size.x, size.y])
	resolution_option.selected = GameState.resolution_index
	resolution_option.disabled = GameState.is_fullscreen

	fullscreen_check.button_pressed = GameState.is_fullscreen

	volume_slider.value = GameState.master_volume
	volume_value_label.text = "%d%%" % round(GameState.master_volume * 100)

func _on_fullscreen_toggled(enabled: bool) -> void:
	GameState.set_fullscreen(enabled)
	resolution_option.disabled = enabled  # 전체화면 중엔 해상도를 바꿔도 의미가 없어서 비활성화

func _on_resolution_selected(index: int) -> void:
	GameState.set_resolution(index)

func _on_volume_changed(value: float) -> void:
	GameState.set_master_volume(value)
	volume_value_label.text = "%d%%" % round(value * 100)

func _make_key_row(action: String, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(80, 0)
	row.add_child(label)

	var key_button := Button.new()
	key_button.custom_minimum_size = Vector2(110, 0)
	key_button.text = _key_display_text(action)
	key_button.pressed.connect(_on_rebind_pressed.bind(action, key_button))
	row.add_child(key_button)
	_key_buttons[action] = key_button

	return row

func _key_display_text(action: String) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "(없음)"
	return OS.get_keycode_string((events[0] as InputEventKey).physical_keycode)

func _on_rebind_pressed(action: String, button: Button) -> void:
	if _listening_action != "":
		return
	_listening_action = action
	button.text = "키 입력..."

## 재배정 대기 중일 때만 실제 키 입력을 가로챈다. ESC를 누르면 재배정을 취소하고 기존 키로 되돌린다
func _unhandled_key_input(event: InputEvent) -> void:
	if _listening_action == "" or not event.pressed or event.is_echo():
		return
	var action := _listening_action
	var button: Button = _key_buttons[action]
	var key_event := event as InputEventKey
	if key_event.physical_keycode == KEY_ESCAPE:
		button.text = _key_display_text(action)
	else:
		GameState.rebind_action(action, key_event.physical_keycode)
		button.text = _key_display_text(action)
	_listening_action = ""
	get_viewport().set_input_as_handled()

func _on_reset_pressed() -> void:
	GameState.reset_keybindings()
	for action in _key_buttons.keys():
		_key_buttons[action].text = _key_display_text(action)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if _listening_action == "" and event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
