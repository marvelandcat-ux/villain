class_name HealSkill
extends Skill

## 자신의 HP를 회복하는 스킬 (촉법소년 궁극기 "엄마가 부르면 집 가서 밥 먹고 옴")
## 회복량/쿨타임은 밸런스 미확정 임시값 (오픈 이슈)
@export var heal_amount: int = 30
## 밥 먹으러 집에 다녀오는 연출 — 그 사이엔 무적 (오픈 이슈였던 "궁극기 중 무적 여부"를 무적으로 확정)
@export var invincible_duration: float = 1.0
## 회복하는 순간 몸이 부풀어 오르는 배율. (1,1)이면 크기 연출 없이 초록빛만 난다
@export var heal_pop: Vector2 = Vector2(1.25, 1.25)

func _execute(fighter: Fighter) -> void:
	fighter.heal(heal_amount)
	fighter.grant_invincibility(invincible_duration)
	# 무적인 동안 초록빛으로 빛나서 "지금은 못 맞는다"는 걸 눈으로 알 수 있게 함
	fighter.set_tint("heal_glow", Color(0.6, 1.0, 0.6), invincible_duration)
	# 몸이 부풀었다 돌아오는 연출. **Visual.scale을 직접 트윈하면 안 된다** —
	# 좌우 반전이 scale.x 부호로 되어 있어서 왼쪽을 보던 캐릭터가 오른쪽으로 뒤집힌다
	# ("궁 쓰면 자꾸 오른쪽 돌아본다"). 리그의 play_squash는 부호를 지켜준다
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("play_squash") and not heal_pop.is_equal_approx(Vector2.ONE):
		visual.play_squash(heal_pop)
