class_name TurnstileSkill
extends Skill

## 개찰구 생성 — 전방에 낮은 장애물(점프로만 통과) 2개를 간격을 두고 놓는다 (지하철 아저씨 스킬1)
@export var turnstile_scene: PackedScene
@export var count: int = 2
## 개찰구 사이 간격(px). **Turnstile.visual_scale x 817(그림 속 한 쌍 몸통 간격)과 같아야** 날개가 맞물린다
@export var spacing: float = 78.0
@export var start_distance: float = 50.0

func _execute(fighter: Fighter) -> void:
	if turnstile_scene == null:
		return
	var parent: Node = fighter.get_parent()
	for i in range(count):
		var obstacle: Node2D = turnstile_scene.instantiate()
		# 개찰구 한 쌍의 날개가 가운데서 맞물리게 — 첫째는 먼 쪽을, 둘째는 가까운 쪽을 가리킨다.
		# Turnstile._ready()가 이 값으로 그림 반쪽을 고르므로 add_child 전에 넣는다
		if "flap_dir" in obstacle:
			obstacle.flap_dir = fighter.facing if i % 2 == 0 else -fighter.facing
		parent.add_child(obstacle)
		var dist: float = start_distance + spacing * i
		# 캐릭터 발밑 높이에 맞춰 놓는다 (캐릭터 캡슐 절반 높이 30 - 장애물 절반 높이 22.5)
		obstacle.global_position = fighter.global_position + Vector2(fighter.facing * dist, 7.5)
