class_name VomitSkill
extends Skill

## 토하기 — 술 스택 수에 비례해 데미지·길이·두께가 세진다. 쓰면 스택이 전부 사라지고 이동속도도 원래대로 돌아온다.
## 날아가는 투사체가 아니라 입에서 앞으로 한 번에 뻗는 가로 기둥이다(아이작 혈사포 느낌).
## 실제 판정과 그림은 VomitBeam.tscn이 전부 들고 있고, 여기서는 스택에 따른 길이·두께·데미지만 계산한다 (주정뱅이 스킬2)
##
## 길이는 0스택 40px(캐릭터 한 칸 폭 — 코앞에 게워냄)에서 스택당 310px씩 늘어 3스택이면 970px.
## 970px는 가로맵의 벽 안쪽 폭(x -460 ~ 460 = 920px)보다 길어서, 최대 스택이면 맵 어디에 서 있든 반대편 벽까지 닿는다
@export var beam_scene: PackedScene
@export var base_damage: int = 6
@export var damage_per_stack: int = 4
## 0스택일 때 기둥 길이(px)
@export var base_range: float = 40.0
## 스택당 늘어나는 기둥 길이(px)
@export var range_per_stack: float = 310.0
## 0스택일 때 기둥 두께(px)
@export var base_height: float = 28.0
## 스택당 늘어나는 기둥 두께(px)
@export var height_per_stack: float = 8.0
## 캐릭터 원점에서 입까지의 거리 — x는 바라보는 방향으로 자동 반전되고, y는 음수가 위쪽
@export var mouth_offset: Vector2 = Vector2(18.0, -24.0)

func _execute(fighter: Fighter) -> void:
	# 토하는 표정으로 잠깐 얼굴을 바꾼다. 그 메서드가 없는 비주얼(임시 사각형 등)은 그냥 넘어간다
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("play_vomit_face"):
		visual.play_vomit_face()

	var stacks: int = fighter.custom_data.get("drink_stacks", 0)
	var damage: int = base_damage + damage_per_stack * stacks
	var length: float = base_range + range_per_stack * stacks
	var height: float = base_height + height_per_stack * stacks
	fighter.custom_data["drink_stacks"] = 0
	fighter.clear_modifier("move_speed_multiplier", "drink_stacks")
	fighter.clear_tint("drunk")
	# 다 게워냈으니 맨정신 얼굴로 되돌린다 (토하는 표정이 끝나는 시점에 반영된다)
	if visual and visual.has_method("set_drunk_head"):
		visual.set_drunk_head(false)

	if beam_scene == null:
		return
	var beam: VomitBeam = beam_scene.instantiate()
	fighter.get_parent().add_child(beam)
	beam.global_position = fighter.global_position + Vector2(mouth_offset.x * fighter.facing, mouth_offset.y)
	beam.setup(fighter.facing, length, height, fighter.compute_damage(damage), fighter)
