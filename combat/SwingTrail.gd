class_name SwingTrail
extends Node2D

## 평타 1·2·3타의 하얀 휘두르기 궤적 (순수 장식, 판정 없음). 그림 없이 `_draw()`로 그린다(2026-10-06 사용자 요청).
## 무기 끝·주먹·발이 지나간 자리를 **맵 좌표로 기록**해서 그 길을 따라 띠를 긋는다 — 앞(새 자리)이 굵고 꼬리로 갈수록 가늘고 옅다.
## 자리마다 life초가 지나면 사라져서 띠가 꼬리부터 줄어든다. BodyRig가 `add_point()`로 자리를 넣고, 다 휘둘렀으면 `finish()`
## **맵에 붙일 것**(캐릭터 자식이면 좌우 반전에 뒤집힌다)

## 띠 색 (가장 진한 앞쪽 끝)
@export var trail_color: Color = Color(1.0, 1.0, 1.0, 0.95)
## 앞쪽 끝 굵기(px)
@export var max_width: float = 10.0
## 띠 가운데 더 하얗고 진한 심지 — 굵기 비율(0 = 심지 없음)
@export var core_ratio: float = 0.45
## 꼬리 쪽 옅어지는 정도 — 1보다 작을수록 꼬리까지 진하게 남는다
@export var fade_power: float = 0.5
## 자리 하나가 남아 있는 시간(초) — 길수록 꼬리가 길다
@export var life: float = 0.14

## 이 노드가 생긴 뒤 흐른 시간(초)
var _time: float = 0.0
var _finished: bool = false
## 마지막으로 자리를 받은 _time — 휘두르던 캐릭터가 사라져 finish()를 못 받아도 스스로 끝내려고
var _last_add: float = 0.0
## 지나간 자리(맵 좌표)와 그때의 _time — 오래된 것이 앞
var _points: PackedVector2Array = PackedVector2Array()
var _times: PackedFloat32Array = PackedFloat32Array()

## 지금 자리 하나를 더한다(맵 좌표)
func add_point(global_pos: Vector2) -> void:
	if _finished:
		return
	# 거의 같은 자리는 건너뛴다 — 띠 방향 계산이 0으로 나뉜다
	if not _points.is_empty() and _points[_points.size() - 1].distance_to(global_pos) < 0.5:
		return
	_points.append(global_pos)
	_times.append(_time)
	_last_add = _time

## 다 휘둘렀다 — 더는 자리를 안 받고, 남은 꼬리가 다 사라지면 스스로 지운다
func finish() -> void:
	_finished = true

func _ready() -> void:
	global_position = Vector2.ZERO
	# 맵 조명(CanvasModulate·암전)에 어두워지지 않게 — 어두운 맵에서도 하얗게 보인다
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat

func _process(delta: float) -> void:
	_time += minf(delta, 0.05)
	if not _finished and _time - _last_add > 0.5:
		_finished = true
	# 오래된 자리부터 지운다
	while not _times.is_empty() and _time - _times[0] >= life:
		_points.remove_at(0)
		_times.remove_at(0)
	if _finished and _points.is_empty():
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var n: int = _points.size()
	if n < 2:
		return
	# 자리마다 띠의 양쪽 가장자리를 구한다 — 남은 수명 비율만큼 굵기·진하기가 줄어든다
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var cols := PackedColorArray()
	var core_left := PackedVector2Array()
	var core_right := PackedVector2Array()
	var core_cols := PackedColorArray()
	left.resize(n)
	right.resize(n)
	cols.resize(n)
	core_left.resize(n)
	core_right.resize(n)
	core_cols.resize(n)
	for i in n:
		var p: Vector2 = to_local(_points[i])
		var a: Vector2 = to_local(_points[maxi(i - 1, 0)])
		var b: Vector2 = to_local(_points[mini(i + 1, n - 1)])
		var dir: Vector2 = (b - a).normalized()
		var normal := Vector2(-dir.y, dir.x)
		var k: float = clampf(1.0 - (_time - _times[i]) / maxf(life, 0.001), 0.0, 1.0)
		# 꼬리 쪽(오래된 자리)일수록 가늘게 — 맨 끝은 0이라 뾰족하다
		var along: float = float(i) / float(n - 1)
		var half: float = max_width * 0.5 * k * along
		left[i] = p + normal * half
		right[i] = p - normal * half
		core_left[i] = p + normal * half * core_ratio
		core_right[i] = p - normal * half * core_ratio
		# 진하기는 굵기보다 천천히 빠진다(fade_power) — 꼬리까지 또렷하게
		var fade: float = pow(k * along, fade_power)
		var c: Color = trail_color
		c.a *= fade
		cols[i] = c
		core_cols[i] = Color(1.0, 1.0, 1.0, fade)
	# 굵기가 0이 될 수 있는 모양이라 draw_primitive로 칸마다 사각형을 그린다(draw_colored_polygon은 triangulation 에러)
	for i in n - 1:
		draw_primitive(
			PackedVector2Array([left[i], left[i + 1], right[i + 1], right[i]]),
			PackedColorArray([cols[i], cols[i + 1], cols[i + 1], cols[i]]),
			PackedVector2Array())
	if core_ratio <= 0.0:
		return
	for i in n - 1:
		draw_primitive(
			PackedVector2Array([core_left[i], core_left[i + 1], core_right[i + 1], core_right[i]]),
			PackedColorArray([core_cols[i], core_cols[i + 1], core_cols[i + 1], core_cols[i]]),
			PackedVector2Array())
