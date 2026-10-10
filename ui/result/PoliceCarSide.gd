extends Node2D

## 연행 장면(ArrestScene) 맨 앞 왼쪽의 **경찰차**(앞모습이 크게 보이게 비스듬히 선 차).
## 그림이 없어서 코드로 그린다 — TODO: 비스듬한 경찰차 그림이 오면 Sprite2D로 바꿀 것
## (지금 있는 `궁극기경찰차.png`는 정면 + 배경까지 칠해진 그림이라 못 쓴다).
##
## 차를 상자 몇 개로 잡고 **ArrestScene과 같은 카메라로 투영**한다 — 그래서 바닥 선·인물 크기와 원근이 맞고,
## 밀고 들어가기(dolly) 때 가까운 차가 사람보다 더 빨리 커진다.
## 게임 그림체에 맞춰 면마다 납작한 색 한 가지 + 두꺼운 검은 외곽선. 카메라를 향한 면만 그린다.
##
## 차 좌표: u = 앞(+)·뒤(-), 앞범퍼가 0 / v = 카메라 쪽 옆면(0) → 먼 옆면(width) / y = 높이.
## 단위는 **캐릭터 키 = 1**(ArrestScene과 같다)

# --- ArrestScene이 매 프레임 넣는 카메라 값(같은 카메라라야 바닥과 맞는다) ---
var vanish_x: float = 760.0
var horizon_y: float = 470.0
var camera_height: float = 0.62
var focal: float = 1500.0
var dolly: float = 0.0
## 실제 시간(초) — 경광등 박자에만 쓴다
var time: float = 0.0
## 사이렌 소리에 맞출 때 장면이 매 프레임 넣는다: 1 = 높은음(빨강), -1 = 낮은음(파랑), 0 = 소리 없이 혼자 돈다(siren_cycle)
var siren_tone: int = 0
## 지금 음이 시작되고 흐른 초 — 음이 바뀌는 순간 첫 번쩍이 터진다
var tone_time: float = 0.0

@export_group("자리")
## 앞범퍼의 카메라 쪽 아래 모서리가 닿는 바닥 자리(월드 X, Z)
@export var origin: Vector2 = Vector2(-1.96, 2.85)
## 차가 바라보는 방향(도). 0이면 화면 오른쪽(+X), 클수록 앞모습이 카메라 쪽으로 돈다
@export var yaw_deg: float = 70.0

@export_group("크기")
@export var length: float = 4.0
@export var width: float = 1.3
## 바퀴 반지름 / 앞범퍼에서 앞바퀴 중심까지 / 뒷범퍼에서 뒷바퀴 중심까지
@export var wheel_radius: float = 0.21
@export var front_axle: float = 0.66
@export var rear_axle: float = 0.75
## 차체 아래 / 범퍼 위 / 앞면 위(보닛 앞 모서리) / 보닛 끝(앞유리 밑) / 지붕 높이
@export var body_bottom: float = 0.12
@export var bumper_top: float = 0.24
@export var nose_top: float = 0.47
@export var hood_back_y: float = 0.56
@export var roof_y: float = 0.9
## 보닛 길이(앞범퍼 → 앞유리 밑) / 앞유리가 눕는 길이 / 지붕 길이
@export var hood_length: float = 0.85
@export var windshield_run: float = 0.45
@export var roof_length: float = 1.35

@export_group("색")
@export var line_color: Color = Color(0.07, 0.07, 0.09)
@export var line_width: float = 3.4
## 빛을 받는 면(카메라 쪽 옆면) / 그늘진 면(앞면) / 위를 보는 면(보닛)
@export var body_lit: Color = Color(0.96, 0.97, 0.99)
@export var body_shade: Color = Color(0.83, 0.86, 0.91)
@export var body_top: Color = Color(1.0, 1.0, 1.0)
## 남색 띠 / 띠 위의 하늘색 가는 줄
@export var stripe_color: Color = Color(0.11, 0.2, 0.47)
@export var pinstripe_color: Color = Color(0.36, 0.64, 0.95)
@export var glass_color: Color = Color(0.16, 0.24, 0.38)
@export var glass_shine: Color = Color(0.42, 0.56, 0.76)
@export var bumper_color: Color = Color(0.23, 0.25, 0.29)
@export var grille_color: Color = Color(0.13, 0.14, 0.17)
@export var headlight_color: Color = Color(1.0, 0.96, 0.74)
@export var tire_color: Color = Color(0.11, 0.11, 0.13)
@export var rim_color: Color = Color(0.68, 0.71, 0.76)

@export_group("경광등")
@export var siren_red: Color = Color(1.0, 0.18, 0.2)
@export var siren_blue: Color = Color(0.2, 0.5, 1.0)
## 경광등이 꺼졌을 때 밝기(켜진 색에 곱한다)
@export_range(0.0, 1.0, 0.05) var siren_dim: float = 0.42
## 빨강·파랑 한 바퀴(빨강 두 번 번쩍 → 파랑 두 번 번쩍)에 걸리는 시간(초). 사이렌 소리에 맞출 땐(siren_tone) 안 쓴다
@export var siren_cycle: float = 0.62
## 사이렌에 맞출 때 한 음 안에서 두 번 번쩍이는 박자(초): 첫 번쩍 끝 / 둘째 시작 / 둘째 끝
@export var tone_flash: Vector3 = Vector3(0.16, 0.22, 0.4)
## 켜진 쪽에서 뻗는 빛살 길이(캐릭터 키 기준)
@export var ray_length: float = 0.62

const LineMesh = preload("res://ui/result/LineMesh.gd")

var _f: Vector3 = Vector3.RIGHT
var _s: Vector3 = Vector3.BACK
const UP := Vector3(0.0, 1.0, 0.0)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var a: float = deg_to_rad(yaw_deg)
	_f = Vector3(cos(a), 0.0, -sin(a))
	_s = Vector3(sin(a), 0.0, cos(a))
	var w: float = width
	var rear: float = -length
	var ws_base: float = -hood_length
	var ws_top: float = ws_base - windshield_run
	var roof_end: float = ws_top - roof_length
	var rear_glass: float = roof_end - windshield_run

	# 1) 차 밑 그림자 — 바닥에 붙어 있게
	_quad([_w(0.05, -0.05, 0.0), _w(0.05, w + 0.04, 0.0), _w(rear - 0.05, w + 0.04, 0.0), _w(rear - 0.05, -0.05, 0.0)],
		Color(0.1, 0.09, 0.12, 0.32), false)

	# 2) 바퀴 — 차체보다 먼저(옆면의 바퀴 구멍으로 보인다). 먼 쪽 바퀴는 범퍼 밑으로 타이어만 살짝 보인다
	_wheel(-front_axle, w - 0.05, false)
	_wheel(rear + rear_axle, 0.05, true)
	_wheel(-front_axle, 0.05, true)

	# 앞에서 본 앞바퀴 두 개 — 범퍼 밑으로 타이어 아랫부분이 보여야 차가 바닥에 선다
	var tire_u: float = -front_axle + wheel_radius
	for span in [Vector2(0.03, 0.24), Vector2(w - 0.24, w - 0.03)]:
		_quad([_w(tire_u, span.x, 0.0), _w(tire_u, span.y, 0.0), _w(tire_u, span.y, wheel_radius * 1.6), _w(tire_u, span.x, wheel_radius * 1.6)], tire_color)

	# 3) 앞면 — 범퍼·그릴·전조등·번호판
	if _sees(_f, _w(0.0, 0.0, body_bottom)):
		_quad([_w(0, 0, body_bottom), _w(0, w, body_bottom), _w(0, w, nose_top), _w(0, 0, nose_top)], body_shade)
		_front_box(0.0, w, body_bottom, bumper_top, bumper_color)
		_front_box(0.0, w, bumper_top, bumper_top + 0.035, stripe_color, false)
		_front_box(0.4, w - 0.4, bumper_top + 0.05, nose_top - 0.07, grille_color)
		for k in range(1, 3):
			var gy: float = lerpf(bumper_top + 0.05, nose_top - 0.07, k / 3.0)
			draw_line(_p(_w(0.0, 0.43, gy)), _p(_w(0.0, w - 0.43, gy)), Color(0.32, 0.34, 0.4), 2.0, true)
		_front_box(0.07, 0.34, bumper_top + 0.09, nose_top - 0.035, headlight_color)
		_front_box(w - 0.34, w - 0.07, bumper_top + 0.09, nose_top - 0.035, headlight_color)
		_front_box(0.11, 0.21, bumper_top + 0.12, nose_top - 0.07, Color(1, 1, 1), false)
		_front_box(w - 0.3, w - 0.2, bumper_top + 0.12, nose_top - 0.07, Color(1, 1, 1), false)
		_front_box(w * 0.5 - 0.17, w * 0.5 + 0.17, body_bottom + 0.025, bumper_top - 0.025, Color(0.97, 0.97, 0.95))
		_outline([_w(0, 0, body_bottom), _w(0, w, body_bottom), _w(0, w, nose_top), _w(0, 0, nose_top)])

	# 4) 카메라 쪽 옆면 — 바퀴 구멍을 뚫은 판 + 남색 띠
	if _sees(-_s, _w(0.0, 0.0, body_bottom)):
		var side: Array = _side_profile(rear)
		_poly(side, body_lit)
		_side_stripe(rear, 0.3, 0.38, stripe_color)
		_side_stripe(rear, 0.395, 0.415, pinstripe_color)
		_outline(side)

	# 5) 보닛 앞 모서리(비스듬한 면)와 보닛 윗면 — 카메라가 보닛보다 조금 높아 가늘게만 보인다
	var bevel: Array = [_w(0, 0, nose_top), _w(0, w, nose_top), _w(-0.1, w - 0.02, nose_top + 0.06), _w(-0.1, 0.02, nose_top + 0.06)]
	if _sees((_f * 0.06 + UP * 0.1).normalized(), bevel[0]):
		_quad(bevel, body_lit)
	# 보닛 + 지붕 아래 어깨 + 트렁크를 한 장으로 — 가운데는 뒤에 그리는 유리·지붕이 덮는다
	var deck: Array = [_w(-0.1, 0.02, nose_top + 0.06), _w(-0.1, w - 0.02, nose_top + 0.06), _w(ws_base, w, hood_back_y),
		_w(rear + 0.1, w, hood_back_y), _w(rear + 0.1, 0.0, hood_back_y), _w(ws_base, 0.0, hood_back_y)]
	if _sees((_f * (hood_back_y - nose_top - 0.06) + UP * (hood_length - 0.1)).normalized(), deck[0]):
		_poly(deck, body_top)

	# 6) 앞유리 + 옆 유리
	var glass_in: float = 0.1
	var roof_in: float = 0.17
	var shield: Array = [_w(ws_base, glass_in, hood_back_y), _w(ws_base, w - glass_in, hood_back_y), _w(ws_top, w - roof_in, roof_y), _w(ws_top, roof_in, roof_y)]
	if _sees((_f * (roof_y - hood_back_y) + UP * windshield_run).normalized(), shield[0]):
		# 차체색 테두리(기둥·지붕 앞 끝) 안쪽에 유리를 넣어야 "차 앞유리"로 읽힌다
		_quad(shield, body_lit, false)
		var pane: Array = [_lerp_quad(shield, 0.05, 0.05), _lerp_quad(shield, 0.95, 0.05), _lerp_quad(shield, 0.93, 0.84), _lerp_quad(shield, 0.07, 0.84)]
		_quad(pane, glass_color, false)
		# 비스듬한 반사 줄 — 유리로 읽히게
		_quad([_lerp_quad(pane, 0.2, 0.0), _lerp_quad(pane, 0.33, 0.0), _lerp_quad(pane, 0.25, 1.0), _lerp_quad(pane, 0.14, 1.0)], glass_shine, false)
		_quad([_lerp_quad(pane, 0.37, 0.0), _lerp_quad(pane, 0.41, 0.0), _lerp_quad(pane, 0.33, 1.0), _lerp_quad(pane, 0.29, 1.0)], glass_shine, false)
		_outline(pane)
		_outline(shield)
		# 사이드미러는 카메라 쪽 하나만 — 먼 쪽 거울은 이 각도에서 경찰 얼굴 앞에 둥둥 떠 보인다
		_mirror(ws_base - 0.04, -0.17, 0.0)
	var side_glass: Array = [_w(ws_base, glass_in, hood_back_y), _w(ws_top, roof_in, roof_y), _w(roof_end, roof_in, roof_y), _w(rear_glass, glass_in, hood_back_y)]
	if _sees(-_s, side_glass[0]):
		_poly(side_glass, glass_color, false)
		# 가운데 기둥(B필러)
		var bu: float = lerpf(ws_top, roof_end, 0.46)
		_quad([_w(bu + 0.06, glass_in, hood_back_y), _w(bu + 0.06, roof_in, roof_y), _w(bu - 0.06, roof_in, roof_y), _w(bu - 0.06, glass_in, hood_back_y)], body_lit)
		_outline(side_glass)

	# 7) 경광등 — 지붕 위 막대. 가까운 절반 빨강, 먼 절반 파랑이 번갈아 두 번씩 번쩍
	_siren_bar(ws_top - 0.12, ws_top - 0.47, w)

## 차 좌표 -> 월드(X, Y, Z)
func _w(u: float, v: float, y: float) -> Vector3:
	return Vector3(origin.x, y, origin.y) + _f * u + _s * v

## 월드 -> 화면(이 노드 좌표). ArrestScene의 투영과 같은 식
func _p(p: Vector3) -> Vector2:
	var z: float = maxf(p.z - dolly, 0.05)
	return Vector2(vanish_x + focal * p.x / z, horizon_y + focal * (camera_height - p.y) / z)

## 바깥을 보는 법선이 normal인 면이 카메라를 향하는지
func _sees(normal: Vector3, on_face: Vector3) -> bool:
	return normal.dot(Vector3(0.0, camera_height, dolly) - on_face) > 0.0

func _px_per_unit(p: Vector3) -> float:
	return focal / maxf(p.z - dolly, 0.05)

func _projected(pts3: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts3:
		out.append(_p(p))
	return out

static func _area(pts: PackedVector2Array) -> float:
	var s: float = 0.0
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		s += a.x * b.y - b.x * a.y
	return s * 0.5

## 네 점짜리 면 — draw_primitive라 거의 납작하게 눌려도 삼각분할 에러가 안 난다
func _quad(pts3: Array, fill: Color, line: bool = true) -> void:
	var pts: PackedVector2Array = _projected(pts3)
	if absf(_area(pts)) < 0.5:
		return
	draw_primitive(pts, PackedColorArray([fill, fill, fill, fill]), PackedVector2Array())
	if line:
		_outline_pts(pts)

## 점이 많은(오목할 수 있는) 면
func _poly(pts3: Array, fill: Color, line: bool = true) -> void:
	var pts: PackedVector2Array = _projected(pts3)
	if absf(_area(pts)) < 4.0:
		return
	draw_colored_polygon(pts, fill)
	if line:
		_outline_pts(pts)

func _outline(pts3: Array) -> void:
	_outline_pts(_projected(pts3))

## 두꺼운 외곽선 — 꼭짓점에 동그라미를 찍어 모서리가 끊겨 보이지 않게 한다.
## ⚠️ 선과 동그라미를 **삼각형 묶음 하나**(`LineMesh`)로 그린다. draw_polyline + 꼭짓점마다 draw_circle이면
## 바퀴·옆면 꼭짓점 수백 개가 그리기 한 번씩이라 경찰차 하나에 연행 장면이 70 → 195fps 차이가 났다(2026-10-08 실측)
func _outline_pts(pts: PackedVector2Array) -> void:
	if pts.size() < 2:
		return
	var mesh := LineMesh.new()
	mesh.add_line(pts, PackedColorArray([line_color]), line_width, true)
	for p in pts:
		mesh.add_disc(p, line_width * 0.5, line_color, 10)
	mesh.draw_on(self)

## 앞면(u = 0) 위의 네모 하나
func _front_box(v0: float, v1: float, y0: float, y1: float, fill: Color, line: bool = true) -> void:
	var u: float = 0.0
	_quad([_w(u, v0, y0), _w(u, v1, y0), _w(u, v1, y1), _w(u, v0, y1)], fill, line)

## 네모 면 안의 한 점 — s는 0번→1번 모서리 방향, t는 아래(0)→위(1)
static func _lerp_quad(q: Array, s: float, t: float) -> Vector3:
	var bottom: Vector3 = (q[0] as Vector3).lerp(q[1], s)
	var top: Vector3 = (q[3] as Vector3).lerp(q[2], s)
	return bottom.lerp(top, t)

## 카메라 쪽 옆면의 윤곽 — 아랫변에 바퀴 구멍 두 개를 반원으로 뚫는다
func _side_profile(rear: float) -> Array:
	var out: Array = []
	var arch_r: float = wheel_radius + 0.06
	var yc: float = wheel_radius
	out.append(_w(0.0, 0.0, body_bottom))
	for axle in [-front_axle, rear + rear_axle]:
		var from_deg: float = rad_to_deg(asin(clampf((body_bottom - yc) / arch_r, -1.0, 1.0)))
		# 앞(+u)쪽에서 시작해 위로 넘어 뒤(-u)쪽으로 — 아랫변을 따라 앞→뒤로 가는 순서
		var steps: int = 14
		for i in range(steps + 1):
			var deg: float = lerpf(from_deg, 180.0 - from_deg, float(i) / steps)
			var r: float = deg_to_rad(deg)
			out.append(_w(axle + cos(r) * arch_r, 0.0, yc + sin(r) * arch_r))
	out.append(_w(rear, 0.0, body_bottom))
	out.append(_w(rear, 0.0, nose_top))
	out.append(_w(rear + 0.1, 0.0, hood_back_y))
	out.append(_w(-hood_length, 0.0, hood_back_y))
	out.append(_w(-0.1, 0.0, nose_top + 0.06))
	out.append(_w(0.0, 0.0, nose_top))
	return out

## 옆면의 가로 띠 — 바퀴 구멍과 겹치는 곳은 끊는다
func _side_stripe(rear: float, y0: float, y1: float, fill: Color) -> void:
	var arch_r: float = wheel_radius + 0.06
	var yc: float = wheel_radius
	var cuts: Array = []
	for axle in [-front_axle, rear + rear_axle]:
		var half0: float = sqrt(maxf(arch_r * arch_r - pow(y0 - yc, 2.0), 0.0))
		var half1: float = sqrt(maxf(arch_r * arch_r - pow(y1 - yc, 2.0), 0.0))
		cuts.append([axle, half0, half1])
	# 앞에서 뒤로: [0 .. 앞바퀴 앞] [앞바퀴 뒤 .. 뒷바퀴 앞] [뒷바퀴 뒤 .. 뒤끝]
	var starts: Array = [[0.0, 0.0]]
	var ends: Array = []
	for c in cuts:
		ends.append([c[0] + c[1], c[0] + c[2]])
		starts.append([c[0] - c[1], c[0] - c[2]])
	ends.append([rear, rear])
	for i in starts.size():
		var a: Array = starts[i]
		var b: Array = ends[i]
		if a[0] <= b[0] + 0.01:
			continue
		_quad([_w(a[0], 0.0, y0), _w(a[1], 0.0, y1), _w(b[1], 0.0, y1), _w(b[0], 0.0, y0)], fill, false)

## 바퀴 하나 — 차 옆면과 같은 평면에 놓인 원을 투영한다(비스듬히 보면 타원)
func _wheel(axle: float, v: float, show_rim: bool) -> void:
	var ring := func(radius: float) -> Array:
		var pts: Array = []
		for i in 24:
			var t: float = TAU * i / 24.0
			pts.append(_w(axle + cos(t) * radius, v, wheel_radius + sin(t) * radius))
		return pts
	_poly(ring.call(wheel_radius), tire_color)
	if show_rim:
		_poly(ring.call(wheel_radius * 0.56), rim_color)
		_poly(ring.call(wheel_radius * 0.2), Color(0.42, 0.45, 0.5), false)

## 지붕 위 경광등 막대. u0(앞)~u1(뒤), 가로는 차 폭 안쪽.
## 카메라가 지붕보다 낮아 윗면은 안 보인다 — 앞면을 두툼하게 잡고 반짝이는 줄을 그어 둥근 덮개처럼 보이게 한다
func _siren_bar(u0: float, u1: float, w: float) -> void:
	var y0: float = roof_y
	var y1: float = roof_y + 0.15
	var v0: float = 0.14
	var v1: float = w - 0.14
	var mid: float = w * 0.5
	var red_on: bool
	var blue_on: bool
	if siren_tone != 0:
		# 사이렌 높은음 = 빨강, 낮은음 = 파랑 — 음이 바뀌는 순간에 맞춰 두 번 번쩍
		var flash: bool = _tone_flash_on(tone_time)
		red_on = siren_tone > 0 and flash
		blue_on = siren_tone < 0 and flash
	else:
		var phase: float = fposmod(time / maxf(siren_cycle, 0.05), 1.0)
		red_on = _flash_on(phase)
		blue_on = _flash_on(fposmod(phase + 0.5, 1.0))
	var red_center: Vector3 = _w(u0, (v0 + mid) * 0.5, (y0 + y1) * 0.5)
	var blue_center: Vector3 = _w(u0, (mid + v1) * 0.5, (y0 + y1) * 0.5)
	# 켜진 쪽 빛살 — 막대보다 먼저 그려서 막대가 위에 온다
	if red_on:
		_rays(red_center, siren_red, 0.0)
	if blue_on:
		_rays(blue_center, siren_blue, 0.35)
	var red: Color = siren_red.lightened(0.15) if red_on else siren_red.darkened(1.0 - siren_dim)
	var blue: Color = siren_blue.lightened(0.15) if blue_on else siren_blue.darkened(1.0 - siren_dim)
	# 받침 — 지붕에 박힌 검은 다리
	_quad([_w(u0 + 0.02, v0 + 0.05, y0 - 0.025), _w(u0 + 0.02, v1 - 0.05, y0 - 0.025), _w(u0 + 0.02, v1 - 0.05, y0 + 0.02), _w(u0 + 0.02, v0 + 0.05, y0 + 0.02)], bumper_color, false)
	if _sees(_f, _w(u0, v0, y0)):
		_quad([_w(u0, v0, y0), _w(u0, mid - 0.05, y0), _w(u0, mid - 0.05, y1), _w(u0, v0, y1)], red, false)
		_quad([_w(u0, mid - 0.05, y0), _w(u0, mid + 0.05, y0), _w(u0, mid + 0.05, y1), _w(u0, mid - 0.05, y1)], Color(0.86, 0.88, 0.92), false)
		_quad([_w(u0, mid + 0.05, y0), _w(u0, v1, y0), _w(u0, v1, y1), _w(u0, mid + 0.05, y1)], blue, false)
		# 켜진 등은 가운데가 하얗게 달아오른다
		if red_on:
			_quad([_w(u0, v0 + 0.08, y0 + 0.045), _w(u0, mid - 0.13, y0 + 0.045), _w(u0, mid - 0.13, y1 - 0.045), _w(u0, v0 + 0.08, y1 - 0.045)], Color(1, 0.93, 0.93), false)
		if blue_on:
			_quad([_w(u0, mid + 0.13, y0 + 0.045), _w(u0, v1 - 0.08, y0 + 0.045), _w(u0, v1 - 0.08, y1 - 0.045), _w(u0, mid + 0.13, y1 - 0.045)], Color(0.92, 0.96, 1), false)
		# 덮개 반짝임 한 줄
		draw_line(_p(_w(u0, v0 + 0.04, y1 - 0.03)), _p(_w(u0, v1 - 0.04, y1 - 0.03)), Color(1, 1, 1, 0.55), 2.0, true)
		_outline([_w(u0, v0, y0), _w(u0, v1, y0), _w(u0, v1, y1), _w(u0, v0, y1)])
	if _sees(-_s, _w(u0, v0, y0)):
		var side: Array = [_w(u0, v0, y0), _w(u0, v0, y1), _w(u1, v0, y1), _w(u1, v0, y0)]
		_quad(side, red.darkened(0.12))

## 사이드미러 앞면(v0~v1은 차 옆으로 튀어나온 범위)
func _mirror(u: float, v0: float, v1: float) -> void:
	var y0: float = hood_back_y + 0.03
	var y1: float = hood_back_y + 0.14
	if not _sees(_f, _w(u, v0, y0)):
		return
	_quad([_w(u, v0, y0), _w(u, v1, y0), _w(u, v1, y1), _w(u, v0, y1)], body_lit)
	_quad([_w(u, v0, y0), _w(u, v1, y0), _w(u, v1, y0 + 0.035), _w(u, v0, y0 + 0.035)], stripe_color, false)

## 한 음이 시작되고 t초 지났을 때 켜져 있는지 — 시작하자마자 번쩍, 잠깐 꺼졌다 한 번 더
func _tone_flash_on(t: float) -> bool:
	return (t >= 0.0 and t < tone_flash.x) or (t >= tone_flash.y and t < tone_flash.z)

## 빨강/파랑 각자 반 바퀴 안에서 두 번 번쩍 — "삐용삐용"보다 "번쩍번쩍"으로 보이게
static func _flash_on(phase: float) -> bool:
	if phase >= 0.5:
		return false
	return phase < 0.17 or (phase >= 0.25 and phase < 0.42)

## 켜진 등에서 뻗는 들쭉날쭉한 빛살(게임의 궁극기 경찰차 그림처럼 번개 모양) + 은은한 번짐.
## 낮 장면이라 번짐만으론 안 보여서 빛살은 진한 색으로 칠한다
func _rays(center3: Vector3, color: Color, seed_shift: float) -> void:
	var c: Vector2 = _p(center3)
	var unit: float = _px_per_unit(center3)
	var reach_base: float = unit * ray_length
	draw_circle(c, reach_base * 0.62, Color(color, 0.14))
	draw_circle(c, reach_base * 0.36, Color(color.lightened(0.35), 0.32))
	var count: int = 10
	for i in count:
		var long: bool = i % 2 == 0
		var ang: float = TAU * i / count + seed_shift + sin(time * 6.0 + i * 1.7) * 0.05
		var reach: float = reach_base * (1.0 if long else 0.58) * (0.88 + 0.12 * sin(time * 13.0 + i * 2.1))
		var half: float = unit * (0.045 if long else 0.032)
		var dir := Vector2(cos(ang), sin(ang))
		var nrm := Vector2(-dir.y, dir.x)
		var jag: Vector2 = nrm * half * (0.9 if i % 4 < 2 else -0.9)
		var base_l: Vector2 = c + nrm * half
		var base_r: Vector2 = c - nrm * half
		var mid_l: Vector2 = c + dir * reach * 0.5 + nrm * half * 0.55 + jag
		var mid_r: Vector2 = c + dir * reach * 0.42 - nrm * half * 0.55 + jag
		var tip: Vector2 = c + dir * reach
		var solid := Color(color, 0.95)
		var mid_col := Color(color, 0.72)
		draw_primitive(PackedVector2Array([base_l, mid_l, mid_r, base_r]), PackedColorArray([solid, mid_col, mid_col, solid]), PackedVector2Array())
		draw_primitive(PackedVector2Array([mid_l, tip, mid_r]), PackedColorArray([mid_col, Color(color, 0.0), mid_col]), PackedVector2Array())
		if long:
			# 가운데 하얀 심
			var core_tip: Vector2 = c + dir * reach * 0.42
			draw_primitive(PackedVector2Array([c + nrm * half * 0.4, core_tip, c - nrm * half * 0.4]),
				PackedColorArray([Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.85)]), PackedVector2Array())
	draw_circle(c, unit * 0.05, Color(1, 1, 1, 0.95))
