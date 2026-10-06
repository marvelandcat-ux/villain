class_name RoomSettings
extends Control

## 로컬 대전 방 만들기 — 라운드 수(1~40), 라운드 제한시간, 전역 쿨타임 배율(10~200%),
## 연출·미니게임 켜고 끄기, 상대(P2) 사람/컴퓨터를 정하고 캐릭터 선택으로 넘어간다.
##
## **2026-10-05 개편**(사용자 스케치): 둥근 카드를 걷어내고 **평행사변형**으로 통일했다.
## 설정 화면·메인메뉴와 같은 결이다 — 탭과 큰 판은 `ui/FanTile.gd`, 켜기/끄기는 `ui/SlantToggle.gd`로
## 그 화면들이 쓰던 부품을 그대로 쓴다.
##
## 위쪽 탭 셋은 **따로 떨어진 버튼이 아니라** 큰 평행사변형 위쪽을 선으로 나눈 칸이다
## (`ui/RoomTabBar.gd`) — 고른 칸만 색이 차고 그 칸 아래 선이 비어서 본문과 한 덩어리로 이어진다.
##
## 탭 셋이 **모드**다:
##  - **표준**: 2선승 / 2분 / 쿨타임 100%
##  - **난장판**: 표준과 같고 **쿨타임만 10%**
##  - **사용자 설정**: 아무 값이나. 값을 하나라도 건드리면 저절로 이 탭으로 옮겨 온다
##
## 왼쪽 줄(라운드·라운드 시간·쿨타임·체력)은 ◀▶로 넘기고, 라운드·쿨타임은 값 칸을 눌러 **직접 쳐 넣어도** 된다
## (Enter를 누르거나 칸 밖을 누르면 확정, 숫자가 아니면 되돌아간다).
##
## **체력**은 두 선수의 최대 체력에 곱하는 배율이다(50~200%) — 한 판 길이를 조절하는 또 하나의 손잡이다.
## `Stage`가 캐릭터를 만들 때 스탯 리소스를 복제해서 건다
##
## 오른쪽 줄은 켜기/끄기 넷이다:
##  - **궁극기 연출**: 끄면 컷인 없이 궁이 바로 나간다(`GameState.ultimate_cutin_enabled`)
##  - **연타 미니게임**: 끄면 스킬이 부딪쳐도 연타 승부를 안 벌인다(`GameState.clash_minigame_enabled`)
##  - **승패 연출**: 끄면 라운드 승패 띠를 건너뛴다(`GameState.result_cutscene_enabled`)
##  - **상대**: 꺼짐이 사람, 켜짐이 컴퓨터(`GameState.vs_ai`)
##
## **화살표(◀ ▶)만 기본 폰트를 쓴다** — 주아체(Jua)에 그 글리프가 없어서 폰트를 지정하면 네모로 나온다.
##
## ⚠️ **가드·대시는 이제 못 끈다**(2026-10-05 사용자 결정) — 둘 다 기본 조작이라 끌 이유가 없다.
## `GameState.guard_enabled`/`dash_enabled`는 늘 켜진 채로 남아 있다.
##
## 돌아가기는 **왼쪽 위 ◀ 버튼뿐**이다(설정·도감과 같은 모양). ESC로 나가는 길은 없앴다.
## 아래 한 줄 요약도 없앴다 — 값이 화면에 다 보여서 두 번 말하는 셈이었다

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
## 체력 배율(%) — 절반이면 순삭 난타전, 두 배면 장기전
const MIN_HP_PERCENT := 50
const MAX_HP_PERCENT := 200
const HP_STEP := 10

## 모드 — 탭 순서와 같다
enum Mode { STANDARD, CHAOS, CUSTOM }

## 모드마다 정해진 값 [라운드, 시간칸, 쿨타임%]. 사용자 설정은 건드리지 않으므로 없다
const MODE_VALUES := {
	Mode.STANDARD: [2, 2, 100, 100],
	Mode.CHAOS: [2, 2, 10, 100],
}

@onready var _tab_bar: RoomTabBar = $TabBar
@onready var _rounds_value: LineEdit = $RoundValue
@onready var _time_value: Label = $TimeValue
@onready var _cooldown_value: LineEdit = $CooldownValue
@onready var _hp_value: LineEdit = $HpValue
@onready var _cutin_toggle: SlantToggle = $CutinToggle
@onready var _minigame_toggle: SlantToggle = $MinigameToggle
@onready var _result_toggle: SlantToggle = $ResultToggle
@onready var _opponent_toggle: SlantToggle = $OpponentToggle

var _rounds: int = 2
## TIME_OPTIONS 중 몇 번째 칸인지. 2 = "2분"(기본값)
var _time_index: int = 2
var _cooldown_percent: int = 100
var _hp_percent: int = 100
var _cutin_on: bool = true
var _minigame_on: bool = true
var _result_on: bool = true
## true면 P2를 컴퓨터가 조종한다 — 지난번 고른 값을 기억해 둔다
var _vs_ai: bool = GameState.vs_ai
var _mode: int = Mode.STANDARD
## 사용자가 **직접** 사용자 설정 탭을 골랐는지. 켜져 있으면 값이 표준과 같아도 그 탭에 머문다 —
## 안 그러면 눌러도 곧바로 표준으로 되돌아가서 "안 눌린다"로 보인다(2026-10-05)
var _custom_picked: bool = false

func _ready() -> void:
	_load_saved()
	_tab_bar.tab_pressed.connect(_on_tab_pressed)
	$RoundPrev.pressed.connect(func(): _change_rounds(-1))
	$RoundNext.pressed.connect(func(): _change_rounds(1))
	$TimePrev.pressed.connect(func(): _change_time(-1))
	$TimeNext.pressed.connect(func(): _change_time(1))
	$CooldownPrev.pressed.connect(func(): _change_cooldown(-1))
	$CooldownNext.pressed.connect(func(): _change_cooldown(1))
	$HpPrev.pressed.connect(func(): _change_hp(-1))
	$HpNext.pressed.connect(func(): _change_hp(1))
	_rounds_value.text_submitted.connect(_on_rounds_text_submitted)
	_rounds_value.focus_exited.connect(func(): _on_rounds_text_submitted(_rounds_value.text))
	_cooldown_value.text_submitted.connect(_on_cooldown_text_submitted)
	_cooldown_value.focus_exited.connect(func(): _on_cooldown_text_submitted(_cooldown_value.text))
	_hp_value.text_submitted.connect(_on_hp_text_submitted)
	_hp_value.focus_exited.connect(func(): _on_hp_text_submitted(_hp_value.text))
	# 켜기/끄기 세 가지 — **애니메이션 없이** 지금 값으로 맞춰 두고 시작한다
	_cutin_toggle.set_on_instant(_cutin_on)
	_minigame_toggle.set_on_instant(_minigame_on)
	_result_toggle.set_on_instant(_result_on)
	_opponent_toggle.set_on_instant(_vs_ai)
	_cutin_toggle.state_changed.connect(func(on): _on_switch_changed("cutin", on))
	_minigame_toggle.state_changed.connect(func(on): _on_switch_changed("minigame", on))
	_result_toggle.state_changed.connect(func(on): _on_switch_changed("result", on))
	_opponent_toggle.state_changed.connect(_on_opponent_changed)
	$NextButton.pressed.connect(_on_next_pressed)
	$BackButton.pressed.connect(_on_back_pressed)
	# 마우스를 올리면 살짝 커진다 — 설정 화면 뒤로가기와 같은 방식이다
	$NextButton.mouse_entered.connect(_on_hover.bind($NextButton, NEXT_HOVER_SCALE, true))
	$NextButton.mouse_exited.connect(_on_hover.bind($NextButton, NEXT_HOVER_SCALE, false))
	$BackButton.mouse_entered.connect(_on_hover.bind($BackButton, BACK_HOVER_SCALE, true))
	$BackButton.mouse_exited.connect(_on_hover.bind($BackButton, BACK_HOVER_SCALE, false))
	_refresh()
	_paint_cursor()

## 지난번 설정을 이어 쓴다 — 방을 다시 열 때마다 처음부터 맞추지 않게
func _load_saved() -> void:
	_rounds = clampi(GameState.rounds_to_win, MIN_ROUNDS, MAX_ROUNDS)
	_cooldown_percent = clampi(int(round(GameState.cooldown_multiplier * 100.0)),
		MIN_COOLDOWN_PERCENT, MAX_COOLDOWN_PERCENT)
	_hp_percent = clampi(int(round(GameState.hp_multiplier * 100.0)), MIN_HP_PERCENT, MAX_HP_PERCENT)
	_cutin_on = GameState.ultimate_cutin_enabled
	_minigame_on = GameState.clash_minigame_enabled
	_result_on = GameState.result_cutscene_enabled
	for i in TIME_OPTIONS.size():
		if int(TIME_OPTIONS[i][1]) == GameState.time_limit_seconds:
			_time_index = i
			break

## --- 모드 탭 ---

func _on_tab_pressed(index: int) -> void:
	if index == Mode.CUSTOM:
		# 사용자 설정은 값을 안 건드린다 — 지금 값 그대로 "내가 맞춘 설정"이 된다
		_mode = Mode.CUSTOM
		_custom_picked = true
		_refresh()
		return
	_custom_picked = false
	var values: Array = MODE_VALUES[index]
	_rounds = int(values[0])
	_time_index = int(values[1])
	_cooldown_percent = int(values[2])
	_hp_percent = int(values[3])
	_mode = index
	_refresh()

## 값을 하나라도 건드리면 **사용자 설정**으로 옮겨 온다 —
## 표준을 골라 둔 채로 쿨타임만 바꾸면 그건 더 이상 표준이 아니다
func _mark_custom() -> void:
	if _mode != Mode.CUSTOM:
		_mode = Mode.CUSTOM

## 지금 값이 어느 모드와 똑같은지 — 맞는 게 있으면 그 탭으로 돌아간다
func _match_mode() -> int:
	for key in MODE_VALUES:
		var v: Array = MODE_VALUES[key]
		if _rounds == int(v[0]) and _time_index == int(v[1]) and _cooldown_percent == int(v[2]) 				and _hp_percent == int(v[3]):
			return key
	return Mode.CUSTOM

## --- 값 바꾸기 ---

func _change_rounds(step: int) -> void:
	_rounds = clampi(_rounds + step, MIN_ROUNDS, MAX_ROUNDS)
	_mark_custom()
	_refresh()

func _change_time(step: int) -> void:
	_time_index = wrapi(_time_index + step, 0, TIME_OPTIONS.size())
	_mark_custom()
	_refresh()

func _change_cooldown(step: int) -> void:
	_cooldown_percent = clampi(_cooldown_percent + step * COOLDOWN_STEP,
		MIN_COOLDOWN_PERCENT, MAX_COOLDOWN_PERCENT)
	_mark_custom()
	_refresh()

func _change_hp(step: int) -> void:
	_hp_percent = clampi(_hp_percent + step * HP_STEP, MIN_HP_PERCENT, MAX_HP_PERCENT)
	_mark_custom()
	_refresh()

## 라운드를 직접 쳐 넣었을 때 — 숫자가 아니면 이전 값으로 되돌아간다
func _on_rounds_text_submitted(text: String) -> void:
	var digits: String = _digits_of(text)
	if digits != "":
		_rounds = clampi(int(digits), MIN_ROUNDS, MAX_ROUNDS)
		_mark_custom()
	_rounds_value.release_focus()
	_refresh()

func _on_cooldown_text_submitted(text: String) -> void:
	var digits: String = _digits_of(text)
	if digits != "":
		# 10 단위로 맞춰 둔다 — ◀▶로 넘길 때와 같은 눈금을 쓴다
		var value: int = int(round(float(int(digits)) / float(COOLDOWN_STEP))) * COOLDOWN_STEP
		_cooldown_percent = clampi(value, MIN_COOLDOWN_PERCENT, MAX_COOLDOWN_PERCENT)
		_mark_custom()
	_cooldown_value.release_focus()
	_refresh()

func _on_hp_text_submitted(text: String) -> void:
	var digits: String = _digits_of(text)
	if digits != "":
		var value: int = int(round(float(int(digits)) / float(HP_STEP))) * HP_STEP
		_hp_percent = clampi(value, MIN_HP_PERCENT, MAX_HP_PERCENT)
		_mark_custom()
	_hp_value.release_focus()
	_refresh()

## 글자에서 숫자만 뽑는다("120%" -> "120"). 숫자가 없으면 빈 문자열
func _digits_of(text: String) -> String:
	var out: String = ""
	for ch in text:
		if ch >= "0" and ch <= "9":
			out += ch
	return out

## 켜기/끄기 — 연출 셋은 모드와 상관없다(표준이어도 연출은 끌 수 있다)
func _on_switch_changed(which: String, on: bool) -> void:
	match which:
		"cutin":
			_cutin_on = on
		"minigame":
			_minigame_on = on
		_:
			_result_on = on
	_refresh()

## 상대 — 꺼짐이 사람, 켜짐이 컴퓨터다
func _on_opponent_changed(on: bool) -> void:
	_vs_ai = on

## --- 보여주기 ---

func _refresh() -> void:
	# 값이 어느 모드와 같아졌으면 그 탭으로 되돌아간다(쿨타임을 10%로 맞추면 난장판이 켜진다)
	if _mode == Mode.CUSTOM and not _custom_picked:
		_mode = _match_mode()
	_rounds_value.text = str(_rounds)
	_time_value.text = str(TIME_OPTIONS[_time_index][0])
	_cooldown_value.text = "%d%%" % _cooldown_percent
	_hp_value.text = "%d%%" % _hp_percent
	_tab_bar.selected = _mode

## --- 넘어가기 ---

func _on_next_pressed() -> void:
	GameState.rounds_to_win = _rounds
	GameState.time_limit_seconds = int(TIME_OPTIONS[_time_index][1])
	GameState.cooldown_multiplier = float(_cooldown_percent) / 100.0
	GameState.hp_multiplier = float(_hp_percent) / 100.0
	GameState.ultimate_cutin_enabled = _cutin_on
	GameState.clash_minigame_enabled = _minigame_on
	GameState.result_cutscene_enabled = _result_on
	GameState.vs_ai = _vs_ai
	GameState.game_mode = "pvp"
	GameState.p1_round_wins = 0
	GameState.p2_round_wins = 0
	get_tree().change_scene_to_file("res://ui/CharacterSelect.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

## 마우스를 올렸을 때 커지는 정도 — 설정 화면과 같은 값이다
const NEXT_HOVER_SCALE := 1.06
const BACK_HOVER_SCALE := 1.18
## 커지고 작아지는 데 걸리는 시간(초)
const HOVER_TIME := 0.12

## 버튼 하나를 가운데를 축으로 키웠다 줄인다
func _on_hover(button: Control, goal_scale: float, entered: bool) -> void:
	button.pivot_offset = button.size * 0.5
	var goal: Vector2 = Vector2.ONE * (goal_scale if entered else 1.0)
	var tw: Tween = create_tween()
	tw.tween_property(button, "scale", goal, HOVER_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## --- 방향키 조작 ---
## 설정 화면·도감과 **같은 방식**이다 — 고도 기본 포커스를 안 쓰고 커서를 직접 옮긴다.
## 사선 칸과 직접 그린 토글이 섞여 있어서, 기본 포커스에 맡기면 어디로 갈지 예측이 안 된다.
##
## 위/아래로 줄을 옮기고, 좌/우로 그 줄의 값을 바꾼다(탭 줄에서는 탭이 옮겨 간다).
## 확인 키는 지금 줄을 누른 것과 같다 — 맨 아래 줄에서는 캐릭터 선택으로 넘어간다

## 커서가 설 수 있는 줄 — 위에서 아래로 늘어놓은 순서 그대로다
enum Cursor { TABS, ROUNDS, TIME, COOLDOWN, HP, CUTIN, MINIGAME, RESULT, OPPONENT, NEXT }
const CURSOR_LAST := Cursor.NEXT

## 방향키를 꾹 누르고 있을 때 — 처음 한 번, 한 박자 쉬고, 그 뒤로 빠르게 반복
const KEY_REPEAT_DELAY := 0.42
const KEY_REPEAT_INTERVAL := 0.1

var _cursor: int = Cursor.TABS
var _held_step: int = 0
var _repeat_left: float = 0.0

func _process(delta: float) -> void:
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
	# 값 칸에 글자를 치는 중이면 방향키는 글자 커서 몫이다
	if _rounds_value.has_focus() or _cooldown_value.has_focus() or _hp_value.has_focus():
		_held_step = 0
		return
	if step != _held_step:
		_held_step = step
		_repeat_left = KEY_REPEAT_DELAY
		_move_cursor(step)
		return
	_repeat_left -= delta
	if _repeat_left <= 0.0:
		_repeat_left = KEY_REPEAT_INTERVAL
		_move_cursor(step)

## 100/-100은 줄 옮기기, 1/-1은 지금 줄의 값 바꾸기
func _move_cursor(step: int) -> void:
	if absi(step) == 100:
		_cursor = clampi(_cursor + (1 if step > 0 else -1), 0, CURSOR_LAST)
		_paint_cursor()
		return
	_change_here(step)

## 지금 줄의 값을 좌우로 바꾼다
func _change_here(step: int) -> void:
	match _cursor:
		Cursor.TABS:
			_on_tab_pressed(clampi(_mode + step, 0, _tab_bar.tabs.size() - 1))
		Cursor.ROUNDS:
			_change_rounds(step)
		Cursor.TIME:
			_change_time(step)
		Cursor.COOLDOWN:
			_change_cooldown(step)
		Cursor.HP:
			_change_hp(step)
		Cursor.CUTIN:
			_cutin_toggle.set_on(step > 0)
		Cursor.MINIGAME:
			_minigame_toggle.set_on(step > 0)
		Cursor.RESULT:
			_result_toggle.set_on(step > 0)
		Cursor.OPPONENT:
			_opponent_toggle.set_on(step > 0)

## 커서가 어디 있는지 — 그 줄의 이름표를 밝게 칠한다
func _paint_cursor() -> void:
	var labels: Dictionary = {
		Cursor.ROUNDS: $RoundLabel, Cursor.TIME: $TimeLabel, Cursor.COOLDOWN: $CooldownLabel,
		Cursor.HP: $HpLabel,
		Cursor.CUTIN: $CutinLabel, Cursor.MINIGAME: $MinigameLabel,
		Cursor.RESULT: $ResultLabel, Cursor.OPPONENT: $OpponentLabel,
	}
	for key in labels:
		var label: Label = labels[key]
		label.add_theme_color_override("font_color",
			Color(1.0, 0.55, 0.65, 1.0) if key == _cursor else Color(1, 1, 1, 1))
	var next_text: Label = $NextButton/Text
	if next_text:
		next_text.add_theme_color_override("font_color",
			Color(1.0, 0.92, 0.6, 1.0) if _cursor == Cursor.NEXT else Color(1, 1, 1, 1))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if _cursor == Cursor.NEXT:
			_on_next_pressed()
		elif _cursor == Cursor.TABS:
			_on_tab_pressed(_mode)
		else:
			# 켜고 끄는 줄이면 뒤집는다
			_change_here(1 if not _switch_on_here() else -1)

## 지금 줄이 켜짐 상태인지(켜고 끄는 줄이 아니면 false)
func _switch_on_here() -> bool:
	match _cursor:
		Cursor.CUTIN:
			return _cutin_on
		Cursor.MINIGAME:
			return _minigame_on
		Cursor.RESULT:
			return _result_on
		Cursor.OPPONENT:
			return _vs_ai
	return false
