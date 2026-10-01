class_name ConfirmPopup
extends Control

## "정말 할까요?"를 묻는 작은 확인 창. 화면 위에 겹쳐 뜨고, 뒤쪽은 클릭이 막힌다.
##
## 쓰는 쪽에서 open("...하시겠습니까?")로 열고 confirmed / cancelled 시그널을 받으면 된다.
## 어떤 동작을 할지는 이 창이 모른다 — 부르는 쪽이 정한다.

## 열릴 때 툭 튀어나오는 데 걸리는 시간(초)
@export var open_time: float = 0.32
## 닫힐 때 오므라드는 시간(초). 닫는 건 여는 것보다 조금 빠른 게 답답하지 않다
@export var close_time: float = 0.22
## 시작 크기 (0.85면 85%에서 커진다)
@export_range(0.3, 1.0, 0.01) var open_from_scale: float = 0.85
## 제 크기를 살짝 넘었다가 돌아오는 정도 (0이면 그냥 커지기만 한다)
@export_range(0.0, 0.3, 0.01) var open_overshoot: float = 0.05

## 확인을 눌렀을 때
signal confirmed
## 취소를 누르거나 ESC를 눌렀을 때
signal cancelled
## 두 갈래 창(open_choice)에서 두 번째 버튼을 눌렀을 때 — 이때 ESC는 여전히 cancelled
signal alternate_chosen

@onready var _message: Label = $Center/Panel/VBox/MessageLabel
@onready var _confirm_button: Button = $Center/Panel/VBox/ButtonRow/ConfirmButton
@onready var _cancel_button: Button = $Center/Panel/VBox/ButtonRow/CancelButton
@onready var _panel: PanelContainer = $Center/Panel
@onready var _backdrop: ColorRect = $Backdrop

## 창이 닫힌 뒤 포커스를 돌려줄 곳 (열기 전에 포커스를 갖고 있던 버튼)
var _return_focus: Control
## 뒷배경이 다 깔렸을 때의 진하기 (씬에 저장된 값을 기억해뒀다가 그만큼까지 어두워진다)
var _backdrop_alpha: float = 0.62
## 연출이 얼마나 진행됐는지(초). 음수면 연출 중이 아니다
var _anim_time: float = -1.0
## 지금 연출이 여는 중인지 (false면 닫는 중)
var _opening: bool = true
## 닫는 연출이 끝나면 보낼 신호 ("confirmed" / "cancelled")
var _closing_result: String = ""
## 두 갈래 창으로 열렸는지 — 두 번째 버튼이 "취소" 대신 alternate_chosen을 보낸다
var _choice_mode: bool = false

func _ready() -> void:
	# **화면 전체 크기로 다시 잡아 준다.** 부모 씬에 인스턴스로 놓다가 앵커가 좌상단(preset 0)으로
	# 저장되면 이 Control이 0x0이 되고, 가운데 정렬(CenterContainer)이 0x0 안에서 이뤄져서
	# 창이 화면 왼쪽 위 구석에 붙어 버린다(2026-09-14 빌드에서 발견). 여기서 한 번 바로잡으면
	# 나중에 에디터가 또 앵커를 건드려도 실행할 땐 항상 가운데에 뜬다
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop_alpha = _backdrop.color.a
	hide()

## 창을 띄운다. 닫히면 confirmed 또는 cancelled 중 하나가 반드시 나온다
func open(message: String) -> void:
	_open_with(message, "확인", "취소", false)

## 버튼 두 개 중 하나를 고르는 창. 첫 버튼 = confirmed, 둘째 버튼 = alternate_chosen, ESC = cancelled
func open_choice(message: String, first_text: String, second_text: String) -> void:
	_open_with(message, first_text, second_text, true)

func _open_with(message: String, confirm_text: String, cancel_text: String, choice_mode: bool) -> void:
	_choice_mode = choice_mode
	_confirm_button.text = confirm_text
	_cancel_button.text = cancel_text
	_message.text = message
	# 취소하면 원래 누르던 버튼으로 포커스가 돌아가야 방향키 조작이 안 끊긴다
	_return_focus = get_viewport().gui_get_focus_owner()
	# 작고 투명한 상태에서 시작해야 첫 프레임에 제 크기로 번쩍하지 않는다
	_opening = true
	_anim_time = 0.0
	_apply_open(0.0, open_overshoot)
	show()
	_confirm_button.grab_focus()

func _process(delta: float) -> void:
	if _anim_time < 0.0:
		return
	var duration: float = open_time if _opening else close_time
	_anim_time = minf(_anim_time + delta, duration)
	var u: float = _anim_time / maxf(duration, 0.001)
	if _opening:
		_apply_open(u, open_overshoot)
	else:
		# 닫을 땐 같은 곡선을 거꾸로 탄다. 오므라들 때 튕기면 어색해서 오버슛은 뺀다
		_apply_open(1.0 - u, 0.0)
	if _anim_time >= duration:
		_anim_time = -1.0
		if not _opening:
			_finish_close()

## 닫는 연출을 시작한다. 이미 닫는 중이면 두 번 눌러도 무시한다
func _start_close(result: String) -> void:
	if _anim_time >= 0.0 and not _opening:
		return
	_closing_result = result
	_opening = false
	_anim_time = 0.0

## 다 오므라든 뒤에 실제로 숨기고 신호를 보낸다 (연출이 끝나고 화면이 넘어가야 자연스럽다)
func _finish_close() -> void:
	hide()
	if _closing_result == "confirmed":
		confirmed.emit()
	elif _closing_result == "alternate":
		alternate_chosen.emit()
	else:
		# 취소하면 원래 누르던 버튼으로 포커스를 돌려줘야 방향키 조작이 안 끊긴다
		if is_instance_valid(_return_focus):
			_return_focus.grab_focus()
		cancelled.emit()

## u가 0이면 작고 투명한 상태, 1이면 다 열린 상태
func _apply_open(u: float, overshoot: float) -> void:
	# 뒤로 갈수록 느려지게(감속) — 툭 튀어나왔다가 사뿐히 멈추는 느낌
	var eased: float = 1.0 - pow(1.0 - u, 3.0)
	# 제 크기를 살짝 넘었다가 돌아온다 (u=0.5 근처에서 가장 크다)
	var s: float = lerpf(open_from_scale, 1.0, eased) + overshoot * sin(u * PI)
	# 컨테이너가 크기를 정해주므로 축은 매번 다시 잡는다 (문구 길이에 따라 창 크기가 달라진다)
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2.ONE * s
	_panel.modulate.a = clampf(u * 2.0, 0.0, 1.0)
	_backdrop.color.a = _backdrop_alpha * eased

func _on_confirm_pressed() -> void:
	_start_close("confirmed")

func _on_cancel_pressed() -> void:
	_start_close("alternate" if _choice_mode else "cancelled")

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		# 여기서 처리했다고 알려야 뒤쪽 화면의 ESC(타이틀로 나가기)가 같이 발동하지 않는다
		get_viewport().set_input_as_handled()
		_start_close("cancelled")
