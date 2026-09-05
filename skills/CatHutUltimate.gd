class_name CatHutUltimate
extends Skill

## 고양이 오두막 설치 — 시간차로 고양이를 계속 소환하는 구조물을 놓는다 (고양이 아주머니 궁극기)
@export var hut_scene: PackedScene

func _execute(fighter: Fighter) -> void:
	if hut_scene == null:
		return
	var hut: CatHut = hut_scene.instantiate()
	fighter.get_parent().add_child(hut)
	hut.global_position = fighter.global_position + Vector2(fighter.facing * 60.0, 20.0)
	hut.owner_fighter = fighter
