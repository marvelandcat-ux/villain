class_name Disclaimer
extends Control

## 게임을 켜면 타이틀보다 **먼저** 나오는 경고 문구 화면 (검은 화면 + 글자만).
## 캐릭터가 실존 인물을 겨냥한 게 아니라는 점을 알리는 고지라, 건너뛰더라도 최소 시간은 띄운다.
##
## 흐름: 검게 시작 -> 글자가 서서히 나타남 -> 읽을 시간만큼 유지 -> 글자가 사라짐 -> 타이틀 화면.
## **전체 2초**(0.35 + 1.3 + 0.35)로 줄였다(2026-10-08 사용자). 원래는 6.1초였다.
## 타이틀은 문구가 떠 있는 동안 **미리 읽어 둔다**. 그래도 글자가 사라진 뒤에 타이틀이
## 아레나를 짓는 1.4초쯤은 검은 화면으로 남는다 — 측정값이고, 문구가 보이는 시간은 아니다
## `skip_after` 뒤부터는 아무 키나 클릭으로 건너뛸 수 있다(그 전엔 안 먹는다 — 연타로 넘겨버리는 걸 막는다).
## 단 **S만은 뜨자마자 바로 넘어간다** — 개발 중에 매번 기다리기 번거로워서 둔 지름길이다

## 이 화면 다음에 열 장면
@export_file("*.tscn") var next_scene: String = "res://ui/TitleScreen.tscn"
## 글자가 나타나는 시간(초)
@export var fade_in_time: float = 0.35
## 다 보이는 채로 머무는 시간(초)
@export var hold_time: float = 1.3
## 글자가 사라지는 시간(초)
@export var fade_out_time: float = 0.35
## 이 시간이 지난 뒤부터 키·클릭으로 건너뛸 수 있다(초)
@export var skip_after: float = 0.5
## **이 키만은 최소 시간을 안 기다리고 바로 건너뛴다.** 개발 중에 매번 기다리기 번거로워서 둔 지름길이다
@export var instant_skip_key: Key = KEY_S

@onready var _text: Control = $Text

var _time: float = 0.0
var _leaving: bool = false

## 타이틀을 **미리 읽어 두었는지** — 다 읽혔으면 장면 교체가 즉시 끝난다
var _preloading: bool = false

func _ready() -> void:
	_text.modulate.a = 0.0
	# **타이틀을 뒤에서 미리 읽는다.** 문구가 끝난 뒤에 읽기 시작하면 그동안 이 화면이
	# 그대로 멈춰 있다. 미리 읽어 두면 교체 순간에 파일 읽기는 3ms로 끝난다
	# (남는 지연은 타이틀이 아레나를 **짓는** 시간이라 여기서 못 줄인다)
	if ResourceLoader.exists(next_scene):
		_preloading = ResourceLoader.load_threaded_request(next_scene) == OK

func _process(delta: float) -> void:
	_time += delta
	if _leaving:
		return
	if _time < fade_in_time:
		_text.modulate.a = _time / maxf(fade_in_time, 0.001)
	elif _time < fade_in_time + hold_time:
		_text.modulate.a = 1.0
	else:
		var out: float = (_time - fade_in_time - hold_time) / maxf(fade_out_time, 0.001)
		_text.modulate.a = clampf(1.0 - out, 0.0, 1.0)
		if out >= 1.0:
			_go_next()

func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	# S는 뜨자마자 바로 넘어간다 (다른 키·클릭은 skip_after를 기다려야 한다)
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == instant_skip_key:
		get_viewport().set_input_as_handled()
		_go_next()
		return
	if _time < skip_after:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		get_viewport().set_input_as_handled()
		_go_next()

func _go_next() -> void:
	if _leaving:
		return
	_leaving = true
	if not ResourceLoader.exists(next_scene):
		push_warning("Disclaimer: 다음 장면을 못 찾았다 — %s" % next_scene)
		return
	# 미리 읽기가 끝나 있으면 기다릴 게 없다. 아직이면 여기서 끝까지 기다리는데,
	# 그건 `change_scene_to_file`로 그냥 읽는 것과 같은 시간이라 손해가 없다
	if _preloading:
		var packed: PackedScene = ResourceLoader.load_threaded_get(next_scene) as PackedScene
		if packed != null:
			get_tree().change_scene_to_packed(packed)
			return
	get_tree().change_scene_to_file(next_scene)
