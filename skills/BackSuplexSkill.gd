class_name BackSuplexSkill
extends Skill

## 백 서플렉스 — 잡기 기술. 손을 뻗어 상대를 붙잡는 잡기 모션이 먼저 끝난 뒤에,
## 그제서야 들어올려 등 뒤로 넘겨 꽂는다(주인공 스킬2). 이 게임엔 막기가 없어서
## 사거리 안에서 마주 보고 있으면 그냥 붙잡힌다.
## 대상이 사거리 밖에 있거나 없어도 동작 자체는 끝까지 재생된다("허공 잡기" 헛스윙) —
## 잡기 기술이니만큼 실패해도 몸이 그 자리에 묶이는 리스크는 그대로 지도록 둔다.
## 붙잡히는 동안 상대는 Fighter.is_grabbed로 완전히 무력화되고(이동·점프·공격·스킬 전부 불가,
## 중력도 안 받음) 이 스킬이 global_position을 직접 옮겨서 들어올리기/넘겨꽂기를 연출한다
##
## 잡기 판정 범위는 따로 값을 안 두고, 그림(BodyRig)의 손이 실제로 뻗는 거리(grab_reach_target.x)를
## 그대로 가져다 쓴다 — 값이 두 군데(스킬/그림)에 있으면 손 뻗는 거리를 조정했을 때 판정이 안 맞을
## 수 있어서, 한 곳(그림)만 기준으로 삼는다. 아래 값은 BodyRig가 없는 비주얼(임시 캐릭터 등)을 위한
## 대체값일 뿐이다
@export var fallback_grab_range: float = 50.0
@export var damage: int = 22
## 잡기 모션 — 손을 뻗어 실제로 붙잡을 때까지 걸리는 시간. 이동안 상대는 그 자리에 그대로 붙들려
## 있고(아직 들리지 않음), 이 시간이 끝나야 비로소 들어올리기가 시작된다
@export var grab_duration: float = 0.2
## 들어올리는 높이(위로 이동하는 거리, px)와 걸리는 시간 — 잡기 모션이 끝난 뒤부터 시작
@export var lift_height: float = 70.0
@export var lift_duration: float = 0.35
## 들어올린 채로 버티는 시간
@export var hold_duration: float = 0.25
## 등 뒤로 넘겨 꽂는 데 걸리는 시간
@export var slam_duration: float = 0.18
## 본체 등 뒤로 이 거리(px)만큼 떨어진 자리에 상대를 꽂는다 (앞이 아니라 뒤!)
@export var behind_distance: float = 55.0
## 내리꽂을 때 넉백 크기 — x는 본체 반대쪽(등 뒤 방향)으로 더 밀려나는 정도, y는 살짝 튕겨오르는 정도
@export var slam_knockback: Vector2 = Vector2(70, -60)
## 켜면 기술을 쓰는 동안(잡기~꽂기~풀기, 헛잡기 포함) **맞아도 안 끊긴다** — HP는 깎이지만 밀리거나 굳거나
## 다른 잡기에 끌려가지 않는다(`Fighter.add_super_armor`). 경찰 바디 수플렉스에서 켠다.
## 기본값이 꺼져 있는 이유: 짐승남 백 서플렉스도 이 스크립트를 쓰는데, 그쪽까지 바뀌면 안 되기 때문이다
@export var super_armor: bool = false

## 지금 아머를 걸어둔 본체. `_release`가 두 번 불려도 한 번만 풀도록 기억해둔다
var _armored_fighter: Fighter = null

func _execute(fighter: Fighter) -> void:
	_suplex(fighter, _find_target(fighter))

## 기술 시작 — 이동을 가로채고, 켜져 있으면 슈퍼아머를 건다. `_suplex`를 오버라이드하는 쪽도 맨 처음에 이걸 부를 것
func _begin(fighter: Fighter) -> void:
	fighter.movement_override = self
	if super_armor and _armored_fighter == null:
		fighter.add_super_armor()
		_armored_fighter = fighter

## 사거리 안에서 마주 보고 있는 상대를 찾는다. 없으면 null — _suplex가 그래도 동작은 재생한다
func _find_target(fighter: Fighter) -> Fighter:
	var opponent: Fighter = fighter.find_opponent()
	if opponent == null or not is_instance_valid(opponent):
		return null
	# **방어 중인 상대는 못 잡는다** — 잡히면 데미지가 0이어도 붙들려 있는 동안 무방비가 된다.
	# null을 돌려주면 _suplex가 "허공 잡기" 쪽으로 흘러가 동작만 재생하고 끝난다
	if not opponent.can_be_grabbed():
		return null
	var dx: float = opponent.global_position.x - fighter.global_position.x
	if absf(dx) > _grab_reach(fighter) or signf(dx) != fighter.facing:
		return null
	return opponent

## 손이 실제로 뻗는 거리를 판정 범위로 쓴다 (BodyRig.grab_reach_target.x) — 그 값이 없는
## 비주얼(임시 캐릭터 등)은 fallback_grab_range로 대신한다
func _grab_reach(fighter: Fighter) -> float:
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual:
		var target = visual.get("grab_reach_target")
		if target != null:
			return absf(target.x)
	return fallback_grab_range

func _suplex(fighter: Fighter, opponent: Fighter) -> void:
	_begin(fighter)

	# 본체 모션 재생 (그 메서드가 있는 비주얼만). 상대가 있으면 손을 뻗어 잡고(grab) → 뒤로 젖히며
	# 들어올려 버티고(lift+hold) → 등 뒤로 넘기는(slam) 전체 동작을, 없으면(허공 잡기) 손을 뻗기만
	# 하고 들어올리는 동작(손을 치켜드는 것)은 하지 않는다
	var fighter_visual: Node2D = fighter.get_node_or_null("Visual")
	if fighter_visual and fighter_visual.has_method("play_grab_motion"):
		if opponent != null:
			fighter_visual.play_grab_motion(grab_duration, lift_duration + hold_duration, slam_duration)
		else:
			fighter_visual.play_grab_motion(grab_duration, 0.0, 0.0)

	if opponent != null:
		# 잡히는 순간 바로 무력화 — 잡기 모션(손 뻗기)이 재생되는 동안에도 빠져나가지 못하게
		opponent.is_grabbed = true
		opponent.velocity = Vector2.ZERO

	# 잡기 — 손을 뻗어 실제로 붙잡을 때까지, 상대가 있으면 그 자리에 그대로 붙들려 있는다
	await get_tree().create_timer(grab_duration).timeout
	if not is_instance_valid(fighter):
		_release(fighter, opponent)
		return
	if opponent == null or not is_instance_valid(opponent):
		# 허공을 잡았다 — 그래도 동작은 끝까지 재생하고 조용히 마무리한다
		await get_tree().create_timer(lift_duration + hold_duration + slam_duration).timeout
		_release(fighter, opponent)
		return

	var opponent_visual: Node2D = opponent.get_node_or_null("Visual")
	var lift_pos: Vector2 = fighter.global_position + Vector2(0, -lift_height)

	# 들어올리기 — 잡기 모션이 끝난 뒤에야 상대를 본체 머리 위로 끌어올리며 거꾸로 뒤집는다
	var lift_tween := fighter.create_tween()
	lift_tween.tween_property(opponent, "global_position", lift_pos, lift_duration)
	if opponent_visual:
		lift_tween.parallel().tween_property(opponent_visual, "rotation", PI, lift_duration)
	await lift_tween.finished
	if not is_instance_valid(opponent) or not is_instance_valid(fighter):
		_release(fighter, opponent)
		return

	# 들고 버티기
	await get_tree().create_timer(hold_duration).timeout
	if not is_instance_valid(opponent) or not is_instance_valid(fighter):
		_release(fighter, opponent)
		return

	# 넘겨 꽂기 — 본체 앞이 아니라 등 뒤(바라보는 방향의 반대쪽)로 넘겨서 떨어뜨린다
	var slam_pos: Vector2 = fighter.global_position + Vector2(-fighter.facing * behind_distance, 0)
	var slam_tween := fighter.create_tween()
	slam_tween.tween_property(opponent, "global_position", slam_pos, slam_duration)
	await slam_tween.finished
	if is_instance_valid(opponent):
		opponent.is_grabbed = false
		var dmg: int = fighter.compute_damage(damage) if is_instance_valid(fighter) else damage
		var facing: float = fighter.facing if is_instance_valid(fighter) else 1.0
		# 등 뒤로 넘어간 방향(-facing) 그대로 더 밀려나며 넘어진다
		opponent.take_damage(dmg, Vector2(-facing * slam_knockback.x, slam_knockback.y))
		if opponent_visual:
			opponent_visual.rotation = 0.0   # 맞는 순간 히트 리액션이 다시 흔들어주니 여기선 그냥 되돌려만 둔다
	_release(fighter, opponent)

func _release(fighter: Fighter, opponent: Fighter) -> void:
	if is_instance_valid(opponent):
		opponent.is_grabbed = false
	if is_instance_valid(fighter) and fighter.movement_override == self:
		fighter.movement_override = null
	if _armored_fighter != null:
		if is_instance_valid(_armored_fighter):
			_armored_fighter.remove_super_armor()
		_armored_fighter = null

## 기술 도중에 스킬 노드가 사라지면(라운드 리로드·캐릭터 교체) `_release`가 안 불릴 수 있다 — 아머가 남지 않게 여기서도 푼다
func _exit_tree() -> void:
	if _armored_fighter != null and is_instance_valid(_armored_fighter):
		_armored_fighter.remove_super_armor()
	_armored_fighter = null

## 잡는 동안 본체는 제자리에 고정 — movement_override 인터페이스만 채워주는 빈 구현
func get_move_velocity_x() -> float:
	return 0.0

func after_physics(_fighter: Fighter, _delta: float) -> void:
	pass
