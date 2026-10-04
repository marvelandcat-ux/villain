class_name KidScream
extends Node2D

## 아이가 지르는 **비명** 연출. 층간소음 빌런 1번 스킬(`KidScreamSkill`)이 **아이 얼굴 자리**에 띄운다.
##
## 동그란 고리가 아니라 **가운데에서 사방으로 뻗는 빛줄기**다(2026-10-04 사용자 요청).
## 줄기마다 길이·속도·굵기·밝기가 조금씩 달라서, 고르게 퍼지는 원이 아니라 쭉쭉 터져 나가는 모양이 된다.
##
## 판정은 안 들고 있다 — 때리는 건 스킬이 직접 거리를 재서 한다.
## (그래야 "보이는 길이 = 걸리는 범위"를 한 곳에서 맞출 수 있다)

## 줄기가 뻗어 나가는 최대 거리(px). 스킬의 사정거리와 같게 맞춰 두면 보이는 대로 걸린다
@export var max_radius: float = 300.0
## 줄기 개수. 많을수록 빽빽하다
@export var ray_count: int = 55
## 연출 전체 길이(초)
@export var duration: float = 0.5
## 줄기 하나의 길이(최대 거리 대비 비율). 0.5면 반지름의 절반만큼 긴 줄기가 된다
@export_range(0.05, 1.0, 0.01) var ray_length: float = 0.45
## 줄기 굵기(px). 끝으로 갈수록 얇아진다
@export var ray_width: float = 3.8
## 가운데에 남겨 둘 빈 구멍 반지름(px) — 여기부터 줄기가 시작한다
@export var inner_radius: float = 6.0
## 줄기마다 길이·속도가 들쭉날쭉한 정도(0이면 전부 똑같다)
@export_range(0.0, 0.9, 0.01) var ray_variance: float = 0.45
## 위아래로 눌린 정도(1이면 동그랗게 사방으로, 작으면 가로로 퍼진다)
@export var squash: float = 1.0

@export_group("색")
## 줄기 색
@export var ray_color: Color = Color(1.0, 1.0, 1.0, 0.9)
## 터지는 순간 가운데에서 번쩍이는 빛의 크기(px)와 시간(초). 0이면 안 그린다
@export var flash_radius: float = 30.0
@export var flash_time: float = 0.16

## 시작하고 흐른 시간
var _time: float = 0.0
## 줄기마다 미리 뽑아 둔 값 — [각도, 속도배수, 길이배수, 굵기배수, 밝기]
var _rays: Array = []

func _ready() -> void:
	# 더하기(add) 혼합이라 어두운 맵에서도 빛나 보인다
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	z_as_relative = false
	z_index = 40
	_build_rays()

## 줄기들을 미리 뽑아 둔다. 매 프레임 다시 뽑으면 지지직거린다
func _build_rays() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var v: float = clampf(ray_variance, 0.0, 0.9)
	for i in range(maxi(ray_count, 0)):
		# 각도는 고르게 깔되 조금씩 흔들어 준다 — 완전히 고르면 바큇살처럼 보인다
		var base: float = TAU * float(i) / float(maxi(ray_count, 1))
		var angle: float = base + rng.randf_range(-1.0, 1.0) * TAU / float(maxi(ray_count, 1))
		_rays.append([
			angle,
			1.0 - rng.randf() * v,          # 속도 배수
			1.0 - rng.randf() * v * 0.8,    # 길이 배수
			0.5 + rng.randf(),              # 굵기 배수
			0.45 + rng.randf() * 0.55,      # 밝기
		])

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _time >= duration:
		queue_free()

func _draw() -> void:
	var k: float = clampf(_time / maxf(duration, 0.01), 0.0, 1.0)
	# 터지는 순간 가운데가 번쩍인다
	if flash_radius > 0.0 and _time < flash_time:
		var f: float = 1.0 - _time / maxf(flash_time, 0.001)
		var glow: Color = ray_color
		glow.a *= f
		draw_circle(Vector2.ZERO, flash_radius * f, glow)
	# 처음엔 빠르게, 끝으로 갈수록 느리게 뻗는다
	var eased: float = 1.0 - pow(1.0 - k, 2.2)
	# 끝물에 서서히 사라진다
	var fade: float = 1.0 - pow(k, 3.0)
	for ray in _rays:
		_draw_ray(ray, eased, fade)

## 줄기 하나 — 안쪽 끝에서 바깥쪽 끝까지 긋는다. 끝으로 갈수록 얇고 옅어진다
func _draw_ray(ray: Array, eased: float, fade: float) -> void:
	var angle: float = ray[0]
	var tip: float = max_radius * ray[1] * eased
	if tip <= inner_radius:
		return
	var tail: float = maxf(tip - max_radius * ray_length * ray[2], inner_radius)
	var dir := Vector2(cos(angle), sin(angle) * squash)
	var color: Color = ray_color
	color.a *= fade * ray[4]
	if color.a <= 0.0:
		return
	var width: float = maxf(ray_width * ray[3] * (1.0 - eased * 0.5), 0.6)
	draw_line(dir * tail, dir * tip, color, width, true)
