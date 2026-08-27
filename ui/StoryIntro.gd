class_name StoryIntro
extends Control

## 스토리 모드 전용 — P1(플레이어) 캐릭터만 고르면 시작한다. 상대는 GameState.STORY_OPPONENTS 순서대로 자동 진행
@onready var status_label: Label = $VBox/StatusLabel
@onready var grid: GridContainer = $VBox/Grid

func _ready() -> void:
	status_label.text = "당신의 캐릭터를 선택하세요"
	for character_name in GameState.CHARACTERS.keys():
		var button := Button.new()
		button.text = character_name
		button.custom_minimum_size = Vector2(170, 48)
		button.pressed.connect(_on_character_picked.bind(character_name))
		grid.add_child(button)

func _on_character_picked(character_name: String) -> void:
	GameState.p1_character_path = GameState.CHARACTERS[character_name]
	GameState.p2_character_path = GameState.STORY_OPPONENTS[GameState.story_index]
	GameState.selected_map_path = GameState.STORY_MAP_PATH
	get_tree().change_scene_to_file(GameState.selected_map_path)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/ModeSelect.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
