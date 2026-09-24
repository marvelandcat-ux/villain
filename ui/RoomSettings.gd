class_name RoomSettings
extends Control

## 로컬 대전 방 만들기 — 선취 라운드 수(1~40), 라운드 시간제한, 전역 쿨타임 배율(10~200%),
## 스킬 클래시(연타 미니게임)·가드·대시 on/off를 정하고 캐릭터 선택으로 넘어간다.
##
## 2026-09-15 개편: 위쪽엔 빠른 프리셋 버튼 2개("표준"/"장기전") + "프리셋" 저장·불러오기 메뉴,
## 아래엔 카드 하나 안에 왼쪽(라운드/제한시간/쿨타임)·오른쪽(연타/가드/대시) 2열로
## 여섯 항목을 나열한다.
##
## **라운드·쿨타임은 ◀▶ 스테퍼뿐 아니라 값 칸(LineEdit)을 눌러 숫자를 직접 타이핑해도 된다**
## — Enter를 누르거나 칸 밖을 클릭하면 값이 확정되고, 잘못된 값(숫자가 아님)은 이전 값으로 되돌아간다.
##
## **"프리셋" 버튼은 지금 설정을 이름 붙여 저장하고, 저장해둔 프리셋을 불러오는 메뉴다**
## — `GameState.save_room_preset()`/`load_room_presets()`가 `user://settings.cfg`에
## 영구 저장해서 게임을 껐다 켜도 남아있는다.
##
## **화살표(◀ ▶)만 기본 폰트를 쓴다** — 주아체(Jua)에는 이 기호 글리프가 없어서
## 폰트를 지정하면 네모로 나온다. 나머지 글자는 전부 주아체다.

## 시간제한 선택지 (표시 -> 초). "무제한"은 0
const TIME_OPTIONS := [
	["무제한", 0],
	["1분", 60],
	["2분", 120],
	["3분", 180],
	["5분", 300],
]

const MIN_ROUNDS := 1
const MAX_ROUNDS := 40
const MIN_COOLDOWN_PERCENT := 10
const MAX_COOLDOWN_PERCENT := 200
const COOLDOWN_STEP := 10

## 저장해둔 내 프리셋의 PopupMenu id는 이 값부터 시작한다(0은 "현재 설정 저장"이 쓴다)
const SAVED_PRESET_ID_BASE := 1

@onready var _rounds_value: LineEdit = $Card/RoundRow/Value
@onready var _time_value: Label = $Card/TimeRow/Value
@onready var _cooldown_value: LineEdit = $Card/CooldownRow/Value
@onready var _clash_toggle: Button = $Card/ClashRow/Toggle
@onready var _guard_toggle: Button = $Card/GuardRow/Toggle
@onready var _dash_toggle: Button = $Card/DashRow/Toggle
@onready var _summary: Label = $Summary

var _rounds: int = 2
var _time_index: int = 0
var _cooldown_percent: int = 100
var _clash_enabled: bool = true
var _guard_enabled: bool = true
var _dash_enabled: bool = true

func _ready() -> void:
	$Card/RoundRow/Prev.pressed.connect(func(): _change_rounds(-1))
	$Card/RoundRow/Next.pressed.connect(func(): _change_rounds(1))
	$Card/TimeRow/Prev.pressed.connect(func(): _change_time(-1))
	$Card/TimeRow/Next.pressed.connect(func(): _change_time(1))
	$Card/CooldownRow/Prev.pressed.connect(func(): _change_cooldown(-1))
	$Card/CooldownRow/Next.pressed.connect(func(): _change_cooldown(1))
	_rounds_value.text_submitted.connect(_on_rounds_text_submitted)
	_rounds_value.focus_exited.connect(func(): _on_rounds_text_submitted(_rounds_value.text))
	_cooldown_value.text_submitted.connect(_on_cooldown_text_submitted)
	_cooldown_value.focus_exited.connect(func(): _on_cooldown_text_submitted(_cooldown_value.text))
	_clash_toggle.pressed.connect(_on_clash_toggle_pressed)
	_guard_toggle.pressed.connect(_on_guard_toggle_pressed)
	_dash_toggle.pressed.connect(_on_dash_toggle_pressed)
	$PresetA.pressed.connect(func(): _apply_preset(2, 2))
	$PresetB.pressed.connect(func(): _apply_preset(3, 0))
	$PresetMore.pressed.connect(_on_more_presets_pressed)
	$NextButton.pressed.connect(_on_next_pressed)
	$BackButton.pressed.connect(_on_back_pressed)
	# 키보드/패드로 바로 조작되도록 첫 버튼에 포커스를 준다
	$NextButton.grab_focus()
	_refresh()

## 선취 라운드 수를 step만큼 바꾼다 (1에서 더 줄이면 40으로, 40에서 더 늘리면 1로 돌아간다)
func _change_rounds(step: int) -> void:
	_rounds = wrapi(_rounds + step, MIN_ROUNDS, MAX_ROUNDS + 1)
	_refresh()

## 시간제한 선택지를 step만큼 옮긴다 (양끝에서 반대쪽으로 돌아간다)
func _change_time(step: int) -> void:
	_time_index = wrapi(_time_index + step, 0, TIME_OPTIONS.size())
	_refresh()

## 전역 쿨타임 배율을 step*10%만큼 바꾼다 (10~200%에서 멈춘다)
func _change_cooldown(step: int) -> void:
	_cooldown_percent = clampi(_cooldown_percent + step * COOLDOWN_STEP, MIN_COOLDOWN_PERCENT, MAX_COOLDOWN_PERCENT)
	_refresh()

## 라운드 값 칸에서 Enter를 누르거나 칸 밖을 클릭했을 때 — 숫자가 아니면 그냥 이전 값으로 되돌린다
func _on_rounds_text_submitted(text: String) -> void:
	var stripped: String = text.strip_edges()
	if stripped.is_valid_int():
		_rounds = clampi(int(stripped), MIN_ROUNDS, MAX_ROUNDS)
	_refresh()
	_rounds_value.release_focus()

## 쿨타임 값 칸에서 Enter를 누르거나 칸 밖을 클릭했을 때 — "%"가 붙어 있어도 앞의 숫자만 읽는다
func _on_cooldown_text_submitted(text: String) -> void:
	var stripped: String = text.strip_edges().trim_suffix("%")
	if stripped.is_valid_int():
		_cooldown_percent = clampi(int(stripped), MIN_COOLDOWN_PERCENT, MAX_COOLDOWN_PERCENT)
	_refresh()
	_cooldown_value.release_focus()

func _on_clash_toggle_pressed() -> void:
	_clash_enabled = not _clash_enabled
	_refresh()

func _on_guard_toggle_pressed() -> void:
	_guard_enabled = not _guard_enabled
	_refresh()

func _on_dash_toggle_pressed() -> void:
	_dash_enabled = not _dash_enabled
	_refresh()

## 라운드 수 + 시간 인덱스를 한 번에 정한다
func _apply_preset(rounds: int, time_index: int) -> void:
	_rounds = clampi(rounds, MIN_ROUNDS, MAX_ROUNDS)
	_time_index = clampi(time_index, 0, TIME_OPTIONS.size() - 1)
	_refresh()

## "프리셋" 버튼 아래에 메뉴를 띄운다 — 맨 위 "현재 설정 저장", 그 아래 저장해둔 내 프리셋
func _on_more_presets_pressed() -> void:
	var menu := PopupMenu.new()
	menu.add_item("현재 설정 저장...", 0)
	var saved: Dictionary = GameState.load_room_presets()
	var saved_names: Array = saved.keys()
	if not saved_names.is_empty():
		menu.add_separator("내 프리셋")
		for i in range(saved_names.size()):
			menu.add_item(str(saved_names[i]), SAVED_PRESET_ID_BASE + i)
	add_child(menu)
	menu.id_pressed.connect(func(id: int):
		if id == 0:
			_show_save_preset_dialog()
		else:
			var idx: int = id - SAVED_PRESET_ID_BASE
			if idx >= 0 and idx < saved_names.size():
				_apply_saved_preset(saved.get(saved_names[idx], {}))
	)
	menu.popup_hide.connect(menu.queue_free)
	var btn: Button = $PresetMore
	var below: Vector2 = btn.global_position + Vector2(0, btn.size.y)
	menu.popup(Rect2i(Vector2i(below), Vector2i.ZERO))

## 저장해둔 프리셋 하나를 지금 화면에 그대로 반영한다 (값이 없는 항목은 지금 값을 유지)
func _apply_saved_preset(data: Dictionary) -> void:
	_rounds = clampi(int(data.get("rounds", _rounds)), MIN_ROUNDS, MAX_ROUNDS)
	_time_index = clampi(int(data.get("time_index", _time_index)), 0, TIME_OPTIONS.size() - 1)
	_cooldown_percent = clampi(int(data.get("cooldown_percent", _cooldown_percent)), MIN_COOLDOWN_PERCENT, MAX_COOLDOWN_PERCENT)
	_clash_enabled = bool(data.get("clash_enabled", _clash_enabled))
	_guard_enabled = bool(data.get("guard_enabled", _guard_enabled))
	_dash_enabled = bool(data.get("dash_enabled", _dash_enabled))
	_refresh()

## 지금 화면의 여섯 값을 이름 붙여 저장할 수 있는 작은 입력창을 띄운다(MapSelect의 팝업과 같은 방식으로 코드로 직접 만든다)
func _show_save_preset_dialog() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -220.0
	panel.offset_right = 220.0
	panel.offset_top = -90.0
	panel.offset_bottom = 90.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.09, 0.16, 0.97)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.45, 0.38, 0.6, 1)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var label := Label.new()
	label.text = "프리셋 이름"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "예: 나만의 설정"
	name_edit.max_length = 20
	vbox.add_child(name_edit)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 12)
	vbox.add_child(button_row)

	var save_btn := Button.new()
	save_btn.text = "저장"
	button_row.add_child(save_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "취소"
	button_row.add_child(cancel_btn)

	save_btn.pressed.connect(func():
		var preset_name: String = name_edit.text.strip_edges()
		if preset_name == "":
			preset_name = "프리셋 %d" % (GameState.load_room_presets().size() + 1)
		_save_current_as_preset(preset_name)
		overlay.queue_free()
	)
	cancel_btn.pressed.connect(overlay.queue_free)
	name_edit.text_submitted.connect(func(_t): save_btn.pressed.emit())
	name_edit.grab_focus()

## 지금 화면의 여섯 값을 이름 붙여 GameState에 저장한다 (같은 이름이면 덮어쓴다)
func _save_current_as_preset(preset_name: String) -> void:
	GameState.save_room_preset(preset_name, {
		"rounds": _rounds,
		"time_index": _time_index,
		"cooldown_percent": _cooldown_percent,
		"clash_enabled": _clash_enabled,
		"guard_enabled": _guard_enabled,
		"dash_enabled": _dash_enabled,
	})

## 화면의 숫자·토글·요약을 지금 값에 맞춘다
func _refresh() -> void:
	var time_name: String = TIME_OPTIONS[_time_index][0]
	_rounds_value.text = str(_rounds)
	_time_value.text = time_name
	_cooldown_value.text = "%d%%" % _cooldown_percent
	_set_toggle(_clash_toggle, _clash_enabled)
	_set_toggle(_guard_toggle, _guard_enabled)
	_set_toggle(_dash_toggle, _dash_enabled)
	var clash_text: String = "켬" if _clash_enabled else "끔"
	var guard_text: String = "켬" if _guard_enabled else "끔"
	var dash_text: String = "켬" if _dash_enabled else "끔"
	var time_summary: String = "시간 무제한" if _time_index == 0 else "한 라운드 %s" % time_name
	_summary.text = "%d선승 / %s / 쿨타임 %d%% / 연타 %s / 가드 %s / 대시 %s" % [
		_rounds, time_summary, _cooldown_percent, clash_text, guard_text, dash_text
	]

## on/off 상태에 따라 토글 버튼 글자·색을 초록/빨강으로 바꾼다
func _set_toggle(toggle: Button, enabled: bool) -> void:
	toggle.text = "ON" if enabled else "OFF"
	toggle.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08, 1))
	toggle.add_theme_constant_override("outline_size", 4)
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	if enabled:
		style.bg_color = Color(0.25, 0.62, 0.36, 0.45)
		style.border_color = Color(0.55, 0.95, 0.65, 1)
	else:
		style.bg_color = Color(0.42, 0.22, 0.24, 0.45)
		style.border_color = Color(0.75, 0.4, 0.42, 1)
	toggle.add_theme_stylebox_override("normal", style)
	toggle.add_theme_stylebox_override("hover", style)
	toggle.add_theme_stylebox_override("pressed", style)
	toggle.add_theme_stylebox_override("focus", style)

func _on_next_pressed() -> void:
	GameState.rounds_to_win = _rounds
	GameState.time_limit_seconds = int(TIME_OPTIONS[_time_index][1])
	GameState.cooldown_multiplier = _cooldown_percent / 100.0
	GameState.clash_minigame_enabled = _clash_enabled
	GameState.guard_enabled = _guard_enabled
	GameState.dash_enabled = _dash_enabled
	GameState.reset_round_wins()
	get_tree().change_scene_to_file("res://ui/CharacterSelect.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
