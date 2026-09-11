class_name DialogueBox
extends Control

## 스토리 모드 대화창 — **화면 아래 큰 반투명 회색 대사창 + 그 위 왼쪽 작은 이름창.**
##
## (2026-09-12 사용자가 러프로 정한 "대화창 초기 형식". 러프에선 잘 보이라고 검정으로 칠했지만 실제는 반투명 회색)
## 이름창은 대사창과 **확 구분**되게(사용자 요청): 더 짙고 덜 투명 + 왼쪽 노란 강조 줄 + 옅은 노란 이름 글자,
## 두 창 사이 6px 틈, 대사창 위쪽엔 얇은 밝은 선. 글꼴은 나눔고딕(`fonts/NanumGothic-Regular.ttf`)
## 장면마다 이 씬(DialogueBox.tscn)을 인스턴스로 올리고 `speaker` / `lines`만 채우면 된다.
##  - 대사는 **한 글자씩 타다닥 찍힌다**(`chars_per_second`). 문장부호 뒤에선 잠깐 쉰다(`punct_pause`)
##  - **스페이스바로만** 넘긴다(사용자 지정). 찍히는 중에 누르면 그 대사를 한 번에 다 보여주고,
##    다 나온 뒤 누르면 다음 대사. 마지막 대사에서 한 번 더 넘기면 `finished`
##  - 대사 앞에 "이름|" 을 붙이면 그 대사부터 말하는 사람이 바뀐다 (예: "민원인|저기요...") — 이후 대사도 그 이름을 이어 쓴다
##  - 말하는 사람이 비어 있으면 이름창을 숨긴다(내레이션)
##  - StoryFadeScene의 `dialogue`에 이 노드를 지정하면, 대사를 다 넘겨야 다음 장면으로 넘어간다
##  - 대화창이 아직 나타나는 중(StoryFadeScene.reveal로 투명)이면 글자도 안 찍고 스페이스도 안 받는다

## 모든 대사를 다 넘겼을 때
signal finished
## 대사가 바뀔 때마다 (index = 지금 보이는 대사 번호)
signal line_changed(index: int)

## 처음 말하는 사람 이름 (이름창에 들어감)
@export var speaker: String = ""
## 대사 목록. "이름|대사" 형식이면 그 줄부터 말하는 사람이 바뀐다
@export var lines: PackedStringArray = PackedStringArray()
## 글자가 찍히는 빠르기(글자/초). 0이면 한 번에 다 나온다
@export var chars_per_second: float = 28.0
## 문장부호(. , ! ? … ~) 뒤에 더 쉬는 시간(초) — "첫날인가..." 같은 말줄임이 한 박자씩 찍힌다
@export var punct_pause: float = 0.12

@onready var _name_panel: Control = $NamePanel
@onready var _name_label: Label = $NamePanel/NameLabel
@onready var _text_label: Label = $TextPanel/TextLabel

var _index: int = 0
var _current_speaker: String = ""
var _finished: bool = false
## 지금 대사에서 찍힌 글자 수 / 전체 글자 수
var _shown: int = 0
var _total: int = 0
var _char_timer: float = 0.0

func _ready() -> void:
	# 글자가 늘어나는 동안 줄바꿈 위치가 흔들리지 않게 — 줄 배치는 대사 전체로 먼저 정하고 글자만 가린다
	_text_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_current_speaker = speaker
	_show_line()

func is_finished() -> bool:
	return _finished or lines.is_empty()

## 지금 대사가 아직 찍히는 중인지
func is_typing() -> bool:
	return _shown < _total

## 스페이스바 한 번 — 찍히는 중이면 이 대사를 다 보여주고, 다 나왔으면 다음 대사로.
## 마지막 대사 다음이면 finished를 한 번 보내고 마지막 대사를 그대로 둔다
func advance() -> void:
	if is_finished():
		return
	if is_typing():
		_reveal_all()
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
	_total = text.length()
	_shown = 0
	_char_timer = 0.0
	if chars_per_second <= 0.0:
		_reveal_all()
	else:
		_text_label.visible_characters = 0

func _reveal_all() -> void:
	_shown = _total
	_text_label.visible_characters = -1

func _process(delta: float) -> void:
	if not is_typing() or modulate.a < 0.99 or not is_visible_in_tree():
		return   # 대화창이 다 나타난 뒤부터 찍는다
	_char_timer -= delta
	while _char_timer <= 0.0 and _shown < _total:
		_shown += 1
		var ch: String = _text_label.text[_shown - 1]
		_char_timer += 1.0 / chars_per_second
		if ch in ".,!?…~":
			_char_timer += punct_pause
	_text_label.visible_characters = -1 if _shown >= _total else _shown

func _unhandled_input(event: InputEvent) -> void:
	# 대사는 스페이스바로만 넘긴다(사용자 지정 — 클릭·엔터로는 안 넘어감). 꾹 누를 때 반복 입력(echo)은 무시
	if not (event is InputEventKey):
		return
	if modulate.a < 0.99 or not is_visible_in_tree():
		return   # 아직 나타나는 중(StoryFadeScene.reveal)이면 안 넘긴다 — 보이지도 않는 대사를 넘겨버리지 않게
	var key: InputEventKey = event
	if key.pressed and not key.echo and (key.keycode == KEY_SPACE or key.physical_keycode == KEY_SPACE) and not is_finished():
		advance()
		get_viewport().set_input_as_handled()
