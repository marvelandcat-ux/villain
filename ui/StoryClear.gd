class_name StoryClear
extends Control

## 스토리 모드에서 모든 상대를 개과천선시킨 뒤 보여주는 최종 클리어 화면
func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_on_menu_pressed()
