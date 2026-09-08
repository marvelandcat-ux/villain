class_name RoundStart
extends CanvasLayer

## 대전 시작 전 "3, 2, 1, FIGHT!" 카운트다운을 보여준다. play()가 끝나야 완료된 걸로 친다
## 숫자는 노란색, FIGHT!는 강조를 위해 빨간색으로 표시
const FIGHT_COLOR := Color(1, 0.15, 0.1, 1)
const NUMBER_COLOR := Color(1, 0.85, 0, 1)

@onready var label: Label = $Label

signal finished

func _ready() -> void:
	play()

func play() -> void:
	for text in ["3", "2", "1", "FIGHT!"]:
		label.text = text
		label.add_theme_color_override("font_color", FIGHT_COLOR if text == "FIGHT!" else NUMBER_COLOR)
		_pop()
		await get_tree().create_timer(0.6).timeout
	finished.emit()
	queue_free()

func _pop() -> void:
	label.scale = Vector2(1.6, 1.6)
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
