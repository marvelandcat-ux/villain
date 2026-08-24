class_name StanceSwitcher
extends Skill

## 궁극기가 없는 예수천국 불신지옥 전용 — SkillUltimate 자리에 대신 들어가서
## 3번 키를 누르면 천사/악마 스탠스를 전환한다 (스킬1/스킬2가 가리키는 실제 스킬이 바뀐다)
@onready var _angel_skill_1: Skill = get_parent().get_node("AngelSkill1")
@onready var _angel_skill_2: Skill = get_parent().get_node("AngelSkill2")
@onready var _demon_skill_1: Skill = get_parent().get_node("DemonSkill1")
@onready var _demon_skill_2: Skill = get_parent().get_node("DemonSkill2")

var is_angel: bool = true

## 천사/악마 스탠스를 눈으로 구분할 수 있도록 캐릭터 그림에 씌우는 색조
@export var angel_tint: Color = Color(1, 1, 1)
@export var demon_tint: Color = Color(1, 0.55, 0.55)

func _ready() -> void:
	var fighter := get_parent() as Fighter
	fighter.skill_1 = _angel_skill_1
	fighter.skill_2 = _angel_skill_2
	fighter.set_tint("stance", angel_tint)

func _execute(fighter: Fighter) -> void:
	is_angel = not is_angel
	fighter.skill_1 = _angel_skill_1 if is_angel else _demon_skill_1
	fighter.skill_2 = _angel_skill_2 if is_angel else _demon_skill_2
	fighter.set_tint("stance", angel_tint if is_angel else demon_tint)
