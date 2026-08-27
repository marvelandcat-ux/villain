class_name CharacterSelect
extends Control

## P1(플레이어) 캐릭터를 먼저 고르고, 이어서 P2(AI) 캐릭터를 고르면 맵 선택 화면으로 넘어간다
@onready var status_label: Label = $VBox/StatusLabel
@onready var grid: GridContainer = $VBox/Grid

var _picking_p1: bool = true

func _ready() -> void:
	status_label.text = "P1(플레이어) 캐릭터를 선택하세요"
	for character_name in GameState.CHARACTERS.keys():
		var button := Button.new()
		button.text = character_name
		button.custom_minimum_size = Vector2(170, 48)
		button.pressed.connect(_on_character_picked.bind(character_name))
		grid.add_child(button)

func _on_character_picked(character_name: String) -> void:
	var path: String = GameState.CHARACTERS[character_name]
	if _picking_p1:
		GameState.p1_character_path = path
		_picking_p1 = false
		status_label.text = "P1: %s | P2(AI) 캐릭터를 선택하세요" % character_name
	else:
		GameState.p2_character_path = path
		get_tree().change_scene_to_file("res://ui/MapSelect.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/RoomSettings.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
