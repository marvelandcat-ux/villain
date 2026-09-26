class_name LaunchTrail
extends Node2D

## 기본공격 마무리 타(3타)에 맞아 날아갈 때의 이펙트 (순수 장식 — 판정 없음, 2026-09-26 사용자 레퍼런스).
## 세 가지를 한 노드에서 그린다:
## ① 맞는 순간 터지는 충격 — 맞은 자리에서 삐죽한 가시가 사방(날아가는 쪽으로 더 길게)으로 튀고 고리가 퍼진다
## ② 뒤로 끌리는 바람 줄기 — 날아가는 동안 몸 뒤로 삐죽한 흰 줄기가 따라온다(속도가 빠를수록 길다)
## ③ 줄지어 남는 먼지 고리 — 지나간 길에 C자 고리가 간격을 두고 남았다가 부풀며 사라진다(입이 날아가는 쪽을 향함)
## 흰색 + 옅은 어두운 테두리 — 점프 바람·착지 먼지와 같은 톤. 그림 없이 `_draw()`로 그린다.
##
## **맵에 붙고 노드는 원점에 둔 채 월드 좌표를 to_local로 바꿔 그린다** — 맞은 사람의 자식으로 달면 그 사람이 좌우로
## 뒤집힐 때 이펙트도 뒤집힌다. `ComboMeleeAttack._launch_finisher()`가 `setup(맞은 사람, 날아가는 방향)`을 부른다

## 땅에 닿거나 느려지기 전까지 따라다니는 최대 시간(초)
@export var max_follow: float = 1.2
## 따라다니기를 멈추는 속도(px/초) — 이보다 느려지면 "다 날아갔다"로 본다
@export var stop_speed: float = 90.0

@export_group("충격")
## 가시 수·길이(px)·굵기(px), 충격이 보이는 시간(초), 퍼지는 고리 반지름(px) — 2026-09-26 사용자 요청으로 크게 키움(9개·34·4·0.22초·30)
@export var burst_spikes: int = 12
@export var burst_length: float = 58.0
@export var burst_spike_width: float = 7.0
@export var burst_time: float = 0.3
@export var burst_ring_radius: float = 52.0
## 맞는 첫 순간 가운데가 번쩍하는 원의 반지름(px)과 보이는 비율(충격 시간 대비) — 0이면 안 나옴
@export var burst_flash_radius: float = 18.0
@export var burst_flash_part: float = 0.35

@export_group("바람 줄기")
@export var streak_count: int = 3
## 줄기 길이 = 속도 x 이 값(px), 최대 streak_max
@export var streak_per_speed: float = 0.09
@export var streak_max: float = 70.0
@export var streak_width: float = 12.0

@export_group("먼지 고리")
## 이만큼(px) 날아갈 때마다 고리를 하나 남긴다
@export var ring_spacing: float = 44.0
@export var ring_radius: float = 9.0
@export var ring_life: float = 0.4
## C자 입 크기(도) — 날아가는 쪽이 뚫려 있다
@export var ring_gap_deg: float = 80.0

@export_group("색")
@export var color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var outline_color: Color = Color(0.12, 0.14, 0.2, 0.55)
@export var outline_px: float = 2.0

## 남긴 고리 하나 — 월드 위치, 날아가던 방향, 나이
class Ring:
	var pos: Vector2
	var dir: Vector2
	var age: float = 0.0

const SEGMENTS: int = 8

var _target: Node2D
var _had_target: bool = false
var _following: bool = true
var _age: float = 0.0
var _follow_age: float = 0.0
var _burst_pos: Vector2
var _burst_dir: Vector2 = Vector2.RIGHT
var _spike_angles: PackedFloat32Array = PackedFloat32Array()
var _spike_lengths: PackedFloat32Array = PackedFloat32Array()
var _rings: Array[Ring] = []
var _last_ring_pos: Vector2
var _trail_pos: Vector2
var _trail_vel: Vector2 = Vector2.ZERO
var _streak_bumps: Array[PackedFloat32Array] = []
var _streak_fade: float = 1.0

## target: 날아가는 사람(Fighter). dir: 날아가는 방향(월드 기준)
func setup(target: Node2D, dir: Vector2) -> void:
	z_index = 5   # 캐릭터 앞에 살짝 — 충격·줄기가 몸에 가려지지 않게
	position = Vector2.ZERO
	_target = target
	_had_target = target != null
	_burst_pos = target.global_position
	_burst_dir = dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	_last_ring_pos = _burst_pos
	_trail_pos = _burst_pos
	# 가시는 사방으로 퍼지되 날아가는 쪽이 더 길다
	for i in burst_spikes:
		var ang: float = TAU * float(i) / burst_spikes + randf_range(-0.2, 0.2)
		_spike_angles.append(ang)
		var along: float = maxf(0.0, Vector2.from_angle(ang).dot(_burst_dir))
		_spike_lengths.append(burst_length * randf_range(0.6, 0.9) * (0.7 + 0.8 * along))
	for i in streak_count:
		var bumps := PackedFloat32Array()
		for j in SEGMENTS + 1:
			bumps.append(randf_range(-1.0, 1.0))
		_streak_bumps.append(bumps)
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	var alive: Array[Ring] = []
	for r in _rings:
		r.age += delta
		if r.age < ring_life:
			alive.append(r)
	_rings = alive
	if _following:
		_follow(delta)
	else:
		_streak_fade = maxf(_streak_fade - delta * 6.0, 0.0)
		if _rings.is_empty() and _age > burst_time and _streak_fade <= 0.0:
			queue_free()
			return
	queue_redraw()

## 날아가는 사람을 따라가며 고리를 남긴다. 땅에 닿았거나 느려졌거나 사라졌으면 멈춘다
func _follow(delta: float) -> void:
	_follow_age += delta
	if _had_target and not is_instance_valid(_target):
		_following = false
		return
	var now: Vector2 = _target.global_position
	_trail_vel = (now - _trail_pos) / maxf(delta, 0.0001)
	_trail_pos = now
	var landed: bool = _follow_age > 0.12 and _target.has_method("is_on_floor") and _target.is_on_floor()
	if landed or _follow_age > max_follow or (_follow_age > 0.12 and _trail_vel.length() < stop_speed):
		_following = false
		return
	var moved: Vector2 = now - _last_ring_pos
	if moved.length() >= ring_spacing:
		var r := Ring.new()
		r.pos = now
		r.dir = moved.normalized()
		_rings.append(r)
		_last_ring_pos = now

func _draw() -> void:
	if outline_px > 0.0 and outline_color.a > 0.0:
		_draw_all(outline_px, outline_color)
	_draw_all(0.0, color)

## 모든 요소를 한 겹 그린다 — 테두리(extra > 0)를 먼저 전부 깔고 흰 몸통을 위에 칠한다
func _draw_all(extra: float, col: Color) -> void:
	_draw_burst(extra, col)
	_draw_rings(extra, col)
	_draw_streaks(extra, col)

## ① 충격: 가시가 튀어나갔다 줄어들고, 고리가 퍼지며 옅어진다
func _draw_burst(extra: float, col: Color) -> void:
	var t: float = _age / burst_time
	if t >= 1.0:
		return
	var center: Vector2 = to_local(_burst_pos)
	var c := col
	c.a *= 1.0 - t
	var out_t: float = 1.0 - (1.0 - t) * (1.0 - t)
	# 첫 순간 가운데 섬광 — 크게 번쩍했다가 빠르게 줄어든다
	if burst_flash_radius > 0.0 and t < burst_flash_part:
		var ft: float = t / maxf(burst_flash_part, 0.001)
		draw_circle(center, burst_flash_radius * (1.0 - ft * 0.6) + extra, Color(col, col.a * (1.0 - ft)))
	for i in _spike_angles.size():
		var d: Vector2 = Vector2.from_angle(_spike_angles[i])
		var n: Vector2 = Vector2(-d.y, d.x)
		var inner: float = 12.0 + 20.0 * out_t
		var outer: float = inner + _spike_lengths[i] * (1.0 - t * 0.5)
		var w: float = burst_spike_width * (1.0 - t) + extra
		draw_colored_polygon(PackedVector2Array([
			center + d * (inner - extra), center + d * inner * 0.9 + n * w,
			center + d * (outer + extra), center + d * inner * 0.9 - n * w]), c)
	draw_arc(center, burst_ring_radius * (0.4 + 0.9 * out_t), 0.0, TAU, 40, c, 5.0 * (1.0 - t) + 1.5 + extra * 2.0)

## ③ 먼지 고리: 날아가는 쪽에 입이 뚫린 C자 — 부풀며 옅어진다
func _draw_rings(extra: float, col: Color) -> void:
	var gap: float = deg_to_rad(ring_gap_deg) * 0.5
	for r in _rings:
		var t: float = r.age / ring_life
		var c := col
		c.a *= 1.0 - t
		var radius: float = ring_radius * (0.7 + 0.8 * t)
		var ang: float = r.dir.angle()
		draw_arc(to_local(r.pos), radius, ang + gap, ang + TAU - gap, 20, c, 3.5 * (1.0 - t * 0.5) + extra * 2.0)

## ② 바람 줄기: 몸 뒤(날아가는 반대쪽)로 삐죽한 줄기 — 속도가 빠를수록 길다
func _draw_streaks(extra: float, col: Color) -> void:
	if _streak_fade <= 0.0 or not is_instance_valid(_target) or _trail_vel.length() < 1.0:
		return
	var back: Vector2 = -_trail_vel.normalized()
	var side: Vector2 = Vector2(-back.y, back.x)
	var length: float = minf(_trail_vel.length() * streak_per_speed, streak_max)
	var base: Vector2 = to_local(_target.global_position)
	var c := col
	c.a *= _streak_fade
	for i in _streak_bumps.size():
		var k: float = float(i) - float(_streak_bumps.size() - 1) * 0.5
		var origin: Vector2 = base + side * k * 12.0 + back * 10.0
		var len_i: float = length * (1.0 if absf(k) < 0.5 else 0.7)
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		for j in SEGMENTS + 1:
			var u: float = float(j) / SEGMENTS
			var w: float = streak_width * (1.0 - u) * (0.6 + 0.4 * sin(PI * (0.3 + 0.7 * u)))
			var bump: float = 1.0 + _streak_bumps[i][j] * 0.5
			var center: Vector2 = origin + back * len_i * u
			left.append(center + side * (w * 0.5 * bump + extra))
			right.append(center - side * (w * 0.5 * (2.0 - bump) + extra))
		for j in SEGMENTS:
			draw_colored_polygon(PackedVector2Array([left[j], left[j + 1], right[j + 1], right[j]]), c)
