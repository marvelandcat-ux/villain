class_name TitleScreen
extends Control

## 게임을 켜면 가장 먼저 나오는 타이틀 화면. 아무 키나 누르면 메인 메뉴로 넘어간다.
## 게임 이름은 여기 한 곳(TitleLabel)과 메인 메뉴에만 있으므로 바꿀 때 두 군데만 고치면 된다
##
## 소리·화면 전환 흐름:
##  1. 켜지면 검은 화면이 걷히면서(enter_fade) 타이틀 브금이 반복 재생된다
##  2. 아무 키나 누르면 클릭 소리가 나고, 화면이 어두워지며(exit_fade) 브금도 같이 잦아든다
##  3. 다 어두워지면 메인 메뉴로 넘어간다
##
## **브금 반복은 코드에서 켠다** — mp3는 임포트 설정에 loop 옵션이 있지만, 그 설정에 기대지 않고
## `AudioStreamMP3.loop`을 _ready()에서 직접 true로 둔다(임포트 설정을 다시 만져도 안 풀린다).

## "아무 키나 누르세요"가 1초에 몇 번 깜빡일지
@export var blink_speed: float = 1.4

@export_group("화면 전환")
## 켜질 때 검은 화면이 걷히는 시간(초)
@export var enter_fade: float = 0.6
## 키를 누른 뒤 어두워지며 메인 메뉴로 넘어가기까지의 시간(초).
## 클릭 소리가 들릴 만큼은 줘야 한다
@export var exit_fade: float = 1.0
## 어두워지는 동안 브금이 잦아드는 정도 (1이면 완전히 무음까지)
@export_range(0.0, 1.0, 0.05) var bgm_fade_out: float = 1.0

@onready var _prompt: Label = $Center/VBox/PromptLabel
@onready var _fade: ColorRect = $Fade
@onready var _bgm: AudioStreamPlayer = $Bgm
@onready var _click: AudioStreamPlayer = $Click

var _time: float = 0.0
## 씬을 넘기는 중이면 입력을 두 번 받지 않도록 잠근다
var _leaving: bool = false
## 나가는 연출이 얼마나 진행됐는지(초)
var _leave_time: float = 0.0
## 브금이 원래 크기(dB) — 잦아들 때 여기서부터 내려간다
var _bgm_volume: float = 0.0

func _ready() -> void:
	_fade.color.a = 1.0
	if _bgm.stream is AudioStreamMP3:
		_bgm.stream.loop = true
	_bgm_volume = _bgm.volume_db
	_bgm.play()

func _process(delta: float) -> void:
	_time += delta
	# 0.35~1.0 사이를 오가게 해서 완전히 사라지지는 않고 은은하게 깜빡인다
	_prompt.modulate.a = 0.675 + 0.325 * sin(_time * blink_speed * TAU)

	if not _leaving:
		# 켜질 때: 검은 판이 서서히 걷힌다
		_fade.color.a = clampf(1.0 - _time / maxf(enter_fade, 0.001), 0.0, 1.0)
		return

	_leave_time += delta
	var t: float = clampf(_leave_time / maxf(exit_fade, 0.001), 0.0, 1.0)
	_fade.color.a = t
	# 브금은 소리 크기를 dB로 내린다. 0배는 -inf라 -60dB에서 끊는다
	var level: float = 1.0 - bgm_fade_out * t
	_bgm.volume_db = _bgm_volume + (linear_to_db(level) if level > 0.001 else -60.0)
	if t >= 1.0:
		get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if pressed:
		_leaving = true
		_leave_time = 0.0
		_click.play()
