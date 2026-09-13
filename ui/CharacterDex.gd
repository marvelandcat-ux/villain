class_name CharacterDex
extends Control

## 도감 — "캐릭터"/"맵" 탭으로 나뉘어 있다.
## 캐릭터 탭: 격자에서 하나를 고르면 왼쪽에 사선 이름 배너·별점(공격/체력/속도)·설명을, 오른쪽에 초상화를 보여준다.
## 맵 탭: 격자에서 하나를 고르면 왼쪽에 이름 배너·기믹 설명을, 오른쪽에 맵 미니 스케치(MapPreview)를 보여준다.
## 둘 다 대전에 영향을 주지 않는 읽기 전용 화면이라 확인 창 없이 바로 들어오고 나간다.
##
## 캐릭터 별점은 실제 전투 수치(CharacterStats.max_hp 등)가 아니라 표시 전용 필드
## (attack_rating/hp_rating/speed_rating, 1~5)를 그대로 읽는다 — 실제 수치는 아직 로스터 전체가
## 거의 똑같아서(밸런스 미확정) 그걸로 막대를 그리면 캐릭터마다 다 똑같아 보인다

const TILE_SIZE := Vector2(120, 108)
const MAP_TILE_SIZE := Vector2(160, 90)
const PREVIEW_BOX_SIZE := Vector2(340, 300)
const MAX_PIPS := 5
const PIP_SIZE := Vector2(20, 20)
const PIP_COLOR_ATTACK := Color(0.35, 0.45, 0.85)
const PIP_COLOR_HP := Color(0.85, 0.3, 0.3)
const PIP_COLOR_SPEED := Color(0.9, 0.85, 0.25)

## 맵은 캐릭터 스탯 리소스 같은 별도 파일이 없어서, 도감 설명 문구만 여기서 짧게 들고 있는다.
## 아직 안 적은 맵은 기본 문구("기믹 설명 준비 중")로 대신한다
const MAP_DESCRIPTIONS := {
	"학교 옥상 (링아웃)": "벽이 없는 옥상 — 넉백으로 밀려나면 그대로 떨어져 링아웃된다.",
	"지하철 승강장 (열차)": "승강장 바닥이 없어 선로에서 싸운다. 주기적으로 열차가 선로를 가로지르며, 의자 발판(이단 점프로만 도달) 위에 올라서야 피할 수 있다.",
	"놀이터": "미끄럼틀(경사면)·트램폴린식 스프링 시소·위에서 떨어지는 화분·이동속도를 늦추는 모래사장이 있는 기믹 맵.",
	"악플러의 방(쓰레기집)": "바닥에 쌓인 쓰레기 더미가 장애물로 작용해 이동 경로를 막는다.",
	"층간소음 아파트": "위층 발판(원웨이)을 오가며 싸울 수 있는 아파트 내부.",
	"지하철 선로": "제자리에서 경고 후 켜졌다 꺼지는 열차 판정이 있는 선로.",
}
const DEFAULT_DESCRIPTION := "기믹 설명 준비 중"

@onready var title_label: Label = $Center/VBox/TitleLabel
@onready var character_tab_button: Button = $Center/VBox/TabRow/CharacterTabButton
@onready var map_tab_button: Button = $Center/VBox/TabRow/MapTabButton
@onready var grid: GridContainer = $Center/VBox/Grid
@onready var preview_box: ColorRect = $Center/VBox/Content/PreviewBox
@onready var preview_image: TextureRect = $Center/VBox/Content/PreviewBox/PreviewImage
@onready var preview_label: Label = $Center/VBox/Content/PreviewBox/PreviewLabel
@onready var preview_map: MapPreview = $Center/VBox/Content/PreviewBox/PreviewMap
@onready var banner_shape: TextureRect = $Center/VBox/Content/Left/NameBanner/Shape
@onready var banner_text: Label = $Center/VBox/Content/Left/NameBanner/Text
@onready var stats_grid: GridContainer = $Center/VBox/Content/Left/StatsGrid
@onready var attack_pips: HBoxContainer = $Center/VBox/Content/Left/StatsGrid/AttackPips
@onready var hp_pips: HBoxContainer = $Center/VBox/Content/Left/StatsGrid/HpPips
@onready var speed_pips: HBoxContainer = $Center/VBox/Content/Left/StatsGrid/SpeedPips
@onready var description_label: Label = $Center/VBox/Content/Left/DescriptionBox/Margin/DescriptionLabel

## "character" 또는 "map"
var _mode: String = "character"
var _thumb_buttons: Dictionary = {}  # {name: Button} — 지금 탭에 해당하는 칸들만 들어있다

func _ready() -> void:
	_show_character_tab()

func _on_character_tab_pressed() -> void:
	_show_character_tab()

func _on_map_tab_pressed() -> void:
	_show_map_tab()

func _show_character_tab() -> void:
	_mode = "character"
	character_tab_button.disabled = true
	map_tab_button.disabled = false
	title_label.text = "캐릭터 도감"
	stats_grid.visible = true
	preview_map.visible = false

	_clear_grid()
	for character_name in GameState.CHARACTERS.keys():
		var button := _make_character_tile(character_name)
		grid.add_child(button)
		_thumb_buttons[character_name] = button
	var first_name: String = GameState.CHARACTERS.keys()[0]
	_show_character(first_name)
	_thumb_buttons[first_name].grab_focus()

func _show_map_tab() -> void:
	_mode = "map"
	character_tab_button.disabled = false
	map_tab_button.disabled = true
	title_label.text = "맵 도감"
	stats_grid.visible = false
	preview_image.visible = false
	preview_label.visible = false

	_clear_grid()
	for map_name in GameState.MAPS.keys():
		var button := _make_map_tile(map_name)
		grid.add_child(button)
		_thumb_buttons[map_name] = button
	var first_name: String = GameState.MAPS.keys()[0]
	_show_map(first_name)
	_thumb_buttons[first_name].grab_focus()

func _clear_grid() -> void:
	for child in grid.get_children():
		child.free()
	_thumb_buttons.clear()

## 격자 칸 공용 테두리 스타일 — 캐릭터/맵 둘 다 같은 느낌으로 쓴다
func _apply_tile_style(button: Button, base_color: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var is_highlighted: bool = state != "normal"
		var style := StyleBoxFlat.new()
		style.bg_color = base_color * (1.15 if state == "hover" else (0.8 if state == "pressed" else 1.0))
		var border_width: int = 4 if is_highlighted else 0
		style.border_width_left = border_width
		style.border_width_right = border_width
		style.border_width_top = border_width
		style.border_width_bottom = border_width
		style.border_color = Color(1, 1, 1)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		button.add_theme_stylebox_override(state, style)

func _make_character_tile(character_name: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = TILE_SIZE
	button.clip_text = false
	button.clip_contents = true
	var color: Color = GameState.CHARACTER_COLORS.get(character_name, GameState.DEFAULT_COLOR)
	_apply_tile_style(button, color)

	if GameState.has_portrait(character_name):
		var image := TextureRect.new()
		image.texture = GameState.portrait_texture(character_name)
		image.anchor_right = 1.0
		image.anchor_bottom = 1.0
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(image)
		GameState.frame_portrait(image, character_name, TILE_SIZE)

		var label := Label.new()
		label.text = character_name
		label.anchor_right = 1.0
		label.anchor_top = 1.0
		label.anchor_bottom = 1.0
		label.offset_top = -22
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		button.add_child(label)
	else:
		button.text = character_name
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 14)

	button.pressed.connect(_show_character.bind(character_name))
	return button

func _make_map_tile(map_name: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = MAP_TILE_SIZE
	button.clip_text = false
	_apply_tile_style(button, Color(0.16, 0.16, 0.19))

	var preview := MapPreview.new()
	preview.anchor_right = 1.0
	preview.anchor_bottom = 1.0
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.set_map(GameState.MAPS[map_name])
	button.add_child(preview)

	var label := Label.new()
	label.text = map_name
	label.anchor_right = 1.0
	label.anchor_top = 1.0
	label.anchor_bottom = 1.0
	label.offset_top = -20
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	button.add_child(label)

	button.pressed.connect(_show_map.bind(map_name))
	return button

## 씬을 트리에 넣지 않고 잠깐 instantiate만 해서 stats 값만 읽고 바로 버린다.
## _ready()는 트리에 들어가야 돌기 때문에 이 방식으로는 _ignore_other_fighters() 등 실행 없이 값만 훔쳐볼 수 있다
func _read_stats(character_name: String) -> CharacterStats:
	var scene: PackedScene = load(GameState.CHARACTERS[character_name])
	var fighter: Fighter = scene.instantiate()
	var stats: CharacterStats = fighter.stats
	fighter.free()
	return stats

## rating(1~5)만큼 색이 채워진 네모를, 나머지는 빈 네모로 채운 pip 바를 만든다
func _fill_pips(container: HBoxContainer, rating: int, color: Color) -> void:
	for child in container.get_children():
		child.free()
	for i in range(MAX_PIPS):
		var pip := ColorRect.new()
		pip.custom_minimum_size = PIP_SIZE
		pip.color = color if i < rating else Color(0.25, 0.25, 0.28)
		container.add_child(pip)

func _show_character(character_name: String) -> void:
	var color: Color = GameState.CHARACTER_COLORS.get(character_name, GameState.DEFAULT_COLOR)
	preview_box.color = color
	banner_shape.modulate = color
	banner_text.text = character_name
	preview_image.visible = true
	if GameState.has_portrait(character_name):
		preview_image.texture = GameState.portrait_texture(character_name)
		preview_box.clip_contents = true
		GameState.frame_portrait(preview_image, character_name, PREVIEW_BOX_SIZE)
		preview_label.visible = false
	else:
		preview_image.texture = null
		preview_label.visible = true
		preview_label.text = character_name

	var stats: CharacterStats = _read_stats(character_name)
	if stats:
		_fill_pips(attack_pips, stats.attack_rating, PIP_COLOR_ATTACK)
		_fill_pips(hp_pips, stats.hp_rating, PIP_COLOR_HP)
		_fill_pips(speed_pips, stats.speed_rating, PIP_COLOR_SPEED)
		description_label.text = stats.description if stats.description != "" else DEFAULT_DESCRIPTION
	else:
		_fill_pips(attack_pips, 0, PIP_COLOR_ATTACK)
		_fill_pips(hp_pips, 0, PIP_COLOR_HP)
		_fill_pips(speed_pips, 0, PIP_COLOR_SPEED)
		description_label.text = DEFAULT_DESCRIPTION

	_highlight_selected(character_name)

func _show_map(map_name: String) -> void:
	var color := Color(0.3, 0.3, 0.35)
	preview_box.color = color
	banner_shape.modulate = color
	banner_text.text = map_name
	preview_box.clip_contents = false
	preview_map.visible = true
	preview_map.set_map(GameState.MAPS[map_name])
	description_label.text = MAP_DESCRIPTIONS.get(map_name, DEFAULT_DESCRIPTION)
	_highlight_selected(map_name)

## 지금 고른 칸만 밝게, 나머지는 어둡게 — 캐릭터/맵 둘 다 같은 방식
func _highlight_selected(selected_name: String) -> void:
	for name_key in _thumb_buttons:
		var button: Button = _thumb_buttons[name_key]
		button.modulate = Color(1, 1, 1) if name_key == selected_name else Color(0.6, 0.6, 0.6)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
