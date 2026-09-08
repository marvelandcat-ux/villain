class_name TitleScreen
extends Control

## 게임을 켜면 가장 먼저 나오는 타이틀 화면. 아무 키나 누르면 메인 메뉴로 넘어간다.
## 게임 이름은 여기 한 곳(TitleLabel)과 메인 메뉴에만 있으므로 바꿀 때 두 군데만 고치면 된다

## "아무 키나 누르세요"가 1초에 몇 번 깜빡일지
@export var blink_speed: float = 1.4

@onready var _prompt: Label = $Center/VBox/PromptLabel

var _time: float = 0.0
## 씬을 넘기는 중이면 입력을 두 번 받지 않도록 잠근다
var _leaving: bool = false

func _process(delta: float) -> void:
	_time += delta
	# 0.35~1.0 사이를 오가게 해서 완전히 사라지지는 않고 은은하게 깜빡인다
	_prompt.modulate.a = 0.675 + 0.325 * sin(_time * blink_speed * TAU)

func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if pressed:
		_leaving = true
		get_tree().change_scene_to_file("res://ui/MainMenu.tscn")
