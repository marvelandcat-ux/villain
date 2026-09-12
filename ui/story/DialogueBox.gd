class_name DialogueBox
extends Control

## 스토리 모드 대화창 — **화면 아래 큰 반투명 회색 대사창 + 그 위 왼쪽 작은 이름창.**
##
## (2026-09-12 사용자가 러프로 정한 "대화창 초기 형식". 러프에선 잘 보이라고 검정으로 칠했지만 실제는 반투명 회색)
## 이름창은 대사창과 **확 구분**되게(사용자 요청): 더 짙고 덜 투명 + 왼쪽 노란 강조 줄 + 옅은 노란 이름 글자,
## 두 창 사이 6px 틈, 대사창 위쪽엔 얇은 밝은 선. 글꼴은 나눔고딕(`fonts/NanumGothic-Regular.ttf`)
## 장면마다 이 씬(DialogueBox.tscn)을 인스턴스로 올리고 `speaker` / `lines`만 채우면 된다.
##  - 대사는 **한 글자씩 타다닥 찍힌다**(`chars_per_second`). 문장부호 뒤에선 잠깐 쉰다(`punct_pause`)
##  - **스페이스바 또는 마우스 좌·우 클릭**으로 넘긴다(사용자 지정, 휠 제외). 찍히는 중에 누르면 그 대사를 한 번에 다 보여주고,
##    다 나온 뒤 누르면 다음 줄. 줄이 다 떨어지면 `finished`
##  - 대사 앞에 "이름|" 을 붙이면 그 대사부터 말하는 사람이 바뀐다 (예: "민원인|저기요...") — 이후 대사도 그 이름을 이어 쓴다
##  - 말하는 사람이 비어 있으면 이름창을 숨긴다(내레이션)
##  - `center_speakers`(기본 ["나레이션"])에 든 이름으로 말하면 대사를 가운데 맞춤하고 **괄호를 자동으로 씌운다**
##  - StoryFadeScene의 `dialogue`에 이 노드를 지정하면, 대사를 다 넘겨야 다음 장면으로 넘어간다
##  - 대화창이 아직 나타나는 중(StoryFadeScene.reveal로 투명)이면 글자도 안 찍고 스페이스도 안 받는다
##
## **명령 줄**: "@"로 시작하는 줄은 대사가 아니라 명령이다 — 스페이스 없이 **차례로** 실행한다.
## 시간이 걸리는 명령은 그 연출이 끝난 뒤 다음 줄로 간다. 대화창을 끊지 않고 같은 장면 안에서 화면을 바꿀 때 쓴다.
##  - "@show 노드 [초]"  : 그 노드를 서서히 나타나게(기본 0.4초)
##  - "@enter 노드 [초] [px]" : 서서히 나타나면서 아래에서 살짝 올라옴(기본 0.35초, 18px) — 인물이 등장할 때
##  - "@hide 노드 [초]"  : 서서히 사라지게(기본 0.4초)
##  - "@exit 노드 [초] [px]" : 옆으로 미끄러지며 사라짐(기본 0.45초, 오른쪽 420px, 점점 빨라짐 — 도망가는 느낌).
##                          음수 px면 왼쪽으로. 사라진 뒤 원래 자리로 되돌려 놓아서 나중에 다시 등장시킬 수 있다
##  - "@close [초]"      : 대화창을 서서히 없앤다(기본 0.3초). 뒤에 줄이 없으면 대화 끝, 뒤에 대사가 오면 대화창이 다시 나타난다
##  - "@waitkey"         : 스페이스나 클릭을 할 때까지 기다린다 — 대화창이 닫혀 있어도 받는다
##  - "@pause 초"        : 그만큼 가만히 기다린다
##  - "@stamp 노드 [초]" : 도장 쾅 — 크게(2.3배) 살짝 더 돌아간 채 나타나 [초](기본 0.14초) 만에 제자리로 줄며 찍히고,
##                         찍히는 순간 그 노드의 **부모**(보통 종이)가 짧게 흔들린다. 노드는 Node2D(Sprite2D)여야 한다
##  노드는 대화창의 부모(장면 루트) 기준 경로. 연출이 도는 동안은 글자도 안 찍고 스페이스도 안 받는다

## 모든 줄을 다 넘겼을 때
signal finished
## 대사가 바뀔 때마다 (index = 지금 보이는 줄 번호)
signal line_changed(index: int)

## 처음 말하는 사람 이름 (이름창에 들어감)
@export var speaker: String = ""
## 대사 목록. "이름|대사" 형식이면 그 줄부터 말하는 사람이 바뀐다. "@"로 시작하면 명령(위 설명)
@export var lines: PackedStringArray = PackedStringArray()
## 글자가 찍히는 빠르기(글자/초). 0이면 한 번에 다 나온다
@export var chars_per_second: float = 28.0
## 문장부호(. , ! ? … ~) 뒤에 더 쉬는 시간(초) — "첫날인가..." 같은 말줄임이 한 박자씩 찍힌다
@export var punct_pause: float = 0.12
## 모든 대사를 대사창 가운데(가로·세로)에 놓는다. 보통은 끄고, 아래 center_speakers로 나레이션만 가운데 맞춤한다
@export var center_text: bool = false
## 이 이름으로 말할 때만 가운데 맞춤 — 지문(나레이션)은 가운데, 인물 대사는 왼쪽 정렬(사용자 요청)
@export var center_speakers: PackedStringArray = PackedStringArray(["나레이션"])

## 명령이 돌려주는 값: 바로 다음 줄로 / 스페이스를 기다림 (양수면 그 시간 기다린 뒤 다음 줄로)
const _CMD_NEXT: float = -1.0
const _CMD_KEY: float = -2.0

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
## 명령 연출이 끝날 때까지 남은 시간(초)과, 끝나면 다음 줄로 넘어갈지
var _wait: float = 0.0
var _resume: bool = false
## @waitkey — 스페이스를 기다리는 중
var _waiting_key: bool = false

func _ready() -> void:
	# 글자가 늘어나는 동안 줄바꿈 위치가 흔들리지 않게 — 줄 배치는 대사 전체로 먼저 정하고 글자만 가린다
	_text_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_current_speaker = speaker
	_goto(0)

func is_finished() -> bool:
	return _finished or lines.is_empty()

## 지금 대사가 아직 찍히는 중인지
func is_typing() -> bool:
	return _shown < _total

## 스페이스바나 클릭 한 번 — 찍히는 중이면 이 대사를 다 보여주고, 다 나왔으면 다음 줄로
func advance() -> void:
	if is_finished():
		return
	if _waiting_key:
		_waiting_key = false
		_goto(_index + 1)
		return
	if _wait > 0.0:
		return
	if is_typing():
		_reveal_all()
		return
	_goto(_index + 1)

## i번째 줄부터 진행한다. 대사 줄을 만나면 보여주고 멈추고, 명령 줄은 실행한다. 줄이 다 떨어지면 끝
func _goto(i: int) -> void:
	_index = i
	while _index < lines.size():
		var raw: String = lines[_index].strip_edges()
		if not raw.begins_with("@"):
			_show_line()
			line_changed.emit(_index)
			return
		var r: float = _run_command(raw.substr(1))
		if r == _CMD_KEY:
			_waiting_key = true
			return
		if r > 0.0:
			_wait = r
			_resume = true
			return
		_index += 1
	_finished = true
	finished.emit()

## 명령 하나 실행. _CMD_NEXT = 바로 다음 줄, _CMD_KEY = 스페이스 기다림, 양수 = 그 시간 뒤 다음 줄
func _run_command(cmd: String) -> float:
	var parts: PackedStringArray = cmd.strip_edges().split(" ", false)
	if parts.is_empty():
		return _CMD_NEXT
	var op: String = parts[0]
	match op:
		"waitkey":
			return _CMD_KEY
		"pause":
			return maxf(parts[1].to_float() if parts.size() > 1 else 0.5, 0.01)
		"close":
			var t: float = maxf(parts[1].to_float() if parts.size() > 1 else 0.3, 0.01)
			var tw: Tween = create_tween()
			tw.tween_property(self, "modulate:a", 0.0, t)
			tw.tween_callback(hide)
			return t
		"show", "hide", "stamp", "enter", "exit":
			if parts.size() < 2:
				push_warning("DialogueBox: @%s 뒤에 노드 이름이 없다" % op)
				return _CMD_NEXT
			var target: CanvasItem = get_parent().get_node_or_null(NodePath(parts[1])) as CanvasItem
			if target == null:
				push_warning("DialogueBox: @%s 할 노드를 못 찾았다 — %s" % [op, parts[1]])
				return _CMD_NEXT
			if op == "stamp":
				var node2d: Node2D = target as Node2D
				if node2d == null:
					push_warning("DialogueBox: @stamp는 Node2D(Sprite2D)만 된다 — %s" % parts[1])
					return _CMD_NEXT
				var st: float = maxf(parts[2].to_float() if parts.size() > 2 else 0.14, 0.01)
				_stamp(node2d, st)
				return st + 0.3
			if op == "exit":
				# 옆으로 미끄러지며 사라진다 — 점점 빨라져서 뛰어 도망가는 느낌
				var xt: float = maxf(parts[2].to_float() if parts.size() > 2 else 0.45, 0.01)
				var dist: float = parts[3].to_float() if parts.size() > 3 else 420.0
				var spot: Vector2 = target.get("position")
				var xtw: Tween = create_tween().set_parallel(true)
				xtw.tween_property(target, "position", spot + Vector2(dist, 0.0), xt).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				xtw.tween_property(target, "modulate:a", 0.0, xt)
				xtw.chain().tween_callback(_hide_and_reset.bind(target, spot))
				return xt
			if op == "enter":
				# 인물 등장 — 서서히 나타나면서 아래에서 살짝 올라온다(경찰서 장면 등장과 같은 느낌)
				var et: float = maxf(parts[2].to_float() if parts.size() > 2 else 0.35, 0.01)
				var rise: float = parts[3].to_float() if parts.size() > 3 else 18.0
				var home: Vector2 = target.get("position")
				target.set("position", home + Vector2(0.0, rise))
				target.modulate.a = 0.0
				target.visible = true
				var etw: Tween = create_tween().set_parallel(true)
				etw.tween_property(target, "modulate:a", 1.0, et)
				etw.tween_property(target, "position", home, et).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				return et
			var t2: float = maxf(parts[2].to_float() if parts.size() > 2 else 0.4, 0.01)
			var tw2: Tween = create_tween()
			if op == "show":
				target.modulate.a = 0.0
				target.visible = true
				tw2.tween_property(target, "modulate:a", 1.0, t2)
			else:
				tw2.tween_property(target, "modulate:a", 0.0, t2)
				tw2.tween_callback(target.hide)
			return t2
	push_warning("DialogueBox: 모르는 명령 — @%s" % cmd)
	return _CMD_NEXT

## @exit로 나간 뒤 정리 — 숨기고 원래 자리·불투명도로 되돌린다(나중에 다시 등장시킬 수 있게)
func _hide_and_reset(target: CanvasItem, spot: Vector2) -> void:
	target.visible = false
	target.set("position", spot)
	target.modulate.a = 1.0


## 도장 쾅 — 씬에 놓아 둔 크기·각도가 최종 모습이다. 크게 살짝 더 돌아간 채 나타나 빠르게(가속하며) 줄어 찍히고 부모가 흔들린다
func _stamp(target: Node2D, t: float) -> void:
	var end_scale: Vector2 = target.scale
	var end_rot: float = target.rotation
	target.scale = end_scale * 2.3
	target.rotation = end_rot - deg_to_rad(10.0)
	target.modulate.a = 0.0
	target.visible = true
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(target, "scale", end_scale, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(target, "rotation", end_rot, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(target, "modulate:a", 1.0, t * 0.5)
	tw.chain().tween_callback(_shake.bind(target.get_parent(), 9.0, 0.28))

## 짧게 흔들기 — 점점 약해지다 제자리로
func _shake(node: Node, strength: float, time: float) -> void:
	if not (node is Control or node is Node2D):
		return
	var base: Vector2 = node.get("position")
	var steps: int = 7
	var tw: Tween = create_tween()
	for k in steps:
		var s: float = strength * (1.0 - float(k) / steps)
		tw.tween_property(node, "position", base + Vector2(randf_range(-s, s), randf_range(-s, s)), time / (steps + 1))
	tw.tween_property(node, "position", base, time / (steps + 1))

func _show_line() -> void:
	if not visible:
		# @close로 닫혔다가 다시 대사가 오면 대화창을 다시 띄운다 (다 나타난 뒤부터 글자가 찍힌다)
		visible = true
		create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
	var text: String = lines[_index] if _index < lines.size() else ""
	var bar: int = text.find("|")
	if bar >= 0:
		_current_speaker = text.substr(0, bar).strip_edges()
		text = text.substr(bar + 1).strip_edges()
	var centered: bool = center_text or _current_speaker in center_speakers
	if _current_speaker in center_speakers and text != "" and not text.begins_with("("):
		text = "(%s)" % text   # 나레이션(지문)은 무조건 괄호로 감싼다(사용자 지정) — 대사 목록에 괄호를 안 써도 된다
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER if centered else VERTICAL_ALIGNMENT_TOP
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
		if _wait <= 0.0 and _resume:
			_resume = false
			_goto(_index + 1)
		return   # 연출이 끝난 뒤에 다음 줄로 / 글자를 찍는다
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
	# 스페이스바 또는 마우스 좌·우 클릭으로 넘긴다(사용자 지정). 꾹 누를 때 반복 입력(echo)과 휠은 무시
	var pressed: bool = false
	if event is InputEventKey:
		var key: InputEventKey = event
		pressed = key.pressed and not key.echo and (key.keycode == KEY_SPACE or key.physical_keycode == KEY_SPACE)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		pressed = mb.pressed and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT)
	if not pressed:
		return
	if _waiting_key:
		get_viewport().set_input_as_handled()   # @waitkey(도장 찍기 전 등)는 대화창이 닫혀 있어도 받는다
		advance()
		return
	if _wait > 0.0 or modulate.a < 0.99 or not is_visible_in_tree() or is_finished():
		return   # 나타나는 중·연출 중이면 안 넘긴다 — 보이지도 않는 대사를 넘겨버리지 않게
	advance()
	get_viewport().set_input_as_handled()
