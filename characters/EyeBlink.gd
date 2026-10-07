@tool
class_name EyeBlink
extends Node2D

## 머리 그림 위에 코드로 눈꺼풀을 그려 눈을 깜빡이게 한다 — 눈 감은 그림이 없어도 된다.
## 이 게임 머리는 살색이 한 가지 색으로 평평하게 칠해져 있어서, 같은 색 타원으로 눈을 덮으면 이음매가 안 보인다.
##
## **리그의 `Head` 스프라이트 자식으로 달고, 노드 위치를 눈 한가운데에 둔다.** 좌표·크기는 머리 그림 픽셀 단위다
## (Head의 배율을 물려받으므로). 에디터에서 `preview_closed`를 올려 보면서 타원이 눈을 딱 덮게 맞추면 된다.
##
## 위아래 눈꺼풀이 `close_line`(눈 높이 대비 위치)에서 만나며 닫히고, 만나는 자리에 검은 곡선이 그어진다.
## **머리 그림이 처음 것(기본 얼굴)일 때만 깜빡인다** — 아픈·취한 얼굴은 눈 자리가 달라서 타원이 어긋난다

## 눈 크기(머리 그림 픽셀). 눈 테두리까지 살짝 넉넉하게 덮어야 감았을 때 테두리 링이 안 남는다
@export var eye_size: Vector2 = Vector2(200, 170)
## 눈꺼풀 색. 알파가 0이면 머리 그림에서 눈 바로 아래 살색을 자동으로 뽑는다
@export var skin_color: Color = Color(0, 0, 0, 0)
## 감은 눈 선 색
@export var line_color: Color = Color(0.05, 0.04, 0.04)
## 감은 눈 선 굵기(머리 그림 픽셀)
@export var line_width: float = 26.0
## 두 눈꺼풀이 만나는 높이 — 눈 위끝 -1, 가운데 0, 아래끝 1. 조금 아래(0.25)여야 아래로 감은 눈처럼 보인다
@export_range(-1.0, 1.0, 0.05) var close_line: float = 0.25
## 감은 선이 아래로 휘는 정도(눈 높이 대비). 0이면 일자
@export_range(0.0, 0.5, 0.01) var line_sag: float = 0.12

@export_group("박자")
## 감기는 데 걸리는 시간(초)
@export var close_time: float = 0.05
## 감은 채로 있는 시간(초)
@export var hold_time: float = 0.1
## 뜨는 데 걸리는 시간(초)
@export var open_time: float = 0.08
## 다음 깜빡임까지 기다리는 시간 범위(초)
@export var interval_min: float = 2.2
@export var interval_max: float = 5.0
## 한 번 깜빡인 뒤 곧바로 한 번 더 깜빡일 확률 — 늘 한 번씩만 깜빡이면 기계처럼 보인다
@export_range(0.0, 1.0, 0.05) var double_blink_chance: float = 0.2

@export_group("에디터")
## 에디터에서 감은 정도를 미리 본다(0 뜸 ~ 1 감음). 게임에는 영향 없다
@export_range(0.0, 1.0, 0.05) var preview_closed: float = 0.0:
	set(v):
		preview_closed = v
		queue_redraw()

## true인 동안 눈을 감고 그대로 있는다(close_time만큼 감기고, false가 되면 open_time만큼 뜬다) — 고양이 피격
var held_closed: bool = false
## false면 리그(BodyRig) 머리가 아니어도 동작한다 — 코드로 조립한 고양이 머리 등
var needs_rig: bool = true

var _base_texture: Texture2D
var _wait: float = 0.0
var _t: float = -1.0
var _amount: float = 0.0
var _color: Color

func _ready() -> void:
	var head := get_parent() as Sprite2D
	if head:
		_base_texture = head.texture
	_color = skin_color if skin_color.a > 0.0 else _sample_skin()
	_wait = randf_range(interval_min, interval_max)

## 지금 바로 한 번 깜빡인다(훈련장 테스트 버튼용). 평소 얼굴이 아니면 _process가 그 자리에서 눈을 뜬 채로 되돌린다
func blink_now() -> void:
	_t = 0.0

## 눈 바로 아래(볼)의 색을 머리 그림에서 읽는다 — 살색을 일일이 적지 않아도 된다
func _sample_skin() -> Color:
	var head := get_parent() as Sprite2D
	if head == null or head.texture == null:
		return Color(1, 0.88, 0.73)
	var img := head.texture.get_image()
	if img == null:
		return Color(1, 0.88, 0.73)
	if img.is_compressed():
		img.decompress()
	var origin: Vector2 = head.offset - (head.texture.get_size() * 0.5 if head.centered else Vector2.ZERO)
	var p: Vector2 = position + Vector2(0, eye_size.y * 0.5 + 30.0) - origin
	var x: int = clampi(int(p.x), 0, img.get_width() - 1)
	var y: int = clampi(int(p.y), 0, img.get_height() - 1)
	var c: Color = img.get_pixel(x, y)
	c.a = 1.0
	return c

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var head := get_parent() as Sprite2D
	# 대시 잔상처럼 리그를 복제해 스크립트를 떼어낸 사본에서는 깜빡이지 않는다
	var rig := head.get_parent() if head else null
	var alive: bool = rig != null and (rig.has_method("play_attack_swing") or not needs_rig)
	if not alive or head.texture != _base_texture:
		# 표정이 바뀌면 그 자리에서 눈을 뜬 상태로 돌려놓고, 다음 깜빡임은 처음부터 다시 기다린다
		if _amount > 0.0:
			_amount = 0.0
			_t = -1.0
			queue_redraw()
		return
	if held_closed or (_t < 0.0 and _amount > 0.0):
		# 감은 채 유지 — 풀리면 그 자리에서 천천히 뜬다
		var speed: float = 1.0 / maxf(close_time if held_closed else open_time, 0.001)
		_amount = move_toward(_amount, 1.0 if held_closed else 0.0, speed * delta)
		_t = -1.0
		queue_redraw()
		return
	if _t < 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_t = 0.0
		return
	_t += delta
	var total: float = close_time + hold_time + open_time
	if _t < close_time:
		_amount = _t / maxf(close_time, 0.001)
	elif _t < close_time + hold_time:
		_amount = 1.0
	elif _t < total:
		_amount = 1.0 - (_t - close_time - hold_time) / maxf(open_time, 0.001)
	else:
		_amount = 0.0
		_t = -1.0
		# 가끔은 곧바로 한 번 더 — 사이는 짧게
		_wait = 0.12 if randf() < double_blink_chance else randf_range(interval_min, interval_max)
	queue_redraw()

func _draw() -> void:
	var amount: float = preview_closed if Engine.is_editor_hint() else _amount
	if Engine.is_editor_hint():
		# 에디터에서는 타원 테두리를 옅게 보여줘서 눈에 맞추기 쉽게 한다
		_draw_ellipse_outline(Color(0.2, 0.8, 1.0, 0.8))
		if _color.a <= 0.0:
			_color = skin_color if skin_color.a > 0.0 else _sample_skin()
	if amount <= 0.001:
		return
	var a: float = eye_size.x * 0.5
	var b: float = eye_size.y * 0.5
	# 위 눈꺼풀은 위끝(-b)에서, 아래 눈꺼풀은 아래끝(+b)에서 출발해 close_line에서 만난다.
	# 아래 눈꺼풀은 덜 움직여야 자연스러워서 끝 무렵에만 올라온다
	var meet: float = close_line * b
	var upper_y: float = lerpf(-b, meet, amount)
	var lower_y: float = lerpf(b, meet, amount * amount)
	var sag: float = line_sag * eye_size.y * amount
	_fill_lid(a, b, upper_y, sag, true)
	_fill_lid(a, b, lower_y, sag, false)
	# 위 눈꺼풀 끝을 따라 속눈썹 선을 긋는다 — 다 감으면 이게 곧 "감은 눈" 곡선이 된다
	var pts := PackedVector2Array()
	var steps: int = 16
	for i in steps + 1:
		var x: float = lerpf(-a, a, float(i) / steps)
		var y: float = upper_y + sag * (1.0 - pow(x / a, 2.0))
		# 타원 밖으로 삐져나간 부분은 안 긋는다
		if pow(x / a, 2.0) + pow(y / b, 2.0) <= 1.02:
			pts.append(Vector2(x, y))
	if pts.size() >= 2:
		draw_polyline(pts, line_color, line_width, true)

## 타원 안에서 눈꺼풀 선의 위쪽(upper) 또는 아래쪽을 살색으로 칠한다.
## 세로 띠(사각형) 여러 개로 나눠 칠한다 — 타원을 선으로 잘라 다각형 하나로 만들면 점이 겹치는 순간
## 다각형 분할이 실패해 에러가 나는데, 띠는 분할을 안 거쳐서 모양이 찌그러져도 안전하다
func _fill_lid(a: float, b: float, edge_y: float, sag: float, upper: bool) -> void:
	var steps: int = 24
	var prev := Vector2.ZERO   # (그 x에서 칠할 위끝, 아래끝)
	var prev_x: float = 0.0
	for i in steps + 1:
		var x: float = lerpf(-a, a, float(i) / steps)
		var half: float = b * sqrt(maxf(1.0 - pow(x / a, 2.0), 0.0))
		var lid: float = clampf(edge_y + sag * (1.0 - pow(x / a, 2.0)), -half, half)
		var span := Vector2(-half, lid) if upper else Vector2(lid, half)
		if i > 0:
			draw_primitive(PackedVector2Array([
				Vector2(prev_x, prev.x), Vector2(x, span.x), Vector2(x, span.y), Vector2(prev_x, prev.y)]),
				PackedColorArray([_color, _color, _color, _color]), PackedVector2Array())
		prev = span
		prev_x = x

func _draw_ellipse_outline(color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 41:
		var ang: float = TAU * float(i) / 40.0
		pts.append(Vector2(cos(ang) * eye_size.x * 0.5, sin(ang) * eye_size.y * 0.5))
	draw_polyline(pts, color, 6.0)
