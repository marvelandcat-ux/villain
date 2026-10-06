extends Node2D

## 검은 고양이 똥 유탄(`CatPoopShell`)이 터질 때 맵에 띄우는 **충격파 + 범위 표시**.
## 판정은 안 들고 있다 — `radius`를 똥의 폭발 반지름과 같게 넣어 "보이는 원 = 맞는 범위"가 되게 한다.
## 값은 add_child **전에** 넣을 것

## 맞는 범위 반지름(px) — 똥의 폭발 반지름과 같게
var radius: float = 140.0
## 충격파 고리가 끝까지 퍼지는 시간(초)과 범위 원이 남아 있는 시간(초)
@export var wave_time: float = 0.22
@export var area_time: float = 0.4
@export var wave_width: float = 7.0
@export var wave_color: Color = Color(0.85, 0.6, 0.3, 0.95)
@export var area_color: Color = Color(0.45, 0.28, 0.12, 0.3)
@export var edge_color: Color = Color(0.3, 0.17, 0.06, 0.85)
## 사방으로 튀는 똥 부스러기 개수·크기(px)
@export var chunk_count: int = 10
@export var chunk_size: float = 6.0

var _time: float = 0.0
## 부스러기마다 방향·속도를 미리 뽑아 둔다(매 프레임 흔들리지 않게)
var _chunks: Array[Vector2] = []

func _ready() -> void:
	z_as_relative = false
	z_index = 19
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(maxi(chunk_count, 0)):
		var a: float = TAU * (float(i) + rng.randf_range(-0.3, 0.3)) / float(maxi(chunk_count, 1))
		_chunks.append(Vector2(cos(a), sin(a)) * rng.randf_range(0.55, 1.0))

func _process(delta: float) -> void:
	_time += minf(delta, 0.05)
	queue_redraw()
	if _time >= maxf(wave_time, area_time):
		queue_free()

func _draw() -> void:
	_draw_area()
	_draw_wave()
	_draw_chunks()

## 맞는 범위 — 처음부터 다 찬 원이 옅어지며 사라진다(테두리로 경계를 또렷하게)
func _draw_area() -> void:
	if _time >= area_time:
		return
	var fade: float = 1.0 - _time / area_time
	var fill: Color = area_color
	fill.a *= fade
	draw_circle(Vector2.ZERO, radius, fill)
	var edge: Color = edge_color
	edge.a *= fade
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, edge, 3.0, true)

## 충격파 고리 — 가운데에서 범위 끝까지 빠르게 퍼진다
func _draw_wave() -> void:
	if _time >= wave_time:
		return
	var k: float = _time / wave_time
	var r: float = radius * (1.0 - pow(1.0 - k, 3.0))
	if r < 1.0:
		return
	var color: Color = wave_color
	color.a *= 1.0 - k * 0.6
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, color, maxf(wave_width * (1.0 - k * 0.5), 1.0), true)

## 똥 부스러기 — 범위 끝 근처까지 날아가며 작아진다
func _draw_chunks() -> void:
	if _time >= area_time:
		return
	var k: float = _time / area_time
	var out: float = 1.0 - pow(1.0 - k, 2.0)
	var color: Color = Color(0.45, 0.28, 0.12)
	color.a = 1.0 - k
	for c in _chunks:
		draw_circle(c * radius * out, chunk_size * (1.0 - k * 0.6), color)
