class_name AIController
extends Node

## 목표(대개 플레이어)와의 거리를 보고 접근/거리유지/후퇴/기본공격/스킬 사용을 스스로 결정하는 단순 AI.
## target을 직접 지정하지 않으면 씬에서 자기 자신이 아닌 첫 Fighter를 자동으로 목표로 삼는다 (1대1 전제)
@export var attack_range: float = 55.0
## 원거리 스킬(BB탄, 토하기 등)을 가진 캐릭터가 유지하려는 거리
@export var ranged_distance: float = 180.0
@export var skill_use_chance: float = 0.02  ## 매 물리 프레임마다 스킬 사용을 시도할 확률
## 자기 스킬이 전부 쿨타임이라 당장 할 게 없을 때, 매 프레임 뒤로 빠지기를 시작할 확률
@export var retreat_start_chance: float = 0.01
@export var retreat_duration: float = 0.5
## 매 프레임 그냥 한 번 뛰어볼 확률 (움직임이 뻣뻣해 보이지 않도록)
@export var jump_chance: float = 0.006
## 이 거리(px) 안에 주울 수 있는 왕관이 있으면 싸움을 미루고 주우러 간다 (놀이터 전용, 왕관 없는 맵은 무시)
@export var crown_interest_range: float = 520.0
## 왕관이 내 발밑보다 이만큼 위에 있으면 점프해서 따라간다
@export var crown_jump_height: float = 40.0
## 왕관이 내 발밑보다 이보다 더 높이 있으면 **아예 포기하고 평소처럼 싸운다**.
## 이 가드가 없으면 꼭대기 발판에 놓인 시작 왕관(발밑에서 588px 위)을 향해
## 영원히 그 아래를 서성이면서 싸움을 안 한다 — 발판을 밟고 올라가는 경로 탐색이 없기 때문
@export var crown_max_height: float = 120.0
@export var target: Fighter

## false면 아무 판단도 안 한다(대전 시작 카운트다운 등) — 그래도 중력·바닥 착지는 계속 처리한다
var is_active: bool = true

var _is_ranged: bool = false
var _retreat_timer: float = 0.0
## 안전지대로 피신할 때 이단 점프 진행 단계: 0=아직 안 뜀, 1=1단 뛰고 정점 기다리는 중, 2=2단까지 다 씀
var _dodge_jump_stage: int = 0

@onready var fighter: Fighter = get_parent()

func _ready() -> void:
	if target == null:
		target = fighter.find_opponent()
	# skill_2가 원거리 스킬(BB탄처럼 projectile_scene, 토하기 기둥처럼 beam_scene을 가진 스킬)이면
	# 원거리 캐릭터로 보고 거리를 두고 싸우게 한다. 캐릭터별로 따로 분기하지 않고 스킬 구성만으로 판단
	_is_ranged = fighter.skill_2 != null and (
		fighter.skill_2.get("projectile_scene") != null or fighter.skill_2.get("beam_scene") != null)

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

	if fighter.movement_override == null:
		if not _try_dodge_hazard() and not _try_take_crown():
			_decide_movement(delta)
	_decide_skills()

	fighter.apply_physics(delta)

## 바닥에 떨어진 왕관(놀이터)이 가까이 있으면 싸움을 잠깐 미루고 주우러 간다.
## 실제로 주우러 갔으면 true를 돌려줘서 평소 이동 판단을 건너뛴다 — `_try_dodge_hazard`와 같은 방식이다.
## 왕관이 없는 맵("crown" 그룹이 비어 있으면)에서는 항상 false라 기존 동작 그대로다.
##
## **초기 위치(꼭대기 발판)의 왕관까지는 못 올라간다.** 이 AI의 점프는 "벽에 막히면 뛴다" 수준이라
## 발판을 밟고 올라가는 경로 탐색이 없다. 바닥에 떨어진 왕관을 쟁탈하는 것까지만 한다
func _try_take_crown() -> bool:
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
	# 손이 닿지 않는 높이면 쳐다보지도 않는다 (Godot는 y가 작을수록 위쪽)
	if crown.global_position.y < fighter.global_position.y - crown_max_height:
		return false
	var dir: float = signf(dx)
	fighter.move(dir)
	fighter.facing = dir
	# 왕관이 머리 위로 한참 높거나 앞이 막혔으면 뛴다
	if fighter.is_on_wall() or crown.global_position.y < fighter.global_position.y - crown_jump_height:
		fighter.jump()
	return true

## 맵 기믹(지나가는 열차 등)이 위험한 상태면 싸움을 잠깐 멈추고 가장 가까운 안전지대(ai_safe_spot)로 피신한다.
## "ai_danger_zone" 그룹의 노드 중 하나라도 is_dangerous()가 true면 위험하다고 본다.
## 실제로 피신 판단을 했으면 true를 돌려줘서 평소 이동 판단(_decide_movement)을 건너뛰게 한다.
## 위험한 맵이 아니면(ai_danger_zone/ai_safe_spot가 씬에 하나도 없으면) 항상 false라 기존 동작 그대로다
func _try_dodge_hazard() -> bool:
	var danger := false
	for hazard in get_tree().get_nodes_in_group("ai_danger_zone"):
		if hazard.has_method("is_dangerous") and hazard.is_dangerous():
			danger = true
			break
	if not danger:
		return false

	var spot: Node2D = _nearest_safe_spot()
	if spot == null:
		return false

	# 발판 위에 실제로 착지해서 더 안 움직이고 버티는 조건 — is_on_floor()까지 같이 봐야 한다.
	# 높이만 보면, 점프 도중 목표 높이를 스쳐 지나가는 순간에도 "다 왔다"고 착각해서
	# 이단 점프를 이어서 안 누르고 그대로 떨어져버리는 버그가 있었다(점프 한 번만 하고 마는 것처럼 보임).
	# Godot는 y가 작을수록 위쪽이라 "<="가 "더 높거나 같음"이다
	if fighter.is_on_floor() and fighter.global_position.y <= spot.global_position.y + 4.0:
		fighter.move(0.0)
		_dodge_jump_stage = 0
		return true

	# 발판이 아니라 진짜 바닥에 도로 내려왔다 — 처음부터 다시 시도한다 (한 번에 못 닿았을 때의 재시도)
	if fighter.is_on_floor():
		_dodge_jump_stage = 0

	var dx: float = spot.global_position.x - fighter.global_position.x
	if absf(dx) > 16.0:
		fighter.move(signf(dx))
		_dodge_jump_stage = 0
	else:
		fighter.move(0.0)
		# 1단 점프를 뛰고, 곧바로 2단 점프를 잇지 않고 velocity.y가 0 이상(더 못 오르고 떨어지기 시작하는 정점)이
		# 될 때까지 기다렸다가 쏜다. jump()의 공중 점프는 그 순간까지 남아있던 속도를 "더하지" 않고
		# air_jump_velocity로 덮어쓰기 때문에, 1단 점프가 아직 한창 오르는 중에 곧바로 이어 쓰면
		# 1단으로 번 높이가 거의 다 날아가서 발판까지 못 닿는 버그가 있었다(밖에서 보면 "한 번만 뛰고 마는" 것처럼 보임)
		if _dodge_jump_stage == 0:
			fighter.jump()
			_dodge_jump_stage = 1
		elif _dodge_jump_stage == 1 and fighter.velocity.y >= 0.0:
			fighter.jump()
			_dodge_jump_stage = 2
	return true

func _nearest_safe_spot() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for spot in get_tree().get_nodes_in_group("ai_safe_spot"):
		var d: float = absf(spot.global_position.x - fighter.global_position.x)
		if d < nearest_dist:
			nearest = spot
			nearest_dist = d
	return nearest

func _decide_movement(delta: float) -> void:
	var dx: float = target.global_position.x - fighter.global_position.x
	var dist: float = absf(dx)
	var dir: float = signf(dx)

	if _retreat_timer > 0.0:
		_retreat_timer -= delta
		fighter.move(-dir)
		fighter.facing = dir  # 뒤로 빠지면서도 상대 쪽을 계속 바라본다(스킬이 반대 방향으로 나가지 않도록)
		return

	var preferred_range: float = ranged_distance if _is_ranged else attack_range

	if dist > preferred_range + 20.0:
		fighter.move(dir)
		# 벽이나 낮은 장애물에 막히면 뛰어넘는다 (아파트 단지 놀이터의 모래통 등)
		if fighter.is_on_wall():
			fighter.jump()
	elif _is_ranged and dist < preferred_range - 20.0:
		# 원거리 캐릭터는 상대가 너무 가까이 오면 거리를 벌리되, 계속 상대를 바라보며 견제한다
		fighter.move(-dir)
		fighter.facing = dir
	else:
		fighter.move(0.0)
		if dist <= attack_range:
			fighter.use_basic_attack()

	# 바닥에 있을 때뿐 아니라 공중에 뜬 상태에서도 굴려서, 가끔 이단 점프까지 이어서 쓴다
	# (jump()가 바닥/공중 점프를 스스로 구분하고 다 썼으면 조용히 무시하므로 안전하다)
	if randf() < jump_chance:
		fighter.jump()

	# 쓸 수 있는 스킬이 하나도 없으면 가끔 한 발짝 물러나서 쿨타임을 번다
	if _all_skills_on_cooldown() and randf() < retreat_start_chance:
		_retreat_timer = retreat_duration

func _all_skills_on_cooldown() -> bool:
	for skill in [fighter.skill_1, fighter.skill_2, fighter.skill_ultimate]:
		if skill and skill.can_use():
			return false
	return true

func _decide_skills() -> void:
	if randf() < skill_use_chance:
		fighter.use_skill_1()
	if randf() < skill_use_chance:
		fighter.use_skill_2()
	if randf() < skill_use_chance * 0.3:
		fighter.use_ultimate()
