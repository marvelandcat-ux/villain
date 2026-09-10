class_name JumpDebuffUltimate
extends Skill

## 소리지르기 — 상대의 점프력을 일정 시간 낮춘다 (주정뱅이 궁극기)
@export var jump_multiplier: float = 0.6
@export var duration: float = 8.0

func _execute(fighter: Fighter) -> void:
	# 소리지르는 순간 스스로 부르르 떤다
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual:
		if visual.has_method("play_squash"):
			visual.play_squash(Vector2(1.15, 0.9))   # Visual.scale 직접 트윈 금지 — 좌우 반전이 깨진다

	var opponent := fighter.find_opponent()
	if opponent:
		opponent.apply_temp_multiplier("jump_multiplier", jump_multiplier, duration)
		# 다리 풀린 느낌으로 보라색으로 물듦
		opponent.set_tint("jump_debuff", Color(0.75, 0.6, 0.85), duration)
