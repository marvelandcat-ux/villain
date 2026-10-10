extends Node2D

## 무기 스미어 — 휘두른 무기가 지나간 자리를 **속이 꽉 찬 초승달 띠**로 남긴다(2026-10-10 사용자 레퍼런스: 격투 게임 칼 스미어).
## `SwingTrail`(끝 한 점을 따라가는 흰 선)과 달리 **손잡이 쪽 ~ 끝 쪽 두 줄**을 기록해 그 사이를 칠한다.
## 띠 색은 무기 그림에서 뽑은 **길이 방향 색 줄무늬**(`bands`, 손잡이 → 끝) — 소주병이면 병목 초록 / 라벨 흰 / 바닥 초록.
## 바깥(끝이 지나간 선)은 무기 윤곽선 색으로 두른다. 오래된 자리일수록 띠가 끝 쪽으로 오그라들어 꼬리가 뾰족해진다.
## BodyRig가 `add_sample()`로 자리를 넣고 다 휘둘렀으면 `finish()`. **맵에 붙일 것**(SwingTrail과 같은 이유)

## 카운터 히트 연출 — 궤적을 길게 남길 때인지·흐림 위로 올릴 때인지를 여기서 읽는다(class_name이 없어 preload)
const _COUNTER_FX := preload("res://combat/CounterHitFx.gd")

## 자리 하나가 남아 있는 시간(초) — 길수록 꼬리가 길다
@export var life: float = 0.13
## 바깥 테두리 굵기(px)
@export var outline_width: float = 2.0
## 띠 전체 진하기
@export_range(0.0, 1.0, 0.05) var opacity: float = 0.9

## 손잡이 → 끝 순서의 색 줄무늬(무기 그림에서 뽑는다, BodyRig가 넣는다)
var bands: PackedColorArray = PackedColorArray([Color.WHITE])
## 테두리 색(무기 윤곽선)
var outline_color: Color = Color(0.05, 0.05, 0.06)

var _time: float = 0.0
var _finished: bool = false
var _last_add: float = 0.0
## 손잡이 쪽 / 끝 쪽 자리(맵 좌표)와 그때의 _time — 오래된 것이 앞
var _inner: PackedVector2Array = PackedVector2Array()
var _tip: PackedVector2Array = PackedVector2Array()
var _times: PackedFloat32Array = PackedFloat32Array()

func add_sample(inner_global: Vector2, tip_global: Vector2) -> void:
	if _finished:
		return
	if not _tip.is_empty() and _tip[_tip.size() - 1].distance_to(tip_global) < 0.5:
		return
	_inner.append(inner_global)
	_tip.append(tip_global)
	_times.append(_time)
	_last_add = _time

func finish() -> void:
	_finished = true

func _ready() -> void:
	global_position = Vector2.ZERO

func _process(delta: float) -> void:
	# 카운터 히트 창이면 **실제 시간**으로 늙되 한 점이 TRAIL_TIME(1.5초)을 살게 늘린다 — 슬로(0.4배)가 1초에 끝나도 그대로
	if _COUNTER_FX.trail_active():
		var real_dt: float = minf(delta / maxf(Engine.time_scale, 0.01), 0.05)
		_time += real_dt * life / _COUNTER_FX.TRAIL_TIME
	else:
		_time += minf(delta, 0.05)
	_raise_above_blur(_COUNTER_FX.focus_active)
	if not _finished and _time - _last_add > 0.5:
		_finished = true
	while not _times.is_empty() and _time - _times[0] >= life:
		_inner.remove_at(0)
		_tip.remove_at(0)
		_times.remove_at(0)
	if _finished and _times.is_empty():
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var n: int = _times.size()
	if n < 2 or bands.is_empty():
		return
	var nb: int = bands.size()
	# 자리마다 띠가 차지하는 폭(0 = 끝 선만, 1 = 손잡이까지 전부)과 진하기
	var cover := PackedFloat32Array()
	var alpha := PackedFloat32Array()
	cover.resize(n)
	alpha.resize(n)
	for i in n:
		var k: float = clampf(1.0 - (_time - _times[i]) / maxf(life, 0.001), 0.0, 1.0)
		var along: float = float(i) / float(n - 1)
		cover[i] = k * along
		alpha[i] = opacity * pow(k, 0.6)
	var tip_l := PackedVector2Array()
	tip_l.resize(n)
	for i in n:
		tip_l[i] = to_local(_tip[i])
	# 색 줄무늬 — 끝 쪽 줄부터 손잡이 쪽으로. 줄 b는 끝에서 [b/nb, (b+1)/nb] 거리만큼(cover를 곱해 오그라든다).
	# 폭이 0이 될 수 있어 draw_primitive로 칸마다 사각형(draw_colored_polygon은 triangulation 에러)
	for b in nb:
		var col: Color = bands[nb - 1 - b]
		var f0: float = float(b) / float(nb)
		var f1: float = float(b + 1) / float(nb)
		for i in n - 1:
			var j: int = i + 1
			var in_i: Vector2 = to_local(_inner[i])
			var in_j: Vector2 = to_local(_inner[j])
			var a0: Vector2 = tip_l[i].lerp(in_i, f0 * cover[i])
			var a1: Vector2 = tip_l[i].lerp(in_i, f1 * cover[i])
			var b0: Vector2 = tip_l[j].lerp(in_j, f0 * cover[j])
			var b1: Vector2 = tip_l[j].lerp(in_j, f1 * cover[j])
			var ci := col
			ci.a *= alpha[i]
			var cj := col
			cj.a *= alpha[j]
			draw_primitive(PackedVector2Array([a0, b0, b1, a1]), PackedColorArray([ci, cj, cj, ci]), PackedVector2Array())
	# 바깥 테두리(끝이 지나간 선) — 무기 윤곽선처럼
	var cols := PackedColorArray()
	cols.resize(n)
	for i in n:
		var c := outline_color
		c.a *= alpha[i] * float(i) / float(n - 1)
		cols[i] = c
	draw_polyline_colors(tip_l, cols, outline_width, true)

## 카운터 흐림이 깔린 동안 흐림 판(CounterHitFx.BLUR_Z) **위로** 올린다 — 캐릭터와 같은 z(FOCUS_Z)라
## 트리 순서대로 캐릭터 바로 뒤에 그려진다. 흐림이 걷히면 원래 z로
var _raised: bool = false
var _saved_z: Array = []
func _raise_above_blur(on: bool) -> void:
	if on == _raised:
		return
	_raised = on
	if on:
		# 흐림이 깔린 뒤에 생긴 궤적은 이미 올라간 캐릭터 z(FOCUS_Z)를 물려받았다 — 그걸 원래 값으로 기억하면 흐림이 걷혀도 캐릭터 위에 남는다
		_saved_z = [0, true] if (z_index == _COUNTER_FX.FOCUS_Z and not z_as_relative) else [z_index, z_as_relative]
		z_as_relative = false
		z_index = _COUNTER_FX.FOCUS_Z
	elif _saved_z.size() == 2:
		z_index = _saved_z[0]
		z_as_relative = _saved_z[1]
