extends CanvasLayer

## 화면 깨지기 연출(황근출 궁 내무반 진입, 2026-10-02) — 지금 화면을 찍어 조각(Polygon2D)으로 나눠 덮고,
## `center`에서 금이 퍼져 나간 뒤(crack_time) 조각이 바깥·아래로 흩어지며 떨어진다(fall_time). 뒤는 검정.
## 다 떨어져 화면이 까매지면 `shattered`를 낸다. 지우는 건 부른 쪽이 한다(검은 화면을 그대로 들고 있게)

signal shattered

@export var crack_time: float = 0.45
@export var fall_time: float = 0.75
## 중심에서 뻗는 금 줄기 수
@export var rays: int = 9
## 고리 모양 금의 반지름(화면 대각선 비율) — 0과 바깥 끝(1.2)은 자동
@export var rings: PackedFloat32Array = PackedFloat32Array([0.1, 0.25, 0.45, 0.7])
## 금 안쪽(가운데 선) 색과 그 둘레 테두리 색
@export var crack_color: Color = Color(0, 0, 0, 1)
@export var crack_outline_color: Color = Color(1, 1, 1, 0.9)
@export var crack_width: float = 2.5

var _center: Vector2
var _diag: float = 1.0
## _verts[i][j] — i번째 고리, j번째 줄기 위의 점
var _verts: Array = []
var _shards: Array[Polygon2D] = []
var _cracks: Node2D
var _crack_progress: float = 0.0

func _ready() -> void:
	layer = 50

## tex: 찍어 둔 화면, center: 금이 시작되는 화면 좌표
func start(tex: Texture2D, center: Vector2) -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	_center = center
	_diag = screen.length()
	var back := ColorRect.new()
	back.color = Color.BLACK
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.size = screen
	add_child(back)
	_build_verts()
	var uv_scale: Vector2 = Vector2(tex.get_size()) / screen
	var n: int = _verts[0].size()
	for i in _verts.size() - 1:
		for j in n:
			var k: int = (j + 1) % n
			var pts: Array = [_verts[i][j], _verts[i + 1][j], _verts[i + 1][k]]
			if i > 0:
				pts.append(_verts[i][k])
			_add_shard(pts, tex, uv_scale)
	_cracks = Node2D.new()
	_cracks.draw.connect(_draw_cracks)
	add_child(_cracks)
	var tw := create_tween()
	tw.tween_method(_set_crack, 0.0, 1.0, crack_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(_fall)

func _build_verts() -> void:
	var radii: Array[float] = [0.0]
	for r in rings:
		radii.append(r * _diag)
	radii.append(1.2 * _diag)
	var base: float = randf() * TAU
	var step: float = TAU / float(rays)
	var angles: Array[float] = []
	for j in rays:
		angles.append(base + j * step + randf_range(-0.3, 0.3) * step)
	_verts.clear()
	for i in radii.size():
		var row: Array[Vector2] = []
		for j in rays:
			if i == 0:
				row.append(_center)
				continue
			var jitter: float = 1.0 if i == radii.size() - 1 else randf_range(0.85, 1.15)
			row.append(_center + Vector2.from_angle(angles[j]) * radii[i] * jitter)
		_verts.append(row)

func _add_shard(pts: Array, tex: Texture2D, uv_scale: Vector2) -> void:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= float(pts.size())
	var poly := PackedVector2Array()
	var uv := PackedVector2Array()
	for p in pts:
		poly.append(p - c)
		uv.append(p * uv_scale)
	var shard := Polygon2D.new()
	shard.texture = tex
	shard.polygon = poly
	shard.uv = uv
	shard.position = c
	add_child(shard)
	_shards.append(shard)

func _set_crack(p: float) -> void:
	_crack_progress = p
	_cracks.queue_redraw()

## 금 — 줄기는 중심에서 바깥으로 자라고, 고리 조각은 금이 그 반지름에 닿으면 나타난다
func _draw_cracks() -> void:
	var reach: float = _crack_progress * _diag * 0.75
	var n: int = rays
	for i in _verts.size() - 1:
		for j in n:
			var a: Vector2 = _verts[i][j]
			var b: Vector2 = _verts[i + 1][j]
			var da: float = a.distance_to(_center)
			if da >= reach:
				continue
			var t: float = clampf((reach - da) / maxf(b.distance_to(_center) - da, 0.001), 0.0, 1.0)
			_crack_line(a, a.lerp(b, t))
			if i > 0:
				var k: int = (j + 1) % n
				if _verts[i][k].distance_to(_center) < reach:
					_crack_line(a, _verts[i][k])

func _crack_line(a: Vector2, b: Vector2) -> void:
	_cracks.draw_line(a, b, crack_outline_color, crack_width * 2.2)
	_cracks.draw_line(a, b, crack_color, crack_width)

func _fall() -> void:
	var fade := _cracks.create_tween()
	fade.tween_property(_cracks, "modulate:a", 0.0, 0.15)
	var longest: float = 0.0
	for shard in _shards:
		var off: Vector2 = shard.position - _center
		var dir: Vector2 = off.normalized() if off.length() > 1.0 else Vector2.DOWN
		var near: float = clampf(off.length() / _diag, 0.0, 1.0)
		var delay: float = near * 0.25 + randf() * 0.08
		var life: float = fall_time * randf_range(0.75, 1.0)
		var target: Vector2 = shard.position + dir * randf_range(60.0, 220.0) + Vector2(0, randf_range(350.0, 650.0))
		var tw := shard.create_tween().set_parallel(true)
		tw.tween_property(shard, "position", target, life).set_delay(delay).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(shard, "rotation", randf_range(-1.6, 1.6), life).set_delay(delay)
		tw.tween_property(shard, "scale", Vector2(0.85, 0.85), life).set_delay(delay)
		tw.tween_property(shard, "modulate:a", 0.0, life * 0.5).set_delay(delay + life * 0.5)
		longest = maxf(longest, delay + life)
	var done := create_tween()
	done.tween_interval(longest + 0.05)
	done.tween_callback(func(): shattered.emit())
