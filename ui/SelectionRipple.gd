class_name SelectionRipple
extends Control

## 캐릭터/맵 선택 칸을 고를 때 물방울이 떨어진 것처럼 흰색 파동이 가운데서부터 바깥으로
## 퍼지며 옅어지는 효과. 자유롭게 퍼지는 원이 아니라 그 칸의 실제 테두리 모양(사각형/FanTile
## 사다리꼴)에 고정해서 그 모양 그대로 커지며 퍼지되, 둘레에 살짝 물결 요철을 더해 딱딱한
## 확대가 아니라 물방울 파동처럼 보이게 한다. 고른 칸(버튼)의 자식으로 잠깐 붙었다가 재생이
## 끝나면 스스로 사라진다(queue_free) — 씬에 미리 놓아두는 노드가 아니라 spawn()으로
## 그때그때 만들어 붙이는 1회용 이펙트.

const RING_COUNT := 3
const RING_DELAY := 0.16
const DURATION := 0.9
const MAX_EXPAND := 24.0  # 칸 가장자리보다 이만큼 더 바깥까지 퍼진다
const START_WIDTH := 5.0
const END_WIDTH := 1.0
## 재생 시간 중 이 비율만큼은 밝기가 0에서부터 서서히 올라온다(갑자기 번쩍이는 느낌 방지)
const FADE_IN_FRACTION := 0.3
## 칸 모양을 벗어나지 않는 선에서 둘레가 살짝 울렁이게 하는 물결 요철 — 마디 수 / 퍼진 거리 대비 크기
const WOBBLE_FREQ := 7.0
const WOBBLE_AMOUNT := 0.05
## 변마다 이만큼 잘게 나눠야 울렁임이 각진 모서리 사이에서도 매끄러운 곡선으로 보인다
const SUBDIVISIONS := 10

## FanTile처럼 비스듬한 모양이면 이 폴리곤(칸의 로컬 좌표 기준 꼭짓점)을 기준 모양으로 삼는다.
## 비어 있으면(기본값) target의 사각형(size)을 기준 모양으로 삼는다
var polygon: PackedVector2Array = PackedVector2Array()
var _t: float = 0.0

## target 칸 위에 파동 효과를 하나 재생한다. corners를 주면 그 폴리곤 모양이, 안 주면
## target 사각형 모양이 중심에서부터 커지며 퍼져나간다
static func spawn(target: Control, corners: PackedVector2Array = PackedVector2Array()) -> void:
	if not is_instance_valid(target):
		return
	var ripple := SelectionRipple.new()
	ripple.polygon = corners
	ripple.position = Vector2.ZERO
	ripple.size = target.size
	target.add_child(ripple)

## 파동이 완전히 끝나기까지 걸리는 시간(초) — 마지막 고리(RING_COUNT-1번째)가 시작해서 DURATION만큼
## 재생을 마치는 시점. 파동을 다 보여준 뒤에 다음 화면으로 넘어가고 싶을 때 이 값만큼 기다리면 된다
static func total_duration() -> float:
	return DURATION + (RING_COUNT - 1) * RING_DELAY

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	set_process(true)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= total_duration():
		queue_free()

func _draw() -> void:
	var base_pts := _subdivided_shape()
	if base_pts.is_empty():
		return
	var center: Vector2 = _centroid(base_pts)
	var base_radius: float = _max_radius(base_pts, center)
	if base_radius <= 0.001:
		return
	for i in range(RING_COUNT):
		var local_t: float = _t - i * RING_DELAY
		if local_t < 0.0 or local_t > DURATION:
			continue
		var progress: float = local_t / DURATION
		# 시작하자마자 확 퍼지지 않도록 처음엔 천천히, 갈수록 부드럽게 커진다(ease-in-out)
		var eased: float = progress * progress * (3.0 - 2.0 * progress)
		var expand: float = lerpf(0.0, MAX_EXPAND, eased)
		if expand <= 0.5:
			continue
		# 나타나자마자 번쩍이지 않도록 처음 구간(FADE_IN_FRACTION)은 서서히 밝아진 뒤에 옅어진다
		var alpha: float = smoothstep(0.0, FADE_IN_FRACTION, progress) * pow(1.0 - progress, 1.4)
		var width: float = lerpf(START_WIDTH, END_WIDTH, progress)
		var color := Color(1.0, 1.0, 1.0, alpha)
		var scale_factor: float = (base_radius + expand) / base_radius
		draw_polyline(_expand_shape(base_pts, center, scale_factor, expand, progress), color, width, true)

## polygon이 있으면 그 꼭짓점, 없으면 target의 네 모서리 — 이 칸의 원래 테두리 모양
func _shape_points() -> PackedVector2Array:
	if polygon.size() >= 3:
		return polygon
	return PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)])

## 변마다 SUBDIVISIONS개로 잘게 나눈 테두리 — 점이 많아야 물결 요철이 각진 모서리에서도 매끄럽게 보인다
func _subdivided_shape() -> PackedVector2Array:
	var base := _shape_points()
	if base.size() < 3:
		return PackedVector2Array()
	var result := PackedVector2Array()
	var n := base.size()
	for i in range(n):
		var a: Vector2 = base[i]
		var b: Vector2 = base[(i + 1) % n]
		for s in range(SUBDIVISIONS):
			result.append(a.lerp(b, float(s) / float(SUBDIVISIONS)))
	return result

func _centroid(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	return c / pts.size()

## 중심에서 가장 먼 꼭짓점까지 거리 — 이 값을 기준으로 확대 비율을 계산한다
func _max_radius(pts: PackedVector2Array, center: Vector2) -> float:
	var farthest: float = 0.0
	for p in pts:
		farthest = maxf(farthest, p.distance_to(center))
	return farthest

## 테두리 모양을 중심 기준으로 scale_factor배 키우고, 그 위에 물결처럼 살짝 울렁이는 요철을 더한다.
## 요철도 각 점이 중심에서 뻗어나가는 방향을 따라만 움직이므로 칸 모양(사다리꼴 기울기 등)을 벗어나지 않는다
func _expand_shape(pts: PackedVector2Array, center: Vector2, scale_factor: float, expand: float, progress: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in pts:
		var offset: Vector2 = p - center
		var dir: Vector2 = offset.normalized() if offset.length() > 0.001 else Vector2.RIGHT
		var wobble: float = sin(dir.angle() * WOBBLE_FREQ + progress * TAU * 1.5) * expand * WOBBLE_AMOUNT
		result.append(center + offset * scale_factor + dir * wobble)
	result.append(result[0])
	return result
