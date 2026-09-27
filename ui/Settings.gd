@tool
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
## 에디터에는 오토로드(GameState) 인스턴스가 없다 — const(RESOLUTIONS)만 이걸로 읽고,
## 나머지 값(지금 볼륨·전체화면 여부)은 에디터용 예시값으로 대신한다
const GAME_STATE := preload("res://GameState.gd")

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

## **에디터에서만 쓰는 미리보기 탭.** 게임에는 아무 영향이 없다 —
## 에디터는 늘 그래픽 탭만 그려서 오디오·조작 칸 자리를 눈으로 잡을 수가 없었다
@export_enum("그래픽", "오디오", "조작") var editor_preview_tab: int = 0

@export_group("칸 자리")
## **여기 값만 바꾸면 화면 배치가 전부 따라 움직인다.**
## 씬(ui/Settings.tscn)에서 루트 Settings 노드를 고르면 인스펙터에 그대로 뜬다.
##
## 첫 번째 탭의 자리와 크기. 두 번째·세 번째 탭은 여기서 자동으로 계산된다
@export var tab_rect: Rect2 = Rect2(296.0, 150.0, 260.0, 64.0)
## 탭 기울기(px). **탭끼리 이만큼 겹쳐 놓아야 대각선 변이 맞물린다** — 값을 키우면 더 많이 눕고 더 겹친다
@export var tab_lean: float = 46.0
## 항목 이름("전체화면" 등)이 놓이는 첫 줄 자리. 글자는 오른쪽 정렬이라 오른쪽 끝이 기준이다
@export var label_rect: Rect2 = Rect2(300.0, 288.0, 250.0, 56.0)
## 값 칸(스위치·막대)이 시작하는 x
@export var control_x: float = 580.0
## 줄 사이 세로 간격(px)
@export var row_step: float = 80.0
## 맨 아래 닫기 단추 자리
@export var close_rect: Rect2 = Rect2(300.0, 620.0, 680.0, 62.0)

@export_group("닫기 단추 커서 반응")
## 커서를 올렸을 때 커지는 배수와 걸리는 시간(초)
@export var close_hover_scale: float = 1.06
@export var close_hover_time: float = 0.12

@export_group("조작 탭")
## 1P 칸이 시작하는 자리(안내문 아래 첫 줄)와 2P 칸까지의 가로 간격
@export var controls_origin: Vector2 = Vector2(330.0, 318.0)
@export var controls_column_gap: float = 340.0
## 키 한 줄의 세로 간격(px)과 이름칸/키칸 너비
@export var controls_row_step: float = 30.0
@export var controls_name_width: float = 110.0
@export var controls_key_width: float = 150.0
## "조작키 초기화" 단추 자리
@export var controls_reset_rect: Rect2 = Rect2(540.0, 556.0, 200.0, 36.0)

@export_group("볼륨 막대")
## 사선 볼륨 막대의 너비·높이·기울기 (오디오 탭 세 줄이 전부 이 값을 쓴다)
@export var volume_bar_width: float = 420.0
@export var volume_bar_height: float = 46.0
@export var volume_bar_lean: float = 46.0

@export_group("해상도 칸")
## **해상도만 네모 칸이다**(2026-09-27 러프) — 평행사변형으로는 목록이 안 예뻐서 그냥 네모로 갔다.
## 아래 네 값이 해상도 줄의 전부다. 씬(ui/Settings.tscn)에서 루트 Settings 노드를 고르면
## 인스펙터 "해상도 칸" 항목에 그대로 뜨니 숫자만 바꾸면 자리가 옮겨진다
@export var resolution_label_rect: Rect2 = Rect2(300.0, 368.0, 250.0, 56.0)
## 닫혀 있을 때의 칸 전체(글자 칸 + 오른쪽 ∨ 단추를 합친 크기)
@export var resolution_rect: Rect2 = Rect2(580.0, 368.0, 400.0, 56.0)
## 오른쪽 ∨ 단추의 너비(px)
@export var resolution_arrow_width: float = 56.0
## 펼쳤을 때 아래로 깔리는 목록 한 줄의 높이(px)
@export var resolution_row_height: float = 44.0

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
var _resolution_main: Button = null
var _resolution_arrow: Button = null
var _resolution_list: Control = null
var _volume_sliders: Dictionary = {}   # {"master"/"music"/"sfx": SlantSlider}
var _volume_labels: Dictionary = {}    # {줄 번호: 퍼센트 Label}
var _key_buttons: Dictionary = {}
## 지금 새 키 입력을 기다리는 액션. 빈 문자열이면 대기 중이 아님
var _listening_action: String = ""

var _scrim_target_alpha: float = 0.55
## 연출 진행 시간(초). 음수면 연출 중이 아니다
var _anim_time: float = -1.0
## 에디터에서 마지막으로 그린 인스펙터 값들의 도장
var _editor_stamp: String = ""
var _opening: bool = true

func _ready() -> void:
	_build()
	_show_tab(_mode)
	_scrim_target_alpha = _scrim.color.a
	if Engine.is_editor_hint():
		# 에디터에서는 미끄러지는 연출 없이 제자리에 그려야 자리를 눈으로 잡을 수 있다
		_show_tab(_editor_tab_name())
		_apply_slide(1.0)
		_editor_stamp = _stamp()
		set_process(true)
		return
	_opening = true
	_anim_time = 0.0
	_apply_slide(0.0)

## 에디터에서 인스펙터 값이 바뀌었는지 보는 도장.
## **내보낸 값을 코드로 전부 훑어서 만든다** — 손으로 적는 방식이면 새 값을 추가할 때
## 여기 빠뜨려서 "인스펙터에서 바꿔도 안 먹는" 일이 생긴다(도감에서 실제로 겪었다)
func _stamp() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for prop in get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.usage & PROPERTY_USAGE_EDITOR:
			parts.append("%s=%s" % [prop.name, str(get(prop.name))])
	return "|".join(parts)

## 에디터 미리보기 탭 번호를 이름으로 바꾼다
func _editor_tab_name() -> String:
	match editor_preview_tab:
		1: return "audio"
		2: return "controls"
		_: return "graphics"

## 칸을 전부 지우고 다시 만든다 (에디터에서 값이 바뀔 때만 쓴다)
func _rebuild() -> void:
	for child in _card.get_children():
		# 씬에 놓아둔 배경 세 장은 그대로 두고, 코드로 만든 칸만 지운다
		if child.name in ["Background", "BackgroundImage", "BackgroundScrim"]:
			continue
		_card.remove_child(child)
		child.queue_free()
	_tabs.clear()
	_panels.clear()
	_volume_sliders.clear()
	_volume_labels.clear()
	_key_buttons.clear()
	_build()
	_show_tab(_editor_tab_name() if Engine.is_editor_hint() else _mode)
	_apply_slide(1.0)

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
	var close := _make_slant(close_rect, 50.0, "닫기 (ESC)", 28)
	close.pressed.connect(_on_back_pressed)
	_add_hover_pop(close)
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
	var pitch: float = tab_rect.size.x - tab_lean
	var rect := Rect2(tab_rect.position + Vector2(pitch * float(index), 0.0), tab_rect.size)
	return _make_slant(rect, tab_lean, text, 30)

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

## 커서를 올리면 **살짝 커지면서 빨개진다** (닫기 단추).
## 가운데를 축으로 커지게 pivot을 가운데로 옮긴다 — 안 그러면 왼쪽 위를 축으로 커져서 자리가 밀린다
func _add_hover_pop(tile: FanTile) -> void:
	tile.pivot_offset = tile.size * 0.5
	tile.mouse_entered.connect(_on_hover_changed.bind(tile, true))
	tile.mouse_exited.connect(_on_hover_changed.bind(tile, false))

func _on_hover_changed(tile: FanTile, hovering: bool) -> void:
	if not is_instance_valid(tile):
		return
	tile.fill_color = TAB_COLOR_ON if hovering else TAB_COLOR
	tile.backdrop_color = tile.fill_color
	var target: float = close_hover_scale if hovering else 1.0
	var tween := create_tween()
	tween.tween_property(tile, "scale", Vector2(target, target), close_hover_time).set_trans(Tween.TRANS_QUAD)

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
	return Rect2(label_rect.position + Vector2(0.0, row_step * float(index)), label_rect.size)

func _row_control_rect(index: int, width: float) -> Rect2:
	return Rect2(Vector2(control_x, label_rect.position.y + row_step * float(index)),
		Vector2(width, label_rect.size.y))


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

	panel.add_child(_make_label("해상도", resolution_label_rect))
	_build_resolution_box(panel)

	_fullscreen_toggle.set_on_instant(_now_fullscreen())
	_refresh_resolution_box()
	return panel

func _on_fullscreen_toggled(enabled: bool) -> void:
	if not Engine.is_editor_hint():
		GameState.set_fullscreen(enabled)
	_refresh_resolution_box()

## 해상도 칸을 만든다 — **네모 한 줄 + 오른쪽 끝에 ∨ 단추**, 누르면 그 아래로 목록이 깔린다.
## 목록은 화면 위에 뜨는 팝업이 아니라 이 화면 안에 그대로 붙는다(러프 그대로)
func _build_resolution_box(panel: Control) -> void:
	var body_width: float = maxf(resolution_rect.size.x - resolution_arrow_width, 40.0)
	_resolution_main = _make_box_button("", Rect2(resolution_rect.position, Vector2(body_width, resolution_rect.size.y)), 26)
	_resolution_main.pressed.connect(_toggle_resolution_list)
	panel.add_child(_resolution_main)

	_resolution_arrow = _make_box_button("∨",
		Rect2(resolution_rect.position + Vector2(body_width, 0.0),
			Vector2(resolution_arrow_width, resolution_rect.size.y)), 24)
	_resolution_arrow.pressed.connect(_toggle_resolution_list)
	panel.add_child(_resolution_arrow)

	_resolution_list = Control.new()
	_resolution_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resolution_list.visible = false
	panel.add_child(_resolution_list)
	for i in range(GAME_STATE.RESOLUTIONS.size()):
		var item: Vector2i = GAME_STATE.RESOLUTIONS[i]
		var row := _make_box_button("%d x %d" % [item.x, item.y],
			Rect2(resolution_rect.position + Vector2(0.0, resolution_rect.size.y + resolution_row_height * float(i)),
				Vector2(body_width, resolution_row_height)), 22)
		row.pressed.connect(_on_resolution_chosen.bind(i))
		_resolution_list.add_child(row)
	_refresh_resolution_box()

## 네모 칸 단추 하나 (해상도 줄 전용 — 나머지 칸은 전부 평행사변형이다)
func _make_box_button(text: String, rect: Rect2, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", TEXT_COLOR_ON)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = TAB_COLOR_ON if state == "hover" else PANEL_COLOR
		style.border_color = OUTLINE_COLOR
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		button.add_theme_stylebox_override(state, style)
	return button

func _toggle_resolution_list() -> void:
	if _now_fullscreen():
		return
	_resolution_list.visible = not _resolution_list.visible
	_resolution_arrow.text = "∧" if _resolution_list.visible else "∨"

func _on_resolution_chosen(index: int) -> void:
	if not Engine.is_editor_hint():
		GameState.set_resolution(index)
	_resolution_list.visible = false
	_resolution_arrow.text = "∨"
	_refresh_resolution_box()

## 해상도 칸 글자를 지금 값으로 맞춘다. 전체화면일 땐 바꿔도 의미가 없어서 눌리지 않게 흐려둔다
func _refresh_resolution_box() -> void:
	if _resolution_main == null:
		return
	var current: Vector2i = GAME_STATE.RESOLUTIONS[_now_resolution_index()]
	_resolution_main.text = "%d x %d" % [current.x, current.y]
	var off: bool = _now_fullscreen()
	_resolution_main.disabled = off
	_resolution_arrow.disabled = off
	_resolution_main.modulate.a = 0.45 if off else 1.0
	_resolution_arrow.modulate.a = 0.45 if off else 1.0
	if off:
		_resolution_list.visible = false
		_resolution_arrow.text = "∨"

# ---------------------------------------------------------------- 오디오

func _build_audio_panel() -> Control:
	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 전체 / 음악 / 효과음 세 줄. 전체 볼륨은 Master라 나머지 둘에 같이 곱해진다
	_volume_sliders["master"] = _add_volume_row(panel, 0, "전체 볼륨", _now_volume("master"), _on_master_volume)
	_volume_sliders["music"] = _add_volume_row(panel, 1, "음악 볼륨", _now_volume("music"), _on_music_volume)
	_volume_sliders["sfx"] = _add_volume_row(panel, 2, "효과음 볼륨", _now_volume("sfx"), _on_sfx_volume)
	# 빌드에서는 소리를 통째로 꺼 뒀다(GameState.MUTE_IN_BUILD) — 헛돌게 두면 고장난 줄 아니까 못 만지게 한다
	if _now_muted():
		for key in _volume_sliders:
			(_volume_sliders[key] as SlantSlider).editable = false
		var muted := Label.new()
		muted.text = "이 빌드는 소리가 꺼져 있습니다"
		muted.position = Vector2(control_x, label_rect.position.y + row_step * 3.0)
		muted.size = Vector2(volume_bar_width, 40.0)
		muted.add_theme_font_size_override("font_size", 20)
		muted.add_theme_color_override("font_color", TEXT_COLOR)
		panel.add_child(muted)
	return panel

## 볼륨 한 줄(라벨 + 사선 막대 + 퍼센트)을 만들어 붙이고 막대를 돌려준다
func _add_volume_row(panel: Control, index: int, text: String, start_value: float, on_change: Callable) -> SlantSlider:
	panel.add_child(_make_label(text, _row_label_rect(index)))
	var rect: Rect2 = _row_control_rect(index, volume_bar_width)
	var slider := SlantSlider.new()
	slider.position = rect.position
	slider.size = Vector2(rect.size.x, volume_bar_height)
	slider.lean = volume_bar_lean
	slider.value = start_value
	slider.value_changed.connect(on_change)
	panel.add_child(slider)

	var percent := Label.new()
	percent.name = "Percent%d" % index
	percent.position = rect.position + Vector2(rect.size.x + 18.0, 0.0)
	percent.size = Vector2(110.0, volume_bar_height)
	percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	percent.add_theme_font_size_override("font_size", 24)
	percent.add_theme_color_override("font_color", TEXT_COLOR)
	percent.text = "%d%%" % round(start_value * 100.0)
	panel.add_child(percent)
	_volume_labels[index] = percent
	return slider

func _on_master_volume(value: float) -> void:
	if not Engine.is_editor_hint():
		GameState.set_master_volume(value)
	_update_percent(0, value)

func _on_music_volume(value: float) -> void:
	if not Engine.is_editor_hint():
		GameState.set_music_volume(value)
	_update_percent(1, value)

func _on_sfx_volume(value: float) -> void:
	if not Engine.is_editor_hint():
		GameState.set_sfx_volume(value)
	_update_percent(2, value)

func _update_percent(index: int, value: float) -> void:
	if _volume_labels.has(index):
		(_volume_labels[index] as Label).text = "%d%%" % round(value * 100.0)

# ---------------------------------------------------------------- 조작

func _build_controls_panel() -> Control:
	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var hint := Label.new()
	hint.text = "바꿀 키를 누른 뒤 새 키를 입력하세요 (ESC로 취소)"
	hint.position = Vector2(300.0, 244.0)
	hint.size = Vector2(680.0, 32.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", TEXT_COLOR)
	panel.add_child(hint)

	for column in range(2):
		var prefix: String = "p1_" if column == 0 else "p2_"
		var header := Label.new()
		header.text = "1P" if column == 0 else "2P"
		header.position = Vector2(controls_origin.x + controls_column_gap * float(column), controls_origin.y - 34.0)
		header.size = Vector2(280.0, 30.0)
		header.add_theme_font_size_override("font_size", 24)
		header.add_theme_color_override("font_color", TEXT_COLOR_ON)
		panel.add_child(header)
		for i in range(ROWS.size()):
			var suffix: String = str(ROWS[i])
			var y: float = controls_origin.y + controls_row_step * float(i)
			var label := Label.new()
			label.text = str(ACTION_LABELS[suffix])
			label.position = Vector2(controls_origin.x + controls_column_gap * float(column), y)
			label.size = Vector2(controls_name_width, 30.0)
			label.add_theme_font_size_override("font_size", 20)
			label.add_theme_color_override("font_color", TEXT_COLOR)
			panel.add_child(label)

			var button := Button.new()
			button.position = Vector2(controls_origin.x + controls_name_width + 6.0 + controls_column_gap * float(column), y)
			button.size = Vector2(controls_key_width, 30.0)
			button.text = _key_display_text(prefix + suffix)
			button.add_theme_font_size_override("font_size", 18)
			button.pressed.connect(_on_rebind_pressed.bind(prefix + suffix, button))
			panel.add_child(button)
			_key_buttons[prefix + suffix] = button

	var reset := Button.new()
	reset.text = "조작키 초기화"
	reset.position = controls_reset_rect.position
	reset.size = controls_reset_rect.size
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
	if Engine.is_editor_hint():
		return
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
	if Engine.is_editor_hint():
		var now: String = _stamp()
		if now != _editor_stamp:
			_editor_stamp = now
			_rebuild()
		return
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
	if Engine.is_editor_hint():
		return
	if _anim_time >= 0.0 and not _opening:
		return
	_opening = false
	_anim_time = 0.0

## 재배정 대기 중일 때만 키 입력을 가로챈다. ESC면 취소하고 기존 키로 되돌린다
func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
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
	if Engine.is_editor_hint():
		return
	if _listening_action != "":
		return
	if event.is_action_pressed("ui_cancel"):
		# **먹었다는 표시를 닫기 전에 해야 한다** — 뒤쪽 메인 메뉴의 ESC가 같이 먹는 걸 막는다
		get_viewport().set_input_as_handled()
		_on_back_pressed()
