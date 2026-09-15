class_name Settings
extends Control

## 설정 화면 — 메인 메뉴 위에 팝업(카드)으로 덮어 씌워진다. 뒤의 메인 메뉴는 Scrim(반투명 검정)을 통해
## 살짝 비쳐 보인다. 위쪽 3개 탭 버튼(그래픽/오디오/조작)을 누르면 그 아래 내용 영역이 바뀐다.
## 그래픽·오디오는 GameState가 즉시 적용 + 저장하고, 조작키는 여기서 바로 재배정 가능(GameState.rebind_action)

## 닫기 버튼을 누르거나 ESC를 눌러 팝업이 닫힐 때(슬라이드 연출이 끝난 뒤 나온다).
## 부르는 쪽(MainMenu)이 포커스를 되돌리고 가려뒀던 버튼을 다시 보여주는 데 쓴다
signal closed

## 열릴 때 화면 위에서 미끄러져 내려오는 데 걸리는 시간(초)
@export var open_time: float = 0.35
## 닫힐 때 다시 위로 미끄러져 올라가는 시간(초) — 여는 것보다 살짝 빠른 게 답답하지 않다
@export var close_time: float = 0.25

## 액션 이름 뒷부분(p1_/p2_ 접두사 제외) -> 화면에 보여줄 한국어 라벨
const ACTION_LABELS := {
	"left": "왼쪽", "right": "오른쪽", "jump": "점프", "down": "아래",
	"basic_attack": "기본공격", "skill_1": "스킬1", "skill_2": "스킬2", "ultimate": "궁극기",
}
const ROWS := ["left", "right", "jump", "down", "basic_attack", "skill_1", "skill_2", "ultimate"]

@onready var tab_buttons := {
	"graphics": $Card/CardVBox/HeaderVBox/TabRow/GraphicsTabButton,
	"audio": $Card/CardVBox/HeaderVBox/TabRow/AudioTabButton,
	"controls": $Card/CardVBox/HeaderVBox/TabRow/ControlsTabButton,
}
@onready var panels := {
	"graphics": $Card/CardVBox/BodyVBox/GraphicsPanel,
	"audio": $Card/CardVBox/BodyVBox/AudioPanel,
	"controls": $Card/CardVBox/BodyVBox/ControlsPanel,
}

@onready var fullscreen_check: CheckButton = $Card/CardVBox/BodyVBox/GraphicsPanel/FullscreenRow/FullscreenCheck
@onready var resolution_option: OptionButton = $Card/CardVBox/BodyVBox/GraphicsPanel/ResolutionRow/ResolutionOption
@onready var volume_slider: HSlider = $Card/CardVBox/BodyVBox/AudioPanel/VolumeRow/VolumeSlider
@onready var volume_value_label: Label = $Card/CardVBox/BodyVBox/AudioPanel/VolumeRow/VolumeValueLabel
@onready var p1_column: VBoxContainer = $Card/CardVBox/BodyVBox/ControlsPanel/Columns/P1Column
@onready var p2_column: VBoxContainer = $Card/CardVBox/BodyVBox/ControlsPanel/Columns/P2Column

## 닫혔을 때 (오버레이로 열렸을 때만 의미가 있다)
signal closed

## **다른 화면 위에 얹어서 연 것인지.** 켜면 "뒤로"·ESC가 메인 메뉴로 가지 않고 자기만 닫는다.
## 일시정지 화면의 "설정"이 이 방식으로 연다 — 대전 중에 장면을 바꿀 수 없기 때문이다
@export var overlay_mode: bool = false

## 지금 새 키 입력을 기다리고 있는 액션 이름. 빈 문자열이면 대기 중이 아님
var _listening_action: String = ""
var _key_buttons: Dictionary = {}  # {action: Button}

@onready var _card: Control = $Card
@onready var _scrim: ColorRect = $Scrim

## Scrim이 다 깔렸을 때의 진하기(씬에 저장된 값을 기억해뒀다가 그만큼까지 어두워진다)
var _scrim_target_alpha: float = 0.55
## 연출이 얼마나 진행됐는지(초). 음수면 연출 중이 아니다
var _anim_time: float = -1.0
## 지금 여는 중인지(false면 닫는 중)
var _opening: bool = true

func _ready() -> void:
	for suffix in ROWS:
		p1_column.add_child(_make_key_row("p1_" + suffix, ACTION_LABELS[suffix]))
	for suffix in ROWS:
		p2_column.add_child(_make_key_row("p2_" + suffix, ACTION_LABELS[suffix]))
	_setup_graphics_audio_controls()
	_show_tab("graphics")
	tab_buttons["graphics"].grab_focus()
	_scrim_target_alpha = _scrim.color.a
	_opening = true
	_anim_time = 0.0
	_apply_slide(0.0)

## u=0이면 화면 위로 완전히 벗어난 상태, u=1이면 제자리(카드가 화면을 꽉 채운 상태)
func _apply_slide(u: float) -> void:
	var shift: float = lerpf(-get_viewport_rect().size.y, 0.0, u)
	_card.offset_top = shift
	_card.offset_bottom = shift
	_scrim.color.a = _scrim_target_alpha * u

func _process(delta: float) -> void:
	if _anim_time < 0.0:
		return
	var duration: float = open_time if _opening else close_time
	_anim_time = minf(_anim_time + delta, duration)
	var t: float = _anim_time / maxf(duration, 0.001)
	# 뒤로 갈수록 느려지게(감속) — 툭 내려왔다가 사뿐히 멈추는 느낌
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	_apply_slide(eased if _opening else 1.0 - eased)
	if _anim_time >= duration:
		_anim_time = -1.0
		if not _opening:
			# 일시정지 화면 위에 얹혀 열린 경우엔 화면을 바꾸지 않고 자기만 닫는다 —
			# 여기서 장면을 바꾸면 하던 대전이 통째로 날아간다
			if overlay_mode:
				closed.emit()
				queue_free()
			else:
				get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

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
	# 빌드에서는 소리를 통째로 꺼 뒀으므로(GameState.MUTE_IN_BUILD) 슬라이더를 만져도 아무 일도 안 난다 —
	# 헛돌게 두면 고장난 줄 아니까 아예 못 만지게 하고 "음소거"라고 알려준다
	if GameState.is_audio_muted():
		volume_slider.editable = false
		volume_value_label.text = "음소거"

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

## 닫는 연출(위로 슬라이드 아웃)을 시작한다 — 다 끝나면 _process가 overlay_mode를 보고
## (오버레이면) closed를 보내고 스스로를 지우거나, (아니면) 메인 메뉴로 장면을 바꾼다.
## 이미 닫는 중이면 두 번 눌러도 무시한다
func _on_back_pressed() -> void:
	if _anim_time >= 0.0 and not _opening:
		return
	_opening = false
	_anim_time = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if _listening_action == "" and event.is_action_pressed("ui_cancel"):
		# **먹었다는 표시를 닫기 전에 해야 한다** — 일시정지 화면 위에 얹혀 있을 때 이걸 빼먹으면
		# 뒤에 있는 PauseMenu도 같은 ESC를 받아서 설정과 일시정지가 한꺼번에 닫힌다.
		# 그리고 _on_back_pressed()가 장면을 바꾼 뒤에는 get_viewport()가 null이라 순서를 뒤집으면 에러가 난다
		get_viewport().set_input_as_handled()
		_on_back_pressed()
