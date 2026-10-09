@tool
class_name PeekabooReveal
extends Node2D

## **까꿍** — 검은 비닐봉지를 뒤집어쓴 무언가를, 손이 쑥 들어와 **봉지를 아래로 확 내리면**
## 그 밑에 숨어 있던 악플러가 "단!" 하고 드러나는 연출 (2026-10-08 사용자 구상).
##
## 쌓는 순서: 들킨 악플러(밑) → 검은 비닐봉지(덮개) → 손.
## **봉지와 손은 같이 내려간다** — 손이 봉지를 쥐고 끌어내리는 것이라 따로 놀면 안 된다.
##
## 흐름(초):
##   `hand_in_at`  손이 화면 밖에서 들어온다
##   `pull_at`     봉지를 잡고 **쑥** 끌어내린다(`pull_time` 동안 `pull_px` 만큼)
##   `hand_out_at` 손만 마저 빠진다 — 봉지는 내려간 자리에 그대로 둔다
##
## 전부 인스펙터에서 만진다. 손이 들어오는 방향·거리도 `hand_from`으로 정한다.

const CANVAS := Vector2(1672.0, 941.0)

@export var fit_to_screen: bool = true

@export_group("자리")
## 봉지가 처음 놓인 자리(px). 원본 그대로면 (0, 0)
@export var bag_home: Vector2 = Vector2.ZERO:
	set(value):
		bag_home = value
		_lay_out()
## 손이 **다 들어왔을 때** 서는 자리(px)
@export var hand_home: Vector2 = Vector2(430.0, 250.0):
	set(value):
		hand_home = value
		_lay_out()
## 손 크기
@export var hand_scale: float = 1.0:
	set(value):
		hand_scale = value
		_lay_out()
## 손이 **숨어 있는 자리**를 `hand_home`에서 잰 거리(px). 화면 밖이어야 한다
@export var hand_from: Vector2 = Vector2(-520.0, 620.0):
	set(value):
		hand_from = value
		_lay_out()

@export_group("덜덜 떨림")
## 봉지가 걷히고 **몇 초 뒤부터** 떨기 시작하는지(`pull_at` 기준)
@export var shiver_from: float = 0.0
## 떨리는 폭(px). 가로·세로
@export var shiver_px: Vector2 = Vector2(3.2, 1.8)
## 떠는 속도(클수록 잘게 떤다)
@export var shiver_speed: float = 33.0
## **몸통만 더 떠는** 배수 — 얼굴보다 어깨가 더 흔들려야 "덜덜"로 읽힌다
@export var shiver_body_extra: float = 1.7
## 같이 흔들리는 각도(도)
@export var shiver_tilt: float = 0.5
## 떨림의 중심(원본 좌표 px) — 사람의 한가운데쯤
@export var guy_pivot: Vector2 = Vector2(792.0, 437.0):
	set(value):
		guy_pivot = value
		_lay_out()

@export_group("꺄악 비명")
## 입을 벌리기 시작하는 때(초)
@export var scream_at: float = 1.2
## 입이 다 벌어지는 데 걸리는 시간(초)
@export var scream_rise: float = 0.16
## 입이 벌어지는 **중심**(원본 좌표 px). 윗입술 자리를 잡아야 턱만 아래로 벌어진다
@export var mouth_pivot: Vector2 = Vector2(648.0, 252.0):
	set(value):
		mouth_pivot = value
		_lay_out()
## 다 벌렸을 때 세로·가로 배수
@export var mouth_open: float = 2.6
@export var mouth_wide: float = 1.3
## 소리 지르는 동안 입이 떠는 횟수(초당)와 그 폭
@export var mouth_wobble: float = 11.0
@export_range(0.0, 0.6, 0.01) var mouth_wobble_amount: float = 0.18

@export_group("박자")
## 손이 들어오기 시작하는 때(초)와 걸리는 시간
@export var hand_in_at: float = 0.35
@export var hand_in_time: float = 0.45
## 봉지를 끌어내리기 시작하는 때(초)와 걸리는 시간
@export var pull_at: float = 0.95
@export var pull_time: float = 0.22
## 끌어내리는 거리(px). 봉지가 화면 밖으로 빠질 만큼
@export var pull_px: float = 980.0
## 손이 빠지기 시작하는 때(초)와 걸리는 시간
@export var hand_out_at: float = 1.35
@export var hand_out_time: float = 0.35

@export_group("맞춰보기")
## 에디터에서 **이 시점의 모습**으로 세워 둔다(초). 자리를 맞출 때 쓴다
@export var preview_time: float = 0.0:
	set(value):
		preview_time = value
		_lay_out()

@onready var _guy: Node2D = $Guy
@onready var _guy_parts: Array[Node2D] = [$Guy/Head, $Guy/Lower, $Guy/Body]
@onready var _body: Sprite2D = $Guy/Body
@onready var _mouth: Node2D = $Guy/MouthPivot
@onready var _mouth_sprite: Sprite2D = $Guy/MouthPivot/Mouth
@onready var _bag: Sprite2D = $Bag
@onready var _hand: Sprite2D = $Hand

var _time: float = 0.0

func _ready() -> void:
	if fit_to_screen:
		_fit()
	if Engine.is_editor_hint():
		set_process(false)
	_lay_out()

func _fit() -> void:
	var screen: Vector2 = get_viewport_rect().size
	scale = Vector2.ONE * maxf(screen.x / CANVAS.x, screen.y / CANVAS.y)

func _process(delta: float) -> void:
	_time += delta
	_lay_out()

## 0~1로 올라가는 진행도. `at` 전이면 0, `at + span` 뒤면 1
func _phase(now: float, at: float, span: float) -> float:
	if span <= 0.0:
		return 1.0 if now >= at else 0.0
	return clampf((now - at) / span, 0.0, 1.0)

func _lay_out() -> void:
	if not is_node_ready():
		return
	var now: float = preview_time if Engine.is_editor_hint() else _time
	# 손: 밖 -> 제자리 -> (다 내린 뒤) 다시 밖
	var came: float = _phase(now, hand_in_at, hand_in_time)
	var left: float = _phase(now, hand_out_at, hand_out_time)
	var away: float = lerpf(1.0 - _ease(came), _ease(left), 1.0 if left > 0.0 else 0.0)
	# 봉지: 잡힌 뒤 아래로 쑥
	var pulled: float = _ease(_phase(now, pull_at, pull_time)) * pull_px
	_shiver(now)
	_scream(now)
	_bag.position = bag_home + Vector2(0.0, pulled)
	_hand.position = hand_home + hand_from * away + Vector2(0.0, pulled)
	_hand.scale = Vector2.ONE * hand_scale

## 시작은 빠르게, 끝은 부드럽게 — 쑥 당기는 맛이 난다
func _ease(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)

## 사람 전체가 잘게 떤다. **몸통은 더 크게** — 얼굴보다 어깨가 흔들려야 덜덜로 읽힌다.
## 회전 중심을 `guy_pivot`에 두고 조각들을 그만큼 되밀어, 떨지 않을 땐 원본 자리에 그대로 선다
func _shiver(now: float) -> void:
	_guy.position = guy_pivot
	for part in _guy_parts:
		part.position = -guy_pivot
	_mouth.position = mouth_pivot - guy_pivot
	_mouth_sprite.position = -mouth_pivot
	var on: float = 1.0 if now >= pull_at + shiver_from else 0.0
	if on <= 0.0:
		_guy.rotation = 0.0
		return
	# 가로·세로를 다른 박자로 흔들어야 한 방향으로 미끄러지지 않는다
	var dx: float = sin(now * shiver_speed) * shiver_px.x
	var dy: float = sin(now * shiver_speed * 1.37 + 1.1) * shiver_px.y
	_guy.position = guy_pivot + Vector2(dx, dy)
	_guy.rotation = deg_to_rad(shiver_tilt) * sin(now * shiver_speed * 0.83)
	var extra := Vector2(dx, dy) * (shiver_body_extra - 1.0)
	_body.position = -guy_pivot + extra

## 입을 **쫙 벌리고** 소리 지르는 동안 파르르 떤다. 한 번 벌리면 장면이 끝날 때까지 벌린 채다
func _scream(now: float) -> void:
	var t: float = now - scream_at
	if t < 0.0:
		_mouth.scale = Vector2.ONE
		return
	var open: float = clampf(t / maxf(scream_rise, 0.001), 0.0, 1.0)
	open = 1.0 - pow(1.0 - open, 3.0)
	var wob: float = 1.0 + sin(now * TAU * mouth_wobble) * mouth_wobble_amount * open
	_mouth.scale = Vector2(lerpf(1.0, mouth_wide, open), lerpf(1.0, mouth_open, open) * wob)
