extends RefCounted

## 굵은 선·꽉 찬 원 여러 개를 **삼각형 묶음 하나**로 쌓았다가 한 번에 그린다(그리기 한 번 = draw call 하나).
## `draw_polyline`/`draw_circle`은 부를 때마다 그리기가 하나씩 늘어서, 연행 장면의 나무·구름·줄눈·경찰차 외곽선
## 수백 개를 그것으로 그리면 30fps까지 떨어졌다(2026-10-08 실측, RTX 5070).
## 선 모양은 `draw_polyline(antialiased = true)`과 같다 — 꺾이는 점은 앞뒤 변의 바깥 방향을 평균 내고,
## 양옆에 1px짜리 투명해지는 가장자리를 붙인다. 원은 `draw_circle` 기본값처럼 안티에일리어싱이 없다.
## 넣은 순서대로 칠해진다(뒤에 넣은 것이 위). class_name은 일부러 안 단다 — 쓰는 쪽에서 preload한다

const FEATHER := 1.0

var points := PackedVector2Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()

## 선 하나(cols는 점마다 색, 한 개면 전체 한 색). closed면 끝점과 첫 점도 잇는다
func add_line(pts: PackedVector2Array, cols: PackedColorArray, width: float, closed: bool = false) -> void:
	var n: int = pts.size()
	if n < 2 or cols.is_empty():
		return
	var base: int = points.size()
	var half: float = width * 0.5
	for i in n:
		var t := Vector2.ZERO
		if closed or i > 0:
			t += _normal(pts[(i - 1 + n) % n], pts[i])
		if closed or i < n - 1:
			t += _normal(pts[i], pts[(i + 1) % n])
		t = t.normalized()
		var c: Color = cols[i] if cols.size() == n else cols[0]
		var clear := Color(c, 0.0)
		points.append(pts[i] + t * (half + FEATHER))
		points.append(pts[i] + t * half)
		points.append(pts[i] - t * half)
		points.append(pts[i] - t * (half + FEATHER))
		colors.append(clear)
		colors.append(c)
		colors.append(c)
		colors.append(clear)
	for i in (n if closed else n - 1):
		var a: int = base + i * 4
		var b: int = base + ((i + 1) % n) * 4
		for strip in 3:
			indices.append(a + strip)
			indices.append(b + strip)
			indices.append(b + strip + 1)
			indices.append(a + strip)
			indices.append(b + strip + 1)
			indices.append(a + strip + 1)

## 꽉 찬 원. sides가 0이면 반지름에 맞춰 정한다
func add_disc(center: Vector2, radius: float, color: Color, sides: int = 0) -> void:
	if radius <= 0.0:
		return
	var seg: int = sides if sides > 2 else clampi(int(radius * 0.9), 18, 64)
	var base: int = points.size()
	points.append(center)
	colors.append(color)
	for k in seg:
		points.append(center + Vector2.from_angle(TAU * float(k) / float(seg)) * radius)
		colors.append(color)
	for k in seg:
		indices.append(base)
		indices.append(base + 1 + k)
		indices.append(base + 1 + (k + 1) % seg)

## 볼록한 도형 하나를 꽉 채운다(첫 점에서 부채꼴로 삼각형을 쌓는다 — 오목하면 삐져나온다)
func add_fill(pts: PackedVector2Array, color: Color) -> void:
	if pts.size() < 3:
		return
	var base: int = points.size()
	for v in pts:
		points.append(v)
		colors.append(color)
	for k in range(1, pts.size() - 1):
		indices.append(base)
		indices.append(base + k)
		indices.append(base + k + 1)

func is_empty() -> bool:
	return indices.is_empty()

## 쌓은 것을 canvas에 한 번에 그린다 — canvas의 `_draw()` 안에서 부를 것
func draw_on(canvas: CanvasItem) -> void:
	if indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), indices, points, colors)

static func _normal(a: Vector2, b: Vector2) -> Vector2:
	var d: Vector2 = b - a
	if d.length_squared() < 0.00000001:
		return Vector2.ZERO
	return Vector2(-d.y, d.x).normalized()
