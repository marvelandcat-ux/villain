class_name DropkickSkill
extends Skill

## 드롭킥 — 황근출 스킬1(G). 무릎을 꿇고 준비(`windup_time`, 슈퍼아머) → 바라보는 쪽으로 두 발을 모아 날아간다.
## 맞히면 상대가 평타 3타처럼 날아가는데 첫 포물선만 더 빠르고·높고·오래(`launch_*_mult`, `Fighter.launch_finisher`의 shape).
## 헛치면 착지한 뒤 `miss_stun`초 동안 넘어져 못 움직인다.
##
## 캐릭터끼리 몸 충돌이 꺼져 있어 판정은 `ShoulderChargeSkill`처럼 **몸 사이 거리**로 본다

## 무릎 꿇고 버티는 준비 시간(초) — 이동안 슈퍼아머(데미지는 받고 밀리지 않는다)
@export var windup_time: float = 0.5
@export var damage: int = 1
## 날아가는 가로 거리(px) — 속도는 `lift`로 정해지는 체공 시간에서 역산한다
@export var travel_distance: float = 300.0
## 뛰어오르는 속도(px/초). 중력 1150에서 320이면 체공 약 0.56초
@export var lift: float = 320.0
## 헛쳤을 때 착지 후 못 움직이는 시간(초)
@export var miss_stun: float = 1.0
## 맞혔을 때 착지 후 일어나는 시간(초) — 넘어졌다 일어나는 그림이 보일 만큼만
@export var hit_getup: float = 0.25
## 맞았다고 볼 몸 사이 거리(px)
@export var hit_range_x: float = 50.0
@export var hit_range_y: float = 46.0
## 상대가 날아가는 첫 포물선 — 평타 3타 대비 옆 속도 / 최고 높이 / 체공 시간 배수
@export var launch_speed_mult: float = 2.0
@export var launch_peak_mult: float = 2.0
@export var launch_airtime_mult: float = 5.0
## 어딘가 걸려 안 떨어질 때를 위한 공중 시간 안전 한도(초)
@export var max_air_time: float = 2.0

const LAUNCH_TRAIL := preload("res://combat/LaunchTrail.gd")
## 뛰어오른 직후 이만큼(초)은 바닥 판정을 안 본다 — 그 프레임엔 아직 발이 땅에 붙어 있다
const GROUND_GRACE := 0.08

enum State { IDLE, WINDUP, AIR, GETUP }

var _state: State = State.IDLE
var _fighter: Fighter = null
var _has_fighter: bool = false
var _dir: float = 1.0
var _speed: float = 0.0
var _time: float = 0.0
var _air_time: float = 0.0
var _hit: bool = false
var _armored: bool = false

func _execute(fighter: Fighter) -> void:
	_fighter = fighter
	_has_fighter = true
	_dir = signf(fighter.facing) if not is_zero_approx(fighter.facing) else 1.0
	_state = State.WINDUP
	_time = windup_time
	_hit = false
	fighter.velocity.x = 0.0
	fighter.movement_override = self
	# 끝나는 시점이 착지에 달려 있어 넉넉히 걸고, 끝날 때 end_busy()로 푼다
	fighter.start_busy(windup_time + max_air_time + miss_stun + 0.5)
	fighter.add_super_armor()
	_armored = true
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("set_kneeling"):
		visual.set_kneeling(true)

## Fighter.apply_physics가 이동 속도를 물어볼 때 — 날아가는 동안만 앞으로, 나머지는 제자리
func get_move_velocity_x() -> float:
	return _dir * _speed if _state == State.AIR else 0.0

## move_and_slide 직후 매 프레임 호출된다 (movement_override로 등록돼 있는 동안만)
func after_physics(fighter: Fighter, delta: float) -> void:
	# Fighter.move()는 못 움직일 때도 facing을 바꾸므로 매 프레임 되돌린다
	fighter.facing = _dir
	match _state:
		State.WINDUP:
			_time -= delta
			if _time <= 0.0:
				_leap(fighter)
		State.AIR:
			# 날아가는 도중에 맞으면 끊는다 — 안 끊으면 넉백을 이 속도가 덮어쓴다
			if fighter.is_in_hitstun():
				_finish()
				return
			_air_time += delta
			if not _hit:
				var enemy: Fighter = Fighter.find_fighter_in_box(fighter, hit_range_x, hit_range_y, _dir)
				if enemy != null:
					_strike(fighter, enemy)
			if (_air_time > GROUND_GRACE and fighter.is_on_floor()) or _air_time >= max_air_time:
				_land(fighter)
		State.GETUP:
			_time -= delta
			if _time <= 0.0:
				_finish()

## 준비가 끝났다 — 슈퍼아머를 풀고 앞으로 뛰어오른다
func _leap(fighter: Fighter) -> void:
	_release_armor()
	_state = State.AIR
	_air_time = 0.0
	var air: float = 2.0 * lift / maxf(Fighter.gravity, 1.0)
	_speed = travel_distance / maxf(air, 0.01)
	fighter.velocity.y = -lift
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual:
		if visual.has_method("set_kneeling"):
			visual.set_kneeling(false)
		if visual.has_method("play_dropkick"):
			visual.play_dropkick()

## 두 발이 닿았다 — 데미지를 주고, 막히지 않았으면 3타처럼(더 멀리) 날려 보낸다
func _strike(fighter: Fighter, enemy: Fighter) -> void:
	_hit = true
	# 카운터 자세에 걸리면 이번 피해는 없던 일이 되고 반격이 시작된다 — 그땐 날리지 않는다
	var countered: bool = enemy.counter_stance != null and is_instance_valid(enemy.counter_stance)
	enemy.take_damage(fighter.compute_damage(damage), Vector2(_dir * 200.0, 0.0), 0.0)
	var parent: Node = fighter.get_parent()
	if parent:
		CrashBurst.spawn(parent, fighter.global_position + Vector2(_dir * 30.0, 0.0))
	if countered or enemy.is_guarding or enemy.is_invincible:
		return
	var ba: Node = fighter.basic_attack
	var shape: Dictionary = {"speed": launch_speed_mult, "peak": launch_peak_mult, "airtime": launch_airtime_mult}
	var enemy_parent: Node = enemy.get_parent()
	if enemy_parent:
		var trail = LAUNCH_TRAIL.new()
		enemy_parent.add_child(trail)
		trail.setup(enemy, Vector2(_dir, -0.3))
	enemy.launch_finisher(_dir, _ba_value(ba, "finisher_launch_speed", 535.0), _ba_value(ba, "finisher_launch_pop", 220.0),
		_ba_value(ba, "finisher_launch_stun", 0.4), _ba_value(ba, "finisher_tumble_turns", 1.0),
		_ba_value(ba, "finisher_max_scale", 2.0), shape)
	var cam: Node = get_tree().get_first_node_in_group("game_camera")
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.4)

func _ba_value(ba: Node, key: String, fallback: float) -> float:
	if ba == null:
		return fallback
	var v = ba.get(key)
	return float(v) if v != null else fallback

## 땅에 닿았다 — 넘어진 자세로 바꾸고, 헛쳤으면 오래(miss_stun) 맞혔으면 짧게(hit_getup) 못 움직인다
func _land(fighter: Fighter) -> void:
	_state = State.GETUP
	_time = hit_getup if _hit else miss_stun
	fighter.velocity.x = 0.0
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("dropkick_land"):
		visual.dropkick_land(_time)

## 끝내고 이동 권한·행동 잠금·자세·슈퍼아머를 되돌린다
func _finish() -> void:
	_state = State.IDLE
	_speed = 0.0
	_release_armor()
	if not _has_fighter or not is_instance_valid(_fighter):
		return
	if _fighter.movement_override == self:
		_fighter.movement_override = null
	_fighter.end_busy()
	var visual: Node = _fighter.get_node_or_null("Visual")
	if visual:
		if visual.has_method("set_kneeling"):
			visual.set_kneeling(false)
		if visual.has_method("dropkick_end"):
			visual.dropkick_end()

## 슈퍼아머는 개수로 세므로 add/remove를 꼭 한 번씩 짝 맞춘다
func _release_armor() -> void:
	if not _armored:
		return
	_armored = false
	if _has_fighter and is_instance_valid(_fighter):
		_fighter.remove_super_armor()

func _physics_process(_delta: float) -> void:
	# 다른 스킬이 이동 권한을 가져갔으면(after_physics가 더는 안 불림) 여기서 정리한다 — 슈퍼아머가 남지 않게
	if _state != State.IDLE and (not is_instance_valid(_fighter) or _fighter.movement_override != self):
		_finish()

func _exit_tree() -> void:
	_release_armor()
