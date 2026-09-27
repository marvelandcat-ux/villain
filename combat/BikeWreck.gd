class_name BikeWreck
extends Node2D

## 금쪽이 자전거가 상대를 들이받으면 부서지며 **부품 하나(바퀴·안장·파란 몸체 중 랜덤)** 가 튀어 올랐다가 바닥에 남는다
## (2026-09-28 사용자 요청 — 술병 유리조각·신문지처럼 바닥에 남게, 부품은 하나만·나머지 자전거는 사라짐). 순수 장식이라 판정이 없다.
## **맵에 붙이고** setup(자전거 스프라이트, 진행 방향)으로 시작한다. 조각 그림은 원본 `자전거.png`와 같은 캔버스(1536x1024)라
## 자전거가 있던 자리에 그대로 겹쳐 시작한다. 라운드가 바뀌면(씬 리로드) 같이 사라진다.
## 조각 그림: 바퀴 = 앞바퀴 아래 절반을 180도 돌려 붙인 포크 없는 바퀴(앞바퀴 자리에서 시작),
## 안장 = 안장+기둥(몸체 틀 위까지), 몸체 = 바퀴·안장을 뺀 파란 프레임(+핸들·페달). 자전거 그림을 바꾸면 조각도 다시 만들 것

## 조각 그림(바퀴, 안장, 몸체 순서 — 아래 속도 배열이 이 순서에 묶여 있다)
const PIECES: Array[Texture2D] = [
	preload("res://sprite/축법소년/자전거_조각_바퀴.png"),
	preload("res://sprite/축법소년/자전거_조각_안장.png"),
	preload("res://sprite/축법소년/자전거_조각_몸체.png"),
]

## true면 세 조각 중 하나만 랜덤으로 나온다(사용자 결정). false면 셋 다
@export var pick_one: bool = true
## 조각별 가로 속도 범위(px/초, 진행 방향 기준 — 음수면 뒤로). 바퀴는 굴러가듯 멀리, 안장은 높이 튄다
@export var speed_x_ranges: Array[Vector2] = [Vector2(170, 280), Vector2(60, 170), Vector2(40, 150)]
## 조각별 위로 튀는 속도 범위(px/초)
@export var speed_up_ranges: Array[Vector2] = [Vector2(240, 360), Vector2(380, 520), Vector2(260, 400)]
## 도는 속도 최대(라디안/초)
@export var spin_max: float = 9.0
## 떨어지는 중력(px/초²) — 캐릭터 중력과 같게
@export var fall_gravity: float = 1150.0
## 바닥에 닿을 때 되튀는 비율, 이보다 느리면 되튀지 않고 눕는다
@export var bounce: float = 0.35
@export var min_bounce_speed: float = 120.0
## 바닥에서 미끄러지다 멈추는 마찰(px/초²)
@export var ground_friction: float = 900.0

## 바닥에 닿은 뒤 무게중심이 낮아지는 쪽으로 넘어지는 속도(라디안/초) — 안장·몸체가 끝으로 선 채 멈추지 않고 눕게
@export var topple_speed: float = 3.5

var _parts: Array = []
## 그림별 "색이 칠해진 부분"의 테두리(볼록 껍질, 캔버스 가운데 기준 px) — 조각끼리 공유해 그림마다 한 번만 잰다
static var _hull_cache: Dictionary = {}

## 자전거 스프라이트 bike의 지금 모습 그대로 조각을 띄우고 dir(1/-1) 쪽으로 흩뿌린다
func setup(bike: Sprite2D, dir: float) -> void:
	var xf: Transform2D = bike.global_transform
	var sc: Vector2 = bike.global_scale
	var picks: Array = range(PIECES.size())
	if pick_one:
		picks = [randi() % PIECES.size()]
	for i in picks:
		var tex: Texture2D = PIECES[i]
		var hull: PackedVector2Array = _hull_of(tex)
		var center_px: Vector2 = _hull_center(hull)
		var part := Sprite2D.new()
		part.texture = tex
		# 원점을 조각 가운데로 옮겨 제자리에서 돌게 한다
		part.offset = -center_px
		add_child(part)
		part.global_position = xf * (center_px + bike.offset)
		part.global_rotation = bike.global_rotation
		part.global_scale = sc
		var local_hull := PackedVector2Array()
		for q in hull:
			local_hull.append(q - center_px)
		var rx: Vector2 = speed_x_ranges[mini(i, speed_x_ranges.size() - 1)]
		var ry: Vector2 = speed_up_ranges[mini(i, speed_up_ranges.size() - 1)]
		_parts.append({
			"node": part,
			"vel": Vector2(randf_range(rx.x, rx.y) * dir, -randf_range(ry.x, ry.y)),
			"spin": randf_range(-spin_max, spin_max),
			"hull": local_hull,
			"scale": sc,
			"grounded": false,
			"rest": false,
			"start_y": part.global_position.y,
		})

func _physics_process(delta: float) -> void:
	var moving: bool = false
	for p in _parts:
		if p.rest:
			continue
		moving = true
		var node: Sprite2D = p.node
		var pos: Vector2 = node.global_position
		p.vel.y += fall_gravity * delta
		var next: Vector2 = pos + p.vel * delta
		# 벽에 부딪히면 튕겨 나온다(맵 밖으로 날아가지 않게) — 칠해진 부분의 옆 끝까지 본다
		var side: float = _reach(p, node.rotation, Vector2(signf(p.vel.x), 0.0))
		var wall: Dictionary = PhysicsQuery.raycast_ignoring_fighters(self, pos, Vector2(next.x + signf(p.vel.x) * side, pos.y))
		if not wall.is_empty() and absf(wall.normal.x) > 0.7:
			p.vel.x = -p.vel.x * 0.4
			next.x = pos.x
		node.global_position = next
		node.rotation += p.spin * delta
		var ground_y: float = PhysicsQuery.ground_y_below(self, next, 2000.0, INF)
		# 바닥이 없는 곳(링아웃 맵 바깥)으로 떨어지면 계산을 멈추고 치운다
		if next.y > p.start_y + 3000.0:
			p.rest = true
			node.hide()
			continue
		# 색이 칠해진 부분의 가장 아래 점이 바닥에 닿았는지 (예전엔 그림 네모 상자로 재서 돌아간 바퀴가 떠 있었다)
		var bottom: float = _reach(p, node.rotation, Vector2.DOWN)
		if next.y + bottom >= ground_y and p.vel.y >= 0.0:
			node.global_position.y = ground_y - bottom
			if p.vel.y > min_bounce_speed and not p.grounded:
				p.vel.y = -p.vel.y * bounce
				p.vel.x *= 0.6
				p.spin *= 0.5
			else:
				p.vel.y = 0.0
				p.grounded = true
		if p.grounded:
			p.vel.x = move_toward(p.vel.x, 0.0, ground_friction * delta)
			p.spin = move_toward(p.spin, 0.0, 14.0 * delta)
			# 넘어지기 — 조금 돌렸을 때 가장 아래 점이 덜 내려가면(= 무게중심이 낮아지면) 그쪽으로 기운다
			var toppling: bool = false
			if absf(p.spin) < 0.5:
				var step: float = topple_speed * delta
				var now: float = _reach(p, node.rotation, Vector2.DOWN)
				var cw: float = _reach(p, node.rotation + step, Vector2.DOWN)
				var ccw: float = _reach(p, node.rotation - step, Vector2.DOWN)
				if minf(cw, ccw) < now - 0.01:
					node.rotation += step if cw < ccw else -step
					toppling = true
				node.global_position.y = ground_y - _reach(p, node.rotation, Vector2.DOWN)
			if absf(p.vel.x) < 1.0 and absf(p.spin) < 0.05 and not toppling:
				p.rest = true
	if not moving:
		set_physics_process(false)

## 조각을 rot만큼 돌렸을 때 원점에서 dir 쪽으로 칠해진 부분이 가장 멀리 나간 거리(px, 월드 배율)
func _reach(p: Dictionary, rot: float, dir: Vector2) -> float:
	var basis := Transform2D(rot, p.scale, 0.0, Vector2.ZERO)
	var best: float = 0.0
	for q in p.hull:
		best = maxf(best, (basis * q).dot(dir))
	return best

## 그림에서 **색이 칠해진 부분(알파 절반 이상)** 을 감싸는 볼록 껍질 — 캔버스 가운데 기준 px.
## 4px 간격으로만 훑는다(1536x1024 기준 10만 번). 조각 그림은 원본 캔버스에 조각만 남긴 것이라 여백이 크다
func _hull_of(tex: Texture2D) -> PackedVector2Array:
	if _hull_cache.has(tex):
		return _hull_cache[tex]
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
	_hull_cache[tex] = hull
	return hull

## 껍질을 감싸는 상자의 가운데 — 조각을 이 점 기준으로 돌린다
func _hull_center(hull: PackedVector2Array) -> Vector2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in hull:
		lo = lo.min(q)
		hi = hi.max(q)
	return (lo + hi) * 0.5
