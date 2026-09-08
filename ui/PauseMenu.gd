class_name PauseMenu
extends CanvasLayer

## ESC로 여는 일시정지 메뉴. Stage.gd가 ui_cancel을 받으면 이 씬을 띄운다.
## 게임을 멈추는 것도(get_tree().paused) 이 스크립트 자신이 처리한다 — 그래서 이 노드는
## process_mode = ALWAYS로 둬서 게임이 멈춰 있어도 계속 입력을 받는다(궁극기 컷인과 같은 방식)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_resume_pressed()

func _on_resume_pressed() -> void:
	get_tree().paused = false
	queue_free()

func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")
