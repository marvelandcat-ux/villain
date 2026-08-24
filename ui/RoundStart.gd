class_name RoundStart
extends CanvasLayer

## 대전 시작 전 "3, 2, 1, FIGHT!" 카운트다운을 보여준다. play()가 끝나야 완료된 걸로 친다
@onready var label: Label = $Label

signal finished

func _ready() -> void:
	play()

func play() -> void:
	for text in ["3", "2", "1", "FIGHT!"]:
		label.text = text
		await get_tree().create_timer(0.6).timeout
	finished.emit()
	queue_free()
