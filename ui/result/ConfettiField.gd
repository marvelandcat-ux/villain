extends Control

## 승리 화면 색종이 — 외곽선 두른 **네모·별·꼬불꼬불 리본**이 축포로 터지고, 위에서도 계속 흩날린다.
##
## 수백 장을 **`_draw()` 한 번에** 그린다(장마다 노드를 만들지 않는다).
##  - 축포: 처음엔 공기저항이 약해 높이 솟고, 시간이 갈수록 저항이 세져 팔랑팔랑 떨어진다
##  - 뒤집힘: 가로폭에 cos를 곱해 줄었다 늘었다 하고, 뒷면(cos < 0)은 조금 어둡게 칠한다
##  - 폭이 0이 될 수 있어서 면은 `draw_primitive`로만 칠한다(`draw_colored_polygon`은 삼각분할 에러)
##  - ⚠️ **테두리·리본도 `draw_primitive` 띠로 칠한다.** `draw_polyline`/`draw_circle`은 부를 때마다 GPU 버퍼를 새로 만들어
##    색종이 240장에 41fps, 리본만이면 14fps까지 떨어졌다(2026-10-08 실측, RTX 5070). `draw_primitive`는 한데 묶여 그려진다
## 시간은 `MatchEnding`이 `tick()`으로 넣는다(실제 시간)

enum Kind { RECT, STAR, RIBBON }

## 색종이 한 장
class Piece:
	var pos: Vector2
	var vel: Vector2
	var rot: float
	var spin: float
	var flip: float
	var flip_speed: float
	var kind: int
	## RECT: 가로x세로 / STAR: (반지름, -) / RIBBON: 길이x굵기
	var size: Vector2
	var color: Color
	var age: float
	var sway_phase: float
	var sway_freq: float
	var wave: float

## 색 — 빨강·파랑·초록·노랑·분홍(레퍼런스)
@export var colors: Array[Color] = [
	Color(0.93, 0.2, 0.22), Color(0.15, 0.42, 0.93), Color(0.13, 0.66, 0.3),
	Color(1.0, 0.8, 0.1), Color(0.98, 0.42, 0.7)]
## 외곽선 색·굵기(px)
@export var outline_color: Color = Color(0.06, 0.05, 0.08)
@export var outline_width: float = 2.4
## 전체 크기 배율 — 앞쪽 층은 크게
@export var size_scale: float = 1.0
## 별·리본이 나올 몫(나머지는 네모)
@export_range(0.0, 1.0, 0.01) var star_ratio: float = 0.16
@export_range(0.0, 1.0, 0.01) var ribbon_ratio: float = 0.12

@export_group("움직임")
## 중력(px/초²)
@export var gravity: float = 900.0
## 막 쏘아졌을 때의 공기저항 → 팔랑일 때의 공기저항(1/초). 떨어지는 끝 속도 ≈ gravity / flutter_drag
@export var launch_drag: float = 0.85
@export var flutter_drag: float = 4.2
## 저항이 약한 쪽에서 센 쪽으로 넘어가는 시간(초)
@export var drag_ramp_time: float = 0.9
## 팔랑일 때 좌우로 흔들리는 세기(px/초)
@export var sway_amount: float = 70.0

@export_group("흩날리기")
## 위에서 계속 떨어뜨리는 양(장/초). 0이면 축포만
@export var fall_rate: float = 30.0
## 한 번에 살아 있을 수 있는 최대 장수
@export var max_pieces: int = 420

## 켜 두면 위에서 계속 흩날린다
var raining: bool = false

var _pieces: Array[Piece] = []
var _rng := RandomNumberGenerator.new()
var _spawn_debt: float = 0.0
## 리본 끝 둥근 마개(10각형)의 꼭짓점 방향
var _disc_dirs := PackedVector2Array()

const DISC_SIDES := 10

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	for k in DISC_SIDES:
		_disc_dirs.append(Vector2.from_angle(TAU * float(k) / float(DISC_SIDES)))

## 축포 한 방 — origin에서 angle_deg(−90 = 바로 위) 쪽으로 spread_deg만큼 벌려 count장 쏜다
func burst(origin: Vector2, angle_deg: float, spread_deg: float, count: int, speed_min: float, speed_max: float) -> void:
	for i in count:
		if _pieces.size() >= max_pieces:
			return
		var p := _make_piece()
		p.pos = origin + Vector2(_rng.randf_range(-34.0, 34.0), _rng.randf_range(-34.0, 34.0))
		var a: float = deg_to_rad(angle_deg + _rng.randf_range(-spread_deg, spread_deg))
		p.vel = Vector2.from_angle(a) * _rng.randf_range(speed_min, speed_max)
		p.spin = _rng.randf_range(7.0, 15.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
		_pieces.append(p)

## 한 프레임 진행(dt = 실제 초)
func tick(dt: float) -> void:
	if raining and fall_rate > 0.0:
		_spawn_debt += fall_rate * dt
		while _spawn_debt >= 1.0:
			_spawn_debt -= 1.0
			_spawn_falling()
	var bottom: float = size.y + 90.0
	var i: int = _pieces.size() - 1
	while i >= 0:
		var p: Piece = _pieces[i]
		_step(p, dt)
		if p.pos.y > bottom or p.pos.x < -260.0 or p.pos.x > size.x + 260.0:
			_pieces[i] = _pieces[_pieces.size() - 1]
			_pieces.pop_back()
		i -= 1
	queue_redraw()

func _step(p: Piece, dt: float) -> void:
	p.age += dt
	var drag: float = lerpf(launch_drag, flutter_drag, clampf(p.age / maxf(drag_ramp_time, 0.01), 0.0, 1.0))
	p.vel.y += gravity * dt
	p.vel *= exp(-drag * dt)
	# 느려질수록(팔랑일 때) 좌우로 흔들리고, 빨리 날 땐 곧게 난다
	var slow: float = clampf(1.0 - p.vel.length() / 520.0, 0.0, 1.0)
	p.pos += p.vel * dt
	p.pos.x += cos(p.age * p.sway_freq + p.sway_phase) * sway_amount * slow * dt
	p.flip += p.flip_speed * dt
	p.wave += dt * 7.0
	if p.kind == Kind.RIBBON:
		# 리본은 팔랑일수록 세로로 늘어지며 살랑인다(레퍼런스처럼 위아래로 길게)
		p.rot += p.spin * dt * (1.0 - slow)
		var hang: float = PI * 0.5 + sin(p.age * 1.6 + p.sway_phase) * 0.45
		p.rot = lerp_angle(p.rot, hang, clampf(slow * dt * 3.0, 0.0, 1.0))
	else:
		p.rot += p.spin * dt * (0.25 + 0.75 * (1.0 - slow)) + cos(p.age * p.sway_freq + p.sway_phase) * 0.9 * slow * dt

func _make_piece() -> Piece:
	var p := Piece.new()
	var roll: float = _rng.randf()
	if roll < ribbon_ratio:
		p.kind = Kind.RIBBON
		p.size = Vector2(_rng.randf_range(64.0, 104.0), _rng.randf_range(7.0, 9.0))
	elif roll < ribbon_ratio + star_ratio:
		p.kind = Kind.STAR
		p.size = Vector2(_rng.randf_range(10.0, 14.0), 0.0)
	else:
		p.kind = Kind.RECT
		p.size = Vector2(_rng.randf_range(15.0, 24.0), _rng.randf_range(8.0, 12.0))
	p.color = colors[_rng.randi() % colors.size()] if not colors.is_empty() else Color.WHITE
	p.rot = _rng.randf() * TAU
	p.flip = _rng.randf() * TAU
	p.flip_speed = _rng.randf_range(4.0, 11.0)
	p.sway_phase = _rng.randf() * TAU
	p.sway_freq = _rng.randf_range(2.2, 3.8)
	p.wave = _rng.randf() * TAU
	return p

func _spawn_falling() -> void:
	if _pieces.size() >= max_pieces:
		return
	var p := _make_piece()
	p.pos = Vector2(_rng.randf_range(-40.0, size.x + 40.0), _rng.randf_range(-90.0, -30.0))
	p.vel = Vector2(_rng.randf_range(-50.0, 50.0), _rng.randf_range(70.0, 190.0))
	p.spin = _rng.randf_range(-3.0, 3.0)
	# 이미 팔랑이는 상태로 시작한다
	p.age = drag_ramp_time
	_pieces.append(p)

func _draw() -> void:
	for p in _pieces:
		var fx: float = cos(p.flip)
		var col: Color = p.color if fx >= 0.0 else p.color.darkened(0.3)
		match p.kind:
			Kind.RECT:
				_draw_rect_piece(p, fx, col)
			Kind.STAR:
				_draw_star_piece(p, fx, col)
			Kind.RIBBON:
				_draw_ribbon_piece(p, fx, col)

func _xf(p: Piece, v: Vector2) -> Vector2:
	return p.pos + v.rotated(p.rot)

func _draw_rect_piece(p: Piece, fx: float, col: Color) -> void:
	# 가운데 걸친 테두리 = 바깥 네모(검정) 위에 안쪽 네모(색). 폭이 0이 돼도 draw_primitive라 안전하다
	var h: Vector2 = p.size * 0.5 * size_scale
	var half_w: float = absf(h.x * fx)
	var o: float = outline_width * 0.5
	_piece_quad(p, half_w + o, h.y + o, outline_color)
	_piece_quad(p, maxf(half_w - o, 0.0), maxf(h.y - o, 0.0), col)

func _piece_quad(p: Piece, hw: float, hh: float, c: Color) -> void:
	draw_primitive(PackedVector2Array([
		_xf(p, Vector2(-hw, -hh)), _xf(p, Vector2(hw, -hh)),
		_xf(p, Vector2(hw, hh)), _xf(p, Vector2(-hw, hh))]),
		PackedColorArray([c, c, c, c]), PackedVector2Array())

func _draw_star_piece(p: Piece, fx: float, col: Color) -> void:
	var r: float = p.size.x * size_scale
	var ring := PackedVector2Array()
	for k in 10:
		var a: float = -PI * 0.5 + PI * 0.2 * float(k)
		var rr: float = r if k % 2 == 0 else r * 0.46
		ring.append(_xf(p, Vector2(cos(a) * rr * fx, sin(a) * rr)))
	var colors4 := PackedColorArray([col, col, col, col])
	# 별 = 가운데에서 뻗은 볼록한 연(kite) 다섯 장 — 폭이 0이 돼도 안전하다
	for i in 5:
		var tip: int = i * 2
		draw_primitive(PackedVector2Array([p.pos, ring[(tip + 9) % 10], ring[tip], ring[tip + 1]]), colors4, PackedVector2Array())
	_stroke(ring, true, outline_width, outline_color)

func _draw_ribbon_piece(p: Piece, fx: float, col: Color) -> void:
	var length: float = p.size.x * size_scale
	var width: float = p.size.y * size_scale
	var amp: float = length * 0.13 * (0.35 + 0.65 * absf(fx))
	var pts := PackedVector2Array()
	const SEGMENTS := 14
	for k in SEGMENTS + 1:
		var u: float = float(k) / float(SEGMENTS)
		pts.append(_xf(p, Vector2((u - 0.5) * length, sin(u * 2.3 * TAU + p.wave) * amp)))
	var edge: float = width + outline_width * 2.0
	_stroke(pts, false, edge, outline_color)
	_disc(pts[0], edge * 0.5, outline_color)
	_disc(pts[SEGMENTS], edge * 0.5, outline_color)
	_stroke(pts, false, width, col)
	_disc(pts[0], width * 0.5, col)
	_disc(pts[SEGMENTS], width * 0.5, col)

## 굵은 선을 draw_primitive 띠로 그린다. 꺾이는 점은 앞뒤 변의 바깥 방향을 평균 내서 잇는다(draw_polyline과 같은 방식)
func _stroke(pts: PackedVector2Array, closed: bool, width: float, c: Color) -> void:
	var n: int = pts.size()
	if n < 2:
		return
	var half: float = width * 0.5
	var offs := PackedVector2Array()
	offs.resize(n)
	for i in n:
		var n_prev: Vector2 = _side_normal(pts[(i - 1 + n) % n], pts[i]) if (closed or i > 0) else Vector2.ZERO
		var n_next: Vector2 = _side_normal(pts[i], pts[(i + 1) % n]) if (closed or i < n - 1) else Vector2.ZERO
		var m: Vector2 = n_prev + n_next
		# 되돌아가는 뾰족 끝(납작해진 별)은 두 방향이 서로 지워지므로 한쪽만 쓴다
		if m.length_squared() < 0.000001:
			m = n_prev if n_prev != Vector2.ZERO else n_next
		offs[i] = m.normalized() * half if m != Vector2.ZERO else Vector2.ZERO
	var cols := PackedColorArray([c, c, c, c])
	var none := PackedVector2Array()
	for i in (n if closed else n - 1):
		var j: int = (i + 1) % n
		draw_primitive(PackedVector2Array([pts[i] + offs[i], pts[j] + offs[j], pts[j] - offs[j], pts[i] - offs[i]]), cols, none)

static func _side_normal(a: Vector2, b: Vector2) -> Vector2:
	var d: Vector2 = b - a
	if d.length_squared() < 0.00000001:
		return Vector2.ZERO
	return Vector2(-d.y, d.x).normalized()

## 꽉 찬 원(10각형) — 가운데가 아니라 한 꼭짓점에서 부채꼴로 네 장
func _disc(c: Vector2, r: float, col: Color) -> void:
	var ring := PackedVector2Array()
	for k in DISC_SIDES:
		ring.append(c + _disc_dirs[k] * r)
	var cols := PackedColorArray([col, col, col, col])
	for k in range(1, DISC_SIDES - 2, 2):
		draw_primitive(PackedVector2Array([ring[0], ring[k], ring[k + 1], ring[k + 2]]), cols, PackedVector2Array())
