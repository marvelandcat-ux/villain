class_name Settings
extends Control

## 설정 화면 — 부르는 화면 위에 덮어 씌워진다. 뒤 화면은 Scrim(반투명 검정)을 통해 비쳐 보인다.
## **메인 메뉴와 일시정지 화면 둘 다 이 방식으로 연다** — 장면을 안 바꾸므로 대전 중에 열어도 판이 안 날아간다.
##
## (2026-09-27 개편) 러프대로 **도감과 같은 틀**로 바꿨다 —
## 왼쪽 위에 ◀ + "설정", 그 아래 사선 탭 3개(그래픽/오디오/조작), 맨 아래 넓은 사선 "닫기".
## 칸은 전부 평행사변형(FanTile)이고, 전체화면은 빨간 덩이가 미끄러져 들어오는 스위치(SlantToggle)다.
##
## **화면은 씬이 아니라 코드로 만든다** — 칸 자리를 아래 상수 한 군데에서만 고치면 되고,
## 도감(CharacterDex)이 목록 칸을 코드로 만드는 방식과 같다

## 닫힐 때(슬라이드 연출이 끝난 뒤) 알린다. 부르는 쪽(MainMenu)이 포커스를 되돌리는 데 쓴다
signal closed

@export var open_time: float = 0.35
@export var close_time: float = 0.25

## --- 색 (도감 탭과 같은 값) ---
const TAB_COLOR := Color(0.09, 0.07, 0.13, 0.82)
const TAB_COLOR_ON := Color(0.72, 0.18, 0.28, 0.95)
const TEXT_COLOR := Color(0.86, 0.82, 0.92, 1.0)
const TEXT_COLOR_ON := Color(1.0, 1.0, 1.0, 1.0)
const OUTLINE_COLOR := Color(0.62, 0.58, 0.72, 0.85)
const PANEL_COLOR := Color(0.13, 0.11, 0.17, 0.85)

## --- 자리 (칸 위치를 바꾸려면 여기만 고치면 된다) ---
const TAB_RECT := Rect2(296.0, 150.0, 260.0, 64.0)
## 탭끼리 기울기만큼 겹쳐 놓아야 대각선 변이 맞물린다
const TAB_LEAN := 46.0
const LABEL_RECT := Rect2(300.0, 320.0, 250.0, 56.0)
const CONTROL_X := 580.0
const ROW_STEP := 80.0
const CLOSE_RECT := Rect2(300.0, 620.0, 680.0, 62.0)

const ACTION_LABELS := {
	"left": "왼쪽", "right": "오른쪽", "jump": "점프", "down": "아래",
	"basic_attack": "기본공격", "skill_1": "스킬1", "skill_2": "스킬2", "ultimate": "궁극기",
}
const ROWS := ["left", "right", "jump", "down", "basic_attack", "skill_1", "skill_2", "ultimate"]

@onready var _card: Control = $Card
@onready var _scrim: ColorRect = $Scrim

var _tabs: Dictionary = {}     # {이름: FanTile}
var _panels: Dictionary = {}   # {이름: Control}
var _mode: String = "graphics"

var _fullscreen_toggle: SlantToggle = null
var _resolution_box: FanTile = null
var _volume_slider: HSlider = null
var _volume_value: Label = null
var _key_buttons: Dictionary = {}
## 지금 새 키 입력을 기다리는 액션. 빈 문자열이면 대기 중이 아님
var _listening_action: String = ""

var _scrim_target_alpha: float = 0.55
## 연출 진행 시간(초). 음수면 연출 중이 아니다
var _anim_time: float = -1.0
var _opening: bool = true

func _ready() -> void:
	_build()
	_show_tab("graphics")
	_scrim_target_alpha = _scrim.color.a
	_opening = true
	_anim_time = 0.0
	_apply_slide(0.0)

# ---------------------------------------------------------------- 화면 만들기

func _build() -> void:
	_card.add_child(_make_back_button())
	_card.add_child(_make_title())
	var names := [["graphics", "그래픽"], ["audio", "오디오"], ["controls", "조작"]]
	for i in range(names.size()):
		var tab := _make_tab(str(names[i][1]), i)
		tab.pressed.connect(_show_tab.bind(str(names[i][0])))
		_tabs[str(names[i][0])] = tab
		_card.add_child(tab)
	_panels["graphics"] = _build_graphics_panel()
	_panels["audio"] = _build_audio_panel()
	_panels["controls"] = _build_controls_panel()
	for key in _panels:
		_card.add_child(_panels[key])
	var close := _make_slant(CLOSE_RECT, 50.0, "닫기 (ESC)", 28)
	close.pressed.connect(_on_back_pressed)
	_card.add_child(close)

func _make_back_button() -> Button:
	var back := Button.new()
	back.text = "◀"
	back.flat = true
	back.position = Vector2(1.0, 1.0)
	back.size = Vector2(66.0, 66.0)
	back.pivot_offset = back.size * 0.5
	back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back.add_theme_font_size_override("font_size", 40)
	back.add_theme_color_override("font_color", TEXT_COLOR)
	back.add_theme_color_override("font_hover_color", TEXT_COLOR_ON)
	back.pressed.connect(_on_back_pressed)
	return back

func _make_title() -> Label:
	var title := Label.new()
	title.text = "설정"
	title.position = Vector2(77.0, 4.0)
	title.size = Vector2(504.0, 76.0)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.96, 0.93, 0.98, 1.0))
	return title

## 사선 탭 하나. 옆 탭과 기울기만큼 겹쳐 놓아야 대각선 변이 딱 맞물린다
func _make_tab(text: String, index: int) -> FanTile:
	var pitch: float = TAB_RECT.size.x - TAB_LEAN
	var rect := Rect2(TAB_RECT.position + Vector2(pitch * float(index), 0.0), TAB_RECT.size)
	return _make_slant(rect, TAB_LEAN, text, 30)

## 평행사변형 칸 하나를 만든다 (탭·닫기·해상도 칸이 전부 이걸 쓴다)
func _make_slant(rect: Rect2, lean: float, text: String, font_size: int) -> FanTile:
	var tile := FanTile.new()
	tile.position = rect.position
	tile.size = rect.size
	tile.lean = lean
	tile.fill_color = TAB_COLOR
	tile.backdrop_color = TAB_COLOR
	tile.name_band_ratio = 0.0
	tile.name_text = ""
	tile.display_text = text
	tile.display_font_size = font_size
	tile.plain_outline = true
	tile.plain_outline_color = OUTLINE_COLOR
	tile.plain_outline_width = 2.0
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return tile

func _make_label(text: String, rect: Rect2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	return label

## 항목 한 줄의 라벨/칸 자리 (index 0부터 아래로 ROW_STEP씩 내려간다)
func _row_label_rect(index: int) -> Rect2:
	return Rect2(LABEL_RECT.position + Vector2(0.0, ROW_STEP * float(index)), LABEL_RECT.size)

func _row_control_rect(index: int, width: float) -> Rect2:
	return Rect2(Vector2(CONTROL_X, LABEL_RECT.position.y + ROW_STEP * float(index)),
		Vector2(width, LABEL_RECT.size.y))

# ---------------------------------------------------------------- 그래픽

func _build_graphics_panel() -> Control:
	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	panel.add_child(_make_label("전체화면", _row_label_rect(0)))
	_fullscreen_toggle = SlantToggle.new()
	var toggle_rect: Rect2 = _row_control_rect(0, 250.0)
	_fullscreen_toggle.position = toggle_rect.position
	_fullscreen_toggle.size = toggle_rect.size
	_fullscreen_toggle.outline_color = OUTLINE_COLOR
	_fullscreen_toggle.base_color = PANEL_COLOR
	_fullscreen_toggle.state_changed.connect(_on_fullscreen_toggled)
	panel.add_child(_fullscreen_toggle)

	panel.add_child(_make_label("해상도", _row_label_rect(1)))
	_resolution_box = _make_slant(_row_control_rect(1, 400.0), 38.0, "", 26)
	_resolution_box.pressed.connect(_on_resolution_pressed)
	panel.add_child(_resolution_box)

	_fullscreen_toggle.set_on_instant(GameState.is_fullscreen)
	_refresh_resolution_box()
	return panel

func _on_fullscreen_toggled(enabled: bool) -> void:
	GameState.set_fullscreen(enabled)
	_refresh_resolution_box()

## 해상도 칸 글자를 지금 값으로 맞춘다. 전체화면일 땐 바꿔도 의미가 없어서 눌리지 않게 흐려둔다
func _refresh_resolution_box() -> void:
	if _resolution_box == null:
		return
	var current: Vector2i = GameState.RESOLUTIONS[GameState.resolution_index]
	_resolution_box.display_text = "%d x %d          ∨" % [current.x, current.y]
	_resolution_box.disabled = GameState.is_fullscreen
	_resolution_box.modulate.a = 0.45 if GameState.is_fullscreen else 1.0

## 해상도 칸 바로 아래에 고를 수 있는 목록을 띄운다
func _on_resolution_pressed() -> void:
	var menu := PopupMenu.new()
	for i in range(GameState.RESOLUTIONS.size()):
		var item: Vector2i = GameState.RESOLUTIONS[i]
		menu.add_item("%d x %d" % [item.x, item.y], i)
	add_child(menu)
	menu.id_pressed.connect(func(id: int) -> void:
		GameState.set_resolution(id)
		_refresh_resolution_box())
	menu.popup_hide.connect(menu.queue_free)
	var anchor: Vector2 = _resolution_box.global_position + Vector2(0.0, _resolution_box.size.y)
	menu.position = Vector2i(anchor) + Vector2i(get_window().position)
	menu.popup()

# ---------------------------------------------------------------- 오디오

func _build_audio_panel() -> Control:
	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(_make_label("전체 볼륨", _row_label_rect(0)))

	var rect: Rect2 = _row_control_rect(0, 330.0)
	_volume_slider = HSlider.new()
	_volume_slider.position = rect.position + Vector2(0.0, rect.size.y * 0.5 - 12.0)
	_volume_slider.size = Vector2(rect.size.x, 24.0)
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.05
	_volume_slider.value = GameState.master_volume
	_volume_slider.value_changed.connect(_on_volume_changed)
	panel.add_child(_volume_slider)

	_volume_value = Label.new()
	_volume_value.position = rect.position + Vector2(rect.size.x + 20.0, 0.0)
	_volume_value.size = Vector2(120.0, rect.size.y)
	_volume_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_volume_value.add_theme_font_size_override("font_size", 26)
	_volume_value.add_theme_color_override("font_color", TEXT_COLOR)
	_volume_value.text = "%d%%" % round(GameState.master_volume * 100.0)
	panel.add_child(_volume_value)

	# 빌드에서는 소리를 통째로 꺼 뒀다(GameState.MUTE_IN_BUILD) — 헛돌게 두면 고장난 줄 아니까 못 만지게 한다
	if GameState.is_audio_muted():
		_volume_slider.editable = false
		_volume_value.text = "음소거"
	return panel

func _on_volume_changed(value: float) -> void:
	GameState.set_master_volume(value)
	_volume_value.text = "%d%%" % round(value * 100.0)

# ---------------------------------------------------------------- 조작

func _build_controls_panel() -> Control:
	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var hint := Label.new()
	hint.text = "바꿀 키를 누른 뒤 새 키를 입력하세요 (ESC로 취소)"
	hint.position = Vector2(300.0, 250.0)
	hint.size = Vector2(680.0, 32.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", TEXT_COLOR)
	panel.add_child(hint)

	for column in range(2):
		var prefix: String = "p1_" if column == 0 else "p2_"
		var header := Label.new()
		header.text = "1P" if column == 0 else "2P"
		header.position = Vector2(330.0 + 340.0 * float(column), 292.0)
		header.size = Vector2(280.0, 30.0)
		header.add_theme_font_size_override("font_size", 24)
		header.add_theme_color_override("font_color", TEXT_COLOR_ON)
		panel.add_child(header)
		for i in range(ROWS.size()):
			var suffix: String = str(ROWS[i])
			var y: float = 328.0 + 34.0 * float(i)
			var label := Label.new()
			label.text = str(ACTION_LABELS[suffix])
			label.position = Vector2(330.0 + 340.0 * float(column), y)
			label.size = Vector2(110.0, 30.0)
			label.add_theme_font_size_override("font_size", 20)
			label.add_theme_color_override("font_color", TEXT_COLOR)
			panel.add_child(label)

			var button := Button.new()
			button.position = Vector2(446.0 + 340.0 * float(column), y)
			button.size = Vector2(150.0, 30.0)
			button.text = _key_display_text(prefix + suffix)
			button.add_theme_font_size_override("font_size", 18)
			button.pressed.connect(_on_rebind_pressed.bind(prefix + suffix, button))
			panel.add_child(button)
			_key_buttons[prefix + suffix] = button

	var reset := Button.new()
	reset.text = "조작키 초기화"
	reset.position = Vector2(540.0, 566.0)
	reset.size = Vector2(200.0, 36.0)
	reset.pressed.connect(_on_reset_pressed)
	panel.add_child(reset)
	return panel

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

func _on_reset_pressed() -> void:
	GameState.reset_keybindings()
	for action in _key_buttons.keys():
		_key_buttons[action].text = _key_display_text(action)

# ---------------------------------------------------------------- 탭 전환·연출

## 고른 탭만 빨갛게 하고, 그 탭의 내용만 보여준다
func _show_tab(tab_name: String) -> void:
	_mode = tab_name
	for key in _panels:
		_panels[key].visible = (key == tab_name)
	for key in _tabs:
		var tile: FanTile = _tabs[key]
		var on: bool = key == tab_name
		tile.fill_color = TAB_COLOR_ON if on else TAB_COLOR
		tile.backdrop_color = tile.fill_color
		tile.selected = on

## u=0이면 화면 위로 완전히 벗어난 상태, u=1이면 제자리
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
	# 뒤로 갈수록 느려지게 — 툭 내려왔다가 사뿐히 멈추는 느낌
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	_apply_slide(eased if _opening else 1.0 - eased)
	if _anim_time >= duration:
		_anim_time = -1.0
		if not _opening:
			closed.emit()
			queue_free()

## 닫는 연출을 시작한다. 이미 닫는 중이면 두 번 눌러도 무시한다
func _on_back_pressed() -> void:
	if _anim_time >= 0.0 and not _opening:
		return
	_opening = false
	_anim_time = 0.0

## 재배정 대기 중일 때만 키 입력을 가로챈다. ESC면 취소하고 기존 키로 되돌린다
func _unhandled_key_input(event: InputEvent) -> void:
	if _listening_action == "" or not event.pressed or event.is_echo():
		return
	var action := _listening_action
	var button: Button = _key_buttons[action]
	var key_event := event as InputEventKey
	if key_event.physical_keycode != KEY_ESCAPE:
		GameState.rebind_action(action, key_event.physical_keycode)
	button.text = _key_display_text(action)
	_listening_action = ""
	get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _listening_action != "":
		return
	if event.is_action_pressed("ui_cancel"):
		# **먹었다는 표시를 닫기 전에 해야 한다** — 뒤쪽 메인 메뉴의 ESC가 같이 먹는 걸 막는다
		get_viewport().set_input_as_handled()
		_on_back_pressed()
