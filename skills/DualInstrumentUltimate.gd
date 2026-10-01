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
@export var duration: float = 15.0
## 그동안 기본공격 데미지에 곱하는 배수
@export var damage_multiplier: float = 1.5

@export_group("대시 공격")
## 대시로 지나가며 주는 피해와 밀어내는 힘
@export var dash_damage: int = 12
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
	_set_rig_phase(-1.0)

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
	_set_rig_phase(0.0)
	if is_instance_valid(fighter) and fighter.movement_override == self:
		fighter.movement_override = null

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
	_dash_hitbox.damage = _armed_fighter.compute_damage(dash_damage)
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
	if _dash_hitbox:
		_dash_hitbox.set_deferred("monitoring", false)
		_dash_hitbox.set_deferred("monitorable", false)
	if _armed_fighter == null or not is_instance_valid(_armed_fighter):
		_armed_fighter = null
		return
	_armed_fighter.clear_modifier("attack_debuff_multiplier", MODIFIER_ID)
	if _armed_fighter.dash_override == self:
		_armed_fighter.dash_override = null
	var visual: Node2D = _armed_fighter.get_node_or_null("Visual")
	if visual and "held_item_l_armed" in visual:
		visual.held_item_l_armed = false
	_armed_fighter = null

## 지금 쌍 악기를 들고 있는지 (UI·다른 스킬이 물어볼 수 있게 열어둔다)
func is_armed() -> bool:
	return _left > 0.0

## 악기를 든 채 라운드가 끝나면 배수가 남을 수 있어서, 사라질 때 확실히 푼다
func _exit_tree() -> void:
	_disarm()
