extends Control

## 맵 선택 화면의 임시 우주 배경 — 보라색 하늘 + 반짝이는 별(그림 없이 `_draw()`). 스프라이트를 받으면 여기를 바꿀 것

@export var top_color: Color = Color(0.13, 0.08, 0.38)
@export var bottom_color: Color = Color(0.2, 0.12, 0.55)
@export var star_count: int = 140
## 십자 모양으로 반짝이는 큰 별 개수
@export var sparkle_count: int = 10
@export var star_color: Color = Color(0.85, 0.85, 1.0)

## 별 하나: x, y(0~1), 크기(px), 깜빡임 박자
var _stars: Array[Vector4] = []
var _sparkles: Array[Vector4] = []
var _time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in star_count:
		_stars.append(Vector4(rng.randf(), rng.randf(), rng.randf_range(0.6, 1.8), rng.randf() * TAU))
	for i in sparkle_count:
		_sparkles.append(Vector4(rng.randf(), rng.randf(), rng.randf_range(4.0, 8.0), rng.randf() * TAU))

func _process(delta: float) -> void:
	_time += minf(delta, 0.05)
	queue_redraw()

func _draw() -> void:
	var colors := PackedColorArray([top_color, top_color, bottom_color, bottom_color])
	var pts := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	draw_primitive(pts, colors, PackedVector2Array())
	for s in _stars:
		var c: Color = star_color
		c.a = 0.35 + 0.45 * (0.5 + 0.5 * sin(_time * 1.6 + s.w))
		draw_circle(Vector2(s.x * size.x, s.y * size.y), s.z, c)
	for s in _sparkles:
		var at := Vector2(s.x * size.x, s.y * size.y)
		var k: float = 0.6 + 0.4 * sin(_time * 2.2 + s.w)
		var c: Color = star_color
		c.a = 0.9 * k
		var r: float = s.z * k
		draw_line(at - Vector2(r, 0), at + Vector2(r, 0), c, 1.5, true)
		draw_line(at - Vector2(0, r), at + Vector2(0, r), c, 1.5, true)
		draw_circle(at, 1.6, c)
