class_name DualInstrumentUltimate
extends Skill

## 쌍 악기 모드 — 지하철 아저씨 궁극기(2026-10-01, 옛 "떡볶이 국물"을 통째로 대체).
## 쓰면 비어 있던 **왼손에 검은 리코더**를 꺼내 양손잡이가 되고, 정해진 시간 동안
## 서 있기·걷기·방어·대시 자세가 전부 바뀐다. **개찰구(스킬1)만 그대로다.**
##
## 이 스킬은 **상태만 바꾼다** — 자세는 `BodyRig`(`held_item_l_armed`)가, 때리는 건
## 기본공격과 **대시**가 한다(경찰 경관봉 모드와 같은 꼴).
##
## 대시는 이 동안 **지나가며 베는 공격**이 된다 — 아래 `_dash_hitbox`를 대시 중에만 켠다

## 악기를 들고 있는 시간(초). **궁을 쓴 순간부터 센다**
@export var duration: float = 30.0
## 그동안 기본공격 데미지에 곱하는 배수
@export var damage_multiplier: float = 1.5

@export_group("궁 중 강화")
## 궁을 쓴 동안 **방어가 이만큼 더 오래 버틴다**(초). 기본 1.0초 + 0.5 = 1.5초.
## 이 캐릭터에게만 걸린다(`Fighter.guard_duration_bonus`) — 상대 방어는 그대로 1초다
@export var guard_duration_bonus: float = 0.5
## 돌진하는 **동안 무적**이 되는지. 끄면 지나가며 때리기만 한다
@export var dash_invincible: bool = true
## 돌진이 끝난 뒤 **마무리 자세**를 유지하는 시간(초). 이 동안 리그에 구간 2를 알려 준다
@export var dash_end_hold: float = 0.18
## 궁을 쓴 동안 **기본공격 콤보가 이만큼 길어진다**. 1이면 3타 → 4타가 된다.
## **지금은 0이다(3타 그대로)** — 2026-10-02에 "리코더가 바로 돌아오니 다시 3콤보"로 정했다.
## 늘리면 늘어난 타의 데미지·넉백은 마지막 타와 같고, 자세만 몸의 4타 포즈 씬이 따로 맡는다
@export var bonus_combo_hits: int = 0

@export_group("대시 공격")
## 대시로 지나가며 주는 피해와 밀어내는 힘
@export var dash_damage: int = 8
@export var dash_knockback: Vector2 = Vector2(190, -170)
## 대시 판정 상자 크기(캐릭터 중심 기준)
@export var dash_hitbox_size: Vector2 = Vector2(74, 86)
## **준비동작 — 캐릭터 두 칸만큼 뒤로 물러났다가**(2026-10-01 사용자 요청) 앞으로 내지른다.
## 평소 대시(`Fighter.dash_speed` x `dash_duration` = 약 112px)는 "지나간다"가 안 살아서,
## 궁 중에는 이동을 통째로 가로채(`movement_override`) 두 구간으로 굴린다
@export var dash_back_distance: float = 110.0
@export var dash_back_speed: float = 780.0
## 뒤로 다 물러난 뒤 앞으로 내지르는 거리·속도
@export var dash_forward_distance: float = 330.0
@export var dash_forward_speed: float = 1700.0

## 데미지 배수를 걸 때 쓰는 이름표. 같은 이름으로 걸고 풀어야 다른 버프와 안 싸운다
const MODIFIER_ID := "dual_instrument"

## 지금 악기를 들고 있는 캐릭터(없으면 null)
var _armed_fighter: Fighter = null
## 남은 시간(초)
var _left: float = 0.0
## 대시용 판정 — 씬의 자식 `Hitbox`(없으면 대시 공격만 조용히 빠진다)
@onready var _dash_hitbox: Hitbox = get_node_or_null("Hitbox")
## 돌진이 어느 구간인지 — 0 안 함 / -1 뒤로 물러나는 중 / 1 앞으로 내지르는 중
var _rush_phase: int = 0
## 이번 구간에서 남은 거리(px)와 돌진 방향
var _rush_left: float = 0.0
var _rush_dir: float = 1.0
## 돌진이 끝난 뒤 마무리 자세를 유지할 남은 시간(초)
var _end_hold_left: float = 0.0
## 지금 이 스킬이 무적을 걸어 둔 상태인지 (중복으로 걸고 안 풀리는 걸 막는다)
var _invincible_on: bool = false

func _ready() -> void:
	super._ready()
	if _dash_hitbox:
		_dash_hitbox.monitoring = false
		_dash_hitbox.monitorable = false
		# 판정 도형은 씬이 공유하는 자원이라 복제해서 크기를 잡는다
		var shape_node := _dash_hitbox.get_node_or_null("HitboxCollision") as CollisionShape2D
		if shape_node and shape_node.shape is RectangleShape2D:
			shape_node.shape = shape_node.shape.duplicate()
			(shape_node.shape as RectangleShape2D).size = dash_hitbox_size

func _process(delta: float) -> void:
	super._process(delta)
	_update_dash_hitbox()
	# 돌진이 끝난 뒤 마무리 자세를 잠깐 유지한다 — 이동은 이미 풀려 있어서 움직이면 그냥 섞여 사라진다
	if _end_hold_left > 0.0:
		_end_hold_left -= delta
		if _end_hold_left <= 0.0:
			_set_rig_phase(0.0)
	if _left <= 0.0:
		return
	_left -= delta
	if _left <= 0.0:
		_disarm()

## `Fighter.dash_override` 인터페이스 — 대시 키가 눌린 **그 프레임에** 불린다.
## 평소 대시를 아예 시작하지 않고 "뒤로 물러났다 앞으로 내지르기"로 바꿔 굴린다.
## ⚠️ 이걸 `_process`에서 "대시 중인지 보고 가로채는" 식으로 하면 한 프레임 늦어서
## 그 사이에 평소 대시가 이미 약 47px 앞으로 튀어 나간다(헤드리스 실측)
func take_over_dash(fighter: Fighter, direction: float) -> void:
	if _left <= 0.0 or fighter.movement_override != null:
		return
	_armed_fighter = fighter
	_rush_dir = signf(direction)
	_rush_phase = -1
	_rush_left = dash_back_distance
	fighter.movement_override = self
	_end_hold_left = 0.0
	_set_rig_phase(-1.0)
	# 돌진하는 동안은 상대 몸을 **뚫고 지나간다** — 막혀 서면 "베고 지나갔다"가 성립하지 않는다
	fighter.pass_through_fighters = true
	# 물러나는 준비동작부터 다 지나갈 때까지 통째로 무적이다 — 지나가며 베는 게 이 궁의 값이므로,
	# 교차하는 순간 서로 맞고 끊기면 "지나갔다"가 성립하지 않는다
	_set_invincible(true)

## `Fighter.movement_override` 인터페이스 — 이 동안 가로 속도는 전부 이쪽이 정한다
func get_move_velocity_x() -> float:
	if _rush_phase < 0:
		# 뒤로 물러나는 동안에도 **보는 방향은 그대로다**(상대를 보며 뒷걸음질 = 준비동작)
		return -_rush_dir * dash_back_speed
	if _rush_phase > 0:
		return _rush_dir * dash_forward_speed
	return 0.0

## `Fighter.movement_override` 인터페이스 — 매 물리 프레임 끝에 불린다. 간 거리를 세서 구간을 넘긴다
func after_physics(fighter: Fighter, delta: float) -> void:
	if _rush_phase == 0:
		return
	var speed: float = dash_back_speed if _rush_phase < 0 else dash_forward_speed
	_rush_left -= speed * delta
	# 벽에 막히면 그 구간은 거기서 끝낸다(벽에 붙어 영영 안 끝나는 걸 막는다)
	var blocked: bool = fighter.is_on_wall()
	if _rush_left > 0.0 and not blocked:
		return
	if _rush_phase < 0:
		# 다 물러났으니 이제 앞으로 내지른다
		_rush_phase = 1
		_rush_left = dash_forward_distance
		_set_rig_phase(1.0)
		fighter.start_air_trail(dash_forward_distance / maxf(dash_forward_speed, 1.0))
	else:
		_end_rush(fighter)

## 돌진을 끝내고 이동 권한을 돌려준다
func _end_rush(fighter: Fighter) -> void:
	_rush_phase = 0
	_rush_left = 0.0
	_set_invincible(false)
	if is_instance_valid(fighter):
		fighter.pass_through_fighters = false
	# 마무리 자세(구간 2)를 dash_end_hold 동안 유지한다. 0이면 곧바로 평소 자세로 돌아간다
	_end_hold_left = maxf(dash_end_hold, 0.0)
	_set_rig_phase(2.0 if _end_hold_left > 0.0 else 0.0)
	if is_instance_valid(fighter) and fighter.movement_override == self:
		fighter.movement_override = null

## 돌진 무적을 켜고 끈다 — 개수로 세는 쪽(`push/pop_invincible`)을 쓰므로
## 다른 스킬의 시간제 무적이 중간에 끝나도 이쪽이 안 풀린다
func _set_invincible(on: bool) -> void:
	if on and not dash_invincible:
		return
	if on == _invincible_on:
		return
	if not is_instance_valid(_armed_fighter):
		_invincible_on = false
		return
	_invincible_on = on
	if on:
		_armed_fighter.push_invincible()
	else:
		_armed_fighter.pop_invincible()

## 리그에 지금 어느 구간인지 알려 준다(자세용) — -1 물러남 / 1 내지름 / 0 평소
func _set_rig_phase(value: float) -> void:
	if not is_instance_valid(_armed_fighter):
		return
	var visual: Node2D = _armed_fighter.get_node_or_null("Visual")
	if visual and "dual_dash_phase" in visual:
		visual.dual_dash_phase = value

## 돌진하는 동안에만 판정을 켜고 몸에 붙여 둔다 — 지나가면서 닿는 상대를 한 번씩 친다.
## **앞으로 내지르는 구간에서만 켠다** — 뒤로 물러나는 준비동작에 맞으면 이상하다
func _update_dash_hitbox() -> void:
	if _dash_hitbox == null:
		return
	var on: bool = _left > 0.0 and is_instance_valid(_armed_fighter) and _rush_phase > 0
	if not on:
		if _dash_hitbox.monitoring:
			_dash_hitbox.set_deferred("monitoring", false)
			_dash_hitbox.set_deferred("monitorable", false)
		return
	_dash_hitbox.global_position = _armed_fighter.global_position
	# ⚠️ **이 궁이 자기한테 건 공격력 배수(damage_multiplier)는 돌진에서 도로 나눈다.**
	#    그 배수는 "기본공격이 세진다"는 뜻인데, 안 빼면 돌진 피해에도 곱해져서
	#    여기 적은 8이 실제로는 12로 들어간다(실측). 약화 같은 **다른** 디버프는 그대로 먹는다
	var own: float = maxf(damage_multiplier, 0.01)
	_dash_hitbox.damage = maxi(int(round(float(_armed_fighter.compute_damage(dash_damage)) / own)), 1)
	_dash_hitbox.knockback = Vector2(dash_knockback.x * _armed_fighter.facing, dash_knockback.y)
	_dash_hitbox.source_fighter = _armed_fighter
	if not _dash_hitbox.monitoring:
		# 대시가 시작될 때마다 새로 켠다 — 그래야 지난 대시에 맞은 상대도 이번에 다시 맞는다
		_dash_hitbox.clear_repeat_state()
		_dash_hitbox.monitoring = true
		_dash_hitbox.monitorable = true

func _execute(fighter: Fighter) -> void:
	# 이미 들고 있는데 또 쓰면 시간만 다시 채운다(겹쳐서 두 번 거는 걸 막는다)
	if _armed_fighter == fighter and _left > 0.0:
		_left = duration
		return
	_armed_fighter = fighter
	_left = duration
	fighter.set_modifier("attack_debuff_multiplier", MODIFIER_ID, damage_multiplier)
	# 궁 중에는 방어가 더 오래 버틴다 (1.0 → 1.5초)
	fighter.guard_duration_bonus = guard_duration_bonus
	# 궁 중에는 평타가 한 타 더 나간다 (3타 → 4타)
	_set_bonus_hits(fighter, bonus_combo_hits)
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual and "held_item_l_armed" in visual:
		visual.held_item_l_armed = true
	# 이 동안 대시는 이 스킬이 가로챈다
	fighter.dash_override = self

## 악기를 도로 집어넣는다 — 시간이 다 됐거나 캐릭터가 사라질 때
func _disarm() -> void:
	_left = 0.0
	if _rush_phase != 0:
		_end_rush(_armed_fighter)
	_set_invincible(false)
	_end_hold_left = 0.0
	# 마무리 자세를 유지하던 중에 시간이 다 됐을 수도 있다 — 구간을 0으로 돌려놔야
	# 다음에 다시 궁을 썼을 때 가만히 서 있는데 마무리 자세가 나오지 않는다
	_set_rig_phase(0.0)
	if _dash_hitbox:
		_dash_hitbox.set_deferred("monitoring", false)
		_dash_hitbox.set_deferred("monitorable", false)
	if _armed_fighter == null or not is_instance_valid(_armed_fighter):
		_armed_fighter = null
		return
	_armed_fighter.clear_modifier("attack_debuff_multiplier", MODIFIER_ID)
	_armed_fighter.guard_duration_bonus = 0.0
	_armed_fighter.pass_through_fighters = false
	_set_bonus_hits(_armed_fighter, 0)
	if _armed_fighter.dash_override == self:
		_armed_fighter.dash_override = null
	var visual: Node2D = _armed_fighter.get_node_or_null("Visual")
	if visual and "held_item_l_armed" in visual:
		visual.held_item_l_armed = false
	_armed_fighter = null

## 기본공격 콤보의 타 수를 늘리거나 되돌린다. 콤보형 기본공격이 아니면 조용히 넘어간다
func _set_bonus_hits(fighter: Fighter, amount: int) -> void:
	if not is_instance_valid(fighter):
		return
	var basic: Node = fighter.basic_attack
	if basic != null and "bonus_hits" in basic:
		basic.bonus_hits = amount

## 지금 쌍 악기를 들고 있는지 (UI·다른 스킬이 물어볼 수 있게 열어둔다)
func is_armed() -> bool:
	return _left > 0.0

## 쌍 악기가 남은 비율(1 → 0). 안 들고 있으면 -1 — 쿨타임 표시가 이걸 보고 남은 시간을 그린다
func active_ratio() -> float:
	if _left <= 0.0:
		return -1.0
	return clampf(_left / maxf(duration, 0.001), 0.0, 1.0)

## 악기를 든 채 라운드가 끝나면 배수가 남을 수 있어서, 사라질 때 확실히 푼다
func _exit_tree() -> void:
	_disarm()
