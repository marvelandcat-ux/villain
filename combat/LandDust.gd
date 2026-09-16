class_name LandDust
extends Node2D

## 높은 데서 떨어져 착지했을 때 발밑에 퍼지는 먼지 (순수 장식 — 판정이 없다).
## **좌우로 낮게 깔리며 퍼진다** — 위로 솟으면 폭발처럼 보여서 "쿵 내려앉았다"로 안 읽힌다.
## 그림 없이 `_draw()`로 그리므로 먼지 스프라이트를 받으면 여기만 바꾸면 된다.
##
## `Fighter._spawn_land_dust()`가 착지 순간 맵에 붙이고 `setup(세기)`로 얼마나 세게 떨어졌는지 넘긴다.

## 한쪽에 몇 뭉치씩 퍼지는지 (좌우 대칭이라 실제로는 두 배)
@export var puffs_per_side: int = 4
## 퍼져나가는 속도(px/초)와 위로 살짝 뜨는 속도
@export var spread_speed: float = 190.0
@export var rise_speed: float = 46.0
## 덩어리 하나가 사라지기까지(초)
@export var puff_life: float = 0.42
## 덩어리 처음·마지막 반지름(px)
@export var puff_radius_start: float = 3.0
@export var puff_radius_end: float = 13.0
## 먼지 색
@export var dust_color: Color = Color(0.82, 0.78, 0.7, 0.75)
## 바닥에 깔리는 정도 (1이면 완전 수평, 0이면 사방으로)
@export_range(0.0, 1.0, 0.05) var flatten: float = 0.72

## 먼지 한 뭉치
class Puff:
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var age: float = 0.0
	var life: float = 0.4
	var size: float = 1.0

var _puffs: Array[Puff] = []

## power는 "얼마나 세게 떨어졌나"(1.0 = 기준 높이). 클수록 크고 멀리 퍼진다
func setup(power: float) -> void:
	var scaled: float = clampf(power, 0.6, 2.2)
	z_index = -1   # 캐릭터 발밑에 깔린다
	for side in [-1.0, 1.0]:
		for i in puffs_per_side:
			var p := Puff.new()
			# 낮게 깔리도록 각도를 수평 쪽으로 눌러준다
			var ang: float = randf_range(0.15, 1.15) * (1.0 - flatten)
			var speed: float = spread_speed * scaled * randf_range(0.6, 1.25)
			p.vel = Vector2(cos(ang) * speed * side, -sin(ang) * speed - rise_speed * randf_range(0.3, 1.0))
			p.pos = Vector2(randf_range(0.0, 7.0) * side, randf_range(-3.0, 1.0))
			p.life = puff_life * randf_range(0.8, 1.25)
			p.size = scaled * randf_range(0.75, 1.2)
			_puffs.append(p)
	queue_redraw()

func _process(delta: float) -> void:
	var alive: Array[Puff] = []
	for p in _puffs:
		p.age += delta
		if p.age >= p.life:
			continue
		# 공기에 먹혀 금세 잦아들고, 그 뒤엔 제자리에서 부풀며 사라진다
		p.vel = p.vel.move_toward(Vector2.ZERO, spread_speed * 2.2 * delta)
		p.pos += p.vel * delta
		alive.append(p)
	_puffs = alive
	queue_redraw()
	if _puffs.is_empty():
		queue_free()

func _draw() -> void:
	for p in _puffs:
		var t: float = p.age / p.life
		var r: float = lerpf(puff_radius_start, puff_radius_end, t) * p.size
		var col: Color = dust_color
		col.a *= (1.0 - t) * (1.0 - t * 0.35)
		draw_circle(p.pos, r, col)
