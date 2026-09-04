class_name CombatHUD
extends CanvasLayer

## 화면 좌/우에 FighterPanel 2개, 가운데 위에 남은 시간 박스와 라운드 스코어를 배치하는 HUD.
## 맵 조립 스크립트(Stage)가 setup()으로 두 Fighter를 연결하고, 매 프레임 update_round_info()로 갱신한다
@onready var p1_panel: FighterPanel = $P1Panel
@onready var p2_panel: FighterPanel = $P2Panel
@onready var round_label: Label = $RoundLabel
@onready var timer_frame: ColorRect = $TimerFrame
@onready var timer_label: Label = $TimerFrame/TimerBox/TimerLabel

func setup(p1: Fighter, p2: Fighter) -> void:
	p1_panel.bind(p1, "P1", false, 1)
	p2_panel.bind(p2, "P2(AI)", true, 2)

## 라운드 스코어와(있다면) 남은 시간을 화면 중앙 상단에 표시한다.
## 시간은 GameState.time_limit_seconds(방 설정에서 고른 값)에서 Stage가 깎아 내려주는 값이라
## 여기서는 따로 계산하지 않는다. 시간 제한 없음(0)이면 시간 박스 자체를 숨긴다
func update_round_info(p1_wins: int, p2_wins: int, time_left: float) -> void:
	round_label.text = "%d : %d" % [p1_wins, p2_wins]
	timer_frame.visible = time_left > 0.0
	if time_left > 0.0:
		timer_label.text = str(ceili(time_left))
		# 10초 이하로 남으면 숫자가 빨개져서 눈에 띈다
		timer_label.modulate = Color(1, 0.35, 0.3) if time_left <= 10.0 else Color(1, 1, 1)
