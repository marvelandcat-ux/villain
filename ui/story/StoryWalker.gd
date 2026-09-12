class_name StoryWalker
extends Sprite2D

## 스토리 장면 속 걸어가는 사람 한 명 — **그림 한 장을 걷는 방향으로 천천히 조금만 밀어준다.**
##
## 다리 동작이 없는 한 장짜리 그림이라, 실제 걷는 속도(그림 속 사람 키 300px 기준 1초에 200px 넘게)로 밀면
## 종이 인형이 미끄러지는 것처럼 보인다. 그래서 장면 내내 수십 px만 움직여 "사람들이 오가는 느낌"만 낸다.
## 원본 그림이 이미 모션 블러로 흐려서, 흐린 사람일수록 더 많이 움직여도 티가 안 난다.
## (2026-09-12) 처음엔 발걸음 박자로 들썩이고(`bob`) 좌우로 기울게(`sway_deg`) 했는데, 사용자가 "흔들리는 게 아니라
## 약간만 앞으로 가게"를 원해서 기본값을 0으로 바꿨다 — 통짜 그림이 들썩이면 오히려 종이 인형 티가 난다. 값을 주면 다시 켜진다
##
## 노드 위치 = 발 밑(`offset`으로 그림을 맞춰 둠). 그래서 `grow`(멀어질수록 작아짐)와 흔들림이 발을 기준으로 일어난다.
## `walk_time`이 지나면 마지막 `stop_time` 동안 서서히 멈춘다 — 장면이 끝나지 않고 계속 보이는 경우
## 사람이 화면 밖이나 잘린 단면까지 끝없이 가지 않게.
## 에디터에선 안 움직인다(@tool 아님) — 배치는 에디터에서, 움직임은 실행해서 본다.

## walk_time 동안 움직일 총 거리(그림 픽셀). 위(-y)가 화면 안쪽으로 멀어지는 방향
@export var walk: Vector2 = Vector2(0, -20)
## 다 걷는 데 걸리는 시간(초)
@export var walk_time: float = 8.0
## 마지막에 서서히 멈추는 시간(초)
@export var stop_time: float = 1.5
## walk_time 동안의 크기 변화 비율. -0.03이면 3% 작아진다(멀어지는 사람), +면 커진다(다가오는 사람)
@export var grow: float = 0.0
## 발걸음마다 들썩이는 높이(px). 0이면 안 들썩인다(기본 — 위 설명 참고)
@export var bob: float = 0.0
## 1초에 내딛는 걸음 수 (bob·sway_deg를 켤 때만 의미 있음)
@export var steps_per_second: float = 1.8
## 걸음 따라 좌우로 기우는 최대 각도(도). 0이면 안 기운다(기본)
@export var sway_deg: float = 0.0
## 사람마다 발 박자를 어긋나게 하는 값(0~1 걸음) — 다 같이 들썩이면 행진처럼 보인다
@export var phase: float = 0.0

var _start_pos: Vector2
var _start_scale: Vector2
var _t: float = 0.0

func _ready() -> void:
	_start_pos = position
	_start_scale = scale

func _process(delta: float) -> void:
	_t += delta
	var f: float = _progress(_t)
	var k: float = _speed_factor(_t)   # 1 = 걷는 중, 멈추는 동안 0으로
	var step: float = (_t * steps_per_second + phase) * PI   # 걸음 하나 = 반주기
	position = _start_pos + walk * f + Vector2(0.0, -absf(sin(step)) * bob * k)
	rotation = deg_to_rad(sway_deg) * sin(step) * k
	scale = _start_scale * (1.0 + grow * f)

## 0~1 — 같은 속도로 가다가 마지막 stop_time 동안 속도가 0까지 줄어든다
func _progress(t: float) -> float:
	var total: float = maxf(walk_time, 0.01)
	var d: float = clampf(stop_time, 0.0, total)
	var v0: float = 1.0 / (total - d * 0.5)
	if t >= total:
		return 1.0
	if t <= total - d:
		return v0 * t
	var tau: float = t - (total - d)
	return v0 * (total - d) + v0 * (tau - tau * tau / (2.0 * d))

func _speed_factor(t: float) -> float:
	var total: float = maxf(walk_time, 0.01)
	var d: float = clampf(stop_time, 0.0, total)
	if t >= total:
		return 0.0
	if t <= total - d:
		return 1.0
	return 1.0 - (t - (total - d)) / d
