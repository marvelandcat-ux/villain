extends Node2D

## 대전 화면 위에 까는 월드 좌표 격자(G + ' 로 켜고 끔, `Stage`가 붙인다).
## 카메라가 보는 범위만 매 프레임 다시 그린다. `step`px마다 옅은 선, `major_every`칸마다 진한 선 + 좌표 숫자, 원점(0,0) 축은 따로 색

@export var step: float = 50.0
@export var major_every: int = 2
@export var line_color: Color = Color(1, 1, 1, 0.18)
@export var major_color: Color = Color(1, 1, 1, 0.4)
@export var axis_color: Color = Color(1, 0.85, 0.2, 0.7)
@export var font_size: int = 10

func _ready() -> void:
	z_index = 100
	z_as_relative = false

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var view: Rect2 = get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	# 이 노드의 로컬 좌표로(맵 원점에 붙어 있으니 보통 그대로)
	view = get_global_transform().affine_inverse() * view
	var zoom: float = get_viewport().get_canvas_transform().get_scale().x
	var width: float = 1.0 / maxf(zoom, 0.01)
	var font: Font = ThemeDB.fallback_font
	var fs: int = int(round(font_size / maxf(zoom, 0.01)))
	var x0: int = int(floorf(view.position.x / step))
	var x1: int = int(ceilf(view.end.x / step))
	var y0: int = int(floorf(view.position.y / step))
	var y1: int = int(ceilf(view.end.y / step))
	for i in range(x0, x1 + 1):
		var x: float = i * step
		var major: bool = i % major_every == 0
		var c: Color = axis_color if i == 0 else (major_color if major else line_color)
		draw_line(Vector2(x, view.position.y), Vector2(x, view.end.y), c, width)
		if major:
			draw_string(font, Vector2(x + 2.0 * width, view.position.y + fs + 2.0 * width), str(int(x)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, major_color)
	for j in range(y0, y1 + 1):
		var y: float = j * step
		var major_y: bool = j % major_every == 0
		var cy: Color = axis_color if j == 0 else (major_color if major_y else line_color)
		draw_line(Vector2(view.position.x, y), Vector2(view.end.x, y), cy, width)
		if major_y:
			draw_string(font, Vector2(view.position.x + 2.0 * width, y - 2.0 * width), str(int(y)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, major_color)
