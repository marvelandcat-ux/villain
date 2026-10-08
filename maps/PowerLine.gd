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
## 이 각도까지는 걸어 오를 수 있게 캐릭터의 바닥 인식 한계(`floor_max_angle`, 기본 45도)를 늘린다.
## ⚠️ 판정은 각도와 상관없이 **모든 토막에** 깐다 — 예전엔 가파른 토막을 건너뛰어서 전선 끝(가장 가파른 곳)에
## 판정 구멍이 생겨 캐릭터가 빠졌다(2026-10-08). 이보다 가파른 토막은 벽처럼 막기만 한다
@export var max_walk_angle_deg: float = 60.0
## 경사에서 통통 튀지 않게 캐릭터 바닥 붙잡기를 늘린다(`SlopeStair`와 같은 이유)
@export var snap_length: float = 12.0

@export_group("출렁임")
@export var bounce_enabled: bool = true
## 스프링 세기 — 클수록 빨리 출렁인다(260이면 초당 약 2.6번)
@export var spring_stiffness: float = 260.0
## 출렁임이 잦아드는 빠르기 — 클수록 빨리 멈춘다(5 → 7, 2026-10-08: 서 있을 때 잔떨림이 빨리 가라앉게)
@export var spring_damping: float = 7.0
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
## 발이 줄에서 잠깐 떨어져도 이 시간(초) 동안은 탄 것으로 친다 — 줄이 내려가며 생기는 한두 프레임의 공중을 메운다
@export var rider_grace: float = 0.2
## 그레이스 동안 "줄 근처"로 보는 높이(px) — 이보다 높이 떠 있으면 진짜 뛰어오른 것
@export var near_wire_px: float = 40.0
@export_group("")

@export_group("전봇대 따라가기")
## 줄 양 끝이 걸린 전봇대(`ForegroundFade`). 전봇대가 시차로 밀리면 **그림 끝만** 같이 따라간다 —
## 판정 선분은 그대로다(밟는 발판이 카메라 따라 움직이면 안 된다). 비우면 그 끝은 안 따라간다
@export var start_anchor: NodePath
@export var end_anchor: NodePath
## 끝에서 이만큼(px) 안쪽까지 서서히 섞어 들어간다 — 짧으면 끝만 꺾여 보인다
@export var anchor_blend_px: float = 260.0
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
## 사람마다 "아직 탄 것으로 치는" 남은 시간(초) — `rider_grace`
var _rider_grace: Dictionary = {}
## 쉬는 모양이 이미 입혀져 있는지 — 가만히 있을 땐 판정을 다시 안 깐다
var _at_rest: bool = true
## 전봇대가 시차로 밀린 만큼(시작 끝 / 마지막 끝) — 그림에만 더한다
var _anchor_shift: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]

func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		# 설치물(고양이 집 등)이 "여긴 땅이 아니다"를 알아보는 표식 — CatHouseSkill이 본다(2026-10-08)
		add_to_group("power_lines")
		# 캐릭터는 Stage._ready()에서 만들어진다 — 이 노드보다 늦으므로 한 박자 미룬다
		_tune_fighters.call_deferred()

func _tune_fighters() -> void:
	for node in get_tree().get_nodes_in_group("fighters"):
		var body := node as CharacterBody2D
		if body == null:
			continue
		body.floor_snap_length = maxf(body.floor_snap_length, snap_length)
		body.floor_max_angle = maxf(body.floor_max_angle, deg_to_rad(max_walk_angle_deg))
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
		for i in range(_curve.size() - 1):
			var a: Vector2 = _curve[i]
			var b: Vector2 = _curve[i + 1]
			if a.distance_squared_to(b) < 0.01:
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

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var changed: bool = false
	for i in 2:
		var shift: Vector2 = _anchor_shift_of(start_anchor if i == 0 else end_anchor)
		if shift.distance_squared_to(_anchor_shift[i]) > 0.0001:
			_anchor_shift[i] = shift
			changed = true
	if changed:
		queue_redraw()

## 전봇대가 지금 밀린 거리 — 전봇대가 없거나 시차 함수가 없으면 0
func _anchor_shift_of(path: NodePath) -> Vector2:
	if path.is_empty():
		return Vector2.ZERO
	var node: Node = get_node_or_null(path)
	if node == null or not node.has_method("parallax_shift"):
		return Vector2.ZERO
	return node.parallax_shift()

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
		var touching: bool = _is_riding(fighter)
		if touching:
			_rider_grace[fighter] = rider_grace
			# 줄 위에선 착지 경직이 없다(스프링 발판과 같은 규칙). 줄이 처지며 착지 높이가 조금 늘어
			# 평소엔 안 걸리던 경직(180px)이 걸리고, 그 0.1~0.3초 동안 누른 점프가 씹혔다(2026-10-08 실측 22번 중 3번)
			if fighter.has_method("cancel_landing_lag"):
				fighter.cancel_landing_lag()
		elif _rider_grace.get(fighter, 0.0) > 0.0 and _near_wire(fighter):
			# 줄이 발밑에서 내려가 한두 프레임 떠 있는 것 — 여전히 탄 것으로 친다 (이걸 안 하면 "탔다/안 탔다"가
			# 프레임마다 뒤집혀 목표 처짐이 0 ↔ rider_sag를 오가고, 줄이 발을 때려 위아래로 떨었다. 2026-10-08)
			_rider_grace[fighter] -= delta
		else:
			_rider_grace.erase(fighter)
		if _rider_grace.has(fighter):
			riders[fighter] = true
			sum_x += to_local(fighter.global_position).x
			# 막 올라탄 사람 — 떨어진 속도만큼 줄을 아래로 민다
			if not _riders_prev.has(fighter):
				_sag_vel += _prev_fall.get(fighter, 0.0) * land_impulse
		_prev_fall[fighter] = maxf(fighter.velocity.y, 0.0)
	_riders_prev = riders

	var old_sag: float = _sag
	var old_contact: float = _contact_x
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
	# 탄 사람을 줄이 움직인 만큼 같이 옮긴다(움직이는 발판처럼). 안 옮기면 줄이 내려갈 때 발이 허공에 뜨고
	# 올라올 때 발을 때려 통통 튄다. 점프해서 떠오르는 중(위로 빠른 속도)이면 안 건드린다
	for fighter in riders:
		if not is_instance_valid(fighter) or fighter.velocity.y < -launch_min_speed:
			continue
		var lx: float = to_local(fighter.global_position).x
		var dy: float = _sag * _shape_at(lx) - old_sag * _shape_at_contact(lx, old_contact)
		if absf(dy) > 0.001:
			fighter.global_position.y += dy

## 줄에서 (위로) 이 거리 안에 있고 x가 줄 범위 안이면 "줄 근처" — 그레이스 동안 탄 사람으로 유지하는 조건
func _near_wire(fighter: CharacterBody2D) -> bool:
	var lp: Vector2 = to_local(fighter.global_position)
	var e: Vector2 = _ends()
	if lp.x < e.x or lp.x > e.y:
		return false
	var wire_y: float = _y_at(lp.x)
	return is_nan(wire_y) == false and lp.y <= wire_y + 4.0 and lp.y >= wire_y - near_wire_px

## 지금 그리는 줄(처짐 포함)의 로컬 x에서의 y. 범위 밖이면 NAN
func _y_at(x: float) -> float:
	var cur: PackedVector2Array = _draw_curve if _draw_curve.size() == _curve.size() else _curve
	for i in range(cur.size() - 1):
		var a: Vector2 = cur[i]
		var b: Vector2 = cur[i + 1]
		if x >= minf(a.x, b.x) and x <= maxf(a.x, b.x):
			var t: float = 0.0 if absf(b.x - a.x) < 0.001 else (x - a.x) / (b.x - a.x)
			return lerpf(a.y, b.y, t)
	return NAN

## `_shape_at`과 같지만 누르는 자리를 바깥에서 준다(직전 프레임 모양을 되짚을 때)
func _shape_at_contact(x: float, contact: float) -> float:
	var e: Vector2 = _ends()
	if x <= contact:
		return clampf((x - e.x) / maxf(contact - e.x, 1.0), 0.0, 1.0)
	return clampf((e.y - x) / maxf(e.y - contact, 1.0), 0.0, 1.0)

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
	if line.size() < 2:
		return
	if _anchor_shift[0] != Vector2.ZERO or _anchor_shift[1] != Vector2.ZERO:
		line = _with_anchor_shift(line)
	draw_polyline(line, line_color, line_width, true)

## 양 끝을 전봇대가 밀린 만큼 옮기고, 끝에서 `anchor_blend_px` 안쪽까지 부드럽게 섞는다
func _with_anchor_shift(line: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(line.size())
	var x0: float = line[0].x
	var x1: float = line[line.size() - 1].x
	var blend: float = maxf(anchor_blend_px, 1.0)
	for i in line.size():
		var p: Vector2 = line[i]
		var w0: float = clampf(1.0 - absf(p.x - x0) / blend, 0.0, 1.0)
		var w1: float = clampf(1.0 - absf(p.x - x1) / blend, 0.0, 1.0)
		w0 = w0 * w0 * (3.0 - 2.0 * w0)
		w1 = w1 * w1 * (3.0 - 2.0 * w1)
		out[i] = p + _anchor_shift[0] * w0 + _anchor_shift[1] * w1
	return out
