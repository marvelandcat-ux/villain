class_name TunaThrowSkill
extends Skill

## 참치캔 투척 — 캔을 던진 자리에서 잠시 후 고양이가 튀어나와 상대에게 빠르게 돌진해 한 번 할퀴고 사라진다 (캣맘 스킬1)
@export var throw_distance: float = 150.0
@export var delay: float = 0.8
@export var damage: int = 10
@export var dash_speed: float = 700.0
@export var cat_scene: PackedScene

func _execute(fighter: Fighter) -> void:
	var can_pos: Vector2 = fighter.global_position + Vector2(fighter.facing * throw_distance, 0)
	_spawn_can_marker(fighter, can_pos)
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(fighter):
		return
	_spawn_rush_cat(fighter, can_pos)

## 참치캔이 놓이는 자리를 잠깐 보여주는 표시 (전용 아트 없이 도형만)
func _spawn_can_marker(fighter: Fighter, pos: Vector2) -> void:
	var mark := Polygon2D.new()
	mark.color = Color(0.6, 0.75, 0.9)
	mark.polygon = PackedVector2Array([Vector2(-6, -6), Vector2(6, -6), Vector2(6, 6), Vector2(-6, 6)])
	fighter.get_parent().add_child(mark)
	mark.global_position = pos
	var timer := Timer.new()
	timer.wait_time = delay
	timer.one_shot = true
	timer.timeout.connect(mark.queue_free)
	mark.add_child(timer)
	timer.start()

func _spawn_rush_cat(fighter: Fighter, from_pos: Vector2) -> void:
	if cat_scene == null:
		return
	var cat: CatPet = cat_scene.instantiate()
	fighter.get_parent().add_child(cat)
	cat.global_position = from_pos
	cat.owner_fighter = fighter
	cat.lifetime = 2.0
	cat.move_speed = dash_speed
	cat.damage = damage
	cat.attack_range = 40.0
