class_name ConfirmPopup
extends Control

## "정말 할까요?"를 묻는 작은 확인 창. 화면 위에 겹쳐 뜨고, 뒤쪽은 클릭이 막힌다.
##
## 쓰는 쪽에서 open("...하시겠습니까?")로 열고 confirmed / cancelled 시그널을 받으면 된다.
## 어떤 동작을 할지는 이 창이 모른다 — 부르는 쪽이 정한다.

## 확인을 눌렀을 때
signal confirmed
## 취소를 누르거나 ESC를 눌렀을 때
signal cancelled

@onready var _message: Label = $Center/Panel/VBox/MessageLabel
@onready var _confirm_button: Button = $Center/Panel/VBox/ButtonRow/ConfirmButton

## 창이 닫힌 뒤 포커스를 돌려줄 곳 (열기 전에 포커스를 갖고 있던 버튼)
var _return_focus: Control

func _ready() -> void:
	hide()

## 창을 띄운다. 닫히면 confirmed 또는 cancelled 중 하나가 반드시 나온다
func open(message: String) -> void:
	_message.text = message
	# 취소하면 원래 누르던 버튼으로 포커스가 돌아가야 방향키 조작이 안 끊긴다
	_return_focus = get_viewport().gui_get_focus_owner()
	show()
	_confirm_button.grab_focus()

func _on_confirm_pressed() -> void:
	hide()
	confirmed.emit()

func _on_cancel_pressed() -> void:
	_close_and_restore_focus()
	cancelled.emit()

func _close_and_restore_focus() -> void:
	hide()
	if is_instance_valid(_return_focus):
		_return_focus.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		# 여기서 처리했다고 알려야 뒤쪽 화면의 ESC(타이틀로 나가기)가 같이 발동하지 않는다
		get_viewport().set_input_as_handled()
		_on_cancel_pressed()
