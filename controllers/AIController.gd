class_name AIController
extends Node

## 규칙 기반 AI(2026-09-27 강화 — 사용자 요청 "콤보·맵 이동·방어·스킬 판단 전부, 전체적으로 강하게").
## 스스로 배우는 AI가 아니라 "이 상황이면 이렇게"를 코드로 정해 둔 것이다. 판단 순서:
## ① 맵 기믹(열차) 피하기 ② 상대 공격 읽고 막기·피하기 ③ 왕관 줍기 ④ 발판 길찾기(상대가 다른 층에 있으면)
## ⑤ 거리 싸움(콤보 이어치기·빈틈 찌르기·방어한 상대 기다리기) ⑥ 스킬별 조건에 맞을 때만 스킬 사용.
## target을 직접 지정하지 않으면 씬에서 자기 자신이 아닌 첫 Fighter를 목표로 삼는다(1대1 전제)

## 기본공격이 닿는 상대 중심까지 거리(px). 0 이하면 기본공격 판정 위치(range)로 자동 계산한다
@export var attack_range: float = -1.0
## 원거리 스킬(비비탄, 토하기 등)을 가진 캐릭터가 **그 스킬이 준비됐을 때** 유지하려는 거리
@export var ranged_distance: float = 180.0
## 스킬을 쓸지 몇 초마다 따져 볼지. 조건이 맞아도 skill_commit_chance 확률로만 쓴다(너무 기계적이지 않게)
@export var skill_think_interval: float = 0.12
@export_range(0.0, 1.0, 0.05) var skill_commit_chance: float = 0.6
## 가끔 한 번 뛰어볼 확률(매 물리 프레임, 싸움 거리 밖에서만)
@export var jump_chance: float = 0.003
## 쓸 스킬이 없을 때(원거리 캐릭터만) 뒤로 빠지기 시작할 확률·시간
@export var retreat_start_chance: float = 0.01
@export var retreat_duration: float = 0.5
@export var target: Fighter

@export_group("반응")
## 상대 공격을 알아채는 데 걸리는 시간(초). 사람 반응속도(0.2~0.25)보다 빠르면 강해진다
@export var reaction_time: float = 0.09
## 공격을 읽었을 때 방어(아래 키)를 켤 확률 — 방어 쿨(5초)이 있어 남발은 안 된다
@export_range(0.0, 1.0, 0.05) var guard_react_chance: float = 0.6
## 방어를 못 켜면 대시·점프로 피할 확률
@export_range(0.0, 1.0, 0.05) var dodge_react_chance: float = 0.75

@export_group("거리 싸움")
## 상대가 이만큼 넘게 떨어져 있으면 대시로 단숨에 붙는다
@export var dash_approach_distance: float = 240.0
## 열차 등을 피해 안전지대로 갈 때, 남은 거리가 이만큼 넘으면 대시로 서두른다
@export var dash_dodge_distance: float = 80.0
## 상대 사거리 바로 바깥에서 멈칫하며 헛손질을 유도할 확률(매 물리 프레임)
@export_range(0.0, 0.2, 0.005) var bait_chance: float = 0.02
## 후속타를 아는지 — 끄면(스토리 모드, 2026-10-01 사용자 요청 "후속타 개념을 모르게") 맞힌 뒤 따라가며 다음 타를 잇지 않고,
## 상대 빈틈(경직·잠김)을 노려 파고들지 않고, 3타에 날아가는 상대를 쫓아 치지 않는다. 한 대씩 툭툭 치는 AI가 된다
@export var knows_follow_ups: bool = true

@export_group("길찾기·왕관")
## 발판 경로를 몇 초마다 다시 계산할지
@export var nav_replan_interval: float = 0.25
## 이 거리(px) 안에 주울 수 있는 왕관이 있으면 싸움을 미루고 주우러 간다(놀이터 전용, 높이 상관없이 발판을 타고 올라간다)
@export var crown_interest_range: float = 900.0

@export_group("구경 모드(타이틀)")
## 켜면 보여주기 위주로 싸운다(타이틀 전용, 2026-09-28 사용자 요청) — 붙어서 계속 치고받지 않고
## 잠깐 거리를 벌린 채 이단 점프·대시로 돌아다니다가 다가가서 스킬을 쓰거나 평타 3타 콤보를 한 번 치고 다시 빠진다.
## 화면(카메라에 보이는 곳) 밖으로는 웬만하면 안 나간다. 실제 대전 AI는 꺼져 있음
@export var showcase: bool = false
## 빠져 있는 동안 벌려 둘 거리(px)
@export var showcase_keep_distance: float = 220.0
## 빠져 있는 시간(초, 최소~최대 랜덤) — 끝나면 다시 다가간다
@export var showcase_kite_time: Vector2 = Vector2(0.5, 1.1)
## 화면 가장자리에서 이만큼(px) 안쪽을 넘어가지 않으려 한다
@export var showcase_screen_margin: float = 70.0
## 준비된 스킬을 조건이 안 맞아 이만큼(초) 못 쓰고 있으면 상대가 showcase_skill_range 안일 때 그냥 쓴다(스킬 보여주기 우선)
@export var showcase_skill_patience: float = 1.2
@export var showcase_skill_range: float = 450.0
## 거리를 벌리는 동안 이단 점프·대시를 하는 간격(초, 최소~최대 랜덤)
@export var showcase_hop_interval: Vector2 = Vector2(0.6, 1.4)
@export var showcase_dash_interval: Vector2 = Vector2(0.7, 1.6)
## 한 번 다가갈 때 최대 몇 초까지 붙어 보는지(그 안에 못 쓰면 다시 빠진다)
@export var showcase_engage_time: float = 1.8

## false면 아무 판단도 안 한다(대전 시작 카운트다운 등) — 그래도 중력·바닥 착지는 계속 처리한다
var is_active: bool = true
## 바깥에서 방어 확률에 곱하는 배수 — ClaudeAIController가 전략(공격적/수비적)에 따라 바꾼다. 1이면 기본
var guard_bias: float = 1.0

## 발끝은 캐릭터 원점에서 +30(허트박스·스쿼시 기준과 같다)
const FEET_OFFSET := 30.0

var _is_ranged: bool = false
var _retreat_timer: float = 0.0
## 안전지대로 피신할 때 이단 점프 진행 단계: 0=아직 안 뜀, 1=1단 뛰고 정점 기다리는 중, 2=2단까지 다 씀
var _dodge_jump_stage: int = 0
var _melee_reach: float = 68.0
var _threat_time: float = 0.0
var _threat_handled: bool = false
## 사거리 바깥에서 멈칫하는 남은 시간
var _hold_timer: float = 0.0
var _skill_timer: float = 0.0

## 발판 목록 — 각 칸은 {id, left, right, top, one_way, spring_v}(spring_v > 0이면 그 위에 서면 튕기는 스프링 좌석)
var _platforms: Array = []
var _platform_refresh: float = 0.0
var _plan_timer: float = 0.0
## 지금 향하는 다음 발판과, 그 계획을 세운 출발 발판 id
var _nav_next = null
var _nav_from_id: int = -1
## 뛰어오른 발판의 높이 — 공중에서 "더 올라가야 하는지" 판단용
var _nav_takeoff_top: float = 0.0
## 끼임 탈출 — 가려는데 제자리(비스듬한 미끄럼틀 밑처럼 벽이 아닌 천장에 막힘)면 반대로 물러났다가 뛰어오른다
var _stuck_time: float = 0.0
var _detour_left: float = 0.0
var _detour_dir: float = 0.0
## 탈출 점프 중 정점 뒤에 향할 방향(0이면 탈출 중 아님)과, 공중에 떴는지
var _escape_dir: float = 0.0
var _escape_airborne: bool = false
var _escape_wait: float = 0.0
var _escape_air_jumped: bool = false
## 탈출 직후엔 발판을 뚫고 내려가지 않는다(내려가면 다시 끼인 자리로 돌아간다)
var _no_drop_left: float = 0.0
## 구경 모드 — 스킬 쓰러 다가가는 중인지, 지금 단계의 남은 시간, 점프·대시 타이머
var _show_engage: bool = false
var _show_timer: float = 0.0
var _show_hop: float = 0.5
var _show_dash: float = 0.8
## 1단 점프 뒤 정점에서 2단 점프를 누를 차례인지(누른 뒤 지난 시간)
var _show_air_pending: bool = false
var _show_air_age: float = 0.0
## 벽에 몰렸을 때 상대를 뛰어넘어 반대편으로 가는 남은 시간
var _show_cross: float = 0.0
## 이번에 다가가서 평타 콤보를 시작했는지 — 콤보가 끝나면(3타 또는 헛침) 빠진다
var _show_combo: bool = false
## 슬롯별(스킬1·스킬2·궁) 준비된 채 못 쓰고 기다린 시간
var _show_skill_wait: Array = [0.0, 0.0, 0.0]

@onready var fighter: Fighter = get_parent()

func _ready() -> void:
	if target == null:
		target = fighter.find_opponent()
	# skill_2가 원거리 스킬(비비탄처럼 projectile_scene, 토하기 기둥처럼 beam_scene을 가진 스킬)이면
	# 원거리 캐릭터로 보고 거리를 두고 싸우게 한다. 캐릭터별로 따로 분기하지 않고 스킬 구성만으로 판단
	_is_ranged = fighter.skill_2 != null and (
		fighter.skill_2.get("projectile_scene") != null or fighter.skill_2.get("beam_scene") != null)
	_melee_reach = attack_range if attack_range > 0.0 else _reach_of(fighter)

## 그 캐릭터의 기본공격이 닿는 상대 중심 거리 — 판정 상자(30x30)가 캐릭터 앞 range에 켜지고 상대 몸 반폭까지 더한 값
func _reach_of(f: Fighter) -> float:
	if f and f.basic_attack and f.basic_attack.get("range") != null:
		return float(f.basic_attack.get("range")) + 28.0
	return 60.0

func _physics_process(delta: float) -> void:
	if not is_active:
		fighter.move(0.0)
		fighter.apply_physics(delta)
		return

	if target == null:
		target = fighter.find_opponent()
	if target == null or not is_instance_valid(target):
		fighter.move(0.0)
		fighter.apply_physics(delta)
		return

	_refresh_platforms(delta)
	# 방어는 이동·공격을 다 막으므로 제일 먼저 정한다.
	# 막고 있는 동안엔 다른 판단을 아예 건너뛴다 (어차피 Fighter가 전부 막는다)
	_update_threat(delta)
	if fighter.is_guarding:
		fighter.move(0.0)
		fighter.apply_physics(delta)
		return

	if fighter.movement_override == null:
		_update_stuck(delta)
		# 구경 모드에선 스킬 쓰러 다가갈 때만 상대 발판까지 길을 찾는다(평소엔 거리를 벌린다)
		var nav_ok: bool = not showcase or _show_engage
		if not _try_dodge_hazard() and not _run_detour(delta) and not _try_take_crown(delta) and not (nav_ok and _navigate_to_target(delta)):
			if showcase:
				_showcase_movement(delta)
			else:
				_decide_movement(delta)
		_jump_obstacles()
	_decide_skills(delta)

	fighter.apply_physics(delta)

# ---------------------------------------------------------------- 상대 공격 읽기

## 상대 공격(휘두르기·돌진·날아오는 투사체)을 reaction_time만큼 늦게 알아채고 한 번 대응한다
func _update_threat(delta: float) -> void:
	var threat: String = _detect_threat()
	if threat == "":
		_threat_time = 0.0
		_threat_handled = false
		return
	_threat_time += delta
	if _threat_handled or _threat_time < reaction_time:
		return
	_threat_handled = true
	_respond_to_threat(threat)

## 지금 나를 노리는 공격 종류("melee"/"charge"/"projectile"/"area"), 없으면 ""
func _detect_threat() -> String:
	var to_me: float = fighter.global_position.x - target.global_position.x
	var dist: float = absf(to_me)
	var dy: float = absf(fighter.global_position.y - target.global_position.y)
	var facing_me: bool = dist < 12.0 or signf(to_me) == signf(target.facing)
	var ba: Skill = target.basic_attack
	if ba and ba.get("_swinging") == true and facing_me and dist <= _reach_of(target) + 30.0 and dy < 60.0:
		return "melee"
	# 자전거·어깨 들이박기·덩크처럼 이동을 가로챈 채 나에게 달려오는 스킬
	if target.movement_override != null and target.movement_override != ba and facing_me and dist < 320.0 and dy < 70.0 \
			and signf(target.velocity.x) == signf(to_me) and absf(target.velocity.x) > 250.0:
		return "charge"
	var map: Node = fighter.get_parent()
	if map == null:
		return ""
	for node in map.get_children():
		var hb := node as Hitbox
		if hb == null or not hb.monitoring or hb.source_fighter != target:
			continue
		var rel: Vector2 = fighter.global_position - hb.global_position
		if hb is Projectile:
			var vx: float = float(hb.get("_velocity_x"))
			if absf(rel.y) > 55.0 or is_zero_approx(vx) or signf(vx) != signf(rel.x):
				continue
			if absf(rel.x) / absf(vx) < 0.35:
				return "projectile"
		elif rel.length() < 110.0:
			return "area"
	return ""

## 막을 수 있으면 막고(확률), 못 막으면 공격 종류에 맞게 피한다
func _respond_to_threat(kind: String) -> void:
	var guard_p: float = clampf(guard_react_chance * guard_bias, 0.0, 0.95)
	# 열차가 오는 중엔 피난처를 벗어나는 회피(대시·점프)는 안 한다 — 고양이를 피하려다 의자에서 떨어져 열차에 맞았다(실측).
	# 방어도 피난처에 이미 서 있을 때만(피하러 가는 도중에 막으면 제자리에 굳어 열차에 맞는다)
	if _hazard_active():
		if _on_safe_spot() and fighter.can_guard() and randf() < guard_p:
			fighter.start_guard()
		return
	# 카운터 스킬이 있으면 방어 대신 카운터 자세 — 막기만 하는 것보다 이득이다
	if _try_counter_stance(guard_p):
		return
	if fighter.can_guard() and randf() < guard_p:
		fighter.start_guard()
		return
	if randf() >= dodge_react_chance:
		return
	var away: float = signf(fighter.global_position.x - target.global_position.x)
	if is_zero_approx(away):
		away = -target.facing
	match kind:
		"projectile", "charge":
			# 땅으로 오는 건 뛰어넘는다(비비탄·자전거)
			if fighter.is_on_floor():
				fighter.jump()
			elif fighter.can_dash():
				fighter.dash(away)
		_:
			if fighter.can_dash():
				# 뒤가 막혔으면 상대를 뚫고 등 뒤로 빠진다(캐릭터끼리 몸 충돌이 없다)
				var dir: float = away if _room_behind(away) > 150.0 else -away
				fighter.dash(dir)

## 스킬2가 카운터(CounterSkill)이고 쓸 수 있으면 chance 확률로 자세를 잡는다. 잡았으면 true
func _try_counter_stance(chance: float) -> bool:
	var s: Skill = fighter.skill_2
	if s == null or s.get_script() == null or s.get_script().get_global_name() != "CounterSkill":
		return false
	if not s.can_use() or fighter.is_busy():
		return false
	if randf() >= chance:
		return false
	fighter.use_skill_2()
	return true

## dir 쪽으로 벽까지 남은 거리(최대 220)
func _room_behind(dir: float) -> float:
	var from: Vector2 = fighter.global_position + Vector2(0.0, -10.0)
	var hit: Dictionary = PhysicsQuery.raycast_ignoring_fighters(fighter, from, from + Vector2(dir * 220.0, 0.0))
	if hit.is_empty():
		return 220.0
	return absf(hit.position.x - from.x)

## "ai_danger_zone" 그룹에 지금 위험한 기믹이 하나라도 있는지
func _hazard_active() -> bool:
	for hazard in get_tree().get_nodes_in_group("ai_danger_zone"):
		if hazard.has_method("is_dangerous") and hazard.is_dangerous():
			return true
	return false

# ---------------------------------------------------------------- 맵 기믹·왕관

## 맵 기믹(지나가는 열차 등)이 위험한 상태면 싸움을 잠깐 멈추고 가장 가까운 안전지대(ai_safe_spot)로 피신한다.
## 실제로 피신 판단을 했으면 true를 돌려줘서 평소 이동 판단을 건너뛰게 한다.
## 위험한 맵이 아니면(ai_danger_zone/ai_safe_spot가 씬에 하나도 없으면) 항상 false라 기존 동작 그대로다
func _try_dodge_hazard() -> bool:
	if not _hazard_active():
		return false

	var spot: Node2D = _nearest_safe_spot()
	if spot == null:
		return false

	# 발판 위에 실제로 착지해서 버티는 조건 — is_on_floor()까지 같이 봐야 한다.
	# 높이만 보면 점프 도중 목표 높이를 스쳐 지나가는 순간에도 "다 왔다"고 착각해 이단 점프를 안 누르고 떨어졌다
	if fighter.is_on_floor() and fighter.global_position.y <= spot.global_position.y + 4.0:
		fighter.move(0.0)
		_dodge_jump_stage = 0
		# 같은 피난처에 올라온 상대가 코앞이면 제자리에서 때린다(밀려 떨어지는 건 상대 쪽이다)
		var tdx: float = target.global_position.x - fighter.global_position.x
		if absf(tdx) <= _melee_reach and absf(target.global_position.y - fighter.global_position.y) < 30.0 \
				and not target.is_guarding and not fighter.is_basic_attack_locked():
			fighter.facing = signf(tdx) if not is_zero_approx(tdx) else fighter.facing
			fighter.use_basic_attack()
		return true

	# 발판이 아니라 진짜 바닥에 도로 내려왔다 — 처음부터 다시 시도한다 (한 번에 못 닿았을 때의 재시도)
	if fighter.is_on_floor():
		_dodge_jump_stage = 0

	var dx: float = spot.global_position.x - fighter.global_position.x
	if absf(dx) > 16.0:
		fighter.move(signf(dx))
		if absf(dx) > dash_dodge_distance:
			fighter.dash(signf(dx))
		_dodge_jump_stage = 0
	else:
		fighter.move(0.0)
		# 2단 점프는 1단의 정점(velocity.y >= 0)에서 — 공중 점프는 속도를 덮어써서, 오르는 중에 쓰면 1단 높이를 버린다
		if _dodge_jump_stage == 0:
			fighter.jump()
			_dodge_jump_stage = 1
		elif _dodge_jump_stage == 1 and fighter.velocity.y >= 0.0:
			fighter.jump()
			_dodge_jump_stage = 2
	return true

## 발 높이로 오가는 방해물("ai_jump_over" 그룹, 놀이터 그네)을 향해 가고 있으면 앞에서 뛰어넘는다(정점에서 모자라면 이단 점프)
func _jump_obstacles() -> void:
	var dir: float = signf(fighter.move_input)
	if is_zero_approx(dir) or _in_combo():
		return
	var feet: float = _feet_y(fighter)
	for node in get_tree().get_nodes_in_group("ai_jump_over"):
		if not node.has_method("ai_obstacle_position"):
			continue
		var p: Vector2 = node.ai_obstacle_position()
		var ahead: float = (p.x - fighter.global_position.x) * dir
		if ahead < -30.0 or ahead > 110.0 or p.y > feet + 10.0 or p.y < feet - 140.0:
			continue
		if fighter.is_on_floor() or fighter.velocity.y > -60.0:
			fighter.jump()
		return

# ---------------------------------------------------------------- 끼임 탈출

## 지난 프레임에 가려고 했는데(move_input) 바닥에서 가로 속도가 0이면 끼인 것이다.
## 벽이면 그 자리에서 뛰고, 벽이 아니면(기울어진 천장 밑) 반대로 물러나는 우회를 시작한다
func _update_stuck(delta: float) -> void:
	_no_drop_left = maxf(_no_drop_left - delta, 0.0)
	if _detour_left > 0.0 or _escape_dir != 0.0:
		_stuck_time = 0.0
		return
	if fighter.is_on_floor() and absf(fighter.move_input) > 0.0 and absf(fighter.velocity.x) < 5.0 \
			and not fighter.is_busy() and not fighter.is_guarding:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
	if _stuck_time < 0.2:
		return
	_stuck_time = 0.0
	if fighter.is_on_wall():
		fighter.jump()
		return
	_detour_dir = -signf(fighter.move_input)
	_detour_left = 1.5

## 우회 중이면 true — 머리 위가 뚫린 곳까지 물러난 뒤 뛰고, 정점에서 이단 점프하며 원래 방향으로 넘어간다
func _run_detour(delta: float) -> bool:
	if _escape_dir != 0.0:
		if fighter.is_on_floor():
			_escape_wait += delta
			# 착지했거나, 뛰었는데 천장에 막혀 못 떴으면 탈출을 접는다(다시 끼이면 새로 우회한다)
			if _escape_airborne or _escape_wait > 0.2:
				_escape_dir = 0.0
				return false
			fighter.move(0.0)
			return true
		_escape_airborne = true
		# 곧게 올라가 1단 정점에서 이단 점프, **이단 점프의 정점까지도 곧게** 오른 뒤에야 원래 방향으로 간다
		# (이단 점프 직후 옆으로 틀면 미끄럼틀 판 밑에 다시 부딪혀 떨어졌다)
		if fighter.velocity.y > -60.0:
			if not _escape_air_jumped:
				fighter.jump()
				_escape_air_jumped = true
				fighter.move(0.0)
			else:
				fighter.move(_escape_dir)
		else:
			fighter.move(0.0)
		return true
	if _detour_left <= 0.0:
		return false
	_detour_left -= delta
	fighter.move(_detour_dir)
	if _head_clear() or _detour_left <= 0.0:
		_detour_left = 0.0
		fighter.move(0.0)
		fighter.jump()
		_escape_dir = -_detour_dir
		_escape_airborne = false
		_escape_air_jumped = false
		_escape_wait = 0.0
		_no_drop_left = 2.0
	return true

## 머리 위 150px가 비었는지(통과 발판은 빈 것으로 본다).
## 광선은 몸 가운데서 쏜다 — 머리 끝에서 쏘면 이미 천장 판 안에서 출발해 판을 못 본다(미끄럼틀 밑에서 겪음)
## 몸 가운데 한 줄만 보면 몸 옆으로 비어져 나온 판 모서리를 놓친다 — 양 어깨 너비(±16)도 같이 본다
func _head_clear() -> bool:
	for off in [-16.0, 0.0, 16.0]:
		var from: Vector2 = fighter.global_position + Vector2(off, 0.0)
		var hit: Dictionary = PhysicsQuery.raycast_ignoring_fighters(fighter, from, from + Vector2(0.0, -185.0))
		if hit.is_empty():
			continue
		var body = hit.collider
		if not (body is CollisionObject2D):
			return false
		var owner_id: int = body.shape_find_owner(hit.shape)
		if owner_id == -1 or not body.is_shape_owner_one_way_collision_enabled(owner_id):
			return false
	return true

## 안전지대(피난 발판) 위에 착지해 있는지
func _on_safe_spot() -> bool:
	var spot: Node2D = _nearest_safe_spot()
	return spot != null and fighter.is_on_floor() and fighter.global_position.y <= spot.global_position.y + 4.0

func _nearest_safe_spot() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for spot in get_tree().get_nodes_in_group("ai_safe_spot"):
		var d: float = absf(spot.global_position.x - fighter.global_position.x)
		if d < nearest_dist:
			nearest = spot
			nearest_dist = d
	return nearest

## 주울 수 있는 왕관(놀이터)이 있으면 싸움을 미루고 주우러 간다 — 높은 발판 위에 있어도 발판 길찾기로 올라간다.
## 상대가 코앞에 있으면 등을 보이지 않고 싸움을 먼저 한다. 왕관 없는 맵에서는 항상 false
func _try_take_crown(delta: float) -> bool:
	# Node로 받으면 is_available()/global_position에서 컴파일 에러가 난다 — Crown으로 캐스팅해서 쓴다
	var crown := get_tree().get_first_node_in_group("crown") as Crown
	if crown == null:
		return false
	# 내가 이미 왕이면 굳이 갈 이유가 없고, 남이 쓰고 있으면 때려서 떨어뜨려야 하니 평소대로 싸운다
	if Crown.is_king(fighter) or not crown.is_available():
		return false
	var dx: float = crown.global_position.x - fighter.global_position.x
	if absf(dx) > crown_interest_range:
		return false
	if _target_distance() < _melee_reach + 30.0 and absf(target.global_position.y - fighter.global_position.y) < 60.0:
		return false
	var goal = _support_under(crown.global_position.x, crown.global_position.y + 8.0)
	if goal != null and _navigate(goal, crown.global_position.x, delta):
		return true
	# 같은 발판 위 — 걸어가서 몸으로 닿는다
	fighter.move(signf(dx) if absf(dx) > 4.0 else 0.0)
	if fighter.is_on_floor() and (fighter.is_on_wall() or crown.global_position.y < fighter.global_position.y - 40.0):
		fighter.jump()
	return true

# ---------------------------------------------------------------- 발판 길찾기

## 맵의 발판·바닥(StaticBody2D의 직사각형 충돌)을 1초마다 다시 모은다 — 부서지는 발판(공사현장)이 사라지고 돌아오므로
func _refresh_platforms(delta: float) -> void:
	_platform_refresh -= delta
	if _platform_refresh > 0.0 and not _platforms.is_empty():
		return
	_platform_refresh = 1.0
	_platforms.clear()
	var pads: Array = []
	var map: Node = fighter.get_parent()
	if map:
		_collect(map, pads)
	# 스프링 좌석: 튕기는 판정(JumpPad)이 바로 위에 있는 발판
	for pad in pads:
		for p in _platforms:
			if pad.global_position.x > p.left and pad.global_position.x < p.right \
					and pad.global_position.y > p.top - 70.0 and pad.global_position.y < p.top + 10.0:
				p.spring_v = float(pad.get("bounce_velocity"))

func _collect(node: Node, pads: Array) -> void:
	for child in node.get_children():
		if child is Fighter:
			continue
		if child is SpringJumpPad:
			pads.append(child)
		if child is StaticBody2D and not (child.get("_broken") == true):
			for cs in child.get_children():
				_add_platform(cs)
		_collect(child, pads)

func _add_platform(cs: Node) -> void:
	var shape_node := cs as CollisionShape2D
	if shape_node == null or shape_node.disabled or not (shape_node.shape is RectangleShape2D):
		return
	var t: Transform2D = shape_node.global_transform
	if absf(t.get_rotation()) > 0.05:
		return
	var size: Vector2 = (shape_node.shape as RectangleShape2D).size * t.get_scale().abs()
	if size.x < 24.0:
		return
	_platforms.append({
		"id": shape_node.get_instance_id(),
		"left": t.origin.x - size.x * 0.5,
		"right": t.origin.x + size.x * 0.5,
		"top": t.origin.y - size.y * 0.5,
		"one_way": shape_node.one_way_collision,
		"spring_v": 0.0,
	})

func _feet_y(f: Fighter) -> float:
	return f.global_position.y + FEET_OFFSET

## (x, feet_y) 바로 아래(또는 그 높이)에 있는 가장 높은 발판
func _support_under(x: float, feet_y: float):
	var best = null
	for p in _platforms:
		if x < p.left - 4.0 or x > p.right + 4.0 or p.top < feet_y - 8.0:
			continue
		if best == null or p.top < best.top:
			best = p
	return best

func _current_support():
	if not fighter.is_on_floor():
		return null
	return _support_under(fighter.global_position.x, _feet_y(fighter))

## 1단·2단 점프로 오를 수 있는 높이
func _jump_height() -> float:
	var v: float = Fighter.jump_velocity * fighter.jump_multiplier
	return v * v / (2.0 * Fighter.gravity)

func _air_jump_height() -> float:
	if Fighter.max_air_jumps <= 0:
		return 0.0
	var v: float = Fighter.air_jump_velocity * fighter.jump_multiplier
	return v * v / (2.0 * Fighter.gravity)

## a 발판에서 b 발판으로 한 번에 갈 수 있는지
func _can_reach(a: Dictionary, b: Dictionary) -> bool:
	if a.id == b.id:
		return false
	var up: float = a.top - b.top
	var gap: float = maxf(0.0, maxf(b.left - a.right, a.left - b.right))
	if up > 4.0:
		var limit: float = _jump_height() + _air_jump_height()
		if a.spring_v > 0.0:
			limit = a.spring_v * a.spring_v / (2.0 * Fighter.gravity) + _air_jump_height()
		if up > limit - 14.0:
			return false
		# 막힌(원웨이 아닌) 발판은 밑에서 뚫고 못 올라가니, a에서 b 옆으로 비켜 설 자리가 있어야 한다
		if not b.one_way and gap <= 0.0 and a.left > b.left - 30.0 and a.right < b.right + 30.0:
			return false
		return gap <= 110.0
	return gap <= 110.0 + (-up) * 0.3

## start에서 goal까지 가장 적게 갈아타는 길의 **다음 발판**(없으면 null)
func _plan_next(start: Dictionary, goal: Dictionary):
	var n: int = _platforms.size()
	var cost: Array = []
	var prev: Array = []
	var done: Array = []
	cost.resize(n)
	prev.resize(n)
	done.resize(n)
	var s: int = -1
	var g: int = -1
	for i in n:
		cost[i] = INF
		prev[i] = -1
		done[i] = false
		if _platforms[i].id == start.id:
			s = i
		if _platforms[i].id == goal.id:
			g = i
	if s < 0 or g < 0:
		return null
	cost[s] = 0.0
	for _step in n:
		var u: int = -1
		for i in n:
			if not done[i] and (u < 0 or cost[i] < cost[u]):
				u = i
		if u < 0 or cost[u] == INF:
			break
		done[u] = true
		if u == g:
			break
		for v in n:
			if done[v] or not _can_reach(_platforms[u], _platforms[v]):
				continue
			var c: float = cost[u] + 1.0 + absf(_center(_platforms[v]) - _center(_platforms[u])) / 600.0
			if c < cost[v]:
				cost[v] = c
				prev[v] = u
	if cost[g] == INF:
		return null
	var cur: int = g
	while prev[cur] != s:
		cur = prev[cur]
		if cur < 0:
			return null
	return _platforms[cur]

func _center(p: Dictionary) -> float:
	return (p.left + p.right) * 0.5

## 상대가 다른 층(발판)에 서 있으면 그쪽으로 길을 찾아간다. 길을 따라 움직였으면 true
func _navigate_to_target(delta: float) -> bool:
	if _target_distance() < _melee_reach + 20.0 and absf(target.global_position.y - fighter.global_position.y) < 50.0:
		_nav_next = null
		return false
	var goal = _support_under(target.global_position.x, _feet_y(target))
	if goal == null:
		return false
	return _navigate(goal, target.global_position.x, delta)

## goal 발판(goal_x 근처)으로 한 걸음. 이미 같은 발판이면 false(평소 판단에 맡긴다)
func _navigate(goal: Dictionary, goal_x: float, delta: float) -> bool:
	if not fighter.is_on_floor():
		if _nav_next == null:
			return false
		_nav_air_control(goal_x)
		return true
	var mine = _current_support()
	if mine == null or mine.id == goal.id:
		_nav_next = null
		return false
	_plan_timer -= delta
	if _nav_next == null or _nav_from_id != mine.id or _plan_timer <= 0.0:
		_nav_next = _plan_next(mine, goal)
		_nav_from_id = mine.id
		_plan_timer = nav_replan_interval
	if _nav_next == null:
		return false
	_nav_ground_step(mine, _nav_next, goal_x)
	return true

## 발판 위에서: 올라갈 거면 도약 자리로 가서 뛰고, 내려갈 거면 발판을 뚫고 내려가거나 가장자리로 걸어 나간다
func _nav_ground_step(cur: Dictionary, nxt: Dictionary, goal_x: float) -> void:
	var x: float = fighter.global_position.x
	_nav_takeoff_top = cur.top
	if nxt.top < cur.top - 4.0:
		# 스프링 좌석 위에 서면 알아서 튕긴다 — 여기서 점프를 누르면 튕기는 속도를 덮어써서 오히려 낮게 뜬다
		if cur.spring_v > 0.0:
			fighter.move(0.0)
			return
		var tx: float = _takeoff_x(cur, nxt, x)
		if absf(tx - x) > 10.0:
			fighter.move(signf(tx - x))
			if absf(tx - x) > 260.0:
				fighter.dash(signf(tx - x))
		else:
			fighter.move(0.0)
			fighter.jump()
		return
	var land_x: float = clampf(goal_x, nxt.left + 20.0, nxt.right - 20.0)
	if cur.one_way and _no_drop_left <= 0.0 and nxt.top > cur.top + 4.0 and x > nxt.left + 10.0 and x < nxt.right - 10.0:
		if fighter.drop_through_platform():
			return
	fighter.move(signf(land_x - x) if absf(land_x - x) > 6.0 else 0.0)
	# 옆 발판이 거의 같은 높이인데 사이가 비었으면 가장자리에서 뛰어 건넌다
	var near_edge: bool = x > cur.right - 18.0 or x < cur.left + 18.0
	if fighter.is_on_wall() or (near_edge and nxt.top < cur.top + 40.0 and (nxt.left > cur.right or nxt.right < cur.left)):
		fighter.jump()

## cur 위 어디서 뛰어야 nxt에 닿는지
func _takeoff_x(cur: Dictionary, nxt: Dictionary, x: float) -> float:
	var l: float = maxf(cur.left, nxt.left) + 16.0
	var r: float = minf(cur.right, nxt.right) - 16.0
	if nxt.one_way and l <= r:
		return clampf(x, l, r)
	if not nxt.one_way and nxt.right > cur.left and nxt.left < cur.right:
		# 막힌 발판 — 바로 옆 바깥에서 뛴다(둘 중 cur 위에 있고 가까운 쪽)
		var spots: Array = []
		if nxt.left - 28.0 > cur.left:
			spots.append(nxt.left - 28.0)
		if nxt.right + 28.0 < cur.right:
			spots.append(nxt.right + 28.0)
		if not spots.is_empty():
			spots.sort_custom(func(a, b): return absf(a - x) < absf(b - x))
			return spots[0]
	if nxt.left >= cur.right - 16.0:
		return cur.right - 12.0
	return cur.left + 12.0

## 뛰어오른 뒤 공중에서: 목표 발판 쪽으로 몸을 틀고, 정점 근처에서 아직 모자라면 이단 점프
func _nav_air_control(goal_x: float) -> void:
	var p: Dictionary = _nav_next
	var x: float = fighter.global_position.x
	var feet: float = _feet_y(fighter)
	var land_x: float = clampf(goal_x, p.left + 24.0, p.right - 24.0)
	var going_up: bool = p.top < _nav_takeoff_top - 4.0
	if not going_up or p.one_way or feet < p.top - 2.0:
		fighter.move(signf(land_x - x) if absf(land_x - x) > 8.0 else 0.0)
	else:
		fighter.move(0.0)
	if going_up and fighter.velocity.y > -60.0 and feet > p.top - 10.0:
		fighter.jump()   # 남은 공중 점프가 없으면 Fighter가 조용히 무시한다

# ---------------------------------------------------------------- 거리 싸움

func _target_distance() -> float:
	return absf(target.global_position.x - fighter.global_position.x)

## 기본공격 콤보가 이어지는 중인지(휘두르는 중이거나 다음 타를 기다리는 중)
func _in_combo() -> bool:
	var ba: Skill = fighter.basic_attack
	if ba == null:
		return false
	return ba.get("_swinging") == true or int(ba.get("_step") if ba.get("_step") != null else 0) > 0

## 상대가 지금 반격하기 어려운 빈틈 상태인지 — 경직·착지 경직·방어에 막혀 공격 잠김·헛손질 쿨·스킬 모션 중
func _target_vulnerable() -> bool:
	if target.is_busy() or target.is_basic_attack_locked():
		return true
	var ba: Skill = target.basic_attack
	return ba != null and ba.get("_swinging") != true and ba.cooldown_left > 0.25

func _target_can_attack() -> bool:
	var ba: Skill = target.basic_attack
	return ba != null and ba.can_use() and not target.is_basic_attack_locked() and not target.is_busy()

func _decide_movement(delta: float) -> void:
	var dx: float = target.global_position.x - fighter.global_position.x
	var dist: float = absf(dx)
	var dir: float = signf(dx) if not is_zero_approx(dx) else fighter.facing
	var dy: float = absf(target.global_position.y - fighter.global_position.y)

	if _retreat_timer > 0.0:
		_retreat_timer -= delta
		fighter.move(-dir)
		fighter.dash(-dir)
		# move()와 dash()가 둘 다 facing을 이동 방향으로 돌리므로 상대 쪽으로 다시 잡는다(스킬이 반대로 나가지 않게)
		fighter.facing = dir
		return

	var ba: Skill = fighter.basic_attack
	# 1) 콤보 중 — 밀려난 상대를 따라가며 계속 누른다(휘두르는 중 누르면 예약돼서 맞으면 바로 다음 타)
	if knows_follow_ups and _in_combo():
		fighter.move(dir if dist > _melee_reach - 8.0 else 0.0)
		fighter.facing = dir
		if dist <= _melee_reach + 45.0 and dy < 60.0:
			fighter.use_basic_attack()
		return

	var can_hit: bool = ba != null and not fighter.is_basic_attack_locked() and not target.is_guarding
	# 후속타를 모르면 콤보가 이어지는 동안(다음 타 대기)과 날아가는 상대에겐 안 친다 — 콤보가 끊긴 뒤 1타부터 다시
	if not knows_follow_ups and (_in_combo() or target.is_finisher_flying()):
		can_hit = false
	# 2) 상대가 방어 중이거나 내 공격이 잠겼다 — 치면 손해다. 상대 사거리 바로 바깥에서 기다린다
	if not can_hit:
		var wait_at: float = _reach_of(target) + 45.0
		if dist < wait_at:
			fighter.move(-dir)
		elif dist > wait_at + 40.0:
			fighter.move(dir)
		else:
			fighter.move(0.0)
		fighter.facing = dir
		return

	var punish: bool = knows_follow_ups and _target_vulnerable()
	# 3) 원거리 캐릭터는 원거리 스킬이 준비됐을 때만 거리를 둔다(아니면 근접으로 싸운다)
	if _is_ranged and not punish and fighter.skill_2 and fighter.skill_2.can_use():
		if dist > ranged_distance + 20.0:
			fighter.move(dir)
		elif dist < ranged_distance - 20.0:
			fighter.move(-dir)
			fighter.dash(-dir)
		else:
			fighter.move(0.0)
		fighter.facing = dir
		if dist <= _melee_reach and dy < 45.0:
			fighter.use_basic_attack()
		return

	# 4) 근접 — 사거리 바로 바깥에서 가끔 멈칫해 헛손질을 유도하고, 빈틈이 보이면 파고든다
	if _hold_timer > 0.0 and not punish:
		_hold_timer -= delta
		fighter.move(0.0)
		fighter.facing = dir
		return
	_hold_timer = 0.0
	if dist > _melee_reach - 12.0:
		fighter.move(dir)
		if dy < 80.0 and (dist > dash_approach_distance or (punish and dist > 200.0)):
			fighter.dash(dir)
		if fighter.is_on_wall() and fighter.is_on_floor():
			fighter.jump()
		var their_reach: float = _reach_of(target)
		if not punish and dist > their_reach + 10.0 and dist < their_reach + 70.0 and _target_can_attack() and randf() < bait_chance:
			_hold_timer = randf_range(0.15, 0.4)
	else:
		fighter.move(0.0)
	fighter.facing = dir
	if dist <= _melee_reach and dy < 45.0:
		fighter.use_basic_attack()

	if dist > 200.0 and randf() < jump_chance:
		fighter.jump()
	if _is_ranged and _all_skills_on_cooldown() and randf() < retreat_start_chance:
		_retreat_timer = retreat_duration

# ---------------------------------------------------------------- 구경 모드(타이틀)

## 보여주기용 움직임 — 잠깐(showcase_kite_time) showcase_keep_distance를 벌리고 이단 점프·대시로 돌아다니다가 다가간다.
## 다가가는 동안 조건 맞는 스킬이 있으면 _decide_skills가 쓰고, 평타 거리까지 붙으면 3타 콤보를 한 번 친다 — 어느 쪽이든 끝나면 다시 빠진다.
## 화면(카메라에 보이는 곳) 가장자리를 넘어가려 하면 안쪽으로 되돌린다
func _showcase_movement(delta: float) -> void:
	var dx: float = target.global_position.x - fighter.global_position.x
	var dist: float = absf(dx)
	var dir: float = signf(dx) if not is_zero_approx(dx) else fighter.facing
	var dy: float = absf(target.global_position.y - fighter.global_position.y)
	var x: float = fighter.global_position.x
	var view: Rect2 = _view_rect()
	_show_timer -= delta
	_showcase_air_jump(delta)

	# 평타 콤보 중 — 밀려난 상대를 따라가며 3타까지 누르고, 콤보가 끝나면(3타 또는 헛침) 빠진다
	if _show_combo:
		if not _in_combo():
			_show_combo = false
			_end_engage()
		else:
			fighter.move(dir if dist > _melee_reach - 8.0 else 0.0)
			fighter.facing = dir
			if dist <= _melee_reach + 45.0 and dy < 60.0:
				fighter.use_basic_attack()
			return

	if _show_engage:
		if _show_timer <= 0.0:
			_end_engage()
		else:
			fighter.move(dir if dist > 70.0 else 0.0)
			if dist > dash_approach_distance and dy < 80.0:
				fighter.dash(dir)
			if fighter.is_on_wall() and fighter.is_on_floor():
				fighter.jump()
			fighter.facing = dir
			if dist <= _melee_reach and dy < 45.0:
				var ba: Skill = fighter.basic_attack
				# 스킬 위주(사용자 요청) — 쓸 스킬이 남아 있으면 평타는 참고 빠져서 스킬을 쓴다
				if _any_skill_ready():
					_end_engage()
				elif ba and ba.can_use() and not fighter.is_basic_attack_locked() and not target.is_guarding:
					fighter.use_basic_attack()
					_show_combo = true
				else:
					_end_engage()
			return

	var keep: float = showcase_keep_distance
	var away: float = -dir
	if _show_cross > 0.0:
		# 벽·화면 끝에 몰렸다 — 상대를 뛰어넘어 반대편으로(캐릭터끼리 몸 충돌이 없다)
		_show_cross -= delta
		fighter.move(dir if dist < 60.0 or _show_cross > 0.35 else away)
	elif dist < keep - 40.0:
		if (_room_behind(away) < 70.0 or not _in_view_x(view, x + away * 60.0)) and fighter.is_on_floor():
			_show_cross = 0.7
			_showcase_hop()
			fighter.move(dir)
		else:
			fighter.move(away)
			if dist < keep * 0.6 and _in_view_x(view, x + away * 200.0):
				fighter.dash(away)
	elif dist > keep + 80.0:
		fighter.move(dir)
	else:
		fighter.move(0.0)

	_show_hop -= delta
	if _show_hop <= 0.0 and fighter.is_on_floor():
		_show_hop = randf_range(showcase_hop_interval.x, showcase_hop_interval.y)
		_showcase_hop()
	_show_dash -= delta
	if _show_dash <= 0.0:
		_show_dash = randf_range(showcase_dash_interval.x, showcase_dash_interval.y)
		# 뒤가 트였고 화면 안이면 뒤로, 아니면 멀 때만 앞으로(거리를 너무 좁히지 않는 선에서)
		if _room_behind(away) > 150.0 and _in_view_x(view, x + away * 200.0):
			fighter.dash(away)
		elif dist > keep and _in_view_x(view, x + dir * 200.0):
			fighter.dash(dir)

	# 화면 가장자리를 넘어가려 하면 안쪽으로 걷는다
	if view.size.x > 0.0:
		if x < view.position.x + showcase_screen_margin:
			fighter.move(1.0)
		elif x > view.end.x - showcase_screen_margin:
			fighter.move(-1.0)
	fighter.facing = dir

	if _show_timer <= 0.0:
		_show_engage = true
		_show_timer = showcase_engage_time

## 스킬1·스킬2·궁 중 지금 쓸 수 있는 게 하나라도 있는지
func _any_skill_ready() -> bool:
	for skill in [fighter.skill_1, fighter.skill_2, fighter.skill_ultimate]:
		if skill and skill.can_use():
			return true
	return false

## 지금 카메라에 보이는 월드 영역(카메라가 없으면 빈 Rect2)
func _view_rect() -> Rect2:
	var vp: Viewport = fighter.get_viewport()
	var cam: Camera2D = vp.get_camera_2d() if vp else null
	if cam == null:
		return Rect2()
	var half: Vector2 = vp.get_visible_rect().size * 0.5 / cam.zoom
	return Rect2(cam.get_screen_center_position() - half, half * 2.0)

## x가 화면 가장자리(showcase_screen_margin 안쪽)를 넘지 않는지. 화면을 모르면 true
func _in_view_x(view: Rect2, x: float) -> bool:
	if view.size.x <= 0.0:
		return true
	return x > view.position.x + showcase_screen_margin and x < view.end.x - showcase_screen_margin

## 1단 점프 후 정점 근처에서 2단 점프까지 쓰게 예약한다
func _showcase_hop() -> void:
	fighter.jump()
	_show_air_pending = true
	_show_air_age = 0.0

func _showcase_air_jump(delta: float) -> void:
	if not _show_air_pending:
		return
	_show_air_age += delta
	if not fighter.is_on_floor() and fighter.velocity.y > -60.0:
		fighter.jump()
		_show_air_pending = false
	elif fighter.is_on_floor() and _show_air_age > 0.2:
		_show_air_pending = false

## 다가가기를 끝내고 잠깐 거리를 벌린다
func _end_engage() -> void:
	_show_engage = false
	_show_timer = randf_range(showcase_kite_time.x, showcase_kite_time.y)

func _all_skills_on_cooldown() -> bool:
	for skill in [fighter.skill_1, fighter.skill_2, fighter.skill_ultimate]:
		if skill and skill.can_use():
			return false
	return true

# ---------------------------------------------------------------- 스킬 판단

## 스킬마다 "지금 쓰면 맞는지"를 따져서 맞을 때만 쓴다(예전엔 매 프레임 2% 확률로 아무 때나 썼다)
func _decide_skills(delta: float) -> void:
	_skill_timer -= delta
	if _skill_timer > 0.0:
		return
	_skill_timer = skill_think_interval
	if fighter.is_busy() or fighter.is_guarding or fighter.movement_override != null or fighter.is_feared:
		return
	_try_map_skill()
	var dir: float = signf(target.global_position.x - fighter.global_position.x)
	var slots: Array = [[fighter.skill_1, 1], [fighter.skill_2, 2], [fighter.skill_ultimate, 3]]
	for pair in slots:
		var skill: Skill = pair[0]
		var slot: int = pair[1] - 1
		if skill == null or not skill.can_use():
			_show_skill_wait[slot] = 0.0
			continue
		var want: bool = _want_skill(skill)
		if showcase and not want:
			# 구경 모드 — 조건이 안 맞아도 오래 못 썼으면 상대가 적당히 가까울 때 그냥 쓴다
			_show_skill_wait[slot] += skill_think_interval
			want = _show_skill_wait[slot] >= showcase_skill_patience and _target_distance() < showcase_skill_range
		if not want:
			continue
		if randf() >= skill_commit_chance:
			continue
		_show_skill_wait[slot] = 0.0
		if not is_zero_approx(dir):
			fighter.facing = dir
		match pair[1]:
			1: fighter.use_skill_1()
			2: fighter.use_skill_2()
			3: fighter.use_ultimate()
		if showcase and not _show_combo:
			_end_engage()
		return

## 맵 전용 스킬(공사현장 내리찍기) — 공중에서 상대 바로 위에 있을 때
func _try_map_skill() -> void:
	if fighter.map_skill == null or fighter.is_on_floor() or not fighter.map_skill.can_use():
		return
	if _target_distance() < 40.0 and target.global_position.y - fighter.global_position.y > 60.0:
		fighter.use_map_skill()

## 이 스킬을 지금 쓸 만한지 — 스킬 스크립트 종류별 사거리·조건
func _want_skill(skill: Skill) -> bool:
	var kind: String = ""
	if skill.get_script():
		kind = skill.get_script().get_global_name()
	var d: float = _target_distance()
	var dy: float = absf(target.global_position.y - fighter.global_position.y)
	var level: bool = dy < 40.0
	var open: bool = not target.is_guarding
	var hp: float = float(fighter.current_hp) / maxf(float(fighter.stats.max_hp), 1.0) if fighter.stats else 1.0
	match kind:
		"DashSkill":
			var reach: float = fighter.stats.move_speed * float(skill.get("dash_speed_multiplier")) * float(skill.get("dash_duration"))
			return level and open and fighter.is_on_floor() and d > 90.0 and d < reach * 0.85
		"BBGunSkill":
			return level and open and d > 90.0 and d < 650.0
		"HealSkill":
			return hp < 0.5 or (hp < 0.7 and d > 300.0)
		"JjajangEatSkill":
			# 먹다 맞으면 끊기므로 멀리 떨어졌을 때만. 먹을수록 대시 쿨이 느니 체력이 꽤 깎였을 때만
			return hp < 0.5 and d > 300.0
		"MouseGrabSkill":
			return level and fighter.is_on_floor() and target.can_be_grabbed() and d > 110.0 and d < 500.0
		"RageBuffSkill":
			return d < 220.0 and not fighter.is_basic_attack_locked()
		"DrinkSkill":
			var stacks: int = int(fighter.custom_data.get("drink_stacks", 0))
			return stacks < int(skill.get("max_stacks")) and d > 230.0
		"VomitSkill":
			var st: int = int(fighter.custom_data.get("drink_stacks", 0))
			var beam: float = float(skill.get("base_range")) + st * float(skill.get("range_per_stack"))
			return st >= 1 and level and open and d < beam * 0.85
		"ScreamConeUltimate":
			return open and d < 300.0 and dy < 40.0 + d * 0.45
		"TunaThrowSkill":
			return d > 90.0 and d < 500.0
		"TunaPlaceSkill":
			return d > 140.0
		"AoeAttack":
			var r: float = float(skill.get("radius"))
			return open and d < r * 0.9 and dy < r
		"VacuumSkill":
			return level and open and d > 50.0 and d < float(skill.get("range"))
		"DunkUltimate":
			var leap: float = float(skill.get("leap_speed")) * float(skill.get("leap_duration"))
			return open and d > 70.0 and d < leap * 1.1
		"TurnstileSkill":
			# 다가오는 상대 앞에 개찰구를 깔아 발을 묶는다
			return level and d > 90.0 and d < 260.0 and signf(target.velocity.x) == -signf(target.global_position.x - fighter.global_position.x)
		"FearSkill":
			return level and open and d < float(skill.get("range")) * 0.85
		"CounterSkill":
			# 아무 때나 켜면 헛방 — 상대 공격을 읽었을 때만 _respond_to_threat()이 쓴다
			return false
		"TteokbokkiUltimate":
			return level and d > 40.0 and d < 350.0
		"BackSuplexSkill":
			return level and target.can_be_grabbed() and d < float(skill.get("fallback_grab_range")) + 15.0
		"CigaretteSmokeSkill":
			return level and open and d < 170.0
		"ShoulderChargeSkill":
			return level and open and d > 50.0 and d < float(skill.get("charge_speed")) * float(skill.get("charge_duration")) * 0.9
		"DropkickSkill":
			return level and open and fighter.is_on_floor() and d > 80.0 and d < float(skill.get("travel_distance")) * 0.9
		"WeakenAuraUltimate", "CatHutUltimate", "IljinCrewUltimate":
			return true
	# 모르는 스킬(빈 껍데기 포함) — 가까울 때 가끔
	return d < 250.0
