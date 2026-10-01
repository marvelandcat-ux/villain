class_name BluntImpact
extends Node2D

## **퍽!** — 둔기로 맞았을 때 뜨는 효과. 날붙이용 `HitSpark`(가늘게 찢어지는 섬광)와 정반대로,
## 두꺼운 충격 고리 + 뭉툭한 쐐기 + 먼지로 "둔탁하게 얻어맞았다"를 만든다.
## 경찰 경봉 1·2타가 쓴다(`Hitbox.blunt_impact`를 켜면 HitSpark 대신 이게 뜬다).
##
## 그림이 없다 — 전부 `_draw()`다. 색·크기는 전부 export라 다른 둔기 캐릭터가 그대로 가져다 쓸 수 있다

## 남아 있는 시간(초). 둔기는 날붙이보다 **조금 더 오래, 더 느리게** 퍼져야 묵직하다
@export var life: float = 0.26
## 맞는 순간 터지는 흰 섬광과 그 반지름
@export var core_color: Color = Color(1.0, 1.0, 0.94, 1.0)
@export var core_radius: float = 15.0
## 바깥으로 퍼지는 충격 고리 — 둔기의 "묵직함"은 거의 이 고리가 만든다
@export var shock_color: Color = Color(1.0, 0.95, 0.84, 1.0)
@export var ring_radius: float = 30.0
@export var ring_width: float = 11.0
## 사방으로 튀는 **뭉툭한 쐐기**(날카로운 선이 아니라 삼각 덩어리)
@export var wedge_count: int = 6
@export var wedge_length: float = 34.0
@export var wedge_width_deg: float = 24.0
## 맞은 방향 쪽으로 쐐기가 몰리는 정도(0 = 고르게, 1 = 전부 그쪽)
@export_range(0.0, 1.0, 0.05) var direction_bias: float = 0.6
## 둔탁함을 거드는 먼지 뭉치
@export var dust_color: Color = Color(0.84, 0.80, 0.74, 0.8)
@export var dust_count: int = 5
@export var dust_radius: float = 7.0
@export var dust_spread: float = 34.0
## 막혔을 때 색(파란 쪽) — 평소와 구분되게
@export var blocked_color: Color = Color(0.62, 0.86, 1.0, 0.95)
## 세기 상한(데미지 7 = 세기 1)
@export var power_max: float = 2.4

class Wedge:
	var dir: Vector2
	var length: float
	var half: float

class Dust:
	var dir: Vector2
	var dist: float
	var radius: float

var _age: float = 0.0
var _dir: Vector2 = Vector2.ZERO
var _power: float = 1.0
var _blocked: bool = false
var _wedges: Array[Wedge] = []
var _dusts: Array[Dust] = []

func _ready() -> void:
	z_index = 30
	_build()

## 맞은 방향(넉백 방향) / 세기(1 = 보통 한 방) / 방어에 막혔는지 — HitSpark와 같은 모양의 함수다
func setup(direction: Vector2, power: float = 1.0, blocked: bool = false) -> void:
	_dir = direction.normalized() if direction.length() > 0.01 else Vector2.ZERO
	_power = clampf(power, 0.5, power_max)
	_blocked = blocked
	if _blocked:
		_power *= 0.7
	_build()

func _build() -> void:
	_wedges.clear()
	_dusts.clear()
	var count: int = maxi(3, roundi(wedge_count * sqrt(_power)))
	for i in count:
		var w := Wedge.new()
		var angle: float
		if _dir != Vector2.ZERO and randf() < direction_bias:
			angle = _dir.angle() + randf_range(-0.8, 0.8)
		else:
			angle = TAU * (float(i) + randf_range(-0.25, 0.25)) / float(count)
		w.dir = Vector2.from_angle(angle)
		w.length = wedge_length * _power * randf_range(0.65, 1.3)
		w.half = deg_to_rad(wedge_width_deg) * randf_range(0.6, 1.2) * 0.5
		_wedges.append(w)
	for i in maxi(dust_count, 0):
		var d := Dust.new()
		d.dir = Vector2.from_angle(randf() * TAU)
		d.dist = dust_spread * _power * randf_range(0.4, 1.0)
		d.radius = dust_radius * randf_range(0.6, 1.3)
		_dusts.append(d)
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t: float = clampf(_age / maxf(life, 0.001), 0.0, 1.0)
	# 확 퍼졌다가 느려진다 — 날붙이보다 한 박자 느린 곡선이라 묵직하게 읽힌다
	var grow: float = 1.0 - pow(1.0 - t, 2.2)
	var fade: float = 1.0 - t
	var main: Color = blocked_color if _blocked else shock_color
	# 먼지는 제일 뒤에
	for d in _dusts:
		var c: Vector2 = d.dir * d.dist * grow
		draw_circle(c, d.radius * _power * (1.0 - t * 0.5), Color(dust_color, dust_color.a * fade * 0.8))
	# 뭉툭한 쐐기 — 테두리를 먼저 깔아야 밝은 배경에서도 덩어리로 보인다
	for w in _wedges:
		var tip: Vector2 = w.dir * w.length * grow
		var base: float = w.length * 0.18 * _power
		var n := Vector2(-w.dir.y, w.dir.x)
		var pts := PackedVector2Array([
			w.dir * base * 0.3 + n * base * 0.55,
			tip,
			w.dir * base * 0.3 - n * base * 0.55])
		draw_colored_polygon(pts, Color(outline_rgb(), 0.75 * fade))
		var inner := PackedVector2Array([
			w.dir * base * 0.3 + n * base * 0.33,
			tip * 0.92,
			w.dir * base * 0.3 - n * base * 0.33])
		draw_colored_polygon(inner, Color(main, main.a * fade))
	# 충격 고리 — 두껍게 퍼지면서 가늘어진다
	var r: float = ring_radius * _power * (0.35 + grow)
	var rw: float = ring_width * _power * (1.0 - t * 0.8)
	if rw > 0.5:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, Color(main, main.a * fade * 0.85), rw, true)
	# 가운데 섬광 — 앞 35%만 번쩍이고 사라진다
	var flash: float = clampf(1.0 - t / 0.35, 0.0, 1.0)
	if flash > 0.01:
		draw_circle(Vector2.ZERO, core_radius * _power * flash, Color(core_color, core_color.a * flash))

## 쐐기 테두리 색 — 어두운 윤곽(밝은 배경에서도 덩어리로 보이게)
func outline_rgb() -> Color:
	return Color(0.12, 0.09, 0.07)
