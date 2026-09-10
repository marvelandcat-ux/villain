class_name ClashBand
extends Control

## 스킬 클래시의 **사선 게이지 띠**.
## 노란(P1) / 파란(P2) 덩어리가 사선으로 맞물려 있고, 그 경계선이 곧 밀당 게이지다 —
## 따로 눈금이나 숫자를 안 보여줘도 "어느 쪽이 밀고 있는지"가 한눈에 읽힌다.
## 경계선에서는 지직거리는 스파크가 튄다.
##
## 노드를 잔뜩 만들지 않고 `_draw()` 한 곳에서 전부 그린다 — 경계가 매 프레임 움직이는 사선이라
## 폴리곤 노드로 만들면 어차피 매 프레임 점을 다시 넣어야 하고, 스파크는 아예 매번 새로 만들어야 한다.

## 띠의 높이 (화면 높이 대비 비율)
@export_range(0.05, 0.8, 0.01) var band_height_ratio: float = 0.30
## 띠의 세로 위치 (0=화면 위, 1=화면 아래).
## **화면 가운데(0.5)에 두면 안 된다** — 카메라가 두 캐릭터를 화면 한가운데에 잡아주는데,
## 띠가 거기 있으면 손 맞대고 대치하는 그 그림을 통째로 가려버린다. 위쪽에 얹어서 아래를 비워둔다
@export_range(0.0, 1.0, 0.01) var band_center_ratio: float = 0.22
## 띠 전체를 살짝 기울인 각도(도). 0이면 반듯한 가로 띠
@export var band_tilt_deg: float = -2.5
## 경계선이 기울어진 정도(px). 위쪽 끝이 아래쪽 끝보다 이만큼 오른쪽에 있다
@export var slant: float = 260.0
## P1 쪽 색
@export var color_a: Color = Color(0.98, 0.86, 0.06)
## P2 쪽 색
@export var color_b: Color = Color(0.20, 0.21, 0.78)
## 띠 테두리·경계선 색
@export var edge_color: Color = Color(0.06, 0.05, 0.08)
## 위아래 테두리 두께(px)
@export var edge_width: float = 7.0
## 한 번에 튀는 스파크 개수
@export var spark_count: int = 22
## 스파크 하나가 경계선에서 뻗어나가는 길이(px)
@export var spark_len: float = 34.0
## 스파크 굵기(px)
@export var spark_width: float = 4.0
## 경계선을 따라 번쩍이는 빛덩어리 개수
@export var glow_count: int = 5
## 빛덩어리 반지름(px)
@export var glow_radius: float = 13.0
## 스파크 모양이 새로 바뀌는 간격(초). 짧을수록 지직거림이 거칠다
@export var spark_interval: float = 0.035
@export var spark_color: Color = Color(1.0, 0.97, 0.72)
@export var spark_color2: Color = Color(1.0, 0.62, 0.15)

## 밀당 게이지. 0이면 B 완승, 1이면 A 완승
var balance: float = 0.5:
	set(value):
		balance = clampf(value, 0.0, 1.0)
		queue_redraw()
## 등장 연출. 0이면 두 덩어리가 화면 밖, 1이면 완전히 맞물린 상태
var slide: float = 1.0:
	set(value):
		slide = value
		queue_redraw()

var _spark_time: float = 0.0
## 스파크 모양은 매 프레임이 아니라 spark_interval마다 새로 뽑는다 — 매 프레임 바꾸면
## 너무 빨리 깜빡여서 오히려 지직거리는 느낌이 안 난다
var _sparks: Array[PackedVector2Array] = []
## 경계선 위에서 번쩍이는 빛덩어리 위치
var _glows: Array[Vector2] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()

func _process(delta: float) -> void:
	_spark_time -= delta
	if _spark_time <= 0.0:
		_spark_time = spark_interval
		_rebuild_sparks()
	queue_redraw()

## 띠의 기울기를 담은 변환. `_draw()`와 얼굴 위치 계산이 **같은 변환**을 써야
## 얼굴이 띠 위에 정확히 얹힌다
func band_transform() -> Transform2D:
	return Transform2D(deg_to_rad(band_tilt_deg), Vector2(size.x * 0.5, size.y * band_center_ratio))

## 이 쪽 얼굴이 놓일 자리(Control 기준 좌표). 게이지가 밀리면 얼굴도 화면 끝으로 밀려난다 —
## 자리가 좁아지는 게 곧 "밀리고 있다"라서, 얼굴을 고정해두는 것보다 훨씬 잘 읽힌다
func face_anchor(is_a_side: bool) -> Vector2:
	var half_w: float = size.x * 0.5
	var bx: float = (balance - 0.5) * size.x
	var x: float = lerpf(-half_w, bx, 0.45) if is_a_side else lerpf(bx, half_w, 0.55)
	return band_transform() * Vector2(x, 0.0)

## 띠의 높이(px) — 얼굴 크기를 여기에 맞춘다
func band_height() -> float:
	return size.y * band_height_ratio

func _rebuild_sparks() -> void:
	_sparks.clear()
	_glows.clear()
	var h: float = band_height() * 0.5
	var bx: float = (balance - 0.5) * size.x
	for i in spark_count:
		# 경계선 위의 한 점에서 좌우 한쪽으로 뻗어나가는 번개 조각.
		# **가로로만 뻗고 세로로는 매 마디 방향을 뒤집는다** — 마디마다 아무 방향으로 꺾으면
		# 조각이 선에서 멀어져 흩어진 나뭇가지처럼 보인다. 지그재그로 묶어둬야 지직거리는 전기가 된다
		var t: float = _rng.randf()
		var origin := Vector2(bx + slant * (0.5 - t), lerpf(-h, h, t))
		var dir: float = 1.0 if _rng.randf() < 0.5 else -1.0
		var pts := PackedVector2Array([origin])
		var p := origin
		var segments: int = _rng.randi_range(2, 4)
		var step: float = spark_len / float(segments)
		for s in segments:
			var zig: float = 1.0 if s % 2 == 0 else -1.0
			p += Vector2(dir * step, zig * _rng.randf_range(0.35, 0.9) * step)
			pts.append(p)
		_sparks.append(pts)
	for i in glow_count:
		var t2: float = _rng.randf()
		_glows.append(Vector2(bx + slant * (0.5 - t2), lerpf(-h, h, t2)))

func _draw() -> void:
	var w: float = size.x
	var half_w: float = w * 0.5
	var h: float = band_height() * 0.5
	# 등장할 때는 두 덩어리가 화면 밖에서 미끄러져 들어와 가운데서 맞물린다
	var off: float = (1.0 - clampf(slide, 0.0, 1.0)) * w
	var bx: float = (balance - 0.5) * w
	var xt: float = bx + slant * 0.5      # 경계선 위쪽 끝
	var xb: float = bx - slant * 0.5      # 경계선 아래쪽 끝
	# 화면 밖까지 넉넉히 그려서, 기울인 띠의 양 끝에 빈틈이 생기지 않게 한다
	var pad: float = half_w + 200.0

	draw_set_transform_matrix(band_transform())

	var left := PackedVector2Array([Vector2(-pad - off, -h), Vector2(xt - off, -h),
									Vector2(xb - off, h), Vector2(-pad - off, h)])
	var right := PackedVector2Array([Vector2(xt + off, -h), Vector2(pad + off, -h),
									 Vector2(pad + off, h), Vector2(xb + off, h)])
	draw_colored_polygon(left, color_a)
	draw_colored_polygon(right, color_b)

	# 위아래 테두리
	draw_line(Vector2(-pad, -h), Vector2(pad, -h), edge_color, edge_width)
	draw_line(Vector2(-pad, h), Vector2(pad, h), edge_color, edge_width)

	if off <= 0.5:
		# 맞물린 뒤에만 경계선과 스파크를 그린다 (들어오는 중엔 경계가 없다)
		draw_line(Vector2(xt, -h), Vector2(xb, h), edge_color, edge_width)
		# 빛덩어리를 먼저 깔고 그 위에 번개를 얹는다 (번개가 빛에 묻히지 않게)
		for g in _glows:
			draw_circle(g, glow_radius, Color(spark_color2.r, spark_color2.g, spark_color2.b, 0.55))
			draw_circle(g, glow_radius * 0.5, spark_color)
		for pts in _sparks:
			if pts.size() < 2:
				continue
			draw_polyline(pts, spark_color2, spark_width + 3.0)
			draw_polyline(pts, spark_color, spark_width)

	draw_set_transform_matrix(Transform2D.IDENTITY)
