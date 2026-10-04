class_name SlamStar
extends Node2D

## **문이 쾅 닫힐 때 튀는 별 모양 충격**. 층간소음 빌런 궁극기 3장(문 쾅)이 문틈에 띄운다.
##
## 그림 없이 `_draw()`로 그린다 — 노란 속에 빨간 테두리를 두른 뾰족한 별이다(2026-10-04 사용자 스케치).
## 스파이크는 **한쪽 방향으로만** 퍼진다(`aim_deg` ± `spread_deg`) — 문에 막힌 쪽으로는 안 튀어야
## "문틈에서 터졌다"로 읽힌다.
##
## 터질 때 작게 시작해 확 커졌다가(살짝 더 커졌다 제자리) 사라진다

## 뾰족한 가지 개수
@export var spike_count: int = 7
## 가장 긴 가지 길이(px)와, 가지 사이 안쪽으로 들어가는 깊이(길이 대비 비율)
@export var radius: float = 90.0
@export_range(0.1, 0.9, 0.01) var inner_ratio: float = 0.42
## 가지 길이가 들쭉날쭉한 정도(0이면 전부 같은 길이)
@export_range(0.0, 0.8, 0.01) var jitter: float = 0.35
## 가지가 퍼지는 **가운데 방향**(도, 0이 오른쪽)과 그 좌우 범위(도)
@export var aim_deg: float = 0.0
@export var spread_deg: float = 115.0

@export_group("색")
@export var fill_color: Color = Color(1.0, 0.87, 0.05)
@export var line_color: Color = Color(0.87, 0.11, 0.09)
@export var line_width: float = 5.0

@export_group("시간")
## 터져 나오는 시간 / 가장 크게 머무는 시간 / 사라지는 시간(초)
@export var grow_time: float = 0.07
@export var hold_time: float = 0.09
@export var fade_time: float = 0.16
## 터지는 순간 잠깐 더 커지는 배율(1이면 안 커진다)
@export var overshoot: float = 1.18

var _time: float = 0.0
var _life: float = 0.0
## 가지마다 미리 뽑아 둔 길이 배수 — 매 프레임 다시 뽑으면 별이 부들거린다
var _spikes: Array[float] = []

func _ready() -> void:
	z_as_relative = false
	z_index = 40
	_life = grow_time + hold_time + fade_time
	_build()

func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_spikes.clear()
	for i in range(maxi(spike_count, 3)):
		_spikes.append(1.0 - rng.randf() * clampf(jitter, 0.0, 0.8))

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _time >= _life:
		queue_free()

func _draw() -> void:
	var grow: float = clampf(_time / maxf(grow_time, 0.01), 0.0, 1.0)
	# 터질 때 한 번 더 커졌다 제자리로 — 펑 하는 맛
	var size: float = radius * grow * (1.0 + (overshoot - 1.0) * sin(grow * PI))
	if _time > grow_time + hold_time:
		size = radius * (1.0 + (overshoot - 1.0) * 0.0)
	if size < 1.0:
		return
	var alpha: float = 1.0
	if _time > grow_time + hold_time:
		alpha = clampf(1.0 - (_time - grow_time - hold_time) / maxf(fade_time, 0.01), 0.0, 1.0)
	var points := _star(size)
	var fill: Color = fill_color
	fill.a *= alpha
	var line: Color = line_color
	line.a *= alpha
	draw_colored_polygon(points, fill)
	# 테두리는 끝점을 한 번 더 이어 닫는다
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, line, line_width, true)

## 별 꼭짓점 — 가지 끝과 가지 사이 골을 번갈아 찍는다.
## `aim_deg`를 가운데로 `spread_deg`만큼만 퍼지므로 반대쪽(문 안쪽)으로는 안 튄다
func _star(size: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n: int = maxi(_spikes.size(), 3)
	var aim: float = deg_to_rad(aim_deg)
	var spread: float = deg_to_rad(clampf(spread_deg, 10.0, 180.0))
	for i in range(n):
		var t: float = float(i) / float(n - 1) if n > 1 else 0.5
		var angle: float = aim + (t * 2.0 - 1.0) * spread
		var tip: float = size * _spikes[i]
		out.append(Vector2(cos(angle), sin(angle)) * tip)
		# 가지 사이 골 — 다음 가지와의 가운데 각도에서 안쪽으로 들어간다
		if i < n - 1:
			var next_t: float = float(i + 1) / float(n - 1)
			var mid: float = aim + ((t + next_t) * 0.5 * 2.0 - 1.0) * spread
			out.append(Vector2(cos(mid), sin(mid)) * size * inner_ratio)
	# 뿌리(문에 붙은 쪽)로 닫는다
	out.append(Vector2.ZERO)
	return out
