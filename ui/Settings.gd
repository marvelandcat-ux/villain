@tool
class_name Settings
extends Control

## 설정 화면 — 부르는 화면 위에 덮어 씌워진다. 뒤 화면은 Scrim(반투명 검정)을 통해 비쳐 보인다.
## **메인 메뉴와 일시정지 화면 둘 다 이 방식으로 연다** — 장면을 안 바꾸므로 대전 중에 열어도 판이 안 날아간다.
##
## (2026-09-27 개편) 러프대로 **도감과 같은 틀**로 바꿨다 —
## 왼쪽 위에 ◀ + "설정", 그 아래 사선 탭 3개(그래픽/오디오/조작), 맨 아래 넓은 사선 "닫기".
##
## **칸은 전부 씬(ui/Settings.tscn)에 진짜 노드로 놓여 있다.** 에디터에서 그냥 집어서 끌면 옮겨지고,
## 손잡이로 늘리면 커진다. 이 스크립트는 자리를 정하지 않고 **동작만 붙인다** —
## `@tool`이라 에디터에서도 그대로 그려지므로 보면서 맞출 수 있다.
##
## 코드가 만드는 건 두 가지뿐이다(손으로 놓기엔 개수가 많아서):
##  - 조작 탭의 키 줄 16개 → `P1Column` / `P2Column` 안에 채운다. **그 두 칸을 끌면 통째로 따라온다**
##  - 해상도 펼침 목록 → `ResolutionList` 안에 채운다. 그 칸을 끌면 목록이 따라온다

## 닫힐 때(슬라이드 연출이 끝난 뒤) 알린다. 부르는 쪽(MainMenu)이 포커스를 되돌리는 데 쓴다
signal closed

## 에디터에는 오토로드(GameState) 인스턴스가 없다 — const(RESOLUTIONS)만 이걸로 읽고,
## 나머지 값(지금 볼륨·전체화면 여부)은 에디터용 예시값으로 대신한다
const GAME_STATE := preload("res://GameState.gd")

@export var open_time: float = 0.35
@export var close_time: float = 0.25

## **에디터에서만 쓰는 미리보기 탭.** 게임에는 아무 영향이 없다 —
## 에디터는 늘 그래픽 탭만 그려서 오디오·조작 칸 자리를 눈으로 잡을 수가 없었다
@export_enum("그래픽", "오디오", "조작") var editor_preview_tab: int = 0:
	set(value):
		editor_preview_tab = value
		if Engine.is_editor_hint() and is_node_ready():
			_show_tab(_editor_tab_name())

@export_group("모양")
## 탭·닫기 칸의 평소 색과 골랐을 때(빨강) 색 — 도감 탭과 같은 값이다
@export var tab_color: Color = Color(0.09, 0.07, 0.13, 0.82)
@export var tab_color_on: Color = Color(0.72, 0.18, 0.28, 0.95)
@export var text_color: Color = Color(0.86, 0.82, 0.92, 1.0)
@export var text_color_on: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var outline_color: Color = Color(0.62, 0.58, 0.72, 0.85)
## 해상도 칸·전체화면 토글·볼륨 막대의 테두리 색 (커서가 안 올라가 있을 때)
@export var field_outline_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var panel_color: Color = Color(0.13, 0.11, 0.17, 0.85)
## 커서를 올렸을 때 커지는 배수와 걸리는 시간(초).
## **닫기만 배수가 작다** — 폭이 680이라 도감 칸과 같은 1.14를 주면 한 번에 95px이 불어나서 너무 요란하다.
## 1.05면 늘어나는 픽셀 수가 도감 칸과 비슷해진다
@export var close_hover_scale: float = 1.05
@export var close_hover_time: float = 0.12
@export var back_hover_scale: float = 1.18
## 탭(그래픽·오디오·조작)이 커지는 배수와 따라붙는 속도. 도감 칸처럼 lerp로 스르륵 커진다
@export var tab_hover_scale: float = 1.05
@export var tab_hover_speed: float = 14.0

@export_group("방향키 조작")
## 꾹 눌렀을 때 — 처음 한 번 옮기고 이만큼 쉬었다가, 그 뒤로 이 간격으로 촤라락 넘어간다.
## 도감(CharacterDex)에 쓴 값과 같다
@export var key_repeat_delay: float = 0.35
@export var key_repeat_interval: float = 0.08
## 방향키 커서가 탭 위에 있을 때 그 탭 테두리에 칠할 색·굵기
@export var tab_cursor_color: Color = Color(1.0, 0.86, 0.9, 1.0)
@export var tab_cursor_width: float = 4.0
## 사선 칸(전체화면 토글·볼륨 막대)에 커서가 올라갔을 때 테두리 색·굵기.
## **네모 칸에 씌우는 FocusRing과 같은 분홍색이다** — 커서 색이 자리마다 다르면 지금 어디인지 헷갈린다
@export var slant_cursor_color: Color = Color(0.95, 0.38, 0.48, 1.0)
@export var slant_cursor_width: float = 5.0
## 커서 테두리(FocusRing)가 칸보다 이만큼 바깥으로 나간다
@export var focus_ring_pad: float = 5.0

@export_group("코드가 채우는 칸")
## 조작 탭 키 줄 한 칸의 높이와, 이름칸/키칸 너비 (P1Column·P2Column 안에서 쓰인다)
@export var key_row_height: float = 30.0
@export var key_name_width: float = 110.0
@export var key_button_width: float = 150.0
## 해상도 펼침 목록 한 줄의 높이 (ResolutionList 안에서 쓰인다)
@export var resolution_row_height: float = 44.0

const ACTION_LABELS := {
	"left": "왼쪽", "right": "오른쪽", "jump": "점프", "down": "아래",
	"basic_attack": "기본공격", "skill_1": "스킬1", "skill_2": "스킬2", "ultimate": "궁극기",
}
const ROWS := ["left", "right", "jump", "down", "basic_attack", "skill_1", "skill_2", "ultimate"]
## 사선 칸(토글·볼륨 막대)의 평소 테두리 굵기 — 커서가 떠나면 이 값으로 되돌린다
const SLANT_OUTLINE_WIDTH := 3.0

@onready var _card: Control = $Card
@onready var _scrim: ColorRect = $Scrim
@onready var _tabs: Dictionary = {
	"graphics": $Card/GraphicsTab,
	"audio": $Card/AudioTab,
	"controls": $Card/ControlsTab,
}
@onready var _panels: Dictionary = {
	"graphics": $Card/GraphicsPanel,
	"audio": $Card/AudioPanel,
	"controls": $Card/ControlsPanel,
}
@onready var _close_button: FanTile = $Card/CloseButton
@onready var _fullscreen_toggle: SlantToggle = $Card/GraphicsPanel/FullscreenToggle
@onready var _resolution_box: Button = $Card/GraphicsPanel/ResolutionBox
@onready var _resolution_arrow: Button = $Card/GraphicsPanel/ResolutionArrow
@onready var _resolution_list: Control = $Card/GraphicsPanel/ResolutionList
@onready var _sliders: Dictionary = {
	"master": $Card/AudioPanel/MasterSlider,
	"music": $Card/AudioPanel/MusicSlider,
	"sfx": $Card/AudioPanel/SfxSlider,
}
@onready var _percents: Dictionary = {
	"master": $Card/AudioPanel/MasterPercent,
	"music": $Card/AudioPanel/MusicPercent,
	"sfx": $Card/AudioPanel/SfxPercent,
}

@onready var _focus_ring: Panel = $Card/FocusRing
@onready var _reset_button: Button = $Card/ControlsPanel/ResetButton

var _mode: String = "graphics"
var _key_buttons: Dictionary = {}
## 지금 새 키 입력을 기다리는 액션. 빈 문자열이면 대기 중이 아님
var _listening_action: String = ""

## 방향키 커서 — "tabs"(탭 줄) / "items"(탭 내용) / "close"(닫기)
var _focus_area: String = "tabs"
var _row: int = 0
var _col: int = 0
## 해상도 목록이 펼쳐져 있을 때 목록 안에서의 커서
var _res_row: int = 0
## 꾹 누르기 반복용 — 지금 누르고 있는 방향과 다음 반복까지 남은 시간
var _held_step: int = 0
var _repeat_left: float = 0.0

## 지금 맨 앞으로 올려 둔 탭 (커진 탭이 옆 탭에 가리지 않게)
var _front_tab: FanTile = null

var _scrim_target_alpha: float = 0.55
## 연출 진행 시간(초). 음수면 연출 중이 아니다
var _anim_time: float = -1.0
var _opening: bool = true

func _ready() -> void:
	_style_tabs()
	_style_resolution_buttons()
	_fill_key_rows()
	_fill_resolution_list()
	_setup_values()
	_setup_nav()
	_connect_signals()
	_scrim_target_alpha = _scrim.color.a
	if Engine.is_editor_hint():
		# 에디터에서는 미끄러지는 연출 없이 제자리에 그려야 자리를 눈으로 잡을 수 있다
		_show_tab(_editor_tab_name())
		_apply_slide(1.0)
		return
	_show_tab("graphics")
	_opening = true
	_anim_time = 0.0
	_apply_slide(0.0)

func _editor_tab_name() -> String:
	match editor_preview_tab:
		1: return "audio"
		2: return "controls"
		_: return "graphics"

# ---------------------------------------------------------------- 모양 입히기

## 씬에 놓인 사선 칸(탭 3개 + 닫기)에 색과 테두리를 입힌다. **자리는 안 건드린다**
func _style_tabs() -> void:
	for tile in [_tabs["graphics"], _tabs["audio"], _tabs["controls"], _close_button]:
		# **글자는 칸 안의 Text Label이 그린다** — 씬에서 그 Label만 따로 끌어 옮길 수 있게 하려고
		# FanTile 자체의 글자는 비워둔다(안 비우면 두 글자가 겹쳐 찍힌다)
		tile.display_text = ""
		tile.fill_color = tab_color
		tile.backdrop_color = tab_color
		tile.name_band_ratio = 0.0
		tile.name_text = ""
		tile.plain_outline = true
		tile.plain_outline_color = outline_color
		tile.plain_outline_width = 2.0

## 해상도 칸은 러프대로 **네모**다 — 평행사변형으로는 펼침 목록이 안 예뻐서 그냥 네모로 갔다
func _style_box_button(button: Button) -> void:
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color_on)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = tab_color_on if state == "hover" else panel_color
		style.border_color = field_outline_color
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		button.add_theme_stylebox_override(state, style)

func _style_resolution_buttons() -> void:
	_style_box_button(_resolution_box)
	_style_box_button(_resolution_arrow)

# ---------------------------------------------------------------- 코드가 채우는 칸

## 조작 탭 키 줄을 P1Column / P2Column 안에 채운다.
## **두 칸을 에디터에서 끌면 줄이 통째로 따라온다** — 줄 자리가 칸 기준 상대 좌표라서
func _fill_key_rows() -> void:
	_key_buttons.clear()
	var columns := {"p1_": $Card/ControlsPanel/P1Column, "p2_": $Card/ControlsPanel/P2Column}
	for prefix in columns:
		var column: Control = columns[prefix]
		for child in column.get_children():
			column.remove_child(child)
			child.queue_free()
		for i in range(ROWS.size()):
			var suffix: String = str(ROWS[i])
			var y: float = key_row_height * float(i)
			var label := Label.new()
			label.text = str(ACTION_LABELS[suffix])
			label.position = Vector2(0.0, y)
			label.size = Vector2(key_name_width, key_row_height)
			label.add_theme_font_size_override("font_size", 20)
			label.add_theme_color_override("font_color", text_color)
			column.add_child(label)

			var button := Button.new()
			button.position = Vector2(key_name_width + 6.0, y)
			button.size = Vector2(key_button_width, key_row_height)
			button.text = _key_display_text(str(prefix) + suffix)
			button.add_theme_font_size_override("font_size", 18)
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			if not Engine.is_editor_hint():
				button.pressed.connect(_on_rebind_pressed.bind(str(prefix) + suffix, button))
			column.add_child(button)
			_key_buttons[str(prefix) + suffix] = button

## 해상도 펼침 목록을 ResolutionList 안에 채운다. 그 칸을 끌면 목록이 따라온다
func _fill_resolution_list() -> void:
	for child in _resolution_list.get_children():
		_resolution_list.remove_child(child)
		child.queue_free()
	for i in range(GAME_STATE.RESOLUTIONS.size()):
		var item: Vector2i = GAME_STATE.RESOLUTIONS[i]
		var row := Button.new()
		row.text = "%d x %d" % [item.x, item.y]
		row.position = Vector2(0.0, resolution_row_height * float(i))
		row.size = Vector2(_resolution_list.size.x, resolution_row_height)
		row.add_theme_font_size_override("font_size", 22)
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_box_button(row)
		if not Engine.is_editor_hint():
			row.pressed.connect(_on_resolution_chosen.bind(i))
			row.mouse_entered.connect(_on_resolution_row_hovered.bind(i))
		row.focus_mode = Control.FOCUS_NONE
		_resolution_list.add_child(row)
	_resolution_list.visible = false

# ---------------------------------------------------------------- 값 채우기·연결

func _setup_values() -> void:
	_fullscreen_toggle.set_on_instant(_now_fullscreen())
	_refresh_resolution_box()
	for key in _sliders:
		var slider: SlantSlider = _sliders[key]
		slider.value = _now_volume(str(key))
		_update_percent(str(key), slider.value)
	# 빌드에서는 소리를 통째로 꺼 뒀다(GameState.MUTE_IN_BUILD) — 헛돌게 두면 고장난 줄 아니까 못 만지게 한다
	var muted: bool = _now_muted()
	for key in _sliders:
		(_sliders[key] as SlantSlider).editable = not muted
	$Card/AudioPanel/MutedLabel.visible = muted

func _connect_signals() -> void:
	if Engine.is_editor_hint():
		return
	$Card/BackButton.pressed.connect(_on_back_pressed)
	$Card/BackButton.mouse_entered.connect(_on_back_hover.bind(true))
	$Card/BackButton.mouse_exited.connect(_on_back_hover.bind(false))
	_close_button.pressed.connect(_on_back_pressed)
	_close_button.mouse_entered.connect(_on_hover_changed.bind(true))
	_close_button.mouse_exited.connect(_on_hover_changed.bind(false))
	for key in _tabs:
		(_tabs[key] as FanTile).pressed.connect(_on_tab_pressed.bind(str(key)))
	_fullscreen_toggle.state_changed.connect(_on_fullscreen_toggled)
	_resolution_box.pressed.connect(_toggle_resolution_list)
	_resolution_arrow.pressed.connect(_toggle_resolution_list)
	(_sliders["master"] as SlantSlider).value_changed.connect(_on_volume_changed.bind("master"))
	(_sliders["music"] as SlantSlider).value_changed.connect(_on_volume_changed.bind("music"))
	(_sliders["sfx"] as SlantSlider).value_changed.connect(_on_volume_changed.bind("sfx"))
	$Card/ControlsPanel/ResetButton.pressed.connect(_on_reset_pressed)

# ---------------------------------------------------------------- 에디터 대비
## 에디터에는 오토로드(GameState)가 없어서 부르면 placeholder 오류가 난다.
## 그래서 "지금 값"을 읽는 곳은 전부 이 함수들을 거친다 — 에디터에서는 보기 좋은 예시값을 돌려준다

func _now_fullscreen() -> bool:
	return false if Engine.is_editor_hint() else GameState.is_fullscreen

func _now_resolution_index() -> int:
	return 0 if Engine.is_editor_hint() else GameState.resolution_index

func _now_muted() -> bool:
	return false if Engine.is_editor_hint() else GameState.is_audio_muted()

## 에디터 예시값은 러프처럼 세 막대가 다 다르게 보이도록 잡았다
func _now_volume(kind: String) -> float:
	if Engine.is_editor_hint():
		match kind:
			"master": return 0.85
			"music": return 0.0
			_: return 0.35
	match kind:
		"master": return GameState.master_volume
		"music": return GameState.music_volume
		_: return GameState.sfx_volume

# ---------------------------------------------------------------- 그래픽

func _on_fullscreen_toggled(enabled: bool) -> void:
	GameState.set_fullscreen(enabled)
	_refresh_resolution_box()

## 해상도 칸 글자를 지금 값으로 맞춘다. 전체화면일 땐 바꿔도 의미가 없어서 눌리지 않게 흐려둔다
func _refresh_resolution_box() -> void:
	var current: Vector2i = GAME_STATE.RESOLUTIONS[_now_resolution_index()]
	_resolution_box.text = "%d x %d" % [current.x, current.y]
	var off: bool = _now_fullscreen()
	_resolution_box.disabled = off
	_resolution_arrow.disabled = off
	_resolution_box.modulate.a = 0.45 if off else 1.0
	_resolution_arrow.modulate.a = 0.45 if off else 1.0
	if off:
		_resolution_list.visible = false
		_resolution_arrow.text = "∨"

func _toggle_resolution_list() -> void:
	if _now_fullscreen():
		return
	_resolution_list.visible = not _resolution_list.visible
	_resolution_arrow.text = "∧" if _resolution_list.visible else "∨"
	if _resolution_list.visible:
		# 펼치는 순간 커서를 지금 쓰는 해상도에 올려 둔다
		_res_row = _now_resolution_index()
	_refresh_cursor()

func _on_resolution_chosen(index: int) -> void:
	GameState.set_resolution(index)
	_resolution_list.visible = false
	_resolution_arrow.text = "∨"
	_refresh_resolution_box()
	_refresh_cursor()

func _on_resolution_row_hovered(index: int) -> void:
	_res_row = index
	_refresh_cursor()

# ---------------------------------------------------------------- 오디오

func _on_volume_changed(value: float, kind: String) -> void:
	match kind:
		"master": GameState.set_master_volume(value)
		"music": GameState.set_music_volume(value)
		_: GameState.set_sfx_volume(value)
	_update_percent(kind, value)

func _update_percent(kind: String, value: float) -> void:
	if _percents.has(kind):
		(_percents[kind] as Label).text = "%d%%" % round(value * 100.0)

# ---------------------------------------------------------------- 조작

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
	if _mode != tab_name:
		# 다른 탭으로 넘어가면 안쪽 커서는 첫 줄로 되돌린다 — 줄 수가 탭마다 달라서
		_row = 0
		_col = 0
	_mode = tab_name
	if tab_name != "graphics" and _resolution_list.visible:
		# 펼쳐 둔 채 탭을 넘기면 커서 테두리만 그 자리에 남아 떠 있는다 — 같이 접는다
		_resolution_list.visible = false
		_resolution_arrow.text = "∨"
	for key in _panels:
		(_panels[key] as Control).visible = (key == tab_name)
	for key in _tabs:
		var tile: FanTile = _tabs[key]
		var on: bool = key == tab_name
		tile.fill_color = tab_color_on if on else tab_color
		tile.backdrop_color = tile.fill_color
		tile.selected = on
		var text: Label = tile.get_node_or_null("Text")
		if text:
			text.add_theme_color_override("font_color", text_color_on if on else text_color)
	_refresh_cursor()

## 마우스로 탭을 눌렀을 때 — 방향키 커서도 탭 줄로 따라 올라온다.
## 안 그러면 화면 아래쪽에 커서 테두리가 남아 있어서 지금 어디를 고르고 있는지 헷갈린다
func _on_tab_pressed(tab_name: String) -> void:
	_focus_area = "tabs"
	_show_tab(tab_name)

## 커서를 올리면 **살짝 커지면서 빨개진다** (닫기 단추).
## 씬에서 pivot_offset을 칸 가운데로 잡아 뒀다 — 안 그러면 왼쪽 위를 축으로 커져서 자리가 밀린다
func _on_hover_changed(hovering: bool) -> void:
	if hovering and not _sliding():
		_focus_area = "close"
		_refresh_cursor()
	_close_button.fill_color = tab_color_on if hovering else tab_color
	_close_button.backdrop_color = _close_button.fill_color
	var target: float = close_hover_scale if hovering else 1.0
	var tween := create_tween()
	tween.tween_property(_close_button, "scale", Vector2(target, target), close_hover_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## 탭도 커서가 올라가면 살짝 부풀린다 (도감 칸과 같은 방식 — 트윈 말고 매 프레임 lerp).
## 마우스를 올렸을 때, 그리고 **방향키 커서가 탭 줄에 있을 때** 그 탭이 커진다.
## 커진 탭이 옆 탭 밑으로 깔리면 어색해서 맨 앞으로 올려 준다
func _update_tab_hover(delta: float) -> void:
	var t: float = clampf(tab_hover_speed * delta, 0.0, 1.0)
	var front: FanTile = null
	for key in _tabs:
		var tile: FanTile = _tabs[key]
		# 크기가 뒤늦게 잡히는 경우가 있어 매번 중심을 다시 잡아준다
		tile.pivot_offset = tile.size * 0.5
		var on: bool = tile.is_hovered() or (_focus_area == "tabs" and str(key) == _mode)
		if on:
			front = tile
		tile.scale = tile.scale.lerp(Vector2.ONE * (tab_hover_scale if on else 1.0), t)
	# **커진 탭을 맨 앞으로 올린다.** 탭은 씬에 놓인 순서(그래픽→오디오→조작)대로 겹쳐 그려져서,
	# 그냥 두면 그래픽·오디오가 커져도 오른쪽 탭 밑에 깔려 밝은 테두리 한 변이 통째로 가려진다.
	# 조작(마지막 탭)만 멀쩡해 보였던 게 그 때문이다
	if front != null and front != _front_tab:
		_front_tab = front
		front.move_to_front()

## 왼쪽 위 ◀ — 커서가 올라가고 내려갈 때 살짝 부풀렸다 되돌린다 (도감과 같은 연출).
## 크기가 뒤늦게 잡히는 경우가 있어 들어올 때마다 중심을 다시 잡아준다
func _on_back_hover(entered: bool) -> void:
	var back: Button = $Card/BackButton
	back.pivot_offset = back.size * 0.5
	var goal: Vector2 = Vector2.ONE * (back_hover_scale if entered else 1.0)
	var tw: Tween = create_tween()
	tw.tween_property(back, "scale", goal, close_hover_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## u=0이면 화면 위로 완전히 벗어난 상태, u=1이면 제자리
func _apply_slide(u: float) -> void:
	var shift: float = lerpf(-get_viewport_rect().size.y, 0.0, u)
	_card.offset_top = shift
	_card.offset_bottom = shift
	_scrim.color.a = _scrim_target_alpha * u

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_key_repeat(delta)
	_update_tab_hover(delta)
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
	if Engine.is_editor_hint() or _listening_action == "" or not event.pressed or event.is_echo():
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
	if Engine.is_editor_hint() or _listening_action != "":
		return
	if event.is_action_pressed("ui_cancel"):
		# **먹었다는 표시를 닫기 전에 해야 한다** — 뒤쪽 메인 메뉴의 ESC가 같이 먹는 걸 막는다
		get_viewport().set_input_as_handled()
		if _resolution_list.visible:
			# 목록이 펼쳐져 있으면 목록만 접는다 — 설정창까지 같이 닫히면 답답하다
			_toggle_resolution_list()
			return
		_on_back_pressed()
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_activate()

# ---------------------------------------------------------------- 방향키 조작
## 도감(CharacterDex)에 쓴 것과 같은 방식이다 — **고도 기본 포커스 이동을 안 쓰고 커서를 직접 옮긴다.**
## 기본 포커스를 쓰면 사선 칸·볼륨 막대처럼 직접 그린 것들이 방향키를 서로 뺏어가서 어디로 갈지 예측이 안 된다.
## 그래서 모든 칸의 focus_mode를 꺼 두고 여기 한 곳에서만 처리한다.
##
## 커서 자리는 세 군데다 — 탭 줄("tabs") / 탭 내용("items") / 닫기("close").
## 내용은 줄(row)과 칸(col)로 센다. 조작 탭만 한 줄에 1P·2P 두 칸이고 나머지는 한 칸씩이다

## 방향키로 오갈 칸들을 정리한다. 한 줄이 곧 위아래 한 칸, 줄 안의 원소가 좌우 한 칸이다
func _rows_of(tab_name: String) -> Array:
	match tab_name:
		"graphics":
			return [[_fullscreen_toggle], [_resolution_box]]
		"audio":
			return [[_sliders["master"]], [_sliders["music"]], [_sliders["sfx"]]]
		_:
			var rows: Array = []
			for action in ROWS:
				var p1: Button = _key_buttons.get("p1_" + str(action))
				var p2: Button = _key_buttons.get("p2_" + str(action))
				if p1 != null and p2 != null:
					rows.append([p1, p2])
			rows.append([_reset_button])
			return rows

## 모든 칸의 기본 포커스를 끄고, 마우스를 올리면 방향키 커서도 따라오게 묶는다.
## **키 줄을 다 채운 뒤에 불러야 한다** — 조작 탭 칸은 코드가 만들기 때문
func _setup_nav() -> void:
	for tab_name in ["graphics", "audio", "controls"]:
		var rows: Array = _rows_of(str(tab_name))
		for r in range(rows.size()):
			var row: Array = rows[r]
			for c in range(row.size()):
				var item: Control = row[c]
				if item == null:
					continue
				item.focus_mode = Control.FOCUS_NONE
				if not Engine.is_editor_hint():
					item.mouse_entered.connect(_on_item_hovered.bind(str(tab_name), r, c))
	_resolution_arrow.focus_mode = Control.FOCUS_NONE
	for tile in [_tabs["graphics"], _tabs["audio"], _tabs["controls"], _close_button]:
		(tile as Control).focus_mode = Control.FOCUS_NONE
	_focus_ring.visible = false

func _on_item_hovered(tab_name: String, r: int, c: int) -> void:
	if _mode != tab_name or _sliding():
		return
	_focus_area = "items"
	_row = r
	_col = c
	_refresh_cursor()

## 창이 위에서 내려오는(또는 올라가는) 연출 중인지.
## **연출 중에는 마우스가 올라왔다는 신호를 무시한다** — 카드가 움직이는 동안 칸들이
## 가만히 있는 마우스 밑을 차례로 스쳐 지나가면서 mouse_entered가 떠 버린다.
## 그래서 설정을 열자마자 커서 테두리가 엉뚱하게 닫기에 가 있었다
func _sliding() -> bool:
	return _anim_time >= 0.0

## 지금 커서가 올라가 있는 칸
func _current_item() -> Control:
	var rows: Array = _rows_of(_mode)
	if rows.is_empty():
		return null
	var row: Array = rows[clampi(_row, 0, rows.size() - 1)]
	if row.is_empty():
		return null
	return row[clampi(_col, 0, row.size() - 1)] as Control

## 방향키를 꾹 누르고 있으면 촤라락 넘어간다 — 처음 한 번, 한 박자 쉬고, 그 뒤로 빠르게 반복
func _update_key_repeat(delta: float) -> void:
	# 키 재배정을 기다리는 중이면 방향키도 "새 키"로 받아야 한다 — 커서를 움직이면 안 된다.
	# 닫히는 연출 중에도 멈춘다
	if _listening_action != "" or (_anim_time >= 0.0 and not _opening):
		_held_step = 0
		return
	var step: int = 0
	if Input.is_action_pressed("ui_right"):
		step = 1
	elif Input.is_action_pressed("ui_left"):
		step = -1
	elif Input.is_action_pressed("ui_down"):
		step = 100
	elif Input.is_action_pressed("ui_up"):
		step = -100
	if step == 0:
		_held_step = 0
		return
	if step != _held_step:
		# 방금 누른 순간 — 한 번 옮기고 첫 반복까지 쉰다
		_held_step = step
		_repeat_left = key_repeat_delay
		_move_cursor(step)
		return
	_repeat_left -= delta
	if _repeat_left <= 0.0:
		_repeat_left = key_repeat_interval
		_move_cursor(step)

## 방향키 하나를 처리한다. 100 / -100이 아래·위다 (칸 수와 안 겹치는 값)
func _move_cursor(step: int) -> void:
	# 해상도 목록이 펼쳐져 있으면 방향키는 목록 안에서만 돈다. **꾹 누르면 여기가 촤라락 넘어간다**
	if _resolution_list.visible:
		if absi(step) == 100:
			var count: int = _resolution_list.get_child_count()
			if count > 0:
				_res_row = wrapi(_res_row + (1 if step > 0 else -1), 0, count)
				_refresh_cursor()
		return
	if _focus_area == "tabs":
		if step == 100:
			_focus_area = "items"
			_row = 0
			_col = 0
			_refresh_cursor()
		elif absi(step) == 1:
			var order: Array = ["graphics", "audio", "controls"]
			var at: int = maxi(order.find(_mode), 0)
			_show_tab(str(order[wrapi(at + step, 0, order.size())]))
		return
	if _focus_area == "close":
		if step == -100:
			_focus_area = "items"
			var last: Array = _rows_of(_mode)
			_row = maxi(last.size() - 1, 0)
			_col = 0
			_refresh_cursor()
		return
	var rows: Array = _rows_of(_mode)
	if rows.is_empty():
		return
	_row = clampi(_row, 0, rows.size() - 1)
	if step == -100:
		if _row == 0:
			_focus_area = "tabs"   # 첫 줄에서 위 -> 탭 줄로 올라간다
		else:
			_row -= 1
	elif step == 100:
		if _row >= rows.size() - 1:
			_focus_area = "close"   # 마지막 줄에서 아래 -> 닫기로 내려간다
		else:
			_row += 1
	else:
		var row: Array = rows[_row]
		if row.size() > 1:
			_col = clampi(_col + step, 0, row.size() - 1)
		else:
			_adjust_value(row[0] as Control, step)
	var now: Array = rows[clampi(_row, 0, rows.size() - 1)]
	_col = clampi(_col, 0, maxi(now.size() - 1, 0))
	_refresh_cursor()

## 줄에 칸이 하나뿐이면 좌우 방향키는 "값 바꾸기"로 쓴다 — 토글은 켜고/끄고, 볼륨은 한 칸씩
func _adjust_value(item: Control, step: int) -> void:
	if item is SlantToggle:
		var toggle: SlantToggle = item
		var want: bool = step > 0
		if toggle.is_on != want:
			toggle.is_on = want
			toggle.state_changed.emit(want)
		return
	if item is SlantSlider:
		var slider: SlantSlider = item
		if not slider.editable:
			return
		var value: float = clampf(slider.value + maxf(slider.step, 0.05) * float(step), 0.0, 1.0)
		if is_equal_approx(value, slider.value):
			return
		slider.value = value
		slider.value_changed.emit(value)

## 확인키(엔터·스페이스)
func _activate() -> void:
	if _resolution_list.visible:
		_on_resolution_chosen(_res_row)
		return
	if _focus_area == "tabs":
		_focus_area = "items"
		_row = 0
		_col = 0
		_refresh_cursor()
		return
	if _focus_area == "close":
		_on_back_pressed()
		return
	var item: Control = _current_item()
	if item == null:
		return
	if item == _resolution_box:
		_toggle_resolution_list()
		return
	if item is Button:
		# 토글·키 칸·초기화는 전부 Button이라 눌린 척만 해 주면 원래 동작이 그대로 돈다
		(item as Button).pressed.emit()

## 커서를 화면에 그린다 —
##  - 탭 줄에 있으면 그 탭 테두리를 밝게 한다 (사선 칸이라 네모 테두리를 두르면 모서리가 어긋난다)
##  - 그 밖에는 FocusRing을 그 칸 위로 옮긴다
func _refresh_cursor() -> void:
	if _focus_ring == null:
		return
	var on_tabs: bool = _focus_area == "tabs"
	for key in _tabs:
		var tile: FanTile = _tabs[key]
		var here: bool = on_tabs and str(key) == _mode
		tile.plain_outline_color = tab_cursor_color if here else outline_color
		tile.plain_outline_width = tab_cursor_width if here else 2.0
	var target: Control = null
	if _resolution_list.visible and _mode == "graphics":
		var count: int = _resolution_list.get_child_count()
		if count > 0:
			_res_row = clampi(_res_row, 0, count - 1)
			target = _resolution_list.get_child(_res_row) as Control
	elif _focus_area == "close":
		target = _close_button
	elif _focus_area == "items":
		target = _current_item()
	# 닫기도 사선 칸이라 네모 커서를 씌우면 모서리가 어긋난다 — 탭처럼 **제 테두리를 밝게** 한다
	var close_lit: bool = target == _close_button
	_close_button.plain_outline_color = tab_cursor_color if close_lit else outline_color
	_close_button.plain_outline_width = tab_cursor_width if close_lit else 2.0
	# 전체화면 토글·볼륨 막대도 같은 이유로 제 테두리를 밝힌다
	for slant in [_fullscreen_toggle, _sliders["master"], _sliders["music"], _sliders["sfx"]]:
		var lit: bool = slant == target
		slant.outline_color = slant_cursor_color if lit else field_outline_color
		slant.outline_width = slant_cursor_width if lit else SLANT_OUTLINE_WIDTH
		(slant as Control).queue_redraw()
	if close_lit or target is SlantToggle or target is SlantSlider:
		_focus_ring.visible = false
		return
	if target == null or not is_instance_valid(target):
		_focus_ring.visible = false
		return
	_focus_ring.visible = true
	# 칸이 패널·세로줄 안에 들어 있을 수도 있어서 화면 좌표로 재고 Card 기준으로 되돌린다
	var rect: Rect2 = target.get_global_rect()
	_focus_ring.position = _card.get_global_transform().affine_inverse() * rect.position - Vector2(focus_ring_pad, focus_ring_pad)
	_focus_ring.size = rect.size + Vector2(focus_ring_pad, focus_ring_pad) * 2.0
