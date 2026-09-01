class_name MeleeAttack
extends Skill

## 기본공격 공용 스킬 — 캐릭터 앞에 잠깐 히트박스를 켰다 끈다.
## damage/range만 캐릭터마다 다르게 지정해서 재사용한다 (사탕찌르기, 키보드 휘두르기, 술병깨기, 팻말 때리기 전부 이걸 씀)
@export var damage: int = 8
@export var range: float = 40.0
@export var active_duration: float = 0.15
## 예비동작 시간 — 공격 모션에서 실제로 때리는 순간까지 기다렸다가 히트박스를 켠다(0이면 바로 켬)
@export var windup: float = 0.0
## 넉백 세기 — x는 밀려나는 방향(공격자 기준으로 자동 반전), y는 살짝 띄우는 높이 (바운스어택류 콤보용)
@export var knockback: Vector2 = Vector2(220, -90)

@onready var hitbox: Hitbox = $Hitbox

func _execute(fighter: Fighter) -> void:
	if windup > 0.0:
		await get_tree().create_timer(windup).timeout
		if not is_instance_valid(fighter):
			return
	hitbox.damage = fighter.compute_damage(damage)
	hitbox.knockback = Vector2(knockback.x * fighter.facing, knockback.y)
	hitbox.source_fighter = fighter
	# Hitbox의 부모(BasicAttack)가 Node2D가 아닌 Node라서 position(부모 상대 좌표)이 아니라
	# global_position(절대 좌표)으로 직접 배치해야 한다
	hitbox.global_position = fighter.global_position + Vector2(range * fighter.facing, 0)
	hitbox.monitoring = true
	hitbox.monitorable = true
	await get_tree().create_timer(active_duration).timeout
	hitbox.monitoring = false
	hitbox.monitorable = false
