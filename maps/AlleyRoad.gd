extends Node2D

## 번화가 가운데 골목의 **멀어지는 도로 한 토막**(2026-10-08). `DowntownAlley`가 깊이 층마다 하나씩 만든다.
## 앞면(싸우는 층)에서 소실점으로 모이는 사다리꼴 중 깊이 `t_from`~`t_to` 구간만 그린다 — 층마다 시차가 달라서
## 도로도 층별로 끊어 그려야 건물과 같이 밀린다. 그림 없이 `_draw()`: 아스팔트 + 양쪽 인도 띠 + 가운데 점선(멀수록 짧고 촘촘)

## 소실점(월드) / 앞면 도로 양 끝 x / 앞면 도로 y
var vanish: Vector2 = Vector2(11.0, 236.0)
var front_left: float = -366.0
var front_right: float = 388.0
var front_y: float = 286.0
## 이 토막이 맡는 깊이 구간(0 = 앞면, 1 = 소실점)
var t_from: float = 0.0
var t_to: float = 0.4

var asphalt: Color = Color(0.16, 0.16, 0.2)
var sidewalk: Color = Color(0.3, 0.29, 0.34)
var curb: Color = Color(0.5, 0.48, 0.5)
var lane: Color = Color(0.85, 0.72, 0.25, 0.85)
## 인도 폭(앞면에서, 도로 반폭 대비 비율) / 점선 개수(앞면~소실점 전체 기준)
var sidewalk_ratio: float = 0.12
var dash_count: int = 14

func _draw() -> void:
	var a: Vector2 = _edge(front_left, t_from)
	var b: Vector2 = _edge(front_right, t_from)
	var c: Vector2 = _edge(front_right, t_to)
	var d: Vector2 = _edge(front_left, t_to)
	draw_polygon(PackedVector2Array([a, b, c, d]), PackedColorArray([asphalt, asphalt, asphalt, asphalt]))
	# 인도 — 도로 양 가장자리 안쪽 띠(멀수록 같이 좁아진다)
	var w0: float = (front_right - front_left) * sidewalk_ratio
	for side in [-1.0, 1.0]:
		var outer_x: float = front_left if side < 0.0 else front_right
		var inner_x: float = outer_x - side * w0
		var p0: Vector2 = _edge(outer_x, t_from)
		var p1: Vector2 = _edge(inner_x, t_from)
		var p2: Vector2 = _edge(inner_x, t_to)
		var p3: Vector2 = _edge(outer_x, t_to)
		draw_polygon(PackedVector2Array([p0, p1, p2, p3]), PackedColorArray([sidewalk, sidewalk, sidewalk, sidewalk]))
		# 연석 선
		draw_line(p1, p2, curb, 1.5, true)
	# 가운데 점선 — 깊이를 균등하게 나누면 멀수록 화면에서 짧아진다
	var mid_x: float = (front_left + front_right) * 0.5
	var step: float = 1.0 / maxf(dash_count, 1)
	var t: float = 0.0
	while t < 1.0:
		var t0: float = t
		var t1: float = t + step * 0.55
		t += step
		if t1 <= t_from or t0 >= t_to:
			continue
		t0 = maxf(t0, t_from)
		t1 = minf(t1, t_to)
		var width: float = lerpf(3.0, 0.8, (t0 + t1) * 0.5)
		draw_line(_edge(mid_x, t0), _edge(mid_x, t1), lane, width, true)

## 앞면 x를 깊이 t만큼 소실점 쪽으로 보낸 자리
func _edge(x: float, t: float) -> Vector2:
	return Vector2(x, front_y).lerp(vanish, t)
