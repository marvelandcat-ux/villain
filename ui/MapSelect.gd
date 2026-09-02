class_name MapSelect
extends Control

## 맵을 고르면 바로 그 맵으로 씬 전환 — 캐릭터는 이미 CharacterSelect에서 GameState에 저장돼 있다.
## 각 칸에는 MapPreview가 그 맵의 실제 바닥·벽 색과 배치를 미니 스케치로 그려서 맵 모습을 미리 보여준다

@onready var map_grid: GridContainer = $Center/VBox/MapGrid

func _ready() -> void:
	for map_name in GameState.MAPS.keys():
		map_grid.add_child(_make_tile(map_name, GameState.MAPS[map_name], _on_map_picked.bind(map_name)))
	map_grid.add_child(_make_tile("?", "", _on_random_pressed))

func _make_tile(label: String, map_path: String, callback: Callable) -> Button:
	var button := Button.new()
	button.clip_text = false
	_apply_tile_style(button)
	button.pressed.connect(callback)

	if map_path == "":
		button.text = label
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 28)
		return button

	var preview := MapPreview.new()
	preview.anchor_right = 1.0
	preview.anchor_bottom = 1.0
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.set_map(map_path)
	button.add_child(preview)

	var name_label := Label.new()
	name_label.text = label
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

func _apply_tile_style(button: Button) -> void:
	button.custom_minimum_size = Vector2(160, 90)
	# hover/pressed/focus(마우스로 올렸거나 키보드로 이동해 지금 고르고 있는 칸)는 두꺼운 흰 테두리로 강조,
	# normal은 은은한 회색 테두리로 눈에 덜 띄게 해서 "지금 뭘 고르는 중인지"가 한눈에 구분되게 한다
	for state in ["normal", "hover", "pressed", "focus"]:
		var is_highlighted: bool = state != "normal"
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.16, 0.19, 1) if is_highlighted else Color(0.09, 0.09, 0.11, 1)
		var border_width: int = 4 if is_highlighted else 2
		style.border_width_left = border_width
		style.border_width_right = border_width
		style.border_width_top = border_width
		style.border_width_bottom = border_width
		style.border_color = Color(1, 1, 1) if is_highlighted else Color(0.6, 0.6, 0.65)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		button.add_theme_stylebox_override(state, style)

func _on_map_picked(map_name: String) -> void:
	GameState.selected_map_path = GameState.MAPS[map_name]
	get_tree().change_scene_to_file(GameState.selected_map_path)

func _on_random_pressed() -> void:
	var map_name: String = GameState.MAPS.keys().pick_random()
	_on_map_picked(map_name)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/CharacterSelect.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
