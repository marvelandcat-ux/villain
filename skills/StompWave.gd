class_name StompWave
extends Node2D

## 아이가 **바닥에 발을 디딜 때 퍼지는 충격파**. 층간소음 빌런 2번 스킬(`RunningKid`)이
## 한 걸음 디딜 때마다 발밑에 띄운다.
##
## 바닥을 타고 좌우로 퍼지는 **납작한 고리** 몇 개와, 발밑에서 튀는 **먼지**로 돼 있다.
## 판정은 안 들고 있다 — 때리는 건 아이 쪽이 직접 거리를 재서 한다.
## (그래야 "보이는 고리 = 맞는 범위"를 한 곳에서 맞출 수 있다)

## 고리가 퍼지는 최대 반지름(px). 때리는 범위와 같게 맞춰 두면 보이는 대로 맞는다
@export var max_radius: float = 110.0
## 고리 개수와 하나가 다 퍼지는 데 걸리는 시간(초), 고리 사이 출발 간격(초)
@export var ring_count: int = 2
@export var ring_time: float = 0.3
@export var ring_gap: float = 0.07
## 고리 굵기(px) — 퍼질수록 얇아진다
@export var ring_width: float = 6.0
## 고리가 위아래로 눌린 정도. 작을수록 바닥을 타고 퍼지는 느낌이 난다
@export var squash: float = 0.22
## 고리 색
@export var ring_color: Color = Color(1.0, 1.0, 1.0, 0.9)

@export_group("먼지")
## 발밑에서 튀는 먼지 개수. 0이면 안 그린다
@export var dust_count: int = 7
## 먼지가 날아가는 거리(px)와 크기(px), 떠 있는 시간(초)
@export var dust_distance: float = 46.0
@export var dust_size: float = 5.0
@export var dust_time: float = 0.34
## 먼지가 위로 뜨는 높이(px)
@export var dust_rise: float = 16.0
@export var dust_color: Color = Color(1.0, 1.0, 1.0, 0.75)

## 시작하고 흐른 시간 / 전체 길이
var _time: float = 0.0
var _life: float = 0.0
## 먼지마다 날아가는 방향·거리를 미리 뽑아 둔다(매 프레임 흔들리지 않게)
var _dust: Array[Vector2] = []

func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	z_as_relative = false
	z_index = 20
	_life = maxf(ring_gap * float(maxi(ring_count - 1, 0)) + ring_time, dust_time)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(maxi(dust_count, 0)):
		# 좌우로 퍼지되 위로도 조금 — 바닥을 치고 튀는 모양
		var dir: float = 1.0 if i % 2 == 0 else -1.0
		_dust.append(Vector2(dir * rng.randf_range(0.35, 1.0), -rng.randf_range(0.2, 1.0)))

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _time >= _life:
		queue_free()

func _draw() -> void:
	for i in range(maxi(ring_count, 0)):
		_draw_ring(_time - ring_gap * float(i))
	_draw_dust()

## 고리 하나. t는 그 고리가 출발하고 흐른 시간
func _draw_ring(t: float) -> void:
	if t <= 0.0 or t >= ring_time:
		return
	var k: float = t / ring_time
	var r: float = max_radius * (1.0 - pow(1.0 - k, 2.0))
	if r < 1.0:
		return
	var color: Color = ring_color
	color.a *= 1.0 - k
	var points := PackedVector2Array()
	var steps: int = 36
	for i in range(steps + 1):
		var a: float = TAU * float(i) / float(steps)
		points.append(Vector2(cos(a) * r, sin(a) * r * squash))
	draw_polyline(points, color, maxf(ring_width * (1.0 - k * 0.7), 1.0), true)

## 발밑에서 튀는 먼지 — 날아가며 작아지고 옅어진다
func _draw_dust() -> void:
	if _dust.is_empty() or _time >= dust_time:
		return
	var k: float = _time / dust_time
	var out: float = 1.0 - pow(1.0 - k, 2.0)
	var color: Color = dust_color
	color.a *= 1.0 - k
	for d in _dust:
		var at := Vector2(d.x * dust_distance * out, d.y * dust_rise * out)
		draw_circle(at, dust_size * (1.0 - k * 0.6), color)
