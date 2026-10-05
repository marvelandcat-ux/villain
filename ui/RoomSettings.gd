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
## 왼쪽 줄(라운드·라운드 시간·쿨타임)은 ◀▶로 넘기고, 라운드·쿨타임은 값 칸을 눌러 **직접 쳐 넣어도** 된다
## (Enter를 누르거나 칸 밖을 누르면 확정, 숫자가 아니면 되돌아간다).
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

## 모드 — 탭 순서와 같다
enum Mode { STANDARD, CHAOS, CUSTOM }

## 모드마다 정해진 값 [라운드, 시간칸, 쿨타임%]. 사용자 설정은 건드리지 않으므로 없다
const MODE_VALUES := {
	Mode.STANDARD: [2, 2, 100],
	Mode.CHAOS: [2, 2, 10],
}

@onready var _tab_bar: RoomTabBar = $TabBar
@onready var _rounds_value: LineEdit = $RoundValue
@onready var _time_value: Label = $TimeValue
@onready var _cooldown_value: LineEdit = $CooldownValue
@onready var _cutin_toggle: SlantToggle = $CutinToggle
@onready var _minigame_toggle: SlantToggle = $MinigameToggle
@onready var _result_toggle: SlantToggle = $ResultToggle
@onready var _opponent_toggle: SlantToggle = $OpponentToggle

var _rounds: int = 2
## TIME_OPTIONS 중 몇 번째 칸인지. 2 = "2분"(기본값)
var _time_index: int = 2
var _cooldown_percent: int = 100
var _cutin_on: bool = true
var _minigame_on: bool = true
var _result_on: bool = true
## true면 P2를 컴퓨터가 조종한다 — 지난번 고른 값을 기억해 둔다
var _vs_ai: bool = GameState.vs_ai
var _mode: int = Mode.STANDARD

func _ready() -> void:
	_load_saved()
	_tab_bar.tab_pressed.connect(_on_tab_pressed)
	$RoundPrev.pressed.connect(func(): _change_rounds(-1))
	$RoundNext.pressed.connect(func(): _change_rounds(1))
	$TimePrev.pressed.connect(func(): _change_time(-1))
	$TimeNext.pressed.connect(func(): _change_time(1))
	$CooldownPrev.pressed.connect(func(): _change_cooldown(-1))
	$CooldownNext.pressed.connect(func(): _change_cooldown(1))
	_rounds_value.text_submitted.connect(_on_rounds_text_submitted)
	_rounds_value.focus_exited.connect(func(): _on_rounds_text_submitted(_rounds_value.text))
	_cooldown_value.text_submitted.connect(_on_cooldown_text_submitted)
	_cooldown_value.focus_exited.connect(func(): _on_cooldown_text_submitted(_cooldown_value.text))
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
	_refresh()

## 지난번 설정을 이어 쓴다 — 방을 다시 열 때마다 처음부터 맞추지 않게
func _load_saved() -> void:
	_rounds = clampi(GameState.rounds_to_win, MIN_ROUNDS, MAX_ROUNDS)
	_cooldown_percent = clampi(int(round(GameState.cooldown_multiplier * 100.0)),
		MIN_COOLDOWN_PERCENT, MAX_COOLDOWN_PERCENT)
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
		_refresh()
		return
	var values: Array = MODE_VALUES[index]
	_rounds = int(values[0])
	_time_index = int(values[1])
	_cooldown_percent = int(values[2])
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
		if _rounds == int(v[0]) and _time_index == int(v[1]) and _cooldown_percent == int(v[2]):
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
	if _mode == Mode.CUSTOM:
		_mode = _match_mode()
	_rounds_value.text = str(_rounds)
	_time_value.text = str(TIME_OPTIONS[_time_index][0])
	_cooldown_value.text = "%d%%" % _cooldown_percent
	_tab_bar.selected = _mode

## --- 넘어가기 ---

func _on_next_pressed() -> void:
	GameState.rounds_to_win = _rounds
	GameState.time_limit_seconds = int(TIME_OPTIONS[_time_index][1])
	GameState.cooldown_multiplier = float(_cooldown_percent) / 100.0
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
