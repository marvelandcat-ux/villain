class_name GuardShield
extends Node2D

## 아래 키를 누른 순간 켜져서 1.2초 동안 캐릭터를 감싸는 반투명 원형 보호막.
## 켜져 있는 동안 들어오는 공격은 데미지·넉백이 전부 0이 된다 (Fighter.start_guard 참고).
## 그림 파일 없이 코드로 그린다 — 반투명 원 + 남은 시간만큼 줄어드는 밝은 테두리 + 미세한 맥동.
## Fighter의 자식으로 붙고, 원점이 곧 몸 중심이라 위치를 따로 맞출 필요가 없다.

## 보호막 반지름(px). 캐릭터 전체(발 y=+32 ~ 머리 위 y=-60, 약 92px)를 감싸는 크기
@export var radius: float = 47.0
## 원의 중심(캐릭터 원점 기준). 몸 원점은 허리 높이라, 머리까지 덮으려면 위로 올려야 한다.
## 캐릭터가 전부 같은 규격(머리 55x55, 전체 약 92px)이라 한 값으로 6명 모두 맞는다
@export var center: Vector2 = Vector2(0, -14)
## 안쪽을 채우는 색 (많이 투명해야 캐릭터가 비쳐 보인다)
@export var fill_color: Color = Color(0.45, 0.78, 1.0, 0.26)
## 테두리 색과 굵기
@export var edge_color: Color = Color(0.78, 0.94, 1.0, 0.85)
@export var edge_width: float = 2.5
## 켜지고 꺼지는 데 걸리는 시간(초)
@export var pop_time: float = 0.1
## 켜질 때 제 크기보다 얼마나 부풀었다 돌아오는지 (0.25 = 25% 더 커졌다 제자리)
@export var pop_overshoot: float = 0.25
## 켜져 있는 동안 크기가 미세하게 흔들리는 폭/속도
@export var pulse: float = 0.035
@export var pulse_speed: float = 6.0

## 지금 켜져 있어야 하는지 (Fighter가 매 프레임 알려준다)
var _active: bool = false
## 남은 시간 비율 (1=방금 켰다, 0=끝). 테두리가 시계처럼 줄어들어 언제 풀리는지 눈으로 보인다
var _remain: float = 1.0
## 0=완전히 꺼짐 ~ 1=완전히 켜짐. 툭 끊기지 않게 사이 값을 거친다
var _blend: float = 0.0
var _phase: float = 0.0

func _ready() -> void:
	z_index = 5   # 캐릭터(0)와 그 손(1)보다 앞 — 반투명이라 몸이 비쳐 보인다
	visible = false

## 방어 상태를 켜고 끈다. Fighter.start_guard()/cancel_guard()가 호출한다
func set_active(on: bool) -> void:
	_active = on

## 남은 시간 비율을 알려준다 (Fighter가 매 물리 프레임 갱신)
func set_remain(remain: float) -> void:
	_remain = clampf(remain, 0.0, 1.0)

func _process(delta: float) -> void:
	_blend = move_toward(_blend, 1.0 if _active else 0.0, delta / maxf(pop_time, 0.001))
	_phase += delta * pulse_speed
	visible = _blend > 0.001
	if visible:
		queue_redraw()

func _draw() -> void:
	if _blend <= 0.001:
		return
	# 켜지는 도중 한 번 부풀었다 제자리로 — sin이라 시작·끝에서는 0이라 튀지 않는다
	var pop: float = 1.0 + pop_overshoot * sin(_blend * PI)
	var r: float = radius * _blend * pop * (1.0 + pulse * sin(_phase))
	var f: Color = fill_color
	var e: Color = edge_color
	f.a *= _blend
	e.a *= _blend
	draw_circle(center, r, f)
	# 흐린 전체 테두리 위에, 남은 시간만큼만 밝은 테두리를 12시 방향부터 시계로 덮는다
	var dim: Color = e
	dim.a *= 0.25
	draw_arc(center, r, 0.0, TAU, 48, dim, edge_width, true)
	if _remain > 0.001:
		draw_arc(center, r, -PI * 0.5, -PI * 0.5 + TAU * _remain, 48, e, edge_width, true)
