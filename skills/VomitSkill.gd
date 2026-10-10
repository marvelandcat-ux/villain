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
@export var base_height: float = 24.0
## 스택당 늘어나는 기둥 두께(px)
@export var height_per_stack: float = 16.0
## 캐릭터 원점에서 입까지의 거리 — x는 바라보는 방향으로 자동 반전되고, y는 음수가 위쪽
@export var mouth_offset: Vector2 = Vector2(18.0, -24.0)
## 스택별로 **그림만** 밀어내는 미세 조정값 (index = 술 스택 수). 판정은 안 움직인다.
## 그림마다 앞뒤 터짐 크기가 달라서, 예를 들어 3스택의 왼쪽 폭발이 얼굴을 가리면 여기서 앞으로 밀면 된다.
## x는 바라보는 방향 기준이라 양수가 항상 "앞쪽"이다.
## 캐릭터 씬을 열어놓고 이 값을 만지면 미리보기가 그 자리에서 같이 움직인다
@export var stack_visual_offsets: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
## 토하기 전 **차지**(초) — 토 표정 + 꿀꺽 움찔 뒤에 나간다(2026-10-10, 혈사포처럼 "즉발 말고"). 그동안 걸을 수는 있고
## 다른 스킬·평타는 막힌다. 나가는 순간의 자리·방향으로 쏜다. 0이면 바로(2026-10-10 사용자 "딜레이 없이 바로" — 지금 0)
@export var charge_time: float = 0.0
## 차지 때 몸이 움찔하는 정도(BodyRig.play_squash) — 볼에 머금는 느낌
@export var charge_squash: Vector2 = Vector2(1.1, 0.9)

@export_group("스택별 크기·위치")
## 스택별 **크기 배수** (index = 술 스택 수). **x는 길이, y는 두께**를 곱하고 판정도 같이 커지고 작아진다.
## 위 base_range/height 공식으로 뼈대를 잡고, 그림에 맞는 최종 크기는 여기서 스택마다 손본다.
## **캐릭터 씬의 SkillRangePreview 아래 `토하기N` 노드를 뷰포트에서 직접 끌고 늘린 뒤
## `Apply Holders To Skill`을 누르면 그 값이 여기로 들어온다** — 에디터에서 본 게 그대로 게임에 나온다
@export var stack_scales: Array[Vector2] = [Vector2.ONE, Vector2.ONE, Vector2.ONE, Vector2.ONE]
## 스택별로 **기둥 전체를(판정 포함) 입에서 더 밀어내는 양**. x는 바라보는 방향 기준이라 양수가 항상 "앞쪽".
## 그림만 밀고 싶으면 위의 stack_visual_offsets를 쓸 것 — 이건 맞는 범위까지 같이 움직인다
@export var stack_offsets: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]

func _execute(fighter: Fighter) -> void:
	# 토하는 표정으로 잠깐 얼굴을 바꾼다. 그 메서드가 없는 비주얼(임시 사각형 등)은 그냥 넘어간다
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("play_vomit_face"):
		visual.play_vomit_face()

	var stacks: int = fighter.custom_data.get("drink_stacks", 0)
	var damage: int = base_damage + damage_per_stack * stacks
	# 스택별 크기 배수는 길이·두께에 똑같이 곱한다 — 에디터에서 홀더를 통째로 늘린 것과 같은 뜻이 되도록
	var size_scale: Vector2 = scale_for(stacks)
	var length: float = (base_range + range_per_stack * stacks) * size_scale.x
	var height: float = (base_height + height_per_stack * stacks) * size_scale.y
	fighter.custom_data["drink_stacks"] = 0
	fighter.clear_modifier("move_speed_multiplier", "drink_stacks")
	fighter.clear_tint("drunk")
	# 다 게워냈으니 맨정신 얼굴로 되돌린다 (토하는 표정이 끝나는 시점에 반영된다)
	if visual and visual.has_method("set_drunk_head"):
		visual.set_drunk_head(false)

	if beam_scene == null:
		return
	if charge_time <= 0.0:
		_fire(fighter, stacks, length, height, damage)
		return
	if visual and visual.has_method("play_squash"):
		visual.play_squash(charge_squash)
	fighter.start_busy(charge_time + 0.05)
	# 시전자 자식 타이머 — 차지 중에 캐릭터가 사라지면 같이 사라진다(Timers.after 규칙)
	Timers.after(fighter, charge_time, _fire.bind(fighter, stacks, length, height, damage))

## 기둥을 실제로 내보낸다 — 이 순간의 입 자리·바라보는 쪽으로
func _fire(fighter: Fighter, stacks: int, length: float, height: float, damage: int) -> void:
	if not is_instance_valid(fighter) or fighter.get_parent() == null:
		return
	if fighter.is_grabbed:
		return
	var beam: VomitBeam = beam_scene.instantiate()
	fighter.get_parent().add_child(beam)
	beam.global_position = fighter.global_position + spawn_offset(stacks, fighter.facing)
	beam.setup(fighter.facing, length, height, fighter.compute_damage(damage), fighter, stacks, visual_offset_for(stacks))

## 캐릭터 원점에서 기둥이 시작되는 지점. 입 위치에 스택별 조정값을 더한 것.
## 미리보기도 같은 함수를 쓰므로 에디터와 게임이 어긋날 수 없다
func spawn_offset(stacks: int, facing: float) -> Vector2:
	var extra: Vector2 = offset_for(stacks)
	return Vector2((mouth_offset.x + extra.x) * facing, mouth_offset.y + extra.y)

## 그 스택의 그림 조정값 (안 적어뒀으면 0)
func visual_offset_for(stacks: int) -> Vector2:
	if stacks >= 0 and stacks < stack_visual_offsets.size():
		return stack_visual_offsets[stacks]
	return Vector2.ZERO

## 그 스택의 크기 배수 (x=길이, y=두께). 안 적어뒀거나 0이면 1배
func scale_for(stacks: int) -> Vector2:
	if stacks >= 0 and stacks < stack_scales.size():
		var s: Vector2 = stack_scales[stacks]
		if s.x > 0.0 and s.y > 0.0:
			return s
	return Vector2.ONE

## 그 스택의 전체 위치 조정값 (안 적어뒀으면 0)
func offset_for(stacks: int) -> Vector2:
	if stacks >= 0 and stacks < stack_offsets.size():
		return stack_offsets[stacks]
	return Vector2.ZERO
