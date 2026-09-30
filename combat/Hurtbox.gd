class_name Hurtbox
extends Area2D

## 피격 판정 — 맞은 데미지를 부모에게 전달한다.
##
## 보통은 부모가 `Fighter`지만, **`take_damage()`/`take_map_damage()`만 있으면 Fighter가 아니어도 된다**
## (일진 궁극기로 불려 나온 패거리처럼 HP만 있는 몸). 그래서 타입을 `Node`로 둔다 —
## `Fighter`로 못박으면 그런 몸을 붙이는 순간 타입 에러가 난다
@onready var fighter: Node = get_parent()

## 이 Fighter의 공격은 안 맞는다. 비워두면 부모 자신의 공격만 무시한다.
## 일진이 자기 패거리를 실수로 때려 죽이지 않게 `IljinCrewMember`가 채워 넣는다
var immune_source: Node = null

## Hitbox가 겹쳤을 때 호출한다. source_fighter가 자기 자신(또는 immune_source)이면 무시하고 false를 반환한다.
## pop_override는 위로 띄우는 힘(음수면 기본 팝업, 0이면 지상 유지) — 콤보 앞 타격이 상대를 안 띄우게 할 때 쓴다.
##
## **주인이 누구냐로 두 갈래가 갈린다:** source_fighter가 있으면 캐릭터의 공격이라 방어로 막히고,
## null이면 맵 기믹(지나가는 열차 등)이라 `take_map_damage()`로 보내 방어를 뚫는다.
## 주인이 있었는데 해제된 경우는 Hitbox가 먼저 걸러내므로 여기까지 null로 오지 않는다
func take_hit(damage: int, knockback: Vector2, source_fighter: Fighter, pop_override: float = -1.0) -> bool:
	if source_fighter == fighter:
		return false
	if immune_source != null and source_fighter == immune_source:
		return false
	if source_fighter == null:
		fighter.take_map_damage(damage, knockback, pop_override)
	else:
		# 카운터 자세(CounterSkill)에 걸렸으면 맞지 않은 것으로 친다 — 데미지 숫자·스파크가 안 뜨고 때린 쪽은 헛친 게 된다
		if fighter.has_method("try_counter") and fighter.try_counter():
			return false
		fighter.take_damage(damage, knockback, pop_override)
	return true
