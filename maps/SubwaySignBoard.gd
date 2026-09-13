@tool
class_name SubwaySignBoard
extends Node2D

## 승강장 전광판 (순수 장식 — 판정 없음). 평소엔 안내 문구가 오른쪽에서 왼쪽으로 흐르고,
## **열차 경고등이 켜지면 빨간 글씨로 바뀌며 깜빡인다** — 열차가 온다는 걸 글자로도 알려준다.
##
## 판과 테두리는 `_draw()`로 그리고, **글자는 자식 `Clip/Text`(Label)가 그린다.**
## `Clip`(Control)의 `clip_contents`가 켜져 있어서 글자가 판 밖으로 삐져나오지 않는다 —
## `_draw()`만으로는 흐르는 글자를 잘라낼 방법이 없어서 이렇게 나눴다

## --- 판 ---
## 전광판 크기(px). 노드 위치가 판의 한가운데다
@export var board_size: Vector2 = Vector2(420.0, 44.0)
@export var board_color: Color = Color(0.05, 0.06, 0.08)
@export var frame_color: Color = Color(0.17, 0.18, 0.22)
## 테두리 두께(px)
@export var frame_width: float = 3.0

## --- 글자 ---
## 평소 문구 (뒤에 가운뎃점을 붙여 이어 흐르게 한다)
@export var normal_text: String = "다음 열차가 곧 도착합니다  ·  안전선 뒤로 물러나 주십시오  ·  "
## 열차가 올 때 문구
@export var alarm_text: String = "열차가 들어오고 있습니다"
@export var normal_color: Color = Color(1.0, 0.78, 0.28)
@export var alarm_color: Color = Color(1.0, 0.36, 0.3)
## 글자가 흐르는 속도(px/초)
@export var scroll_speed: float = 62.0
## 경고 중 글자가 깜빡이는 빠르기(초당 횟수)
@export var alarm_blink_speed: float = 2.5

var _alarm: bool = false
var _train: SubwayTrain = null

@onready var _clip: Control = get_node_or_null("Clip")
@onready var _text: Label = get_node_or_null("Clip/Text")

func _process(delta: float) -> void:
	if _clip == null or _text == null:
		return
	_clip.size = board_size
	_clip.position = -board_size * 0.5
	queue_redraw()
	if Engine.is_editor_hint():
		# 에디터에서는 흐르지 않고, 문구·색만 반영해서 위치를 눈으로 잡을 수 있게 한다
		_text.text = normal_text
		_text.modulate = normal_color
		_text.position = Vector2(0.0, 0.0)
		_text.size.y = board_size.y
		return
	var train: SubwayTrain = _find_train()
	var danger: bool = train != null and train.is_dangerous()
	if danger != _alarm:
		_alarm = danger
		_text.text = alarm_text if _alarm else normal_text
		_text.position.x = board_size.x if not _alarm else 0.0
	_text.size.y = board_size.y
	if _alarm:
		# 경고 중엔 흐르지 않고 가운데에서 깜빡인다 (읽어야 하는 문구라 흘리면 안 읽힌다)
		_text.size.x = board_size.x
		_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_text.position.x = 0.0
		var on: bool = sin(Time.get_ticks_msec() / 1000.0 * TAU * alarm_blink_speed) > -0.3
		_text.modulate = alarm_color if on else Color(alarm_color, 0.25)
	else:
		_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_text.size.x = _text.get_minimum_size().x
		_text.modulate = normal_color
		_text.position.x -= scroll_speed * delta
		# 글자가 판 왼쪽으로 다 빠져나가면 오른쪽 끝에서 다시 들어온다
		if _text.position.x < -_text.size.x:
			_text.position.x = board_size.x

## "subway_train" 그룹의 열차를 찾아 기억해둔다 (열차가 없는 맵이면 평소 문구만 계속 흐른다)
func _find_train() -> SubwayTrain:
	if not is_instance_valid(_train):
		_train = get_tree().get_first_node_in_group("subway_train") as SubwayTrain
	return _train

func _draw() -> void:
	var rect := Rect2(-board_size * 0.5, board_size)
	draw_rect(rect, board_color)
	draw_rect(rect, frame_color, false, frame_width)
	# 판 위쪽에 옅은 빛줄 하나 — 밋밋한 검은 사각형이 "전광판"으로 읽히게 한다
	draw_rect(Rect2(rect.position + Vector2(frame_width, frame_width), Vector2(board_size.x - frame_width * 2.0, 2.0)),
		Color(frame_color, 0.5))
