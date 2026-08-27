class_name ModeSelect
extends Control

## 스토리 모드 / 로컬 대전을 고르는 화면 (메인 메뉴 다음)

func _on_story_pressed() -> void:
	GameState.game_mode = "story"
	GameState.rounds_to_win = 2
	GameState.time_limit_seconds = 120
	GameState.story_index = 0
	GameState.reset_round_wins()
	get_tree().change_scene_to_file("res://ui/StoryIntro.tscn")

func _on_local_pvp_pressed() -> void:
	GameState.game_mode = "pvp"
	get_tree().change_scene_to_file("res://ui/RoomSettings.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
