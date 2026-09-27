class_name StoneThrowSkill
extends Skill

## 돌 던지기 — 주인공 스토리 모드 스킬2.
## 어깨 뒤로 젖혀 들었다가 앞으로 돌을 뿌린다. 돌은 중력을 안 받고 **직선으로 쫘악 뻗어나가고**,
## **자전거로 돌진해 오는 상대(버릇없는 아이)를 맞히면 돌진이 그 자리에서 끊긴다.**
## 돌진 중이 아닌 상대에게 맞아도 데미지는 그대로 들어간다.
##
## 스토리 모드에서는 연출에 맞춰 주인공의 2번 스킬이 계속 바뀐다 — 이 스킬은 자전거 편(잼민이) 전용이다

@export var stone_scene: PackedScene = preload("res://skills/ThrownStone.tscn")
@export var damage: int = 6
## 날아가는 속도(px/s). 직구라 이 속도로 끝까지 간다
@export var throw_speed: float = 1100.0
## 던지는 순간 위로 뜨는 속도(px/s). **직구라 기본은 0이다** —
## 값을 주면 그만큼 포물선이 되는데, 높이 뜨면 돌진해 오는 상대의 머리 위로 넘어가서
## "자전거를 맞혀 멈춘다"가 거의 안 통한다
@export var throw_lift: float = 0.0
## 돌에 걸리는 중력(px/s²). **직구라 기본은 0이다**(안 떨어지고 수평으로 간다)
@export var stone_gravity: float = 0.0
## 이만큼 날아가면 아무것도 안 맞았어도 사라진다(px). 스킬 사거리 기준 "원거리"(SkillRange.LONG)에 맞췄다
@export var throw_range: float = 582.0
## 던지는 동작 전체 길이(초). 돌은 이 시간의 `BodyRig.throw_release_ratio`(기본 62%) 지점에서 손을 떠난다.
## 길수록 묵직해 보이지만 그만큼 돌이 늦게 나가서, 돌진해 오는 상대를 맞히기 어려워진다
@export var motion_duration: float = 0.5
## 던지는 동작이 없는 리그(BodyRig가 아닌 캐릭터)에서 쓸 대비용 예비동작 시간(초)
@export var fallback_windup: float = 0.16
## 던지기 전 손에 쥐여줄 돌 그림 — 이게 보이는 동안 원래 손에 든 물건(경봉)은 숨는다
@export var hand_stone_texture: Texture2D = preload("res://sprite/storymode/경찰서/던지는돌1-Photoroom.png")
## 손에 쥔 돌 그림의 크기 배율
@export var hand_stone_scale: float = 0.018
## 돌이 손을 떠나는 자리(캐릭터 원점 기준). x는 바라보는 방향으로 자동 반전, y는 음수가 위.
## **머리(대략 x -10~30, y -55~-20)보다 앞으로 빼둔다** — 더 안쪽에서 나오면 첫 프레임에 돌이 얼굴을 가린다
@export var hand_offset: Vector2 = Vector2(46, -20)
## 맞은 상대의 돌진(자전거)을 끊을지
@export var stop_dash: bool = true

func _execute(fighter: Fighter) -> void:
	var visual: Node2D = fighter.get_node_or_null("Visual")
	# 돌이 손을 떠나는 시점을 리그에서 직접 읽어온다 — 두 군데에 같은 숫자를 적어두면 한쪽만 고쳤을 때 손과 돌이 어긋난다
	var wait: float = fallback_windup
	if visual and visual.has_method("play_throw_motion"):
		visual.play_throw_motion(motion_duration)
		wait = motion_duration * float(visual.throw_release_ratio)
		# 손에 돌을 쥐여준다 (이 동안 경봉은 자동으로 숨는다)
		if visual.has_method("set_throw_item"):
			visual.set_throw_item(hand_stone_texture, hand_stone_scale)
	var direction: float = fighter.facing
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
	# 젖히는 동안 라운드가 끝나거나 캐릭터가 사라졌을 수 있다
	if not is_instance_valid(fighter):
		return
	# 손에 쥐고 있던 돌을 치우고, 같은 자리에서 진짜 돌을 날린다
	if visual and is_instance_valid(visual) and visual.has_method("clear_throw_item"):
		visual.clear_throw_item()
	_throw(fighter, direction)

func _throw(fighter: Fighter, direction: float) -> void:
	if stone_scene == null:
		return
	var parent: Node = fighter.get_parent()
	if parent == null:
		return
	var stone: ThrownStone = stone_scene.instantiate()
	parent.add_child(stone)
	stone.fall_gravity = stone_gravity
	stone.stop_dash = stop_dash
	# 사거리를 시간으로 환산해 수명에 넣는다 — 직구라 "속도 x 시간 = 거리"가 그대로 맞는다
	stone.lifetime = throw_range / maxf(throw_speed, 1.0)
	stone.global_position = fighter.global_position + Vector2(hand_offset.x * direction, hand_offset.y)
	stone.launch(direction, throw_speed, throw_lift, fighter.compute_damage(damage), fighter)

## 돌을 던지는 동작을 스킬이 직접 재생하므로 Fighter의 기본 스윙은 덧대지 않는다
func handles_own_visual() -> bool:
	return true
