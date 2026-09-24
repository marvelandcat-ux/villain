class_name BodySuplexSkill
extends BackSuplexSkill

## 바디 수플렉스(저먼 수플렉스) — 주인공 스킬1. 브록 레스너가 즐겨 쓰던 그 기술.
## 앞에서 상대를 붙잡고, 몸을 뒤로 확 젖히면서 상대를 **머리 위로 아치를 그리며 넘겨** 등 뒤 바닥에 꽂는다.
##
## 잡기 판정·잡힌 상대 무력화·놓아주기는 BackSuplexSkill(헬스장 빌런 스킬2)을 그대로 물려받고,
## **던지는 부분만** 다르게 만들었다 — 백 서플렉스는 "위로 들고 버틴 뒤 뒤로 옮겨 놓기"라 직선 두 번인데,
## 수플렉스는 멈춤 없이 한 번의 곡선으로 넘어가야 그 기술로 보인다.
## 상대는 넘어가는 동안 거꾸로 뒤집히고, 떨어질수록 빨라져서 바닥에 쾅 박힌다

## 붙잡은 뒤 머리 위로 넘겨 바닥에 박힐 때까지 걸리는 시간(초)
@export var throw_duration: float = 0.42
## 넘어가는 곡선의 꼭대기 높이(px) — 주인공 머리를 확실히 넘어야 한다
@export var arc_height: float = 130.0
## 뒤로 갈수록 빨라지는 정도. 1이면 일정한 속도, 클수록 처음엔 천천히 들리다 끝에서 확 꽂힌다
@export_range(1.0, 3.0, 0.05) var throw_accel: float = 1.7
## 꽂은 뒤 젖힌 자세(브릿지)를 유지하는 시간(초) — 기술이 들어갔다는 걸 읽을 틈
@export var bridge_hold: float = 0.2
## 몸을 젖힐 때 축이 되는 점 (리그 기준 좌표) — **발 높이**여야 발이 땅에 붙은 채 뒤로 넘어간다.
## 리그는 몸 한가운데를 원점으로 돌기 때문에, 그대로 두면 젖히는 순간 발이 공중으로 떠 버린다
@export var bridge_pivot: Vector2 = Vector2(0, 34)
## 꽂히는 순간 화면 흔들림 세기 (0~1)
@export_range(0.0, 1.0, 0.05) var impact_trauma: float = 0.55

func _suplex(fighter: Fighter, opponent: Fighter) -> void:
	_begin(fighter)

	# 몸 뒤로 젖히기는 리그의 잡기 모션을 그대로 쓴다: 손 뻗기(grab) → 바로 젖히며 던지기(버티기 없음)
	var fighter_visual: Node2D = fighter.get_node_or_null("Visual")
	if fighter_visual and fighter_visual.has_method("play_grab_motion"):
		if opponent != null:
			fighter_visual.play_grab_motion(grab_duration, 0.0, throw_duration + bridge_hold)
		else:
			fighter_visual.play_grab_motion(grab_duration, 0.0, 0.0)

	if opponent != null:
		opponent.is_grabbed = true
		opponent.velocity = Vector2.ZERO

	await get_tree().create_timer(grab_duration).timeout
	if not is_instance_valid(fighter):
		_release(fighter, opponent)
		return
	if opponent == null or not is_instance_valid(opponent):
		# 허공 잡기 — 손만 뻗고 헛치는 리스크는 그대로 진다
		await get_tree().create_timer(throw_duration + bridge_hold).timeout
		_release(fighter, opponent)
		return

	var opponent_visual: Node2D = opponent.get_node_or_null("Visual")
	var base_visual_pos: Vector2 = fighter_visual.position if fighter_visual else Vector2.ZERO
	var facing: float = fighter.facing
	var start: Vector2 = opponent.global_position
	# 등 뒤 바닥 — 앞에서 잡아 뒤로 넘긴다
	var land: Vector2 = Vector2(fighter.global_position.x - facing * behind_distance, fighter.global_position.y)

	# 넘기기 — 한 번의 곡선. 상대는 머리부터 뒤로 넘어가며 거꾸로 뒤집힌다
	var elapsed: float = 0.0
	while elapsed < throw_duration:
		await get_tree().process_frame
		if not is_instance_valid(opponent) or not is_instance_valid(fighter):
			_release(fighter, opponent)
			return
		elapsed += get_process_delta_time()
		var u: float = clampf(elapsed / maxf(throw_duration, 0.001), 0.0, 1.0)
		var e: float = pow(u, throw_accel)
		var pos: Vector2 = start.lerp(land, e)
		pos.y -= sin(PI * e) * arc_height
		opponent.global_position = pos
		# 앞(주인공 쪽)을 보던 머리가 뒤쪽으로 넘어가므로, 주인공이 오른쪽을 볼 때 반시계(음수)로 돈다
		if opponent_visual:
			opponent_visual.rotation = -facing * PI * e
		_plant_feet(fighter_visual, base_visual_pos)

	# 꽂힘
	opponent.is_grabbed = false
	if opponent_visual:
		opponent_visual.rotation = 0.0   # 맞는 순간 히트 리액션이 다시 흔들어 준다
	opponent.take_damage(fighter.compute_damage(damage), Vector2(-facing * slam_knockback.x, slam_knockback.y))
	var camera: Camera2D = fighter.get_viewport().get_camera_2d()
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(impact_trauma)

	# 젖힌 자세 잠깐 유지하고 풀어 준다 (유지하는 동안에도 발은 땅에 붙여 둔다)
	var held: float = 0.0
	while held < bridge_hold:
		await get_tree().process_frame
		if not is_instance_valid(fighter):
			break
		held += get_process_delta_time()
		_plant_feet(fighter_visual, base_visual_pos)
	if is_instance_valid(fighter_visual):
		fighter_visual.position = base_visual_pos
	_release(fighter, opponent)

## 리그가 기운 만큼 위치를 되돌려 **발(bridge_pivot)이 제자리에 남게** 한다.
## 리그 변환 = 위치 + 회전(배율(점)) 이라, 발이 원래 자리 base + 배율(발)에 오려면
## 위치 = base + 배율(발) - 회전(배율(발)) 이어야 한다 (배율에 좌우 뒤집기가 들어 있어도 그대로 맞는다)
func _plant_feet(visual: Node2D, base: Vector2) -> void:
	if not is_instance_valid(visual):
		return
	var foot: Vector2 = bridge_pivot * visual.scale
	visual.position = base + foot - foot.rotated(visual.rotation)
