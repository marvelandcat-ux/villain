class_name BatonModeUltimate
extends Skill

## 경관봉 모드 — 경찰 궁극기(2026-09-30).
## 쓰는 순간 허리에서 경봉을 뽑아 들고, **정해진 시간 동안 기본공격이 주먹 대신 경봉 타격**이 된다.
## 경봉을 든 동안은 데미지가 크게 오르고, 시간이 다 되면 도로 집어넣는다.
##
## 이 스킬은 **상태만 바꾼다** — 때리는 건 그대로 `BasicAttack`(ComboMeleeAttack)이 한다.
## 경봉을 들었는지에 따라 `BodyRig`가 알아서 잽(맨손) / 휘두르기(경봉)를 갈아 끼운다.
##
## 시간 재기는 `Skill`의 `_process`를 쓰지 않고 자체 타이머로 센다 —
## 쿨타임과 지속시간은 서로 다른 시계라서(궁 쿨 20초 / 경봉 15초) 섞으면 헷갈린다

## 경봉을 들고 있는 시간(초). **궁을 쓴 순간부터 센다**
@export var duration: float = 15.0
## 경봉을 든 동안 기본공격 데미지에 곱하는 배수
@export var damage_multiplier: float = 2.0
## 경봉을 든 동안 기본공격 사거리에 곱하는 배수 — 봉이 주먹보다 길다
@export var range_multiplier: float = 1.35

## 데미지 배수를 걸 때 쓰는 이름표. 같은 이름으로 걸고 풀어야 다른 버프와 안 싸운다
const MODIFIER_ID := "baton_mode"

## 지금 경봉을 들고 있는 캐릭터(없으면 null) — 라운드가 끝나 사라질 때 정리하려고 들고 있는다
var _armed_fighter: Fighter = null
## 남은 시간(초)
var _left: float = 0.0
## 경봉을 들기 전의 기본공격 사거리·쿨타임 — 끝나면 이 값들로 되돌린다
var _base_range: float = 0.0
var _base_cooldown: float = -1.0
var _base_miss_cooldown: float = -1.0

func _process(delta: float) -> void:
	super._process(delta)
	if _left <= 0.0:
		return
	_left -= delta
	if _left <= 0.0:
		_disarm()

func _execute(fighter: Fighter) -> void:
	# 이미 들고 있는데 또 쓰면 시간만 다시 채운다(겹쳐서 두 번 거는 걸 막는다)
	if _armed_fighter == fighter and _left > 0.0:
		_left = duration
		return
	_armed_fighter = fighter
	_left = duration
	fighter.set_modifier("attack_debuff_multiplier", MODIFIER_ID, damage_multiplier)
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual and "held_item_armed" in visual:
		visual.held_item_armed = true
	var basic: Node = fighter.get_node_or_null("BasicAttack")
	if basic and "range" in basic:
		_base_range = basic.range
		basic.range = _base_range * range_multiplier
	# **경봉을 든 동안엔 평타 쿨을 아예 없앤다**(2026-09-30 사용자 지정) — 누르는 대로 바로 나간다.
	# 헛쳤을 때 도는 쿨(miss_cooldown)도 같이 0으로 둔다. 안 그러면 한 번 헛치는 순간 1초를 쉰다
	if basic and "cooldown" in basic:
		_base_cooldown = basic.cooldown
		basic.cooldown = 0.0
		basic.cooldown_left = 0.0
	if basic and "miss_cooldown" in basic:
		_base_miss_cooldown = basic.miss_cooldown
		basic.miss_cooldown = 0.0

## 경봉을 도로 집어넣는다 — 시간이 다 됐거나 캐릭터가 사라질 때
func _disarm() -> void:
	_left = 0.0
	if _armed_fighter == null or not is_instance_valid(_armed_fighter):
		_armed_fighter = null
		return
	_armed_fighter.clear_modifier("attack_debuff_multiplier", MODIFIER_ID)
	var visual: Node2D = _armed_fighter.get_node_or_null("Visual")
	if visual and "held_item_armed" in visual:
		visual.held_item_armed = false
	var basic: Node = _armed_fighter.get_node_or_null("BasicAttack")
	if basic and "range" in basic and _base_range > 0.0:
		basic.range = _base_range
	if basic and "cooldown" in basic and _base_cooldown >= 0.0:
		basic.cooldown = _base_cooldown
		_base_cooldown = -1.0
	if basic and "miss_cooldown" in basic and _base_miss_cooldown >= 0.0:
		basic.miss_cooldown = _base_miss_cooldown
		_base_miss_cooldown = -1.0
	_armed_fighter = null

## 지금 경봉을 들고 있는지 (UI·다른 스킬이 물어볼 수 있게 열어둔다)
func is_armed() -> bool:
	return _left > 0.0

## 경봉을 든 채 라운드가 끝나면 배수가 남을 수 있어서, 사라질 때 확실히 푼다
func _exit_tree() -> void:
	_disarm()
