class_name HowToPlay
extends Control

## 조작 방법 화면 — **설정 > 조작 탭과 똑같은 키보드 그림**으로 보여준다(2026-09-30).
## 예전에는 "조작 이름 + 키" 16줄짜리 표였는데, 설정에서 키를 바꿀 때 보는 그림과
## 여기서 보는 표가 서로 달라 같은 걸 두 번 익혀야 했다.
##
## 그림은 `ui/KeyboardMap.gd`가 그대로 그린다 — **읽기 전용**이라 여기서는 못 끌어다 놓는다.
## 키를 바꾸는 건 설정 > 조작 탭에서 한다.
## 배정은 InputMap에서 그때그때 읽으므로, 설정에서 바꾼 키가 여기에도 바로 반영된다

## 좌측 상단 ◀에 커서를 올렸을 때 커지는 배수 — 도감·설정과 같은 값이라 손맛이 통일된다
@export var back_hover_scale: float = 1.18

@onready var _keyboard: KeyboardMap = $Center/VBox/Keyboard
@onready var _back_button: Button = $BackButton

func _ready() -> void:
	# 이 화면에 들어올 때마다 지금 배정을 다시 읽는다 — 설정에서 바꾸고 돌아온 경우가 있다
	_keyboard.refresh()
	_back_button.pressed.connect(_on_back_pressed)
	# 커지는 기준점을 버튼 한가운데로 — 왼쪽 위 기준이면 커질 때 오른쪽 아래로 밀린다
	_back_button.pivot_offset = _back_button.size * 0.5
	_back_button.mouse_entered.connect(_on_back_hover.bind(true))
	_back_button.mouse_exited.connect(_on_back_hover.bind(false))

func _on_back_hover(entered: bool) -> void:
	_back_button.pivot_offset = _back_button.size * 0.5
	var goal: Vector2 = Vector2.ONE * (back_hover_scale if entered else 1.0)
	var tw := create_tween()
	tw.tween_property(_back_button, "scale", goal, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
