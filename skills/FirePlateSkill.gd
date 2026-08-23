class_name FirePlateSkill
extends Skill

## 불판 깔기 — 발밑에 화상 장판을 깐다. 기획 문서에서 오픈 이슈였던 동시 개수 상한을 3개로 확정,
## 초과하면 가장 오래된 장판부터 사라진다 (예수천국 불신지옥 악마 스킬2)
@export var plate_scene: PackedScene
@export var max_plates: int = 3

func _execute(fighter: Fighter) -> void:
	if plate_scene == null:
		return
	var plates: Array = fighter.custom_data.get("fire_plates", [])
	plates = plates.filter(func(p): return is_instance_valid(p))
	if plates.size() >= max_plates:
		var oldest = plates.pop_front()
		oldest.queue_free()

	var plate: FirePlate = plate_scene.instantiate()
	fighter.get_parent().add_child(plate)
	plate.global_position = fighter.global_position + Vector2(fighter.facing * 20.0, 30.0)
	plate.source_fighter = fighter
	plates.append(plate)
	fighter.custom_data["fire_plates"] = plates
