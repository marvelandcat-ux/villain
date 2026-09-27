class_name BikeWreck
extends Node2D

## 금쪽이 자전거가 상대를 들이받으면 세 조각(뒷바퀴·앞바퀴·몸체)으로 부서져 튀어 올랐다가 바닥에 남는다
## (2026-09-28 사용자 요청 — 술병 유리조각·신문지처럼 바닥에 남게). 순수 장식이라 판정이 없다.
## **맵에 붙이고** setup(자전거 스프라이트, 진행 방향)으로 시작한다. 조각 그림은 원본 `자전거.png`와 같은 캔버스(1536x1024)라
## 자전거가 있던 자리에 그대로 겹쳐 시작한다. 라운드가 바뀌면(씬 리로드) 같이 사라진다.
## 조각 그림은 원본을 바퀴 둘레 원으로 잘라 만든 것 — 자전거 그림을 바꾸면 조각도 다시 만들 것

## 조각 그림(뒷바퀴, 앞바퀴, 몸체 순서 — 속도 성격이 순서에 묶여 있다)
const PIECES: Array[Texture2D] = [
	preload("res://sprite/축법소년/자전거_조각_뒷바퀴.png"),
	preload("res://sprite/축법소년/자전거_조각_앞바퀴.png"),
	preload("res://sprite/축법소년/자전거_조각_몸체.png"),
]

## 조각별 가로 속도 범위(px/초, 진행 방향 기준 — 음수면 뒤로). 앞바퀴는 멀리, 뒷바퀴는 살짝 뒤로 튄다
@export var speed_x_ranges: Array[Vector2] = [Vector2(-150, -40), Vector2(170, 280), Vector2(40, 150)]
## 위로 튀는 속도 범위(px/초)
@export var speed_up: Vector2 = Vector2(260, 420)
## 도는 속도 최대(라디안/초)
@export var spin_max: float = 9.0
## 떨어지는 중력(px/초²) — 캐릭터 중력과 같게
@export var fall_gravity: float = 1150.0
## 바닥에 닿을 때 되튀는 비율, 이보다 느리면 되튀지 않고 눕는다
@export var bounce: float = 0.35
@export var min_bounce_speed: float = 120.0
## 바닥에서 미끄러지다 멈추는 마찰(px/초²)
@export var ground_friction: float = 900.0

var _parts: Array = []

## 자전거 스프라이트 bike의 지금 모습 그대로 세 조각을 띄우고 dir(1/-1) 쪽으로 흩뿌린다
func setup(bike: Sprite2D, dir: float) -> void:
	var xf: Transform2D = bike.global_transform
	var sc: Vector2 = bike.global_scale
	for i in PIECES.size():
		var tex: Texture2D = PIECES[i]
		var used: Rect2 = _used_rect(tex)
		var center_px: Vector2 = used.get_center() - tex.get_size() * 0.5
		var part := Sprite2D.new()
		part.texture = tex
		# 원점을 조각 가운데로 옮겨 제자리에서 돌게 한다
		part.offset = -center_px
		add_child(part)
		part.global_position = xf * (center_px + bike.offset)
		part.global_rotation = bike.global_rotation
		part.global_scale = sc
		var rx: Vector2 = speed_x_ranges[mini(i, speed_x_ranges.size() - 1)]
		_parts.append({
			"node": part,
			"vel": Vector2(randf_range(rx.x, rx.y) * dir, -randf_range(speed_up.x, speed_up.y)),
			"spin": randf_range(-spin_max, spin_max),
			"half": used.size * sc.abs() * 0.5,
			"grounded": false,
			"rest": false,
			"start_y": part.global_position.y,
		})
	z_index = -1   # 캐릭터보다 뒤, 바닥 위

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
		# 벽에 부딪히면 튕겨 나온다(맵 밖으로 날아가지 않게)
		var wall: Dictionary = PhysicsQuery.raycast_ignoring_fighters(self, pos, Vector2(next.x + signf(p.vel.x) * p.half.x, pos.y))
		if not wall.is_empty() and absf(wall.normal.x) > 0.7:
			p.vel.x = -p.vel.x * 0.4
			next.x = pos.x
		node.global_position = next
		node.rotation += p.spin * delta
		# 돌아간 조각의 가장 아래 점이 바닥에 닿았는지 — 회전한 사각형의 세로 반폭
		var ext: float = absf(p.half.x * sin(node.rotation)) + absf(p.half.y * cos(node.rotation))
		var ground_y: float = PhysicsQuery.ground_y_below(self, next, 2000.0, INF)
		# 바닥이 없는 곳(링아웃 맵 바깥)으로 떨어지면 계산을 멈추고 치운다
		if next.y > p.start_y + 3000.0:
			p.rest = true
			node.hide()
			continue
		if next.y + ext >= ground_y and p.vel.y >= 0.0:
			node.global_position.y = ground_y - ext
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
			if absf(p.vel.x) < 1.0 and absf(p.spin) < 0.05:
				p.rest = true
	if not moving:
		set_physics_process(false)

## 그림에서 보이는 영역(알파 절반 이상) — 조각 그림은 원본 캔버스에 조각만 남긴 것이라 여백이 크다
func _used_rect(tex: Texture2D) -> Rect2:
	var img: Image = tex.get_image()
	if img == null:
		return Rect2(Vector2.ZERO, tex.get_size())
	if img.is_compressed():
		img.decompress()
	return Rect2(img.get_used_rect())
