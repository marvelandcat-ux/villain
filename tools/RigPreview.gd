extends Node2D

## BodyRig 조립 상태를 PNG로 뽑아보는 임시 미리보기 도구 (확인용, 게임에는 쓰지 않음)
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.9, 0.9, 0.92))
	var rig: Node2D = preload("res://characters/BodyRig.tscn").instantiate()
	rig.position = Vector2(576, 340)
	rig.scale = Vector2(4.0, 4.0)
	add_child(rig)
	# 캡슐 콜리전(radius 20 / height 60) 범위를 참고선으로 같이 그린다
	queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("res://rig_preview.png")
	get_tree().quit()

func _draw() -> void:
	# 파란 사각형 = 충돌 캡슐이 차지하는 영역(가로 40, 세로 60), 초록 선 = 바닥 위치
	draw_rect(Rect2(576 - 80, 340 - 120, 160, 240), Color(0.2, 0.4, 1.0, 0.6), false, 2.0)
	draw_line(Vector2(300, 340 + 120), Vector2(850, 340 + 120), Color(0.1, 0.7, 0.2), 2.0)
