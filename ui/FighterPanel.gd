class_name FighterPanel
extends HBoxContainer

## 캐릭터 박스 + HP 바 + 스킬1/스킬2/궁극기 쿨타임 슬롯 3칸을 보여주는 패널.
## 쿨타임은 막대 대신 스킬 로고에 물이 차오르는 방식으로 보여준다 (SkillCooldownIcon).
## bind()로 Fighter를 지정하면 이후 슬롯들이 알아서 갱신된다
@onready var _character_box: ColorRect = $CharacterBox
@onready var _character_image: TextureRect = $CharacterBox/CharacterImage
@onready var _hp_row: HBoxContainer = $BarsVBox/HPRow
@onready var _hp_bar_wrap: Control = $BarsVBox/HPRow/HPBarSlot/HPBarWrap
@onready var _hp_bar: ProgressBar = $BarsVBox/HPRow/HPBarSlot/HPBarWrap/HPBar

## HPBarWrap(HPBar+HPFrame) 크기 — HPBarWrap.custom_minimum_size와 같은 값
const HP_BAR_SIZE := Vector2(232.0, 20.0)
@onready var _skill_row: HBoxContainer = $BarsVBox/SkillRow
@onready var _skill_slots: Array[SkillCooldownIcon] = [
	$BarsVBox/SkillRow/Skill1Slot,
	$BarsVBox/SkillRow/Skill2Slot,
	$BarsVBox/SkillRow/UltimateSlot,
]

var fighter: Fighter
var _player_index: int = 1

## mirrored가 true면 캐릭터 박스를 오른쪽으로 옮기고 막대들도 오른쪽에 붙여서 계단이 반대로 꺾이게 한다 (P2용 좌우 반전).
## player_index는 쿨타임 슬롯에 띄울 조작 키를 찾는 데 쓴다 (1이면 p1_skill_1 …)
func bind(target_fighter: Fighter, mirrored: bool = false, player_index: int = 1) -> void:
	fighter = target_fighter
	_apply_portrait(fighter.stats.character_name)
	_hp_bar.max_value = fighter.stats.max_hp
	_hp_bar.value = fighter.current_hp
	fighter.health_changed.connect(_on_health_changed)
	_player_index = player_index
	fighter.skill_slots_changed.connect(_on_skill_slots_changed)
	_bind_skill_slots(player_index)
	if mirrored:
		move_child(_character_box, get_child_count() - 1)
		for row in [_hp_row, _skill_row]:
			row.alignment = BoxContainer.ALIGNMENT_END
	_apply_hp_bar_mirror(mirrored)

## ProgressBar는 항상 왼쪽부터 차서 오른쪽부터 닳는다. mirrored(P2, 화면 오른쪽)는 캐릭터가
## 화면 가운데를 보고 있으니 체력도 화면 가운데 쪽(왼쪽)부터 닳아야 자연스럽다 — 그래서 HPBarWrap을
## 통째로 좌우 반전(scale.x=-1)해서 내부적으론 그대로 왼쪽부터 차지만 화면엔 오른쪽부터 차 보이게 한다.
## 안의 내용(막대 채움 색·테두리)은 전부 좌우 대칭이라 뒤집어도 글자처럼 깨지는 부분이 없다
func _apply_hp_bar_mirror(mirrored: bool) -> void:
	_hp_bar_wrap.pivot_offset = HP_BAR_SIZE / 2.0
	_hp_bar_wrap.scale.x = -1.0 if mirrored else 1.0

## 스킬1/스킬2/궁극기 슬롯에 각각의 Skill과 조작 키를 물려준다.
## 스토리 모드·컴퓨터 대전의 P2는 AI가 조작하므로 키 표시를 지운다 (사람이 누르는 키가 아니라서 헷갈린다)
func _bind_skill_slots(player_index: int) -> void:
	var fallback_color: Color = GameState.CHARACTER_COLORS.get(fighter.stats.character_name, GameState.DEFAULT_COLOR)
	var p2_is_ai: bool = GameState.game_mode == "story" or GameState.vs_ai
	var show_keys: bool = not (player_index == 2 and p2_is_ai)
	var skills: Array[Skill] = [fighter.skill_1, fighter.skill_2, fighter.skill_ultimate]
	var actions: Array[String] = [
		"p%d_skill_1" % player_index,
		"p%d_skill_2" % player_index,
		"p%d_ultimate" % player_index,
	]
	for i in _skill_slots.size():
		var hint: String = SkillCooldownIcon.key_hint(actions[i]) if show_keys else ""
		_skill_slots[i].bind(skills[i], hint, fallback_color)

## 초상화 그림이 있는 캐릭터면 CharacterBox를 그림으로 채운다(없으면 흰 칸 그대로 비워둠).
## **이름표(빨간 테두리 도장)는 2026-09-28에 뺐다** — HUD가 화면 아래로 내려가면서 화면 밖으로 삐져나왔고,
## 어차피 초상화만으로 누가 누군지 알 수 있어서 지웠다
func _apply_portrait(character_name: String) -> void:
	if not GameState.has_portrait(character_name):
		_character_image.texture = null
		return
	_character_image.texture = GameState.portrait_texture(character_name)
	# 편집 씬(PortraitFrames.tscn)에서 잡은 배율·위치를 HUD 초상화 칸(70x70)에도 똑같이 적용
	GameState.frame_portrait(_character_image, character_name, Vector2(70, 70))

func _on_skill_slots_changed() -> void:
	_bind_skill_slots(_player_index)

func _on_health_changed(current: int, max_hp: int) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = current
