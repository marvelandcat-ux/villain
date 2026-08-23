class_name MeleeAttack
extends Skill

## 기본공격 공용 스킬 — 캐릭터 앞에 잠깐 히트박스를 켰다 끈다.
## damage/range만 캐릭터마다 다르게 지정해서 재사용한다 (사탕찌르기, 키보드 휘두르기, 술병깨기, 팻말 때리기 전부 이걸 씀)
@export var damage: int = 8
@export var range: float = 40.0
@export var active_duration: float = 0.15

@onready var hitbox: Hitbox = $Hitbox

func _execute(fighter: Fighter) -> void:
	hitbox.damage = fighter.compute_damage(damage)
	hitbox.source_fighter = fighter
	hitbox.position.x = range * fighter.facing
	hitbox.monitoring = true
	hitbox.monitorable = true
	await get_tree().create_timer(active_duration).timeout
	hitbox.monitoring = false
	hitbox.monitorable = false
