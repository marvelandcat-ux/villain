extends Node2D

## 연행 장면(ArrestScene)의 **포승줄 한 토막** — 두 점 사이를 축 처진 곡선으로 잇는다.
## 진한 테두리 + 갈색 줄 + 비스듬한 꼬임 결로 그려서 게임 그림체(두꺼운 외곽선)와 맞춘다.
## 끝점에 손목을 감은 고리를, 시작점에 늘어진 꼬리를 달 수 있다.
## 자리·처짐·굵기는 ArrestScene이 매 프레임 `set_rope()`로 넣는다(손이 걸음마다 들썩이므로)

@export var rope_color: Color = Color(0.71, 0.48, 0.25)
@export var rope_dark: Color = Color(0.46, 0.29, 0.13)
@export var line_color: Color = Color(0.13, 0.07, 0.03)
## 테두리 두께(px, 한쪽)
@export var line_width: float = 1.6

var from_point: Vector2 = Vector2.ZERO
var to_point: Vector2 = Vector2.ZERO
## 가운데가 아래로 처지는 깊이(px)
var sag: float = 20.0
## 줄 굵기(px)
var thickness: float = 5.0
## 시작점에서 아래로 늘어뜨린 꼬리 길이(px). 0이면 없다
var tail_length: float = 0.0
## 끝점에 손목을 감은 고리를 그릴지
var loop_at_end: bool = true

## 두 점·처짐·굵기를 한 번에 넣고 다시 그린다
func set_rope(a: Vector2, b: Vector2, sag_px: float, thick: float) -> void:
	from_point = a
	to_point = b
	sag = sag_px
	thickness = maxf(thick, 1.0)
	queue_redraw()

func _draw() -> void:
	if tail_length > 0.5:
		var t0: Vector2 = from_point
		var t2: Vector2 = from_point + Vector2(thickness * 1.8, tail_length)
		var t1: Vector2 = from_point + Vector2(thickness * 3.2, tail_length * 0.45)
		_strand(_bezier(t0, t1, t2, 12), true)
	var mid: Vector2 = (from_point + to_point) * 0.5 + Vector2(0.0, sag * 2.0)
	_strand(_bezier(from_point, mid, to_point, 28), false)
	if loop_at_end:
		_loop(to_point)

## 2차 베지어 — 가운데 조절점을 처짐의 두 배만큼 내리면 곡선의 가장 낮은 곳이 딱 처짐만큼 내려간다
static func _bezier(a: Vector2, c: Vector2, b: Vector2, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var t: float = float(i) / steps
		var u: float = 1.0 - t
		pts.append(a * (u * u) + c * (2.0 * u * t) + b * (t * t))
	return pts

## 줄 한 가닥 — 테두리 → 갈색 → 꼬임 결 → 둥근 끝
func _strand(pts: PackedVector2Array, frayed_end: bool) -> void:
	if pts.size() < 2:
		return
	var outer: float = thickness + line_width * 2.0
	draw_polyline(pts, line_color, outer, true)
	draw_circle(pts[0], outer * 0.5, line_color)
	draw_circle(pts[pts.size() - 1], outer * 0.5, line_color)
	draw_polyline(pts, rope_color, thickness, true)
	draw_circle(pts[0], thickness * 0.5, rope_color)
	draw_circle(pts[pts.size() - 1], thickness * 0.5, rope_color)
	# 꼬임 결 — 줄을 따라 일정 간격으로 비스듬한 짧은 선
	var step: float = maxf(thickness * 1.5, 3.0)
	var next_at: float = step * 0.5
	var walked: float = 0.0
	for i in range(1, pts.size()):
		var seg: Vector2 = pts[i] - pts[i - 1]
		var length: float = seg.length()
		if length < 0.001:
			continue
		var dir: Vector2 = seg / length
		var nrm := Vector2(-dir.y, dir.x)
		while next_at <= walked + length:
			var p: Vector2 = pts[i - 1] + dir * (next_at - walked)
			var half: Vector2 = (nrm * 0.5 + dir * 0.32) * thickness
			draw_line(p - half, p + half, rope_dark, maxf(thickness * 0.3, 1.0), true)
			next_at += step
		walked += length
	if frayed_end:
		# 꼬리 끝은 풀린 실 몇 가닥
		var end: Vector2 = pts[pts.size() - 1]
		var back: Vector2 = (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized()
		for k: float in [-1.0, 0.0, 1.0]:
			var side: Vector2 = Vector2(-back.y, back.x) * k * thickness * 0.45
			draw_line(end + side, end + side + (back + Vector2(-back.y, back.x) * k * 0.4).normalized() * thickness * 1.1,
				line_color, maxf(thickness * 0.28, 1.0), true)

## 손목(수갑)을 한 바퀴 감은 고리
func _loop(c: Vector2) -> void:
	var rx: float = thickness * 1.25
	var ry: float = thickness * 2.1
	var pts := PackedVector2Array()
	for i in 25:
		var t: float = TAU * i / 24.0
		pts.append(c + Vector2(cos(t) * rx, sin(t) * ry))
	draw_polyline(pts, line_color, thickness * 0.8 + line_width * 2.0, true)
	draw_polyline(pts, rope_color, thickness * 0.8, true)
	draw_line(c + Vector2(-rx, -ry * 0.2), c + Vector2(rx, ry * 0.2), rope_dark, maxf(thickness * 0.3, 1.0), true)
