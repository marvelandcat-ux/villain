class_name RoomSettings
extends Control

## 로컬 대전 방 만들기 — 선취 라운드 수(1~40)와 라운드 시간제한을 정하고 캐릭터 선택으로 넘어간다.
##
## 대난투 규칙 설정 화면을 참고한 구성이다(2026-09-09 개편):
##  - 위: 빠른 설정 프리셋 3개 (누르면 두 값이 한 번에 정해진다)
##  - 가운데: 큰 카드 2장. 각 카드는 [◀ 큰 값 ▶] 스테퍼 + 아래 한 줄 설명
##  - 아래: 지금 설정을 한 줄로 요약
##
## 예전에는 SpinBox/OptionButton을 세로로 늘어놓기만 해서 화면이 휑했다.
## 배경은 메인 메뉴와 같은 그림에 같은 흐림 셰이더를 걸어 화면이 이어지는 느낌을 준다.
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
## 빠른 설정 프리셋 (선취 라운드, 시간 선택지 index)
const PRESET_QUICK := [1, 1]      # 1선승 · 1분
const PRESET_STANDARD := [2, 2]   # 2선승 · 2분
const PRESET_LONG := [3, 3]       # 3선승 · 3분

const MIN_ROUNDS := 1
const MAX_ROUNDS := 40

@onready var _rounds_value: Label = $RoundsCard/Value
@onready var _rounds_hint: Label = $RoundsCard/Hint
@onready var _time_value: Label = $TimeCard/Value
@onready var _summary: Label = $Summary

var _rounds: int = 2
var _time_index: int = 0

func _ready() -> void:
	$RoundsCard/Prev.pressed.connect(func(): _change_rounds(-1))
	$RoundsCard/Next.pressed.connect(func(): _change_rounds(1))
	$TimeCard/Prev.pressed.connect(func(): _change_time(-1))
	$TimeCard/Next.pressed.connect(func(): _change_time(1))
	$PresetQuick.pressed.connect(func(): _apply_preset(PRESET_QUICK))
	$PresetStandard.pressed.connect(func(): _apply_preset(PRESET_STANDARD))
	$PresetLong.pressed.connect(func(): _apply_preset(PRESET_LONG))
	$NextButton.pressed.connect(_on_next_pressed)
	$BackButton.pressed.connect(_on_back_pressed)
	# 키보드/패드로 바로 조작되도록 첫 버튼에 포커스를 준다
	$NextButton.grab_focus()
	_refresh()

## 선취 라운드 수를 step만큼 바꾼다 (1~40에서 멈춘다)
func _change_rounds(step: int) -> void:
	_rounds = clampi(_rounds + step, MIN_ROUNDS, MAX_ROUNDS)
	_refresh()

## 시간제한 선택지를 step만큼 옮긴다 (양끝에서 반대쪽으로 돌아간다)
func _change_time(step: int) -> void:
	_time_index = wrapi(_time_index + step, 0, TIME_OPTIONS.size())
	_refresh()

## 프리셋 하나를 그대로 적용한다
func _apply_preset(preset: Array) -> void:
	_rounds = clampi(int(preset[0]), MIN_ROUNDS, MAX_ROUNDS)
	_time_index = clampi(int(preset[1]), 0, TIME_OPTIONS.size() - 1)
	_refresh()

## 화면의 숫자·설명·요약을 지금 값에 맞춘다
func _refresh() -> void:
	var time_name: String = TIME_OPTIONS[_time_index][0]
	_rounds_value.text = str(_rounds)
	_rounds_hint.text = "먼저 %d판 이기면 승리 (%d~%d)" % [_rounds, MIN_ROUNDS, MAX_ROUNDS]
	_time_value.text = time_name
	if _time_index == 0:
		_summary.text = "%d선승 / 시간 무제한" % _rounds
	else:
		_summary.text = "%d선승 / 한 라운드 %s" % [_rounds, time_name]

func _on_next_pressed() -> void:
	GameState.rounds_to_win = _rounds
	GameState.time_limit_seconds = int(TIME_OPTIONS[_time_index][1])
	GameState.reset_round_wins()
	get_tree().change_scene_to_file("res://ui/CharacterSelect.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
