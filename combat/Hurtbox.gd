class_name Hurtbox
extends Area2D

## 피격 판정 — Fighter의 자식으로 붙어서, 맞은 데미지를 Fighter에게 전달한다
@onready var fighter: Fighter = get_parent()

## Hitbox가 겹쳤을 때 호출한다. source_fighter가 자기 자신이면 무시(자해 방지)하고 false를 반환한다.
## pop_override는 위로 띄우는 힘(음수면 기본 팝업, 0이면 지상 유지) — 콤보 앞 타격이 상대를 안 띄우게 할 때 쓴다.
##
## **주인이 누구냐로 두 갈래가 갈린다:** source_fighter가 있으면 캐릭터의 공격이라 방어로 막히고,
## null이면 맵 기믹(지나가는 열차 등)이라 `take_map_damage()`로 보내 방어를 뚫는다.
## 주인이 있었는데 해제된 경우는 Hitbox가 먼저 걸러내므로 여기까지 null로 오지 않는다
func take_hit(damage: int, knockback: Vector2, source_fighter: Fighter, pop_override: float = -1.0) -> bool:
	if source_fighter == fighter:
		return false
	if source_fighter == null:
		fighter.take_map_damage(damage, knockback, pop_override)
	else:
		fighter.take_damage(damage, knockback, pop_override)
	return true
