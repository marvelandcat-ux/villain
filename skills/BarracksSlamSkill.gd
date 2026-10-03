class_name BarracksSlamSkill
extends Skill

## 내무반 전용 스킬2(H) — 황근출 궁 `BarracksUltimate`가 내무반에 있는 동안만 스킬2 자리에 끼운다(평소엔 짜장면 먹기).
## 순간이동처럼 앞으로 돌진(잔상·바람) → 닿으면 두 손으로 상대를 번쩍 들어 곧장 위로 띄우고(기절) →
## 상대 위로 순간이동해 다리로 내려찍는다 → 상대는 땅에 꽂혔다가 드롭킥보다 2배 멀리·높이·오래 앞으로 튕겨 날아간다.
## 방어는 무시하고 잡는다(`cancel_guard`). 무적이면 그냥 지나가고, 카운터 자세면 카운터가 이긴다. 헛치면 경직 없이 끝
##
## 돌진이 빨라서 한 프레임에 수십 px를 가므로 맞음 판정은 "이번 프레임에 지나간 구간"으로 본다

## 돌진 거리(px)와 걸리는 시간(초) — 짧을수록 순간이동처럼 보인다
@export var dash_distance: float = 500.0
@export var dash_time: float = 0.14
## 돌진이 상대를 잡는 앞쪽 거리 / 위아래 허용 거리(px)
@export var hit_range_x: float = 40.0
@export var hit_range_y: float = 46.0
## 돌진 중 잔상 남기는 간격(초)
@export var ghost_interval: float = 0.016
## 들어 올리기 피해
@export var lift_damage: int = 8
## 상대를 곧장 위로 띄우는 높이(px)와 걸리는 시간(초)
@export var lift_height: float = 250.0
@export var lift_time: float = 0.35
## 띄운 뒤 순간이동까지(초)
@export var blink_delay: float = 0.05
## 상대 위 몇 px에 나타나는지 / 나타나서 잠깐 떠 있는 시간(초) / 내려찍는 속도(px/초)
@export var stomp_height: float = 100.0
@export var stomp_hang: float = 0.08
@export var stomp_speed: float = 1600.0
## 발이 상대에 닿았다고 볼 몸 중심 사이 높이(px)
@export var stomp_contact_gap: float = 70.0
## 내려찍기 피해
@export var stomp_damage: int = 22
## 상대가 땅으로 꽂히는 속도(px/초)
@export var slam_speed: float = 1800.0
## 튕겨 날아가는 첫 포물선 — 평타 3타 대비 배수. 드롭킥(옆 2 / 높이 2 / 체공 5)에서 높이·체공을 2배로 해
## 거리·높이·기절 시간이 모두 2배가 되게 했다(옆 속도는 같아도 2배 오래 날아서 거리가 2배)
@export var launch_speed_mult: float = 2.0
@export var launch_peak_mult: float = 4.0
@export var launch_airtime_mult: float = 10.0
## 기절 기본 시간 배수(평타 3타 기준 값에 곱함)
@export var launch_stun_mult: float = 2.0
## 어딘가 걸렸을 때를 위한 안전 한도(초)
@export var max_time: float = 3.0
## 화면 전체 슬로모션(게임 속도 배율) — 들어 올리는 동안 / 내려찍은 뒤 상대가 땅에 꽂힐 때까지
@export var lift_time_scale: float = 0.45
@export var stomp_time_scale: float = 0.25

const LAUNCH_TRAIL := preload("res://combat/LaunchTrail.gd")
const CHARGE_WIND := preload("res://skills/ChargeWind.gd")
const JUMP_WIND := preload("res://combat/JumpWind.gd")
## 내려찍은 뒤 이만큼(초)은 바닥 판정을 안 본다
const GROUND_GRACE := 0.05

enum State { IDLE, DASH, LIFT, HANG, STOMP, FALL }

var _state: State = State.IDLE
var _fighter: Fighter = null
var _has_fighter: bool = false
var _enemy: Fighter = null
var _holding: bool = false
var _slamming: bool = false
var _dir: float = 1.0
var _time: float = 0.0
var _total: float = 0.0
var _ghost_timer: float = 0.0
var _prev_x: float = 0.0
var _lift_from: Vector2 = Vector2.ZERO
var _hover: Vector2 = Vector2.ZERO
var _wind = null
var _slam_time: float = 0.0
## 이 스킬이 Engine.time_scale을 바꿔 놓았는지 — 되돌릴 때 남의 슬로(카운터 등)를 건드리지 않게
var _slowed: bool = false

func _execute(fighter: Fighter) -> void:
	_fighter = fighter
	_has_fighter = true
	_enemy = null
	_holding = false
	_slamming = false
	_dir = signf(fighter.facing) if not is_zero_approx(fighter.facing) else 1.0
	_state = State.DASH
	_time = 0.0
	_total = 0.0
	_ghost_timer = 0.0
	_prev_x = fighter.global_position.x
	fighter.movement_override = self
	fighter.start_busy(max_time)
	_spawn_wind(fighter.global_position + Vector2(-_dir * 20.0, 22.0), Vector2(_dir, 0.0))
	var parent: Node = fighter.get_parent()
	if parent:
		_wind = CHARGE_WIND.new()
		parent.add_child(_wind)
		_wind.setup(fighter, _dir, dash_time)

## Fighter.apply_physics가 이동 속도를 물어볼 때 — 돌진 동안만 앞으로
func get_move_velocity_x() -> float:
	return _dir * dash_distance / maxf(dash_time, 0.01) if _state == State.DASH else 0.0

## move_and_slide 직후 매 프레임 호출된다 (movement_override로 등록돼 있는 동안만)
func after_physics(fighter: Fighter, delta: float) -> void:
	fighter.facing = _dir
	_total += delta
	if _total >= max_time:
		_finish()
		return
	# 띄우기 전까지 맞으면 끊는다(잡고 있던 상대는 놓아 준다)
	if fighter.is_in_hitstun() and _state != State.FALL:
		_finish()
		return
	match _state:
		State.DASH:
			_update_dash(fighter, delta)
		State.LIFT:
			_time += delta
			var t: float = clampf(_time / maxf(lift_time, 0.01), 0.0, 1.0)
			var rise: float = 1.0 - (1.0 - t) * (1.0 - t)
			_hold_enemy_at(_lift_from + Vector2(0.0, -lift_height * rise))
			_hold_self(fighter, fighter.global_position)
			if _time >= lift_time + blink_delay:
				_blink(fighter)
		State.HANG:
			_time += delta
			_hold_enemy_at(_lift_from + Vector2(0.0, -lift_height))
			_hold_self(fighter, _hover)
			if _time >= stomp_hang:
				_state = State.STOMP
		State.STOMP:
			_hold_enemy_at(_lift_from + Vector2(0.0, -lift_height))
			fighter.velocity = Vector2(0.0, stomp_speed)
			if not _enemy_valid() or fighter.global_position.y >= _enemy.global_position.y - stomp_contact_gap:
				_stomp(fighter)
		State.FALL:
			_time += delta
			if (_time > GROUND_GRACE and fighter.is_on_floor()):
				_finish()

## 돌진 — 이번 프레임에 지나간 구간 안에 상대가 있으면 잡는다. 벽에 막히거나 다 가면 헛방(경직 없음)
func _update_dash(fighter: Fighter, delta: float) -> void:
	_time += delta
	_ghost_timer -= delta
	if _ghost_timer <= 0.0:
		_ghost_timer = ghost_interval
		_spawn_ghost(fighter, 0.5, 0.22)
	var enemy: Fighter = _enemy_in_path(fighter)
	_prev_x = fighter.global_position.x
	if enemy != null:
		_grab(fighter, enemy)
		return
	if _time >= dash_time or fighter.is_on_wall():
		_finish()

func _enemy_in_path(fighter: Fighter) -> Fighter:
	var lo: float = minf(_prev_x, fighter.global_position.x + _dir * hit_range_x)
	var hi: float = maxf(_prev_x, fighter.global_position.x + _dir * hit_range_x)
	for n in get_tree().get_nodes_in_group("fighters"):
		var f := n as Fighter
		if f == null or f == fighter or f.current_hp <= 0:
			continue
		if f.global_position.x < lo or f.global_position.x > hi:
			continue
		if absf(f.global_position.y - fighter.global_position.y) > hit_range_y:
			continue
		return f
	return null

## 닿았다 — 방어는 풀어 버리고, 두 손으로 번쩍 들어 곧장 위로 띄운다
func _grab(fighter: Fighter, enemy: Fighter) -> void:
	_stop_wind()
	fighter.velocity = Vector2.ZERO
	# 무적이면 그냥 지나간 셈 — 잡지 않고 끝낸다
	if enemy.is_invincible:
		_finish()
		return
	# 카운터 자세면 카운터가 이긴다 — 넉백 있는 피해를 넣어 반격을 일으키고 이 스킬은 끝
	if enemy.counter_stance != null and is_instance_valid(enemy.counter_stance):
		enemy.take_damage(fighter.compute_damage(lift_damage), Vector2(_dir * 200.0, 0.0), 0.0)
		_finish()
		return
	enemy.cancel_finisher_flight()
	enemy.cancel_guard()
	enemy.take_damage(fighter.compute_damage(lift_damage), Vector2.ZERO, 0.0)
	if not is_instance_valid(enemy) or enemy.current_hp <= 0:
		_finish()
		return
	_enemy = enemy
	_holding = true
	enemy.is_grabbed = true
	enemy.velocity = Vector2.ZERO
	# 상대를 손 앞에 세워 두고 거기서부터 위로
	_lift_from = Vector2(fighter.global_position.x + _dir * hit_range_x, fighter.global_position.y)
	_hold_enemy_at(_lift_from)
	StunStars.spawn(enemy, lift_time + blink_delay + stomp_hang + 0.4)
	_state = State.LIFT
	_time = 0.0
	_set_slow(lift_time_scale)
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("set_lift_pose"):
		visual.set_lift_pose(true)
	var parent: Node = fighter.get_parent()
	if parent:
		CrashBurst.spawn(parent, _lift_from + Vector2(0.0, -10.0))
	_shake(0.3)

## 상대 위로 순간이동 — 떠난 자리에 잔상, 나타난 자리에 아래로 뻗는 바람
func _blink(fighter: Fighter) -> void:
	_clear_slow()
	_spawn_ghost(fighter, 0.6, 0.3)
	_hover = _lift_from + Vector2(0.0, -lift_height - stomp_height)
	_hold_self(fighter, _hover)
	_spawn_wind(_hover + Vector2(0.0, -20.0), Vector2.DOWN)
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual:
		if visual.has_method("set_lift_pose"):
			visual.set_lift_pose(false)
		if visual.has_method("set_stomp_pose"):
			visual.set_stomp_pose(true)
	_state = State.HANG
	_time = 0.0

## 발이 닿았다 — 피해를 주고 상대를 땅으로 꽂는다(땅에 닿는 순간 _launch가 앞으로 튕겨 보낸다)
func _stomp(fighter: Fighter) -> void:
	_state = State.FALL
	_time = 0.0
	fighter.velocity = Vector2(0.0, 200.0)
	_spawn_wind(fighter.global_position + Vector2(0.0, -30.0), Vector2.DOWN)
	if not _enemy_valid():
		_release_enemy()
		return
	var enemy: Fighter = _enemy
	_release_enemy()
	enemy.take_damage(fighter.compute_damage(stomp_damage), Vector2.ZERO, 0.0)
	if not is_instance_valid(enemy) or enemy.current_hp <= 0:
		return
	enemy.apply_hitstun(1.0)
	enemy.velocity = Vector2(0.0, slam_speed)
	_enemy = enemy
	_slamming = true
	_slam_time = 0.0
	_set_slow(stomp_time_scale)
	var parent: Node = fighter.get_parent()
	if parent:
		CrashBurst.spawn(parent, enemy.global_position + Vector2(0.0, -30.0))
	_shake(0.45)

## 꽂힌 상대가 땅에 닿았다 — 드롭킥의 2배로 앞으로 튕겨 날려 보낸다
func _launch(enemy: Fighter) -> void:
	_slamming = false
	_clear_slow()
	var parent: Node = enemy.get_parent()
	if parent:
		CrashBurst.spawn(parent, enemy.global_position + Vector2(0.0, 26.0))
		var trail = LAUNCH_TRAIL.new()
		parent.add_child(trail)
		trail.setup(enemy, Vector2(_dir, -0.6))
	var ba: Node = _fighter.basic_attack if _has_fighter and is_instance_valid(_fighter) else null
	var shape: Dictionary = {"speed": launch_speed_mult, "peak": launch_peak_mult, "airtime": launch_airtime_mult}
	enemy.launch_finisher(_dir, _ba_value(ba, "finisher_launch_speed", 535.0), _ba_value(ba, "finisher_launch_pop", 220.0),
		_ba_value(ba, "finisher_launch_stun", 0.4) * launch_stun_mult, _ba_value(ba, "finisher_tumble_turns", 1.0),
		_ba_value(ba, "finisher_max_scale", 2.0), shape)
	_shake(0.6)

func _ba_value(ba: Node, key: String, fallback: float) -> float:
	if ba == null:
		return fallback
	var v = ba.get(key)
	return float(v) if v != null else fallback

## 꽂히는 상대가 땅에 닿는지 본다 — 시전자가 먼저 착지해 스킬이 끝나도 계속 봐야 해서 _physics_process에서
func _physics_process(delta: float) -> void:
	if _slamming:
		if not _enemy_valid():
			_slamming = false
			_clear_slow()
		else:
			_slam_time += delta
			if _slam_time > GROUND_GRACE and _enemy.is_on_floor():
				_launch(_enemy)
			elif _slam_time > 1.0:
				_slamming = false
				_clear_slow()
	# 다른 스킬이 이동 권한을 가져갔으면(after_physics가 더는 안 불림) 여기서 정리한다
	if _state != State.IDLE and (not _has_fighter or not is_instance_valid(_fighter) or _fighter.movement_override != self):
		_finish()

## 궁이 끝나 원래 맵으로 돌아갈 때 — 하던 걸 그 자리에서 멈추고 잡은 상대도 놓는다
func abort() -> void:
	_slamming = false
	_clear_slow()
	_finish()

func _hold_enemy_at(pos: Vector2) -> void:
	if _enemy_valid():
		_enemy.global_position = pos
		_enemy.velocity = Vector2.ZERO

func _hold_self(fighter: Fighter, pos: Vector2) -> void:
	fighter.global_position = pos
	fighter.velocity = Vector2.ZERO

func _enemy_valid() -> bool:
	return _enemy != null and is_instance_valid(_enemy)

func _release_enemy() -> void:
	if _holding and _enemy_valid():
		_enemy.is_grabbed = false
	_holding = false

## 끝내고 이동 권한·행동 잠금·자세를 되돌린다
func _finish() -> void:
	_state = State.IDLE
	# 꽂히는 중이면 땅에 닿을 때(_launch)까지 슬로를 둔다
	if not _slamming:
		_clear_slow()
	_release_enemy()
	_stop_wind()
	if not _has_fighter or not is_instance_valid(_fighter):
		return
	if _fighter.movement_override == self:
		_fighter.movement_override = null
	_fighter.end_busy()
	var visual: Node = _fighter.get_node_or_null("Visual")
	if visual:
		if visual.has_method("set_lift_pose"):
			visual.set_lift_pose(false)
		if visual.has_method("set_stomp_pose"):
			visual.set_stomp_pose(false)

func _stop_wind() -> void:
	if _wind != null and is_instance_valid(_wind):
		_wind.stop()
	_wind = null

## 잔상 — Visual을 그 순간 모습 그대로 복제해 맵에 남기고 서서히 지운다(스크립트를 떼야 따라 움직이지 않는다)
func _spawn_ghost(fighter: Fighter, alpha: float, fade: float) -> void:
	var visual: Node2D = fighter.get_node_or_null("Visual")
	var parent: Node = fighter.get_parent()
	if visual == null or parent == null:
		return
	var ghost := visual.duplicate() as Node2D
	if ghost == null:
		return
	ghost.set_script(null)
	parent.add_child(ghost)
	ghost.z_index = -2
	ghost.global_position = visual.global_position
	ghost.scale = visual.scale
	ghost.modulate = Color(1.0, 1.0, 1.0, alpha)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, fade)
	tween.tween_callback(ghost.queue_free)

## 바람 줄기 — 맵에 붙여 제자리에 남긴다(캐릭터 자식이면 좌우 반전에 뒤집힌다)
func _spawn_wind(pos: Vector2, dir: Vector2) -> void:
	if not _has_fighter or not is_instance_valid(_fighter):
		return
	var parent: Node = _fighter.get_parent()
	if parent == null:
		return
	var wind := JUMP_WIND.new()
	parent.add_child(wind)
	wind.global_position = pos
	wind.setup(dir, false)

func _shake(amount: float) -> void:
	var cam: Node = get_tree().get_first_node_in_group("game_camera")
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(amount)

## 화면 전체를 느리게 — 이미 다른 효과가 0.5 밑으로 늦춰 놨으면 건드리지 않는다
func _set_slow(scale: float) -> void:
	if not _slowed and Engine.time_scale < 0.5:
		return
	Engine.time_scale = scale
	_slowed = true

func _clear_slow() -> void:
	if _slowed:
		Engine.time_scale = 1.0
	_slowed = false

func _exit_tree() -> void:
	_release_enemy()
	_clear_slow()
