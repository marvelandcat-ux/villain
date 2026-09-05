class_name TurnstileSkill
extends Skill

## 개찰구 생성 — 전방에 낮은 장애물(점프로만 통과) 2개를 간격을 두고 놓는다 (지하철 아저씨 스킬1)
@export var turnstile_scene: PackedScene
@export var count: int = 2
@export var spacing: float = 60.0
@export var start_distance: float = 50.0

func _execute(fighter: Fighter) -> void:
	if turnstile_scene == null:
		return
	var parent: Node = fighter.get_parent()
	for i in range(count):
		var obstacle: Node2D = turnstile_scene.instantiate()
		parent.add_child(obstacle)
		var dist: float = start_distance + spacing * i
		# 캐릭터 발밑 높이에 맞춰 놓는다 (캐릭터 캡슐 절반 높이 30 - 장애물 절반 높이 22.5)
		obstacle.global_position = fighter.global_position + Vector2(fighter.facing * dist, 7.5)
