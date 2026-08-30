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
@export var target: Fighter

## false면 아무 판단도 안 한다(대전 시작 카운트다운 등) — 그래도 중력·바닥 착지는 계속 처리한다
var is_active: bool = true

var _is_ranged: bool = false
var _retreat_timer: float = 0.0

@onready var fighter: Fighter = get_parent()

func _ready() -> void:
	if target == null:
		target = fighter.find_opponent()
	# skill_2가 투사체를 쏘는 스킬(BBGunSkill처럼 projectile_scene을 가진 스킬)이면
	# 원거리 캐릭터로 보고 거리를 두고 싸우게 한다. 캐릭터별로 따로 분기하지 않고 스킬 구성만으로 판단
	_is_ranged = fighter.skill_2 != null and fighter.skill_2.get("projectile_scene") != null

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
		_decide_movement(delta)
	_decide_skills()

	fighter.apply_physics(delta)

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

	if fighter.is_on_floor() and randf() < jump_chance:
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
