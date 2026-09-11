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
##
## **명령 줄**: "@"로 시작하는 줄은 대사가 아니라 명령이다 — 스페이스 없이 바로 실행하고 다음 줄로 넘어간다.
## 대화창을 그대로 둔 채 같은 장면 안에서 화면을 바꿀 때 쓴다(장면을 바꾸면 대화창이 끊긴다).
##  - "@show 노드이름 [초]" : 장면의 그 노드를 서서히 나타나게(기본 0.4초). **다 나타난 뒤** 다음 대사를 찍는다
##  - "@hide 노드이름 [초]" : 서서히 사라지게(기본 0.4초)
##  - "@close [초]"         : 대화창을 서서히 없애고(기본 0.3초) 대화를 끝낸다(finished) — 그 뒤엔 화면만 남는다
##  노드이름은 대화창의 부모(장면 루트) 기준 경로. 연출이 도는 동안은 글자도 안 찍고 스페이스도 안 받는다

## 모든 대사를 다 넘겼을 때 (@close 포함)
signal finished
## 대사가 바뀔 때마다 (index = 지금 보이는 대사 번호)
signal line_changed(index: int)

## 처음 말하는 사람 이름 (이름창에 들어감)
@export var speaker: String = ""
## 대사 목록. "이름|대사" 형식이면 그 줄부터 말하는 사람이 바뀐다. "@"로 시작하면 명령(위 설명)
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
## 명령(@show 등) 연출이 끝날 때까지 남은 시간(초)
var _wait: float = 0.0

func _ready() -> void:
	# 글자가 늘어나는 동안 줄바꿈 위치가 흔들리지 않게 — 줄 배치는 대사 전체로 먼저 정하고 글자만 가린다
	_text_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_current_speaker = speaker
	_goto(0, false)

func is_finished() -> bool:
	return _finished or lines.is_empty()

## 지금 대사가 아직 찍히는 중인지
func is_typing() -> bool:
	return _shown < _total

## 스페이스바 한 번 — 찍히는 중이면 이 대사를 다 보여주고, 다 나왔으면 다음 줄로
func advance() -> void:
	if is_finished():
		return
	if is_typing():
		_reveal_all()
		return
	_goto(_index + 1, true)

## i번째 줄로 간다. 명령 줄은 실행하고 건너뛴다. 줄이 다 떨어지면 끝(마지막 대사는 그대로 둔다)
func _goto(i: int, notify: bool) -> void:
	var last_shown: int = _index
	_index = i
	while _index < lines.size() and lines[_index].strip_edges().begins_with("@"):
		if _run_command(lines[_index].strip_edges().substr(1)):
			return   # @close — 대화 끝
		_index += 1
	if _index >= lines.size():
		_index = last_shown
		_finished = true
		finished.emit()
		return
	_show_line()
	if notify:
		line_changed.emit(_index)

## 명령 하나 실행. 대화를 끝내는 명령(@close)이면 true
func _run_command(cmd: String) -> bool:
	var parts: PackedStringArray = cmd.strip_edges().split(" ", false)
	if parts.is_empty():
		return false
	var op: String = parts[0]
	if op == "close":
		var t: float = parts[1].to_float() if parts.size() > 1 else 0.3
		_finished = true
		var tw: Tween = create_tween()
		tw.tween_property(self, "modulate:a", 0.0, t)
		tw.tween_callback(hide)
		finished.emit()
		return true
	if op == "show" or op == "hide":
		if parts.size() < 2:
			push_warning("DialogueBox: @%s 뒤에 노드 이름이 없다" % op)
			return false
		var target: CanvasItem = get_parent().get_node_or_null(NodePath(parts[1])) as CanvasItem
		if target == null:
			push_warning("DialogueBox: @%s 할 노드를 못 찾았다 — %s" % [op, parts[1]])
			return false
		var t: float = parts[2].to_float() if parts.size() > 2 else 0.4
		var tw: Tween = create_tween()
		if op == "show":
			target.modulate.a = 0.0
			target.visible = true
			tw.tween_property(target, "modulate:a", 1.0, t)
		else:
			tw.tween_property(target, "modulate:a", 0.0, t)
			tw.tween_callback(target.hide)
		_wait = maxf(_wait, t)
		return false
	push_warning("DialogueBox: 모르는 명령 — @%s" % cmd)
	return false

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
	if _wait > 0.0:
		_wait -= delta
		return   # @show 같은 연출이 끝난 뒤에 찍는다
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
	if _wait > 0.0 or modulate.a < 0.99 or not is_visible_in_tree():
		return   # 나타나는 중·연출 중이면 안 넘긴다 — 보이지도 않는 대사를 넘겨버리지 않게
	var key: InputEventKey = event
	if key.pressed and not key.echo and (key.keycode == KEY_SPACE or key.physical_keycode == KEY_SPACE) and not is_finished():
		advance()
		get_viewport().set_input_as_handled()
