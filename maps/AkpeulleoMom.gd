class_name AkpeulleoMom
extends CharacterBody2D

## 악플러의 집 맵 기믹 "악플러집 엄마" — `MomDoorGimmick`이 문을 열고 내보낸다.
## 나오면 "안 자고 뭐하니!" 한마디 → 가장 가까운 플레이어에게 걸어가서 → 사거리에 들면 3타처럼 등짝을 때려 날려 보낸다.
## `stay_time`이 지나면 들어온 문 말고 **다른 문**으로 걸어가 들어간다.
##
## **Fighter가 아니다**(`IljinCrewMember`와 같은 이유) — "fighters" 그룹에 들어가면 카메라·AI·승패 판정이 엄마를 캐릭터로 착각한다.
## Hurtbox가 없어서 **맞지 않는다**. 이단 점프는 없다(1단 점프만, 사용자 지정) — 1단으로 못 가는 발판 위는 피난처가 된다.
## 그림은 `AkpeulleoMomRig`(엄마 스프라이트 머리·몸통 + 손발은 고양이 아줌마 것을 빌려 씀)

## 다른 문 앞에 도착했다 — 기믹이 그 문을 열고 `vanish()`를 부른다
signal exit_reached
## 사라졌다(문으로 들어갔거나, 못 가서 그 자리에서 사라졌거나)
signal vanished

const DISPLAY_NAME := "악플러집 엄마"
## 몸 캡슐(r20 h60) 원점에서 발바닥까지
const FEET_OFFSET := 30.0
## 몸 캡슐 반지름 — 발판 끝에 반쯤 걸쳐 서 있을 수 있는 폭
const BODY_RADIUS := 20.0
## 점프 스피드 라인 — 캐릭터 점프(`Fighter._spawn_jump_speed_lines`)와 같은 것
const SPEED_LINES_SCRIPT := preload("res://combat/DashTrailLines.gd")
const JUMP_SPEED_LINE_TIME := 0.4
const LEAP_SPEED_LINE_TIME := 0.7
## 3타 날아가기 이펙트 (평타 마무리와 같은 것)
const LAUNCH_TRAIL := preload("res://combat/LaunchTrail.gd")
## 암전 때 켜지는 노란 십자 눈빛 — 리그 Head 자식으로 붙인다
const EYE_GLOW := preload("res://maps/MomEyeGlow.gd")

## 걷는 속도 = **쫓는 플레이어의 이동속도**(그 캐릭터 스탯 move_speed) x speed_ratio.
## 쫓는 상대가 없을 때(문으로 돌아갈 때 등)는 마지막으로 쫓던 상대, 그것도 없으면 이 스탯을 쓴다
@export var base_stats: CharacterStats
@export var speed_ratio: float = 1.0
## 나와서 들어갈 때까지 머무는 시간(초). 이게 지나면 다른 문으로 향한다
@export var stay_time: float = 16.0
## 나오자마자 하는 대사와 말풍선이 떠 있는 시간(초)
@export var line: String = "안 자고 뭐하니!"
@export var line_time: float = 2.2
## 나와서 대사하며 멈춰 서 있는 시간(초)
@export var intro_pause: float = 0.8

## --- 등짝 (3타처럼) ---
@export var damage: int = 20
## 앞쪽으로 닿는 거리(px)와 위아래로 인정하는 범위(px)
## (2026-10-06 사용자 요청으로 네모 범위 전체를 1.6배: 50→80, 45→72)
@export var attack_range: float = 80.0
@export var attack_height: float = 72.0
## 휘두르기 시작부터 맞는 순간까지(초) — **평타 3타 준비시간(0.223초)과 같게**
@export var strike_delay: float = 0.223
## 때린 뒤 굳어 있는 시간 / 다음 등짝까지 쉬는 시간(초)
@export var attack_recover: float = 0.45
@export var attack_cooldown: float = 1.0
## 날려 보내는 값 — `ComboMeleeAttack`의 3타 기본값과 같다(`Fighter.launch_finisher`에 그대로 넘김)
@export var launch_speed: float = 535.0
@export var launch_pop: float = 220.0
@export var launch_stun: float = 0.4
@export var launch_turns: float = 1.0
@export var launch_max_scale: float = 2.0
## 등짝 휘두를 때 말풍선 대사, 동작이 끝나고도 더 떠 있는 시간(초)
@export var smash_line: String = "등짝 스매쉬!"
@export var smash_line_linger: float = 0.4

## 다른 문까지 이 시간(초) 안에 못 가면 그 자리에서 사라진다(길이 막혔을 때 영원히 남지 않게)
@export var exit_timeout: float = 20.0
## 1단 점프로 못 올라가는 문 발판이면 문 아래 이 거리(px) 안까지 걸어간 뒤 한 번에 뛰어오른다
@export var exit_leap_distance: float = 180.0
## 나타나고 사라지는 시간(초)
@export var fade_time: float = 0.3

## 기믹이 add_child 전에 넣어준다 — 발판을 모을 맵, 들어갈 문 앞 발바닥 자리
var map: Node = null
var exit_feet: Vector2 = Vector2.ZERO

enum State { ENTER, CHASE, EXIT, LEAVING }
var _state: int = State.ENTER
var _state_time: float = 0.0
var _facing: float = 1.0
## 등짝 동작 남은 시간 / 이미 맞혔는지 / 다음 등짝까지 쿨
var _attack_left: float = 0.0
var _struck: bool = false
var _attack_cd: float = 0.0
## 문 발판으로 한 번에 뛰어오르는 중 — 공중에서 가로 속도를 건드리지 않는다
var _leaping: bool = false
## 이미 사라지는 중인지(두 번 사라지지 않게)
var _vanishing: bool = false
## 말풍선 대사 번호 — 앞 대사의 닫기 타이머가 새 대사를 일찍 닫지 않게
var _say_id: int = 0
## 걷는 속도를 따라갈 상대(마지막으로 쫓던 플레이어)
var _speed_ref: Fighter = null
## 몸 충돌을 이미 꺼 둔 캐릭터들 {instance_id: true}
var _ignored: Dictionary = {}

## 발판 목록 — 각 칸은 {id, left, right, top, one_way} (AIController 발판 길찾기와 같은 방식, 1단 점프 기준)
var _platforms: Array = []
var _nav_next = null
var _nav_from_id: int = -1
var _plan_timer: float = 0.0

@onready var _visual: Node2D = get_node_or_null("Visual")
@onready var _bubble: Node2D = get_node_or_null("Bubble")

func _ready() -> void:
	# 계단(SlopeStair)은 "fighters"만 바닥 붙잡기를 늘려 주므로 엄마는 직접 맞춘다
	floor_snap_length = 12.0
	floor_constant_speed = true
	_collect_platforms()
	_attach_eye_glow()
	# 방 가운데를 보고 나온다
	_set_facing(signf(exit_feet.x - global_position.x))
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, fade_time)
	if _bubble:
		# 말풍선이 방 바깥(벽 쪽)으로 삐져나가지 않게 방 안쪽으로 띄운다
		_bubble.bubble_center = Vector2(absf(_bubble.bubble_center.x) * _facing, _bubble.bubble_center.y)
		_say(line, line_time)

func _physics_process(delta: float) -> void:
	delta = minf(delta, 0.05)
	_state_time += delta
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	if not is_on_floor():
		var g: float = Fighter.gravity * (Fighter.fall_gravity_multiplier if velocity.y > 0.0 else 1.0)
		velocity.y += g * delta
	match _state:
		State.ENTER:
			velocity.x = 0.0
			if _state_time >= intro_pause:
				_change_state(State.CHASE)
		State.CHASE:
			_update_chase(delta)
			if _state_time >= stay_time and _attack_left <= 0.0:
				_change_state(State.EXIT)
		State.EXIT:
			_update_exit(delta)
		State.LEAVING:
			velocity.x = 0.0
	move_and_slide()
	if is_on_floor():
		_leaping = false
	_ignore_fighter_bodies()
	_update_walk_pose()

func _change_state(s: int) -> void:
	_state = s
	_state_time = 0.0
	_nav_next = null

## 말풍선에 대사를 띄우고 duration초 뒤 닫는다(그 사이 새 대사가 뜨면 그쪽 타이머가 닫는다)
func _say(text: String, duration: float) -> void:
	if _bubble == null:
		return
	_say_id += 1
	var id: int = _say_id
	_bubble.say(text)
	Timers.after(self, duration, func() -> void:
		if id == _say_id:
			_bubble.close())

## 문 안으로 사라진다 — 기믹이 문을 연 뒤 부른다
func vanish() -> void:
	if _vanishing:
		return
	_vanishing = true
	_state = State.LEAVING
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	tween.tween_callback(func() -> void:
		vanished.emit()
		queue_free())

# ---------------------------------------------------------------- 쫓아가서 등짝

func _update_chase(delta: float) -> void:
	if _attack_left > 0.0:
		_update_attack(delta)
		return
	var foe: Fighter = _find_target()
	if foe:
		_speed_ref = foe
	# 라운드가 끝났으면(KO 연출·결과 화면) 더 때리지 않고 서 있는다
	if foe == null or _round_over():
		velocity.x = 0.0
		return
	var dx: float = foe.global_position.x - global_position.x
	var dy: float = foe.global_position.y - global_position.y
	if is_on_floor() and _attack_cd <= 0.0 and absf(dx) <= attack_range and absf(dy) <= attack_height:
		_start_attack(signf(dx) if not is_zero_approx(dx) else _facing)
		return
	# 같은 발판에서 붙었으면 멈춰 선다(계속 밀고 들어가면 겹친다)
	if is_on_floor() and absf(dy) <= attack_height and absf(dx) <= attack_range * 0.8:
		velocity.x = 0.0
		_set_facing(signf(dx))
		return
	_go_to(foe.global_position.x, foe.global_position.y + FEET_OFFSET, delta)

func _start_attack(dir: float) -> void:
	_set_facing(dir)
	velocity.x = 0.0
	_attack_left = strike_delay + attack_recover
	_struck = false
	_say(smash_line, strike_delay + attack_recover + smash_line_linger)
	if _visual and _visual.has_method("play_attack_swing"):
		# 리그의 "내리치기 시작" 비율로 모션 길이를 역산해 맞는 순간을 strike_delay에 맞춘다(3번째 휘두르기 = 마무리 손)
		var ratio: float = _visual.strike_time(1.0) if _visual.has_method("strike_time") else 0.4
		_visual.play_attack_swing(2, strike_delay / maxf(ratio, 0.01))
		# 평타처럼 휘두르는 손에 하얀 궤적을 남긴다(2026-10-06 사용자 요청) — 스윙을 정한 **다음에** 켠다
		if _visual.has_method("play_swing_trail"):
			_visual.play_swing_trail()

func _update_attack(delta: float) -> void:
	velocity.x = 0.0
	_attack_left = maxf(_attack_left - delta, 0.0)
	if not _struck and _attack_left <= attack_recover:
		_struck = true
		_strike()
	if _attack_left <= 0.0:
		_attack_cd = attack_cooldown

## 앞쪽 상자 안 캐릭터를 전부 때려 날린다. **맵 피해**라 방어로 못 막는다(`take_map_damage`가 방어를 깸)
func _strike() -> void:
	for f in get_tree().get_nodes_in_group("fighters"):
		if not (f is Fighter) or not is_instance_valid(f):
			continue
		var target: Fighter = f
		var dx: float = target.global_position.x - global_position.x
		if absf(dx) > attack_range + 16.0 or dx * _facing < -32.0:
			continue
		if absf(target.global_position.y - global_position.y) > attack_height:
			continue
		if target.is_invincible:
			continue
		target.take_map_damage(damage)
		_launch(target)

## 3타 날리기 — 평타 마무리(`ComboMeleeAttack._launch_finisher`)와 같은 값·이펙트
func _launch(target: Fighter) -> void:
	if target.has_super_armor():
		return
	var parent: Node = target.get_parent()
	if parent:
		var up: float = tan(deg_to_rad(Fighter.FINISHER_LAUNCH_ANGLE_DEG))
		var trail = LAUNCH_TRAIL.new()
		parent.add_child(trail)
		trail.setup(target, Vector2(_facing, -up))
	target.launch_finisher(_facing, launch_speed, launch_pop, launch_stun, launch_turns, launch_max_scale)

## 가장 가까운 캐릭터
func _find_target() -> Fighter:
	var best: Fighter = null
	var best_d: float = INF
	for f in get_tree().get_nodes_in_group("fighters"):
		if not (f is Fighter) or not is_instance_valid(f):
			continue
		var d: float = global_position.distance_squared_to(f.global_position)
		if d < best_d:
			best_d = d
			best = f
	return best

## 맵 루트(Stage)가 라운드 끝 상태인지
func _round_over() -> bool:
	return map != null and is_instance_valid(map) and map.get("_round_over") == true

# ---------------------------------------------------------------- 다른 문으로

func _update_exit(delta: float) -> void:
	if _state_time >= exit_timeout:
		vanish()
		return
	var feet_y: float = global_position.y + FEET_OFFSET
	var dx: float = exit_feet.x - global_position.x
	if is_on_floor() and absf(dx) <= 16.0 and absf(feet_y - exit_feet.y) <= 14.0:
		velocity.x = 0.0
		_state = State.LEAVING
		exit_reached.emit()
		return
	if _leaping:
		return
	var reachable: bool = _go_to(exit_feet.x, exit_feet.y, delta)
	# 1단 점프로 이어지는 길이 없으면(양쪽 문 발판은 땅에서 1단으로 못 닿는다) 문 아래까지 가서 한 번에 뛰어오른다
	if not reachable and is_on_floor() and exit_feet.y < feet_y - 4.0 and absf(dx) <= exit_leap_distance:
		_leap_to(exit_feet)

## target(발바닥 자리)에 내려앉는 포물선으로 한 번 뛴다 — 꼭대기는 목표보다 50px 위
func _leap_to(target: Vector2) -> void:
	var feet_y: float = global_position.y + FEET_OFFSET
	var rise: float = feet_y - target.y
	var apex: float = maxf(rise + 50.0, 60.0)
	var g_up: float = Fighter.gravity
	var g_down: float = Fighter.gravity * Fighter.fall_gravity_multiplier
	var vy: float = -sqrt(2.0 * g_up * apex)
	var t: float = -vy / g_up + sqrt(2.0 * (apex - rise) / g_down)
	velocity.y = vy
	velocity.x = (target.x - global_position.x) / maxf(t, 0.1)
	_set_facing(signf(velocity.x))
	_leaping = true
	_spawn_speed_lines(LEAP_SPEED_LINE_TIME)

# ---------------------------------------------------------------- 발판 길찾기 (1단 점프)

## (goal_x, goal_feet_y)로 한 걸음. 1단 점프로 이어지는 길이 없으면 false(그래도 가로로는 따라간다)
func _go_to(goal_x: float, goal_feet_y: float, delta: float) -> bool:
	var x: float = global_position.x
	if not is_on_floor():
		# 공중: 다음 발판(없으면 목표) 쪽으로 몸을 튼다
		var land_x: float = goal_x
		if _nav_next != null:
			land_x = clampf(goal_x, _nav_next.left + 24.0, _nav_next.right - 24.0)
		_walk(signf(land_x - x) if absf(land_x - x) > 8.0 else 0.0)
		return true
	# 발판 끝에 몸이 걸쳐 서 있어도(가운데가 끝을 넘어도) 그 발판으로 쳐야 한다 — 아니면 훨씬 아래 발판으로 잘못 잡혀
	# "아래 계단으로 가라 / 다시 오른쪽으로 가라"를 번갈아 하며 끝에서 떤다(맨 위 발판 오른쪽 끝에서 실제로 겪음)
	var mine = _support_under(x, global_position.y + FEET_OFFSET, BODY_RADIUS)
	var goal = _support_under(goal_x, goal_feet_y)
	if mine == null or goal == null or mine.id == goal.id:
		_nav_next = null
		_walk(signf(goal_x - x) if absf(goal_x - x) > 6.0 else 0.0)
		return mine != null and goal != null
	_plan_timer -= delta
	if _nav_next == null or _nav_from_id != mine.id or _plan_timer <= 0.0:
		_nav_next = _plan_next(mine, goal)
		_nav_from_id = mine.id
		_plan_timer = 0.5
	if _nav_next == null:
		_walk(signf(goal_x - x) if absf(goal_x - x) > 6.0 else 0.0)
		return false
	_nav_ground_step(mine, _nav_next, goal_x)
	return true

## 발판 위에서: 올라갈 거면 도약 자리로 가서 뛰고, 내려갈 거면 발판을 뚫고 내려가거나 가장자리로 걸어 나간다
func _nav_ground_step(cur: Dictionary, nxt: Dictionary, goal_x: float) -> void:
	var x: float = global_position.x
	if nxt.top < cur.top - 4.0:
		var tx: float = _takeoff_x(cur, nxt, x)
		if absf(tx - x) > 10.0:
			_walk(signf(tx - x))
		else:
			_walk(0.0)
			_jump()
		return
	var land_x: float = clampf(goal_x, nxt.left + 20.0, nxt.right - 20.0)
	if cur.one_way and nxt.top > cur.top + 4.0 and x > nxt.left + 10.0 and x < nxt.right - 10.0:
		if _drop_through():
			return
	_walk(signf(land_x - x) if absf(land_x - x) > 6.0 else 0.0)
	# 옆 발판이 거의 같은 높이인데 사이가 비었으면 가장자리에서 뛰어 건넌다
	var near_edge: bool = x > cur.right - 18.0 or x < cur.left + 18.0
	if is_on_wall() or (near_edge and nxt.top < cur.top + 40.0 and (nxt.left > cur.right or nxt.right < cur.left)):
		_jump()

## cur 위 어디서 뛰어야 nxt에 닿는지
func _takeoff_x(cur: Dictionary, nxt: Dictionary, x: float) -> float:
	var l: float = maxf(cur.left, nxt.left) + 16.0
	var r: float = minf(cur.right, nxt.right) - 16.0
	if nxt.one_way and l <= r:
		return clampf(x, l, r)
	if nxt.left >= cur.right - 16.0:
		return cur.right - 12.0
	return cur.left + 12.0

## 1단 점프만 — 공중 점프는 없다
func _jump() -> void:
	if is_on_floor():
		velocity.y = Fighter.jump_velocity
		_spawn_speed_lines(JUMP_SPEED_LINE_TIME)

## 지나간 길을 따라 하얀 줄을 남긴다 — 엄마 자식이면 좌우 반전에 뒤집히므로 부모(맵 쪽)에 붙인다
func _spawn_speed_lines(life: float) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var lines = SPEED_LINES_SCRIPT.new()
	lines.offset_along_normal = true
	lines.spread_y = Vector2(-18.0, 18.0)
	parent.add_child(lines)
	lines.setup(self, life)

## 밟고 있는 통과 발판과의 충돌만 잠깐 꺼서 아래층으로 내려간다(`Fighter.drop_through_platform`과 같은 방식)
func _drop_through() -> bool:
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if collision.get_normal().y > -0.7:
			continue
		var body = collision.get_collider()
		if not (body is PhysicsBody2D):
			continue
		var owner_id: int = body.shape_find_owner(collision.get_collider_shape_index())
		if owner_id == -1 or not body.is_shape_owner_one_way_collision_enabled(owner_id):
			continue
		add_collision_exception_with(body)
		velocity.y = maxf(velocity.y, 10.0)
		Timers.after(self, 0.35, func() -> void:
			if is_instance_valid(body):
				remove_collision_exception_with(body))
		return true
	return false

## 맵의 발판·바닥(StaticBody2D의 기울지 않은 직사각형 충돌)을 모은다 — 악플러의 집은 발판이 안 바뀌어서 한 번이면 된다
func _collect_platforms() -> void:
	_platforms.clear()
	if map != null and is_instance_valid(map):
		_collect(map)

func _collect(node: Node) -> void:
	for child in node.get_children():
		if child is Fighter:
			continue
		if child is StaticBody2D:
			for cs in child.get_children():
				_add_platform(cs)
		_collect(child)

func _add_platform(cs: Node) -> void:
	var shape_node := cs as CollisionShape2D
	if shape_node == null or shape_node.disabled or not (shape_node.shape is RectangleShape2D):
		return
	var t: Transform2D = shape_node.global_transform
	if absf(t.get_rotation()) > 0.05:
		return
	var size: Vector2 = (shape_node.shape as RectangleShape2D).size * t.get_scale().abs()
	if size.x < 24.0:
		return
	_platforms.append({
		"id": shape_node.get_instance_id(),
		"left": t.origin.x - size.x * 0.5,
		"right": t.origin.x + size.x * 0.5,
		"top": t.origin.y - size.y * 0.5,
		"one_way": shape_node.one_way_collision,
	})

## (x, feet_y) 바로 아래(또는 그 높이)에 있는 가장 높은 발판
func _support_under(x: float, feet_y: float, margin: float = 4.0):
	var best = null
	for p in _platforms:
		if x < p.left - margin or x > p.right + margin or p.top < feet_y - 8.0:
			continue
		if best == null or p.top < best.top:
			best = p
	return best

## a 발판에서 b 발판으로 1단 점프 한 번(또는 걸어 내려가기)으로 갈 수 있는지.
## 가로 한계는 걷는 속도가 느린 만큼(캐릭터 425 기준 110px) 줄여서 본다
func _can_reach(a: Dictionary, b: Dictionary) -> bool:
	if a.id == b.id:
		return false
	var up: float = a.top - b.top
	var gap: float = maxf(0.0, maxf(b.left - a.right, a.left - b.right))
	var reach: float = 110.0 * _walk_speed() / 425.0
	if up > 4.0:
		var jump_h: float = Fighter.jump_velocity * Fighter.jump_velocity / (2.0 * Fighter.gravity)
		if up > jump_h - 14.0 or not b.one_way:
			return false
		return gap <= reach
	return gap <= reach + (-up) * 0.3

## start에서 goal까지 가장 적게 갈아타는 길의 **다음 발판**(없으면 null) — 너비 우선 탐색
func _plan_next(start: Dictionary, goal: Dictionary):
	var n: int = _platforms.size()
	var prev: Array = []
	prev.resize(n)
	prev.fill(-2)
	var s: int = -1
	var g: int = -1
	for i in n:
		if _platforms[i].id == start.id:
			s = i
		if _platforms[i].id == goal.id:
			g = i
	if s < 0 or g < 0:
		return null
	prev[s] = -1
	var queue: Array = [s]
	while not queue.is_empty():
		var u: int = queue.pop_front()
		if u == g:
			break
		for v in n:
			if prev[v] != -2 or not _can_reach(_platforms[u], _platforms[v]):
				continue
			prev[v] = u
			queue.append(v)
	if prev[g] == -2:
		return null
	var cur: int = g
	while prev[cur] != s:
		cur = prev[cur]
		if cur < 0:
			return null
	return _platforms[cur]

# ---------------------------------------------------------------- 몸

func _walk_speed() -> float:
	var base: float = base_stats.move_speed if base_stats else 411.75
	if _speed_ref != null and is_instance_valid(_speed_ref) and _speed_ref.stats:
		base = _speed_ref.stats.move_speed
	return base * speed_ratio

func _walk(dir: float) -> void:
	velocity.x = dir * _walk_speed()
	if dir != 0.0:
		_set_facing(dir)

## 좌우 반전은 리그의 scale.x 부호로만
func _set_facing(dir: float) -> void:
	if dir == 0.0:
		return
	_facing = signf(dir)
	if _visual:
		_visual.scale.x = absf(_visual.scale.x) * _facing

## 리그는 부모 Fighter의 속도를 보는데 엄마는 Fighter가 아니라 `manual_speed_ratio`로 직접 넣는다
func _update_walk_pose() -> void:
	if _visual == null or not ("manual_speed_ratio" in _visual):
		return
	var ratio: float = 0.0
	if is_on_floor():
		ratio = clampf(absf(velocity.x) / maxf(_walk_speed(), 1.0), 0.0, 1.0)
	_visual.manual_speed_ratio = ratio

## 캐릭터와 몸 충돌을 끈다(양쪽 다) — 늦게 생긴 캐릭터도 걸리도록 매 프레임 훑되 이미 건 상대는 건너뛴다
func _ignore_fighter_bodies() -> void:
	for f in get_tree().get_nodes_in_group("fighters"):
		if not (f is PhysicsBody2D) or not is_instance_valid(f):
			continue
		var id: int = f.get_instance_id()
		if _ignored.has(id):
			continue
		_ignored[id] = true
		add_collision_exception_with(f)
		f.add_collision_exception_with(self)

## 눈빛 노드를 리그 머리에 붙인다(평소엔 안 보이고 암전이 시작되면 켜진다)
func _attach_eye_glow() -> void:
	var head: Node = _visual.get_node_or_null("Head") if _visual else null
	if head == null:
		return
	var glow: Node2D = EYE_GLOW.new()
	glow.name = "EyeGlow"
	head.add_child(glow)
