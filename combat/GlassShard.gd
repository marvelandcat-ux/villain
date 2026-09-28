class_name GlassShard
extends Node2D

## 주정뱅이 술병이 깨질 때 바닥에 남는 초록 유리 파편 (순수 장식 — 판정 없음).
## Hitbox가 명중 지점에서 스폰하고 setup()으로 시작 위치를 넘기면, 아래로 떨어져 바닥에 그대로 쌓인다.
## 라운드가 바뀌면 씬이 리로드되면서 함께 사라진다.
## 바닥 닿음은 그림 네모 상자가 아니라 **색이 칠해진 부분의 볼록 껍질**로 잰다(2026-09-29 사용자 요청 "폴리곤 딱 맞게" —
## 상자로 재면 돌아간 조각이 떠 있거나 파묻혔다). 껍질의 한 변이 바닥에 눕도록 돌려서 떨어뜨린다(BikeWreck와 같은 방식)

## 떨어지는 데 걸리는 시간(초)
@export var fall_time: float = 0.35
## 떨어지면서 옆으로 튀는 최대 거리(px)
@export var scatter_x: float = 26.0
## 바닥에 쌓인 뒤 이 시간(초)이 지나면 서서히 투명해지며 사라진다
@export var lifetime: float = 10.0
## 사라질 때 투명해지는 데 걸리는 시간(초)
@export var fade_time: float = 1.5
## 바닥을 못 찾았을 때(공중) 대비 아래로 쏘는 레이캐스트 길이(px)
@export var ground_probe: float = 2000.0
## 파편 그림 후보 — 스폰할 때 이 중 하나를 무작위로 골라 쓴다 (비어 있으면 씬에 지정된 기본 그림을 그대로 둔다)
@export var textures: Array[Texture2D] = []
## 파편 그림에 곱하는 색 — 그림이 밝은 형광 초록이라, 같은 맵 조명을 받아도 주변(의자·바닥)보다 빛나 보였다(2026-09-26 사용자 요청).
## 전체를 어둡게 누르고 초록을 조금 더 눌러 주변 톤에 맞춘다. (1, 1, 1)이면 그림 그대로
@export var tint: Color = Color(0.65, 0.55, 0.65)

## 그림 경로별 볼록 껍질(캔버스 가운데 기준 px) — 그림 자체를 넣어 두면 종료 때 자원이 안 풀려 경고가 나서 경로로 기억한다
static var _hull_cache: Dictionary = {}

@onready var _piece: Sprite2D = get_node_or_null("Piece")

func _ready() -> void:
	# 사라질 때 트윈이 이 노드의 modulate(투명도)를 쓰므로, 색은 조각 스프라이트 쪽에 건다
	if _piece != null:
		_piece.modulate = tint

## 명중 지점에서 파편을 떨어뜨린다. Hitbox가 add_child 직후 호출한다
func setup(spawn_pos: Vector2) -> void:
	global_position = spawn_pos
	# 두 그림(유리조각/유리조각2) 중 하나를 무작위로 고른다
	if _piece != null and not textures.is_empty():
		_piece.texture = textures.pick_random()
	# 매번 크기·좌우 반전을 조금씩 다르게 줘서 자연스럽게 쌓이게 한다
	var s: float = randf_range(0.8, 1.2)
	scale = Vector2(s * (-1.0 if randf() < 0.5 else 1.0), s)
	rotation = randf_range(-0.4, 0.4)
	var hull: PackedVector2Array = _local_hull()
	var rest_rot: float = _resting_rotation(hull)
	_fall(spawn_pos, rest_rot, _reach_down(hull, rest_rot))

## 칠해진 부분의 볼록 껍질을 이 노드 좌표(노드 배율·반전까지 곱한 것, 회전 전)로 돌려준다.
## 조각 그림은 껍질 가운데가 노드 원점에 오게 offset을 맞춘다(그 점을 축으로 돈다)
func _local_hull() -> PackedVector2Array:
	var out := PackedVector2Array()
	if _piece == null or _piece.texture == null:
		return out
	var hull: PackedVector2Array = _hull_of(_piece.texture)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in hull:
		lo = lo.min(q)
		hi = hi.max(q)
	var center: Vector2 = (lo + hi) * 0.5
	# centered 스프라이트라 캔버스 가운데 기준 점 q는 q + offset에 그려진다
	_piece.centered = true
	_piece.offset = -center
	for q in hull:
		out.append((q - center) * _piece.scale * scale)
	return out

## 껍질의 한 변이 바닥에 평평하게 닿는 회전각 — 긴 변일수록 잘 뽑힌다(넓은 면으로 눕는 게 자연스러워서)
func _resting_rotation(hull: PackedVector2Array) -> float:
	if hull.size() < 3:
		return rotation
	var mid_all := Vector2.ZERO
	for q in hull:
		mid_all += q
	mid_all /= float(hull.size())
	var angles: Array[float] = []
	var weights: Array[float] = []
	var total: float = 0.0
	for i in hull.size():
		var a: Vector2 = hull[i]
		var b: Vector2 = hull[(i + 1) % hull.size()]
		var length: float = a.distance_to(b)
		if length < 0.01:
			continue
		var d: Vector2 = (b - a) / length
		var normal := Vector2(-d.y, d.x)
		if normal.dot((a + b) * 0.5 - mid_all) < 0.0:
			normal = -normal
		# 바깥쪽 법선이 아래(+y)를 보게 돌리면 이 변이 바닥에 눕는다
		angles.append(PI * 0.5 - normal.angle())
		weights.append(length * length)
		total += length * length
	if angles.is_empty():
		return rotation
	var pick: float = randf() * total
	for i in angles.size():
		pick -= weights[i]
		if pick <= 0.0:
			return angles[i]
	return angles[angles.size() - 1]

## rot만큼 돌렸을 때 원점에서 칠해진 부분의 가장 아래까지 거리(px, 월드)
func _reach_down(hull: PackedVector2Array, rot: float) -> float:
	var best: float = 0.0
	for q in hull:
		best = maxf(best, q.rotated(rot).y)
	return best

## 명중 높이에서 바닥까지 중력처럼 떨어지며 굴러 누운 자세가 되고, 칠해진 부분의 맨 아래가 바닥선에 딱 닿는다
func _fall(spawn_pos: Vector2, rest_rot: float, drop: float) -> void:
	var ground_y: float = _find_ground_y(spawn_pos)
	var land_x: float = spawn_pos.x + randf_range(-scatter_x, scatter_x)
	var target := Vector2(land_x, ground_y - drop)
	# 가까운 쪽으로 한 바퀴 안에서 굴러 눕게(예: 350도를 돌지 않게)
	var end_rot: float = rotation + wrapf(rest_rot - rotation, -PI, PI)
	var tween := create_tween()
	# 아래로 갈수록 빨라지게(EASE_IN) 떨어뜨린다
	tween.tween_property(self, "global_position", target, fall_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "rotation", end_rot, fall_time)
	# 바닥에 쌓인 뒤 lifetime이 지나면 서서히 투명해지며 사라진다 (self에 붙은 트윈이라 씬이 정리되면 같이 사라진다)
	tween.tween_interval(lifetime)
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	tween.tween_callback(queue_free)

## 스폰 지점에서 아래로 레이캐스트해 바닥 윗면 y를 찾는다. 못 찾으면(공중 등) 그 자리에 둔다
func _find_ground_y(from: Vector2) -> float:
	return PhysicsQuery.ground_y_below(self, from, ground_probe, from.y)

## 그림에서 **색이 칠해진 부분(알파 절반 이상)** 을 감싸는 볼록 껍질 — 캔버스 가운데 기준 px (BikeWreck._hull_of와 같은 방식).
## `get_used_rect()`는 알파 1/255 점 하나에도 늘어나 조각이 떠 보였다
func _hull_of(tex: Texture2D) -> PackedVector2Array:
	var key: String = tex.resource_path
	if _hull_cache.has(key):
		return _hull_cache[key]
	var half: Vector2 = tex.get_size() * 0.5
	var pts := PackedVector2Array()
	var img: Image = tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		const STEP := 4
		for y in range(0, img.get_height(), STEP):
			var first: int = -1
			var last: int = -1
			for x in range(0, img.get_width(), STEP):
				if img.get_pixel(x, y).a >= 0.5:
					if first < 0:
						first = x
					last = x
			# 줄마다 양 끝 두 점만 있으면 볼록 껍질에 충분하다
			if first >= 0:
				pts.append(Vector2(first, y) - half)
				pts.append(Vector2(first, y + STEP) - half)
				pts.append(Vector2(last + STEP, y) - half)
				pts.append(Vector2(last + STEP, y + STEP) - half)
	var hull: PackedVector2Array = Geometry2D.convex_hull(pts) if pts.size() >= 3 else PackedVector2Array([-half, half])
	_hull_cache[key] = hull
	return hull
