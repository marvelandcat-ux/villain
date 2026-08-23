class_name FighterPanel
extends VBoxContainer

## HP 바 + 스킬 쿨타임 3칸(스킬1/스킬2/궁극기)을 보여주는 패널.
## bind()로 Fighter를 지정하면 이후 자동으로 갱신된다
@onready var hp_bar: ProgressBar = $HPBar
@onready var name_label: Label = $NameLabel
@onready var skill_bars: Array[ProgressBar] = [$SkillRow/Skill1Bar, $SkillRow/Skill2Bar, $SkillRow/UltimateBar]

var fighter: Fighter

func bind(target_fighter: Fighter) -> void:
	fighter = target_fighter
	name_label.text = fighter.stats.character_name
	hp_bar.max_value = fighter.stats.max_hp
	hp_bar.value = fighter.current_hp
	fighter.health_changed.connect(_on_health_changed)

func _on_health_changed(current: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current

func _process(_delta: float) -> void:
	if fighter == null:
		return
	_update_skill_bar(skill_bars[0], fighter.skill_1)
	_update_skill_bar(skill_bars[1], fighter.skill_2)
	_update_skill_bar(skill_bars[2], fighter.skill_ultimate)

func _update_skill_bar(bar: ProgressBar, skill: Skill) -> void:
	if skill == null:
		bar.visible = false
		return
	bar.visible = true
	bar.max_value = skill.cooldown
	bar.value = skill.cooldown - skill.cooldown_left
