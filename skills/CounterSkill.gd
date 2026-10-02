class_name CounterSkill
extends Skill

## 카운터 — 누르면 stance_duration 동안 단소를 겨누고 기다린다(지하철 아저씨 스킬2).
## 그 사이 상대의 공격(평타·스킬·투사체 전부, 맵 기믹 제외)에 맞으면 피해 없이 반격한다(2026-09-30 사용자 결정):
##   맞는 순간 시간이 느려지고(slow_scale 배속, slow_time 실제 초) 화면 전체가 살짝 어두워진다 ->
##   상대 등 뒤로 순간이동 -> 어둠 속에서 선글라스만 번쩍(`CounterFlash.gd`) -> 3타 베기 모션으로 후려침 ->
##   시간이 돌아오며 상대는 **평타 3타처럼 날아간다**(`Fighter.launch_finisher` + 날아가는 이펙트, 값은 이 캐릭터 평타의 finisher_* 그대로).
## 아무것도 안 맞으면 헛방 — whiff_lag 동안 굳는다(카운터를 아무 때나 켜 두지 못하게).
##
## 가로채는 곳은 두 군데다: `Hurtbox.take_hit()`(판정이 때린 경우 — 데미지 숫자·스파크가 안 뜨고 상대 공격은 헛친 것으로 처리)
## 와 `Fighter.take_damage()`(판정 없이 직접 피해를 주는 스킬 — 자전거 돌진·어깨치기 등). 둘 다 `Fighter.try_counter()`를 부른다.
## 자세 중엔 잡기(유선 마우스·백 서플렉스)에 안 잡힌다(`Fighter.can_be_grabbed()`)

## 카운터 자세를 유지하는 시간(초) — 이 안에 맞아야 반격이 나간다
@export var stance_duration: float = 0.6
## 헛방이면 자세가 끝난 뒤 이만큼 더 굳는다(초)
@export var whiff_lag: float = 0.35
## 상대 등 뒤 어디에 나타날지 — 상대 몸 중심에서 떨어진 거리(px)
@export var behind_distance: float = 48.0
## 반격 데미지(공격력 배율이 곱해진다)
@export var counter_damage: int = 20
## 반격 판정이 켜져 있는 시간(초)
@export var active_duration: float = 0.12
## 반격 판정 위치 — 캐릭터 앞쪽 거리(px)
@export var strike_range: float = 40.0
## 반격이 나가는 동안 무적(초, 게임 시간) — 순간이동 직후 상대의 다음 공격에 바로 맞으면 반격이 무의미하다
@export var counter_invincible: float = 0.6
## 반격 때 재생할 리그 공격 모션 번호(0=1타, 2=3타 베기)
@export var counter_swing_variant: int = 2
## 그 모션에서 후려치는 순간까지 걸리는 시간(초, 게임 시간) — 리그 attack_duration 0.4 x 0.4
@export var swing_strike_time: float = 0.16
## 자세 중 몸 색
@export var stance_tint: Color = Color(0.75, 0.9, 1.0)

@export_group("연출")
## 반격하는 동안의 시간 배속(0.3 = 0.3배로 느리게)
@export var slow_scale: float = 0.3
## 맞은 순간부터 후려칠 때까지(실제 초) — 이 동안 느리고 어둡다
@export var slow_time: float = 0.8

const COUNTER_FLASH := preload("res://skills/CounterFlash.gd")
## 날아가는 이펙트 — ComboMeleeAttack 마무리 타와 같은 것
const LAUNCH_TRAIL := preload("res://combat/LaunchTrail.gd")

@onready var hitbox: Hitbox = $Hitbox

var _fighter: Fighter = null
var _in_stance: bool = false
## 자세를 켤 때마다 1씩 올린다 — 앞 자세의 종료 예약이 새 자세를 끄지 않게
var _stance_id: int = 0
## 반격 판정이 켜져 있는 동안만 true — 명중 시 날리기를 이때만 한다
var _striking: bool = false
## 내가 시간을 느리게 했는지, 그 전 배속은 얼마였는지 — 되돌릴 때 다른 연출(KO 슬로우)을 덮지 않게
var _slowed: bool = false
var _prev_time_scale: float = 1.0
## 타입을 안 붙인다 — CounterFlash는 class_name이 없어 Node로 받으면 release()를 못 찾는다
var _flash = null
## 반격이 맞기 전까지 두 사람을 묶어 둘 자리 {Fighter: Vector2} — 비어 있으면 안 묶는다(필중, 2026-10-02 사용자 요청)
var _lock_positions: Dictionary = {}
var _lock_opponent: Fighter = null

func _ready() -> void:
	super()
	hitbox.connected.connect(_on_hitbox_connected)

## 묶인 동안 매 물리 프레임 두 사람을 제자리에 세우고 이동·점프·공격·방어를 막는다
func _physics_process(_delta: float) -> void:
	if _lock_positions.is_empty():
		return
	for f in _lock_positions:
		if not is_instance_valid(f):
			continue
		f.global_position = _lock_positions[f]
		f.velocity = Vector2.ZERO
		f.start_busy(0.1)
	if is_instance_valid(_lock_opponent):
		_lock_opponent.apply_hitstun(0.1)
		if _lock_opponent.is_guarding:
			_lock_opponent.cancel_guard(true)

func _lock(fighter: Fighter, opponent: Fighter) -> void:
	_lock_opponent = opponent
	_lock_positions = {fighter: fighter.global_position, opponent: opponent.global_position}

func _unlock() -> void:
	_lock_positions.clear()
	_lock_opponent = null

func _execute(fighter: Fighter) -> void:
	_fighter = fighter
	_in_stance = true
	_stance_id += 1
	var my_id: int = _stance_id
	fighter.counter_stance = self
	fighter.movement_override = self
	fighter.velocity.x = 0.0
	fighter.start_busy(stance_duration + whiff_lag)
	fighter.set_tint("counter_stance", stance_tint)
	_set_rig_stance(true)
	Timers.after(self, stance_duration, func(): _on_stance_timeout(my_id))

## `Fighter.movement_override` 인터페이스 — 자세 중엔 제자리에 선다
func get_move_velocity_x() -> float:
	return 0.0

func after_physics(_f: Fighter, _delta: float) -> void:
	pass

## 헛방 — 자세만 풀고 잠금(start_busy)은 whiff_lag만큼 남는다
func _on_stance_timeout(id: int) -> void:
	if id != _stance_id or not _in_stance:
		return
	_end_stance()

func _end_stance() -> void:
	_in_stance = false
	if not is_instance_valid(_fighter):
		return
	if _fighter.counter_stance == self:
		_fighter.counter_stance = null
	if _fighter.movement_override == self:
		_fighter.movement_override = null
	_fighter.clear_tint("counter_stance")
	_set_rig_stance(false)

## `Fighter.try_counter()`가 부른다 — 맞는 순간 피해 대신 반격을 시작한다
func trigger_counter(fighter: Fighter) -> void:
	if not _in_stance:
		return
	_end_stance()
	fighter.end_busy()
	fighter.grant_invincibility(counter_invincible)
	var opponent: Fighter = fighter.find_opponent()
	if opponent == null or not is_instance_valid(opponent):
		return
	# 상대를 연출 동안 그 자리에 묶는다 — 느려진 동안 빠져나가면 후려치기가 허공을 친다
	opponent.cancel_finisher_flight()
	opponent.cancel_guard(true)
	opponent.velocity = Vector2.ZERO
	opponent.apply_hitstun(slow_time * slow_scale + 0.1)
	_start_slow()
	_teleport_behind(fighter, opponent)
	# 반격이 맞을 때까지 둘 다 그 자리에 묶는다 — 상대가 빠져나가거나 막아서 헛치는 일이 없게(필중)
	_lock(fighter, opponent)
	fighter.start_busy(slow_time * slow_scale + active_duration + 0.1)
	_spawn_flash(fighter)
	# 모션의 후려치는 순간이 slow_time에 오도록 거꾸로 계산해 휘두르기 시작 시각을 정한다(느려진 만큼 모션도 길다)
	var swing_at: float = maxf(slow_time - _swing_strike_time(fighter) / maxf(slow_scale, 0.01), 0.0)
	Timers.after(self, swing_at, func(): _play_swing(fighter), true)
	Timers.after(self, slow_time, func(): _strike(fighter), true)

## 상대가 바라보는 반대쪽(등 뒤)으로 옮긴다. 그쪽이 벽이면 벽 앞에서 멈춘다
func _teleport_behind(fighter: Fighter, opponent: Fighter) -> void:
	if fighter.has_method("_spawn_dash_afterimage"):
		fighter._spawn_dash_afterimage()
	var back: float = -opponent.facing if not is_zero_approx(opponent.facing) else signf(fighter.global_position.x - opponent.global_position.x)
	var from: Vector2 = opponent.global_position
	var target: Vector2 = from + Vector2(back * behind_distance, 0.0)
	var hit: Dictionary = PhysicsQuery.raycast_ignoring_fighters(fighter, from, target + Vector2(back * 20.0, 0.0))
	if not hit.is_empty():
		# 벽에 파묻히지 않게 몸 반폭(20)만큼 떨어진 자리
		target.x = hit.position.x - back * 20.0
	fighter.global_position = target
	fighter.velocity = Vector2.ZERO
	fighter.facing = -back

## 반격 모션에서 후려치는 순간까지(게임 시간) — 그 타가 리그의 회전 타격(spin_hit_index)이면 리그가 계산한 값,
## 아니면 swing_strike_time. 지하철 3타는 2026-09-30부터 한 바퀴 돌며 벤다(0.5초 x 0.62 x 0.72 ≈ 0.223)
func _swing_strike_time(fighter: Fighter) -> float:
	var visual := fighter.get_node_or_null("Visual")
	if visual and visual.has_method("strike_time") and int(visual.get("spin_hit_index")) == counter_swing_variant:
		return visual.strike_time(float(visual.get("spin_duration")), true)
	return swing_strike_time

func _play_swing(fighter: Fighter) -> void:
	if not is_instance_valid(fighter):
		return
	var visual := fighter.get_node_or_null("Visual")
	if visual and visual.has_method("play_attack_swing"):
		visual.play_attack_swing(counter_swing_variant)

func _strike(fighter: Fighter) -> void:
	_end_slow()
	if _flash != null and is_instance_valid(_flash):
		_flash.release()
	_flash = null
	if not is_instance_valid(fighter):
		_unlock()
		return
	# 필중 — 무적(대시 등)이 걸려 있어도 이 한 방은 들어간다
	if is_instance_valid(_lock_opponent):
		_lock_opponent.is_invincible = false
	hitbox.damage = fighter.compute_damage(counter_damage)
	# 피격 반응(움찔·콤보 수)용 넉백 — 실제 날아가는 속도는 명중 뒤 launch_finisher가 덮어쓴다
	hitbox.knockback = Vector2(220.0 * fighter.facing, -90.0)
	hitbox.source_fighter = fighter
	# Skill은 Node라 좌표가 없다 — 판정은 global_position으로 직접 놓는다
	hitbox.global_position = fighter.global_position + Vector2(strike_range * fighter.facing, 0)
	_striking = true
	hitbox.monitoring = true
	hitbox.monitorable = true
	Timers.after(self, active_duration, _disable_hitbox)

func _disable_hitbox() -> void:
	# 판정이 켜진 동안 겹침 신호가 안 왔으면(묶인 자리가 판정과 어긋난 경우) 상대 허트박스를 직접 때린다
	if _striking and is_instance_valid(_lock_opponent):
		var hurt := _lock_opponent.get_node_or_null("Hurtbox") as Hurtbox
		if hurt:
			hitbox._try_hit(hurt)
	_unlock()
	_striking = false
	hitbox.monitoring = false
	hitbox.monitorable = false

## 맞았으면 평타 3타처럼 날린다 — 값은 이 캐릭터 평타(ComboMeleeAttack)의 finisher_* 를 그대로 빌린다
func _on_hitbox_connected(victim: Node) -> void:
	if not _striking:
		return
	_striking = false
	_unlock()
	if not (victim is Fighter) or not is_instance_valid(victim) or not is_instance_valid(_fighter):
		return
	var target: Fighter = victim
	# 막혔으면 날아가지 않는다 (ComboMeleeAttack._launch_finisher와 같은 규칙)
	if target.is_guarding:
		return
	var dir: float = signf(_fighter.facing) if not is_zero_approx(_fighter.facing) else 1.0
	var ba: Node = _fighter.basic_attack
	var speed: float = _finisher_value(ba, "finisher_launch_speed", 535.0)
	var pop: float = _finisher_value(ba, "finisher_launch_pop", 220.0)
	var stun: float = _finisher_value(ba, "finisher_launch_stun", 0.4)
	var turns: float = _finisher_value(ba, "finisher_tumble_turns", 1.0)
	var max_scale: float = _finisher_value(ba, "finisher_max_scale", 2.0)
	var parent: Node = target.get_parent()
	if parent != null:
		var trail = LAUNCH_TRAIL.new()
		parent.add_child(trail)
		trail.setup(target, Vector2(dir, -0.35))
	target.launch_finisher(dir, speed, pop, stun, turns, max_scale)

func _finisher_value(ba: Node, key: String, fallback: float) -> float:
	if ba == null:
		return fallback
	var v = ba.get(key)
	return float(v) if v != null else fallback

func _start_slow() -> void:
	# 이미 다른 연출(KO 슬로우·히트스톱)로 느린 중이면 건드리지 않는다
	if _slowed or Engine.time_scale < 0.5:
		return
	_prev_time_scale = Engine.time_scale
	Engine.time_scale = slow_scale
	_slowed = true

func _end_slow() -> void:
	if not _slowed:
		return
	_slowed = false
	# 그 사이 다른 연출이 배속을 바꿨으면 그쪽을 존중한다
	if is_equal_approx(Engine.time_scale, slow_scale):
		Engine.time_scale = _prev_time_scale

func _spawn_flash(fighter: Fighter) -> void:
	var parent: Node = fighter.get_parent()
	if parent == null:
		return
	var flash = COUNTER_FLASH.new()
	parent.add_child(flash)
	flash.setup(_lens_node(fighter))
	_flash = flash

## 선글라스 자리 — 리그 머리의 렌즈 반짝임 노드(LensGlint), 없으면 머리, 그것도 없으면 몸
func _lens_node(fighter: Fighter) -> Node2D:
	var lens := fighter.get_node_or_null("Visual/Head/LensGlint") as Node2D
	if lens:
		return lens
	var head := fighter.get_node_or_null("Visual/Head") as Node2D
	return head if head else fighter

## 자세 그림 — 리그의 카운터 자세(단소 앞 아래 겨누기 + 한 손 얼굴 옆 + 앞으로 숙임, BodyRig.counter_*)
func _set_rig_stance(on: bool) -> void:
	if not is_instance_valid(_fighter):
		return
	var visual := _fighter.get_node_or_null("Visual")
	if visual and visual.has_method("set_counter_stance"):
		visual.set_counter_stance(on)

func _exit_tree() -> void:
	# 연출 도중 라운드가 바뀌거나 나가도 게임이 느린 채로 남지 않게
	_end_slow()
	_unlock()
	if _in_stance:
		_end_stance()
