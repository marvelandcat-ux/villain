class_name ContinueIndicator
extends Control

## "계속하려면 누르세요" 를 알려주는 **깜빡이는 아래 화살표(▼)**.
##
## (2026-09-15 멘토 피드백) 첫 컷신에서 **눌러야 넘어간다는 걸 모른다**는 지적을 받아서 넣었다.
## 사건 파일 화면처럼 대화창이 닫혀 있는 구간에서도 떠야 해서, 대화창 안이 아니라 **따로 노는 노드**다.
##
## **애셋을 안 쓴다** — `_draw()`로 삼각형을 그린다. 그래서 화풍에 종속되지 않고, 세피아 서류 위에서도
## 컬러 인게임 위에서도 같은 값으로 읽힌다(작업 브리프 원칙 B: "UI 표시물은 제3의 레이어").
## **색을 화면마다 다르게 바꾸지 말 것** — 어두운 외곽선 + 밝은 단색이라 어느 배경에서도 묻히지 않게 잡은 값이다.
##
## 입력은 **받지 않는다**(`MOUSE_FILTER_IGNORE`). 넘기는 처리는 이미 `DialogueBox._unhandled_input`이
## 하고 있어서, 여기서 또 받으면 한 번 눌렀는데 두 줄이 넘어간다. 이 노드는 **보여주기만** 한다.
##
## `watch`에 대화창(또는 `is_waiting_input()`을 가진 아무 노드)을 지정하면 그게 입력을 기다리는 동안에만
## 나타난다. 스토리 장면은 `StoryFadeScene`이 자동으로 하나 붙이고 연결해 준다.
##
## **대사 줄마다 뜨지는 않는다**(`only_when_dialogue_hidden`, 2026-09-16 사용자 요청 — "상시로 있으니 어지럽다").
## **대화창이 닫힌 채 기다리는 구간에서만** 뜬다. 대화창이 떠 있으면 그 창 자체가 "뭔가 진행 중"이라는
## 신호라서 화살표가 잔소리가 되고, 반대로 창이 닫힌 사건 파일 화면에서는 **아무 단서도 없어서**
## 처음 하는 사람이 멈춘다 — 멘토가 지적한 게 정확히 그 화면이다.
## 지금 그런 구간은 `@waitkey`를 쓰는 사건 파일 둘뿐이다(수사 착수 / 사건 해결).
##
## **화살표 옆 글씨("스페이스 또는 클릭")는 처음 한 번만 보여준다.** 멘토 지적의 원문이
## "클릭해야 하는 걸 모름"이라 화살표만으로는 *무슨 동작*인지 안 알려주는데, 그렇다고 대사 줄마다
## 박아 두면 화면이 지저분해진다. 그래서 **플레이어가 한 번 넘기는 순간 사라지고 다시 안 나온다**.
## 본 적 있는지는 `GameState.dialogue_hint_seen`(user://settings.cfg)에 남아서 껐다 켜도 유지된다.

## 이 노드가 지켜볼 대상 — `is_waiting_input() -> bool` 을 가진 노드(보통 DialogueBox)
@export var watch: NodePath
## 켜면 **지켜보는 대화창이 화면에 안 보일 때만** 화살표를 띄운다.
## 끄면 대사 줄마다 뜬다(어지럽다는 피드백이 있어서 기본값은 켬)
@export var only_when_dialogue_hidden: bool = true

@export_group("모양")
## 화살표 크기(px)
@export var arrow_size: Vector2 = Vector2(30.0, 18.0):
	set(value):
		arrow_size = value
		queue_redraw()
## 안쪽 색과 외곽선 색·두께
@export var fill_color: Color = Color(1.0, 0.96, 0.88):
	set(value):
		fill_color = value
		queue_redraw()
@export var outline_color: Color = Color(0.12, 0.09, 0.07):
	set(value):
		outline_color = value
		queue_redraw()
@export var outline_width: float = 4.0:
	set(value):
		outline_width = value
		queue_redraw()

@export_group("첫 안내 글씨")
## 처음 한 번만 화살표 옆에 띄울 글씨. 비우면 안 띄운다.
## **대사를 넘기는 입력을 그대로 적을 것** — 지금은 스페이스/Z/X/좌·우클릭이 다 먹는다(DialogueBox.ADVANCE_KEYS)
@export var hint_text: String = "스페이스 또는 클릭"
@export var hint_font_size: int = 18
## 글씨가 화살표에서 왼쪽으로 떨어지는 거리(px)
@export var hint_gap: float = 14.0
## 첫 입력 뒤 글씨가 사라지는 데 걸리는 시간(초)
@export var hint_fade_time: float = 0.45

@export_group("깜빡임")
## 한 번 깜빡이는 데 걸리는 시간(초)
@export var blink_period: float = 0.9
## 가장 옅을 때의 투명도 (1.0이 가장 진하다)
@export_range(0.0, 1.0, 0.05) var blink_min_alpha: float = 0.3
## 깜빡이면서 위아래로 움직이는 거리(px). 움직임이 있어야 "누르라는 신호"로 읽힌다
@export var bob: float = 5.0
## 나타나고 사라지는 데 걸리는 시간(초)
@export var fade_time: float = 0.18

var _target: Node = null
var _time: float = 0.0
## 지금 보여야 하는 상태인지와, 실제로 얼마나 나타나 있는지(0~1)
var _armed: bool = false
var _shown: float = 0.0
## 깜빡임에 맞춰 아래로 내려가 있는 정도(px). **자리를 옮기지 않고 그림만 내려 그린다** —
## 앵커가 걸린 Control의 position을 매 프레임 건드리면 레이아웃과 싸운다
var _bob_offset: float = 0.0
## 화살표가 지금 얼마나 진한지(0~1). **노드의 modulate를 안 쓰는 이유**: modulate는 자식(안내 글씨)까지
## 같이 먹어서 글씨도 같이 깜빡인다. 화살표만 깜빡이고 글씨는 잔잔해야 읽힌다
var _arrow_alpha: float = 0.0
## 안내 글씨 — 처음 한 번만 뜬다. 다 봤으면 아예 안 만든다
var _hint: Label = null
var _hint_fade_left: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # 클릭은 대화창이 받아야 한다
	_target = get_node_or_null(watch)
	_build_hint()

## 처음 하는 사람에게만 보여줄 안내 글씨. 이미 본 적 있으면 만들지도 않는다.
## 화살표 **왼쪽**에 놓는다 — 오른쪽은 화면 끝이라 자리가 없다
func _build_hint() -> void:
	if hint_text.is_empty() or GameState.dialogue_hint_seen:
		return
	_hint = Label.new()
	_hint.text = hint_text
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_size_override("font_size", hint_font_size)
	_hint.add_theme_color_override("font_color", fill_color)
	_hint.add_theme_color_override("font_outline_color", outline_color)
	_hint.add_theme_constant_override("outline_size", int(outline_width) * 2)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 화살표 왼쪽으로 뻗어 나가게 — 오른쪽 끝을 화살표 왼쪽 변에 붙이고 왼쪽으로 넓게 잡는다
	_hint.size = Vector2(300.0, arrow_size.y + 8.0)
	_hint.position = Vector2(-300.0 - hint_gap, -4.0)
	add_child(_hint)

## 대화창을 나중에 연결할 때 쓴다 (StoryFadeScene이 부른다)
func set_watch_target(node: Node) -> void:
	_target = node

## 지켜볼 대상 없이 직접 켜고 끌 때 쓴다
func arm() -> void:
	_armed = true

func _process(delta: float) -> void:
	_time += delta
	if _target and is_instance_valid(_target) and _target.has_method("is_waiting_input"):
		var waiting: bool = _target.is_waiting_input()
		# 대화창이 떠 있으면 그 창이 곧 단서다 — 화살표는 창이 닫힌 구간에만 남긴다
		if waiting and only_when_dialogue_hidden and _target is CanvasItem:
			waiting = not (_target as CanvasItem).visible
		# **기다리다가 넘어간 순간**이 "처음 눌러 봤다"는 뜻이다 — 그때 안내 글씨를 지운다
		if _armed and not waiting:
			_retire_hint()
		_armed = waiting
	_update_hint(delta)
	# 켜지고 꺼질 때 툭 끊기지 않게 한 번 더 완충한다
	var goal: float = 1.0 if _armed else 0.0
	_shown = move_toward(_shown, goal, delta / maxf(fade_time, 0.001))
	if _shown <= 0.0:
		if _arrow_alpha > 0.0:
			_arrow_alpha = 0.0
			queue_redraw()
		return
	# 0.5를 중심으로 오르내리는 깜빡임 — 완전히 사라졌다 나타나면 정신없어서 최저값을 둔다
	var pulse: float = 0.5 - 0.5 * cos(_time * TAU / maxf(blink_period, 0.01))
	_arrow_alpha = _shown * lerpf(blink_min_alpha, 1.0, pulse)
	_bob_offset = bob * pulse
	queue_redraw()

func _draw() -> void:
	if _arrow_alpha <= 0.0:
		return
	# 아래를 가리키는 삼각형. 원점이 화살표의 왼쪽 위 모서리다
	var points := PackedVector2Array([
		Vector2(0.0, _bob_offset),
		Vector2(arrow_size.x, _bob_offset),
		Vector2(arrow_size.x * 0.5, arrow_size.y + _bob_offset),
	])
	# 외곽선을 먼저 굵게 깔고 그 위에 안쪽 색을 얹는다 — 어느 배경에서도 형태가 살아난다
	var loop := points.duplicate()
	loop.append(points[0])
	draw_polyline(loop, Color(outline_color, outline_color.a * _arrow_alpha), outline_width, true)
	draw_colored_polygon(points, Color(fill_color, fill_color.a * _arrow_alpha))

## 첫 입력을 확인했으니 안내 글씨를 지우기 시작하고, 다시는 안 나오게 기록한다
func _retire_hint() -> void:
	if _hint == null or _hint_fade_left > 0.0:
		return
	_hint_fade_left = hint_fade_time
	GameState.mark_dialogue_hint_seen()

## 안내 글씨는 화살표와 따로 사그라든다 — 화살표는 계속 깜빡여야 하므로 알파를 같이 쓰면 안 된다
func _update_hint(delta: float) -> void:
	if _hint == null:
		return
	if _hint_fade_left <= 0.0:
		# 화살표가 보이는 만큼만 같이 보인다 (깜빡임은 안 따라가고 잔잔하게 둔다)
		_hint.modulate.a = _shown * 0.9
		return
	_hint_fade_left = maxf(_hint_fade_left - delta, 0.0)
	_hint.modulate.a = _shown * 0.9 * (_hint_fade_left / maxf(hint_fade_time, 0.001))
	if _hint_fade_left <= 0.0:
		_hint.queue_free()
		_hint = null
