class_name CatSuitCombo
extends Node

## 고양이 옷(주황 고양이 궁)을 입은 동안 기본공격(`ComboMeleeAttack`)의 **자식으로 붙는 부가 장치**.
## 1·2타 주먹 찌르기는 리그의 맨손 잽(`unarmed_thrust`, 양손 번갈아)이 맡고, 이 노드는 3타만 맡는다:
## 두 손을 앞으로 뻗어 머리를 잡고 — 맞았으면 머리 위로 넘겨 **등 뒤 바닥에 내동댕이친다**(맞는 순간 짧은 슬로 모션),
## 헛치면 빈손으로 돌아온다. 부모가 마무리 타로 날려 보낸 상대는 날아가기를 끊고 붙잡는다.
## **피해는 잡을 때가 아니라 내리꽂을 때 들어간다** — 3타 판정을 `sense_only`(닿았는지만 알림)로 켜고,
## 판정에 담긴 피해를 기억해 뒀다가 꽂는 순간 준다

## 판정 뒤 손을 뻗은 채 버티는 시간 / 빈손으로 돌아오는 시간(초)
@export var reach_hold: float = 0.12
@export var reach_back: float = 0.15
## 머리 위로 넘기는 시간 / 꽂은 뒤 제자리로 돌아오는 시간(초, 게임 시간이라 슬로 중엔 늘어난다)
@export var throw_duration: float = 0.4
@export var throw_recover: float = 0.2
## 잡힌 상대 원점이 두 손에서 떨어진 거리(px) — 손은 머리를 쥐고 몸은 그 밑에 매달린다
@export var head_drop: float = 30.0
## 꽂은 뒤 튕겨 나가는 세기 — 평타(부모 콤보)의 3타 날아가기 값에 곱하는 배수(1 = 보통 3타와 같음)
@export var slam_launch_speed_mult: float = 1.0
@export var slam_launch_stun_mult: float = 1.0
## 꽂을 때 화면 흔들림
@export var slam_shake: float = 0.35
## 잡은 순간 슬로 모션 — 게임 속도 배수와 길이(실제 초)
@export var slow_scale: float = 0.3
@export var slow_duration: float = 0.5
## 3타를 뻗는 순간 카메라가 아주머니에게 바짝 다가간다(지하철 아저씨 궁 3타 `XSlashFinisher`와 같은 값) —
## 평소 배율의 몇 배까지, 다가가 있는 실제 시간(초), 들어가고 나오는 시간(초)
@export var zoom_mul: float = 1.55
@export var zoom_time: float = 1.1
@export var zoom_blend: float = 0.12

var _fighter: Fighter = null
## 잡은 쪽 — 캐릭터(Fighter) 또는 생물체 소환물(`summon_creature` 그룹: 고양이·일진 패거리)
var _victim: Node2D = null
var _has_victim: bool = false
var _throw_left: float = 0.0
var _dir: float = 1.0
## 이 노드가 Engine.time_scale을 바꿔 놓았는지 — 되돌릴 때 남의 슬로를 건드리지 않게
var _slowed: bool = false
## 3타 판정에 담겨 있던 피해 — 내리꽂을 때 준다
var _pending_damage: int = 0

func _exit_tree() -> void:
	_release()
	_clear_slow()
	# 옷을 벗으면 판정을 평소대로(피해 주기) 돌려 둔다
	var hitbox: Hitbox = _combo_hitbox()
	if hitbox:
		hitbox.sense_only = false

func _combo_hitbox() -> Hitbox:
	var combo: Node = get_parent()
	if combo == null or not ("hitbox" in combo):
		return null
	return combo.hitbox

## 부모(콤보)가 판정을 켜기 직전 — 3타면 피해를 기억해 두고 판정은 "닿았는지만" 알리게 바꾼다.
## false를 돌려줘 몸 판정은 그대로 켜게 한다
func on_combo_strike(_fighter_unused: Fighter, step: int, hitbox: Hitbox) -> bool:
	var combo: Node = get_parent()
	var final: bool = combo.has_method("_is_final") and combo._is_final(step)
	hitbox.sense_only = final
	if final:
		_pending_damage = hitbox.damage
	return false

## 부모(콤보)가 이 타를 시작했다 — 3타면 두 손을 뻗어 잡는 모션
func on_combo_swing(fighter: Fighter, step: int) -> void:
	var combo: Node = get_parent()
	if not combo.has_method("_is_final") or not combo._is_final(step):
		return
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("play_head_grab"):
		visual.play_head_grab(combo._windup_for(step, fighter), reach_hold, reach_back)
	var camera: Camera2D = fighter.get_viewport().get_camera_2d()
	if camera and camera.has_method("focus_on"):
		camera.focus_on(fighter, zoom_mul, zoom_time, zoom_blend)

## 부모(콤보)의 타가 맞았다 — 3타면 머리를 잡아 넘기기 시작한다
func on_combo_hit(fighter: Fighter, step: int, victim: Node) -> void:
	var combo: Node = get_parent()
	if not combo.has_method("_is_final") or not combo._is_final(step) or _has_victim:
		return
	if not is_instance_valid(victim):
		return
	var hitbox: Hitbox = _combo_hitbox()
	# 생물체 소환물(고양이·일진 패거리)은 캐릭터처럼 머리를 잡아 넘긴다(2026-10-07 사용자 요청)
	if victim.is_in_group(&"summon_creature") and "is_grabbed" in victim:
		if not victim.is_grabbed:
			_grab(fighter, victim)
		return
	# 판정이 sense_only라 피해가 안 들어갔다 — 잡지 못하는 것(고양이 집 같은 건물 등)은 그 자리에서 바로 맞는다.
	# **예전엔 이 검사 앞에서 Fighter가 아니면 그냥 돌아가 버려서, 건물을 3타로 치면 모션만 나오고 피해가 0이었다**
	if not (victim is Fighter):
		if victim.has_method("take_damage") and hitbox:
			victim.take_damage(_pending_damage, hitbox.knockback)
			hitbox._spawn_damage_number(victim.global_position, _pending_damage, 0)
		return
	var target: Fighter = victim
	if target.is_invincible:
		return
	# 막았으면 평소처럼 막힌 이펙트 — 피해도 잡기도 없다
	if target.is_guarding:
		if hitbox:
			hitbox._notify_blocked_by_guard()
			var hurt: Area2D = target.get_node_or_null("Hurtbox")
			if hurt:
				hitbox._spawn_guard_impact(hurt, hitbox.knockback)
		return
	# 잡을 수 없는 상대(슈퍼아머·카운터 자세 등)는 평소 3타처럼 맞고 날아간다
	if target.is_grabbed or not target.can_be_grabbed():
		target.take_damage(_pending_damage, hitbox.knockback if hitbox else Vector2.ZERO)
		if hitbox:
			hitbox._spawn_damage_number(target.global_position, _pending_damage, target.get_combo_count())
		return
	# **날아가기를 먼저 끊는다** — 부모가 방금 마무리 타로 날려 보냈다
	target.cancel_finisher_flight()
	_grab(fighter, target)

## 잡아서 머리 위로 넘기기 시작한다 — 캐릭터든 생물체 소환물이든 같다(둘 다 `is_grabbed`면 스스로 안 움직인다)
func _grab(fighter: Fighter, target: Node2D) -> void:
	target.is_grabbed = true
	target.velocity = Vector2.ZERO
	_fighter = fighter
	_victim = target
	_has_victim = true
	_dir = signf(fighter.facing) if not is_zero_approx(fighter.facing) else 1.0
	_throw_left = throw_duration
	# 넘기는 동안 제자리에 서서 다른 행동을 못 한다(맞으면 놓친다 — _process)
	fighter.movement_override = self
	fighter.start_busy(throw_duration + throw_recover)
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("play_head_throw"):
		visual.play_head_throw(throw_duration, throw_recover)
	_start_slow()

func _process(delta: float) -> void:
	if not _has_victim:
		return
	if not is_instance_valid(_victim) or not is_instance_valid(_fighter):
		_release()
		return
	# 던지는 쪽이 맞아 굳거나 잡히면 그 자리에서 놓친다
	if _fighter.is_in_hitstun() or _fighter.is_grabbed:
		_release()
		return
	_throw_left = maxf(_throw_left - delta, 0.0)
	var t: float = 1.0 - _throw_left / maxf(throw_duration, 0.001)
	_hold_victim_at(t)
	if _throw_left <= 0.0:
		_slam()

## 상대를 두 손(머리)에 붙인다. 넘기는 동안 몸이 거꾸로 뒤집힌다 — 처음엔 머리 아래로 매달리고,
## 머리 위에서는 발이 앞쪽으로 눕고, 등 뒤에 꽂힐 땐 머리가 바닥 쪽이다
func _hold_victim_at(t: float) -> void:
	var visual: Node2D = _fighter.get_node_or_null("Visual")
	var hand: Vector2 = _fighter.global_position
	if visual and visual.has_method("head_grab_point"):
		hand = visual.to_global(visual.head_grab_point())
	var angle: float = -_dir * PI * t * t
	var want: Vector2 = hand + Vector2(0.0, head_drop).rotated(angle)
	# 벽 너머로 넘기지 않는다 — 몸 가운데에서 그 자리까지 막히면 벽 앞에 둔다
	# ctx는 get_world_2d()가 있는 노드여야 한다 — 이 노드는 그냥 Node라 캐릭터를 넘긴다
	var hit: Dictionary = PhysicsQuery.raycast_ignoring_fighters(_fighter, _fighter.global_position, want)
	if not hit.is_empty():
		want = hit.position - (want - _fighter.global_position).normalized() * 20.0
	_victim.global_position = want
	var victim_visual: Node2D = _victim.get_node_or_null("Visual")
	if victim_visual:
		victim_visual.rotation = angle

## 등 뒤 바닥에 내리꽂고 놓는다 — 피해는 이때 들어간다
func _slam() -> void:
	var target: Node2D = _victim
	_release()
	if not is_instance_valid(target):
		return
	var combo: Node = get_parent()
	if not (target is Fighter):
		_slam_creature(target, combo)
		return
	# 넉백을 줘야 피격 반응·콤보 수가 들어간다. 속도는 아래 launch_finisher가 덮어쓴다
	target.take_damage(_pending_damage, Vector2(-_dir, -1.0))
	var hitbox: Hitbox = _combo_hitbox()
	if hitbox:
		hitbox._spawn_damage_number(target.global_position, _pending_damage, target.get_combo_count())
	# 바닥에 꽂힌 반동으로 **등 뒤 쪽으로 튕겨 날아가며 기절** — 보통 3타 날아가기와 같은 값(배수만 곱함)
	target.launch_finisher(-_dir,
		_combo_value(combo, "finisher_launch_speed", 535.0) * slam_launch_speed_mult,
		_combo_value(combo, "finisher_launch_pop", 220.0),
		_combo_value(combo, "finisher_launch_stun", 0.4) * slam_launch_stun_mult,
		_combo_value(combo, "finisher_tumble_turns", 1.0),
		_combo_value(combo, "finisher_max_scale", 2.0))
	if combo and combo.has_method("_spawn_launch_smoke") and bool(_combo_value(combo, "launch_smoke", 1.0)):
		combo._spawn_launch_smoke(target, maxf(_combo_value(combo, "finisher_launch_stun", 0.4), 0.45))
	var cam: Node = get_tree().get_first_node_in_group("game_camera")
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(slam_shake)

## 생물체 소환물을 꽂는다 — `launch_finisher`가 없으니 같은 세기의 넉백(등 뒤 쪽)으로 날린다
func _slam_creature(target: Node2D, combo: Node) -> void:
	if target.has_method("take_damage"):
		target.take_damage(_pending_damage, Vector2(
			-_dir * _combo_value(combo, "finisher_launch_speed", 535.0) * slam_launch_speed_mult,
			-_combo_value(combo, "finisher_launch_pop", 220.0)))
	var hitbox: Hitbox = _combo_hitbox()
	if hitbox and is_instance_valid(target):
		hitbox._spawn_damage_number(target.global_position, _pending_damage, 0)
	var cam: Node = get_tree().get_first_node_in_group("game_camera")
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(slam_shake)

## 부모 콤보의 값(없으면 기본값)
func _combo_value(combo: Node, key: String, fallback: float) -> float:
	if combo and key in combo:
		return float(combo.get(key))
	return fallback

## 잡은 상대를 놓고 이동 가로채기를 푼다(두 번 불려도 된다)
func _release() -> void:
	if _has_victim and is_instance_valid(_victim):
		_victim.is_grabbed = false
		var victim_visual: Node2D = _victim.get_node_or_null("Visual")
		if victim_visual:
			victim_visual.rotation = 0.0
	_has_victim = false
	_victim = null
	if is_instance_valid(_fighter) and _fighter.movement_override == self:
		_fighter.movement_override = null

## 화면 전체를 느리게 — 이미 다른 효과가 0.5 밑으로 늦춰 놨으면 건드리지 않는다
func _start_slow() -> void:
	if not _slowed and Engine.time_scale < 0.5:
		return
	Engine.time_scale = slow_scale
	_slowed = true
	Timers.after(self, slow_duration, _clear_slow, true)

func _clear_slow() -> void:
	if _slowed:
		Engine.time_scale = 1.0
	_slowed = false

## 넘기는 동안 그 자리에 선다 — movement_override 인터페이스
func get_move_velocity_x() -> float:
	return 0.0

func after_physics(_f: Fighter, _delta: float) -> void:
	pass
