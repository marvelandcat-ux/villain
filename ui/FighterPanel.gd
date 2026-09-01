class_name FighterPanel
extends HBoxContainer

## 캐릭터 박스 + HP 바 + 궁극기 게이지 + 스킬1/스킬2 쿨타임 2칸을 보여주는 패널.
## HP > 궁극기 게이지 > 스킬 순으로 폭이 좁아지는 계단식 배치. bind()로 Fighter를 지정하면 이후 자동으로 갱신된다
@onready var character_box: ColorRect = $CharacterBox
@onready var character_image: TextureRect = $CharacterBox/CharacterImage
@onready var name_label: Label = $CharacterBox/NameLabel
@onready var hp_row: HBoxContainer = $BarsVBox/HPRow
@onready var hp_bar: ProgressBar = $BarsVBox/HPRow/HPBar
@onready var ultimate_row: HBoxContainer = $BarsVBox/UltimateRow
@onready var ultimate_bar: ProgressBar = $BarsVBox/UltimateRow/UltimateBar
@onready var skill_row: HBoxContainer = $BarsVBox/SkillRow
@onready var skill_bars: Array[ProgressBar] = [$BarsVBox/SkillRow/Skill1Bar, $BarsVBox/SkillRow/Skill2Bar]

var fighter: Fighter

## label_prefix가 있으면 캐릭터 이름 앞에 붙인다 (예: "P1", "P2 (AI)").
## mirrored가 true면 캐릭터 박스를 오른쪽으로 옮기고 막대들도 오른쪽에 붙여서 계단이 반대로 꺾이게 한다 (P2용 좌우 반전)
func bind(target_fighter: Fighter, label_prefix: String = "", mirrored: bool = false) -> void:
	fighter = target_fighter
	name_label.text = (label_prefix + " " + fighter.stats.character_name) if label_prefix != "" else fighter.stats.character_name
	character_box.color = GameState.CHARACTER_COLORS.get(fighter.stats.character_name, GameState.DEFAULT_COLOR)
	_apply_portrait(fighter.stats.character_name)
	hp_bar.max_value = fighter.stats.max_hp
	hp_bar.value = fighter.current_hp
	fighter.health_changed.connect(_on_health_changed)
	if mirrored:
		move_child(character_box, get_child_count() - 1)
		for row in [hp_row, ultimate_row, skill_row]:
			row.alignment = BoxContainer.ALIGNMENT_END

## 초상화 그림이 있는 캐릭터면 CharacterBox를 그림으로 채우고, 이름표는 그림 위에서도 읽히도록
## 하단으로 옮기고 테두리를 준다. 없으면 기존처럼 이름표가 박스 전체에 가운데 정렬된다
func _apply_portrait(character_name: String) -> void:
	var portrait_path: String = GameState.PORTRAITS.get(character_name, "")
	if portrait_path == "":
		character_image.texture = null
		return
	character_image.texture = load(portrait_path)
	name_label.anchor_top = 1.0
	name_label.offset_top = -16
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_constant_override("outline_size", 4)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))

func _on_health_changed(current: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current

func _process(_delta: float) -> void:
	if fighter == null:
		return
	_update_cooldown_bar(skill_bars[0], fighter.skill_1)
	_update_cooldown_bar(skill_bars[1], fighter.skill_2)
	_update_cooldown_bar(ultimate_bar, fighter.skill_ultimate)

func _update_cooldown_bar(bar: ProgressBar, skill: Skill) -> void:
	if skill == null:
		bar.visible = false
		return
	bar.visible = true
	bar.max_value = skill.cooldown
	bar.value = skill.cooldown - skill.cooldown_left
