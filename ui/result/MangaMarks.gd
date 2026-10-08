extends Node2D

## 머리 둘레의 만화 기호 — 그림 파일 없이 `_draw()`로 그린다.
##  - HYPE(승리): 머리 둘레에 짧은 검은 획이 두 줄씩 튄다. 제자리에서 지글지글 떨며 깜빡인다(레퍼런스의 흥분 선)
##  - GLOOM(패배): 이마를 덮는 세로 우울선 + 관자놀이에서 흘러내리는 식은땀 + `sigh()`로 내뱉는 한숨 입김
## 자리는 `MatchEnding`이 매 프레임 `center`(머리 가운데, 화면 좌표)·`radius`(머리 반지름 px)·`facing`으로 넣는다.
## 시간은 `tick()`으로 받는다(실제 시간)

enum Mode { HYPE, GLOOM }

@export var mode: Mode = Mode.HYPE
## 선 색(먹색)
@export var line_color: Color = Color(0.05, 0.04, 0.08)

@export_group("흥분 선")
## 획이 놓일 각도(도, 오른쪽을 볼 때 기준 — 0 = 앞, −90 = 위). **얼굴 앞·아래(입)는 비워 둔다**
@export var hype_angles_deg: PackedFloat32Array = PackedFloat32Array([-24.0, -50.0, -76.0, -102.0, -128.0, -154.0, 178.0, 150.0])
## 머리 가운데에서 획까지 거리(머리 반지름 배수)
@export var hype_distance: float = 1.14
## 획 길이(머리 반지름 배수)
@export var hype_length: float = 0.2
## 획 굵기(px)
@export var hype_width: float = 5.5
## 지글거림 — 이 간격(초)마다 자리·길이를 살짝 다시 뽑는다
@export var hype_boil_interval: float = 0.085
## 획이 보이는 몫(나머지는 깜빡여 사라져 있다)
@export_range(0.0, 1.0, 0.05) var hype_visible_ratio: float = 0.78

@export_group("우울")
## 세로 우울선 수·색·굵기
@export var gloom_line_count: int = 9
@export var gloom_color: Color = Color(0.09, 0.06, 0.24, 0.92)
@export var gloom_width: float = 4.5
## 우울선이 내려오는 깊이(머리 반지름 배수, 머리 가운데 기준 — 0이면 가운데까지)
@export var gloom_reach_min: float = -0.15
@export var gloom_reach_max: float = 0.3
## 식은땀 색과 크기(머리 반지름 배수)
@export var sweat_color: Color = Color(0.62, 0.86, 1.0)
@export var sweat_size: float = 0.16
## 땀이 한 번 흘러내리는 시간(초)
@export var sweat_cycle: float = 2.3
## 한숨 입김 색·크기(머리 반지름 배수)·사라지는 시간(초)
@export var puff_color: Color = Color(0.86, 0.88, 0.98, 0.95)
@export var puff_size: float = 0.13
@export var puff_life: float = 1.1

## 머리 가운데(화면 좌표)
var center: Vector2 = Vector2.ZERO
## 머리 반지름(px)
var radius: float = 100.0
## 바라보는 쪽(1 = 오른쪽, −1 = 왼쪽)
var facing: float = 1.0
## 나타난 정도(0~1)
var strength: float = 0.0

var _time: float = 0.0
var _boil: float = 0.0
var _rng := RandomNumberGenerator.new()
## 흥분 선마다 [각도 흔들림(rad), 길이 배율, 보이는지]
var _marks: Array = []
## 우울선마다 [가로 자리(−1~1), 내려오는 깊이]
var _gloom: Array = []
## 입김마다 [나이(초)]
var _puffs: Array[float] = []

func _ready() -> void:
	_rng.randomize()
	for i in hype_angles_deg.size():
		_marks.append([0.0, 1.0, true])
	_reboil()
	for i in gloom_line_count:
		var u: float = float(i) / float(maxi(gloom_line_count - 1, 1))
		_gloom.append([lerpf(-0.66, 0.78, u) + _rng.randf_range(-0.04, 0.04), _rng.randf_range(gloom_reach_min, gloom_reach_max)])

## 한숨 — 입 앞에서 입김 한 덩이를 내뱉는다
func sigh() -> void:
	_puffs.append(0.0)

## 한 프레임 진행(dt = 실제 초)
func tick(dt: float) -> void:
	_time += dt
	_boil -= dt
	if _boil <= 0.0:
		_boil = hype_boil_interval
		_reboil()
	var i: int = _puffs.size() - 1
	while i >= 0:
		_puffs[i] += dt
		if _puffs[i] >= puff_life:
			_puffs.remove_at(i)
		i -= 1
	queue_redraw()

func _reboil() -> void:
	for m in _marks:
		m[0] = deg_to_rad(_rng.randf_range(-4.0, 4.0))
		m[1] = _rng.randf_range(0.82, 1.18)
		m[2] = _rng.randf() < hype_visible_ratio

func _draw() -> void:
	if strength <= 0.001 or radius <= 1.0:
		return
	if mode == Mode.HYPE:
		_draw_hype()
	else:
		_draw_gloom()

## 오른쪽 기준 각도를 지금 바라보는 쪽으로 뒤집는다
func _dir(deg: float, wobble: float) -> Vector2:
	var a: float = deg_to_rad(deg) + wobble
	var v := Vector2.from_angle(a)
	v.x *= facing
	return v

func _draw_hype() -> void:
	var col := Color(line_color, line_color.a * minf(strength * 1.5, 1.0))
	var pop: float = 0.6 + 0.4 * minf(strength, 1.0)
	for i in mini(_marks.size(), hype_angles_deg.size()):
		var m: Array = _marks[i]
		if not m[2]:
			continue
		var dir: Vector2 = _dir(hype_angles_deg[i], float(m[0]))
		var side := Vector2(-dir.y, dir.x)
		var base: Vector2 = center + dir * radius * hype_distance
		var length: float = radius * hype_length * float(m[1]) * pop
		var gap: float = radius * 0.055
		# 두 줄 중 바깥 줄을 조금 짧게 — 손으로 그은 느낌
		_round_line(base + side * gap, base + side * gap + dir * length, col, hype_width)
		_round_line(base - side * gap + dir * length * 0.12, base - side * gap + dir * length * 0.8, col, hype_width)

func _draw_gloom() -> void:
	var a: float = clampf(strength, 0.0, 1.0)
	# 세로 우울선 — 머리 윤곽(원)에서 시작해 아래로 흐려진다
	for g in _gloom:
		var u: float = float(g[0])
		var x: float = center.x + u * radius * facing
		var half_chord: float = sqrt(maxf(1.0 - u * u, 0.0))
		var top: float = center.y - half_chord * radius * 0.94
		var bottom: float = center.y + float(g[1]) * radius
		if bottom <= top + 2.0:
			continue
		var shimmer: float = 0.85 + 0.15 * sin(_time * 2.3 + u * 7.0)
		var c_top := Color(gloom_color, gloom_color.a * a * shimmer)
		var c_bottom := Color(gloom_color, 0.0)
		draw_polyline_colors(PackedVector2Array([Vector2(x, top), Vector2(x, bottom)]), PackedColorArray([c_top, c_bottom]), gloom_width, true)
	_draw_sweat(a)
	for age in _puffs:
		_draw_puff(age)

func _draw_sweat(a: float) -> void:
	var t: float = fmod(_time, sweat_cycle) / sweat_cycle
	var slide: float = t * t * radius * 0.42
	var fade: float = a * clampf((1.0 - t) * 4.0, 0.0, 1.0) * clampf(t * 8.0, 0.0, 1.0)
	if fade <= 0.01:
		return
	var h: float = radius * sweat_size
	var at: Vector2 = center + Vector2(-facing * radius * 0.7, -radius * 0.32 + slide)
	# 위가 뾰족한 물방울 — 아래 원 + 꼭짓점
	var ring := PackedVector2Array()
	ring.append(at + Vector2(0.0, -h))
	var body_r: float = h * 0.44
	var body_c: Vector2 = at + Vector2(0.0, h * 0.26)
	for k in 13:
		var ang: float = deg_to_rad(-60.0 + 300.0 * float(k) / 12.0)
		ring.append(body_c + Vector2(cos(ang), sin(ang)) * body_r)
	draw_colored_polygon(ring, Color(sweat_color, sweat_color.a * fade))
	ring.append(ring[0])
	draw_polyline(ring, Color(line_color, fade), maxf(radius * 0.022, 2.0), true)
	draw_circle(body_c + Vector2(-body_r * 0.35, -body_r * 0.3), body_r * 0.22, Color(1, 1, 1, 0.9 * fade))

func _draw_puff(age: float) -> void:
	var u: float = clampf(age / maxf(puff_life, 0.01), 0.0, 1.0)
	var alpha: float = (1.0 - u) * (1.0 - u)
	if alpha <= 0.01:
		return
	var r0: float = radius * puff_size * (0.6 + 0.6 * (1.0 - pow(1.0 - u, 2.0)))
	var start: Vector2 = center + Vector2(facing * radius * 0.98, radius * 0.4)
	var at: Vector2 = start + Vector2(facing * radius * 0.42 * u, radius * 0.3 * u)
	var blobs: Array = [[Vector2.ZERO, 1.0], [Vector2(facing * 0.75, -0.3), 0.8], [Vector2(facing * 1.4, 0.05), 0.6]]
	var edge: float = maxf(radius * 0.02, 2.0)
	# 외곽선 원을 먼저 다 깔고 그 위에 속을 칠해야 덩어리 하나로 보인다
	for b in blobs:
		draw_circle(at + (b[0] as Vector2) * r0, r0 * float(b[1]) + edge, Color(line_color, alpha))
	for b in blobs:
		draw_circle(at + (b[0] as Vector2) * r0, r0 * float(b[1]), Color(puff_color, puff_color.a * alpha))

func _round_line(a: Vector2, b: Vector2, col: Color, width: float) -> void:
	draw_line(a, b, col, width, true)
	draw_circle(a, width * 0.5, col)
	draw_circle(b, width * 0.5, col)
