class_name CatSelectSkill
extends Skill

## 고양이 고르기 — 고양이 아주머니 스킬2(H). 누를 때마다 검은 → 주황 → 흰 → 검은… 순서로 바뀌고,
## 머리 위에 고른 고양이 얼굴이 `show_time`초 뜬다. 라운드 시작은 검은 고양이.
## 고른 값은 `fighter.custom_data["cat_kind"]`에 둔다 — 스킬1(`CatHouseSkill`)이 집을 다 지을 때 읽는다

const ICON_SCRIPT := preload("res://skills/CatFaceIcon.gd")
const KIND_COUNT := 3

## 머리 위 표시가 떠 있는 시간(초)
@export var show_time: float = 1.5
## 표시 자리(캐릭터 원점 기준) — 머리 꼭대기 위
@export var icon_offset: Vector2 = Vector2(0.0, -88.0)

var _icon = null

## 궁극기 주황 고양이 옷을 입은 동안은 못 쓴다(CatUltimate)
func can_use() -> bool:
	var fighter := get_parent() as Fighter
	return super() and not (fighter != null and fighter.custom_data.get("cat_suit", false))

func _execute(fighter: Fighter) -> void:
	var kind: int = (int(fighter.custom_data.get("cat_kind", 0)) + 1) % KIND_COUNT
	fighter.custom_data["cat_kind"] = kind
	if _icon == null or not is_instance_valid(_icon):
		_icon = ICON_SCRIPT.new()
		_icon.name = "CatFaceIcon"
		_icon.z_index = 70
		fighter.add_child(_icon)
	_icon.position = icon_offset
	_icon.show_kind(kind, show_time)

## 고르기는 순식간이라 클래시(연타 대결) 대기창을 타지 않는다 — 타면 누르고 한참 뒤에 바뀐다
func clashable() -> bool:
	return false
