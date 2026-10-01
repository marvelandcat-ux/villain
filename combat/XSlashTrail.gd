class_name XSlashTrail
extends Node2D

## 공중에 **X자 자취**를 그려 놓는 연출. 지하철 아저씨 쌍 악기 3타(돌면서 X자 긋기)가 띄운다.
##
## 두 획이 **차례로 그어진다** — 한 획이 끝에서 끝까지 쭉 그어지고, 조금 뒤 반대 획이 겹쳐 그어져
## X가 완성된다. 그 뒤 잠깐 머물렀다가 사라진다. 긋는 동안 획 끝이 가장 밝아서 "지나간 자취"로 읽힌다.
##
## 시간은 **게임 시간**으로 센다 — 같이 들어가는 슬로우모션에 맞춰 천천히 그어져야 보이기 때문이다

## 획 하나의 길이(px)와 **가장 두꺼운 곳의 굵기**(px).
## 획은 폭이 일정한 막대가 아니라 **양 끝이 뾰족한 날** 모양이다 — 아래 taper 값들이 그 모양을 정한다
@export var stroke_length: float = 130.0
@export var stroke_width: float = 11.0

@export_group("날 모양")
## 가장 두꺼운 지점이 획의 어디쯤인지(0 = 꼬리, 1 = 끝). 앞쪽에 둘수록 길게 뻗은 칼날이 된다
@export_range(0.05, 0.95, 0.01) var taper_bias: float = 0.3
## **끝이 뾰족해지는 정도.** 클수록 끝이 길고 날카롭게 빠진다
@export var tip_sharpness: float = 2.1
## 꼬리가 굵어지는 정도. 1보다 작으면 꼬리 쪽이 빨리 두꺼워진다(짧고 뭉툭한 꼬리)
@export var tail_sharpness: float = 0.55
## 획이 옆으로 휘는 정도(px). 0이면 곧은 직선, 조금 주면 베고 지나간 호(弧)처럼 보인다
@export var bow: float = 10.0
## 날을 몇 조각으로 쪼개 그릴지. 클수록 매끄럽다
@export var segments: int = 18
## X가 벌어진 각도(도). 45면 정확한 ×, 작으면 날렵한 ×가 된다
@export var stroke_angle_deg: float = 42.0
## 획 하나를 긋는 데 걸리는 시간(초)
@export var draw_time: float = 0.12
## 첫 획을 긋기 시작하고 둘째 획이 시작되기까지의 간격(초)
@export var stroke_gap: float = 0.08
## 다 그은 뒤 그대로 머무는 시간(초)과 사라지는 데 걸리는 시간(초)
@export var hold_time: float = 0.18
@export var fade_time: float = 0.22

@export_group("색")
## 획의 몸통 색(바깥쪽 굵은 부분)
@export var trail_color: Color = Color(0.45, 0.85, 1.0, 0.85)
## 획 가운데를 지나는 밝은 심지
@export var core_color: Color = Color(1.0, 1.0, 1.0, 0.95)
## 심지 굵기는 몸통의 이 비율
@export var core_ratio: float = 0.4
## 긋고 있는 **획 끝의 번쩍임** 크기(px). 0이면 안 그린다
@export var tip_glow: float = 9.0

## 시작하고 흐른 시간
var _time: float = 0.0
## 전체 길이 — 이 시간이 지나면 스스로 사라진다
var _life: float = 0.0

func _ready() -> void:
	# 더하기(add) 혼합이라 어두운 배경 위에서 빛나는 획처럼 보인다
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	_life = stroke_gap + draw_time + hold_time + fade_time
	# **맞은 쪽 몸의 자식으로 붙기 때문에** z를 부모 기준으로 두면 몸에 묻힌다.
	# 절대값으로 바꿔 어디에 붙든 항상 맨 앞에 그린다
	z_as_relative = false
	z_index = 60

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _time >= _life:
		queue_free()

func _draw() -> void:
	var done: float = stroke_gap + draw_time
	# 다 그은 뒤에는 통째로 서서히 지운다
	var alpha: float = 1.0
	if _time > done + hold_time:
		alpha = 1.0 - clampf((_time - done - hold_time) / maxf(fade_time, 0.01), 0.0, 1.0)
	if alpha <= 0.0:
		return
	var rad: float = deg_to_rad(stroke_angle_deg)
	# 두 획은 서로 거울상이다 — 하나는 위에서 아래로, 하나는 아래에서 위로 긋는다
	_draw_stroke(Vector2(-cos(rad), -sin(rad)), 0.0, alpha)
	_draw_stroke(Vector2(-cos(rad), sin(rad)), stroke_gap, alpha)

## 획 하나. dir은 획이 **시작되는 쪽**(가운데에서 바깥으로의 방향)이고, start는 이 획이 시작되는 시각
func _draw_stroke(dir: Vector2, start: float, alpha: float) -> void:
	var t: float = clampf((_time - start) / maxf(draw_time, 0.01), 0.0, 1.0)
	if t <= 0.0:
		return
	# 끝으로 갈수록 느려진다 — 휘두른 끝이 살짝 멎는 느낌
	var eased: float = 1.0 - pow(1.0 - t, 2.0)
	var half: float = stroke_length * 0.5
	var from: Vector2 = dir * half
	var to: Vector2 = -dir * half
	var tip: Vector2 = from.lerp(to, eased)
	var body: Color = trail_color
	body.a *= alpha
	var core: Color = core_color
	core.a *= alpha
	# 바깥 날 → 안쪽 심지 순서로 덮어 그린다
	var side: float = 1.0 if start <= 0.0 else -1.0
	draw_colored_polygon(_blade(from, tip, stroke_width * 0.5, side), body)
	draw_colored_polygon(_blade(from, tip, stroke_width * 0.5 * core_ratio, side), core)
	# 아직 긋는 중이면 끝에 번쩍임을 둔다 — 여기가 "지금 지나가는 자리"다
	if tip_glow > 0.0 and t < 1.0:
		draw_circle(tip, tip_glow * (1.0 - t * 0.4), core)

## **양 끝이 뾰족한 날** 한 조각을 만든다. from에서 tip까지 가면서 폭이 불었다 줄어드는 다각형이다.
## 폭이 일정한 선(draw_line)으로 그리면 막대기(직사각형)로 보여서 베는 맛이 안 난다
func _blade(from: Vector2, tip: Vector2, half_width: float, side: float) -> PackedVector2Array:
	var axis: Vector2 = tip - from
	var length: float = axis.length()
	var pts := PackedVector2Array()
	if length < 0.01 or half_width <= 0.0:
		return pts
	axis /= length
	var perp := Vector2(-axis.y, axis.x)
	var steps: int = maxi(segments, 3)
	# 한쪽 변을 따라 끝까지 갔다가, 반대쪽 변을 따라 돌아온다
	for i in range(steps + 1):
		var s: float = float(i) / float(steps)
		pts.append(_rib(from, tip, perp, s, half_width, side, 1.0))
	for i in range(steps, -1, -1):
		var s: float = float(i) / float(steps)
		pts.append(_rib(from, tip, perp, s, half_width, side, -1.0))
	return pts

## 날의 s 지점(0=꼬리, 1=끝) 한쪽 가장자리
func _rib(from: Vector2, tip: Vector2, perp: Vector2, s: float, half_width: float, side: float, edge: float) -> Vector2:
	var center: Vector2 = from.lerp(tip, s) + perp * (bow * side * sin(PI * s))
	return center + perp * (half_width * _taper(s) * edge)

## 폭 비율(0~1) — 꼬리에서 0, taper_bias에서 1, 끝에서 다시 0. 끝 쪽이 더 길게 빠진다
func _taper(s: float) -> float:
	var bias: float = clampf(taper_bias, 0.05, 0.95)
	if s <= bias:
		return pow(s / bias, maxf(tail_sharpness, 0.05))
	return pow((1.0 - s) / (1.0 - bias), maxf(tip_sharpness, 0.05))
