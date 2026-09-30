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

## 마지막으로 맞았을 때 밀려난 가로 방향(+1 오른쪽, 0이면 아직 안 맞음).
## 처치 연출(Stage)이 이 방향으로 날려보낸다 — "맞은 방향의 반대쪽"이 곧 넉백 방향이다
var last_hit_direction: float = 0.0

## 중력/점프력의 기본값 — 훈련장에서 이것저것 바꿔본 뒤 원래대로 되돌릴 때 쓴다
const DEFAULT_GRAVITY: float = 1150.0
## **2026-09-15: -430 -> -215(반토막) -> -260 -> -190 -> -300 -> -350 -> -430 -> -470(공중 -510) -> -705(공중 -765, 1.5배) -> -478(공중 -519, 이단 점프 = 직전 한 번 점프 높이).** 전부 사용자 요청이다.
## ⚠️ **높이는 속도의 제곱에 비례한다** — 속도를 반으로 줄이면 높이는 1/4이 된다.
## 높이 = 속도² / (2 x 중력). 중력 1150 기준 지상 점프 높이:
## -190은 17px / -215는 22px / -260은 32px / -300은 39px / -350은 53px / -430은 84px
const DEFAULT_JUMP_VELOCITY: float = -478.0
## 공중에서 한 번 더 뛰는 이단 점프의 세기.
## **2026-09-17 기준 -519**(지상 -478의 약 1.09배 — 이단 점프가 직전 "한 번 점프" 높이만큼 더 뜬다).
## 이단 점프가 약 209px(계산값)이라 지하철 의자(145px)·놀이터 3단(최대 190px)·공사현장(170px) 발판에 다시 올라간다
const DEFAULT_AIR_JUMP_VELOCITY: float = -519.0

## --- 방향키 두 번 대시 (전 캐릭터 공용, 스킬이 아니라 기본 조작이다) ---
## 대시하는 동안의 수평 속도(px/초). 걷기(240~275)의 약 다섯 배.
## **2026-09-14에 700 -> 1400으로 올렸다**(사용자 요청 "훨씬 빠르게") — 700은 걷기의 2.6배뿐이라
## 순간이동하듯 "슉" 빠지는 맛이 없었다
const DEFAULT_DASH_SPEED: float = 1400.0
## 대시가 유지되는 시간(초). **속도 x 시간이 곧 이동 거리다** — 1400 x 0.16 = 224px(몸통 폭의 약 5.6배).
## 속도를 올리면서 시간을 0.18에서 줄인 이유: 그대로 두면 252px까지 가서 화면의 5분의 1을 한 번에 건너뛰고,
## 조작이 돌아오기까지도 그만큼 오래 걸린다
const DEFAULT_DASH_DURATION: float = 0.16
## 다음 대시까지 기다리는 시간(초)
const DEFAULT_DASH_COOLDOWN: float = 3.0
## 대시 중 잔상을 남기는 간격(초)
const DASH_TRAIL_INTERVAL: float = 0.04
## 그네에 튕기거나 스프링 시소로 높이 튈 때 날아가는 몸 뒤로 남기는 잔상(start_air_trail)의 간격·처음 투명도·사라지는 시간.
## 촉법소년 자전거(DashSkill) 잔상과 같은 값이라 같은 느낌이 난다
const AIR_TRAIL_INTERVAL: float = 0.04
const AIR_TRAIL_ALPHA: float = 0.45
const AIR_TRAIL_FADE: float = 0.25

## --- 아래 키 방어 (전 캐릭터 공용) ---
## 아래 키를 누른 순간 켜져서 이 시간(초) 동안 유지된다. 누르고 있는 게 아니라 한 번 눌러 발동하는 방식
const DEFAULT_GUARD_DURATION: float = 1.0
## 방어가 끝나고 다음 방어까지 기다리는 시간(초)
const DEFAULT_GUARD_COOLDOWN: float = 5.0
## 기본공격이 상대 방어에 막혔을 때 기본공격이 잠기는 시간(초).
## 무기가 빨갛게 깜빡이는 시간과 같은 값이라 "빨간 동안엔 못 때린다"가 눈으로 읽힌다
const DEFAULT_BLOCKED_ATTACK_LOCK: float = 3.0
## 방어할 때 몸을 감싸는 원형 보호막
const GUARD_SHIELD_SCRIPT := preload("res://combat/GuardShield.gd")

## --- 착지 먼지 (전 캐릭터 공용) ---
## **모든 착지**에서 발 양옆으로 먼지 뭉치가 나가고, 크기는 떨어진 높이에 비례한다(2026-09-26 사용자 요청).
## land_dust_height = **기본 크기(세기 1)가 되는 높이(px)** — 이보다 낮게 떨어지면 작게, 높으면 크게.
## **높이로 적는 이유:** 점프력·중력을 바꿔도 "이만큼 떨어지면 이 크기"가 그대로 유지된다.
## **음수(기본 -1)면 "이단 점프 최고 높이"를 점프력·중력에서 그때그때 계산해 쓴다** — 지금 값(-478/-519, 중력 1150)이면 약 216px.
## 0이면 안 난다(착지 경직이 걸린 착지만 난다). **착지 경직이 걸린 착지는 최소 기본 크기로 난다**
const DEFAULT_LAND_DUST_HEIGHT: float = -1.0
static var land_dust_height: float = DEFAULT_LAND_DUST_HEIGHT
## 이보다 낮게 떨어진 착지(px)는 먼지가 안 난다 — 턱을 살짝 내려오거나 발판 끝을 걸어 내려올 때까지 매번 나면 지저분하다
static var land_dust_min_height: float = 20.0
## 착지 경직(2026-09-25) — 이 높이(px) 이상에서 떨어져 착지하면 무릎을 굽힌 채 LANDING_LAG_TIME 동안 아무것도 못 한다.
## 점프(특히 이단 점프) 연타를 막으려는 것. 이단 점프 최고 높이(약 216px)보다 조금 낮게 잡았다 —
## 한 번 점프(약 103px)와 두 번째 점프를 바로 이어 누른 이단 점프(약 150px)는 안 걸린다.
## 0이면 꺼진다. 맞아서 날아가다 떨어진 착지는 안 걸린다
const DEFAULT_LANDING_LAG_HEIGHT: float = 180.0
static var landing_lag_height: float = DEFAULT_LANDING_LAG_HEIGHT
## 착지 경직 시간(초) — 2026-09-26 사용자 요청으로 0.5 -> 0.3
static var landing_lag_time: float = 0.3
## 착지 먼지 이펙트 (그림 없이 _draw()로 그린다)
const LAND_DUST_SCRIPT := preload("res://combat/LandDust.gd")
## 점프할 때 발밑에 남는 바람 줄기 (그림 없이 _draw()로 그린다)
const JUMP_WIND_SCRIPT := preload("res://combat/JumpWind.gd")

## 통과 가능한 발판(one_way_collision)을 뚫고 내려갈 때 그 발판과의 충돌을 꺼두는 시간(초).
## 발판 두께(20px)를 지나 떨어지는 데 필요한 시간(약 0.21초)보다 넉넉하게 잡았다
const DROP_THROUGH_DURATION: float = 0.35

## 모든 Fighter가 함께 쓰는 중력/점프력. 아직 값을 정하는 중이라 훈련장(maps/TrainingGround.gd)에서
## 실시간으로 바꿔볼 수 있게 static var로 두었다 — 값이 확정되면 위 DEFAULT_ 상수에 옮겨 적으면 된다.
## 점프력은 위쪽이 음수라서 -350처럼 음수 값이다
static var gravity: float = DEFAULT_GRAVITY
## 떨어질 때(꼭대기를 지나 아래로 내려갈 때)만 중력에 곱하는 배수(2026-09-25) — 올라갈 때는 그대로라
## 점프 높이는 안 바뀌고, 내려올 때만 툭 떨어져 둥둥 떠 보이지 않는다(대난투·브롤할라식).
## 1이면 예전과 같다. **맞아서 날아가는 중(경직)에는 안 곱한다** — 콤보 마무리의 날아가는 궤적을 맞춰 둔 값이라서
## (1.6으로 넣었다가 "떨어질 때 너무 세다"는 사용자 요청으로 1.0 — 올라갈 때와 같게 — 으로 되돌렸다)
const DEFAULT_FALL_GRAVITY_MULTIPLIER: float = 1.0
static var fall_gravity_multiplier: float = DEFAULT_FALL_GRAVITY_MULTIPLIER
static var jump_velocity: float = DEFAULT_JUMP_VELOCITY
static var air_jump_velocity: float = DEFAULT_AIR_JUMP_VELOCITY
## 바닥에서 뛴 뒤 공중에서 추가로 뛸 수 있는 횟수. 1이면 이단 점프, 0이면 예전처럼 바닥에서만 점프
static var max_air_jumps: int = 1
## 대시 값도 중력·점프력과 같이 전 캐릭터가 공유하고 훈련장에서 바로 바꿔볼 수 있게 static var로 둔다
static var dash_speed: float = DEFAULT_DASH_SPEED
static var dash_duration: float = DEFAULT_DASH_DURATION
static var dash_cooldown: float = DEFAULT_DASH_COOLDOWN
static var guard_duration: float = DEFAULT_GUARD_DURATION
static var guard_cooldown: float = DEFAULT_GUARD_COOLDOWN
static var blocked_attack_lock: float = DEFAULT_BLOCKED_ATTACK_LOCK

var current_hp: int = 0
var facing: float = 1.0
## 지금 공중에서 몇 번 더 뛸 수 있는지. 바닥에 닿을 때마다 max_air_jumps로 다시 채워진다
var _air_jumps_left: int = 0
## 직전 프레임에 바닥에 있었는지 — "이번 프레임에 착지했다"를 잡는 데 쓴다
var _was_on_floor: bool = true
## 대시가 남은 시간 / 대시 방향 / 다음 대시까지 남은 쿨타임 / 다음 잔상까지 남은 시간
var _dash_time: float = 0.0
var _dash_dir: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_trail_timer: float = 0.0
## 날아갈 때 잔상이 남은 시간 / 다음 잔상까지 남은 시간 (start_air_trail이 켠다)
var _air_trail_left: float = 0.0
var _air_trail_timer: float = 0.0
## 방어(보호막)가 켜져 있는지. 이 동안은 어떤 공격도 데미지·넉백이 전부 0이다
var is_guarding: bool = false
## 방어가 유지되는 남은 시간 / 다음 방어까지 남은 쿨타임
var _guard_time: float = 0.0
var _guard_cooldown_left: float = 0.0
## 기본공격이 막혀서 기본공격이 잠겨 있는 남은 시간(초)
var _blocked_attack_left: float = 0.0
## 방어 중에 몸을 감싸는 원형 보호막 (처음 방어할 때 만든다).
## 타입을 안 붙인 이유 — GuardShield는 preload로 가져오는 새 class_name이라, 타입을 붙이면
## 전역 클래스 캐시가 갱신되기 전에는 set_active()를 못 찾는다고 파싱 에러가 난다
var _shield = null

## 자식 노드 이름(Skill1/Skill2/SkillUltimate/BasicAttack)으로 자동 연결되는 스킬 슬롯.
## 스탠스 전환처럼 특수한 캐릭터는 직접 다시 할당해서 바꿀 수 있다
var skill_1: Skill
var skill_2: Skill
var skill_ultimate: Skill
var basic_attack: Skill

## 캐릭터 씬이 아니라 "맵"이 스폰 시점에 심어주는 전용 스킬(예: 아파트 내리찍기).
## Stage.gd가 map_skill_scene을 지정한 맵에서만 채워지고, 그 외 맵에서는 null이라
## 컨트롤러가 그냥 아무 일도 하지 않는다
var map_skill: Skill = null

## 돌진처럼 이동을 잠깐 가로채는 스킬이 자신을 등록해두는 슬롯.
## get_move_velocity_x()와 after_physics(fighter, delta)를 구현한 오브젝트여야 한다.
## 타입을 지정하지 않아야 서로 다른 스킬 클래스를 덕 타이핑으로 담을 수 있다
var movement_override = null
## 카운터 자세(`CounterSkill`)가 자신을 등록해두는 슬롯. 이게 있는 동안 캐릭터의 공격에 맞으면
## 피해 대신 `trigger_counter(fighter)`가 불린다(`try_counter()`). 타입은 movement_override와 같은 이유로 비워 둔다
var counter_stance = null

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
## 슈퍼아머를 걸어둔 스킬 수. 0보다 크면 **맞아도 기술이 안 끊긴다** — HP는 깎이고 피격 반짝임·표정도 나오지만
## 넉백·띄우기·경직·피격 기울기·구르기는 무시하고, 잡기 기술에도 안 잡힌다(`can_be_grabbed()`).
## bool이 아니라 개수인 이유: 아머를 거는 기술이 겹쳤다 먼저 끝난 쪽이 풀어버리면 남은 쪽 아머까지 사라진다.
## 거는 쪽은 반드시 add/remove를 짝으로 부를 것(바디 수플렉스 `BackSuplexSkill.super_armor`)
var _super_armor: int = 0
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
## 넉백을 받고 아직 착지하지 않았는지 — 이 동안엔 move()가 가로 속도를 덮어쓰지 않고 날아가던 힘을 유지한다
var _launch_momentum: bool = false
## 남은 착지 경직(초) — 0보다 크면 이동·점프·대시·방어·공격·스킬이 전부 막힌다
var _landing_lag: float = 0.0
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
## 맞고 날아가는 동안(착지 전) 방향키로 가로 속도를 바꿀 수 있는 가속도(px/s²). 작을수록 날아가는 힘을 못 거스른다
const LAUNCH_AIR_CONTROL := 900.0
## 맞고 날아가는 동안 방향키를 안 누르면 가로 속도가 줄어드는 정도(px/s²). 0이면 착지할 때까지 그대로 날아간다
const LAUNCH_AIR_DRAG := 300.0
## 피격으로 떠 있는 동안(경직+공중) 적용할 중력 배수 — 1보다 작으면 평소보다 천천히 떨어져 잠깐 더 체공한다
const HIT_LAUNCH_GRAVITY_SCALE := 0.6
## 이 시간(초) 안에 다시 맞으면 콤보가 이어진다. 넘으면 다음 타격은 콤보 1부터 새로 시작
const COMBO_WINDOW := 1.5

## 데미지를 받는다. damage_reduction이 있으면 경감하고, 경감분은 custom_data["guard_absorbed"]에 누적된다.
## is_invincible이 true면 아예 무시한다
## pop_override: 위로 띄우는 힘(px/s)을 직접 지정한다. 음수(기본)면 데미지에 비례한 기본 팝업을 쓰고,
## 0이면 전혀 안 띄운다(지상 유지 — 콤보 앞 타격이 상대를 붙잡아두게). 콤보 마무리만 기본 팝업으로 크게 날린다
## 맵 기믹이 주는 피해 — 지나가는 열차, 떨어지는 화분, 층간소음 충격파처럼
## **주인(공격한 캐릭터)이 없는 피해**는 전부 이 함수를 거친다.
##
## 캐릭터의 공격과 달리 **방어로 막히지 않는다.** 열차를 방어로 버틸 수 있으면
## 의자로 피해 올라갈 이유가 없어져서 기믹 자체가 죽기 때문이다.
##
## **맵 피해에만 붙일 처리는 앞으로 전부 여기에 넣을 것** — 여기 한 줄을 추가하면
## 열차·화분·충격파에 한꺼번에 적용된다. 지금은 방어를 무시하는 것 하나뿐이다.
## (맵 히트박스는 `Hurtbox.take_hit()`이 `source_fighter == null`을 보고 이쪽으로 보내고,
##  히트박스 없이 직접 때리는 기믹은 `StompZone`처럼 이 함수를 직접 부른다)
func take_map_damage(amount: int, knockback: Vector2 = Vector2.ZERO, pop_override: float = -1.0) -> void:
	# **맞으면 방어가 깨진다.** 데미지만 통과시키면 넉백이 지워진다 —
	# 방어 중에는 apply_physics가 "제자리에 버틴다"고 매 프레임 velocity.x를 0으로 만들기 때문에,
	# 열차에 맞아도 그 자리에 붙박이로 서 있게 된다(실측으로 잡은 문제).
	# 쿨타임은 정상적으로 물린다 — 기믹 앞에서 방어를 켠 건 그만큼 손해여야 한다
	if is_guarding:
		cancel_guard()
	take_damage(amount, knockback, pop_override, true)

## 피해를 입는다. **맵 기믹이 주는 피해는 이 함수가 아니라 take_map_damage()를 쓸 것** —
## ignore_guard는 그쪽이 넘겨주는 값이라 바깥에서 직접 true로 주면 두 경로가 갈라진다
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, pop_override: float = -1.0, ignore_guard: bool = false) -> void:
	if is_invincible:
		return
	# 카운터 자세 중이면 피해 대신 반격 — 판정 없이 직접 피해를 주는 스킬(자전거 돌진 등)용.
	# 판정이 때린 경우는 Hurtbox.take_hit()이 먼저 가로챈다. 맵 피해(ignore_guard)·넉백 없는 도트 틱은 카운터 못 함
	if not ignore_guard and knockback != Vector2.ZERO and try_counter():
		return
	# 3타로 날아가는 중 추가타를 맞으면 위아래 속도는 맞기 전 그대로 둔다(_rebound_finisher) — 아래 넉백·팝업이 바꾸기 전에 기억
	var vy_before_hit: float = velocity.y
	# 방어 중엔 캐릭터의 공격이 통하지 않는다 — 데미지도 넉백도 없다(무적과 같은 취급).
	# **단 맵 기믹(지나가는 열차·화분 등)은 방어로 못 막는다** — ignore_guard로 그냥 통과한다.
	# 막아낸 양은 얼마나 잘 막았는지 볼 수 있게 누적해둔다
	if is_guarding and not ignore_guard:
		custom_data["guard_absorbed"] = custom_data.get("guard_absorbed", 0) + amount
		return
	var reduced_amount: int = int(round(amount * (1.0 - damage_reduction)))
	if damage_reduction > 0.0:
		custom_data["guard_absorbed"] = custom_data.get("guard_absorbed", 0) + (amount - reduced_amount)
	current_hp = max(current_hp - reduced_amount, 0)
	_flash_hit()
	_play_hurt_face()
	# 실제 타격(넉백이 있는 피해)에만 히트 리액션 — 공포·틱 데미지 같은 넉백 없는 피해엔 적용 안 한다
	# 슈퍼아머 중엔 HP만 깎이고 몸은 안 밀린다 — 넉백·띄우기·경직·기울기가 들어가면 잡고 있던 기술이 망가진다
	# (공중으로 붕 뜬 채 상대를 꽂거나, 경직으로 굳어 몸이 휙 돌아가는 식). 콤보 수는 그대로 센다
	if knockback != Vector2.ZERO and has_super_armor():
		if _combo_timer <= 0.0:
			_combo_count = 0
		_combo_count += 1
		_combo_timer = COMBO_WINDOW
	elif knockback != Vector2.ZERO:
		# 수평 넉백을 키워 콤보처럼 넉백 방향으로 멀리 날린다 (수직은 팝업이 담당)
		var kb_x: float = knockback.x * KNOCKBACK_MULTIPLIER
		velocity.x += kb_x
		_launch_momentum = true
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
	# 실제로 깎였을 때만 — 가드로 전부 막았으면 "맞았다"고 치지 않는다
	if reduced_amount > 0:
		# 처치 연출이 "마지막으로 맞은 반대쪽(=넉백 방향)"으로 날려보낼 때 쓴다.
		# 수평 넉백이 없는 공격이면 바라보던 반대쪽으로 친다
		if not is_zero_approx(knockback.x):
			last_hit_direction = signf(knockback.x)
		elif last_hit_direction == 0.0:
			last_hit_direction = -facing
		damaged.emit(reduced_amount, knockback)
		# 날아가며 기절한 동안 또 맞았으면 때린 방향으로 다시 날아가고 날아가는 시간이 늘어난다 — 공격 종류(맵 공격 포함)는 안 가린다.
		# 이번 타가 새 3타면 이 뒤에 ComboMeleeAttack이 때린 쪽 방향으로 다시 날리므로 그쪽이 이긴다
		if _finisher_window > 0.0:
			_rebound_finisher(knockback.x, vy_before_hit)
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
	# 이미 굴러가는 중이면 기울기를 얹지 않는다 — 매 프레임 도는 각도와 트윈이 서로 각도를 뺏어
	# 덜덜 떨린다. 구르기가 끝나면 일어서는 트윈이 알아서 각도를 정리한다
	if _tumble_left > 0.0:
		return
	# 조각 몸(BodyRig)이면 몸 전체를 뒤로 기울이는 대신 "배를 맞은" 움찔 자세를 쓴다(2026-09-25 사용자 요청) —
	# 상체를 앞으로 숙이고 엉덩이를 빼고 두 손을 앞으로 모은다. 세기는 0.6에서 시작해 데미지 1당 0.05씩(잽 3 = 0.75, 7 = 0.95)
	if visual.has_method("play_hit_flinch"):
		# 그림이 밀리는 쪽 = 넉백 방향을 리그 기준으로 바꾼 것(리그는 왼쪽을 볼 때 좌우가 뒤집혀 있다).
		# 수평 넉백이 없으면 뒤로 민다
		var push_dir: float = -1.0
		if not is_zero_approx(knockback.x):
			push_dir = signf(knockback.x) * (1.0 if facing >= 0.0 else -1.0)
		visual.play_hit_flinch(clampf(0.6 + amount * 0.05, 0.6, 1.0), push_dir)
		return
	var dir: float = signf(knockback.x)
	if dir == 0.0:
		dir = -facing   # 수평 넉백이 없으면 뒤로(바라보는 반대쪽) 기운다
	var lean_deg: float = clampf(HIT_LEAN_BASE_DEG + amount * HIT_LEAN_PER_DAMAGE, 0.0, HIT_LEAN_MAX_DEG)
	# 이 트윈을 기억해둔다 — 뒤이어 크게 날아가는 타(발차기 마무리)가 들어오면 몸을 굴려야 하는데,
	# 이 기울기 트윈이 살아 있으면 매 프레임 rotation을 도로 제자리로 끌어당겨 구르기가 안 보인다
	if _lean_tween != null and _lean_tween.is_valid():
		_lean_tween.kill()
	_lean_tween = create_tween()
	_lean_tween.tween_property(visual, "rotation", deg_to_rad(dir * lean_deg), 0.05)
	_lean_tween.tween_property(visual, "rotation", 0.0, 0.22)

## --- 크게 날아갈 때 구르기 (촉법소년 3타 발차기 등) ---
## 구르기가 끝난 뒤 똑바로 서기까지 걸리는 시간(초)
const TUMBLE_RECOVER := 0.16
## 날아오른 직후 이만큼(초)은 바닥 판정을 보지 않는다 — 맞은 그 프레임엔 아직 발이 땅에 닿아 있어서,
## 바로 검사하면 구르기가 시작하자마자 끝나버린다
const TUMBLE_GROUND_GRACE := 0.14

## 피격 기울기 트윈 (구르기가 시작되면 꺼야 한다)
var _lean_tween: Tween = null
## 남은 구르기 시간(초)과 도는 속도(라디안/초)
var _tumble_left: float = 0.0
var _tumble_speed: float = 0.0
var _tumble_grace: float = 0.0

## 몸이 빙글빙글 돌면서 날아간다. turns=도는 바퀴 수, duration=도는 시간(초),
## spin_dir=도는 방향(+1이면 시계방향 = 오른쪽으로 날아갈 때). **바닥에 닿으면 그 자리에서 멈춘다**
func play_launch_tumble(turns: float, duration: float, spin_dir: float) -> void:
	var visual: Node2D = get_node_or_null("Visual")
	if visual == null or turns <= 0.0 or duration <= 0.0 or has_super_armor():
		return
	if _lean_tween != null and _lean_tween.is_valid():
		_lean_tween.kill()
	var dir: float = 1.0 if spin_dir >= 0.0 else -1.0
	_tumble_left = duration
	_tumble_grace = TUMBLE_GROUND_GRACE
	_tumble_speed = dir * TAU * turns / duration

## 매 물리 프레임 — 구르는 중이면 몸을 돌리고, 끝나거나 착지하면 똑바로 세운다
func _update_tumble(delta: float) -> void:
	var visual: Node2D = get_node_or_null("Visual")
	if visual == null:
		_tumble_left = 0.0
		return
	_tumble_grace = maxf(_tumble_grace - delta, 0.0)
	_tumble_left = maxf(_tumble_left - delta, 0.0)
	# 3타로 땅에 튕겨 다시 떠오르는 순간(위로 가는 중)은 착지로 치지 않는다 — 튕길 때마다 구르기가 끊기지 않게
	var landed: bool = _tumble_grace <= 0.0 and is_on_floor() and velocity.y >= 0.0
	if _tumble_left <= 0.0 or landed:
		_tumble_left = 0.0
		# 돌던 각도를 -180~180도로 접어두고 가까운 쪽으로 일어선다 (안 접으면 몇 바퀴를 되감는다)
		visual.rotation = wrapf(visual.rotation, -PI, PI)
		if _lean_tween != null and _lean_tween.is_valid():
			_lean_tween.kill()
		_lean_tween = create_tween()
		_lean_tween.tween_property(visual, "rotation", 0.0, TUMBLE_RECOVER)
		return
	visual.rotation += _tumble_speed * delta

## --- 3타 공격 날리기 (스매시식, 2026-09-29) ---
## 콤보 마무리 타(3타)에 맞으면 **날아가며 기절해 있는 동안** 어떤 공격이든(맵 공격 포함) 또 맞으면
## 때린 방향으로 다시 날아가고, 날아가는(기절) 시간이 FINISHER_EXTRA_TIME만큼 늘어난다(계속 맞으면 계속 더 오래).
## 속도는 그대로라 시간이 늘수록 더 멀리 날아간다
const FINISHER_EXTRA_TIME := 0.5
## 3타에 맞고 날아가다 벽에 부딪히면 부딪힌 가로 속도의 이 비율로 반대쪽(때린 사람 쪽)으로 튕겨 나온다(2026-09-29 사용자 요청, 전원 —
## 처음 0.5였다가 "속도·거리 100%"로 1.0: 부딪힌 속도 그대로 되튕긴다)
const FINISHER_WALL_BOUNCE := 1.0
## 이 가로 속도(px/초)보다 느리게 닿으면 튕기지 않는다(다 미끄러져 벽에 기대는 정도는 제외)
const FINISHER_WALL_MIN_SPEED := 120.0
## 벽에 부딪힐 때 화면 흔들림(CameraRig.add_trauma)
const FINISHER_WALL_TRAUMA := 0.35
## 3타로 날아가다 땅에 떨어지면 떨어진 속도의 이 비율로 다시 튀어 오른다(2026-09-29 사용자 요청 "벽처럼 100%").
## 앞으로 가는 속도가 FINISHER_WALL_MIN_SPEED 밑으로 줄면 더는 안 튕기고 내려앉아 미끄러진다
const FINISHER_GROUND_BOUNCE := 1.0
## 이 낙하 속도(px/초)보다 약하게 닿으면 튕기지 않는다
const FINISHER_GROUND_MIN_FALL := 120.0
## 땅에 튕길 때 화면 흔들림
const FINISHER_GROUND_TRAUMA := 0.2
## 3타 기절은 완전히 멈출 때까지 가지만, 어딘가 끼어 안 멈추는 경우를 위한 안전 한도(초)
const FINISHER_MAX_FLY_TIME := 6.0
## 3타로 날아가는 각도(도, 수평에서 위로) — 2026-09-29 사용자 요청 "아래로 말고 위쪽으로" 45도. 속도 크기는 그대로, 방향만 돌린다
const FINISHER_LAUNCH_ANGLE_DEG := 45.0
## 최고 높이 상한(px) = 이 값 x 체력 배율(풀피 150 ~ 빈사 300) — 45도 그대로면 빈사 때 약 720px(화면 위로 사라짐)라 위로 솟는 속도를 자른다
const FINISHER_PEAK_PER_SCALE := 150.0
## 3타로 날아가는 동안 중력 배율(평소의 45%, 사용자 결정) — 다른 피격 경직의 HIT_LAUNCH_GRAVITY_SCALE(0.6)과 따로
const FINISHER_GRAVITY_SCALE := 0.45
## 3타로 날아가는 동안 **공중에서** 옆 속도가 줄어드는 빠르기(px/초²) — 바닥 마찰(HITSTUN_FRICTION 900)을 공중에도 쓰면
## 옆 속도가 먼저 끝나 마지막엔 수직으로 떨어진다. 300이면 빈사 때 2500px까지 날아가서 중간값
const FINISHER_AIR_DRAG := 500.0
## 3타로 날아가다 **처음** 땅에 튕길 때 때린 사람 반대쪽으로 날리는 옆 속도 = 처음 날아간 옆 속도 x 이 배율
## (2026-09-29 사용자 요청 "제자리에서 통통 튀면 추가타가 너무 쉽다" — 1.5배). 두 번째 튕김부턴 안 민다(매번 밀면 영영 안 멈춤)
const FINISHER_GROUND_KICK := 1.5

## 추가 피격을 받을 수 있는 남은 시간(= 남은 기절 시간) / 지금 날아가는 방향(+1 오른쪽)
var _finisher_window: float = 0.0
var _finisher_dir: float = 0.0
## 마지막 3타의 기준값 — 추가 피격 때 같은 속도로 다시 날릴 때 쓴다
var _finisher_params: Dictionary = {}
## 추가 피격으로 누적된 날아가는 시간(초). 새 3타가 시작될 때 0으로 리셋된다
var _finisher_extra_time: float = 0.0
## 3타에 맞아 날아가는 중인지 — **완전히 멈출 때까지** 기절이 이어진다(2026-09-29 사용자 요청 "기절 시간 = 날아가는 시간")
var _finisher_flying: bool = false
var _finisher_fly_time: float = 0.0
## 이번 3타에서 위로 솟는 속도 상한(최고 높이 제한에서 역산) — 벽에 튕겨 다시 떠오를 때도 쓴다
var _finisher_up_cap: float = 0.0
## 이번 3타에서 땅에 튕긴 횟수 — 첫 착지는 옆 속도와 상관없이 한 번은 튕긴다(사용자 결정)
var _finisher_ground_bounces: int = 0
## 이번 3타에서 처음 날아간 옆 속도(크기) — 첫 땅 튕김 때 FINISHER_GROUND_KICK을 곱해 반대쪽으로 날린다
var _finisher_launch_vx: float = 0.0
## 날아가는 동안 머리 위에 띄운 기절 별 — 멈출 때까지 늘리고, 멈추면 지운다
var _finisher_stars: StunStars = null

## 3타 공격에 맞아 dir 쪽으로 기절한 채 돌면서 날아간다.
## speed/pop/stun/turns는 **잃은 체력 0일 때** 값이고, 잃은 체력 비율만큼 max_scale배 쪽으로 커진다
## (전부 잃었으면 max_scale배, 반이면 그 중간). 히트박스 넉백으로 붙은 속도는 덮어쓴다
func launch_finisher(dir: float, speed: float, pop: float, stun: float, turns: float, max_scale: float) -> void:
	if has_super_armor() or is_zero_approx(dir):
		return
	# 아직 날아가는 중(window > 0)이면 추가 피격으로 이어지는 것이라 누적 시간을 유지하고,
	# 그게 아니면 새로 시작하는 3타이므로 누적 시간을 0으로 리셋한다
	if _finisher_window <= 0.0:
		_finisher_extra_time = 0.0
	var max_hp: int = maxi(stats.max_hp, 1)
	var lost_ratio: float = clampf(float(max_hp - current_hp) / float(max_hp), 0.0, 1.0)
	var launch_scale: float = lerpf(1.0, max_scale, lost_ratio)
	var d: float = signf(dir)
	# 날아가는(기절) 시간 = 기본 + 추가 피격으로 누적된 시간. 속도는 그대로라 시간이 늘수록 더 멀리 간다
	var time: float = stun * launch_scale + _finisher_extra_time
	# 속도 크기는 예전 가로 속도 그대로, 방향은 FINISHER_LAUNCH_ANGLE_DEG 위로(2026-09-29). pop은 더 안 쓴다 —
	# 위로 솟는 속도는 각도로 정하되 최고 높이(FINISHER_PEAK_PER_SCALE x 배율)를 넘지 않게 자른다
	var total: float = speed * KNOCKBACK_MULTIPLIER * launch_scale
	var ang: float = deg_to_rad(FINISHER_LAUNCH_ANGLE_DEG)
	_finisher_up_cap = sqrt(2.0 * gravity * FINISHER_GRAVITY_SCALE * FINISHER_PEAK_PER_SCALE * launch_scale)
	_finisher_launch_vx = total * cos(ang)
	velocity.x = d * _finisher_launch_vx
	velocity.y = -minf(total * sin(ang), _finisher_up_cap)
	_finisher_ground_bounces = 0
	_launch_momentum = true
	# 새로 날아가는 것이므로 남은 경직과 상관없이 이번 시간으로 다시 잡는다
	_hitstun_time = time
	play_launch_tumble(turns * launch_scale, time, d)
	_finisher_stars = StunStars.spawn(self, time)
	_finisher_flying = true
	_finisher_fly_time = 0.0
	_finisher_dir = d
	# 날아가며 기절해 있는 동안 계속 추가 피격을 받을 수 있다(감지 시간 = 남은 기절 시간)
	_finisher_window = time
	_finisher_params = {"speed": speed, "pop": pop, "stun": stun, "turns": turns, "max_scale": max_scale}

## 3타에 맞고 날아가는 중(_finisher_window)에 벽에 부딪혔으면 반대쪽으로 튕겨 낸다 — apply_physics가 move_and_slide 직후 부른다.
## pre_vx는 **move_and_slide가 0으로 지우기 전의** 가로 속도. 튕긴 뒤엔 벽에서 멀어지므로 같은 벽에 또 걸리지 않는다
func _try_finisher_wall_bounce(pre_vx: float) -> void:
	if _finisher_window <= 0.0 or not is_on_wall() or absf(pre_vx) < FINISHER_WALL_MIN_SPEED:
		return
	var normal: Vector2 = get_wall_normal()
	# 벽 쪽으로 가던 중일 때만(벽에서 멀어지는 중인데 벽 판정만 남은 프레임은 무시)
	if is_zero_approx(normal.x) or signf(pre_vx) != -signf(normal.x):
		return
	velocity.x = -pre_vx * FINISHER_WALL_BOUNCE
	# 떨어지던 속도를 버리고 처음 맞았을 때처럼 FINISHER_LAUNCH_ANGLE_DEG 위로 다시 떠오른다(사용자 결정, 높이 상한 동일)
	velocity.y = -minf(absf(velocity.x) * tan(deg_to_rad(FINISHER_LAUNCH_ANGLE_DEG)), _finisher_up_cap)
	_launch_momentum = true
	_finisher_dir = signf(velocity.x)
	# 구르는 방향도 뒤집는다(날아가는 쪽으로 굴러야 자연스럽다)
	_tumble_speed = -_tumble_speed
	var parent: Node = get_parent()
	if parent:
		CrashBurst.spawn(parent, global_position - Vector2(normal.x * 18.0, 6.0))
	var cam: Node = get_tree().get_first_node_in_group("game_camera")
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(FINISHER_WALL_TRAUMA)

## 3타로 날아가는 동안 매 물리 프레임(move_and_slide 직후) — 땅에 떨어지면 튕겨 올리고, **완전히 멈출 때까지** 기절을 붙잡아 둔다.
## fall_speed는 move_and_slide가 0으로 지우기 전의 낙하 속도. 앞으로 가는 속도는 기절 중 마찰(HITSTUN_FRICTION)로 줄어서,
## FINISHER_WALL_MIN_SPEED 밑이 되면 더는 안 튕기고 내려앉아 미끄러지다 멈춘다 — 그때 기절이 풀린다
func _update_finisher_flight(delta: float, fall_speed: float) -> void:
	if not _finisher_flying:
		return
	_finisher_fly_time += delta
	if has_super_armor() or is_grabbed or _finisher_fly_time >= FINISHER_MAX_FLY_TIME:
		_end_finisher_flight()
		return
	# 첫 착지는 옆 속도와 상관없이 한 번은 튕긴다(사용자 결정) — 그 뒤로는 옆 속도가 남아 있을 때만
	var can_bounce: bool = absf(velocity.x) >= FINISHER_WALL_MIN_SPEED or _finisher_ground_bounces == 0
	if is_on_floor() and fall_speed > FINISHER_GROUND_MIN_FALL and can_bounce:
		# 첫 땅 튕김은 제자리에서 통통 튀지 않고 때린 사람 반대쪽으로 세게 날아간다(추가타가 너무 쉬웠다, 사용자 요청)
		if _finisher_ground_bounces == 0:
			var away: float = _away_from_opponent()
			velocity.x = away * _finisher_launch_vx * FINISHER_GROUND_KICK
			if signf(_tumble_speed) != away:
				_tumble_speed = -_tumble_speed
			_finisher_dir = away
		_finisher_ground_bounces += 1
		velocity.y = -fall_speed * FINISHER_GROUND_BOUNCE
		# 바닥에 닿아 꺼진 날아가는 관성을 다시 켠다(다음 착지까지 가로 속도를 조작으로 덮어쓰지 않게)
		_launch_momentum = true
		var parent: Node = get_parent()
		if parent:
			# 발끝(원점 +30) 조금 위 — 바닥에 부딪힌 자리
			CrashBurst.spawn(parent, global_position + Vector2(0.0, 24.0))
		var cam: Node = get_tree().get_first_node_in_group("game_camera")
		if cam and cam.has_method("add_trauma"):
			cam.add_trauma(FINISHER_GROUND_TRAUMA)
	if is_on_floor() and velocity.y >= 0.0 and absf(velocity.x) < 1.0:
		_end_finisher_flight()
		return
	# 아직 날아가거나 미끄러지는 중 — 기절·추가타 창·구르기·기절 별을 계속 잡아 둔다
	_hitstun_time = maxf(_hitstun_time, 0.1)
	_finisher_window = maxf(_finisher_window, 0.1)
	if _tumble_left > 0.0 and not is_on_floor():
		_tumble_left = maxf(_tumble_left, 0.1)
	if is_instance_valid(_finisher_stars):
		_finisher_stars.extend(0.15)

## 상대(때린 사람)의 반대쪽 방향(+1 오른쪽 / -1 왼쪽). 같은 x거나 상대가 없으면 날아가던 방향
func _away_from_opponent() -> float:
	var opp: Fighter = find_opponent()
	if opp != null and is_instance_valid(opp):
		var dx: float = global_position.x - opp.global_position.x
		if absf(dx) > 1.0:
			return signf(dx)
	return _finisher_dir if not is_zero_approx(_finisher_dir) else 1.0

## 3타 날아가기가 끝났다(멈춤·잡힘·안전 한도) — 기절을 풀고 구르기·기절 별을 정리한다
func _end_finisher_flight() -> void:
	_finisher_flying = false
	_hitstun_time = 0.0
	_finisher_window = 0.0
	if _tumble_left > 0.0:
		_tumble_left = 0.001   # 다음 프레임 _update_tumble이 똑바로 세운다
	if is_instance_valid(_finisher_stars):
		_finisher_stars.queue_free()
	_finisher_stars = null

## 날아가며 기절한 동안 또 맞았을 때 — **때린 방향으로** 같은 속도로 다시 날리고, 날아가는 시간을 늘린다.
## 시간만 FINISHER_EXTRA_TIME씩 누적되므로(속도는 그대로) 계속 따라가 때리면 점점 더 오래·더 멀리 날아간다.
## hit_dir는 이번 추가타의 넉백 방향(x). 넉백이 없는 피해(맵 도트 등)면 날아가던 방향을 그대로 쓴다.
## **추가타는 옆으로만 민다(2026-09-29 사용자 결정)** — 위아래 속도는 맞기 전(vy_before) 그대로. 3타처럼 45도 위로 다시 솟게 하면
## 비비탄 첫 발에 맞은 상대가 위로 떠올라 2·3발째가 발밑으로 지나갔다("총알이 씹힌다")
func _rebound_finisher(hit_dir: float, vy_before: float) -> void:
	var p: Dictionary = _finisher_params
	_finisher_extra_time += FINISHER_EXTRA_TIME
	var d: float = signf(hit_dir) if not is_zero_approx(hit_dir) else _finisher_dir
	launch_finisher(d, p.speed, p.pop, p.stun, p.turns, p.max_scale)
	velocity.y = vy_before

## 맞았을 때 잠깐 아파하는 얼굴로 바꾼다 (그 표정이 있는 캐릭터만 — 없으면 그냥 넘어간다)
func _play_hurt_face() -> void:
	var visual: Node = get_node_or_null("Visual")
	if visual and visual.has_method("play_hurt_face"):
		visual.play_hurt_face()

## 바닥에 닿은 순간 — 충분히 높은 데서 떨어졌으면 발밑에 먼지를 퍼뜨린다.
## fall_speed는 **move_and_slide()가 0으로 지우기 전의** 낙하 속도(아래로 떨어지는 중이면 양수)
## 떨어질 때 실제로 받는 중력 — "이 높이에서 떨어지면 속도가 얼마"를 거꾸로 계산할 때 쓴다(착지 경직·착지 먼지).
## 떨어질 때만 중력이 세지므로 기본 중력으로 계산하면 같은 높이에서도 기준을 넘어버린다
func _fall_gravity() -> float:
	return gravity * fall_gravity_multiplier

## launched: 맞아서 날아가던 중에 떨어졌는지 — 그럴 땐 착지 경직을 안 건다(콤보를 맞고 떨어졌는데 또 굳으면 너무 가혹하다)
func _on_landed(fall_speed: float, launched: bool = false) -> void:
	if fall_speed <= 0.0:
		return
	# 착지 경직 — 떨어진 높이로만 판단한다(이단 점프를 썼는지는 안 본다 — 사용자 결정).
	# 스킬이 이동을 쥐고 있는 착지(내리찍기 등)는 그 스킬이 알아서 하므로 건너뛴다
	var lagged: bool = false
	if landing_lag_height > 0.0 and not launched and movement_override == null \
			and fall_speed >= sqrt(2.0 * _fall_gravity() * landing_lag_height):
		lagged = true
		_landing_lag = landing_lag_time
		velocity.x = 0.0
		_dash_time = 0.0
		var visual: Node = get_node_or_null("Visual")
		if visual and visual.has_method("play_land_crouch"):
			visual.play_land_crouch(landing_lag_time)
	# 착지 먼지 — **모든 착지**에서 떨어진 높이에 비례한 크기로(2026-09-26 사용자 요청). 높이 = 속도² / (2 x 중력)
	var dust_height: float = _land_dust_height()
	if dust_height <= 0.0 and not lagged:
		return
	var fallen: float = fall_speed * fall_speed / (2.0 * maxf(_fall_gravity(), 1.0))
	if fallen < land_dust_min_height and not lagged:
		return
	var power: float = fallen / maxf(dust_height, 1.0)
	# 경직이 걸린 착지는 기준보다 낮게 떨어졌어도 최소 기본 크기(1)로 퍼뜨린다
	_spawn_land_dust(maxf(power, 1.0) if lagged else power)

## 착지 먼지가 나는 높이(px). land_dust_height가 음수면 이단 점프 최고 높이를 계산해 쓴다.
## 올라갈 때는 기본 중력만 받으므로(떨어질 때만 배수가 붙는다) 높이 = 속도² / (2 x 중력)을 점프마다 더한다
func _land_dust_height() -> float:
	if land_dust_height >= 0.0:
		return land_dust_height
	return (jump_velocity * jump_velocity + max_air_jumps * air_jump_velocity * air_jump_velocity) \
		/ (2.0 * maxf(gravity, 1.0))

## 발밑에 먼지를 띄운다. power가 1이면 기준 높이에서 떨어진 것, 크면 더 세게 퍼진다.
## **맵에 붙인다** — 캐릭터의 자식으로 달면 좌우 반전에 같이 뒤집히고 캐릭터가 사라질 때 잘린다
func _spawn_land_dust(power: float) -> void:
	var map: Node = get_parent()
	if map == null:
		return
	var dust := LAND_DUST_SCRIPT.new()
	map.add_child(dust)
	# 캡슐 반지름 20 + 절반 30 = 발바닥이 원점에서 30px 아래
	dust.global_position = global_position + Vector2(0.0, 30.0)
	dust.setup(power)

## 점프하는 순간 발밑에 바람 줄기를 남긴다 — 방향은 지금 속도(가로 이동 + 방금 넣은 점프 속도)라 대각선으로 뛰면 비스듬하다.
## 착지 먼지와 같은 이유로 **맵에 붙인다**(캐릭터 자식이면 좌우 반전에 뒤집히고 따라 움직인다 — 이건 뛴 자리에 남아야 한다)
func _spawn_jump_wind(air: bool) -> void:
	var map: Node = get_parent()
	if map == null:
		return
	var wind := JUMP_WIND_SCRIPT.new()
	map.add_child(wind)
	wind.global_position = global_position + Vector2(0.0, 30.0)
	wind.setup(velocity, air)

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

## duration초 후 callback을 실행한다 (Timers.after 참고 — Fighter가 그 전에 사라지면 콜백째 정리된다)
func _after(duration: float, callback: Callable) -> void:
	Timers.after(self, duration, callback)

## 밖에서 경직을 걸어준다 (놀이터에서 왕관을 떨어뜨렸을 때 등).
## 이미 걸린 경직보다 짧으면 무시한다 — 짧은 값으로 덮어써서 경직이 오히려 일찍 풀리는 걸 막는다
func apply_hitstun(duration: float) -> void:
	# 슈퍼아머 중엔 안 굳는다 — 어깨치기·발차기 마무리·왕관 떨어뜨리기가 따로 거는 경직도 여기서 막힌다
	if has_super_armor():
		return
	_hitstun_time = maxf(_hitstun_time, duration)

## 지금 경직 중인가 (이동·점프·스킬이 막혀 있는 상태)
func is_in_hitstun() -> bool:
	return _hitstun_time > 0.0

## 슈퍼아머를 건다/푼다. **반드시 짝으로 부를 것** — 개수로 세기 때문에 한쪽만 부르면 아머가 안 풀린다
func add_super_armor() -> void:
	_super_armor += 1

func remove_super_armor() -> void:
	_super_armor = maxi(_super_armor - 1, 0)

## 지금 슈퍼아머 중인가 (맞아도 밀리거나 굳지 않고 기술이 계속된다)
func has_super_armor() -> bool:
	return _super_armor > 0

## 잡기 기술(백 서플렉스·유선 마우스 등)이 이 캐릭터를 붙잡을 수 있는지.
## 방어 중(디버프 면역)이거나 슈퍼아머 중이면 못 잡는다 — 수플렉스하던 중에 다른 잡기에 끌려가면 기술이 끊긴다.
## `blocks_debuff()`에 아머를 섞지 않은 이유: 그러면 공포·도트까지 같이 막혀버리는데, 그 둘은 쓰던 기술을 끊지 않는다
func can_be_grabbed() -> bool:
	return not blocks_debuff() and not has_super_armor() and counter_stance == null

## 카운터 자세 중이면 반격을 시작하고 true — 이번 피해는 없던 일이 된다. 자세가 아니면 false
func try_counter() -> bool:
	if counter_stance == null or not is_instance_valid(counter_stance):
		counter_stance = null
		return false
	var stance = counter_stance
	counter_stance = null
	stance.trigger_counter(self)
	return true

## duration초 동안 무적 상태로 만든다
func grant_invincibility(duration: float) -> void:
	is_invincible = true
	_after(duration, func(): is_invincible = false)

## 지금 이 캐릭터에게 디버프(둔화·공포·그랩 등)를 걸 수 있는지. true면 튕겨낸다.
##
## **방어 중에는 어떤 디버프도 안 걸린다** — 데미지·넉백만 막고 둔화·공포·그랩이 그대로 들어가면
## "1초 무적"이 무적이 아니게 된다(막았는데 유선 마우스에 끌려가는 식).
## **단 궁극기는 예외다 — 피해는 막히지만 디버프는 뚫고 들어간다.** 궁을 쓰고도 아무 일이 없으면
## 긴 쿨(20~50초)을 쓸 이유가 없어지므로, 궁에만 "막아도 한 대는 남는다"를 남겨둔 것이다.
##
## **맵 기믹(열차·모래사장·왕관)은 이 함수를 안 거친다** — 예전처럼 방어와 무관하게 걸린다
func blocks_debuff(from_ultimate: bool = false) -> bool:
	if is_invincible:
		return true
	return is_guarding and not from_ultimate

## duration초 동안 공포 상태로 만든다 (기본공격/스킬 사용 불가, 이동은 가능).
## 방어 중이면 안 걸린다 — 궁극기가 거는 공포만 뚫고 들어온다
func apply_fear(duration: float, from_ultimate: bool = false) -> void:
	if blocks_debuff(from_ultimate):
		return
	is_feared = true
	set_tint("fear", Color(0.75, 0.75, 1.0), duration)
	_after(duration, func(): is_feared = false)

## 기본 공격력에 캐릭터 배율과 디버프를 반영한 최종 데미지를 계산한다
func compute_damage(base_damage: int) -> int:
	return int(round(base_damage * stats.attack_multiplier * attack_debuff_multiplier))

## 지금 방어를 켤 수 있는지. 쿨타임이 남았거나 이미 방어 중이거나,
## 경직·붙잡힘·대시 중이거나 다른 스킬이 이동을 가로챈 상태면 안 된다.
## 방 설정에서 껐으면(GameState.guard_enabled) 아예 못 켠다
func can_guard() -> bool:
	if not GameState.guard_enabled:
		return false
	if _guard_cooldown_left > 0.0 or _guard_time > 0.0:
		return false
	return _hitstun_time <= 0.0 and not is_grabbed and _dash_time <= 0.0 and movement_override == null and _landing_lag <= 0.0

## 아래 키를 **누른 순간** 호출한다 — guard_duration(1.0초) 동안 보호막이 켜지고
## 그 사이에 들어오는 공격은 전부 무효가 된다. 실제로 켜졌으면 true.
## 공중에서도 켜지고, 켜져 있는 동안엔 이동·점프·공격·스킬이 전부 막힌다(무적의 대가)
func start_guard() -> bool:
	if not can_guard():
		return false
	is_guarding = true
	_guard_time = guard_duration
	velocity.x = 0.0
	if _shield == null:
		_shield = GUARD_SHIELD_SCRIPT.new()
		add_child(_shield)
	_shield.set_active(true)
	_shield.set_remain(1.0)
	_set_visual_guard(true)
	return true

## 방어를 끈다. refund가 true면 쿨타임을 물리지 않는다 —
## "아래키를 누르자마자 점프"(발판 통과)처럼 방어할 의도가 아니었던 경우에 쓴다
func cancel_guard(refund: bool = false) -> void:
	if not is_guarding:
		return
	is_guarding = false
	_guard_time = 0.0
	_guard_cooldown_left = 0.0 if refund else guard_cooldown
	if _shield:
		_shield.set_active(false)
	_set_visual_guard(false)

## 내 기본공격이 상대 방어에 막혔을 때 — blocked_attack_lock(3초) 동안 기본공격이 잠기고,
## 때린 오른손과 거기 든 무기가 같은 시간만큼 빨갛게 깜빡인다("빨간 동안엔 못 때린다").
## **잠금 시간을 몸에 넘겨줘서** 인스펙터에서 한쪽만 고쳐 둘이 어긋나는 일이 없게 한다.
## 그 연출이 없는 비주얼(임시 사각형)이면 잠금만 걸리고 그림은 안 바뀐다
func play_weapon_blocked() -> void:
	_blocked_attack_left = blocked_attack_lock
	var visual: Node = get_node_or_null("Visual")
	if visual and visual.has_method("play_weapon_blocked"):
		visual.play_weapon_blocked(blocked_attack_lock)

## 지금 기본공격이 막혀서 잠겨 있는지 (방어에 막힌 뒤 blocked_attack_lock 동안)
func is_basic_attack_locked() -> bool:
	return _blocked_attack_left > 0.0

## 몸(BodyRig)에 막는 자세를 켜고 끈다. 그 메서드가 없는 비주얼이면 그냥 넘어간다
func _set_visual_guard(on: bool) -> void:
	var visual: Node2D = get_node_or_null("Visual")
	if visual and visual.has_method("set_guarding"):
		visual.set_guarding(on)

## 지금 대시를 쓸 수 있는지. 쿨타임이 남았거나, 경직·붙잡힘 상태거나,
## 다른 스킬이 이동을 가로채고 있으면(movement_override) 안 된다.
## 방 설정에서 껐으면(GameState.dash_enabled) 아예 못 쓴다
func can_dash() -> bool:
	if not GameState.dash_enabled:
		return false
	if _dash_cooldown_left > 0.0 or _dash_time > 0.0:
		return false
	return _hitstun_time <= 0.0 and not is_grabbed and not is_guarding and movement_override == null and _landing_lag <= 0.0

## 방향키를 두 번 눌렀을 때 그 방향으로 짧게 미끄러진다. 실제로 나갔으면 true.
## 스킬이 아니라 기본 조작이라 스킬 클래시·is_busy()와 무관하게 동작한다
func dash(direction: float) -> bool:
	if is_zero_approx(direction) or not can_dash():
		return false
	_dash_dir = signf(direction)
	facing = _dash_dir
	_dash_time = dash_duration
	_dash_cooldown_left = dash_cooldown
	_dash_trail_timer = 0.0
	_spawn_dash_afterimage()
	return true

## 대시 잔상 — 푸른빛을 입혀서 남긴다
func _spawn_dash_afterimage() -> void:
	_spawn_afterimage(Color(0.7, 0.82, 1.0, 0.42), 0.22)

## duration초 동안 날아가는 몸 뒤로 잔상을 남긴다 — 그네에 튕길 때(Swing)·스프링 시소로 높이 튈 때(SpringJumpPad) 맵이 부른다.
## 이미 남기는 중이면 남은 시간과 비교해 더 긴 쪽을 쓴다
func start_air_trail(duration: float) -> void:
	if _air_trail_left <= 0.0:
		_air_trail_timer = 0.0   # 새로 시작하면 이번 프레임에 바로 한 장 남긴다
	_air_trail_left = maxf(_air_trail_left, duration)

## 날아갈 때 잔상을 한 물리 프레임 진행한다 (apply_physics가 부른다).
## 촉법소년 자전거 잔상처럼 몸의 지금 색(피격·약화 색조 포함)은 그대로 두고 투명도만 낮춘다
func _update_air_trail(delta: float) -> void:
	if _air_trail_left <= 0.0:
		return
	_air_trail_left -= delta
	_air_trail_timer -= delta
	if _air_trail_timer > 0.0:
		return
	_air_trail_timer = AIR_TRAIL_INTERVAL
	var visual: Node2D = get_node_or_null("Visual")
	if visual == null:
		return
	var tint: Color = visual.modulate
	tint.a = AIR_TRAIL_ALPHA
	_spawn_afterimage(tint, AIR_TRAIL_FADE)

## 잔상 하나 — Visual을 그 순간 모습 그대로 복제해 본체 뒤에 두고, tint 색으로 시작해 fade초에 걸쳐 투명하게 지운다.
## DashSkill._spawn_afterimage()와 같은 방식이라 임시 사각형이든 스프라이트 몸이든 그대로 동작한다.
## 복제본의 스크립트를 떼는 게 핵심 — 안 떼면 BodyRig의 매 프레임 자세 계산이 잔상에서도 돌아 같이 움직인다
func _spawn_afterimage(tint: Color, fade: float) -> void:
	var visual: Node2D = get_node_or_null("Visual")
	var parent: Node = get_parent()
	if visual == null or parent == null:
		return
	var ghost := visual.duplicate() as Node2D
	if ghost == null:
		return
	ghost.set_script(null)
	parent.add_child(ghost)
	ghost.z_index = -2   # 본체(0)와 그 손(1)보다 확실히 뒤로
	ghost.global_position = visual.global_position
	ghost.scale = visual.scale
	ghost.modulate = tint
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, fade)
	tween.tween_callback(ghost.queue_free)

func move(direction: float) -> void:
	# 실제로 움직이지 못하는 상황(경직 등)에도 "무슨 방향을 누르고 있는지"는 남긴다 —
	# 이동이 아니라 입력 자체를 읽어야 하는 기믹이 이 값을 본다 (예전 탑승식 그네가 그랬다)
	move_input = direction
	# 피격 경직 중엔 조작으로 넉백 속도를 덮어쓰지 않는다 (그래야 넉백 방향으로 날아간다)
	if _hitstun_time > 0.0 or is_grabbed:
		return
	# 방어는 제자리에 버티는 자세다 — 움직이면서 절반만 맞으면 안 지킬 이유가 없어진다
	if is_guarding:
		velocity.x = 0.0
		return
	# 착지 경직 중엔 제자리에 굳는다 — 방향도 안 바뀐다
	if _landing_lag > 0.0:
		velocity.x = 0.0
		return
	if direction != 0.0:
		facing = signf(direction)
	var target_x: float = direction * stats.move_speed * move_speed_multiplier
	# **맞고 날아가는 중(착지 전)엔 날아가던 힘을 유지한다(2026-09-17, 브롤할라식).** 예전엔 경직이 공중에서 먼저 풀리면
	# 이 줄이 가로 속도를 입력값(안 누르면 0)으로 덮어써서, 날아가다 허공에서 뚝 멈추고 수직으로 떨어졌다.
	# 방향키는 LAUNCH_AIR_CONTROL만큼만 먹고, 안 누르면 LAUNCH_AIR_DRAG로 서서히 줄어든다. 평소 점프 조작감은 그대로다
	if _launch_momentum and not is_on_floor():
		var dt: float = get_physics_process_delta_time()
		if direction != 0.0:
			velocity.x = move_toward(velocity.x, target_x, LAUNCH_AIR_CONTROL * dt)
		else:
			velocity.x = move_toward(velocity.x, 0.0, LAUNCH_AIR_DRAG * dt)
		return
	velocity.x = target_x

## 바닥에서는 보통 점프, 공중에서는 남은 횟수만큼 이단 점프.
## 이단 점프는 지금까지의 낙하 속도를 무시하고 속도를 새로 덮어써서, 떨어지는 중에 눌러도 제대로 뜬다
func jump() -> void:
	# 경직 중엔 점프로 넉백을 못 벗어난다. 방어 중에도 못 뛴다(1.2초를 버티기로 한 대가)
	if _hitstun_time > 0.0 or is_grabbed or is_guarding or _landing_lag > 0.0:
		return
	var air: bool = not is_on_floor()
	if not air:
		velocity.y = jump_velocity * jump_multiplier
	elif _air_jumps_left > 0:
		_air_jumps_left -= 1
		velocity.y = air_jump_velocity * jump_multiplier
	else:
		return
	_spawn_jump_wind(air)
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
	if _landing_lag > 0.0:
		return false
	var platform: PhysicsBody2D = get_one_way_floor()
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
## 그 면이 속한 충돌 도형에 one_way_collision이 켜져 있는지 확인한다.
## drop_through_platform() 말고도 GroundPoundSkill처럼 "지금 밟은 발판이 뭔지" 알아야 하는
## 외부 스킬이 있어서 공개 메서드로 뒀다
func get_one_way_floor() -> PhysicsBody2D:
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
	return _busy_time > 0.0 or _hitstun_time > 0.0 or _landing_lag > 0.0

## 착지 경직 중인지 (높은 데서 떨어져 무릎을 굽히고 굳은 동안)
func is_landing_lagged() -> bool:
	return _landing_lag > 0.0

## 착지 경직을 그 자리에서 푼다 — 착지하자마자 튕겨 나가는 기믹(스프링 시소)이 부른다.
## 안 풀면 경직을 단 채로 날아가서 공중에서 0.5초 동안 조작을 못 한다
func cancel_landing_lag() -> void:
	if _landing_lag <= 0.0:
		return
	_landing_lag = 0.0
	var visual: Node = get_node_or_null("Visual")
	if visual and visual.has_method("play_land_crouch"):
		visual.play_land_crouch(0.0)

## duration초 동안 다른 스킬·기본공격 입력을 막는다 (모션이 겹쳐 나오지 않게). 이동은 계속 가능하다.
## 더 긴 잠금이 이미 걸려 있으면 짧은 걸로 줄어들지 않게 둘 중 큰 값을 쓴다
func start_busy(duration: float) -> void:
	_busy_time = maxf(_busy_time, duration)

## 걸려 있던 행동 잠금을 그 자리에서 푼다 — 스킬이 예정보다 일찍 끝났을 때 쓴다.
## (일진 어깨 들이박기: 상대를 받아 올린 순간 돌진이 끝나므로, 남은 잠금을 풀어야 평타로 바로 이어진다)
func end_busy() -> void:
	_busy_time = 0.0

## 씬에 SkillClashManager가 있으면(1대1 대전 맵) 반환하고, 없으면(훈련장 등) null
func _get_clash_manager() -> Node:
	return get_tree().get_first_node_in_group("skill_clash_manager")

func use_skill_1() -> void:
	if skill_1 == null or is_feared or is_grabbed or is_guarding or is_busy() or not skill_1.can_use():
		return
	var manager: Node = _get_clash_manager()
	if manager:
		manager.request(self, "skill_1", func(): skill_1.use(self), func(): skill_1.cancel_use())
	else:
		skill_1.use(self)

func use_skill_2() -> void:
	if skill_2 == null or is_feared or is_grabbed or is_guarding or is_busy() or not skill_2.can_use():
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
	if skill_ultimate == null or is_feared or is_grabbed or is_guarding or is_busy() or not skill_ultimate.can_use():
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
	# 방어에 막힌 직후엔 무기가 빨간 동안(blocked_attack_lock) 기본공격이 안 나간다
	if basic_attack == null or is_feared or is_grabbed or is_guarding or is_busy() or is_basic_attack_locked() or not basic_attack.can_use():
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

## 맵 전용 스킬(map_skill)을 쓴다. 캐릭터 스킬과 달리 스킬 클래시(연타 미니게임)를 타지 않는다 —
## 상대 캐릭터가 아니라 맵 자체와의 상호작용이라 "동시에 썼다"는 개념이 맞지 않는다
func use_map_skill() -> void:
	if map_skill == null or is_feared or is_grabbed or is_busy() or not map_skill.can_use():
		return
	map_skill.use(self)

## 1대1 전제로 자기 자신이 아닌 다른 Fighter를 찾는다
func find_opponent() -> Fighter:
	for f in get_tree().get_nodes_in_group("fighters"):
		if f != self:
			return f
	return null

## fighter를 기준으로 가로 range_x/세로 range_y 상자 안에 있는 다른 Fighter를 찾는다.
## 캐릭터끼리는 몸 충돌이 꺼져 있어(_ignore_other_fighters) 물리로는 못 잡으므로,
## 근접 판정(자전거 돌진·어깨 들이박기 등)이 몸 사이 거리로 직접 확인할 때 쓴다.
## dx * direction이 -back_tolerance보다 작으면(명백히 등 뒤) 제외하고, 거의 겹친 경우는 통과시킨다
static func find_fighter_in_box(fighter: Fighter, range_x: float, range_y: float, direction: float, back_tolerance: float = 20.0) -> Fighter:
	for other in fighter.get_tree().get_nodes_in_group("fighters"):
		if other == fighter or not (other is Fighter) or not is_instance_valid(other):
			continue
		var dx: float = other.global_position.x - fighter.global_position.x
		var dy: float = other.global_position.y - fighter.global_position.y
		if absf(dx) > range_x or absf(dy) > range_y:
			continue
		if dx * direction < -back_tolerance:
			continue
		return other
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

## property에 duration초 동안만 유지되는 임시 배수 효과를 건다 (자동으로 id를 발급하고 만료 처리).
##
## **스킬이 거는 디버프는 전부 이 함수를 지난다** — 방어 차단도 여기 한 곳에서만 한다.
## `set_modifier`를 직접 부르는 쪽(맵 기믹·자기 자신 버프)은 이 검사를 안 거친다
func apply_temp_multiplier(property: String, value: float, duration: float, from_ultimate: bool = false) -> void:
	if blocks_debuff(from_ultimate):
		return
	var id := _next_modifier_id
	_next_modifier_id += 1
	set_modifier(property, id, value)
	_after(duration, func(): clear_modifier(property, id))

## tick_interval마다 damage_per_tick씩 ticks번 데미지를 준다 (화상 등 도트 데미지).
## 방어 중에 걸면 아예 안 붙는다 — 걸어두기만 하고 방어가 풀린 뒤 터지면 막은 의미가 없다
func apply_dot(damage_per_tick: int, tick_interval: float, ticks: int, from_ultimate: bool = false) -> void:
	if blocks_debuff(from_ultimate):
		return
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
	if _finisher_window > 0.0:
		_finisher_window = maxf(_finisher_window - delta, 0.0)
	# 경직 중엔 넉백 속도가 마찰로 서서히 줄며 미끄러진다 (멈출 때쯤 경직도 끝나 조작이 돌아온다)
	if _hitstun_time > 0.0:
		_hitstun_time = maxf(_hitstun_time - delta, 0.0)
		# 3타로 날아가는 중 공중에선 옆 속도를 덜 깎는다(포물선이 끝까지 이어지게) — 바닥에선 평소 마찰
		var friction: float = FINISHER_AIR_DRAG if _finisher_flying and not is_on_floor() else HITSTUN_FRICTION
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	# 크게 날아가는 중이면 몸이 빙글빙글 돈다 (시간이 다 되거나 바닥에 닿으면 알아서 일어선다)
	if _tumble_left > 0.0:
		_update_tumble(delta)
	if _combo_timer > 0.0:
		_combo_timer = maxf(_combo_timer - delta, 0.0)
	if not is_on_floor():
		# 피격으로 떠 있는 동안엔 중력을 줄여 잠깐 더 체공하게 한다 (옆보다 위로 뜨는 넉백과 어울림)
		var g: float = gravity
		if _finisher_flying:
			g *= FINISHER_GRAVITY_SCALE
		elif _hitstun_time > 0.0:
			g *= HIT_LAUNCH_GRAVITY_SCALE
		elif velocity.y > 0.0:
			g *= fall_gravity_multiplier
		velocity.y += g * delta
	# 방어 — 정해진 시간이 지나면 저절로 꺼지고 그때부터 쿨타임이 돈다.
	# 켜져 있는 동안엔 제자리에 버틴다(이동·점프·공격은 각 함수에서 막는다)
	# 방어에 막혀서 잠긴 기본공격 — 시간이 지나면 저절로 풀린다(무기 깜빡임도 같이 끝난다)
	if _blocked_attack_left > 0.0:
		_blocked_attack_left = maxf(_blocked_attack_left - delta, 0.0)
	if _guard_cooldown_left > 0.0:
		_guard_cooldown_left = maxf(_guard_cooldown_left - delta, 0.0)
	if _guard_time > 0.0:
		_guard_time = maxf(_guard_time - delta, 0.0)
		velocity.x = 0.0
		if _shield:
			_shield.set_remain(_guard_time / maxf(guard_duration, 0.001))
		if is_zero_approx(_guard_time):
			is_guarding = false
			_guard_cooldown_left = guard_cooldown
			if _shield:
				_shield.set_active(false)
			_set_visual_guard(false)

	# 대시 — 짧은 시간 동안 입력보다 우선해서 수평 속도를 덮어쓴다.
	# 맞으면 그 자리에서 끊긴다(넉백이 대시를 이겨야 콤보가 성립한다)
	if _dash_cooldown_left > 0.0:
		_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	if _dash_time > 0.0:
		if _hitstun_time > 0.0 or is_grabbed:
			_dash_time = 0.0
		else:
			_dash_time = maxf(_dash_time - delta, 0.0)
			velocity.x = _dash_dir * dash_speed
			_dash_trail_timer -= delta
			if _dash_trail_timer <= 0.0:
				_dash_trail_timer = DASH_TRAIL_INTERVAL
				_spawn_dash_afterimage()
	# 그네·스프링 시소로 날아가는 중이면 잔상을 남긴다
	_update_air_trail(delta)
	# 돌진 스킬 등이 이동을 가로챘으면 그쪽이 최종 결정권을 갖는다 (대시보다 뒤에 둔 이유)
	if movement_override:
		velocity.x = movement_override.get_move_velocity_x()
	# **move_and_slide()가 부딪히는 순간 velocity.y를 0으로 만들어버린다** — 착지 세기를 알려면
	# 그 전에 낙하 속도를 따로 기억해둬야 한다(스프링 발판이 _prev_fall을 쓰는 것과 같은 이유)
	# 슈퍼아머 중엔 위로 튕겨 오르지 않는다. take_damage 쪽 넉백은 이미 막았지만,
	# 어깨치기처럼 **velocity를 직접 덮어써서** 띄우는 기술은 거길 안 거쳐서 여기서 한 번 더 막는다
	# (수평은 아머를 거는 기술이 movement_override로 이미 잡고 있다)
	if has_super_armor() and velocity.y < 0.0:
		velocity.y = 0.0
	var fall_speed: float = velocity.y
	# 아래에서 착지하면 _launch_momentum이 지워지므로 날아가던 중이었는지는 미리 기억해 둔다
	var was_launched: bool = _launch_momentum or _hitstun_time > 0.0
	if _landing_lag > 0.0:
		_landing_lag = maxf(_landing_lag - delta, 0.0)
	# 벽에 부딪히면 move_and_slide()가 가로 속도를 0으로 만든다 — 3타 벽 튕김에 쓸 속도를 미리 기억한다
	var pre_vx: float = velocity.x
	move_and_slide()
	_try_finisher_wall_bounce(pre_vx)
	_update_finisher_flight(delta, fall_speed)
	# 착지할 때마다 공중 점프 횟수를 다시 채운다 (move_and_slide 뒤라야 이번 프레임의 착지가 반영된다)
	if is_on_floor():
		_air_jumps_left = max_air_jumps
		_launch_momentum = false
	# 공중에 있다가 이번 프레임에 바닥에 닿았으면 = 착지
	if is_on_floor() and not _was_on_floor:
		_on_landed(fall_speed, was_launched)
	_was_on_floor = is_on_floor()
	if movement_override:
		movement_override.after_physics(self, delta)
	# 상대 캐릭터와 겹쳤으면 가로로 밀어내 통과하지 못하게 한다
	_separate_from_others()
