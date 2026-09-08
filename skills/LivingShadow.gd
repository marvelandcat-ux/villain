class_name LivingShadow
extends CharacterBody2D

## LivingShadowSkill(살아있는 그림자)이 던지는 그림자의 몸통.
## 허공에 뜬 채로 멈춰 있지 않고 실제 캐릭터처럼 중력을 받아 바닥에 떨어져 선다.
## 캐릭터가 이 몸을 발판처럼 밟고 서지 못하게, 스폰될 때 모든 Fighter와 충돌 예외를 걸어둔다
## (Fighter._ignore_other_fighters()와 같은 방식 — 공격 판정은 이 몸과 무관한 별도 Area2D
## 히트박스라 그대로 서로를 감지한다)

## 던져진 직후 이 시간(초) 동안은 중력 없이 그 자리에 떠 있다가 그 뒤부터 떨어진다.
## 공중에서 던졌을 때 바로 뚝 떨어지지 않고 살짝 체공하다 떨어지게 하려는 연출용 값
@export var hang_time: float = 0.2

var _hang_left: float = 0.0

func _ready() -> void:
	_hang_left = hang_time
	for f in get_tree().get_nodes_in_group("fighters"):
		if f is PhysicsBody2D:
			add_collision_exception_with(f)
			f.add_collision_exception_with(self)

func _physics_process(delta: float) -> void:
	if _hang_left > 0.0:
		_hang_left -= delta
		velocity.y = 0.0
	elif not is_on_floor():
		velocity.y += Fighter.gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
