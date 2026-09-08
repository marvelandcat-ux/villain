extends Node2D
func _ready() -> void:
	GameState.game_mode = "pvp"
	GameState.p1_character_path = "res://characters/jujeongbaengi/Jujeongbaengi.tscn"
	GameState.p2_character_path = "res://characters/jujeongbaengi/Jujeongbaengi.tscn"
	GameState.time_limit_seconds = 0
	add_child(load("res://maps/SubwayPlatform.tscn").instantiate())
	await _wait(3.8)   # 카운트다운 끝나 컨트롤러 is_active 될 때까지
	var fs: Array = get_tree().get_nodes_in_group("fighters")
	var atk: Fighter = fs[0]; var vic: Fighter = fs[1]
	var combo := atk.get_node("BasicAttack")
	# 붙여두기 (상대 정지)
	atk.global_position.x = vic.global_position.x - 34.0
	atk.facing = 1.0
	var s := vic.current_hp
	print("=== 진짜 F키 입력 주입으로 3번 탭 ===")
	for i in range(3):
		# 진짜 입력 이벤트 (컨트롤러의 is_action_just_pressed 경로를 그대로 탄다)
		Input.action_press("p1_basic_attack")
		await get_tree().physics_frame
		await get_tree().physics_frame
		Input.action_release("p1_basic_attack")
		await _wait(0.30)
		print("  탭%d -> 상대HP=%d  콤보단계=%d  쿨=%.2f is_busy=%s" % [
			i+1, vic.current_hp, combo._step, combo.cooldown_left, str(atk.is_busy())])
		await _wait(0.10)
	print("  => 총 %d 데미지 (기대 14)" % (s - vic.current_hp))
	print("ALLDONE")
	get_tree().quit()
func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout
