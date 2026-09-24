class_name SkillRange
extends RefCounted

## 스킬 사거리 3단계 공용 기준 (2026-09-19 사용자 결정).
## 스킬마다 제각각이던 사거리를 "근접 / 중거리 / 원거리" 세 칸으로 맞춘다.
## **거리는 시전자 몸 중심에서 판정이 닿는 가장 먼 지점까지의 px**다 (상대 몸 두께는 안 친다).
##
## 세 값은 게임에 이미 있는 스킬에서 그대로 따왔다 — 새로 지어낸 숫자가 아니라,
## "지금 이 스킬만큼"이라고 말할 수 있는 기준점이다:
##   근접  = 기본공격      (ComboMeleeAttack.range 40 + 히트박스 절반 15)
##   중거리 = 주정뱅이 궁극기 (ScreamCone.cone_range 320)
##   원거리 = 주정뱅이 토하기 최대 (VomitSkill (40 + 310 x 3스택) x 길이배수 0.6)
##
## **2026-09-20 너프로 원거리 기준이 970 -> 582로 줄었다.** 기준 스킬이 바뀌면 이 값도 같이 바뀐다 —
## 기준을 "주정뱅이 토하기 최대"로 정했기 때문이다. 970을 그대로 쓰고 싶으면 여기만 되돌리면 된다

## 근접 — 붙어야 닿는다
const MELEE: float = 55.0
## 중거리 — 한 발 떨어져서 닿는다
const MID: float = 320.0
## 원거리 — 화면 절반쯤까지 닿는다 (1280px 화면의 약 45%)
const LONG: float = 582.0

## 세 기준 중 어디에 드는지 이름으로 돌려준다. 기준값 사이는 가까운 쪽 이름을 쓴다 —
## 예를 들어 200px짜리 스킬은 중거리(320)보다 근접(55)에서 더 머니까 "중거리"다
static func label_for(distance: float) -> String:
	if distance <= (MELEE + MID) * 0.5:
		return "근접"
	if distance <= (MID + LONG) * 0.5:
		return "중거리"
	return "원거리"

## 이름으로 기준 거리를 돌려준다 (스킬을 이 기준에 맞춰 세팅할 때 쓴다)
static func distance_for(label: String) -> float:
	match label:
		"근접":
			return MELEE
		"중거리":
			return MID
		_:
			return LONG
