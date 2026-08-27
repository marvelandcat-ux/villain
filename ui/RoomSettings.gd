class_name RoomSettings
extends Control

## 로컬 대전 방 만들기 — 라운드 수(1~40)와 시간제한을 정하고 캐릭터 선택으로 넘어간다
@onready var rounds_spin: SpinBox = $VBox/RoundsRow/RoundsSpin
@onready var time_option: OptionButton = $VBox/TimeRow/TimeOption

## 시간제한 옵션 (표시 -> 초). "무제한"은 0
const TIME_OPTIONS := [
	["무제한", 0],
	["1분", 60],
	["2분", 120],
	["3분", 180],
	["5분", 300],
]

func _ready() -> void:
	rounds_spin.min_value = 1
	rounds_spin.max_value = 40
	rounds_spin.value = 2
	for opt in TIME_OPTIONS:
		time_option.add_item(opt[0])
	time_option.select(0)

func _on_next_pressed() -> void:
	GameState.rounds_to_win = int(rounds_spin.value)
	GameState.time_limit_seconds = TIME_OPTIONS[time_option.selected][1]
	GameState.reset_round_wins()
	get_tree().change_scene_to_file("res://ui/CharacterSelect.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/ModeSelect.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
