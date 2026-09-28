@tool
class_name LensGlint
extends Node2D

## 안경·선글라스 렌즈 위로 가끔 흰 빛줄기가 "번쩍" 훑고 지나간다 — 눈이 안 보이는 캐릭터의 눈 깜빡임 대신(2026-09-26 사용자 요청).
## 악플러·캣맘·지하철 아저씨가 쓴다. **리그의 `Head` 스프라이트 자식으로 달고, 노드 위치를 렌즈 한가운데에 둔다.**
## 좌표·크기는 머리 그림 픽셀 단위다(Head 배율을 물려받는다). 빛줄기는 렌즈 타원 안에서만 그려진다.
## 조명 무시(unshaded)라 어두운 맵에서도 번쩍인다. 머리 그림이 처음 것(기본 얼굴)일 때만 나온다(EyeBlink와 같은 규칙)

## 렌즈 크기(머리 그림 픽셀) — 렌즈 테두리 안쪽에 맞출 것(넘치면 안경테 위로 빛이 샌다)
@export var lens_size: Vector2 = Vector2(200, 200)
## 빛줄기 굵기(렌즈 너비 대비)와 기울기(세로로 내려갈수록 가로로 밀리는 정도)
@export var band_width: float = 0.2
@export var slant: float = 0.7
## 뒤따라오는 가는 줄 굵기·간격(렌즈 너비 대비). 굵기 0이면 안 그림
@export var trail_width: float = 0.06
@export var trail_gap: float = 0.34
## 빛 색 — 렌즈가 흰색이면(악플러) 흰 빛이 안 보이니 옅은 하늘색으로 준다
@export var glint_color: Color = Color(1.0, 1.0, 1.0, 0.85)
## 빛줄기 둘레에 두르는 테두리 색·두께(렌즈 너비 대비). 투명(알파 0)이면 안 그린다.
## **렌즈가 흰색이면(악플러) 흰 빛이 렌즈에 묻히므로** 옅은 하늘색 테두리를 둘러 흰 빛줄기가 도드라지게 한다(2026-09-28 사용자 요청 "하얀색 느낌")
@export var band_edge_color: Color = Color(0, 0, 0, 0)
@export var band_edge_width: float = 0.05
## 빛줄기가 지나갈 때 렌즈 모서리에 튀는 반짝 별(✦) 크기(머리 그림 픽셀). 0이면 안 나온다
@export var sparkle_size: float = 0.0
## 반짝 별 위치(렌즈 크기 대비, 가운데 기준) — 기본은 오른쪽 위 모서리
@export var sparkle_at: Vector2 = Vector2(0.32, -0.32)

@export_group("박자")
## 한 번 훑고 지나가는 시간(초)
@export var sweep_time: float = 0.3
## 다음 반짝임까지 기다리는 시간 범위(초)
@export var interval_min: float = 3.5
@export var interval_max: float = 7.5

@export_group("에디터")
## 에디터에서 빛줄기 위치를 미리 본다(0 시작 ~ 1 끝, 음수면 안 보임). 게임에는 영향 없다
@export_range(-0.05, 1.0, 0.05) var preview: float = -0.05:
	set(v):
		preview = v
		queue_redraw()

## 렌즈 가로를 몇 조각으로 나눠 칠할지 — 타원을 다각형 하나로 자르면 분할이 실패할 수 있어 세로 띠로 칠한다
const STRIPS: int = 24

var _base_texture: Texture2D
var _wait: float = 0.0
var _t: float = -1.0

func _ready() -> void:
	var head := get_parent() as Sprite2D
	if head:
		_base_texture = head.texture
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	_wait = randf_range(interval_min, interval_max)

## 지금 바로 한 번 번쩍인다(훈련장 "눈 깜빡임" 버튼이 이 이름으로 부른다)
func blink_now() -> void:
	_t = 0.0

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if not _can_show():
		_t = -1.0
		queue_redraw()
		return
	if _t < 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_t = 0.0
	else:
		_t += delta
		if _t >= sweep_time:
			_t = -1.0
			_wait = randf_range(interval_min, interval_max)
	queue_redraw()

## 평소 얼굴이고, 스크립트가 달린 진짜 리그일 때만(대시 잔상처럼 스크립트를 뗀 복제본에선 안 나온다)
func _can_show() -> bool:
	var head := get_parent() as Sprite2D
	if head == null or head.texture != _base_texture:
		return false
	var rig := head.get_parent()
	return rig != null and rig.has_method("play_attack_swing")

func _draw() -> void:
	var p: float = -1.0
	if Engine.is_editor_hint():
		p = preview
		# 에디터에서는 렌즈 범위를 하늘색 선으로 보여 준다 — 렌즈에 맞춰 위치·크기를 잡기 쉽게
		var ring := PackedVector2Array()
		for i in 33:
			var ang: float = TAU * i / 32.0
			ring.append(Vector2(cos(ang) * lens_size.x * 0.5, sin(ang) * lens_size.y * 0.5))
		draw_polyline(ring, Color(0.4, 0.85, 1.0, 0.9), 6.0)
	elif _t >= 0.0:
		p = _t / maxf(sweep_time, 0.001)
	if p < 0.0:
		return
	# 줄기 중심이 렌즈 왼쪽 밖에서 오른쪽 밖으로 지나간다(기울기만큼 여유를 더 준다)
	var reach: float = 1.0 + absf(slant) + band_width
	var center: float = lerpf(-reach, reach, p)
	if band_edge_color.a > 0.0:
		_draw_band(center, band_width + band_edge_width, band_edge_color)
		if trail_width > 0.0:
			_draw_band(center - trail_gap, trail_width + band_edge_width, band_edge_color)
	_draw_band(center, band_width, glint_color)
	if trail_width > 0.0:
		_draw_band(center - trail_gap, trail_width, Color(glint_color, glint_color.a * 0.8))
	if sparkle_size > 0.0:
		_draw_sparkle(p)

## 반짝 별 — 빛줄기가 절반쯤 지나갈 때 커졌다 줄어든다. 흰 렌즈 위에서도 보이게 어두운 테두리를 먼저 깐다
func _draw_sparkle(p: float) -> void:
	var k: float = clampf((p - 0.25) / 0.75, 0.0, 1.0)
	var s: float = sin(PI * k) * sparkle_size
	if s <= 0.5:
		return
	var c: Vector2 = Vector2(lens_size.x * sparkle_at.x, lens_size.y * sparkle_at.y)
	var pts := PackedVector2Array()
	for i in 8:
		var r: float = s if i % 2 == 0 else s * 0.28
		var ang: float = PI * 0.25 * i - PI * 0.5
		pts.append(c + Vector2(cos(ang), sin(ang)) * r)
	var outline := pts.duplicate()
	outline.append(pts[0])
	# 테두리 굵기도 별 크기에 비례(고정 8px이면 머리 배율 0.05에선 화면에 안 보인다)
	draw_polyline(outline, Color(0.05, 0.04, 0.04, 0.9), maxf(8.0, s * 0.14))
	draw_colored_polygon(pts, Color(glint_color, 1.0))

## 렌즈 타원 안에서 u = x/a + slant·y/b 가 [center - w, center + w]인 사선 띠를 세로 조각으로 칠한다
func _draw_band(center: float, w: float, col: Color) -> void:
	var a: float = lens_size.x * 0.5
	var b: float = lens_size.y * 0.5
	for i in STRIPS:
		var xs: Array[float] = [-1.0 + 2.0 * i / STRIPS, -1.0 + 2.0 * (i + 1) / STRIPS]
		var tops: Array[float] = []
		var bottoms: Array[float] = []
		var ok: bool = true
		for xn in xs:
			var half: float = sqrt(maxf(0.0, 1.0 - xn * xn))
			var y0: float
			var y1: float
			if absf(slant) < 0.001:
				if absf(xn - center) > w:
					ok = false
					break
				y0 = -half
				y1 = half
			else:
				y0 = (center - w - xn) / slant
				y1 = (center + w - xn) / slant
				if y0 > y1:
					var tmp: float = y0
					y0 = y1
					y1 = tmp
				y0 = maxf(y0, -half)
				y1 = minf(y1, half)
				if y0 >= y1:
					ok = false
					break
			tops.append(y0)
			bottoms.append(y1)
		if not ok:
			continue
		draw_primitive(PackedVector2Array([
			Vector2(xs[0] * a, tops[0] * b), Vector2(xs[1] * a, tops[1] * b),
			Vector2(xs[1] * a, bottoms[1] * b), Vector2(xs[0] * a, bottoms[0] * b)]), PackedColorArray([col, col, col, col]), PackedVector2Array())
