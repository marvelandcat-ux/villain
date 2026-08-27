class_name TunaPlaceSkill
extends Skill

## 참치캔 놓기 — 그 자리에 고양이가 나타나 잠깐 밥을 먹은 뒤, 다 먹으면 맵을 돌아다니며 상대를 할퀸다 (캣맘 스킬2)
@export var eating_duration: float = 1.5
@export var wander_duration: float = 6.0
@export var damage: int = 6
@export var move_speed: float = 150.0
@export var cat_scene: PackedScene

func _execute(fighter: Fighter) -> void:
	if cat_scene == null:
		return
	var cat: CatPet = cat_scene.instantiate()
	fighter.get_parent().add_child(cat)
	cat.global_position = fighter.global_position + Vector2(fighter.facing * 40.0, 0)
	cat.owner_fighter = fighter
	cat.eating_duration = eating_duration
	cat.lifetime = eating_duration + wander_duration
	cat.move_speed = move_speed
	cat.damage = damage
