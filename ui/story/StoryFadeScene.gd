class_name StoryFadeScene
extends Control

## 스토리 모드의 한 장면 — **검은 화면에서 페이드인으로 시작해서, 잠깐 머문 뒤 페이드아웃하고 다음 장면으로 넘어간다.**
##
## (2026-09-12) 옛 스토리 모드(에피소드 선택 -> 캐릭터 선택 -> 대전 -> 개과천선 대사 -> 클리어)를 싹 걷어내고
## 새로 짜는 스토리 모드의 뼈대다. 장면마다 이 스크립트를 붙이고 인스펙터에서 시간·다음 장면만 바꿔 쓴다.
## 화면 내용은 씬에 자유롭게 올리면 되고, **맨 마지막 자식 `Fade`(검은 ColorRect)**가 알파로 가렸다 걷었다 한다 —
## 트리 맨 아래라서 다른 걸 아무리 올려도 그 위를 덮는다.
##
## 페이드아웃이 끝나면 화면이 완전히 검은 채로 다음 장면을 부르고, 다음 장면도 검은 화면에서 시작하므로 이음매가 안 보인다.
## ESC를 누르면 메인 메뉴로 나간다 — 다른 화면들처럼 언제든 빠져나갈 길이 있어야 한다.

## 검은 화면이 걷히는 시간(초)
@export var fade_in_time: float = 1.2
## 다 보인 채로 머무는 시간(초)
@export var hold_time: float = 1.5
## 다시 검게 덮이는 시간(초)
@export var fade_out_time: float = 1.2
## 다 끝나면 넘어갈 장면. **비워두면 페이드인한 채로 멈춰 있는다**(다음 장면이 아직 없는 마지막 장면)
@export_file("*.tscn") var next_scene: String = ""
## 대화창(DialogueBox)을 지정하면 대사를 끝까지 넘겨야 페이드아웃한다(hold_time도 지나야 함). 비우면 시간만 본다
@export var dialogue: NodePath

enum Step { FADE_IN, HOLD, FADE_OUT, DONE }

@onready var _fade: ColorRect = $Fade

var _step: int = Step.FADE_IN
var _t: float = 0.0

func _ready() -> void:
	_fade.color.a = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_t += delta
	match _step:
		Step.FADE_IN:
			_fade.color.a = 1.0 - clampf(_t / maxf(fade_in_time, 0.001), 0.0, 1.0)
			if _t >= fade_in_time:
				_go(Step.HOLD)
		Step.HOLD:
			if next_scene == "":
				_go(Step.DONE)   # 다음 장면이 없으면 여기서 끝 — 보이는 채로 멈춘다
			elif _t >= hold_time and _dialogue_done():
				_go(Step.FADE_OUT)
		Step.FADE_OUT:
			_fade.color.a = clampf(_t / maxf(fade_out_time, 0.001), 0.0, 1.0)
			if _t >= fade_out_time:
				_go(Step.DONE)
				_open_next()

func _dialogue_done() -> bool:
	if dialogue.is_empty():
		return true
	var box: DialogueBox = get_node_or_null(dialogue) as DialogueBox
	return box == null or box.is_finished()

func _go(step: int) -> void:
	_step = step
	_t = 0.0

func _open_next() -> void:
	# 경로가 틀렸으면 조용히 멈추는 대신 이유를 남긴다 (검은 화면에서 멈춰 버리면 왜 그런지 알 길이 없다)
	if not ResourceLoader.exists(next_scene):
		push_warning("StoryFadeScene: 다음 장면을 못 찾았다 — %s" % next_scene)
		return
	get_tree().change_scene_to_file(next_scene)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://ui/MainMenu.tscn")
