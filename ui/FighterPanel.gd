class_name FighterPanel
extends HBoxContainer

## 캐릭터 박스 + HP 바 + 스킬1/스킬2/궁극기 쿨타임 슬롯 3칸을 보여주는 패널.
## 쿨타임은 막대 대신 스킬 로고에 물이 차오르는 방식으로 보여준다 (SkillCooldownIcon).
## bind()로 Fighter를 지정하면 이후 슬롯들이 알아서 갱신된다
@onready var character_box: ColorRect = $CharacterBox
@onready var character_image: TextureRect = $CharacterBox/CharacterImage
@onready var name_label: Label = $CharacterBox/NameLabel
@onready var hp_row: HBoxContainer = $BarsVBox/HPRow
@onready var hp_bar: ProgressBar = $BarsVBox/HPRow/HPBar
@onready var skill_row: HBoxContainer = $BarsVBox/SkillRow
@onready var skill_slots: Array[SkillCooldownIcon] = [
	$BarsVBox/SkillRow/Skill1Slot,
	$BarsVBox/SkillRow/Skill2Slot,
	$BarsVBox/SkillRow/UltimateSlot,
]

var fighter: Fighter

## label_prefix가 있으면 캐릭터 이름 앞에 붙인다 (예: "P1", "P2 (AI)").
## mirrored가 true면 캐릭터 박스를 오른쪽으로 옮기고 막대들도 오른쪽에 붙여서 계단이 반대로 꺾이게 한다 (P2용 좌우 반전).
## player_index는 쿨타임 슬롯에 띄울 조작 키를 찾는 데 쓴다 (1이면 p1_skill_1 …)
func bind(target_fighter: Fighter, label_prefix: String = "", mirrored: bool = false, player_index: int = 1) -> void:
	fighter = target_fighter
	name_label.text = (label_prefix + " " + fighter.stats.character_name) if label_prefix != "" else fighter.stats.character_name
	character_box.color = GameState.CHARACTER_COLORS.get(fighter.stats.character_name, GameState.DEFAULT_COLOR)
	_apply_portrait(fighter.stats.character_name)
	hp_bar.max_value = fighter.stats.max_hp
	hp_bar.value = fighter.current_hp
	fighter.health_changed.connect(_on_health_changed)
	_bind_skill_slots(player_index)
	if mirrored:
		move_child(character_box, get_child_count() - 1)
		for row in [hp_row, skill_row]:
			row.alignment = BoxContainer.ALIGNMENT_END

## 스킬1/스킬2/궁극기 슬롯에 각각의 Skill과 조작 키를 물려준다.
## 스토리 모드의 P2는 AI가 조작하므로 키 표시를 지운다 (사람이 누르는 키가 아니라서 헷갈린다)
func _bind_skill_slots(player_index: int) -> void:
	var fallback_color: Color = GameState.CHARACTER_COLORS.get(fighter.stats.character_name, GameState.DEFAULT_COLOR)
	var show_keys: bool = not (player_index == 2 and GameState.game_mode == "story")
	var skills: Array[Skill] = [fighter.skill_1, fighter.skill_2, fighter.skill_ultimate]
	var actions: Array[String] = [
		"p%d_skill_1" % player_index,
		"p%d_skill_2" % player_index,
		"p%d_ultimate" % player_index,
	]
	for i in skill_slots.size():
		var hint: String = SkillCooldownIcon.key_hint(actions[i]) if show_keys else ""
		skill_slots[i].bind(skills[i], hint, fallback_color)

## 초상화 그림이 있는 캐릭터면 CharacterBox를 그림으로 채우고, 이름표는 그림 위에서도 읽히도록
## 하단으로 옮기고 테두리를 준다. 없으면 기존처럼 이름표가 박스 전체에 가운데 정렬된다
func _apply_portrait(character_name: String) -> void:
	var portrait_path: String = GameState.PORTRAITS.get(character_name, "")
	if portrait_path == "":
		character_image.texture = null
		return
	character_image.texture = load(portrait_path)
	name_label.anchor_top = 1.0
	# "고양이 아주머니"처럼 긴 이름은 두 줄로 접히므로 이름표 높이를 두 줄치로 잡는다 —
	# 16px로 두면 두 번째 줄이 초상화 칸 밖으로 흘러내린다 (실제로 그렇게 보였음)
	name_label.offset_top = -28
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_constant_override("outline_size", 4)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))

func _on_health_changed(current: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current
