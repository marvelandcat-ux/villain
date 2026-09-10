class_name Fighter
extends CharacterBody2D

## 모든 캐릭터 씬이 공통으로 쓰는 베이스 스크립트.
## 캐릭터 전용 .gd는 만들지 않고, 스탯 리소스(stats)와 스킬 노드(Skill1/Skill2/SkillUltimate/BasicAttack) 조합만으로 새 캐릭터를 만든다.

## HP가 바뀔 때마다 UI 등에 알린다
signal health_changed(current: int, max: int)
## HP가 0이 되면 알린다 — Stage.gd가 이 시그널을 듣고 승패를 판정한다
signal died
## 기본공격을 실제로 발동시켰을 때 알린다 (분신이 기본공격을 따라 하는 스킬 등이 듣는다)
signal basic_attack_used
## 실제로 피해를 입은 순간 알린다 — 경감 후 깎인 양과 그때의 넉백을 같이 넘긴다.
## "맞으면 풀리는" 효과가 쓴다(놀이터 왕관이 몸에서 떨어져 나가는 처리).
## **health_changed로 대신하면 안 된다** — 회복할 때도 같이 날아오고, 넉백 방향을 알 수 없다.
## 가드로 완전히 막아 실제로 0이 깎였으면 발동하지 않는다
signal damaged(amount: int, knockback: Vector2)

## 캐릭터 고정 수치
@export var stats: CharacterStats

## 중력/점프력의 기본값 — 훈련장에서 이것저것 바꿔본 뒤 원래대로 되돌릴 때 쓴다
const DEFAULT_GRAVITY: float = 1150.0
const DEFAULT_JUMP_VELOCITY: float = -430.0
## 공중에서 한 번 더 뛰는 이단 점프의 세기. 지상 점프(-350, 71px)보다 세게 잡아서
## 둘을 이어 뛰면 약 172px까지 올라간다 — 지하철 승강장의 의자 발판(바닥에서 145px)이
## 지상 점프 한 번(71px)으로는 절대 안 닿고 이단 점프로만 닿게 하려고 정한 값.
## 의자를 이 높이에 둔 이유는 의자에 올라선 캐릭터가 열차 지붕(y=195)보다 확실히 위에 있어야 하기 때문
const DEFAULT_AIR_JUMP_VELOCITY: float = -510.0

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
## 기본공격 전용 공격속도 배수 — 1.5면 기본공격 쿨타임이 1.5배 빨리 돌아 50% 더 자주 때린다 (악플러 열등감 스킬)
var attack_speed_multiplier: float = 1.0
## 받는 데미지 감소율 (0.0=없음, 1.0=완전 무효) — 가드 스킬 등이 사용
var damage_reduction: float = 0.0
## true인 동안은 어떤 데미지도 받지 않는다 (예: 촉법소년 궁극기 사용 중)
var is_invincible: bool = false
## true인 동안은 무서워서 기본공격/스킬을 전혀 못 쓴다(이동은 가능) — 지하철 아저씨 공포 단소 등
var is_feared: bool = false
## true인 동안은 붙잡힌 상태라 이동·점프·공격·스킬을 전혀 못 쓰고 중력도 받지 않는다.
## 잡은 스킬(파일드라이버 등)이 apply_physics를 건너뛰게 해서 위치를 직접 조작할 수 있게 한다
var is_grabbed: bool = false
## 이번 프레임에 조작으로 들어온 좌우 입력(-1/0/1). 그네처럼 "누르고 있는 방향"이 필요한 기믹이 읽는다
var move_input: float = 0.0
## true면 점프할 때 개찰구를 뛰어넘는 듯한 연출이 추가된다 (지하철 아저씨 전용, 캐릭터 씬에서 켬)
@export var vault_jump: bool = false

## 캐릭터별 스킬이 자유롭게 쓰는 임시 데이터 저장소 (예: 주정뱅이 술 스택)
var custom_data: Dictionary = {}

## 스킬 모션(마시기/토하기/공격 등)이 재생되는 동안 다른 스킬·기본공격을 못 쓰게 막는 남은 시간(초).
## 이동은 막지 않는다(마시면서 걷기 등은 그대로). apply_physics에서 매 물리 프레임 줄어든다
var _busy_time: float = 0.0
## 피격 경직(히트스턴) 남은 시간(초). 0보다 크면 조작(이동·점프·스킬)을 막고 넉백 속도가 실려 미끄러진다
var _hitstun_time: float = 0.0
## 지금까지 연속으로 맞은 콤보 수와, 콤보가 유지되는 남은 시간
var _combo_count: int = 0
var _combo_timer: float = 0.0

## move_speed_multiplier 등을 여러 효과가 동시에 걸어도 서로 안 지우도록 관리하는 내부 저장소.
## {property: {id: value}} — 최종 배수는 같은 property에 걸린 값들을 전부 곱한 것
var _modifiers: Dictionary = {}
var _next_modifier_id: int = 0

func _ready() -> void:
	current_hp = stats.max_hp
	add_to_group("fighters")
	_ignore_other_fighters()
	if skill_1 == null:
		skill_1 = get_node_or_null("Skill1")
	if skill_2 == null:
		skill_2 = get_node_or_null("Skill2")
	if skill_ultimate == null:
		skill_ultimate = get_node_or_null("SkillUltimate")
	if basic_attack == null:
		basic_attack = get_node_or_null("BasicAttack")

## 캐릭터끼리는 서로의 몸을 밟고 올라설 수 없게 몸 충돌을 무시한다.
## 충돌 레이어를 통째로 바꾸지 않고 add_collision_exception_with로 "상대 캐릭터"만 예외 처리하는 이유:
## 레이어를 바꾸면 바닥·벽·발판까지 같이 영향을 받는다. 여기서 빼는 건 몸(CharacterBody2D)끼리의
## 충돌뿐이고, 공격 판정(Hitbox/Hurtbox)은 Area2D라 그대로 서로를 감지한다.
##
## 새로 스폰된 쪽이 자기 _ready()에서 이미 있던 캐릭터들과 양방향으로 걸어두므로,
## 라운드 리로드·훈련장 캐릭터 교체처럼 나중에 생기는 경우도 자동으로 처리된다
func _ignore_other_fighters() -> void:
	for other in get_tree().get_nodes_in_group("fighters"):
		if other == self or not (other is PhysicsBody2D):
			continue
		add_collision_exception_with(other)
		other.add_collision_exception_with(self)

## 캐릭터끼리 서로 밀어내 겹치지 않게 하는 최소 가로 간격(px). 몸 반지름(20)의 두 배쯤
const BODY_PUSH_WIDTH := 38.0
## 세로로 이만큼 넘게 벌어져 있으면(상대가 위에 있으면) 안 밀어낸다 — 점프로 넘어갈 수 있게
const BODY_PUSH_HEIGHT := 46.0

## 상대 캐릭터와 몸이 가로로 겹치면 서로 밀어내 통과하지 못하게 한다.
## 몸 충돌(add_collision_exception_with)은 그대로 무시하므로 세로로는 안 막혀서 머리 위에 올라서는 건 여전히 방지되고,
## 여기서는 가로로만 밀어낸다. 두 캐릭터가 각자 절반씩 밀어내므로 한두 프레임 안에 딱 붙어 떨어진다.
## move_and_collide로 밀어서 벽은 뚫지 않는다(상대에게 몰리면 벽에 막혀 코너에 갇힌다)
func _separate_from_others() -> void:
	for other in get_tree().get_nodes_in_group("fighters"):
		if other == self or not is_instance_valid(other):
			continue
		if absf(global_position.y - other.global_position.y) > BODY_PUSH_HEIGHT:
			continue
		var dx: float = global_position.x - other.global_position.x
		var dist: float = absf(dx)
		if dist >= BODY_PUSH_WIDTH:
			continue
		var dir: float = signf(dx)
		if dir == 0.0:
			# 완전히 겹쳤으면 인스턴스 순서로 방향을 갈라 서로 반대로 밀어낸다
			dir = 1.0 if get_instance_id() > other.get_instance_id() else -1.0
		move_and_collide(Vector2(dir * (BODY_PUSH_WIDTH - dist) * 0.5, 0.0))

## --- 피격 리액션(격투 게임식 히트 리액션) 튜닝값 ---
## 넉백 방향으로 기우는 각도(도) = 이 기본값 + 데미지 × 비례값, 최대 HIT_LEAN_MAX_DEG로 제한
const HIT_LEAN_BASE_DEG := 7.0
const HIT_LEAN_PER_DAMAGE := 0.4
const HIT_LEAN_MAX_DEG := 20.0
## 피격 시 살짝 떠오르는 팝업 세기(위로 튀는 속도) = 이 기본값 + 데미지 × 비례값, 최대 HIT_POP_MAX
## 피격 시 위로 뜨는 팝업 세기 — 옆보다 위로 날아가게 크게 잡는다
const HIT_POP_BASE := 220.0
const HIT_POP_PER_DAMAGE := 7.0
const HIT_POP_MAX := 400.0
## 들어온 수평 넉백을 이 배수로 조절한다. 1보다 작으면 옆으로 덜 밀린다(위로 뜨는 느낌 강조)
const KNOCKBACK_MULTIPLIER := 1.15
## 경직(히트스턴) 중 넉백 속도가 이 감속도(px/s²)로 줄며 미끄러진다
const HITSTUN_FRICTION := 900.0
## 최소 경직(체공) 시간 — 넉백이 작아도 이만큼은 떠 있는다
const HITSTUN_MIN := 0.3
const HITSTUN_MAX := 0.5
## 피격으로 떠 있는 동안(경직+공중) 적용할 중력 배수 — 1보다 작으면 평소보다 천천히 떨어져 잠깐 더 체공한다
const HIT_LAUNCH_GRAVITY_SCALE := 0.6
## 이 시간(초) 안에 다시 맞으면 콤보가 이어진다. 넘으면 다음 타격은 콤보 1부터 새로 시작
const COMBO_WINDOW := 1.5

## 데미지를 받는다. damage_reduction이 있으면 경감하고, 경감분은 custom_data["guard_absorbed"]에 누적된다.
## is_invincible이 true면 아예 무시한다
## pop_override: 위로 띄우는 힘(px/s)을 직접 지정한다. 음수(기본)면 데미지에 비례한 기본 팝업을 쓰고,
## 0이면 전혀 안 띄운다(지상 유지 — 콤보 앞 타격이 상대를 붙잡아두게). 콤보 마무리만 기본 팝업으로 크게 날린다
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, pop_override: float = -1.0) -> void:
	if is_invincible:
		return
	var reduced_amount: int = int(round(amount * (1.0 - damage_reduction)))
	if damage_reduction > 0.0:
		custom_data["guard_absorbed"] = custom_data.get("guard_absorbed", 0) + (amount - reduced_amount)
	current_hp = max(current_hp - reduced_amount, 0)
	_flash_hit()
	_play_hurt_face()
	# 실제 타격(넉백이 있는 피해)에만 히트 리액션 — 공포·틱 데미지 같은 넉백 없는 피해엔 적용 안 한다
	if knockback != Vector2.ZERO:
		# 수평 넉백을 키워 콤보처럼 넉백 방향으로 멀리 날린다 (수직은 팝업이 담당)
		var kb_x: float = knockback.x * KNOCKBACK_MULTIPLIER
		velocity.x += kb_x
		velocity.y += knockback.y
		# 살짝 공중으로 떠오르게 (이미 그보다 크게 위로 뜨는 넉백은 그대로 둔다).
		# pop_override가 0 이상이면 그 값을 쓴다 — 0이면 안 띄워서 지상에 붙잡아둔다
		var pop: float = pop_override if pop_override >= 0.0 else clampf(HIT_POP_BASE + amount * HIT_POP_PER_DAMAGE, 0.0, HIT_POP_MAX)
		if pop > 0.0:
			velocity.y = minf(velocity.y, -pop)
		# 경직: 이 동안 조작으로 velocity.x를 못 덮어써서 넉백이 실려 미끄러진다.
		# 길이 = 마찰이 넉백 속도를 멈추는 데 걸리는 시간이라, 미끄러져 멈추는 순간 조작이 돌아온다
		_hitstun_time = clampf(absf(kb_x) / HITSTUN_FRICTION, HITSTUN_MIN, HITSTUN_MAX)
		# 콤보 카운트 — 유지 시간 안에 다시 맞으면 누적, 끊겼으면 1부터
		if _combo_timer <= 0.0:
			_combo_count = 0
		_combo_count += 1
		_combo_timer = COMBO_WINDOW
		_play_hit_reaction(knockback, amount)
	else:
		velocity += knockback
	health_changed.emit(current_hp, stats.max_hp)
	_update_hp_face()
	# 실제로 깎였을 때만 — 가드로 전부 막았으면 "맞았다"고 치지 않는다
	if reduced_amount > 0:
		damaged.emit(reduced_amount, knockback)
	if current_hp <= 0:
		died.emit()

## 지금까지 연속으로 맞은 콤보 수 (데미지 팝업이 "N HIT" 표시에 쓴다)
func get_combo_count() -> int:
	return _combo_count

## 피격 시 넉백 방향으로 몸을 살짝 기울였다가 되돌린다 (데미지가 클수록 크게 기운다)
func _play_hit_reaction(knockback: Vector2, amount: int) -> void:
	var visual: Node2D = get_node_or_null("Visual")
	if visual == null:
		return
	var dir: float = signf(knockback.x)
	if dir == 0.0:
		dir = -facing   # 수평 넉백이 없으면 뒤로(바라보는 반대쪽) 기운다
	var lean_deg: float = clampf(HIT_LEAN_BASE_DEG + amount * HIT_LEAN_PER_DAMAGE, 0.0, HIT_LEAN_MAX_DEG)
	var tween := create_tween()
	tween.tween_property(visual, "rotation", deg_to_rad(dir * lean_deg), 0.05)
	tween.tween_property(visual, "rotation", 0.0, 0.22)

## 맞았을 때 잠깐 아파하는 얼굴로 바꾼다 (그 표정이 있는 캐릭터만 — 없으면 그냥 넘어간다)
func _play_hurt_face() -> void:
	var visual: Node = get_node_or_null("Visual")
	if visual and visual.has_method("play_hurt_face"):
		visual.play_hurt_face()

## 남은 HP 비율을 몸에 알려준다 — HP가 얼마 안 남으면 지친 얼굴로 바뀐다.
## 그 표정이 없는 캐릭터나 임시 사각형 비주얼이면 그냥 넘어간다. HP가 바뀔 때마다 부른다
func _update_hp_face() -> void:
	var visual: Node = get_node_or_null("Visual")
	if visual and visual.has_method("update_hp_ratio"):
		var max_hp: int = stats.max_hp if stats else 0
		visual.update_hp_ratio(float(current_hp) / float(max_hp) if max_hp > 0 else 1.0)

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
	_update_hp_face()

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

## 밖에서 경직을 걸어준다 (놀이터에서 왕관을 떨어뜨렸을 때 등).
## 이미 걸린 경직보다 짧으면 무시한다 — 짧은 값으로 덮어써서 경직이 오히려 일찍 풀리는 걸 막는다
func apply_hitstun(duration: float) -> void:
	_hitstun_time = maxf(_hitstun_time, duration)

## 지금 경직 중인가 (이동·점프·스킬이 막혀 있는 상태)
func is_in_hitstun() -> bool:
	return _hitstun_time > 0.0

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
	_update_hp_face()
	died.emit()

## 기본 공격력에 캐릭터 배율과 디버프를 반영한 최종 데미지를 계산한다
func compute_damage(base_damage: int) -> int:
	return int(round(base_damage * stats.attack_multiplier * attack_debuff_multiplier))

func move(direction: float) -> void:
	# 실제로 움직이지 못하는 상황(경직 등)에도 "무슨 방향을 누르고 있는지"는 남긴다 —
	# 그네처럼 이동이 아니라 입력 자체를 읽어야 하는 기믹이 이 값을 본다
	move_input = direction
	# 피격 경직 중엔 조작으로 넉백 속도를 덮어쓰지 않는다 (그래야 넉백 방향으로 날아간다)
	if _hitstun_time > 0.0 or is_grabbed:
		return
	if direction != 0.0:
		facing = signf(direction)
	velocity.x = direction * stats.move_speed * move_speed_multiplier

## 바닥에서는 보통 점프, 공중에서는 남은 횟수만큼 이단 점프.
## 이단 점프는 지금까지의 낙하 속도를 무시하고 속도를 새로 덮어써서, 떨어지는 중에 눌러도 제대로 뜬다
func jump() -> void:
	# 경직 중엔 점프로 넉백을 못 벗어난다
	if _hitstun_time > 0.0 or is_grabbed:
		return
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

## 개찰구를 훌쩍 뛰어넘는 듯한 점프 연출 (지하철 아저씨 전용)
func _play_vault_effect() -> void:
	var visual: Node2D = get_node_or_null("Visual")
	if visual == null:
		return
	var tween := create_tween()
	tween.tween_property(visual, "rotation", facing * -0.5, 0.15)
	tween.tween_property(visual, "rotation", 0.0, 0.15)

## 지금 스킬 모션 중이라 다른 행동을 못 하는 상태인지
func is_busy() -> bool:
	return _busy_time > 0.0 or _hitstun_time > 0.0

## duration초 동안 다른 스킬·기본공격 입력을 막는다 (모션이 겹쳐 나오지 않게). 이동은 계속 가능하다.
## 더 긴 잠금이 이미 걸려 있으면 짧은 걸로 줄어들지 않게 둘 중 큰 값을 쓴다
func start_busy(duration: float) -> void:
	_busy_time = maxf(_busy_time, duration)

## 씬에 SkillClashManager가 있으면(1대1 대전 맵) 반환하고, 없으면(훈련장 등) null
func _get_clash_manager() -> Node:
	return get_tree().get_first_node_in_group("skill_clash_manager")

func use_skill_1() -> void:
	if skill_1 == null or is_feared or is_grabbed or is_busy() or not skill_1.can_use():
		return
	var manager: Node = _get_clash_manager()
	if manager:
		manager.request(self, "skill_1", func(): skill_1.use(self), func(): skill_1.cancel_use())
	else:
		skill_1.use(self)

func use_skill_2() -> void:
	if skill_2 == null or is_feared or is_grabbed or is_busy() or not skill_2.can_use():
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
	if skill_ultimate == null or is_feared or is_grabbed or is_busy() or not skill_ultimate.can_use():
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

## 기본공격은 스킬 클래시(연타 미니게임)에 태우지 않는다 — 스킬1/2/궁극기보다 훨씬 자주 나가는 잽이라,
## 여기까지 클래시로 걸리면 마주칠 때마다 화면이 멈추고 연타 게임이 뜨는 꼴이 된다. 항상 바로 나간다
func use_basic_attack() -> void:
	if basic_attack == null or is_feared or is_grabbed or is_busy() or not basic_attack.can_use():
		return
	_fire_basic_attack()

func _fire_basic_attack() -> void:
	basic_attack.use(self)
	# 콤보 평타처럼 스킬이 타별 스윙을 직접 재생하는 경우엔 여기서 기본 스윙을 덧대지 않는다
	if not basic_attack.handles_own_visual():
		_play_visual_attack()
	basic_attack_used.emit()

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
	# 붙잡힌 동안은 중력·이동을 전부 건너뛴다 — 잡은 스킬(파일드라이버 등)이 global_position을
	# 직접 옮기므로, 여기서 물리를 건드리면 서로 부딪혀 위치가 튄다
	if is_grabbed:
		velocity = Vector2.ZERO
		return
	if _busy_time > 0.0:
		_busy_time = maxf(_busy_time - delta, 0.0)
	# 경직 중엔 넉백 속도가 마찰로 서서히 줄며 미끄러진다 (멈출 때쯤 경직도 끝나 조작이 돌아온다)
	if _hitstun_time > 0.0:
		_hitstun_time = maxf(_hitstun_time - delta, 0.0)
		velocity.x = move_toward(velocity.x, 0.0, HITSTUN_FRICTION * delta)
	if _combo_timer > 0.0:
		_combo_timer = maxf(_combo_timer - delta, 0.0)
	if not is_on_floor():
		# 피격으로 떠 있는 동안엔 중력을 줄여 잠깐 더 체공하게 한다 (옆보다 위로 뜨는 넉백과 어울림)
		var g: float = gravity
		if _hitstun_time > 0.0:
			g *= HIT_LAUNCH_GRAVITY_SCALE
		velocity.y += g * delta
	if movement_override:
		velocity.x = movement_override.get_move_velocity_x()
	move_and_slide()
	# 착지할 때마다 공중 점프 횟수를 다시 채운다 (move_and_slide 뒤라야 이번 프레임의 착지가 반영된다)
	if is_on_floor():
		_air_jumps_left = max_air_jumps
	if movement_override:
		movement_override.after_physics(self, delta)
	# 상대 캐릭터와 겹쳤으면 가로로 밀어내 통과하지 못하게 한다
	_separate_from_others()
