extends Node2D

## **빵빠레** — 헬스장 운동이 10스택(꽉)이 되는 순간 한 번 터진다(2026-10-06 사용자 지정).
## 금빛 큰 폭죽 하나 + 둘레에서 엇갈려 터지는 작은 폭죽 넷 + 양옆으로 쏟아지는 색종이.
## 효과음 파일이 아직 없어서 그림만이다 — 소리가 생기면 `spawn()`에서 같이 틀면 된다.
##
## 맵에 붙이고 부위들의 가운데를 따라간다(`LevelUpBurst`와 같은 방식)

const BURST := preload("res://combat/LevelUpBurst.gd")

## 색종이 개수·퍼지는 세기·중력(px/s²)·사는 시간(초)
@export var confetti_count: int = 70
@export var confetti_speed: float = 420.0
@export var confetti_gravity: float = 620.0
@export var duration: float = 1.8
## 색종이 색
@export var colors: Array[Color] = [Color(1.0, 0.84, 0.2), Color(1.0, 0.35, 0.45), Color(0.4, 0.75, 1.0),
	Color(0.5, 0.95, 0.5), Color(1.0, 1.0, 1.0), Color(0.85, 0.5, 1.0)]

var follow: Array = []
var _time: float = 0.0
## 색종이마다 [위치, 속도, 각도, 도는 속도, 크기, 색]
var _pieces: Array = []

## 부위들의 가운데에서 빵빠레를 터뜨린다. parent는 맵
static func spawn(parent: Node, parts: Array) -> Node2D:
	var fanfare: Node2D = (load("res://combat/FanfareBurst.gd") as GDScript).new()
	fanfare.follow = parts
	fanfare.z_index = 61
	parent.add_child(fanfare)
	fanfare.call("_stick")
	# 금빛 큰 폭죽 — 가운데
	BURST.spawn(parent, parts, 1.9, Color(1.0, 0.86, 0.3), 0.9)
	# 둘레의 작은 폭죽 넷 — 조금씩 늦게, 조금씩 비켜서
	var offsets: Array = [Vector2(-70, -60), Vector2(75, -45), Vector2(-45, -110), Vector2(55, -115)]
	for i in offsets.size():
		var anchor := Node2D.new()
		parent.add_child(anchor)
		anchor.global_position = fanfare.global_position + offsets[i]
		Timers.self_destruct(anchor, 2.0)
		Timers.after(parent, 0.12 + 0.11 * i, func() -> void:
			if is_instance_valid(anchor):
				BURST.spawn(parent, [anchor], 0.75))
	return fanfare

## 따라갈 부위들의 가운데로 옮긴다
func _stick() -> void:
	var sum := Vector2.ZERO
	var count: int = 0
	for part in follow:
		if is_instance_valid(part):
			sum += (part as Node2D).global_position
			count += 1
	if count > 0:
		global_position = sum / count

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in confetti_count:
		# 왼쪽 위·오른쪽 위로 반씩 쏜다(크래커 두 개)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var angle: float = deg_to_rad(-90.0 + side * rng.randf_range(15.0, 60.0))
		var speed: float = confetti_speed * rng.randf_range(0.55, 1.1)
		_pieces.append([
			Vector2.ZERO,
			Vector2.from_angle(angle) * speed,
			rng.randf() * TAU,
			rng.randf_range(-12.0, 12.0),
			Vector2(rng.randf_range(4.0, 8.0), rng.randf_range(2.5, 4.5)),
			colors[rng.randi() % colors.size()],
		])

func _process(delta: float) -> void:
	_time += delta
	if _time >= duration:
		queue_free()
		return
	for piece in _pieces:
		var vel: Vector2 = piece[1]
		vel.y += confetti_gravity * delta
		vel.x *= 1.0 - minf(delta * 1.6, 0.5)   # 옆으로는 공기에 걸려 금방 느려진다
		piece[1] = vel
		piece[0] += vel * delta
		piece[2] += piece[3] * delta
	queue_redraw()

func _draw() -> void:
	var fade: float = 1.0 - smoothstep(0.7, 1.0, _time / maxf(duration, 0.01))
	for piece in _pieces:
		var size: Vector2 = piece[4]
		# 종이가 팔랑이며 도는 것처럼 세로 폭을 cos로 접는다
		var flip: float = absf(cos(piece[2] * 1.7))
		var color: Color = piece[5]
		color.a = fade
		draw_set_transform(piece[0], piece[2], Vector2(1.0, maxf(flip, 0.15)))
		draw_rect(Rect2(-size * 0.5, size), color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
