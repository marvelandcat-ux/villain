class_name CombatHUD
extends CanvasLayer

## 화면 좌/우에 FighterPanel 2개를 배치하는 HUD. 맵 조립 스크립트가 setup()으로 두 Fighter를 연결한다
@onready var p1_panel: FighterPanel = $P1Panel
@onready var p2_panel: FighterPanel = $P2Panel
@onready var round_label: Label = $RoundLabel

func setup(p1: Fighter, p2: Fighter) -> void:
	p1_panel.bind(p1, "P1")
	p2_panel.bind(p2, "P2(AI)")

## 라운드 스코어와(있다면) 남은 시간을 화면 중앙 상단에 표시한다
func update_round_info(p1_wins: int, p2_wins: int, time_left: float) -> void:
	var text: String = "%d : %d" % [p1_wins, p2_wins]
	if time_left > 0.0:
		text += "   %d" % ceili(time_left)
	round_label.text = text
