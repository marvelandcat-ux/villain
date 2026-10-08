extends Node2D

## 번화가 전선 위 비둘기(2026-10-08, 임시 — 그림은 `_draw()`로 그린다. 괜찮으면 스프라이트로 교체).
## 라운드마다 세 전선 중 **랜덤 한 줄**에 `min_count`~`max_count`마리가 나란히 앉는다(측면).
## **순수 장식** — 판정 없음, 맞지도 막지도 않는다.
##
## 도망 조건(앉아 있을 때, 마리마다):
## - 앉은 전선에 **누가 올라타면**(`PowerLine.has_riders()`)
## - 캐릭터가 `flee_radius`(100px) 원 안에 들어오면
## - 투사체(`projectiles`·`thrown_stones` 그룹)가 그 원 안에 들어오면
## - 옆 비둘기가 날아오르면 `startle_radius` 안의 비둘기도 조금 늦게 따라 뜬다
##
## 피신 자리 = **충돌 판정 있는 표면 아무 데나**(사용자 결정): 다른 전선 + 원웨이 발판(`RectangleShape2D`) 윗면 중
## 지금보다 `min_rise`만큼 위에 있고 안전한 곳. 위에 없으면 안전한 아무 데나, 그것도 없으면 허공에서 맴돌다 다시 고른다.
## 위협이 `calm_time` 동안 사라지면 **원래 자리로 돌아온다**. 전선이 출렁이면 앉은 비둘기도 같이 오르내린다.
## 전봇대 꼭대기는 그림뿐(판정 없음)이라 앉을 자리에 안 든다.

@export var min_count: int = 3
@export var max_count: int = 4
## 나란히 앉는 간격(px)
@export var spacing: float = 26.0
## 캐릭터·투사체가 이 반경(px) 안에 들어오면 도망
@export var flee_radius: float = 100.0
## 날아오른 비둘기 근처 이 거리 안의 비둘기도 놀라서 따라 뜬다
@export var startle_radius: float = 70.0
## 피신 자리는 지금보다 최소 이만큼(px) 위
@export var min_rise: float = 40.0
## 위협이 이 시간(초, + 0~2초 랜덤) 동안 없으면 집으로 돌아온다
@export var calm_time: float = 3.0
## 나는 속도(px/s)와 방향을 트는 빠르기
@export var fly_speed: float = 300.0
@export var fly_accel: float = 900.0
## 날개 퍼덕이는 속도(초당 라디안)
@export var flap_speed: float = 24.0
## 전선 양 끝에서 이만큼 안쪽에만 앉는다 — 끝은 전봇대 시차로 그림이 살짝 밀려 떠 보인다
@export var wire_end_margin_ratio: float = 0.25

## 그룹 이름 — 둥지(전선)와 피신 자리 후보는 여기서 찾는다
const WIRE_GROUP := "power_lines"

var _pigeons: Array = []

func _ready() -> void:
	# 전선·캐릭터는 이 노드보다 늦게 준비될 수 있다 — 한 박자 미룬다
	_spawn.call_deferred()

func _spawn() -> void:
	var wires: Array = _wires()
	if wires.is_empty():
		return
	var wire: Node2D = wires.pick_random()
	var ends: Vector2 = wire.global_ends()
	var span: float = ends.y - ends.x
	var count: int = randi_range(min_count, max_count)
	var row: float = spacing * (count - 1)
	var lo: float = ends.x + span * wire_end_margin_ratio
	var hi: float = ends.y - span * wire_end_margin_ratio - row
	var start_x: float = randf_range(lo, maxf(lo, hi))
	for i in count:
		var bird := PigeonBird.new()
		bird.flock = self
		bird.home_wire = wire
		bird.home_x = start_x + spacing * i
		bird.facing = -1.0 if randf() < 0.5 else 1.0
		add_child(bird)
		_pigeons.append(bird)

## 지금 맵의 전선들(`PowerLine`)
func _wires() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group(WIRE_GROUP):
		if node is Node2D and node.has_method("surface_global_y"):
			out.append(node)
	return out

## 이 점이 위협받는지 — 캐릭터·투사체가 반경 안에 있거나, 앉은 전선에 누가 타고 있으면
func threatened(point: Vector2, wire: Node2D, radius: float) -> bool:
	if wire != null and is_instance_valid(wire) and wire.has_riders():
		return true
	var r2: float = radius * radius
	for node in get_tree().get_nodes_in_group("fighters"):
		var f := node as Node2D
		if f != null and f.global_position.distance_squared_to(point) <= r2:
			return true
	for group in ["projectiles", "thrown_stones"]:
		for node in get_tree().get_nodes_in_group(group):
			var p := node as Node2D
			if p != null and p.global_position.distance_squared_to(point) <= r2:
				return true
	return false

## 가장 가까운 위협의 x — 도망칠 때 반대쪽을 보려고. 없으면 NAN
func nearest_threat_x(point: Vector2) -> float:
	var best: float = NAN
	var best_d: float = INF
	for group in ["fighters", "projectiles", "thrown_stones"]:
		for node in get_tree().get_nodes_in_group(group):
			var n := node as Node2D
			if n == null:
				continue
			var d: float = n.global_position.distance_squared_to(point)
			if d < best_d:
				best_d = d
				best = n.global_position.x
	return best

## 피신 자리 하나 고르기 — `from`보다 `min_rise` 위이고 안전한 곳 우선, 없으면 안전한 아무 데나.
## 돌려주는 사전: {"pos": Vector2, "wire": Node2D(전선이면) 또는 null}. 아무것도 없으면 빈 사전
func pick_perch(from: Vector2, exclude_wire: Node2D) -> Dictionary:
	var above: Array = []
	var any: Array = []
	for cand in _candidates():
		var pos: Vector2 = cand["pos"]
		var wire: Node2D = cand["wire"]
		if wire == exclude_wire and exclude_wire != null:
			continue
		if threatened(pos, wire, flee_radius * 1.2):
			continue
		any.append(cand)
		if pos.y <= from.y - min_rise:
			above.append(cand)
	if not above.is_empty():
		return above.pick_random()
	if not any.is_empty():
		return any.pick_random()
	return {}

## 앉을 수 있는 자리 후보 — 전선마다·발판마다 몇 점씩 랜덤으로 뽑는다
func _candidates() -> Array:
	var out: Array = []
	for wire in _wires():
		var ends: Vector2 = wire.global_ends()
		var span: float = ends.y - ends.x
		for i in 3:
			var x: float = randf_range(ends.x + span * wire_end_margin_ratio, ends.y - span * wire_end_margin_ratio)
			var y: float = wire.surface_global_y(x)
			if is_nan(y):
				continue
			out.append({"pos": Vector2(x, y), "wire": wire})
	var map: Node = get_parent()
	if map == null:
		return out
	for node in map.get_children():
		var body := node as StaticBody2D
		if body == null or body.has_method("surface_global_y"):
			continue
		for child in body.get_children():
			var cs := child as CollisionShape2D
			if cs == null or not cs.one_way_collision:
				continue
			var rect := cs.shape as RectangleShape2D
			if rect == null:
				continue
			var half: Vector2 = rect.size * 0.5 * cs.global_scale.abs()
			if half.x < 30.0:
				continue
			var top: float = cs.global_position.y - half.y
			for i in 2:
				var x: float = randf_range(cs.global_position.x - half.x + 20.0, cs.global_position.x + half.x - 20.0)
				out.append({"pos": Vector2(x, top), "wire": null})
	return out

## 한 마리가 날아오르면 옆 비둘기도 놀란다
func startle_near(source: Node2D) -> void:
	for bird in _pigeons:
		if bird == source or not is_instance_valid(bird):
			continue
		if bird.state == PigeonBird.State.PERCHED and bird.global_position.distance_to(source.global_position) <= startle_radius:
			bird.flee_after(randf_range(0.04, 0.18))


## 비둘기 한 마리 — 발끝이 원점, 오른쪽을 본다(`scale.x`로 뒤집기)
class PigeonBird extends Node2D:
	enum State { PERCHED, FLYING }

	var flock: Node2D
	## 둥지 — 처음 앉은 전선과 그 위의 월드 x
	var home_wire: Node2D
	var home_x: float
	var facing: float = 1.0
	var state: State = State.PERCHED
	## 지금 앉아 있는 곳(전선이면 그 전선, 발판이면 null)과 그 자리
	var perch_wire: Node2D
	var perch_pos: Vector2
	## 나는 중 목표와 목표가 전선이면 그 전선. `_hovering`이면 앉을 데 없이 허공을 맴도는 중
	var _target: Vector2
	var _target_wire: Node2D
	var _hovering: bool = false
	var _velocity: Vector2 = Vector2.ZERO
	var _flap: float = 0.0
	var _calm: float = 0.0
	var _calm_needed: float = 0.0
	var _recheck: float = 0.0
	var _flee_delay: float = -1.0

	func _ready() -> void:
		perch_wire = home_wire
		perch_pos = Vector2(home_x, home_wire.surface_global_y(home_x))
		global_position = perch_pos
		scale.x = facing
		_flap = randf() * TAU

	func _process(delta: float) -> void:
		delta = minf(delta, 0.05)
		match state:
			State.PERCHED:
				_perched(delta)
			State.FLYING:
				_flying(delta)
		queue_redraw()

	func _perched(delta: float) -> void:
		# 전선이 출렁이면 같이 오르내린다
		if perch_wire != null and is_instance_valid(perch_wire):
			var y: float = perch_wire.surface_global_y(perch_pos.x)
			if not is_nan(y):
				perch_pos.y = y
		global_position = perch_pos
		if _flee_delay >= 0.0:
			_flee_delay -= delta
			if _flee_delay < 0.0:
				_take_off()
			return
		if flock.threatened(global_position, perch_wire, flock.flee_radius):
			_take_off()
			flock.startle_near(self)
			return
		# 집이 아니면, 집이 조용해진 지 충분히 지났을 때 돌아간다
		if _at_home():
			return
		var home: Vector2 = Vector2(home_x, home_wire.surface_global_y(home_x))
		if flock.threatened(home, home_wire, flock.flee_radius * 1.2):
			_calm = 0.0
			return
		_calm += delta
		if _calm >= _calm_needed:
			_fly_to(home, home_wire)

	func _at_home() -> bool:
		return perch_wire == home_wire and absf(perch_pos.x - home_x) < 1.0

	## 조금 뒤에 날아오른다(옆 비둘기가 놀랐을 때)
	func flee_after(delay: float) -> void:
		if state == State.PERCHED and _flee_delay < 0.0:
			_flee_delay = delay

	func _take_off() -> void:
		_flee_delay = -1.0
		var tx: float = flock.nearest_threat_x(global_position)
		if not is_nan(tx) and absf(tx - global_position.x) > 1.0:
			facing = 1.0 if global_position.x > tx else -1.0
		_velocity = Vector2(facing * randf_range(60.0, 120.0), -randf_range(200.0, 260.0))
		_choose_perch()
		state = State.FLYING
		_calm = 0.0
		_calm_needed = flock.calm_time + randf_range(0.0, 2.0)

	## 피신 자리를 고른다 — 없으면 허공 한 점을 목표로 맴돈다
	func _choose_perch() -> void:
		var pick: Dictionary = flock.pick_perch(global_position, perch_wire)
		if pick.is_empty():
			_hovering = true
			_target = global_position + Vector2(randf_range(-120.0, 120.0), -randf_range(180.0, 280.0))
			_target_wire = null
		else:
			_hovering = false
			_target = pick["pos"]
			_target_wire = pick["wire"]
		_recheck = 0.3

	func _fly_to(pos: Vector2, wire: Node2D) -> void:
		_hovering = false
		_target = pos
		_target_wire = wire
		_velocity = Vector2(signf(pos.x - global_position.x) * 80.0, -160.0)
		state = State.FLYING
		_recheck = 0.3

	func _flying(delta: float) -> void:
		_flap += flock.flap_speed * delta
		# 목표가 전선이면 출렁임을 따라 목표 높이를 매 프레임 갱신
		if _target_wire != null and is_instance_valid(_target_wire):
			var y: float = _target_wire.surface_global_y(_target.x)
			if not is_nan(y):
				_target.y = y
		_recheck -= delta
		if _recheck <= 0.0:
			_recheck = 0.3
			if _hovering:
				_choose_perch()
			elif flock.threatened(_target, _target_wire, flock.flee_radius):
				_choose_perch()
		var to_target: Vector2 = _target - global_position
		var dist: float = to_target.length()
		if dist <= 30.0:
			# 가까우면 그냥 끌어당긴다 — 관성으로 빙빙 돌지 않게
			var step: float = maxf(110.0, fly_speed_near(dist)) * delta
			if step >= dist:
				_land()
				return
			global_position += to_target / dist * step
			_velocity = to_target / dist * 110.0
		else:
			var desired: Vector2 = to_target / dist * fly_speed_near(dist)
			_velocity = _velocity.move_toward(desired, flock.fly_accel * delta)
			global_position += _velocity * delta
		if absf(_velocity.x) > 10.0:
			facing = signf(_velocity.x)
		scale.x = facing
		rotation = clampf(atan2(_velocity.y, absf(_velocity.x)) * 0.5, -0.5, 0.5) * facing

	func fly_speed_near(dist: float) -> float:
		return lerpf(110.0, flock.fly_speed, clampf(dist / 120.0, 0.0, 1.0))

	func _land() -> void:
		if _hovering:
			# 맴돌 자리에 닿았다 — 다시 앉을 데를 찾는다
			_choose_perch()
			return
		global_position = _target
		perch_pos = _target
		perch_wire = _target_wire
		rotation = 0.0
		_velocity = Vector2.ZERO
		state = State.PERCHED
		_calm = 0.0

	func _draw() -> void:
		var body_col := Color(0.6, 0.62, 0.68)
		var head_col := Color(0.42, 0.46, 0.56)
		var dark := Color(0.38, 0.4, 0.46)
		var orange := Color(0.9, 0.5, 0.2)
		var flying: bool = state == State.FLYING
		# 다리(앉아 있을 때만)
		if not flying:
			draw_line(Vector2(-2.5, -3.0), Vector2(-2.5, 0.0), orange, 1.2)
			draw_line(Vector2(2.0, -3.0), Vector2(2.0, 0.0), orange, 1.2)
		# 꼬리
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -7), Vector2(-14, -5), Vector2(-13, -9.5), Vector2(-6, -10)]), dark)
		if flying:
			# 먼쪽 날개(연함) → 몸 → 가까운 날개(진함). 퍼덕임은 날개 끝 높이로 — 얇아질 때 넓이 0이 되므로 draw_primitive
			var flap: float = sin(_flap)
			_draw_wing(Vector2(1, -9), flap * 0.75, Color(0.7, 0.72, 0.78))
		# 몸통
		draw_circle(Vector2(0, -8), 7.0, body_col)
		if not flying:
			# 접은 날개
			draw_colored_polygon(PackedVector2Array([Vector2(-3, -11), Vector2(4, -10), Vector2(-1, -5.5), Vector2(-8, -7)]), dark)
		# 머리·눈·부리
		draw_circle(Vector2(6, -14), 4.2, head_col)
		draw_circle(Vector2(7.6, -15), 0.9, Color(0.05, 0.05, 0.06))
		draw_colored_polygon(PackedVector2Array([Vector2(9.6, -14.6), Vector2(13.5, -13.6), Vector2(9.6, -12.6)]), orange)
		if flying:
			_draw_wing(Vector2(-1, -9), sin(_flap + 0.35), dark)

	## 어깨에서 뒤쪽으로 뻗는 날개 — `lift`가 -1(위)~1(아래)로 날개 끝 높이
	func _draw_wing(shoulder: Vector2, lift: float, col: Color) -> void:
		var tip: Vector2 = shoulder + Vector2(-7.0, 17.0 * lift)
		var pts := PackedVector2Array([shoulder + Vector2(4, 0), tip + Vector2(3, 0), tip + Vector2(-4, 0), shoulder + Vector2(-5, 0)])
		var cols := PackedColorArray([col, col, col, col])
		draw_primitive(pts, cols, PackedVector2Array())
