class_name VersusSparks
extends Control

## 두 사다리꼴이 **쾅 부딪힌 순간** 이음새에서 터지는 불꽃.
## 그림 파일 없이 전부 코드로 그린다 — 색·개수·속도를 인스펙터에서 바로 만질 수 있고
## 파티클 리소스를 따로 만들 필요도 없다.
##
## 세 가지가 겹쳐서 "파지직" 하는 느낌을 만든다:
##  1) 이음새를 따라 확 밝아졌다 꺼지는 흰 띠 (부딪힌 자리 자체가 빛난다)
##  2) 가운데에서 사방으로 뻗어 나가는 불똥 선 (빠르게 나갔다가 느려지며 사라진다)
##  3) 뻗어 나간 끝에 남는 작은 점

## 불꽃이 다 사라졌을 때
signal finished

## 불똥 개수
@export var spark_count: int = 24
## 터지고 다 사라질 때까지 걸리는 시간(초)
@export var duration: float = 0.55
## 불똥이 날아가는 거리(px) 범위
@export var spark_distance_min: float = 150.0
@export var spark_distance_max: float = 620.0
## 불똥 선 자체의 길이(px) 범위와 굵기
@export var spark_length_min: float = 26.0
@export var spark_length_max: float = 96.0
@export var spark_width: float = 5.0
## 불똥 색 — 둘 사이에서 하나씩 섞어 쓴다
@export var hot_color: Color = Color(1.0, 0.97, 0.78, 1.0)
@export var cool_color: Color = Color(1.0, 0.52, 0.1, 1.0)
## 위아래로만 튀면 부딪힌 느낌이 안 나서 좌우로 납작하게 퍼뜨린다(1이면 동그랗게)
@export_range(0.2, 1.0, 0.05) var spread_flatten: float = 0.55

@export_group("이음새 번쩍임")
## 이음새를 따라 번쩍이는 흰 띠의 두께(px)와 남는 시간(초)
@export var flash_width: float = 150.0
@export var flash_time: float = 0.18
@export var flash_color: Color = Color(1.0, 1.0, 1.0, 1.0)
## 이음새 기울기 — **VersusHalf의 lean과 같은 값을 넣어야** 띠가 빗변에 딱 겹친다
@export var lean: float = 130.0

## 터진 뒤 지난 시간(초). 음수면 지금은 아무것도 안 그린다
var _time: float = -1.0
var _origin: Vector2 = Vector2.ZERO
## [{dir, distance, length, width, color}]
var _sparks: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

## 이 자리에서 불꽃을 터뜨린다 (보통 이음새 한가운데)
func burst(origin: Vector2) -> void:
	_origin = origin
	_time = 0.0
	_sparks.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(spark_count):
		var angle: float = rng.randf_range(-PI, PI)
		var dir: Vector2 = Vector2(cos(angle), sin(angle) * spread_flatten).normalized()
		_sparks.append({
			"dir": dir,
			"distance": rng.randf_range(spark_distance_min, spark_distance_max),
			"length": rng.randf_range(spark_length_min, spark_length_max),
			"width": rng.randf_range(spark_width * 0.45, spark_width),
			"color": hot_color.lerp(cool_color, rng.randf()),
		})
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if _time < 0.0:
		return
	_time += delta
	queue_redraw()
	if _time >= duration:
		_time = -1.0
		set_process(false)
		finished.emit()

func _draw() -> void:
	if _time < 0.0:
		return
	_draw_seam_flash()
	# 처음엔 확 뻗다가 점점 느려진다 — 진짜 불똥이 튀는 느낌은 이 감속에서 나온다
	var t: float = clampf(_time / maxf(duration, 0.001), 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	var alpha: float = clampf(1.0 - pow(t, 1.6), 0.0, 1.0)
	for spark in _sparks:
		var dir: Vector2 = spark["dir"]
		var head: Vector2 = _origin + dir * (float(spark["distance"]) * eased)
		# 꼬리는 날아갈수록 짧아진다
		var tail: Vector2 = head - dir * (float(spark["length"]) * (1.0 - t * 0.7))
		var color: Color = spark["color"]
		color.a = alpha
		draw_line(tail, head, color, float(spark["width"]))
		draw_circle(head, float(spark["width"]) * 0.6, color)
	# 터진 자리에 남는 흰 핵 — 아주 빠르게 쪼그라든다
	if t < 0.35:
		var core: float = (1.0 - t / 0.35)
		var core_color: Color = flash_color
		core_color.a = core
		draw_circle(_origin, 46.0 * core, core_color)

## 빗변을 따라 흰 띠를 그린다. VersusHalf의 빗변과 같은 식으로 점을 잡는다
func _draw_seam_flash() -> void:
	if _time >= flash_time:
		return
	var fade: float = 1.0 - _time / maxf(flash_time, 0.001)
	var half_w: float = flash_width * (0.3 + 0.7 * fade) * 0.5
	var c: float = size.x * 0.5
	var color: Color = flash_color
	color.a = fade
	draw_colored_polygon(PackedVector2Array([
		Vector2(c - lean - half_w, 0.0),
		Vector2(c - lean + half_w, 0.0),
		Vector2(c + lean + half_w, size.y),
		Vector2(c + lean - half_w, size.y),
	]), color)
