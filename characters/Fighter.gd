class_name Fighter
extends CharacterBody2D

## 모든 캐릭터 씬이 공통으로 쓰는 베이스 스크립트.
## 캐릭터 전용 .gd는 만들지 않고, 스탯 리소스(stats)와 스킬 노드(Skill1/Skill2/SkillUltimate/BasicAttack) 조합만으로 새 캐릭터를 만든다.

## HP가 바뀔 때마다 UI 등에 알린다
signal health_changed(current: int, max: int)
## HP가 0이 되면 알린다 (아직 라운드 종료 처리는 없음 — TODO)
signal died

## 캐릭터 고정 수치
@export var stats: CharacterStats

const GRAVITY: float = 900.0
const JUMP_VELOCITY: float = -350.0

var current_hp: int = 0
var facing: float = 1.0

## 자식 노드 이름(Skill1/Skill2/SkillUltimate/BasicAttack)으로 자동 연결되는 스킬 슬롯.
## 스탠스 전환처럼 특수한 캐릭터는 직접 다시 할당해서 바꿀 수 있다
var skill_1: Skill
var skill_2: Skill
var skill_ultimate: Skill
var basic_attack: Skill

## 돌진처럼 이동을 잠깐 가로채는 스킬이 자신을 등록해두는 슬롯.
## get_move_velocity_x()와 after_physics(fighter, delta)를 구현한 오브젝트여야 한다.
## 타입을 지정하지 않아야 서로 다른 스킬 클래스를 덕 타이핑으로 담을 수 있다
var movement_override = null

## 이동속도/점프력/공격력/쿨타임 진행속도 배수 — 버프·디버프 스킬이 일시적으로 바꾼다
var move_speed_multiplier: float = 1.0
var jump_multiplier: float = 1.0
var attack_debuff_multiplier: float = 1.0
var cooldown_rate_multiplier: float = 1.0
## 받는 데미지 감소율 (0.0=없음, 1.0=완전 무효) — 가드 스킬 등이 사용
var damage_reduction: float = 0.0

## 캐릭터별 스킬이 자유롭게 쓰는 임시 데이터 저장소 (예: 주정뱅이 술 스택, 예수천국 흡수 데미지)
var custom_data: Dictionary = {}

func _ready() -> void:
	current_hp = stats.max_hp
	add_to_group("fighters")
	if skill_1 == null:
		skill_1 = get_node_or_null("Skill1")
	if skill_2 == null:
		skill_2 = get_node_or_null("Skill2")
	if skill_ultimate == null:
		skill_ultimate = get_node_or_null("SkillUltimate")
	if basic_attack == null:
		basic_attack = get_node_or_null("BasicAttack")

## 데미지를 받는다. damage_reduction이 있으면 경감하고, 경감분은 custom_data["guard_absorbed"]에 누적된다
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	var reduced_amount: int = int(round(amount * (1.0 - damage_reduction)))
	if damage_reduction > 0.0:
		custom_data["guard_absorbed"] = custom_data.get("guard_absorbed", 0) + (amount - reduced_amount)
	current_hp = max(current_hp - reduced_amount, 0)
	velocity += knockback
	health_changed.emit(current_hp, stats.max_hp)
	if current_hp <= 0:
		died.emit()

## HP를 회복시킨다 (최대 HP를 넘지 않음)
func heal(amount: int) -> void:
	current_hp = mini(current_hp + amount, stats.max_hp)
	health_changed.emit(current_hp, stats.max_hp)

## 기본 공격력에 캐릭터 배율과 디버프를 반영한 최종 데미지를 계산한다
func compute_damage(base_damage: int) -> int:
	return int(round(base_damage * stats.attack_multiplier * attack_debuff_multiplier))

func move(direction: float) -> void:
	if direction != 0.0:
		facing = signf(direction)
	velocity.x = direction * stats.move_speed * move_speed_multiplier

func jump() -> void:
	if is_on_floor():
		velocity.y = JUMP_VELOCITY * jump_multiplier

func use_skill_1() -> void:
	if skill_1:
		skill_1.use(self)

func use_skill_2() -> void:
	if skill_2:
		skill_2.use(self)

func use_ultimate() -> void:
	if skill_ultimate:
		skill_ultimate.use(self)

func use_basic_attack() -> void:
	if basic_attack:
		basic_attack.use(self)

## 1대1 전제로 자기 자신이 아닌 다른 Fighter를 찾는다
func find_opponent() -> Fighter:
	for f in get_tree().get_nodes_in_group("fighters"):
		if f != self:
			return f
	return null

## property(예: "move_speed_multiplier")를 value로 바꿨다가 duration초 후 1.0으로 되돌린다.
## 여러 디버프가 겹치면 나중 것이 이전 것을 덮어쓰는 단순한 방식이다 (임시 구현)
func apply_temp_multiplier(property: String, value: float, duration: float) -> void:
	set(property, value)
	get_tree().create_timer(duration).timeout.connect(func(): set(property, 1.0))

## tick_interval마다 damage_per_tick씩 ticks번 데미지를 준다 (화상 등 도트 데미지)
func apply_dot(damage_per_tick: int, tick_interval: float, ticks: int) -> void:
	for i in range(ticks):
		get_tree().create_timer(tick_interval * (i + 1)).timeout.connect(func(): take_damage(damage_per_tick))

## 이동/점프 입력 처리 후 컨트롤러가 매 물리 프레임 마지막에 호출한다.
## Fighter 스스로는 _physics_process를 갖지 않고, 이 함수로만 물리 갱신이 일어난다
func apply_physics(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if movement_override:
		velocity.x = movement_override.get_move_velocity_x()
	move_and_slide()
	if movement_override:
		movement_override.after_physics(self, delta)
