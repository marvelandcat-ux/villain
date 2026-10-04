extends Skill

## 고양이 아주머니 궁극기(검은 고양이 똥 유탄 / 흰 고양이 할퀴기) 동안 기본공격 자리에 끼우는 대체 평타 —
## 실제 동작은 `CatUltimate`가 넘겨준 `on_fire`가 한다.
## 쿨타임 = 발사 간격. `range`는 AI가 "이 거리면 기본공격"을 판단할 때 읽는다

## AI가 기본공격 사거리로 읽는 값(px)
@export var range: float = 300.0

var on_fire: Callable = Callable()

func _execute(fighter: Fighter) -> void:
	if on_fire.is_valid():
		on_fire.call(fighter)

## 휘두르는 모션을 덧대지 않는다 — 고양이를 겨누고 쏘는 동작은 궁극기가 직접 낸다
func handles_own_visual() -> bool:
	return true
