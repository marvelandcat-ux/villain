@tool
class_name RoundWinBanner
extends Control

## 라운드 승리 **띠** — 이긴 쪽에서 튀어나와 화면을 가로지르고, 잠깐 멈췄다가 휙 사라진다.
##
##  - **P1이 이기면 왼쪽에서 나와 오른쪽으로**, P2가 이기면 오른쪽에서 나와 왼쪽으로 지나간다.
##  - 띠는 **평행사변형**인데, 가운데에 멈춰 있는 동안에는 **화면보다 넓어서 양 끝이 안 보인다**
##    (그래서 그냥 가로지르는 띠로 보인다). 비스듬한 끝은 들어올 때와 나갈 때만 스쳐 지나간다.
##  - 멈춰 있는 동안 살짝 커졌다가 그대로 빠져나간다.
##
## 색은 이긴 쪽에 맞춰 바뀐다(P1 파랑 / P2 빨강). `play(p1_won)`로 시작하고, 다 끝나면 `finished`를 낸다.
## 에디터에서는 `preview`를 켜면 멈춰 있는 모습 그대로 보여 준다 — 그걸 보고 값을 잡으면 된다

## 연출이 다 끝났을 때
signal finished

@export_group("띠 모양")
## 띠의 가로 길이(px). **화면보다 넉넉히 길어야** 멈춰 있을 때 양 끝이 화면 밖으로 나간다
@export var band_width: float = 1900.0:
	set(value):
		band_width = value
		queue_redraw()
## 띠의 세로 두께(px)
@export var band_height: float = 132.0:
	set(value):
		band_height = value
		queue_redraw()
## 비스듬한 정도(px). 위쪽 변이 아래쪽 변보다 이만큼 오른쪽으로 밀린다
@export var lean: float = 150.0:
	set(value):
		lean = value
		queue_redraw()
## 화면 세로 가운데에서 위아래로 얼마나 비킬지(px, 음수면 위)
@export var band_offset_y: float = -40.0:
	set(value):
		band_offset_y = value
		queue_redraw()

@export_group("색")
## P1이 이겼을 때 띠 색 / P2가 이겼을 때 띠 색
@export var p1_color: Color = Color(0.17, 0.42, 0.92, 1.0):
	set(value):
		p1_color = value
		queue_redraw()
@export var p2_color: Color = Color(0.90, 0.18, 0.22, 1.0):
	set(value):
		p2_color = value
		queue_redraw()
## 띠 위아래에 깔리는 테두리 띠의 색과 두께(px). 두께 0이면 안 그린다
@export var edge_color: Color = Color(1.0, 1.0, 1.0, 0.92):
	set(value):
		edge_color = value
		queue_redraw()
@export var edge_width: float = 7.0:
	set(value):
		edge_width = value
		queue_redraw()
## 띠 뒤에 깔리는 그림자 띠 — 살짝 어긋나게 깔아 두께감을 준다. 알파 0이면 안 그린다
@export var shadow_color: Color = Color(0.05, 0.05, 0.09, 0.45):
	set(value):
		shadow_color = value
		queue_redraw()
@export var shadow_offset: Vector2 = Vector2(0, 9):
	set(value):
		shadow_offset = value
		queue_redraw()

@export_group("글자")
## 띠에 쓰는 말. `{P}`는 이긴 쪽 번호(1 또는 2)로 바뀐다
@export var win_text: String = "P{P} 승리!"
## 무승부일 때 쓰는 말
@export var draw_text: String = "무승부"
## 글자가 띠 가운데에서 비키는 정도(px)
@export var text_offset: Vector2 = Vector2(0, 0)

@export_group("움직임")
## 밖에서 가운데까지 들어오는 시간(초)
@export var enter_time: float = 0.26
## 가운데에 머무는 시간(초)
@export var hold_time: float = 0.95
## 가운데에서 반대편 밖으로 빠져나가는 시간(초)
@export var exit_time: float = 0.2
## **띠 자체가** 머무는 동안 커지는 배율. 1이면 안 커진다(기본) — 커지는 건 글자만 맡는다
@export var grow_scale: float = 1.0
## 그 배율까지 커지는 데 걸리는 시간(초)
@export var grow_time: float = 0.35

@export_subgroup("글자 톡 튀기")
## 띠가 멈추는 순간 **글자가 한 번 확 커졌다가** 제자리로 돌아온다. 1이면 안 튄다
@export var text_pop_scale: float = 1.38
## 커지는 데 걸리는 시간(초). 짧을수록 톡 튄다
@export var text_pop_time: float = 0.1
## 도로 줄어드는 데 걸리는 시간(초)
@export var text_settle_time: float = 0.22
## 커질 때 **같이 돌아가는 각도(도).** P1이 이기면 시계방향, P2면 반대로 돈다 —
## 띠가 나아가는 쪽으로 기울어서 "지나가며 찍고 간다"는 느낌이 난다. 0이면 안 돈다.
## 커졌다 가라앉는 그 곡선을 그대로 타므로 **제자리(0도)로 돌아온다**
@export var text_pop_deg: float = 7.5
## 들어올 때·나갈 때 화면 밖으로 더 비켜 둘 여유(px) — 끝이 살짝이라도 걸치지 않게
@export var travel_margin: float = 120.0

@export_group("미리보기")
## **이 씬만 따로 실행하면**(에디터에서 F6) 띠가 P1 → P2 → P1 … 로 계속 반복된다.
## 라운드를 진짜로 이기지 않고도 움직임을 볼 수 있다. 게임 안에 붙어 있을 땐 저절로 꺼진다
@export var autoplay_when_alone: bool = true
## 반복 미리보기에서 한 번 끝나고 다음까지 쉬는 시간(초)
@export var autoplay_interval: float = 0.5
## 반복 미리보기일 때 뒤에 깔아 주는 바탕색 — 띠만 덩그러니 띄우면 잘 안 보인다
@export var preview_backdrop: Color = Color(0.13, 0.14, 0.19, 1.0)

## 켜면 **멈춰 있는 모습**을 그대로 보여 준다(에디터 전용). 게임에는 영향 없다
@export var preview: bool = true:
	set(value):
		preview = value
		queue_redraw()
## 미리보기에서 어느 쪽 승리로 볼지
@export_enum("P1", "P2") var preview_winner: int = 0:
	set(value):
		preview_winner = value
		queue_redraw()

## 지금 어느 토막인지 — -1 안 함 / 0 들어옴 / 1 머묾 / 2 나감
var _phase: int = -1
## 그 토막에서 흐른 시간
var _time: float = 0.0
## 이번에 이긴 쪽(1 또는 2), 무승부면 0
var _winner: int = 1
## 지금 띠가 놓인 가로 위치(화면 가운데 기준)와 크기 배율
var _x: float = 0.0
var _scale: float = 1.0
## 글자만 따로 쓰는 배율 — 멈추는 순간 확 커졌다가 1로 돌아온다
var _text_scale: float = 1.0
## 글자가 돌아간 각도(라디안) — 배율과 같은 곡선을 타고 0으로 돌아온다
var _text_rot: float = 0.0
## 띠에 쓸 말
var _text: String = ""
## 이 씬만 따로 실행된 상태인지(반복 미리보기 중)
var _standalone: bool = false
## 반복 미리보기에서 다음에 보여 줄 쪽
var _loop_p1: bool = true

@onready var _label: Label = get_node_or_null("Label")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Engine.is_editor_hint():
		queue_redraw()
		return
	# **이 씬만 따로 실행했으면**(F6) 반복해서 보여 준다 — 미리보기용
	if autoplay_when_alone and get_parent() != null and get_tree().current_scene == get_parent():
		_standalone = true
		_loop_preview()
		return
	# 게임에서는 `play()`를 부르기 전까지 아무것도 안 보인다
	visible = false
	set_process(false)

## 반복 미리보기 — P1 쪽, P2 쪽을 번갈아 계속 보여 준다
func _loop_preview() -> void:
	visible = true
	while is_inside_tree():
		play(_loop_p1)
		_loop_p1 = not _loop_p1
		await finished
		visible = true   # 한 번 끝나면 숨겨지므로 바탕은 다시 켜 둔다
		queue_redraw()
		await get_tree().create_timer(autoplay_interval).timeout

## 띠를 띄운다. p1_won이 true면 왼쪽에서, false면 오른쪽에서 튀어나온다.
## is_draw면 양쪽 색을 안 쓰고 무승부 글자를 띄운다(방향은 왼쪽에서 오른쪽)
func play(p1_won: bool, is_draw: bool = false) -> void:
	_winner = 0 if is_draw else (1 if p1_won else 2)
	_text = draw_text if is_draw else win_text.replace("{P}", str(_winner))
	_phase = 0
	_time = 0.0
	_scale = 1.0
	_text_scale = 1.0
	_text_rot = 0.0
	_x = _travel_distance() * -_direction()
	visible = true
	set_process(true)
	queue_redraw()

## 띠가 나아가는 쪽 — P1은 +1(오른쪽), P2는 -1(왼쪽). 무승부는 P1과 같다
func _direction() -> float:
	return -1.0 if _winner == 2 else 1.0

## 화면 밖으로 완전히 비켜나는 거리
func _travel_distance() -> float:
	return (size.x + band_width * maxf(grow_scale, 1.0)) * 0.5 + travel_margin

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _phase < 0:
		return
	_time += delta
	var dir: float = _direction()
	var away: float = _travel_distance()
	match _phase:
		0:
			var t: float = clampf(_time / maxf(enter_time, 0.01), 0.0, 1.0)
			# 끝에서 멎는다 — 미끄러져 들어와 탁 멈추는 느낌
			_x = lerpf(-away * dir, 0.0, 1.0 - pow(1.0 - t, 3.0))
			if t >= 1.0:
				_phase = 1
				_time = 0.0
		1:
			_x = 0.0
			var g: float = clampf(_time / maxf(grow_time, 0.01), 0.0, 1.0)
			_scale = lerpf(1.0, grow_scale, g * g * (3.0 - 2.0 * g))
			# 커지기와 돌기가 **같은 곡선**을 탄다 — 따로 놀면 글자가 비뚤게 굳은 것처럼 보인다
			var pop: float = _pop_amount(_time)
			_text_scale = lerpf(1.0, text_pop_scale, pop)
			_text_rot = deg_to_rad(text_pop_deg) * _direction() * pop
			if _time >= hold_time:
				_phase = 2
				_time = 0.0
		2:
			var e: float = clampf(_time / maxf(exit_time, 0.01), 0.0, 1.0)
			# 가속해서 휙 빠진다
			_x = lerpf(0.0, away * dir, e * e)
			if e >= 1.0:
				_phase = -1
				visible = false
				set_process(false)
				finished.emit()
				return
	queue_redraw()

## 멈춘 뒤 흐른 시간으로 **튀어오른 정도(0 → 1 → 0)**를 구한다.
## 올라갈 땐 끝에서 멎고(text_pop_time), 내려올 땐 부드럽게 가라앉는다(text_settle_time).
## 배율과 회전이 이 값 하나를 같이 쓴다
func _pop_amount(t: float) -> float:
	var up: float = maxf(text_pop_time, 0.01)
	if t < up:
		return 1.0 - pow(1.0 - t / up, 3.0)
	var b: float = clampf((t - up) / maxf(text_settle_time, 0.01), 0.0, 1.0)
	return 1.0 - b * b * (3.0 - 2.0 * b)

func _draw() -> void:
	# 혼자 실행 중이면 뒤에 바탕을 깔아 띠가 잘 보이게 한다
	if _standalone:
		draw_rect(Rect2(Vector2.ZERO, size), preview_backdrop, true)
	var shown: bool = _phase >= 0
	if Engine.is_editor_hint():
		if not preview:
			return
		shown = true
		_winner = preview_winner + 1
		_x = 0.0
		_scale = grow_scale
		_text_scale = 1.0
		_text_rot = 0.0
		_text = win_text.replace("{P}", str(_winner))
	if not shown:
		return
	var center := Vector2(size.x * 0.5 + _x, size.y * 0.5 + band_offset_y)
	var fill: Color = p2_color if _winner == 2 else p1_color
	if shadow_color.a > 0.0:
		draw_colored_polygon(_shape(center + shadow_offset), shadow_color)
	draw_colored_polygon(_shape(center), fill)
	if edge_width > 0.0 and edge_color.a > 0.0:
		# 위·아래 변을 따라 테두리 띠를 하나씩 깐다(평행사변형이라 네 변을 다 두르면 끝이 지저분해진다)
		var half_w: float = band_width * _scale * 0.5
		var half_h: float = band_height * _scale * 0.5
		var slant: float = lean * _scale * 0.5
		draw_line(center + Vector2(-half_w + slant, -half_h), center + Vector2(half_w + slant, -half_h), edge_color, edge_width * _scale)
		draw_line(center + Vector2(-half_w - slant, half_h), center + Vector2(half_w - slant, half_h), edge_color, edge_width * _scale)
	_place_label(center)

## 평행사변형 네 점 — 위쪽 변이 lean만큼 오른쪽으로 밀려 있다
func _shape(center: Vector2) -> PackedVector2Array:
	var half_w: float = band_width * _scale * 0.5
	var half_h: float = band_height * _scale * 0.5
	var slant: float = lean * _scale * 0.5
	return PackedVector2Array([
		center + Vector2(-half_w + slant, -half_h),
		center + Vector2(half_w + slant, -half_h),
		center + Vector2(half_w - slant, half_h),
		center + Vector2(-half_w - slant, half_h),
	])

## 글자를 띠 가운데에 올린다. 띠가 커질 때 글자도 같이 커진다
func _place_label(center: Vector2) -> void:
	if _label == null:
		return
	_label.text = _text
	_label.pivot_offset = _label.size * 0.5
	var k: float = _scale * _text_scale
	_label.scale = Vector2(k, k)
	_label.rotation = _text_rot
	_label.position = center + text_offset - _label.size * 0.5
