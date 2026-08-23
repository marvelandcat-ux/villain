class_name PlayerController
extends Node

## 방향키 이동/점프, Z 기본공격, 숫자키 1/2/3 스킬을 읽어서 부모 Fighter를 조작한다.
## 이동/기본공격 키는 조작 체계(오픈 이슈)가 확정되기 전까지의 임시 배정
@onready var fighter: Fighter = get_parent()

func _physics_process(delta: float) -> void:
	if fighter.movement_override == null:
		var direction := Input.get_axis("ui_left", "ui_right")
		fighter.move(direction)
		if Input.is_action_just_pressed("ui_up"):
			fighter.jump()

	if Input.is_action_just_pressed("basic_attack"):
		fighter.use_basic_attack()
	if Input.is_action_just_pressed("skill_1"):
		fighter.use_skill_1()
	if Input.is_action_just_pressed("skill_2"):
		fighter.use_skill_2()
	if Input.is_action_just_pressed("skill_3"):
		fighter.use_ultimate()

	fighter.apply_physics(delta)
