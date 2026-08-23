class_name AIController
extends Node

## 목표(대개 플레이어)와의 거리를 보고 접근/기본공격/스킬 사용을 스스로 결정하는 단순 AI.
## target을 직접 지정하지 않으면 씬에서 자기 자신이 아닌 첫 Fighter를 자동으로 목표로 삼는다 (1대1 전제)
@export var attack_range: float = 55.0
@export var skill_use_chance: float = 0.02  ## 매 물리 프레임마다 스킬 사용을 시도할 확률
@export var target: Fighter

@onready var fighter: Fighter = get_parent()

func _ready() -> void:
	if target == null:
		target = fighter.find_opponent()

func _physics_process(delta: float) -> void:
	if target == null:
		target = fighter.find_opponent()
	if target == null or not is_instance_valid(target):
		fighter.apply_physics(delta)
		return

	if fighter.movement_override == null:
		var dx: float = target.global_position.x - fighter.global_position.x
		if absf(dx) > attack_range:
			fighter.move(signf(dx))
		else:
			fighter.move(0.0)
			fighter.use_basic_attack()

	if randf() < skill_use_chance:
		fighter.use_skill_1()
	if randf() < skill_use_chance:
		fighter.use_skill_2()
	if randf() < skill_use_chance * 0.3:
		fighter.use_ultimate()

	fighter.apply_physics(delta)
