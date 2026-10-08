extends Control

## 승리 → 패배 사이의 와이프 — **패자 쪽 화면 끝에서** 어두운 막이 지그재그 앞날을 세우고 확 덮친다.
## 앞날에는 밝은 보라 선 하나와 그 뒤 옅은 줄 하나가 따라붙어 "번쩍" 하고 지나가는 맛을 낸다.
## `progress`(0~1, 1이면 화면을 다 덮음)와 `modulate.a`(걷어낼 때)를 `MatchEnding`이 넣는다

## 막 색 — 패배 화면 바탕(#251F55)과 같게
@export var color: Color = Color(0.145, 0.122, 0.333)
## 앞날 선 색·굵기
@export var edge_color: Color = Color(0.74, 0.68, 1.0)
@export var edge_width: float = 8.0
## 앞날 뒤를 따라오는 옅은 줄 색·굵기·거리(px)
@export var stripe_color: Color = Color(0.42, 0.37, 0.8, 0.9)
@export var stripe_width: float = 5.0
@export var stripe_gap: float = 26.0
## 지그재그 이빨 수와 깊이(px)
@export var teeth: int = 6
@export var teeth_depth: float = 48.0
## 앞날 기울기(px) — 위쪽이 아래쪽보다 이만큼 앞선다
@export var slant: float = 170.0

## true면 오른쪽 끝에서 왼쪽으로 덮친다(패자가 오른쪽 = P2)
var from_right: bool = true
## 0 = 아직 화면 밖, 1 = 화면을 다 덮음
var progress: float = 0.0:
	set(value):
		progress = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if progress <= 0.0:
		return
	var w: float = size.x
	var h: float = size.y
	# 앞날 x(가운데 높이 기준)가 화면 밖 → 반대편 화면 밖까지 간다
	var start_x: float = -slant * 0.5 - 24.0
	var end_x: float = w + slant * 0.5 + teeth_depth + 24.0
	var edge_x: float = lerpf(start_x, end_x, clampf(progress, 0.0, 1.0))
	var edge := PackedVector2Array()
	var steps: int = maxi(teeth, 1) * 2
	for k in steps + 1:
		var y: float = lerpf(-20.0, h + 20.0, float(k) / float(steps))
		var lean: float = slant * (0.5 - y / maxf(h, 1.0))
		var bite: float = -teeth_depth if k % 2 == 1 else 0.0
		edge.append(Vector2(edge_x + lean + bite, y))
	# 뒤쪽은 화면 밖 멀리 — 막이 늘 넓이를 가져서 다각형이 찌그러지지 않는다
	var far_x: float = -slant - teeth_depth - 400.0
	var poly := PackedVector2Array([Vector2(far_x, -20.0)])
	poly.append_array(edge)
	poly.append(Vector2(far_x, h + 20.0))
	var stripe := PackedVector2Array()
	for p in edge:
		stripe.append(p - Vector2(stripe_gap, 0.0))
	if from_right:
		poly = _mirror(poly, w)
		edge = _mirror(edge, w)
		stripe = _mirror(stripe, w)
	draw_colored_polygon(poly, color)
	draw_polyline(stripe, stripe_color, stripe_width, true)
	draw_polyline(edge, edge_color, edge_width, true)

static func _mirror(points: PackedVector2Array, w: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(Vector2(w - p.x, p.y))
	return out
