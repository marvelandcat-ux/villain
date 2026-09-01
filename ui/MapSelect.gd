class_name MapSelect
extends Control

## 맵을 고르면 바로 그 맵으로 씬 전환 — 캐릭터는 이미 CharacterSelect에서 GameState에 저장돼 있다.
## 스케치처럼 격자 모양의 빈 사각형 칸으로 맵 목록을 보여준다 (아직 맵별 미리보기 그림은 없음)

@onready var map_grid: GridContainer = $Center/VBox/MapGrid

func _ready() -> void:
	for map_name in GameState.MAPS.keys():
		map_grid.add_child(_make_tile(map_name, _on_map_picked.bind(map_name)))
	map_grid.add_child(_make_tile("?", _on_random_pressed))

func _make_tile(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_tile_style(button)
	button.pressed.connect(callback)
	return button

func _apply_tile_style(button: Button) -> void:
	button.custom_minimum_size = Vector2(160, 90)
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.09, 0.09, 0.11, 1) if state != "hover" else Color(0.16, 0.16, 0.19, 1)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.5, 0.5, 0.55) if state == "pressed" else Color(0.85, 0.85, 0.9)
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
