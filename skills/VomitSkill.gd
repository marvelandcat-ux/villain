class_name VomitSkill
extends Skill

## 토하기 — 술 스택 수에 비례해 데미지·사거리가 세진다. 사용하면 스택이 전부 사라지고 이동속도도 원래대로 돌아온다.
## 사거리는 투사체 생존시간으로 근사한다 (주정뱅이 스킬2)
@export var projectile_scene: PackedScene
@export var base_damage: int = 6
@export var damage_per_stack: int = 4
@export var base_speed: float = 350.0
@export var speed_per_stack: float = 60.0
@export var base_lifetime: float = 0.5
@export var lifetime_per_stack: float = 0.15

func _execute(fighter: Fighter) -> void:
	var stacks: int = fighter.custom_data.get("drink_stacks", 0)
	var damage: int = base_damage + damage_per_stack * stacks
	var speed: float = base_speed + speed_per_stack * stacks
	var lifetime: float = base_lifetime + lifetime_per_stack * stacks
	fighter.custom_data["drink_stacks"] = 0
	fighter.move_speed_multiplier = 1.0

	if projectile_scene == null:
		return
	var projectile: Projectile = projectile_scene.instantiate()
	fighter.get_parent().add_child(projectile)
	projectile.global_position = fighter.global_position + Vector2(fighter.facing * 30.0, 0.0)
	projectile.lifetime = lifetime
	projectile.setup(fighter.facing, speed, fighter.compute_damage(damage), fighter)
