class_name CombatHUD
extends CanvasLayer

## 화면 좌/우에 FighterPanel 2개를 배치하는 HUD. 맵 조립 스크립트가 setup()으로 두 Fighter를 연결한다
@onready var p1_panel: FighterPanel = $P1Panel
@onready var p2_panel: FighterPanel = $P2Panel

func setup(p1: Fighter, p2: Fighter) -> void:
	p1_panel.bind(p1)
	p2_panel.bind(p2)
