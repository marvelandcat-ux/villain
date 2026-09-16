class_name HitSpark
extends Node2D

## 타격 순간 튀는 히트 이펙트 (그림 없이 `_draw()`로 그린다).
## 세 겹으로 겹쳐 그린다: ① 가운데 번쩍 ② 맞은 방향으로 길게 찢어지는 섬광 ③ 사방으로 튀는 불꽃 줄기.
## **세게 맞을수록(power) 크고 줄기가 많아지고**, `ring_power` 이상이면 충격파 고리까지 퍼진다.
## 방어에 막힌 한 방은 차가운 파랑으로 작게 튀고 섬광·고리가 없다 — 맞았는지 막혔는지 색으로 읽힌다.
##
## `setup()`을 안 불러도 기본값(세기 1, 방향 없음 = 사방으로 퍼짐)으로 동작한다 — 투사체 착탄·총구 섬광·도발 표시가
## 이 씬을 그대로 가져다 쓰기 때문이다.

## 전체가 사라지기까지(초)
@export var life: float = 0.22
## 처음부터 이만큼 진행된 상태로 시작한다(0~1). 히트스톱으로 화면이 멈춘 동안에도 모양이 읽히게 하려는 값 —
## 0이면 멈춘 동안 줄기 길이가 0이라 가운데 점만 보인다
@export_range(0.0, 0.5, 0.01) var start_progress: float = 0.15
## 가운데 번쩍·섬광 색 / 불꽃 줄기 색 / 막혔을 때 색 / 윤곽선 색
@export var hot_color: Color = Color(1.0, 1.0, 0.88)
@export var spark_color: Color = Color(1.0, 0.78, 0.22)
@export var blocked_color: Color = Color(0.62, 0.86, 1.0)
@export var outline_color: Color = Color(0.18, 0.08, 0.0, 0.85)
## 가운데 번쩍 반지름(px)
@export var core_radius: float = 10.0
## 맞은 방향 섬광의 길이·두께(px)
@export var slash_length: float = 48.0
@export var slash_width: float = 9.0
## 불꽃 줄기 개수(세기 1 기준)와 길이(px)
@export var ray_count: int = 6
@export var ray_length: float = 32.0
## 줄기 중 맞은 방향 쪽(±50도)으로 몰리는 비율. 0이면 사방으로 고르게, 1이면 전부 한쪽으로
@export_range(0.0, 1.0, 0.05) var direction_bias: float = 0.65
## 세기가 이 값 이상이면 충격파 고리가 퍼진다 — 약한 잽까지 고리가 나면 센 한 방이 안 구분된다
@export var ring_power: float = 1.5
@export var ring_radius: float = 34.0
## 세기 상한 — 궁극기처럼 데미지가 큰 판정에서 화면을 덮지 않게
@export var power_max: float = 2.4

class Ray:
	var dir: Vector2
	var length: float
	var width: float

var _age: float = 0.0
var _dir: Vector2 = Vector2.ZERO
var _power: float = 1.0
var _blocked: bool = false
var _rays: Array[Ray] = []

func _ready() -> void:
	z_index = 30
	_age = life * start_progress
	_build()

## 맞은 방향(넉백 방향, 없으면 ZERO) / 세기(1 = 보통 한 방) / 방어에 막혔는지
func setup(direction: Vector2, power: float = 1.0, blocked: bool = false) -> void:
	_dir = direction.normalized() if direction.length() > 0.01 else Vector2.ZERO
	_power = clampf(power, 0.5, power_max)
	_blocked = blocked
	if _blocked:
		_power *= 0.7
	_build()

func _build() -> void:
	_rays.clear()
	var count: int = maxi(3, roundi(ray_count * sqrt(_power)))
	for i in count:
		var r := Ray.new()
		var angle: float
		if _dir != Vector2.ZERO and randf() < direction_bias:
			angle = _dir.angle() + randf_range(-0.87, 0.87)
		else:
			angle = TAU * (float(i) + randf_range(-0.3, 0.3)) / float(count)
		r.dir = Vector2.from_angle(angle)
		r.length = ray_length * _power * randf_range(0.6, 1.25)
		r.width = randf_range(2.0, 3.5) * sqrt(_power)
		_rays.append(r)
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t: float = clampf(_age / life, 0.0, 1.0)
	var grow: float = 1.0 - pow(1.0 - t, 3.0)   # 확 퍼졌다가 느려지는 곡선
	var fade: float = 1.0 - t
	var main: Color = blocked_color if _blocked else spark_color
	var hot: Color = blocked_color.lightened(0.5) if _blocked else hot_color
	var s: float = sqrt(_power)

	# ③ 충격파 고리 — 센 한 방만
	if not _blocked and _power >= ring_power:
		var ring_col := hot
		ring_col.a = fade * 0.8
		draw_arc(Vector2.ZERO, ring_radius * s * (0.35 + grow), 0.0, TAU, 32, ring_col, 5.0 * fade + 1.0)

	# 불꽃 줄기 — 머리가 먼저 뻗고 꼬리가 뒤따라 줄어든다
	for r in _rays:
		var head: Vector2 = r.dir * r.length * grow
		var tail: Vector2 = r.dir * r.length * maxf(grow - 0.45, 0.0) + r.dir * 4.0
		if head.distance_to(tail) < 1.0:
			continue
		var w: float = r.width * (0.4 + 0.6 * fade)
		var out_col := outline_color
		out_col.a *= fade
		draw_line(tail, head, out_col, w + 2.5)
		var col := main
		col.a = fade
		draw_line(tail, head, col, w)

	# ② 맞은 방향으로 찢어지는 섬광(마름모) — 방향이 있을 때만
	if not _blocked and _dir != Vector2.ZERO:
		var length: float = slash_length * s * (0.55 + 0.6 * grow)
		var width: float = slash_width * s * fade
		var side: Vector2 = _dir.orthogonal() * width
		var pts := PackedVector2Array([
			_dir * length * 0.75, side, -_dir * length * 0.25, -side,
		])
		var out_col := outline_color
		out_col.a *= fade
		draw_polyline(pts + PackedVector2Array([pts[0]]), out_col, 2.0)
		var col := hot
		col.a = fade
		draw_colored_polygon(pts, col)

	# ① 가운데 번쩍 — 앞 절반에서만
	if t < 0.55:
		var k: float = 1.0 - t / 0.55
		var core_col := hot
		core_col.a = k
		draw_circle(Vector2.ZERO, core_radius * s * (0.6 + 0.8 * t), core_col)
