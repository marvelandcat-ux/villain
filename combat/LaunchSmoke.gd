class_name LaunchSmoke
extends Node2D

## 크게 얻어맞고 날아가는 캐릭터 뒤에 남는 연기 꼬리 (순수 장식 — 판정이 없다).
## 맞는 순간 한 뭉치가 확 터지고, 그 뒤로 날아가는 동안 연기 덩어리를 하나씩 흘린다.
## 그림 없이 `_draw()`로 그리므로 연기 스프라이트를 받으면 여기만 바꾸면 된다.
##
## `ComboMeleeAttack`이 마무리 타에 new()로 만들어 **맵에 붙인다** — 맞은 사람의 자식으로 달면
## 그 사람이 좌우로 뒤집힐 때 연기까지 따라 뒤집히고, 캐릭터가 사라질 때 같이 잘린다.

## 맞는 순간 사방으로 터지는 덩어리 수
@export var burst_count: int = 10
## 터진 덩어리가 퍼져나가는 속도(px/초)
@export var burst_speed: float = 170.0
## 날아가는 동안 덩어리를 얼마마다 하나씩 흘리는지(초)
@export var trail_interval: float = 0.03
## 덩어리 하나가 사라지기까지(초) — 이 시간에 걸쳐 커지며 옅어진다
@export var puff_life: float = 0.5
## 덩어리 처음·마지막 반지름(px)
@export var puff_radius_start: float = 5.0
@export var puff_radius_end: float = 21.0
## 연기가 위로 뜨는 속도(px/초)
@export var rise_speed: float = 34.0
## 연기 색
@export var smoke_color: Color = Color(0.78, 0.77, 0.74, 0.72)

## 연기 덩어리 하나
class Puff:
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var age: float = 0.0
	var life: float = 0.5
	var size: float = 1.0

var _target: Node2D = null
var _left: float = 0.0
var _spawn_left: float = 0.0
var _last: Vector2 = Vector2.ZERO
var _puffs: Array[Puff] = []

## 때린 쪽이 스폰 직후 부른다. life 동안 날아가는 사람을 따라다니며 연기를 흘린다
func setup(target: Node2D, life: float) -> void:
	_target = target
	_left = maxf(life, 0.0)
	z_index = -1   # 날아가는 캐릭터가 연기에 가리지 않도록 뒤에 깔린다
	if is_instance_valid(target):
		_last = to_local(target.global_position)
	_burst()

## 맞는 순간 그 자리에서 사방으로 터지는 한 뭉치
func _burst() -> void:
	for i in burst_count:
		var ang: float = TAU * float(i) / float(maxi(burst_count, 1)) + randf_range(-0.3, 0.3)
		var speed: float = burst_speed * randf_range(0.5, 1.2)
		_puffs.append(_make_puff(_last, Vector2(cos(ang), sin(ang)) * speed, randf_range(0.9, 1.5)))

func _process(delta: float) -> void:
	if is_instance_valid(_target):
		_last = to_local(_target.global_position)
	else:
		_left = 0.0   # 날아가던 사람이 사라졌으면 더 흘리지 않고 남은 연기만 마저 그린다
	if _left > 0.0 and trail_interval > 0.0:
		_left = maxf(_left - delta, 0.0)
		_spawn_left -= delta
		while _spawn_left <= 0.0:
			_spawn_left += trail_interval
			var drift := Vector2(randf_range(-20.0, 20.0), -rise_speed * randf_range(0.4, 1.1))
			_puffs.append(_make_puff(_last, drift, randf_range(0.7, 1.1)))
	elif _left > 0.0:
		_left = maxf(_left - delta, 0.0)
	_advance(delta)
	queue_redraw()
	if _left <= 0.0 and _puffs.is_empty():
		queue_free()

func _make_puff(at: Vector2, vel: Vector2, size: float) -> Puff:
	var p := Puff.new()
	p.pos = at + Vector2(randf_range(-6.0, 6.0), randf_range(-10.0, 10.0))
	p.vel = vel
	p.life = puff_life * randf_range(0.8, 1.25)
	p.size = size
	return p

func _advance(delta: float) -> void:
	var alive: Array[Puff] = []
	for p in _puffs:
		p.age += delta
		if p.age >= p.life:
			continue
		# 퍼지는 힘이 공기에 먹히며 잦아들고, 그 뒤로는 천천히 위로만 뜬다
		p.vel.x = move_toward(p.vel.x, 0.0, burst_speed * 1.6 * delta)
		p.vel.y = move_toward(p.vel.y, -rise_speed * 0.4, burst_speed * delta)
		p.pos += p.vel * delta
		alive.append(p)
	_puffs = alive

func _draw() -> void:
	for p in _puffs:
		var t: float = p.age / p.life
		var r: float = lerpf(puff_radius_start, puff_radius_end, t) * p.size
		var col: Color = smoke_color
		# 나오자마자 가장 진하고 끝으로 갈수록 사라진다
		col.a *= (1.0 - t) * (1.0 - t * 0.4)
		draw_circle(p.pos, r, col)
