class_name Hurtbox
extends Area2D

## 피격 판정 — Fighter의 자식으로 붙어서, 맞은 데미지를 fighter.take_damage()로 전달한다
@onready var fighter: Fighter = get_parent()

## Hitbox가 겹쳤을 때 호출한다. source_fighter가 자기 자신이면 무시(자해 방지)하고 false를 반환한다.
## pop_override는 위로 띄우는 힘(음수면 기본 팝업, 0이면 지상 유지) — 콤보 앞 타격이 상대를 안 띄우게 할 때 쓴다
func take_hit(damage: int, knockback: Vector2, source_fighter: Fighter, pop_override: float = -1.0) -> bool:
	if source_fighter == fighter:
		return false
	fighter.take_damage(damage, knockback, pop_override)
	return true
