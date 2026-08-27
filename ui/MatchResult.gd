class_name MatchResult
extends CanvasLayer

## 대전 종료 후 승패 결과를 보여주는 오버레이. Stage.gd가 승자를 판정하면 show_result()를 호출한다
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var retry_button: Button = $Panel/VBox/RetryButton
@onready var menu_button: Button = $Panel/VBox/MenuButton

func show_result(p1_won: bool, winner_name: String) -> void:
	title_label.text = ("승리! (%s)" if p1_won else "패배... (%s 승)") % winner_name

## 양쪽이 동시에 쓰러졌을 때 (무승부)
func show_draw() -> void:
	title_label.text = "무승부! 둘 다 쓰러졌습니다"

## 최종 승부가 아직 안 난 라운드 중간 결과 — 버튼 없이 점수만 잠깐 보여주고 Stage.gd가 알아서 다음 라운드로 넘어간다
func show_round_result(p1_won: bool, is_draw: bool, p1_wins: int, p2_wins: int) -> void:
	retry_button.visible = false
	menu_button.visible = false
	var round_text: String = "무승부" if is_draw else ("P1 라운드 승!" if p1_won else "P2 라운드 승!")
	title_label.text = "%s  (%d : %d)" % [round_text, p1_wins, p2_wins]

func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")
