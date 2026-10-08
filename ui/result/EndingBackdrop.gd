extends Control

## 승리·패배 화면의 바탕 — 그림 파일 없이 `_draw()`로 그린다.
##  - SUNBURST: 밝은 노랑 + 인물 머리에서 뻗어 천천히 도는 햇살 줄무늬 + 머리 뒤 은은한 빛
##  - NIGHT: 진한 남색(위가 조금 더 어둡다)
##  - VIGNETTE: 가장자리만 어둡게 누르는 막 — 패배 화면 맨 위에 한 장 더 깐다
## 시간은 `MatchEnding`이 `tick()`으로 넣어 준다(실제 시간 — 슬로 연출에 안 흔들리게)

enum Style { SUNBURST, NIGHT, VIGNETTE }

@export var style: Style = Style.SUNBURST
## 바탕색(NIGHT면 아래쪽 색)
@export var base_color: Color = Color(1.0, 0.894, 0.361)
## NIGHT일 때 위쪽 색
@export var top_color: Color = Color(0.1, 0.08, 0.24)

@export_group("햇살")
## 줄무늬 색 — 바탕보다 살짝만 밝게(인물·색종이보다 튀면 안 된다)
@export var ray_color: Color = Color(1.0, 0.94, 0.56)
## 줄 수
@export var ray_count: int = 16
## 도는 빠르기(라디안/초)
@export var ray_spin_speed: float = 0.14
## 한 칸에서 줄이 차지하는 몫
@export_range(0.1, 0.9, 0.05) var ray_fill: float = 0.5
## 머리 뒤 빛의 반지름(화면 높이 비율)과 색. 알파 0이면 안 그린다
@export var glow_radius: float = 0.55
@export var glow_color: Color = Color(1.0, 1.0, 0.9, 0.55)

@export_group("비네팅")
@export var vignette_color: Color = Color(0.02, 0.01, 0.08, 0.82)
## 화면 가운데에서 어두워지기 시작하는 자리(0 = 가운데, 1 = 모서리 쪽)
@export_range(0.0, 1.0, 0.05) var vignette_start: float = 0.42

## 햇살·빛의 가운데(화면 좌표) — MatchEnding이 인물 머리 자리를 넣는다
var focus: Vector2 = Vector2(320, 300)

## 흔들림 등으로 가장자리가 비치지 않게 화면보다 이만큼 넓게 칠한다
const MARGIN := 80.0

var _spin: float = 0.0
var _soft_disc: GradientTexture2D
var _vignette: GradientTexture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_soft_disc = _radial_texture([0.0, 0.55, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	var clear := Color(vignette_color, 0.0)
	_vignette = _radial_texture([0.0, vignette_start, 1.0], [clear, clear, vignette_color])

## 한 프레임 진행(dt = 실제 초)
func tick(dt: float) -> void:
	if style == Style.SUNBURST:
		_spin = fmod(_spin + ray_spin_speed * dt, TAU)
	queue_redraw()

func _draw() -> void:
	var full := Rect2(-Vector2(MARGIN, MARGIN), size + Vector2(MARGIN, MARGIN) * 2.0)
	match style:
		Style.SUNBURST:
			draw_rect(full, base_color)
			_draw_rays(full)
			if glow_color.a > 0.0:
				var r: float = size.y * glow_radius
				draw_texture_rect(_soft_disc, Rect2(focus - Vector2(r, r), Vector2(r, r) * 2.0), false, glow_color)
		Style.NIGHT:
			var pts := PackedVector2Array([full.position, Vector2(full.end.x, full.position.y), full.end, Vector2(full.position.x, full.end.y)])
			draw_polygon(pts, PackedColorArray([top_color, top_color, base_color, base_color]))
		Style.VIGNETTE:
			# 모서리까지 닿게 대각선 길이로 키운 원을 깐다(화면 비율이 달라도 가장자리가 고르게 어두워진다)
			var half: Vector2 = size * 0.5
			var r2: float = half.length()
			draw_texture_rect(_vignette, Rect2(half - Vector2(r2, r2), Vector2(r2, r2) * 2.0), false)

func _draw_rays(full: Rect2) -> void:
	if ray_count <= 0:
		return
	var reach: float = full.size.length() + focus.distance_to(full.get_center())
	var step: float = TAU / float(ray_count)
	for i in ray_count:
		var a0: float = _spin + step * float(i)
		var a1: float = a0 + step * ray_fill
		draw_colored_polygon(PackedVector2Array([focus, focus + Vector2.from_angle(a0) * reach, focus + Vector2.from_angle(a1) * reach]), ray_color)

static func _radial_texture(offsets: Array, colors: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex
