@tool
class_name ExclamationMark
extends Node2D

## 머리 위에 **툭 튀어나오는 느낌표(!)**. 만화에서 "어?" 하고 알아챌 때 쓰는 그 표시다.
##
## 그림 파일을 안 쓴다 — `_draw()`로 그린다. 크기·색·기울기를 인스펙터에서 바로 만질 수 있고,
## 어느 배경 위에 올려도 **어두운 테두리 + 밝은 속**이라 안 묻힌다.
##
## 나올 때 한 번 **크게 튀었다 제자리로** 오고(`pop_*`), 그 뒤로는 천천히 위아래로 까딱인다(`bob_*`).
##
## ⚠️ 튀는 연출을 노드의 `scale`로 안 준다 — 그러면 인스펙터에서 잡아 둔 크기를 매 프레임 덮어쓴다.
## 대신 **그릴 때의 숫자**만 키웠다 줄인다. `position`·`scale`은 전부 사람 몫이다.

## **그림을 쓰려면 여기에 넣는다.** 비워 두면 아래 값들로 직접 그린다(`_draw`).
## 그림을 넣으면 `thickness`·`taper`·`gap`·`색` 칸은 안 쓴다 — 크기(`height`)·기울기·튀어나오기만 먹는다
@export var texture: Texture2D = null:
	set(value):
		texture = value
		queue_redraw()
## 그림에서 **느낌표가 실제로 그려진 칸**(px). 둘레의 빈 자리·흐린 번짐을 빼고 잡아야
## `height`가 보이는 크기와 맞고, 자리도 이 칸 한가운데를 기준으로 선다
@export var texture_trim: Rect2 = Rect2(356, 145, 342, 1269):
	set(value):
		texture_trim = value
		queue_redraw()

## 느낌표 전체 높이(px)
@export var height: float = 86.0:
	set(value):
		height = value
		queue_redraw()
## 막대 **위쪽** 굵기(px)
@export var thickness: float = 24.0:
	set(value):
		thickness = value
		queue_redraw()
## 막대 아래쪽이 위쪽의 몇 배로 가늘어지는지
@export_range(0.2, 1.0, 0.05) var taper: float = 0.55:
	set(value):
		taper = value
		queue_redraw()
## 막대와 점 사이 틈 (전체 높이 대비)
@export_range(0.0, 0.5, 0.01) var gap: float = 0.16:
	set(value):
		gap = value
		queue_redraw()
## 기울기(도). 살짝 기울어야 "탁" 튀어나온 느낌이 난다
@export var tilt_deg: float = -8.0:
	set(value):
		tilt_deg = value
		queue_redraw()

@export_group("색")
@export var color: Color = Color(1.0, 0.86, 0.2):
	set(value):
		color = value
		queue_redraw()
@export var outline_color: Color = Color(0.09, 0.07, 0.05):
	set(value):
		outline_color = value
		queue_redraw()
@export var outline_width: float = 7.0:
	set(value):
		outline_width = value
		queue_redraw()

@export_group("튀어나오기")
## 나오기 전에 기다리는 시간(초)
@export var start_delay: float = 0.35
## 튀어나오는 데 걸리는 시간(초)
@export var pop_time: float = 0.22
## 튀는 도중 제일 커졌을 때의 배수
@export var pop_overshoot: float = 1.35

@export_group("까딱임")
## 한 번 까딱이는 시간(초). 0이면 안 움직인다
@export var bob_period: float = 1.2
## 까딱이며 오르내리는 거리(px)
@export var bob_px: float = 4.0

var _age: float = 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		# 에디터에서는 **다 나온 모습**으로 세워 둔다 — 자리를 맞추려면 보여야 한다
		_age = start_delay + pop_time + 1000.0
		set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	queue_redraw()

## 지금 얼마나 커져 있는지(0 = 아직 안 나옴, 1 = 제 크기). 튀는 동안 1을 넘었다 돌아온다
func _pop() -> float:
	if _age < start_delay:
		return 0.0
	if pop_time <= 0.0:
		return 1.0
	var t: float = clampf((_age - start_delay) / pop_time, 0.0, 1.0)
	if t >= 1.0:
		return 1.0
	# 0 -> pop_overshoot -> 1. 앞은 빠르게 커지고 뒤는 살짝 되돌아온다
	var up: float = sin(t * PI * 0.5)
	return lerpf(0.0, pop_overshoot, up) - (pop_overshoot - 1.0) * pow(t, 3.0)

func _draw() -> void:
	var k: float = _pop()
	if k <= 0.001:
		return
	if texture != null:
		_draw_texture(k)
		return
	var h: float = height * k
	var w0: float = thickness * k
	var w1: float = w0 * taper
	var dot_d: float = w0 * 0.95
	var bar_h: float = h - h * gap - dot_d
	if bar_h <= 0.0:
		return
	var bob: float = 0.0
	if bob_period > 0.0 and k >= 1.0:
		bob = sin(_age * TAU / bob_period) * bob_px
	var turn: float = deg_to_rad(tilt_deg)

	# 가운데를 원점으로 잡고 세운 뒤 통째로 기울인다
	var top: float = -h * 0.5 + bob
	var bar_bottom: float = top + bar_h
	var dot_center := Vector2(0.0, top + h - dot_d * 0.5)
	var bar := PackedVector2Array([
		Vector2(-w0 * 0.5, top), Vector2(w0 * 0.5, top),
		Vector2(w1 * 0.5, bar_bottom), Vector2(-w1 * 0.5, bar_bottom)])
	for i in bar.size():
		bar[i] = bar[i].rotated(turn)
	dot_center = dot_center.rotated(turn)

	# 테두리 먼저 — 선을 변 위에 두껍게 긋고 그 위를 속색으로 덮는다
	var ring := PackedVector2Array(bar)
	ring.append(bar[0])
	var edge: float = maxf(outline_width * k, 1.0)
	draw_polyline(ring, outline_color, edge * 2.0, true)
	draw_circle(dot_center, dot_d * 0.5 + edge, outline_color)
	draw_colored_polygon(bar, color)
	draw_circle(dot_center, dot_d * 0.5, color)

## 그림으로 그린다. **보이는 칸(`texture_trim`)의 높이**가 `height`가 되도록 줄이고,
## 그 칸 한가운데를 노드 자리에 맞춘다 — 그래야 빈 여백이 얼마든 자리가 안 흔들린다
func _draw_texture(k: float) -> void:
	var trim: Rect2 = texture_trim
	if trim.size.y <= 0.0:
		trim = Rect2(Vector2.ZERO, texture.get_size())
	var fit: float = height * k / trim.size.y
	var bob: float = 0.0
	if bob_period > 0.0 and k >= 1.0:
		bob = sin(_age * TAU / bob_period) * bob_px
	draw_set_transform(Vector2(0.0, bob), deg_to_rad(tilt_deg), Vector2.ONE)
	var whole: Vector2 = texture.get_size() * fit
	# 보이는 칸의 한가운데가 원점에 오도록 통째로 민다
	var at: Vector2 = -(trim.position + trim.size * 0.5) * fit
	draw_texture_rect(texture, Rect2(at, whole), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
