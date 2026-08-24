class_name MainMenu
extends Control

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/CharacterSelect.tscn")
