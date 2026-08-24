class_name MatchResult
extends CanvasLayer

## 대전 종료 후 승패 결과를 보여주는 오버레이. Stage.gd가 승자를 판정하면 show_result()를 호출한다
@onready var title_label: Label = $Panel/VBox/TitleLabel

func show_result(p1_won: bool, winner_name: String) -> void:
	title_label.text = ("승리! (%s)" if p1_won else "패배... (%s 승)") % winner_name

## 양쪽이 동시에 쓰러졌을 때 (무승부)
func show_draw() -> void:
	title_label.text = "무승부! 둘 다 쓰러졌습니다"

func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")
