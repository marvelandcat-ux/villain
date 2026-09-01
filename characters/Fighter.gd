class_name Fighter
extends CharacterBody2D

## 모든 캐릭터 씬이 공통으로 쓰는 베이스 스크립트.
## 캐릭터 전용 .gd는 만들지 않고, 스탯 리소스(stats)와 스킬 노드(Skill1/Skill2/SkillUltimate/BasicAttack) 조합만으로 새 캐릭터를 만든다.

## HP가 바뀔 때마다 UI 등에 알린다
signal health_changed(current: int, max: int)
## HP가 0이 되면 알린다 — Stage.gd가 이 시그널을 듣고 승패를 판정한다
signal died

## 캐릭터 고정 수치
@export var stats: CharacterStats

## 중력/점프력의 기본값 — 훈련장에서 이것저것 바꿔본 뒤 원래대로 되돌릴 때 쓴다
const DEFAULT_GRAVITY: float = 900.0
const DEFAULT_JUMP_VELOCITY: float = -350.0

## 모든 Fighter가 함께 쓰는 중력/점프력. 아직 값을 정하는 중이라 훈련장(maps/TrainingGround.gd)에서
## 실시간으로 바꿔볼 수 있게 static var로 두었다 — 값이 확정되면 위 DEFAULT_ 상수에 옮겨 적으면 된다.
## 점프력은 위쪽이 음수라서 -350처럼 음수 값이다
static var gravity: float = DEFAULT_GRAVITY
static var jump_velocity: float = DEFAULT_JUMP_VELOCITY

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
## true인 동안은 어떤 데미지도 받지 않는다 (예: 잼민이 궁극기 사용 중)
var is_invincible: bool = false
## true인 동안은 무서워서 기본공격/스킬을 전혀 못 쓴다(이동은 가능) — 지하철빌런 공포 단소 등
var is_feared: bool = false
## true면 점프할 때 개찰구를 뛰어넘는 듯한 연출이 추가된다 (지하철빌런 전용, 캐릭터 씬에서 켬)
@export var vault_jump: bool = false

## 캐릭터별 스킬이 자유롭게 쓰는 임시 데이터 저장소 (예: 주정뱅이 술 스택, 예수천국 흡수 데미지)
var custom_data: Dictionary = {}

## move_speed_multiplier 등을 여러 효과가 동시에 걸어도 서로 안 지우도록 관리하는 내부 저장소.
## {property: {id: value}} — 최종 배수는 같은 property에 걸린 값들을 전부 곱한 것
var _modifiers: Dictionary = {}
var _next_modifier_id: int = 0

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

## 데미지를 받는다. damage_reduction이 있으면 경감하고, 경감분은 custom_data["guard_absorbed"]에 누적된다.
## is_invincible이 true면 아예 무시한다
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	if is_invincible:
		return
	var reduced_amount: int = int(round(amount * (1.0 - damage_reduction)))
	if damage_reduction > 0.0:
		custom_data["guard_absorbed"] = custom_data.get("guard_absorbed", 0) + (amount - reduced_amount)
	current_hp = max(current_hp - reduced_amount, 0)
	velocity += knockback
	_flash_hit()
	health_changed.emit(current_hp, stats.max_hp)
	if current_hp <= 0:
		died.emit()

## 맞았을 때 캐릭터 그림을 잠깐 빨갛게 물들이는 피격 이펙트
func _flash_hit() -> void:
	var visual: CanvasItem = get_node_or_null("Visual")
	if visual == null:
		return
	var tween := create_tween()
	tween.tween_property(visual, "modulate", Color(1, 0.3, 0.3), 0.05)
	tween.tween_property(visual, "modulate", Color(1, 1, 1), 0.15)

## HP를 회복시킨다 (최대 HP를 넘지 않음)
func heal(amount: int) -> void:
	current_hp = mini(current_hp + amount, stats.max_hp)
	health_changed.emit(current_hp, stats.max_hp)

## 여러 상태이상 색조가 겹쳐도 서로 안 지우도록 관리하는 저장소. {id: Color} — 화면에는 가장 최근 것이 보이고,
## 그게 풀리면 그 전에 걸려있던 것으로 되돌아간다 (전부 사라지면 원래 색)
var _tints: Dictionary = {}
var _tint_order: Array = []

## id로 구분되는 색조 효과를 캐릭터 그림에 씌운다. duration을 주면 그 시간 후 자동으로 걷힌다(0이면 clear_tint로 직접 해제)
func set_tint(id, color: Color, duration: float = 0.0) -> void:
	_tint_order.erase(id)
	_tint_order.append(id)
	_tints[id] = color
	_apply_top_tint()
	if duration > 0.0:
		_after(duration, func(): clear_tint(id))

## id로 건 색조 효과를 해제한다
func clear_tint(id) -> void:
	_tints.erase(id)
	_tint_order.erase(id)
	_apply_top_tint()

func _apply_top_tint() -> void:
	var visual: CanvasItem = get_node_or_null("Visual")
	if visual == null:
		return
	visual.modulate = _tints[_tint_order[-1]] if not _tint_order.is_empty() else Color(1, 1, 1)

## duration초 후 callback을 실행한다. get_tree().create_timer()와 달리 이 Fighter의 자식 Timer로 만들어서,
## Fighter가 그 전에 사라지면(대전 도중 나가기, 다시하기 등으로 씬이 정리되는 경우) 콜백이 아예 실행되지 않고
## 같이 정리된다 — 그렇지 않으면 이미 사라진 Fighter를 건드리려다 에러가 난다
func _after(duration: float, callback: Callable) -> void:
	var timer := Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(func():
		callback.call()
		timer.queue_free()
	)
	timer.start()

## duration초 동안 무적 상태로 만든다
func grant_invincibility(duration: float) -> void:
	is_invincible = true
	_after(duration, func(): is_invincible = false)

## duration초 동안 공포 상태로 만든다 (기본공격/스킬 사용 불가, 이동은 가능)
func apply_fear(duration: float) -> void:
	is_feared = true
	set_tint("fear", Color(0.75, 0.75, 1.0), duration)
	_after(duration, func(): is_feared = false)

## 링아웃(낙사)으로 즉시 패배 처리한다
func ring_out() -> void:
	if current_hp <= 0:
		return
	current_hp = 0
	health_changed.emit(current_hp, stats.max_hp)
	died.emit()

## 기본 공격력에 캐릭터 배율과 디버프를 반영한 최종 데미지를 계산한다
func compute_damage(base_damage: int) -> int:
	return int(round(base_damage * stats.attack_multiplier * attack_debuff_multiplier))

func move(direction: float) -> void:
	if direction != 0.0:
		facing = signf(direction)
	velocity.x = direction * stats.move_speed * move_speed_multiplier

func jump() -> void:
	if not is_on_floor():
		return
	velocity.y = jump_velocity * jump_multiplier
	if vault_jump:
		_play_vault_effect()

## 개찰구를 훌쩍 뛰어넘는 듯한 점프 연출 (지하철빌런 전용)
func _play_vault_effect() -> void:
	var visual: Node2D = get_node_or_null("Visual")
	if visual == null:
		return
	var tween := create_tween()
	tween.tween_property(visual, "rotation", facing * -0.5, 0.15)
	tween.tween_property(visual, "rotation", 0.0, 0.15)

func use_skill_1() -> void:
	if skill_1 and not is_feared:
		skill_1.use(self)

func use_skill_2() -> void:
	if skill_2 and not is_feared:
		skill_2.use(self)

## 궁극기는 바로 나가지 않고, 씬에 컷인 연출이 있으면 연출을 먼저 재생한다.
## 실제 발동은 연출이 끝난 뒤 fire_ultimate_now()로 이뤄진다
func use_ultimate() -> void:
	if skill_ultimate == null or is_feared or not skill_ultimate.can_use():
		return
	var cutin: Node = get_tree().get_first_node_in_group("ultimate_cutin")
	if cutin and cutin.has_method("play"):
		cutin.play(self)
	else:
		skill_ultimate.use(self)

## 컷인 연출이 끝난 뒤 실제로 궁극기를 발동시킨다 (연출이 없는 씬에서는 쓰이지 않는다)
func fire_ultimate_now() -> void:
	if skill_ultimate:
		skill_ultimate.use(self)

func use_basic_attack() -> void:
	# 쿨타임 중이면 use()가 아무것도 안 하므로, 실제로 나가는 경우에만 공격 모션을 재생한다
	if basic_attack and not is_feared and basic_attack.can_use():
		basic_attack.use(self)
		_play_visual_attack()

## 공격 모션을 가진 비주얼(BodyRig 등)에 휘두르라고 알린다.
## 아직 임시 사각형(Polygon2D)을 쓰는 캐릭터는 이 메서드가 없어서 그냥 넘어간다
func _play_visual_attack() -> void:
	var visual := get_node_or_null("Visual")
	if visual and visual.has_method("play_attack_swing"):
		visual.play_attack_swing()

## 1대1 전제로 자기 자신이 아닌 다른 Fighter를 찾는다
func find_opponent() -> Fighter:
	for f in get_tree().get_nodes_in_group("fighters"):
		if f != self:
			return f
	return null

## property(예: "move_speed_multiplier")에 id로 구분되는 배수 효과를 하나 건다.
## 같은 property에 걸린 다른 id의 효과와는 서로 지우지 않고 곱해져서 함께 적용된다.
## id는 임시 버프면 자동 발급된 정수, 스택형(주정뱅이 술 등)처럼 켰다 껐다 하는 효과면 "drink_stacks" 같은 고정 문자열을 쓴다
func set_modifier(property: String, id, value: float) -> void:
	if not _modifiers.has(property):
		_modifiers[property] = {}
	_modifiers[property][id] = value
	_recompute_modifier(property)

## id로 건 효과를 해제한다
func clear_modifier(property: String, id) -> void:
	if _modifiers.has(property):
		_modifiers[property].erase(id)
		_recompute_modifier(property)

func _recompute_modifier(property: String) -> void:
	var result := 1.0
	for value in _modifiers.get(property, {}).values():
		result *= value
	set(property, result)

## property에 duration초 동안만 유지되는 임시 배수 효과를 건다 (자동으로 id를 발급하고 만료 처리)
func apply_temp_multiplier(property: String, value: float, duration: float) -> void:
	var id := _next_modifier_id
	_next_modifier_id += 1
	set_modifier(property, id, value)
	_after(duration, func(): clear_modifier(property, id))

## tick_interval마다 damage_per_tick씩 ticks번 데미지를 준다 (화상 등 도트 데미지)
func apply_dot(damage_per_tick: int, tick_interval: float, ticks: int) -> void:
	for i in range(ticks):
		_after(tick_interval * (i + 1), func(): take_damage(damage_per_tick))

## 이동/점프 입력 처리 후 컨트롤러가 매 물리 프레임 마지막에 호출한다.
## Fighter 스스로는 _physics_process를 갖지 않고, 이 함수로만 물리 갱신이 일어난다
func apply_physics(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	if movement_override:
		velocity.x = movement_override.get_move_velocity_x()
	move_and_slide()
	if movement_override:
		movement_override.after_physics(self, delta)
