class_name CatPet
extends CharacterBody2D

## 참치캔에 이끌려 나타나는 고양이 — 주인이 아닌 쪽에게 다가가서 할퀸다.
## 돌진형(고양이 아주머니 스킬1)과 배회형(스킬2/궁극기)이 전부 이 스크립트 하나를 값만 다르게 써서 재사용한다
@export var move_speed: float = 220.0
@export var damage: int = 5
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 1.0
@export var lifetime: float = 6.0
## 0보다 크면 그동안은 안 움직이고 "밥 먹는" 상태로 대기했다가 그 후 정상 행동을 시작한다
@export var eating_duration: float = 0.0

const GRAVITY: float = 900.0

## 이 고양이를 부른 캐릭터 (공격 대상에서 제외)
var owner_fighter: Fighter

var _attack_timer: float = 0.0
var _eating_timer: float = 0.0
var _lifetime_left: float = 0.0
## export 값들은 스킬 스크립트가 instantiate 직후에 채워주므로, _ready()가 아니라
## 첫 물리 프레임에서 한 번만 내부 카운터로 옮겨 담는다 (그래야 나중에 설정된 값을 정확히 반영함)
var _initialized: bool = false

@onready var hitbox: Hitbox = $Hitbox

func _physics_process(delta: float) -> void:
	if not _initialized:
		_initialized = true
		_eating_timer = eating_duration
		_lifetime_left = lifetime

	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		queue_free()
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if _eating_timer > 0.0:
		_eating_timer -= delta
		velocity.x = 0.0
		move_and_slide()
		return

	var target: Fighter = owner_fighter.find_opponent() if owner_fighter and is_instance_valid(owner_fighter) else null
	if target and is_instance_valid(target):
		var dx: float = target.global_position.x - global_position.x
		if absf(dx) > attack_range:
			velocity.x = signf(dx) * move_speed
		else:
			velocity.x = 0.0
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_attack_timer = attack_cooldown
				_claw(signf(dx) if dx != 0.0 else 1.0)
	else:
		velocity.x = 0.0

	move_and_slide()

## dir(1 또는 -1) 방향으로 살짝 내밀어서 할퀸다 — 고양이 몸 위치 그대로 두면
## attack_range가 실제 히트박스/허트박스 판정 범위보다 넓어서 닿지 않는 경우가 있었음
func _claw(dir: float) -> void:
	hitbox.source_fighter = owner_fighter
	hitbox.damage = owner_fighter.compute_damage(damage) if owner_fighter and is_instance_valid(owner_fighter) else damage
	hitbox.global_position = global_position + Vector2(dir * 20.0, 0)
	hitbox.monitoring = true
	hitbox.monitorable = true
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(hitbox):
		hitbox.monitoring = false
		hitbox.monitorable = false
