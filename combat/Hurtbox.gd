class_name Hurtbox
extends Area2D

## 피격 판정 — Fighter의 자식으로 붙어서, 맞은 데미지를 fighter.take_damage()로 전달한다
@onready var fighter: Fighter = get_parent()

## Hitbox가 겹쳤을 때 호출한다. source_fighter가 자기 자신이면 무시(자해 방지)
func take_hit(damage: int, knockback: Vector2, source_fighter: Fighter) -> void:
	if source_fighter == fighter:
		return
	fighter.take_damage(damage, knockback)
