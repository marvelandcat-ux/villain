class_name CutInAnimation
extends Node2D

## 궁극기 컷인 한 장면 — 그림 여러 장을 미리 그리는 대신, 파츠(머리/몸/손)를 코드로 흔들어서 애니메이션을 만든다.
## 자식으로 Head / Body / HandL / HandR 이름의 Sprite2D가 있으면 자동으로 찾아 쓴다(없는 건 그냥 건너뜀).
## Background(단색 판) / BackgroundImage(배경 그림)는 흔들지 않고 화면 확대만 같이 받는다.
##
## 흐름: 시작하면 떨림이 0에서 시작해 `ramp_time`에 걸쳐 최대치까지 점점 심해진다.
## 괴성은 여기서 지르지 않는다 — 컷인은 "참는 구간"이고, 실제로 지르는 건 화면 복귀 후 인게임 궁극기다.
##
## 파츠 위치는 씬에 저장된 값을 그대로 기억해뒀다가 거기서부터 흔들기 때문에,
## 에디터에서 배치를 바꿔도 이 스크립트는 손댈 필요가 없다.

## 가장 심할 때 떨리는 크기(px)
@export var shake_max: float = 6.0
## 1초에 떠는 횟수 — 30 정도면 "덜덜" 떠는 느낌
@export var shake_speed: float = 30.0
## 떨림이 0에서 최대까지 커지는 데 걸리는 시간(초). 컷인 길이와 맞추면 된다
@export var ramp_time: float = 1.0
## 끝까지 갔을 때 화면이 다가오는 정도 (0.12 = 12% 확대)
@export var zoom_in: float = 0.12
## 끝까지 갔을 때 얼굴이 붉어지는 세기 (0이면 안 붉어짐)
@export var red_tint: float = 0.45
## 손은 얼굴보다 더 심하게 떨리게 하는 배수
@export var hand_shake_scale: float = 1.6

@onready var _head: Sprite2D = get_node_or_null("Head")
@onready var _body: Sprite2D = get_node_or_null("Body")
@onready var _hand_l: Sprite2D = get_node_or_null("HandL")
@onready var _hand_r: Sprite2D = get_node_or_null("HandR")

var _time: float = 0.0
var _playing: bool = false
var _rest_positions: Dictionary = {}
var _rest_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	_rest_scale = scale
	for part in [_head, _body, _hand_l, _hand_r]:
		if part:
			_rest_positions[part] = part.position

## 컷인 재생을 시작한다 (연출 노드가 호출한다). 에디터에서 혼자 열어봤을 땐 가만히 서 있는다
func play() -> void:
	_time = 0.0
	_playing = true

func _process(delta: float) -> void:
	if not _playing:
		return
	_time += delta
	# 0 → 1 로 점점 커지는 세기. 뒤로 갈수록 급격해지게 제곱을 쓴다
	var intensity: float = clampf(_time / ramp_time, 0.0, 1.0)
	intensity *= intensity

	# 파츠마다 위상을 다르게 줘서 따로따로 덜덜 떨리게 한다
	_shake(_body, intensity, 0.0, 1.0)
	_shake(_head, intensity, 1.3, 1.0)
	_shake(_hand_l, intensity, 2.6, hand_shake_scale)
	_shake(_hand_r, intensity, 4.1, hand_shake_scale)

	# 화면 전체가 서서히 다가온다
	scale = _rest_scale * (1.0 + zoom_in * intensity)

	# 얼굴이 점점 붉어진다 (숨 참는 느낌)
	if _head:
		var red: float = red_tint * intensity
		_head.modulate = Color(1.0, 1.0 - red, 1.0 - red)

func _shake(part: Sprite2D, intensity: float, phase: float, scale_multiplier: float) -> void:
	if part == null:
		return
	var amount: float = shake_max * intensity * scale_multiplier
	var angle: float = _time * shake_speed * TAU
	# x와 y의 주기를 다르게 해서 같은 방향으로만 흔들리지 않게 한다
	var offset := Vector2(sin(angle + phase), sin(angle * 1.37 + phase * 2.0)) * amount
	part.position = _rest_positions[part] + offset
