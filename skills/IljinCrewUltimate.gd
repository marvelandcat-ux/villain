class_name IljinCrewUltimate
extends Skill

## 패거리 부르기 — 일진 궁극기 (2026-09-14, **1단계: 등장까지만**).
## 궁을 쓴 자리 좌우에 **일진의 친구(왼쪽)와 여자친구(오른쪽)** 가 투명한 채로 나타나 서서히 진해진다.
## 지금은 나타나서 가만히 서 있는 것까지다 — 공격·버프·퇴장은 다음 단계에서 붙인다.
##
## 둘은 `IljinCrewMember`(StaticBody2D + Hurtbox + BodyRig)라 **몸으로 길을 막고 맞으면 HP가 깎인다.**
## 그 안의 `Visual`(BodyRig)은 부모가 Fighter가 아니라서 `_face_moving_direction()`이 그냥 넘어가고
## 걷기 속도도 0이라, 따로 정지 처리를 안 해도 숨쉬기·머리 긁기만 하는 "가만히 서 있는" 상태가 된다.

## 좌우에 세울 몸(`characters/iljin/IljinFriend.tscn` / `IljinGirlfriend.tscn`)
@export var friend_scene: PackedScene
@export var girlfriend_scene: PackedScene
## 궁을 쓴 자리에서 좌우로 떨어뜨릴 거리(px)
@export var side_offset: float = 95.0
## 투명(0) -> 불투명(1)이 되는 데 걸리는 시간(초)
@export var fade_in: float = 0.55
## 패거리를 그리는 층 — 캐릭터와 같은 층(0). 소환물은 전부 캐릭터와 같은 층에 그린다(2026-10-04 확정)
@export var crew_z_index: int = 0

func _execute(fighter: Fighter) -> void:
	# **화면 기준으로 친구가 늘 왼쪽, 여자친구가 늘 오른쪽이다** — 일진이 어느 쪽을 보든 자리는 고정이라
	# "누가 어느 쪽에 있었지"를 매번 다시 읽을 필요가 없다
	_summon(fighter, friend_scene, -side_offset)
	_summon(fighter, girlfriend_scene, side_offset)

## 궁을 쓴 자리에서 dx만큼 떨어진 곳에 한 명을 띄운다
func _summon(fighter: Fighter, scene: PackedScene, dx: float) -> void:
	if scene == null:
		return
	var map: Node = fighter.get_parent()
	if map == null:
		return
	var crew := scene.instantiate() as Node2D
	if crew == null:
		return
	map.add_child(crew)
	crew.global_position = fighter.global_position + Vector2(dx, 0.0)
	crew.z_index = crew_z_index
	# 부른 사람의 공격은 안 맞게 해둔다 — 바로 옆에 서 있어서 상대를 때리려다 자기 편을 때린다
	if crew.has_method("set_owner_fighter"):
		crew.set_owner_fighter(fighter)
	# 일진과 같은 쪽을 본다. **루트(StaticBody2D)가 아니라 Visual만 뒤집는다** —
	# 물리 몸에 음수 배율을 주면 충돌 도형까지 뒤집혀 엉뚱하게 동작한다.
	# 리그는 부모가 Fighter가 아니면 매 프레임 방향을 다시 잡지 않아 이 부호가 그대로 유지된다
	var dir: float = signf(fighter.facing)
	if is_zero_approx(dir):
		dir = 1.0
	var visual := crew.get_node_or_null("Visual") as Node2D
	if visual:
		visual.scale.x = absf(visual.scale.x) * dir
	# 투명한 채로 나타나 서서히 진해진다
	crew.modulate.a = 0.0
	var tween := crew.create_tween()
	tween.tween_property(crew, "modulate:a", 1.0, fade_in)
