class_name PlayerController
extends Node

## 방향키 이동/점프, Z 기본공격, 숫자키 1/2/3 스킬을 읽어서 부모 Fighter를 조작한다.
## 이동/기본공격 키는 조작 체계(오픈 이슈)가 확정되기 전까지의 임시 배정
@onready var fighter: Fighter = get_parent()

## false면 입력을 무시한다(대전 시작 카운트다운, 승패 판정 후 등) — 그래도 중력·바닥 착지는 계속 처리한다
var is_active: bool = true

func _physics_process(delta: float) -> void:
	if is_active:
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
	else:
		# 멈춘 순간의 관성으로 계속 미끄러지지 않도록 수평 속도를 0으로 고정
		fighter.move(0.0)

	fighter.apply_physics(delta)
