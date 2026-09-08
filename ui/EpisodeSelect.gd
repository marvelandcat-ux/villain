class_name EpisodeSelect
extends Control

## 스토리 모드에서 어떤 상대(에피소드)와 싸울지 고르는 화면.
## 1번 에피소드만 처음부터 열려 있고, 하나를 깨야(GameState.mark_story_cleared) 다음이 열린다.
## 이미 깬 에피소드는 계속 다시 골라 재도전할 수 있다.

@onready var episode_grid: GridContainer = $Center/VBox/EpisodeGrid
@onready var status_label: Label = $Center/VBox/StatusLabel

func _ready() -> void:
	# 스토리 모드를 거치지 않고 이 화면으로 바로 들어온 경우(예: 디버그) 대비 — 크기가 안 맞으면 새로 초기화
	if GameState.story_cleared.size() != GameState.STORY_OPPONENTS.size():
		GameState.reset_story_progress()
	if GameState.is_story_complete():
		status_label.text = "모든 에피소드를 클리어했습니다! 다시 도전해보세요"
	for i in GameState.STORY_OPPONENTS.size():
		episode_grid.add_child(_make_tile(i))

func _make_tile(index: int) -> Button:
	var character_name: String = _find_character_name(GameState.STORY_OPPONENTS[index])
	var unlocked: bool = GameState.is_episode_unlocked(index)
	var cleared: bool = GameState.story_cleared[index]
	var color: Color = GameState.CHARACTER_COLORS.get(character_name, GameState.DEFAULT_COLOR) if unlocked else Color(0.16, 0.16, 0.18)

	var button := Button.new()
	button.clip_text = false
	button.disabled = not unlocked
	_apply_tile_style(button, color)
	if unlocked:
		button.pressed.connect(_on_episode_picked.bind(index))

	if unlocked:
		var portrait_path: String = GameState.PORTRAITS.get(character_name, "")
		if portrait_path != "":
			var image := TextureRect.new()
			image.texture = load(portrait_path)
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			image.anchor_right = 1.0
			image.anchor_bottom = 1.0
			image.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(image)

	var episode_label := Label.new()
	episode_label.text = "EPISODE %d" % (index + 1)
	episode_label.anchor_right = 1.0
	episode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	episode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	episode_label.add_theme_font_size_override("font_size", 11)
	episode_label.add_theme_constant_override("outline_size", 4)
	episode_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	button.add_child(episode_label)

	var name_label := Label.new()
	name_label.text = (character_name + ("  ✔" if cleared else "")) if unlocked else "잠김"
	name_label.anchor_right = 1.0
	name_label.anchor_top = 1.0
	name_label.anchor_bottom = 1.0
	name_label.offset_top = -20
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_constant_override("outline_size", 4)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	button.add_child(name_label)

	return button

## 캐릭터 씬 경로로 GameState.CHARACTERS에 등록된 표시 이름을 역으로 찾는다
func _find_character_name(path: String) -> String:
	for character_name in GameState.CHARACTERS.keys():
		if GameState.CHARACTERS[character_name] == path:
			return character_name
	return "?"

func _apply_tile_style(button: Button, color: Color) -> void:
	button.custom_minimum_size = Vector2(120, 100)
	# hover/pressed/focus는 두꺼운 흰 테두리로 강조(다른 선택 화면과 동일). 잠긴 칸은 disabled라 이 스타일이 안 보인다
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var is_highlighted: bool = state == "hover" or state == "pressed" or state == "focus"
		var style := StyleBoxFlat.new()
		style.bg_color = color * (1.15 if is_highlighted else 1.0)
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

func _on_episode_picked(index: int) -> void:
	GameState.story_index = index
	get_tree().change_scene_to_file("res://ui/CharacterSelect.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
