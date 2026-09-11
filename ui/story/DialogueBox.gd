class_name DialogueBox
extends Control

## 스토리 모드 대화창 — **화면 아래 큰 반투명 회색 대사창 + 그 위 왼쪽 작은 이름창.**
##
## (2026-09-12 사용자가 러프로 정한 "대화창 초기 형식". 러프에선 잘 보이라고 검정으로 칠했지만 실제는 반투명 회색)
## 장면마다 이 씬(DialogueBox.tscn)을 인스턴스로 올리고 `speaker` / `lines`만 채우면 된다.
##  - **스페이스바로만** 다음 대사(사용자 지정). 마지막 대사에서 한 번 더 넘기면 `finished`
##  - 대사 앞에 "이름|" 을 붙이면 그 대사부터 말하는 사람이 바뀐다 (예: "민원인|저기요...") — 이후 대사도 그 이름을 이어 쓴다
##  - 말하는 사람이 비어 있으면 이름창을 숨긴다(내레이션)
##  - StoryFadeScene의 `dialogue`에 이 노드를 지정하면, 대사를 다 넘겨야 다음 장면으로 페이드아웃한다

## 모든 대사를 다 넘겼을 때
signal finished
## 대사가 바뀔 때마다 (index = 지금 보이는 대사 번호)
signal line_changed(index: int)

## 처음 말하는 사람 이름 (이름창에 들어감)
@export var speaker: String = ""
## 대사 목록. "이름|대사" 형식이면 그 줄부터 말하는 사람이 바뀐다
@export var lines: PackedStringArray = PackedStringArray()

@onready var _name_panel: Control = $NamePanel
@onready var _name_label: Label = $NamePanel/NameLabel
@onready var _text_label: Label = $TextPanel/TextLabel

var _index: int = 0
var _current_speaker: String = ""
var _finished: bool = false

func _ready() -> void:
	_current_speaker = speaker
	_show_line()

func is_finished() -> bool:
	return _finished or lines.is_empty()

## 다음 대사로. 마지막 대사 다음이면 finished를 한 번 보내고 마지막 대사를 그대로 둔다
func advance() -> void:
	if is_finished():
		return
	if _index + 1 >= lines.size():
		_finished = true
		finished.emit()
		return
	_index += 1
	_show_line()
	line_changed.emit(_index)

func _show_line() -> void:
	var text: String = lines[_index] if _index < lines.size() else ""
	var bar: int = text.find("|")
	if bar >= 0:
		_current_speaker = text.substr(0, bar).strip_edges()
		text = text.substr(bar + 1).strip_edges()
	_name_label.text = _current_speaker
	_name_panel.visible = _current_speaker != ""
	_text_label.text = text

func _unhandled_input(event: InputEvent) -> void:
	# 대사는 스페이스바로만 넘긴다(사용자 지정 — 클릭·엔터로는 안 넘어감). 꾹 누를 때 반복 입력(echo)은 무시
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event
	if key.pressed and not key.echo and (key.keycode == KEY_SPACE or key.physical_keycode == KEY_SPACE) and not is_finished():
		advance()
		get_viewport().set_input_as_handled()
