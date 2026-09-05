extends Node2D

## 새로 붙인 리그(층간소음/캣맘/지하철빌런) 조립 상태를 PNG로 뽑아보는 임시 확인용 도구.
## 확인이 끝나면 이 파일과 NewRigPreview.tscn은 지운다.
const RIGS := {
	"악플러": "res://characters/akpeulleo/AkpeulleoRig.tscn",
	"주정뱅이": "res://characters/jujeongbaengi/JujeongbaengiRig.tscn",
	"촉법소년": "res://characters/chokbeopsonyeon/ChokbeopsonyeonRig.tscn",
	"층간소음": "res://characters/floornoise/FloorNoiseRig.tscn",
	"캣맘": "res://characters/catmom/CatMomRig.tscn",
	"지하철빌런": "res://characters/subwayvillain/SubwayVillainRig.tscn",
}

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.9, 0.9, 0.92))
	var index: int = 0
	for label in RIGS.keys():
		var rig: Node2D = load(RIGS[label]).instantiate()
		rig.position = Vector2(220 + index * 340, 340)
		rig.scale = Vector2(3.0, 3.0)
		add_child(rig)
		index += 1
	queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("res://new_rig_preview.png")
	get_tree().quit()

func _draw() -> void:
	# 파란 사각형 = 충돌 캡슐 영역(가로 40, 세로 60 → 3배 확대), 초록 선 = 바닥 위치
	for i in range(RIGS.size()):
		var center_x: float = 220 + i * 340
		draw_rect(Rect2(center_x - 60, 340 - 90, 120, 180), Color(0.2, 0.4, 1.0, 0.6), false, 2.0)
		draw_line(Vector2(center_x - 120, 340 + 90), Vector2(center_x + 120, 340 + 90), Color(0.1, 0.7, 0.2), 2.0)
