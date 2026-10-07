@tool
extends StaticBody2D

## 번화가 전선 — 전봇대 사이에 늘어진 줄. **올라타서 걸을 수 있는 발판**이다(2026-10-07 사용자 결정).
## 그림은 `_draw()`로 긋고, 판정은 같은 곡선을 따라 원웨이 선분(SegmentShape2D)으로 깐다 —
## 위에서만 밟히고, 아래키 두 번으로 내려갈 수 있다(`Fighter.get_one_way_floor`가 선분도 그대로 잡는다).
## ⚠️ AI 발판 길찾기는 RectangleShape2D만 읽어서 **AI는 전선을 길로 모른다**
##
## **출렁임(2026-10-08)**: 올라선 자리를 꼭짓점으로 줄이 V자로 처지고(줄을 한 점에서 누른 모양),
## 떨어진 속도만큼 더 꺼졌다가 스프링처럼 되돌아온다. 되돌아오는 속도가 빠르면 탄 사람을 위로 띄운다.
## 그림과 판정 선분이 **같이** 움직인다 — 처진 줄 위에 발이 그대로 붙어 있다.
## 처짐 하나(`_sag`)를 감쇠 스프링으로 굴리는 단순한 모델이다(줄 전체를 시뮬레이션하지 않는다)

## 줄이 지나가는 점(맵 좌표 = 이 노드 기준). 이 점들을 부드럽게 이어 늘어진 줄을 만든다
@export var points: PackedVector2Array = PackedVector2Array():
	set(v):
		points = v
		_rebuild()
## 점과 점 사이를 몇 토막으로 나눠 부드럽게 할지
@export var smooth_steps: int = 8:
	set(v):
		smooth_steps = maxi(v, 1)
		_rebuild()
@export var line_width: float = 3.0:
	set(v):
		line_width = v
		queue_redraw()
@export var line_color: Color = Color(0.09, 0.09, 0.1):
	set(v):
		line_color = v
		queue_redraw()
## 이보다 가파른 토막은 밟을 수 없게 판정을 안 깐다(캐릭터 바닥 인식 한계가 45도)
@export var max_walk_angle_deg: float = 40.0
## 경사에서 통통 튀지 않게 캐릭터 바닥 붙잡기를 늘린다(`SlopeStair`와 같은 이유)
@export var snap_length: float = 12.0

@export_group("출렁임")
@export var bounce_enabled: bool = true
## 스프링 세기 — 클수록 빨리 출렁인다(260이면 초당 약 2.6번)
@export var spring_stiffness: float = 260.0
## 출렁임이 잦아드는 빠르기 — 클수록 빨리 멈춘다
@export var spring_damping: float = 5.0
## 한 명이 가운데 서 있을 때 처지는 깊이(px). 전봇대 쪽으로 갈수록 덜 처진다
@export var rider_sag: float = 14.0
## 떨어진 속도(px/s)에 이 값을 곱해 줄을 아래로 민다 — 세게 떨어질수록 깊이 꺼진다
@export var land_impulse: float = 0.45
## 가장 깊이 처질 수 있는 깊이(px). 위로는 이 절반까지 튄다
@export var max_sag: float = 48.0
## 줄이 이보다 빠르게(px/s) 올라올 때만 탄 사람을 띄운다 — 작은 떨림에 통통 튀지 않게
@export var launch_min_speed: float = 120.0
## 띄울 때 줄이 올라오는 속도에 곱하는 배수
@export var launch_boost: float = 1.2
@export_group("")

## 줄의 원래 모양(쉬는 상태)과 지금 그리는 모양
var _curve: PackedVector2Array = PackedVector2Array()
var _draw_curve: PackedVector2Array = PackedVector2Array()
## 판정 선분과 그 선분이 _curve의 몇 번째 점에서 시작하는지 [[CollisionShape2D, index], ...]
var _segments: Array = []
## 처짐 깊이(px, 아래가 +)와 그 속도, 누르는 자리(로컬 x)
var _sag: float = 0.0
var _sag_vel: float = 0.0
var _contact_x: float = 0.0
## 지난 프레임에 줄 위에 있던 사람 / 사람마다 직전 낙하 속도
var _riders_prev: Dictionary = {}
var _prev_fall: Dictionary = {}
## 쉬는 모양이 이미 입혀져 있는지 — 가만히 있을 땐 판정을 다시 안 깐다
var _at_rest: bool = true

func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		# 캐릭터는 Stage._ready()에서 만들어진다 — 이 노드보다 늦으므로 한 박자 미룬다
		_tune_fighters.call_deferred()

func _tune_fighters() -> void:
	for node in get_tree().get_nodes_in_group("fighters"):
		var body := node as CharacterBody2D
		if body == null:
			continue
		body.floor_snap_length = maxf(body.floor_snap_length, snap_length)
		body.floor_constant_speed = true

## 곡선을 다시 뽑고 판정 선분을 새로 깐다
func _rebuild() -> void:
	if not is_inside_tree():
		return
	_curve = _sample(points)
	_draw_curve = _curve.duplicate()
	_segments.clear()
	for child in get_children():
		if child is CollisionShape2D:
			remove_child(child)
			child.queue_free()
	if not Engine.is_editor_hint():
		var max_slope: float = tan(deg_to_rad(max_walk_angle_deg))
		for i in range(_curve.size() - 1):
			var a: Vector2 = _curve[i]
			var b: Vector2 = _curve[i + 1]
			var dx: float = absf(b.x - a.x)
			if dx < 0.5 or absf(b.y - a.y) / dx > max_slope:
				continue
			var seg := SegmentShape2D.new()
			seg.a = a
			seg.b = b
			var cs := CollisionShape2D.new()
			cs.shape = seg
			cs.one_way_collision = true
			# 줄이 위로 튈 때 발이 판정 안으로 파묻혀도 빠지지 않게 넉넉히
			cs.one_way_collision_margin = 8.0
			add_child(cs)
			_segments.append([cs, i])
	queue_redraw()

## Catmull-Rom으로 점들을 지나는 부드러운 곡선을 뽑는다
func _sample(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.size() < 2:
		return pts
	for i in range(pts.size() - 1):
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, pts.size() - 1)]
		for s in smooth_steps:
			var t: float = float(s) / smooth_steps
			var t2: float = t * t
			var t3: float = t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t
				+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[pts.size() - 1])
	return out

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not bounce_enabled or _curve.size() < 2:
		return
	delta = minf(delta, 0.05)
	var riders: Dictionary = {}
	var sum_x: float = 0.0
	for node in get_tree().get_nodes_in_group("fighters"):
		var fighter := node as CharacterBody2D
		if fighter == null or not is_instance_valid(fighter):
			continue
		if _is_riding(fighter):
			riders[fighter] = true
			sum_x += to_local(fighter.global_position).x
			# 막 올라탄 사람 — 떨어진 속도만큼 줄을 아래로 민다
			if not _riders_prev.has(fighter):
				_sag_vel += _prev_fall.get(fighter, 0.0) * land_impulse
		_prev_fall[fighter] = maxf(fighter.velocity.y, 0.0)
	_riders_prev = riders

	var target: float = 0.0
	if not riders.is_empty():
		_contact_x = _clamp_x(sum_x / riders.size())
		target = rider_sag * riders.size() * _end_factor(_contact_x)
	_sag_vel += (spring_stiffness * (target - _sag) - spring_damping * _sag_vel) * delta
	_sag += _sag_vel * delta
	if _sag > max_sag:
		_sag = max_sag
		_sag_vel = minf(_sag_vel, 0.0)
	elif _sag < -max_sag * 0.5:
		_sag = -max_sag * 0.5
		_sag_vel = maxf(_sag_vel, 0.0)

	# 줄이 빠르게 올라오면 탄 사람을 같이 들어 올린다 — 줄이 멈추면 그 속도로 날아오른다
	if _sag_vel < -launch_min_speed:
		for fighter in riders:
			var up: float = _sag_vel * _shape_at(to_local(fighter.global_position).x) * launch_boost
			if up < -launch_min_speed:
				fighter.velocity.y = minf(fighter.velocity.y, up)

	var resting: bool = riders.is_empty() and absf(_sag) < 0.05 and absf(_sag_vel) < 0.5
	if resting:
		if _at_rest:
			return
		_sag = 0.0
		_sag_vel = 0.0
	_at_rest = resting
	_apply_deform()

## 이 사람이 지금 이 줄을 밟고 서 있는지
func _is_riding(fighter: CharacterBody2D) -> bool:
	if not fighter.is_on_floor():
		return false
	for i in fighter.get_slide_collision_count():
		if fighter.get_slide_collision(i).get_collider() == self:
			return true
	return false

## 줄 양 끝 x
func _ends() -> Vector2:
	var a: float = _curve[0].x
	var b: float = _curve[_curve.size() - 1].x
	return Vector2(minf(a, b), maxf(a, b))

func _clamp_x(x: float) -> float:
	var e: Vector2 = _ends()
	return clampf(x, e.x + 1.0, e.y - 1.0)

## 가운데면 1, 전봇대 쪽으로 갈수록 0 — 끝에서 누르면 덜 처진다
func _end_factor(x: float) -> float:
	var e: Vector2 = _ends()
	var t: float = (x - e.x) / maxf(e.y - e.x, 1.0)
	return clampf(4.0 * t * (1.0 - t), 0.0, 1.0)

## 누르는 자리에서 1, 양 끝에서 0인 V자 — 줄을 한 점에서 누른 모양
func _shape_at(x: float) -> float:
	var e: Vector2 = _ends()
	if x <= _contact_x:
		return clampf((x - e.x) / maxf(_contact_x - e.x, 1.0), 0.0, 1.0)
	return clampf((e.y - x) / maxf(e.y - _contact_x, 1.0), 0.0, 1.0)

## 처짐을 그림과 판정 선분에 같이 입힌다
func _apply_deform() -> void:
	if _draw_curve.size() != _curve.size():
		_draw_curve = _curve.duplicate()
	for i in _curve.size():
		var p: Vector2 = _curve[i]
		_draw_curve[i] = Vector2(p.x, p.y + _sag * _shape_at(p.x))
	for pair in _segments:
		var cs: CollisionShape2D = pair[0]
		var idx: int = pair[1]
		var seg := cs.shape as SegmentShape2D
		seg.a = _draw_curve[idx]
		seg.b = _draw_curve[idx + 1]
	queue_redraw()

func _draw() -> void:
	var line: PackedVector2Array = _draw_curve if _draw_curve.size() == _curve.size() else _curve
	if line.size() >= 2:
		draw_polyline(line, line_color, line_width, true)
