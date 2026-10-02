class_name SlashMark
extends Node2D

## **칼자국** — 지하철 아저씨 궁(쌍 악기) 돌진이 스치고 지나간 상대 몸에 새긴다.
## 두 획이 X로 **쩍 벌어진 채 남아 있다가**, 돌진이 끝나는 순간 `burst()`로 **터진다**.
## 양손에 악기를 들고 지나가니 획도 둘이라야 "둘로 그었다"가 읽힌다.
##
## 그림이 따로 없다 — 전부 `_draw()`다(SlashArc·XSlashTrail과 같은 방식).
##
## **맞은 쪽 몸의 자식으로 붙여 쓴다**(`DualInstrumentUltimate`가 붙인다) — 맵에 붙이면
## 상대만 빠져나가 버려서 "몸에 자국이 났다"가 아니라 "바닥에 자국이 났다"가 된다.
## 그래서 z를 **절대값으로** 두고 맨 앞에 그린다 — 안 그러면 부모 몸에 묻힌다

## 획 하나의 길이(px)와 가장 벌어진 곳의 폭(px)
@export var stroke_length: float = 62.0
@export var stroke_width: float = 9.0
## X가 벌어진 각도(도). 45면 정확한 ×
@export var cross_angle_deg: float = 38.0
## 획 끝이 뾰족해지는 정도. 클수록 가운데만 벌어지고 끝이 날카롭다
@export var tip_sharpness: float = 1.5
## 획을 몇 조각으로 쪼개 그릴지. 클수록 매끄럽다
@export var segments: int = 14
## 자국이 **벌어지는 데** 걸리는 시간(초). 짧아야 "슥" 그어진 느낌이 난다
@export var open_time: float = 0.06
## 아무도 안 터뜨려 주면 이 시간(초) 뒤 스스로 옅어져 사라진다 —
## 궁이 중간에 끝나거나 돌진이 끊겨도 자국이 영영 남지 않게 하는 안전장치
@export var max_life: float = 2.5

@export_group("색")
## 벤 자리(상처) 색 — 몸 위에서 바로 "베였다"로 읽히게 붉은 쪽으로 둔다
@export var mark_color: Color = Color(0.95, 0.22, 0.28, 0.9)
## 자국 가운데를 지나는 밝은 심지
@export var core_color: Color = Color(1.0, 0.95, 0.95, 0.95)
## 자국 바깥에 번지는 빛 — 터질 게 남아 있다는 신호라 일부러 깜빡인다
@export var glow_color: Color = Color(1.0, 0.45, 0.35, 0.35)
## 바깥 빛이 몸통보다 몇 배 두꺼운지
@export var glow_ratio: float = 2.6
## 깜빡이는 속도와 세기(폭이 이 비율만큼 늘었다 줄어든다)
@export var pulse_speed: float = 26.0
@export var pulse_amount: float = 0.18

@export_group("터질 때")
## 터지는 데 걸리는 시간(초)
@export var burst_time: float = 0.3
## 터질 때 색 — 자국 색에서 이 색으로 확 바뀐다
@export var burst_color: Color = Color(1.0, 0.86, 0.5, 1.0)
## 퍼지는 고리의 최대 반지름(px)과 두께(px)
@export var ring_radius: float = 74.0
@export var ring_width: float = 9.0
## 사방으로 뻗는 **파편** 수와 길이·밑동 폭(px). 끝이 뾰족한 쐐기라 "튀어나간 조각"으로 읽힌다
@export var spike_count: int = 9
@export var spike_length: float = 34.0
@export var spike_width: float = 7.0
## 가운데 섬광 크기(px)
@export var flash_radius: float = 26.0
## 터질 때 획이 이 비율만큼 바깥으로 늘어난다 — 자국이 찢어지며 벌어지는 느낌
@export var burst_stretch: float = 1.9

## 생긴 뒤 흐른 시간(초)
var _age: float = 0.0
## 터지기 시작하고 흐른 시간. 음수면 아직 안 터졌다(기다리는 중)
var _burst_t: float = -1.0
## 가시가 뻗는 방향들 — 터지는 순간 정해 두고 그동안 안 바꾼다(매 프레임 흔들리면 지저분하다)
var _spikes: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
	# 맵 조명(CanvasModulate)에 눌리면 어두운 맵에서 자국이 안 보인다
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	# 부모(맞은 쪽 몸) 기준 z를 쓰면 몸에 묻힌다 — 절대값으로 맨 앞에 그린다
	z_as_relative = false
	z_index = 62

## 자국이 누워 있는 방향을 정한다(도). 베고 지나간 방향을 넘겨 주면 자국이 그 결대로 눕는다
func setup(angle_deg: float = 0.0, size_mult: float = 1.0) -> void:
	rotation_degrees = angle_deg
	scale = Vector2.ONE * size_mult

## 이미 터졌거나 터지는 중인지 — 두 번 터뜨리는 걸 막는다
func is_bursting() -> bool:
	return _burst_t >= 0.0

## **터뜨린다.** 데미지는 부르는 쪽(스킬)이 따로 넣는다 — 여기는 보이는 것만 맡는다
func burst() -> void:
	if _burst_t >= 0.0:
		return
	_burst_t = 0.0
	_spikes.clear()
	for i in range(maxi(spike_count, 0)):
		# 고르게 벌려 놓고 조금씩만 흔든다 — 완전 난수면 한쪽에 뭉친다
		_spikes.append(TAU * float(i) / float(maxi(spike_count, 1)) + randf_range(-0.2, 0.2))
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	if _burst_t >= 0.0:
		_burst_t += delta
		if _burst_t >= burst_time:
			queue_free()
			return
	elif _age >= max_life:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	# 벌어지는 중에는 길이·폭이 같이 자란다 — 그래야 그어지는 것처럼 보인다
	var open: float = clampf(_age / maxf(open_time, 0.001), 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - open, 3.0)
	if _burst_t < 0.0:
		_draw_waiting(eased)
	else:
		_draw_burst(clampf(_burst_t / maxf(burst_time, 0.001), 0.0, 1.0))

## 터지기를 기다리는 동안 — 자국이 깜빡이며 남아 있다
func _draw_waiting(eased: float) -> void:
	# 수명 끝이 다가오면 옅어진다(아무도 안 터뜨려 준 경우)
	var fade: float = 1.0
	if max_life > 0.0:
		fade = clampf((max_life - _age) / 0.35, 0.0, 1.0)
	var pulse: float = 1.0 + sin(_age * pulse_speed) * pulse_amount
	var length: float = stroke_length * eased
	var half: float = stroke_width * 0.5 * eased * pulse
	for dir in _dirs():
		_stroke(dir, length, half * glow_ratio, Color(glow_color, glow_color.a * fade))
		_stroke(dir, length, half, Color(mark_color, mark_color.a * fade))
		_stroke(dir, length * 0.92, half * 0.34, Color(core_color, core_color.a * fade))

## 터지는 중 — 획이 바깥으로 찢어지고, 고리와 가시가 퍼지고, 가운데가 번쩍인다
func _draw_burst(b: float) -> void:
	var out: float = 1.0 - pow(1.0 - b, 2.0)   # 처음에 확 퍼지고 끝에서 느려진다
	var fade: float = 1.0 - b * b
	var hot: Color = mark_color.lerp(burst_color, 0.75)
	# 1) 찢어지며 늘어나는 획
	var length: float = stroke_length * (1.0 + burst_stretch * out)
	var half: float = stroke_width * 0.5 * (1.0 - b * 0.7)
	for dir in _dirs():
		_stroke(dir, length, half * glow_ratio * 0.8, Color(burst_color, 0.3 * fade))
		_stroke(dir, length, half, Color(hot, fade))
	# 2) 퍼지는 충격 고리
	var r: float = ring_radius * out
	if r > 2.0:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 30, Color(burst_color, 0.85 * fade), ring_width * (1.0 - b * 0.8), true)
	# 3) 사방으로 튀는 파편 — 밑동이 넓고 끝이 뾰족한 쐐기다.
	#    굵기가 일정한 선으로 그으면 빨대 다발처럼 보여서 터진 맛이 안 난다
	var half_w: float = spike_width * 0.5 * (1.0 - b * 0.8)
	for ang in _spikes:
		var dir := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-dir.y, dir.x)
		var base: Vector2 = dir * (r * 0.2)
		var tip: Vector2 = dir * (r * 0.7 + spike_length * out)
		draw_colored_polygon(PackedVector2Array([base + perp * half_w, tip, base - perp * half_w]),
			Color(burst_color, 0.9 * fade))
	# 4) 가운데 섬광 — 터진 자리를 흰빛으로 눌러 준다
	if b < 0.5:
		var f: float = 1.0 - b * 2.0
		draw_circle(Vector2.ZERO, flash_radius * (0.5 + f * 0.5), Color(1.0, 1.0, 1.0, 0.85 * f))

## X를 이루는 두 획의 방향
func _dirs() -> Array[Vector2]:
	var rad: float = deg_to_rad(cross_angle_deg)
	return [Vector2(cos(rad), sin(rad)), Vector2(cos(rad), -sin(rad))]

## 획 하나 — **양 끝이 뾰족하고 가운데가 벌어진** 렌즈 모양이다.
## 굵기가 일정한 선(draw_line)으로 그으면 막대기로 보여서 베인 자국이 안 된다
func _stroke(dir: Vector2, length: float, half_w: float, color: Color) -> void:
	if length < 0.5 or half_w <= 0.0 or color.a <= 0.003:
		return
	var perp := Vector2(-dir.y, dir.x)
	var steps: int = maxi(segments, 4)
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		pts.append(_rib(dir, perp, float(i) / float(steps), length, half_w, 1.0))
	for i in range(steps, -1, -1):
		pts.append(_rib(dir, perp, float(i) / float(steps), length, half_w, -1.0))
	draw_colored_polygon(pts, color)

## 획의 s 지점(0=한쪽 끝, 0.5=가운데, 1=반대 끝) 한쪽 가장자리
func _rib(dir: Vector2, perp: Vector2, s: float, length: float, half_w: float, edge: float) -> Vector2:
	var center: Vector2 = dir * lerpf(-length * 0.5, length * 0.5, s)
	return center + perp * (half_w * pow(sin(PI * s), maxf(tip_sharpness, 0.05)) * edge)
