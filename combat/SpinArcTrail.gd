extends Node2D

## 빙빙 도는 무기 끝이 지나간 길을 **겹겹의 호**로 그리는 트레일(2026-10-10 사용자 레퍼런스: 격투 게임 회전 공격).
## 줄마다 흰색·검은색이 번갈아 겹치고(2026-10-10 사용자: "하얀색 검은 색 섞어줘"), 머리(무기 끝)에서 꼬리로 갈수록 투명해진다.
## 악플러 회전 난무(`BodyRig.play_keyboard_fan`)가 리그 자식으로 붙여 매 프레임 `center`·`angle`·`radius`를 넣어 준다 —
## 리그 로컬 좌표라 좌우 반전은 저절로 맞는다. 무기 양 끝(angle, angle+PI) 두 갈래를 그린다.
## 그림 없이 `_draw()`다

## 호가 뒤로 이어지는 각도(도) — 클수록 원반처럼 꽉 찬다
@export var sweep_deg: float = 160.0
## 겹쳐 그리는 호 개수와 반지름 범위(무기 반길이 대비 배율, 안쪽 → 바깥)
@export var line_count: int = 6
@export var inner_ratio: float = 0.7
@export var outer_ratio: float = 1.3
## 선 색: 흰 줄과 검은 줄이 번갈아 온다 / 뒤에 깔리는 번짐 띠 색
@export var light_color: Color = Color(1.0, 1.0, 1.0, 0.95)
@export var dark_color: Color = Color(0.06, 0.06, 0.08, 0.9)
@export var glow_color: Color = Color(0.85, 0.85, 0.9, 0.22)
## 선 굵기 범위(px, 리그 로컬)
@export var line_width_min: float = 1.4
@export var line_width_max: float = 3.2
## 꺼진 뒤 사라지는 시간(초)
@export var fade_time: float = 0.12

## 회전 축 / 지금 무기 각도(라디안) / 무기 반길이(px) — 리그가 매 프레임 넣는다
var center: Vector2 = Vector2.ZERO
var angle: float = 0.0
var radius: float = 30.0
## 도는 방향(+1 = 각도가 커지는 쪽). 꼬리는 그 반대로 뻗는다
var spin_dir: float = 1.0

var _active: bool = false
var _alpha: float = 0.0

func set_active(on: bool) -> void:
	_active = on
	if on:
		_alpha = 1.0
		visible = true

func _process(delta: float) -> void:
	if not _active:
		_alpha = maxf(_alpha - delta / maxf(fade_time, 0.001), 0.0)
		if _alpha <= 0.0:
			visible = false
			return
	queue_redraw()

func _draw() -> void:
	if _alpha <= 0.0 or radius <= 1.0:
		return
	var sweep: float = deg_to_rad(sweep_deg)
	var steps: int = 24
	for tip in 2:
		var head: float = angle + PI * tip
		# 바깥 번짐 띠 — 굵은 반투명 호 하나
		_draw_fading_arc(head, sweep, radius * (inner_ratio + outer_ratio) * 0.5,
				radius * (outer_ratio - inner_ratio) + line_width_max * 2.0, glow_color, steps)
		for i in line_count:
			var f: float = float(i) / maxf(line_count - 1, 1)
			var col: Color = light_color if i % 2 == 0 else dark_color
			var w: float = lerpf(line_width_max, line_width_min, absf(f - 0.35) * 1.5)
			# 줄마다 꼬리 길이를 조금씩 달리해 레퍼런스처럼 결이 생기게
			var len_k: float = 1.0 - 0.18 * float((i * 3) % line_count) / maxf(line_count, 1)
			_draw_fading_arc(head, sweep * len_k, radius * lerpf(inner_ratio, outer_ratio, f), w, col, steps)

## head 각도에서 도는 반대쪽으로 sweep만큼 이어지는 호. 머리는 진하고 꼬리로 갈수록 투명·가늘어진다
func _draw_fading_arc(head: float, sweep: float, r: float, width: float, col: Color, steps: int) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for s in steps + 1:
		var k: float = float(s) / float(steps)
		pts.append(center + Vector2.from_angle(head - spin_dir * sweep * k) * r)
		var c := col
		c.a *= _alpha * pow(1.0 - k, 1.4)
		cols.append(c)
	draw_polyline_colors(pts, cols, width, true)
