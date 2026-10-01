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

## 데미지 배수를 걸 때 쓰는 이름표. 같은 이름으로 걸고 풀어야 다른 버프와 안 싸운다
const MODIFIER_ID := "dual_instrument"

## 지금 악기를 들고 있는 캐릭터(없으면 null)
var _armed_fighter: Fighter = null
## 남은 시간(초)
var _left: float = 0.0
## 대시용 판정 — 씬의 자식 `Hitbox`(없으면 대시 공격만 조용히 빠진다)
@onready var _dash_hitbox: Hitbox = get_node_or_null("Hitbox")

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

## 대시하는 동안에만 판정을 켜고 몸에 붙여 둔다 — 지나가면서 닿는 상대를 한 번씩 친다
func _update_dash_hitbox() -> void:
	if _dash_hitbox == null:
		return
	var on: bool = _left > 0.0 and is_instance_valid(_armed_fighter) and _armed_fighter.is_dashing()
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

## 악기를 도로 집어넣는다 — 시간이 다 됐거나 캐릭터가 사라질 때
func _disarm() -> void:
	_left = 0.0
	if _dash_hitbox:
		_dash_hitbox.set_deferred("monitoring", false)
		_dash_hitbox.set_deferred("monitorable", false)
	if _armed_fighter == null or not is_instance_valid(_armed_fighter):
		_armed_fighter = null
		return
	_armed_fighter.clear_modifier("attack_debuff_multiplier", MODIFIER_ID)
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
