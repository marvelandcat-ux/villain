class_name MapSelect
extends Control

## 맵을 고르면 바로 그 맵으로 씬 전환 — 캐릭터는 이미 CharacterSelect에서 GameState에 저장돼 있다
@onready var list: VBoxContainer = $VBox/List

func _ready() -> void:
	for map_name in GameState.MAPS.keys():
		var button := Button.new()
		button.text = map_name
		button.custom_minimum_size = Vector2(240, 44)
		button.pressed.connect(_on_map_picked.bind(map_name))
		list.add_child(button)

func _on_map_picked(map_name: String) -> void:
	GameState.selected_map_path = GameState.MAPS[map_name]
	get_tree().change_scene_to_file(GameState.selected_map_path)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/CharacterSelect.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
