class_name GuardImpact
extends Node2D

## 방어에 막힌 순간 막힌 자리에서 터지는 이펙트(2026-10-10 사용자 레퍼런스).
## 예전의 "BLOCK" 글자 + 작은 파란 불꽃을 대신한다. 그림 없이 `_draw()`로 그린다:
## ① 가운데서 파란 원이 한 번 번쩍 → 초승달 고리가 되어 **막는 사람 뒤쪽으로 밀려나며** 커진다
## ② 그 뒤에 비치는 하늘색 반투명 판 ③ 보라·흰 번개 ④ 뒤쪽으로 튀는 흰 속도선
##
## 그리는 좌표는 "+x = 막는 사람의 뒤쪽(공격이 밀고 들어가는 쪽)" 하나로 짜고,
## 반대쪽이면 `draw_set_transform`으로 가로만 뒤집는다(돌리면 번개의 위아래까지 뒤집힌다)

## 전체 크기 배율 — 모양·굵기·거리를 통째로 키운다(2026-10-10 사용자: 1 -> 1.4)
@export var size: float = 1.4
## 전체가 사라지기까지(초)
@export var life: float = 0.34
## 고리 색 / 가운데 번쩍 색 / 판 색 / 번개 바깥(번짐)·안쪽 색 / 속도선 색
@export var ring_color: Color = Color(0.36, 0.72, 1.0)
@export var core_color: Color = Color(0.92, 0.98, 1.0)
@export var panel_color: Color = Color(0.45, 0.95, 1.0, 0.32)
@export var bolt_glow_color: Color = Color(0.62, 0.38, 1.0, 0.6)
@export var bolt_color: Color = Color(0.96, 0.92, 1.0)
@export var streak_color: Color = Color(1.0, 1.0, 1.0)
## ① 처음 번쩍이는 원의 반지름(px)
@export var flash_radius: float = 16.0
## 번쩍임이 초승달로 바뀌는 시점(0~1)
@export_range(0.05, 0.6, 0.01) var flash_part: float = 0.22
## 초승달 반지름: 처음 → 끝(px). 캐릭터 키가 약 92px라 끝에서 몸을 반쯤 덮는다
@export var arc_radius_start: float = 18.0
@export var arc_radius_end: float = 48.0
## 초승달이 뒤로 밀려나는 거리(px)
@export var arc_travel: float = 26.0
## 초승달이 감싸는 각도(도, 양쪽 합)와 가장 두꺼운 곳 두께(px)
@export var arc_span_deg: float = 150.0
@export var arc_thickness: float = 13.0
## ② 판 크기(px) — 높이 x 폭. 고리 뒤에 세로로 선다
@export var panel_size: Vector2 = Vector2(78.0, 16.0)
## ③ 번개 줄기 수 / 한 줄 마디 수 / 마디 길이(px) / 모양이 바뀌는 간격(초, 지직거림)
@export var bolt_count: int = 3
@export var bolt_segments: int = 6
@export var bolt_step: float = 8.0
@export var bolt_flicker: float = 0.045
## ④ 속도선 수와 길이(px)
@export var streak_count: int = 7
@export var streak_length: float = 30.0
## 세기 상한 — 궁처럼 큰 한 방에서 화면을 덮지 않게
@export var power_max: float = 1.8

var _age: float = 0.0
## +1 = 오른쪽이 막는 사람의 뒤쪽, -1 = 왼쪽
var _side: float = 1.0
var _power: float = 1.0
var _bolts: Array[PackedVector2Array] = []
var _bolt_timer: float = 0.0
## 속도선: (각도, 길이 배율, 출발 지연 0~1)
var _streaks: Array[Vector3] = []

func _ready() -> void:
	z_index = 30
	scale = Vector2(size, size)
	_build_streaks()
	_build_bolts()

## push_dir = 공격이 밀고 들어가는 방향(가로 부호만 쓴다) / power = 세기(1 = 보통 한 방)
func setup(push_dir: Vector2, power: float = 1.0) -> void:
	if absf(push_dir.x) > 0.01:
		_side = signf(push_dir.x)
	_power = clampf(power, 0.7, power_max)
	_build_streaks()
	_build_bolts()

func _build_streaks() -> void:
	_streaks.clear()
	for i in streak_count:
		_streaks.append(Vector3(randf_range(-0.75, 0.75), randf_range(0.6, 1.3), randf_range(0.0, 0.35)))

## 번개는 가운데에서 뒤쪽·위아래로 지그재그로 뻗는다. 일정 간격마다 다시 만들어 지직거린다
func _build_bolts() -> void:
	_bolts.clear()
	var s: float = sqrt(_power)
	for i in bolt_count:
		var base: float = randf_range(-1.3, 1.3)
		var p := Vector2(randf_range(-4.0, 6.0), randf_range(-6.0, 6.0))
		var pts := PackedVector2Array([p])
		for j in bolt_segments:
			var a: float = base + randf_range(-0.9, 0.9)
			p += Vector2.from_angle(a) * bolt_step * s * randf_range(0.6, 1.3)
			pts.append(p)
		_bolts.append(pts)

func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	_bolt_timer -= delta
	if _bolt_timer <= 0.0:
		_bolt_timer = bolt_flicker
		_build_bolts()
	queue_redraw()

func _draw() -> void:
	var t: float = clampf(_age / life, 0.0, 1.0)
	var s: float = sqrt(_power)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_side, 1.0))

	# 초승달이 떠나는 진행도(번쩍임이 끝난 뒤 0 → 1, 확 나갔다 느려진다)
	var u: float = clampf((t - flash_part * 0.5) / (1.0 - flash_part * 0.5), 0.0, 1.0)
	var go: float = 1.0 - pow(1.0 - u, 3.0)
	var fade: float = 1.0 - u
	var arc_x: float = arc_travel * s * go

	# ② 판 — 고리 바로 뒤에서 비치다 사라진다
	if t < 0.7:
		var k: float = 1.0 - t / 0.7
		var h: float = panel_size.x * s * (0.75 + 0.35 * go) * 0.5
		var w: float = panel_size.y * s * 0.5
		var cx: float = arc_x + 6.0 * s
		var skew: float = 6.0 * s
		var pts := PackedVector2Array([
			Vector2(cx - w + skew, -h), Vector2(cx + w + skew, -h),
			Vector2(cx + w - skew, h), Vector2(cx - w - skew, h),
		])
		var fill := panel_color
		fill.a *= k
		draw_primitive(pts, PackedColorArray([fill, fill, fill, fill]), PackedVector2Array())
		var edge := panel_color.lightened(0.5)
		edge.a = minf(panel_color.a * 2.2, 1.0) * k
		draw_polyline(pts + PackedVector2Array([pts[0]]), edge, 1.5)

	# ③ 번개 — 앞 60%에서만 지직거린다
	if t < 0.6:
		var k: float = 1.0 - t / 0.6
		var glow := bolt_glow_color
		glow.a *= k
		var core := bolt_color
		core.a = k
		for pts in _bolts:
			draw_polyline(pts, glow, 4.0)
			draw_polyline(pts, core, 1.5)

	# ① 초승달 고리 — 볼록한 쪽이 공격자 쪽, 두께는 가운데가 두껍고 양 끝이 뾰족
	if t >= flash_part * 0.5:
		var radius: float = lerpf(arc_radius_start, arc_radius_end, go) * s
		var center := Vector2(arc_x + radius * 0.55, 0.0)
		var half: float = deg_to_rad(arc_span_deg) * 0.5
		var thick: float = arc_thickness * s * (0.5 + 0.5 * fade)
		var bright: float = pow(fade, 0.6)   # 두께보다 밝기가 천천히 빠져야 묵직하다
		var glow := ring_color
		glow.a = 0.35 * bright
		_draw_crescent(center, radius, half, thick * 2.2, glow)
		var col := ring_color
		col.a = bright
		_draw_crescent(center, radius, half, thick, col)
		var hot := core_color
		hot.a = bright
		_draw_crescent(center, radius, half * 0.8, thick * 0.35, hot)

	# ④ 속도선 — 고리 언저리에서 뒤쪽으로 쏜다
	for st in _streaks:
		var v: float = clampf((u - st.z) / (1.0 - st.z), 0.0, 1.0)
		if v <= 0.0 or v >= 1.0:
			continue
		var dir := Vector2.from_angle(st.x)
		var from: Vector2 = Vector2(arc_x, 0.0) + dir * (12.0 * s + streak_length * s * st.y * v)
		var to: Vector2 = from + dir * streak_length * s * st.y * (1.0 - v) * 0.8
		var col := streak_color
		col.a = 1.0 - v
		draw_line(from, to, col, 2.0)

	# 가운데 번쩍 — 파란 원이 한 번 보였다 사라진다
	if t < flash_part:
		var k: float = t / flash_part
		var ring := ring_color
		ring.a = 1.0 - k
		draw_circle(Vector2.ZERO, flash_radius * s * (0.6 + 0.6 * k), ring)
		var hot := core_color
		hot.a = 1.0 - k
		draw_circle(Vector2.ZERO, flash_radius * s * 0.55 * (1.0 - 0.5 * k), hot)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 원의 왼쪽(공격자 쪽, 각도 PI 둘레) 호를 두께가 양 끝으로 줄어드는 띠로 그린다.
## 끝에서 두께가 0이 되므로 다각형 분할 대신 칸마다 `draw_primitive`로 그린다
func _draw_crescent(center: Vector2, radius: float, half: float, thick: float, col: Color) -> void:
	var steps: int = 20
	var cols := PackedColorArray([col, col, col, col])
	var prev_in: Vector2
	var prev_out: Vector2
	for i in steps + 1:
		var f: float = float(i) / float(steps)
		var a: float = PI - half + 2.0 * half * f
		var w: float = thick * sin(f * PI)
		var d := Vector2.from_angle(a)
		var p_in: Vector2 = center + d * (radius - w * 0.5)
		var p_out: Vector2 = center + d * (radius + w * 0.5)
		if i > 0:
			draw_primitive(PackedVector2Array([prev_in, prev_out, p_out, p_in]), cols, PackedVector2Array())
		prev_in = p_in
		prev_out = p_out
