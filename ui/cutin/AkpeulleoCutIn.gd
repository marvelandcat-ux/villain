class_name AkpeulleoCutIn
extends Node2D

## 악플러 궁극기 "실시간 급상승" 컷인.
## 그림 여러 장을 그리는 대신 파츠를 코드로 움직여서 한 장면 안에서 두 가지가 동시에 돌아간다.
##  - 왼쪽: 악플러 정면 얼굴과 몸(Portrait) — 낄낄대며 고개를 흔들고, 끝으로 갈수록 다가온다
##  - 그 양옆 손: 위아래로 번갈아 내려찍어 타자 치는 것처럼 보이게 하고, 눌리는 순간 타닥 효과선이 번쩍인다
##  - 노란 사선(MonitorLight): 화면 밖 아래에 모니터가 있는 것처럼 빛만으로 표현한다. 더하기 블렌드라 비추는 느낌이 난다
##  - 오른쪽: 댓글이 하나씩 실시간으로 쌓인다 (Comments/Comment0..)
##
## 진행 속도는 ramp_time에 맞춘다 — UltimateCutIn이 컷인 표시 시간(hold_time)을 여기에 넣어준다.
## 에디터에서 혼자 열어봤을 땐 가만히 있는다.

## 연출 전체 길이(초). UltimateCutIn이 자기 hold_time으로 덮어쓴다
@export var ramp_time: float = 1.0

@export_group("낄낄대는 얼굴")
## 고개가 좌우로 기우는 최대 각도(도)
@export var head_tilt_deg: float = 7.0
## 고개가 위아래로 들썩이는 폭(px)
@export var head_bob: float = 14.0
## 1초에 몇 번 들썩일지
@export var head_speed: float = 5.0
## 끝으로 갈수록 얼굴이 다가오는 정도 (0.15 = 15% 확대)
@export var head_zoom: float = 0.15
## 몸이 같이 들썩이는 정도 (얼굴 대비 비율). 어깨는 머리보다 덜 움직여야 자연스럽다
@export var body_bob_ratio: float = 0.35

@export_group("타자 치는 손")
## 손이 위아래로 움직이는 폭(px)
@export var type_stroke: float = 22.0
## 1초에 몇 번 두드릴지
@export var type_speed: float = 11.0

@export_group("모니터 빛")
## 빛이 깜빡이는 폭 (0이면 가만히 있는다)
@export_range(0.0, 0.5, 0.01) var light_flicker: float = 0.16
## 1초에 몇 번 깜빡일지
@export var light_speed: float = 17.0

@export_group("댓글창")
## 첫 댓글이 뜨는 시점 (전체 길이 대비 비율)
@export var comment_start: float = 0.08
## 마지막 댓글이 뜨는 시점 (전체 길이 대비 비율)
@export var comment_end: float = 0.78
## 댓글 하나가 튀어나오는 데 걸리는 시간 (전체 길이 대비 비율)
@export var comment_pop: float = 0.12
## 튀어나올 때 옆에서 밀려들어오는 거리(px)
@export var comment_slide: float = 46.0

@onready var _head: Sprite2D = get_node_or_null("BlurHead")
@onready var _body: Sprite2D = get_node_or_null("PortraitBody")
@onready var _comments: Node2D = get_node_or_null("Comments")
@onready var _monitor_light: Node2D = get_node_or_null("MonitorLight")

var _time: float = 0.0
var _playing: bool = false
## 씬에 저장돼 있던 제자리 값들 — 에디터에서 배치를 바꿔도 코드는 손댈 필요가 없다
var _rest_positions: Dictionary = {}
var _rest_head_scale: Vector2 = Vector2.ONE
var _comment_rows: Array[Node2D] = []
## 타자 치는 손과, 그 손이 눌릴 때 번쩍이는 효과선 (왼손/오른손 순서로 짝지어 둔다)
var _type_hands: Array[Sprite2D] = []
var _tap_marks: Array[Node2D] = []

func _ready() -> void:
	for part in [_head, _body]:
		if part:
			_rest_positions[part] = part.position
	if _head:
		_rest_head_scale = _head.scale
	for side in ["L", "R"]:
		var hand: Sprite2D = get_node_or_null("TypeHand%s" % side)
		if hand:
			_type_hands.append(hand)
			_rest_positions[hand] = hand.position
		_tap_marks.append(get_node_or_null("TapMark%s" % side))
	if _comments:
		for row in _comments.get_children():
			_comment_rows.append(row)
			_rest_positions[row] = row.position
	_reset_comments()

## 컷인 재생을 시작한다 (UltimateCutIn이 호출한다)
func play() -> void:
	_time = 0.0
	_playing = true
	_reset_comments()

## 댓글을 전부 숨겨서 아직 아무도 안 쓴 상태로 되돌린다
func _reset_comments() -> void:
	for row in _comment_rows:
		row.modulate.a = 0.0
		row.scale = Vector2(0.9, 0.9)

func _process(delta: float) -> void:
	if not _playing:
		return
	_time += delta
	var progress: float = clampf(_time / maxf(ramp_time, 0.001), 0.0, 1.0)
	_animate_portrait(progress)
	_animate_typing()
	_animate_light()
	_animate_comments(progress)

## 낄낄대는 느낌 — 고개를 좌우로 기울이며 위아래로 들썩이고, 뒤로 갈수록 얼굴이 다가온다
func _animate_portrait(progress: float) -> void:
	if _head == null:
		return
	var angle: float = _time * head_speed * TAU
	# 웃을 때 어깨가 들썩이듯 위로만 튀어오르게 절댓값을 쓴다 (위쪽이 음수)
	var bounce: float = -absf(sin(angle)) * head_bob
	_head.rotation = deg_to_rad(head_tilt_deg) * sin(angle * 0.5)
	_head.position = _rest_positions[_head] + Vector2(0.0, bounce)
	_head.scale = _rest_head_scale * (1.0 + head_zoom * progress)
	if _body:
		_body.position = _rest_positions[_body] + Vector2(0.0, bounce * body_bob_ratio)

## 두 손이 반 박자 엇갈려서 번갈아 내려찍는다. 가장 깊이 눌린 순간에만 타닥 효과선이 보인다
func _animate_typing() -> void:
	for i in range(_type_hands.size()):
		var hand: Sprite2D = _type_hands[i]
		var phase: float = _time * type_speed * TAU + PI * float(i)
		var press: float = maxf(sin(phase), 0.0)
		hand.position = _rest_positions[hand] + Vector2(0.0, press * type_stroke)
		var mark: Node2D = _tap_marks[i] if i < _tap_marks.size() else null
		if mark:
			# 0.6보다 깊이 눌렸을 때만 번쩍이게 잘라낸다 (계속 켜져 있으면 효과선처럼 안 보인다)
			mark.modulate.a = clampf((press - 0.6) * 2.5, 0.0, 1.0)

## 모니터 화면이 바뀌는 것처럼 빛이 미세하게 깜빡인다
func _animate_light() -> void:
	if _monitor_light == null:
		return
	_monitor_light.modulate.a = 1.0 - light_flicker + light_flicker * sin(_time * light_speed)

## 댓글이 하나씩 옆에서 밀려들어오며 뜬다
func _animate_comments(progress: float) -> void:
	var count: int = _comment_rows.size()
	if count == 0:
		return
	for i in range(count):
		var row: Node2D = _comment_rows[i]
		# 첫 댓글부터 마지막 댓글까지 시간을 고르게 나눠 갖는다
		var spawn_at: float = comment_start
		if count > 1:
			spawn_at = lerpf(comment_start, comment_end, float(i) / float(count - 1))
		var t: float = clampf((progress - spawn_at) / maxf(comment_pop, 0.001), 0.0, 1.0)
		# 끝으로 갈수록 느려지게 (툭 튀어나왔다 자리잡는 느낌)
		var eased: float = 1.0 - (1.0 - t) * (1.0 - t)
		row.modulate.a = eased
		row.scale = Vector2.ONE * lerpf(0.9, 1.0, eased)
		row.position = _rest_positions[row] + Vector2(comment_slide * (1.0 - eased), 0.0)
