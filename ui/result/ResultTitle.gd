extends Control

## 결과 화면의 큰 글자("승리!" / "패배...") + 그 아래 이름표("P1 금쪽이").
##
## 글자를 **한 자씩 따로** 그린다 —
##  - POP(승리): 한 자씩 0에서 튀어나와 크게 부풀었다가 제자리에 앉고, 그 뒤로는 물결치듯 까딱인다
##  - DROOP(패배): 한 자씩 위에서 툭 떨어져 찌그러졌다가 **축 처지며** 기울어진다. 점(.)은 더 느리게 하나씩
## 그림자 → 외곽선 → 글자 순으로 **겹마다 전부** 그린다(한 자씩 다 그리면 옆 글자 외곽선이 앞 글자를 덮는다).
## 주아체는 기호 글리프가 거의 없다 — 한글·영문·숫자·! ? . - 만 쓸 것.
## 시간은 `MatchEnding`이 `tick()`으로 넣는다(실제 시간). `show_title()`을 부르기 전엔 안 보인다

enum Style { POP, DROOP }

@export var style: Style = Style.POP
@export var text: String = "승리!"
@export var font: Font = preload("res://fonts/Jua-Regular.ttf")
@export var font_size: int = 176
@export var fill_color: Color = Color(1, 1, 1)
@export var outline_color: Color = Color(0.05, 0.04, 0.08)
## 외곽선 굵기(px)
@export var outline_size: int = 30
## 뒤에 깔리는 단단한 그림자 — 알파 0이면 안 그린다
@export var shadow_color: Color = Color(0.9, 0.32, 0.12)
@export var shadow_offset: Vector2 = Vector2(8, 11)
## 글자 전체 기울기(도, 음수면 오른쪽이 올라간다)
@export var tilt_deg: float = -7.0
## 글자 사이 간격 보정(px)
@export var letter_spacing: float = -6.0

@export_group("움직임")
## 한 자씩 나오는 간격(초)
@export var letter_stagger: float = 0.075
## DROOP: 점(.)이 하나씩 나오는 간격(초)과 첫 점까지 더 쉬는 시간
@export var dot_stagger: float = 0.34
@export var dot_pause: float = 0.25
## POP: 튀어나오는 시간(초)과 부푸는 정도(클수록 크게 넘쳤다 돌아온다)
@export var pop_time: float = 0.3
@export var pop_overshoot: float = 3.2
## POP: 자리 잡은 뒤 물결 높이(px)
@export var wave_amount: float = 6.0
## DROOP: 떨어지는 높이(px)·시간(초)
@export var drop_height: float = 150.0
@export var drop_time: float = 0.3
## DROOP: 축 처지며 기우는 각도(도)와 가라앉는 깊이(px)
@export var sag_deg: float = 9.0
@export var sag_depth: float = 12.0

@export_group("이름표")
@export var subtitle_size: int = 42
## 이름표 바탕색(P1 파랑 / P2 빨강 — MatchEnding이 넣는다)
@export var tag_color: Color = Color(0.17, 0.42, 0.92)
@export var tag_text_color: Color = Color(1, 1, 1)
## 큰 글자가 나오고 이름표가 나올 때까지(초)
@export var subtitle_delay: float = 0.5
## 큰 글자와 이름표 사이(px)
@export var subtitle_gap: float = 6.0

## 큰 글자 가운데(화면 좌표) — MatchEnding이 넣는다
var anchor: Vector2 = Vector2(640, 260)
## 이름표 글("P1 금쪽이"). 비우면 이름표를 안 그린다
var subtitle: String = ""

var _time: float = -1.0
var _rng := RandomNumberGenerator.new()
## 글자마다 [글자, 가운데 x(제목 기준), 너비, 나오는 시각, 무작위 −1~1]
var _letters: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()

## 글자를 나오게 한다(처음부터 다시)
func show_title() -> void:
	_build_letters()
	_time = 0.0
	queue_redraw()

## 한 프레임 진행(dt = 실제 초)
func tick(dt: float) -> void:
	if _time < 0.0:
		return
	_time += dt
	queue_redraw()

func _build_letters() -> void:
	_letters.clear()
	if font == null:
		return
	var total: float = 0.0
	var widths: Array[float] = []
	for ch in text:
		var w: float = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		widths.append(w)
		total += w
	total += letter_spacing * float(maxi(text.length() - 1, 0))
	var x: float = -total * 0.5
	var at: float = 0.0
	var dots: int = 0
	for i in text.length():
		var ch: String = text[i]
		if style == Style.DROOP and ch == ".":
			at += dot_pause if dots == 0 else 0.0
			at += dot_stagger if dots > 0 else 0.0
			dots += 1
		elif i > 0:
			at += letter_stagger
		_letters.append([ch, x + widths[i] * 0.5, widths[i], at, _rng.randf_range(-1.0, 1.0)])
		x += widths[i] + letter_spacing

func _draw() -> void:
	if _time < 0.0 or font == null:
		return
	var title_xf := Transform2D(deg_to_rad(tilt_deg), anchor)
	var base_y: float = (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	var shown: Array = []
	var xfs: Array[Transform2D] = []
	for l in _letters:
		if _letter_visible(l):
			shown.append(l)
			xfs.append(title_xf * _letter_transform(l))
	if shadow_color.a > 0.0:
		for i in shown.size():
			draw_set_transform_matrix(xfs[i].translated(shadow_offset))
			var pos_s := Vector2(-float(shown[i][2]) * 0.5, base_y)
			draw_char_outline(font, pos_s, shown[i][0], font_size, outline_size, shadow_color)
			draw_char(font, pos_s, shown[i][0], font_size, shadow_color)
	for i in shown.size():
		draw_set_transform_matrix(xfs[i])
		draw_char_outline(font, Vector2(-float(shown[i][2]) * 0.5, base_y), shown[i][0], font_size, outline_size, outline_color)
	for i in shown.size():
		draw_set_transform_matrix(xfs[i])
		draw_char(font, Vector2(-float(shown[i][2]) * 0.5, base_y), shown[i][0], font_size, _letter_fill(shown[i]))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_tag(title_xf)

## 글자가 지금 보이는지(아직 차례가 안 왔거나 막 튀어나오기 직전이면 false)
func _letter_visible(l: Array) -> bool:
	var t: float = _time - float(l[3])
	if t < 0.0:
		return false
	if style == Style.POP:
		return _ease_out_back(clampf(t / maxf(pop_time, 0.01), 0.0, 1.0), pop_overshoot) > 0.001
	return true

## 글자 하나의 자리·각도·크기(제목 기준)
func _letter_transform(l: Array) -> Transform2D:
	var t: float = _time - float(l[3])
	var x: float = float(l[1])
	var r: float = float(l[4])
	if style == Style.POP:
		var u: float = clampf(t / maxf(pop_time, 0.01), 0.0, 1.0)
		var s: float = _ease_out_back(u, pop_overshoot)
		var settle: float = clampf((t - pop_time) / 0.3, 0.0, 1.0)
		var rot: float = r * 0.45 * (1.0 - _ease_out_cubic(u)) + sin(_time * 3.1 + x * 0.02) * 0.035 * settle
		var y: float = 34.0 * (1.0 - _ease_out_cubic(u)) + sin(_time * 4.6 - x * 0.012) * wave_amount * settle
		return Transform2D(rot, Vector2(s, s), 0.0, Vector2(x, y))
	# DROOP — 떨어지고(가속) → 찌그러졌다 → 축 처진다
	var dot: bool = str(l[0]) == "."
	var u2: float = clampf(t / maxf(drop_time, 0.01), 0.0, 1.0)
	var y2: float = -drop_height * (1.0 - u2 * u2) * (0.5 if dot else 1.0)
	var sx: float = 1.0
	var sy: float = 1.0
	var rot2: float = 0.0
	if t > drop_time:
		var tl: float = t - drop_time
		var bounce: float = exp(-8.0 * tl) * cos(15.0 * tl) * (0.4 if dot else 1.0)
		sy = 1.0 - 0.24 * bounce
		sx = 1.0 + 0.16 * bounce
		var sag: float = _ease_out_cubic(clampf(tl / 1.6, 0.0, 1.0))
		rot2 = deg_to_rad(sag_deg) * r * sag * (0.4 if dot else 1.0)
		y2 += sag_depth * (0.6 + 0.4 * absf(r)) * sag
	return Transform2D(rot2, Vector2(sx, sy), 0.0, Vector2(x, y2))

## DROOP 글자는 떨어지는 동안 서서히 진해진다
func _letter_fill(l: Array) -> Color:
	if style == Style.POP:
		return fill_color
	var t: float = _time - float(l[3])
	return Color(fill_color, fill_color.a * clampf(t / (drop_time * 0.5), 0.0, 1.0))

func _draw_tag(title_xf: Transform2D) -> void:
	if subtitle == "":
		return
	var t: float = _time - subtitle_delay
	if t <= 0.0:
		return
	var u: float = clampf(t / 0.28, 0.0, 1.0)
	var k: float = _ease_out_back(u, 2.0)
	var alpha: float = clampf(u * 2.5, 0.0, 1.0)
	var text_w: float = font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, subtitle_size).x
	var h: float = subtitle_size * 1.5
	var w: float = text_w + subtitle_size * 1.4
	var lean: float = h * 0.32
	var y: float = font_size * 0.5 + subtitle_gap + h * 0.5 + (1.0 - k) * 26.0
	var tag_xf: Transform2D = title_xf * Transform2D(0.0, Vector2(0.6 + 0.4 * k, 0.6 + 0.4 * k), 0.0, Vector2(0.0, y))
	draw_set_transform_matrix(tag_xf)
	var pts := PackedVector2Array([Vector2(-w * 0.5 + lean, -h * 0.5), Vector2(w * 0.5 + lean, -h * 0.5),
		Vector2(w * 0.5 - lean, h * 0.5), Vector2(-w * 0.5 - lean, h * 0.5)])
	# 단단한 그림자 → 바탕 → 테두리
	var shadow_pts := PackedVector2Array()
	for p in pts:
		shadow_pts.append(p + Vector2(5, 6))
	draw_colored_polygon(shadow_pts, Color(outline_color, 0.9 * alpha))
	draw_colored_polygon(pts, Color(tag_color, alpha))
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, Color(outline_color, alpha), 5.0, true)
	var base_y: float = (font.get_ascent(subtitle_size) - font.get_descent(subtitle_size)) * 0.5
	var pos := Vector2(-text_w * 0.5, base_y)
	draw_string_outline(font, pos, subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, subtitle_size, 10, Color(outline_color, alpha))
	draw_string(font, pos, subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, subtitle_size, Color(tag_text_color, alpha))
	draw_set_transform_matrix(Transform2D.IDENTITY)

static func _ease_out_back(u: float, s: float) -> float:
	var v: float = u - 1.0
	return 1.0 + (s + 1.0) * v * v * v + s * v * v

static func _ease_out_cubic(u: float) -> float:
	return 1.0 - pow(1.0 - u, 3.0)
