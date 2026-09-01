extends Node2D

const STEPS := 6

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.93, 0.93, 0.95))
	for i in range(STEPS):
		var rig: Node2D = load("res://characters/akpeulleo/AkpeulleoRig.tscn").instantiate()
		rig.position = Vector2(105 + i * 187, 320)
		rig.scale = Vector2(1.9, 1.9)
		add_child(rig)
		# 1번은 평소 자세, 2~6번이 예비동작~휘두르기
		if i > 0:
			var progress: float = 0.30 + (i - 1) * 0.11
			rig.set("_attack_time", rig.attack_duration * (1.0 - progress))
	queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_swing.png")
	get_tree().quit()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var labels := ["평소", "예비", "훑기", "아래", "올림", "끝"]
	for i in range(STEPS):
		var x: float = 105 + i * 187
		draw_line(Vector2(x - 85, 320 + 57), Vector2(x + 85, 320 + 57), Color(0.1, 0.7, 0.2), 2.0)
		draw_string(font, Vector2(x - 22, 500), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.15, 0.15, 0.2))
