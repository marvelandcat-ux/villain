class_name JumpWind
extends Node2D

## 점프하는 순간 발밑에 남는 바람 줄기 (순수 장식 — 판정 없음, 2026-09-26 사용자 요청).
## 뛴 자리에 남아서 **뛰는 방향을 따라 삐죽한 흰 줄기가 뻗었다가, 뛴 자리 쪽(꼬리)부터 따라 올라가며 사라진다** —
## 캐릭터가 지나간 길에 "휙" 자국이 남는 느낌. 대각선으로 뛰면 줄기도 비스듬하다.
## 그림 없이 `_draw()`로 그리므로 스프라이트를 받으면 여기만 바꾸면 된다(LandDust와 같은 방식).
##
## `Fighter._spawn_jump_wind()`가 점프 순간 맵에 붙이고 `setup(방향, 공중 점프인지)`를 부른다

## 줄기 수 (가운데 하나가 가장 길고 양옆은 짧다)
@export var streak_count: int = 3
## 줄기 길이(px) — 지상 점프 / 공중 점프
@export var length_ground: float = 80.0
@export var length_air: float = 66.0
## 줄기 가장 굵은 곳의 폭(px)
@export var width: float = 14.0
## 양옆 줄기가 벌어지는 각도(도)와 옆으로 떨어지는 거리(px)
@export var spread_deg: float = 14.0
@export var side_offset: float = 12.0
## 줄기 끝이 다 뻗는 시간 / 꼬리가 따라 올라가기 시작하는 시간 / 전체 수명(초)
@export var grow_time: float = 0.08
@export var tail_delay: float = 0.05
@export var life: float = 0.35
## 가장자리 삐죽삐죽한 정도(폭 대비)
@export_range(0.0, 1.0, 0.05) var jagged: float = 0.55
## 색
@export var color: Color = Color(1.0, 1.0, 1.0, 0.9)
## 테두리 색과 굵기(px) — 흰색만 있으면 하늘·밝은 벽에 묻혀서 게임 그림체(검은 외곽선)에 맞춰 옅게 두른다. 0이면 안 그림
@export var outline_color: Color = Color(0.12, 0.14, 0.2, 0.55)
@export var outline_px: float = 2.0

## 줄기 하나 — 방향, 시작 위치, 길이 배수, 가장자리 흔들림(마디마다 고정된 난수)
class Streak:
	var dir: Vector2 = Vector2.UP
	var origin: Vector2 = Vector2.ZERO
	var scale: float = 1.0
	var bumps: PackedFloat32Array = PackedFloat32Array()

const SEGMENTS: int = 10

var _streaks: Array[Streak] = []
var _age: float = 0.0
var _length: float = 40.0

## dir: 뛰는 방향(월드 기준, 위쪽이 -y). air: 공중 점프면 조금 짧게
func setup(dir: Vector2, air: bool) -> void:
	z_index = -1   # 캐릭터 뒤에 깔린다
	_length = length_air if air else length_ground
	var base_dir: Vector2 = dir.normalized() if dir.length() > 0.01 else Vector2.UP
	var side: Vector2 = Vector2(-base_dir.y, base_dir.x)
	for i in streak_count:
		var s := Streak.new()
		# 가운데(0)부터 좌우로 번갈아 벌린다: 0, -1, +1, -2, ...
		var k: int = int(float(i + 1) / 2.0) * (1 if i % 2 == 0 else -1)
		s.dir = base_dir.rotated(deg_to_rad(spread_deg * k * randf_range(0.7, 1.2)))
		s.origin = side * side_offset * k + side * randf_range(-2.0, 2.0)
		s.scale = 1.0 if k == 0 else randf_range(0.55, 0.75)
		for j in SEGMENTS + 1:
			s.bumps.append(randf_range(-1.0, 1.0))
		_streaks.append(s)
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	# 끝(머리)은 grow_time 안에 다 뻗고, 꼬리는 tail_delay 뒤부터 수명 끝까지 머리 쪽으로 따라간다
	var head_t: float = clampf(_age / maxf(grow_time, 0.001), 0.0, 1.0)
	head_t = 1.0 - (1.0 - head_t) * (1.0 - head_t)
	var tail_t: float = clampf((_age - tail_delay) / maxf(life - tail_delay, 0.001), 0.0, 1.0)
	tail_t = tail_t * tail_t
	var fade: float = 1.0 - clampf((_age - tail_delay) / maxf(life - tail_delay, 0.001), 0.0, 1.0) * 0.6
	# 테두리를 먼저 전부 깔고 그 위에 흰 몸통을 칠한다 — 줄기끼리 겹쳐도 테두리가 남의 몸통을 덮지 않게
	if outline_px > 0.0 and outline_color.a > 0.0:
		var oc: Color = outline_color
		oc.a *= fade
		for s in _streaks:
			_draw_streak(s, head_t, tail_t, outline_px, oc)
	var col: Color = color
	col.a *= fade
	for s in _streaks:
		_draw_streak(s, head_t, tail_t, 0.0, col)

## 줄기 하나를 마디마다 사각형으로 나눠 그린다(extra만큼 양옆을 넓혀 테두리로도 쓴다).
## 삐죽한 모양을 다각형 하나로 그리면 분할에 실패해 에러가 날 수 있어서다(EyeBlink에서 겪음)
func _draw_streak(s: Streak, head_t: float, tail_t: float, extra: float, col: Color) -> void:
	var length: float = _length * s.scale
	var a: float = length * tail_t - extra
	var b: float = length * head_t + extra
	if b - a < 1.0 + extra * 2.0:
		return
	var normal: Vector2 = Vector2(-s.dir.y, s.dir.x)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for j in SEGMENTS + 1:
		var u: float = float(j) / SEGMENTS
		var d: float = lerpf(a, b, u)
		# 꼬리(뛴 자리 쪽)가 굵고 머리로 갈수록 뾰족해지는 불꽃 모양 — 가장자리는 마디마다 삐죽하게
		var w: float = width * s.scale * sin(PI * (0.15 + 0.85 * (1.0 - u))) * (1.0 - u * 0.6)
		var bump: float = 1.0 + s.bumps[j] * jagged
		var center: Vector2 = s.origin + s.dir * d
		left.append(center + normal * (w * 0.5 * bump + extra))
		right.append(center - normal * (w * 0.5 * (2.0 - bump) + extra))
	for j in SEGMENTS:
		draw_colored_polygon(PackedVector2Array([left[j], left[j + 1], right[j + 1], right[j]]), col)
