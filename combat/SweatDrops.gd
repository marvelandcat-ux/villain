class_name SweatDrops
extends Node2D

## **땀 몇 방울** — 헬스장에서 바벨을 다 들어 올린 순간 머리 위로 쭉 튀는 물방울이다.
##
## 그림 없이 `_draw()`로 그린다. 방울마다 **퍼지는 방향과 빠르기를 미리 뽑아** 두고
## 위로 날아가다 느려지며 사라진다(중력은 약하게만 걸어서 "쭉 뻗는" 맛을 남긴다).
##
## 다 사라지면 **스스로 지워진다** — 부르는 쪽은 만들어서 붙이기만 하면 된다

## 방울 수
@export var count: int = 3
## 날아가는 시간(초)
@export var life: float = 0.45
## 처음 튀어 나가는 빠르기(px/초)와 방울마다 들쭉날쭉한 정도(0~1)
@export var speed: float = 115.0
@export_range(0.0, 0.8, 0.05) var speed_jitter: float = 0.3
## 퍼지는 **가운데 방향**(도, -90이 바로 위)과 좌우로 벌어지는 범위(도)
@export var aim_deg: float = -90.0
@export var spread_deg: float = 52.0
## 아래로 당기는 힘(px/초²). 0이면 똑바로 뻗기만 한다
@export var gravity: float = 150.0
## 방울 크기(px)와 끝으로 갈수록 작아지는 정도
@export var radius: float = 2.6
@export_range(0.0, 1.0, 0.05) var shrink: float = 0.55
## 물방울 색
@export var color: Color = Color(0.58, 0.82, 1.0, 0.95)
## 테두리(밝은 쪽) 색과 굵기. 굵기가 0이면 테두리를 안 그린다
@export var line_color: Color = Color(0.92, 0.97, 1.0, 0.9)
@export var line_width: float = 0.8

var _time: float = 0.0
## 방울마다 [방향 단위벡터 × 빠르기]
var _vel: Array[Vector2] = []

func _ready() -> void:
	z_as_relative = false
	z_index = 8
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var aim: float = deg_to_rad(aim_deg)
	var spread: float = deg_to_rad(spread_deg)
	for i in range(maxi(count, 1)):
		# 부채꼴로 고르게 나눠 뿌린다 — 전부 랜덤이면 한쪽에 뭉치는 판이 나온다
		var t: float = (float(i) + 0.5) / float(maxi(count, 1))
		var angle: float = aim + (t * 2.0 - 1.0) * spread
		var v: float = speed * (1.0 - rng.randf() * clampf(speed_jitter, 0.0, 0.8))
		_vel.append(Vector2(cos(angle), sin(angle)) * v)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _time >= life:
		queue_free()

func _draw() -> void:
	var k: float = clampf(_time / maxf(life, 0.01), 0.0, 1.0)
	# 끝에서 녹듯이 사라진다
	var alpha: float = 1.0 - k * k
	var r: float = radius * (1.0 - shrink * k)
	if r < 0.2:
		return
	for v in _vel:
		# 등가속 운동 그대로 — 처음 빠르고 중력에 눌려 느려진다
		var at: Vector2 = v * _time + Vector2(0.0, gravity * _time * _time * 0.5)
		var c: Color = color
		c.a *= alpha
		draw_circle(at, r, c)
		if line_width > 0.0:
			var lc: Color = line_color
			lc.a *= alpha
			draw_arc(at, r, 0.0, TAU, 12, lc, line_width, true)
