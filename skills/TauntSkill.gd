class_name TauntSkill
extends Skill

## 도발 — 전방 범위 안의 상대를 조롱해서 이동속도를 잠깐 늦춘다.
## 기획 문서에 효과가 미정이었던 오픈 이슈를 임의로 확정한 것 (악플러 스킬1)
@export var range: float = 250.0
@export var slow_multiplier: float = 0.7
@export var duration: float = 3.0

func _execute(fighter: Fighter) -> void:
	# 도발 동작 자체는 항상 보이도록 캐릭터 위에서 잠깐 반짝인다
	_spawn_taunt_mark(fighter)
	var opponent := fighter.find_opponent()
	if opponent == null:
		return
	var dx: float = opponent.global_position.x - fighter.global_position.x
	if absf(dx) <= range and signf(dx) == fighter.facing:
		opponent.apply_temp_multiplier("move_speed_multiplier", slow_multiplier, duration)
		# 도발당해서 느려진 상대는 노랗게 물든다
		opponent.set_tint("taunted", Color(1.0, 0.95, 0.4), duration)

func _spawn_taunt_mark(fighter: Fighter) -> void:
	var scene_root: Node = fighter.get_tree().current_scene
	if scene_root == null:
		return
	var mark: Node2D = load("res://combat/HitSpark.tscn").instantiate()
	scene_root.add_child(mark)
	mark.global_position = fighter.global_position + Vector2(0, -50)
	mark.scale = Vector2(0.7, 0.7)
