class_name ModeSelect
extends Control

## 스토리 모드 / 로컬 대전 / 훈련장을 고르는 화면 (메인 메뉴 다음)

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

## 훈련장 — 상대도 라운드도 없이 캐릭터 하나만 평지에 세워두고 중력·속도 같은 값을 조절해보는 방.
## 캐릭터 선택 화면을 거치지 않고 바로 들어가고, 캐릭터는 훈련장 안에서 바꾼다
func _on_training_pressed() -> void:
	GameState.game_mode = "training"
	get_tree().change_scene_to_file("res://maps/TrainingGround.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
