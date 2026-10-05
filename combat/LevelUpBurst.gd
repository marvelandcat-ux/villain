extends Node2D

## **운동 레벨업 폭죽** — 헬스장 운동 스택이 1 오를 때마다 그 부위(손·발)에서 선이 쫘악 터진다
## (2026-10-06 사용자 지정: "좀 오바해서 폭죽, 선이 쫘앙 나온다고 생각").
## 가운데에서 빛줄기가 사방으로 뻗어 나가며 길게 늘어났다가 끝의 밝은 점만 남기고 사라진다.
##
## **맵에 붙이고 부위를 따라간다** — 캐릭터 자식으로 달면 몸이 뒤집힐 때 같이 뒤집히고,
## 리그 조각 크기(0.1배 같은)에 같이 줄어든다. `spawn()`으로 만든다

## 빛줄기 개수
@export var rays: int = 44
## 다 퍼졌을 때 반지름(월드 px)
@export var radius: float = 95.0
## 터지는 시간(초)
@export var duration: float = 0.65
## 빛줄기 굵기(px)
@export var ray_width: float = 2.2
## 주된 색(따뜻한 흰빛) — 그중 몇 줄은 accent 색으로 섞는다
@export var main_color: Color = Color(1.0, 0.9, 0.62)
@export var accent_colors: Array[Color] = [Color(1.0, 0.3, 0.42), Color(0.45, 0.6, 1.0)]
## 섞을 accent 줄의 비율
@export_range(0.0, 1.0, 0.05) var accent_ratio: float = 0.18

## 따라갈 부위들 — **그 가운데**에서 터진다(두 발이면 두 발 사이). 다 사라지면 그 자리에 남는다
var follow: Array = []

var _time: float = 0.0
## 줄마다 [각도, 길이 배율, 속도 배율, 색]
var _ray_data: Array = []

## 부위들의 가운데에 폭죽 하나를 터뜨린다. parent는 맵(캐릭터의 부모).
## color·time을 주면 주된 색·터지는 시간을 바꾼다(빵빠레의 금빛 큰 폭죽) — add_child 전에 넣어야 _ready가 본다
static func spawn(parent: Node, parts: Array, size_scale: float = 1.0, color: Color = Color(0, 0, 0, 0), time: float = 0.0) -> Node2D:
	var burst: Node2D = (load("res://combat/LevelUpBurst.gd") as GDScript).new()
	burst.follow = parts
	burst.radius *= size_scale
	if color.a > 0.0:
		burst.main_color = color
	if time > 0.0:
		burst.duration = time
	burst.z_index = 60
	parent.add_child(burst)
	burst.call("_stick")
	return burst

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
	for i in rays:
		var angle: float = TAU * float(i) / rays + rng.randf_range(-0.07, 0.07)
		var color: Color = main_color
		if rng.randf() < accent_ratio and not accent_colors.is_empty():
			color = accent_colors[rng.randi() % accent_colors.size()]
		_ray_data.append([angle, rng.randf_range(0.55, 1.0), rng.randf_range(0.8, 1.15), color])

func _process(delta: float) -> void:
	_time += delta
	_stick()
	if _time >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t: float = clampf(_time / maxf(duration, 0.01), 0.0, 1.0)
	# 처음엔 확 퍼지고(ease out) 뒤로 갈수록 느려진다
	var spread: float = 1.0 - pow(1.0 - t, 3.0)
	var fade: float = 1.0 - smoothstep(0.55, 1.0, t)
	# 터지는 순간 가운데 번쩍임
	if t < 0.25:
		var flash: float = 1.0 - t / 0.25
		draw_circle(Vector2.ZERO, radius * 0.22 * (0.6 + spread), Color(1.0, 0.97, 0.85, 0.75 * flash))
	for ray in _ray_data:
		var dir := Vector2.from_angle(ray[0])
		var reach: float = radius * spread * ray[2]
		# 빛줄기는 바깥 끝을 따라 나가고, 꼬리는 처음엔 길다가 점점 짧아진다
		var tail: float = radius * ray[1] * (0.55 - 0.35 * t)
		var outer: Vector2 = dir * reach
		var inner: Vector2 = dir * maxf(reach - tail, radius * 0.08)
		var color: Color = ray[3]
		color.a = fade
		draw_line(inner, outer, color, ray_width * (1.0 - 0.4 * t), true)
		# 끝의 밝은 점 — 사진 속 불꽃 알갱이
		var tip: Color = color.lerp(Color.WHITE, 0.6)
		tip.a = fade
		draw_circle(outer, ray_width * 1.3, tip)
