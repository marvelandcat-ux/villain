class_name StanceSwitcher
extends Skill

## 궁극기가 없는 예수천국 불신지옥 전용 — SkillUltimate 자리에 대신 들어가서
## 3번 키를 누르면 천사/악마 스탠스를 전환한다 (스킬1/스킬2가 가리키는 실제 스킬이 바뀐다)
@onready var _angel_skill_1: Skill = get_parent().get_node("AngelSkill1")
@onready var _angel_skill_2: Skill = get_parent().get_node("AngelSkill2")
@onready var _demon_skill_1: Skill = get_parent().get_node("DemonSkill1")
@onready var _demon_skill_2: Skill = get_parent().get_node("DemonSkill2")

var is_angel: bool = true

func _ready() -> void:
	var fighter := get_parent() as Fighter
	fighter.skill_1 = _angel_skill_1
	fighter.skill_2 = _angel_skill_2

func _execute(fighter: Fighter) -> void:
	is_angel = not is_angel
	fighter.skill_1 = _angel_skill_1 if is_angel else _demon_skill_1
	fighter.skill_2 = _angel_skill_2 if is_angel else _demon_skill_2
