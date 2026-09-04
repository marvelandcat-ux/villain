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
## 공중에서 한 번 더 뛰는 이단 점프의 세기. 지상 점프(-350, 71px)보다 세게 잡아서
## 둘을 이어 뛰면 약 172px까지 올라간다 — 지하철 승강장의 의자 발판(바닥에서 145px)이
## 지상 점프 한 번(71px)으로는 절대 안 닿고 이단 점프로만 닿게 하려고 정한 값.
## 의자를 이 높이에 둔 이유는 의자에 올라선 캐릭터가 열차 지붕(y=195)보다 확실히 위에 있어야 하기 때문
const DEFAULT_AIR_JUMP_VELOCITY: float = -420.0

## 통과 가능한 발판(one_way_collision)을 뚫고 내려갈 때 그 발판과의 충돌을 꺼두는 시간(초).
## 발판 두께(20px)를 지나 떨어지는 데 필요한 시간(약 0.21초)보다 넉넉하게 잡았다
const DROP_THROUGH_DURATION: float = 0.35

## 모든 Fighter가 함께 쓰는 중력/점프력. 아직 값을 정하는 중이라 훈련장(maps/TrainingGround.gd)에서
## 실시간으로 바꿔볼 수 있게 static var로 두었다 — 값이 확정되면 위 DEFAULT_ 상수에 옮겨 적으면 된다.
## 점프력은 위쪽이 음수라서 -350처럼 음수 값이다
static var gravity: float = DEFAULT_GRAVITY
static var jump_velocity: float = DEFAULT_JUMP_VELOCITY
static var air_jump_velocity: float = DEFAULT_AIR_JUMP_VELOCITY
## 바닥에서 뛴 뒤 공중에서 추가로 뛸 수 있는 횟수. 1이면 이단 점프, 0이면 예전처럼 바닥에서만 점프
static var max_air_jumps: int = 1

var current_hp: int = 0
var facing: float = 1.0
## 지금 공중에서 몇 번 더 뛸 수 있는지. 바닥에 닿을 때마다 max_air_jumps로 다시 채워진다
var _air_jumps_left: int = 0

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
## true인 동안은 어떤 데미지도 받지 않는다 (예: 촉법소년 궁극기 사용 중)
var is_invincible: bool = false
## true인 동안은 무서워서 기본공격/스킬을 전혀 못 쓴다(이동은 가능) — 지하철빌런 공포 단소 등
var is_feared: bool = false
## true면 점프할 때 개찰구를 뛰어넘는 듯한 연출이 추가된다 (지하철빌런 전용, 캐릭터 씬에서 켬)
@export var vault_jump: bool = false

## 캐릭터별 스킬이 자유롭게 쓰는 임시 데이터 저장소 (예: 주정뱅이 술 스택)
var custom_data: Dictionary = {}

## 스킬 모션(마시기/토하기/공격 등)이 재생되는 동안 다른 스킬·기본공격을 못 쓰게 막는 남은 시간(초).
## 이동은 막지 않는다(마시면서 걷기 등은 그대로). apply_physics에서 매 물리 프레임 줄어든다
var _busy_time: float = 0.0

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

## 바닥에서는 보통 점프, 공중에서는 남은 횟수만큼 이단 점프.
## 이단 점프는 지금까지의 낙하 속도를 무시하고 속도를 새로 덮어써서, 떨어지는 중에 눌러도 제대로 뜬다
func jump() -> void:
	if is_on_floor():
		velocity.y = jump_velocity * jump_multiplier
	elif _air_jumps_left > 0:
		_air_jumps_left -= 1
		velocity.y = air_jump_velocity * jump_multiplier
	else:
		return
	if vault_jump:
		_play_vault_effect()
	# 점프하는 순간 몸이 세로로 늘어나는 연출 (그 메서드가 있는 비주얼만)
	var visual := get_node_or_null("Visual")
	if visual and visual.has_method("play_jump_stretch"):
		visual.play_jump_stretch()

## 지금 밟고 있는 바닥이 통과 가능한 발판(one_way_collision)이면, 그 발판과의 충돌만 잠깐 꺼서
## 아래층으로 내려간다. 성공하면 true, 발판 위가 아니면(진짜 지면이거나 공중) 아무것도 안 하고 false.
##
## 충돌 레이어를 통째로 끄지 않고 add_collision_exception_with()로 그 발판 하나만 예외 처리하는 이유:
## 레이어를 끄면 같은 레이어인 진짜 지면·벽까지 같이 통과해버려서 맵 밖으로 떨어진다
func drop_through_platform() -> bool:
	var platform: PhysicsBody2D = _get_one_way_floor()
	if platform == null:
		return false
	add_collision_exception_with(platform)
	# 예외를 걸어도 속도가 0이면 그 자리에 멈춰 있으므로, 곧바로 떨어지기 시작하게 아래로 살짝 밀어준다
	velocity.y = maxf(velocity.y, 10.0)
	# 다 내려간 뒤 예외를 되돌린다. get_tree().create_timer()가 아니라 자식 Timer(_after)를 쓰는 이유는
	# 대전 도중 나가기 등으로 이 Fighter가 먼저 사라지면 콜백 자체가 실행되지 않게 하기 위함
	_after(DROP_THROUGH_DURATION, func():
		# 맵이 먼저 정리되어 발판만 사라진 경우를 대비 (해제된 객체는 == null 비교가 안 통해서 이 함수로 확인)
		if is_instance_valid(platform):
			remove_collision_exception_with(platform)
	)
	return true

## 발밑에 닿아 있는 바닥 중 "통과 가능한 발판"이 있으면 그 StaticBody2D를 돌려준다.
## 직전 move_and_slide()가 기록해둔 충돌 목록에서 위를 향한 면만 골라 보고,
## 그 면이 속한 충돌 도형에 one_way_collision이 켜져 있는지 확인한다
func _get_one_way_floor() -> PhysicsBody2D:
	if not is_on_floor():
		return null
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		# 법선이 위를 향하는 면 = 발밑 바닥. 벽이나 천장에 스친 충돌은 건너뛴다
		if collision.get_normal().y > -0.7:
			continue
		var body = collision.get_collider()
		if not (body is PhysicsBody2D):
			continue
		var owner_id: int = body.shape_find_owner(collision.get_collider_shape_index())
		if owner_id != -1 and body.is_shape_owner_one_way_collision_enabled(owner_id):
			return body
	return null

## 개찰구를 훌쩍 뛰어넘는 듯한 점프 연출 (지하철빌런 전용)
func _play_vault_effect() -> void:
	var visual: Node2D = get_node_or_null("Visual")
	if visual == null:
		return
	var tween := create_tween()
	tween.tween_property(visual, "rotation", facing * -0.5, 0.15)
	tween.tween_property(visual, "rotation", 0.0, 0.15)

## 지금 스킬 모션 중이라 다른 행동을 못 하는 상태인지
func is_busy() -> bool:
	return _busy_time > 0.0

## duration초 동안 다른 스킬·기본공격 입력을 막는다 (모션이 겹쳐 나오지 않게). 이동은 계속 가능하다.
## 더 긴 잠금이 이미 걸려 있으면 짧은 걸로 줄어들지 않게 둘 중 큰 값을 쓴다
func start_busy(duration: float) -> void:
	_busy_time = maxf(_busy_time, duration)

## 씬에 SkillClashManager가 있으면(1대1 대전 맵) 반환하고, 없으면(훈련장 등) null
func _get_clash_manager() -> Node:
	return get_tree().get_first_node_in_group("skill_clash_manager")

func use_skill_1() -> void:
	if skill_1 == null or is_feared or is_busy() or not skill_1.can_use():
		return
	var manager: Node = _get_clash_manager()
	if manager:
		manager.request(self, "skill_1", func(): skill_1.use(self), func(): skill_1.cancel_use())
	else:
		skill_1.use(self)

func use_skill_2() -> void:
	if skill_2 == null or is_feared or is_busy() or not skill_2.can_use():
		return
	var manager: Node = _get_clash_manager()
	if manager:
		manager.request(self, "skill_2", func(): skill_2.use(self), func(): skill_2.cancel_use())
	else:
		skill_2.use(self)

## 궁극기는 바로 나가지 않고, 씬에 컷인 연출이 있으면 연출을 먼저 재생한다.
## 실제 발동은 연출이 끝난 뒤 fire_ultimate_now()로 이뤄진다.
## 상대와 같은 타이밍에 궁극기를 함께 쓰면(클래시) 진 쪽은 컷인조차 뜨지 않고 쿨타임만 소모된다
func use_ultimate() -> void:
	if skill_ultimate == null or is_feared or is_busy() or not skill_ultimate.can_use():
		return
	var manager: Node = _get_clash_manager()
	if manager:
		manager.request(self, "ultimate", func(): _play_ultimate_cutin(), func(): skill_ultimate.cancel_use())
	else:
		_play_ultimate_cutin()

func _play_ultimate_cutin() -> void:
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
	if basic_attack == null or is_feared or is_busy() or not basic_attack.can_use():
		return
	var manager: Node = _get_clash_manager()
	if manager:
		manager.request(self, "basic_attack", func(): _fire_basic_attack(), func(): basic_attack.cancel_use())
	else:
		_fire_basic_attack()

func _fire_basic_attack() -> void:
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
	if _busy_time > 0.0:
		_busy_time = maxf(_busy_time - delta, 0.0)
	if not is_on_floor():
		velocity.y += gravity * delta
	if movement_override:
		velocity.x = movement_override.get_move_velocity_x()
	move_and_slide()
	# 착지할 때마다 공중 점프 횟수를 다시 채운다 (move_and_slide 뒤라야 이번 프레임의 착지가 반영된다)
	if is_on_floor():
		_air_jumps_left = max_air_jumps
	if movement_override:
		movement_override.after_physics(self, delta)
