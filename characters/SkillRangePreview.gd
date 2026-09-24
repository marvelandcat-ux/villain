@tool
class_name SkillRangePreview
extends Node2D

## 에디터에서만 동작하는 미리보기 — 토하기 기둥과 괴성 부채꼴이 몸의 어디에서 어떤 크기로 나가는지
## 캐릭터 씬 안에서 몸과 같이 보여준다. 게임 중에는 숨고 아무것도 하지 않는다.
##
## 모양을 새로 그리지 않고 실제 효과 씬(VomitBeam.tscn / ScreamCone.tscn)을 그대로 띄워서
## 같은 코드로 만들기 때문에, 여기 보이는 것이 곧 게임에서 나오는 모양이다.
##
## **켜고 끄는 건 씬 트리의 눈 아이콘으로 한다(2026-09-09 변경).**
## 자식으로 빈 담는 노드가 붙어 있고, 각 미리보기는 그 안에 만들어진다:
##   토하는얼굴 / 토하기0 / 토하기1 / 토하기2 / 토하기3 / 괴성
## **트리 순서가 곧 그리는 순서다(뒤에 있을수록 위).** 얼굴이 맨 앞에 있는 이유는,
## 게임에서 기둥이 캐릭터의 자식이 아니라 맵에 붙어서 캐릭터 위에 그려지기 때문이다 — 미리보기도 똑같이 맞춘 것
## 하나만 보고 싶으면 나머지 눈을 끄면 된다. 예전에는 체크박스 export로 껐는데,
## 네 개가 한꺼번에 나오고 궁극기까지 겹쳐서 위치를 잡을 수가 없었다.
##
## 담는 노드는 씬에 저장되지만 **안에 만들어지는 기둥·부채꼴은 owner를 안 주므로 저장되지 않는다** —
## 게임에 떠도는 Area2D가 생기지 않는다. 미리보기 노드 자체도 게임에서는 통째로 숨는다.
##
## 사용법: 캐릭터 씬을 열고 형제 노드인 Skill2(토하기)/SkillUltimate(괴성)의 값을 인스펙터에서 바꾸면
## 화면의 미리보기가 그 자리에서 같이 움직인다. 효과 씬 자체(색·두께 등)를 고쳤을 때는 Refresh를 눌러 다시 읽는다.

## 여러 개를 같이 켰을 때 각 기둥의 투명도. 하나만 켜면 이 값과 무관하게 불투명하게 보인다
@export_range(0.2, 1.0, 0.05) var all_stacks_alpha: float = 0.7:
	set(value):
		all_stacks_alpha = value
		_rebuild()
## 덧그리는 "입 벌린 토하는 얼굴"의 크기 배수.
## 토하는 머리(46px)가 평소 머리(55px)보다 작아서 1.0이면 뒤에 평소 머리가 테두리처럼 비친다.
## 실제 크기 그대로 보려면 1.0으로 내릴 것
@export_range(1.0, 1.6, 0.05) var vomit_face_scale: float = 1.2:
	set(value):
		vomit_face_scale = value
		_rebuild()
## **누르면 `토하기N` 노드를 끌고/늘려 맞춰둔 모양이 Skill2의 값으로 들어간다.**
## 홀더는 미리보기를 담는 껍데기라서 게임은 안 본다 — 이 버튼이 그 값을 게임이 읽는 곳으로 옮겨준다.
## 옮긴 뒤 홀더는 원점·1배로 되돌아가지만 **보이는 모양은 그대로다**(같은 값을 스킬 쪽에서 다시 적용하므로).
## 누른 다음 반드시 씬을 저장할 것
@export var apply_holders_to_skill: bool = false:
	set(value):
		apply_holders_to_skill = false
		_apply_holders()
## 효과 씬(VomitBeam.tscn / ScreamCone.tscn)에서 값을 고친 뒤 눌러서 다시 읽는다
@export var refresh: bool = false:
	set(value):
		refresh = false
		_rebuild()

## 담는 노드 이름 — 스택 수를 그대로 뒤에 붙인다
const BEAM_HOLDER := "토하기%d"
const CONE_HOLDER := "괴성"
const FACE_HOLDER := "토하는얼굴"

## 형제 스킬 노드에서 읽어온 값들. 이게 바뀌면 미리보기를 다시 만든다
var _last_snapshot: Array = []

func _ready() -> void:
	if not Engine.is_editor_hint():
		hide()
		set_process(false)
		return
	# _ready 도중에 자식을 붙이면 부모가 아직 정리 중이라 경고가 나므로 한 프레임 미룬다
	_rebuild.call_deferred()

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	var snapshot: Array = _snapshot()
	if snapshot != _last_snapshot:
		_last_snapshot = snapshot
		_rebuild()

## 인스펙터에서 값을 바꿨는지, 눈 아이콘을 껐다 켰는지 알아보려고 지금 상태를 모아둔다
func _snapshot() -> Array:
	var vomit := _skill("Skill2") as VomitSkill
	var scream := _skill("SkillUltimate") as ScreamConeUltimate
	var result: Array = []
	if vomit:
		result.append([vomit.mouth_offset, vomit.base_range, vomit.range_per_stack,
			vomit.base_height, vomit.height_per_stack, vomit.stack_visual_offsets.duplicate(),
			vomit.stack_scales.duplicate(), vomit.stack_offsets.duplicate()])
	if scream:
		result.append([scream.mouth_offset])
	# 담는 노드를 껐다 켜면 바로 반영되도록 보이기 상태도 같이 본다
	var shown: Array = []
	for child in get_children():
		shown.append([child.visible, child.position, child.scale])
	result.append(shown)
	return result

func _skill(node_name: String) -> Node:
	var fighter: Node = get_parent()
	return fighter.get_node_or_null(node_name) if fighter else null

## 스킬 노드의 스택별 그림 조정값을 읽는다.
## **에디터에서는 @tool이 아닌 스크립트의 메서드를 부를 수 없다**(껍데기 인스턴스라 "placeholder" 에러가 난다).
## 그래서 VomitSkill.visual_offset_for()를 부르지 않고 export 배열을 직접 들여다본다
func _offset_of(skill: Node, stacks: int) -> Vector2:
	return _array_at(skill.stack_visual_offsets, stacks, Vector2.ZERO)

## 기둥 전체(판정 포함)를 미는 값
func _whole_offset_of(skill: Node, stacks: int) -> Vector2:
	return _array_at(skill.stack_offsets, stacks, Vector2.ZERO)

## 크기 배수 (x=길이, y=두께). 0이 들어 있으면 무시하고 1배로 본다
func _scale_of(skill: Node, stacks: int) -> Vector2:
	var s: Vector2 = _array_at(skill.stack_scales, stacks, Vector2.ONE)
	return s if s.x > 0.0 and s.y > 0.0 else Vector2.ONE

func _array_at(arr: Array, index: int, fallback: Variant) -> Variant:
	if index >= 0 and index < arr.size():
		return arr[index]
	return fallback

## 술 스택 상한은 마시기 스킬이 들고 있다
func _max_stacks() -> int:
	var drink := _skill("Skill1") as DrinkSkill
	return drink.max_stacks if drink else 3

## 이름으로 담는 노드를 찾는다. 없으면 만들어서 씬에 남긴다(눈 아이콘으로 켜고 끌 수 있게 owner를 준다)
func _holder(holder_name: String) -> Node2D:
	var node: Node2D = get_node_or_null(holder_name) as Node2D
	if node:
		return node
	node = Node2D.new()
	node.name = holder_name
	add_child(node)
	if owner:
		node.owner = owner
	return node

func _rebuild() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	# 담는 노드는 남기고 그 안에 만들어둔 것만 지운다
	for child in get_children():
		for made in child.get_children():
			child.remove_child(made)
			made.queue_free()
	_build_vomit_face()
	_build_beam_previews()
	_build_cone_preview()

## 스택마다 담는 노드 안에 기둥을 하나씩 만든다. 꺼져 있는 노드는 건너뛴다
func _build_beam_previews() -> void:
	var skill := _skill("Skill2") as VomitSkill
	if skill == null or skill.beam_scene == null:
		return
	var top: int = _max_stacks()
	var shown: int = 0
	for stacks in range(top + 1):
		if _holder(BEAM_HOLDER % stacks).visible:
			shown += 1
	# 하나만 켜져 있으면 굳이 반투명하게 할 이유가 없다
	var alpha: float = 1.0 if shown <= 1 else all_stacks_alpha
	for stacks in range(top + 1):
		var holder: Node2D = _holder(BEAM_HOLDER % stacks)
		if not holder.visible:
			continue
		var beam := skill.beam_scene.instantiate() as VomitBeam
		holder.add_child(beam)
		# 게임(VomitSkill._execute)과 똑같은 식을 쓴다 — 오른쪽을 볼 때(facing=1)와 같은 배치
		var size_scale: Vector2 = _scale_of(skill, stacks)
		beam.position = skill.mouth_offset + _whole_offset_of(skill, stacks)
		beam.modulate.a = alpha
		beam.build_preview(1.0,
			(skill.base_range + skill.range_per_stack * stacks) * size_scale.x,
			(skill.base_height + skill.height_per_stack * stacks) * size_scale.y,
			stacks,
			_offset_of(skill, stacks))

## 입 벌린 토하는 얼굴을 머리 위에 한 장 덧그린다 (미리보기 전용).
## 리그(BodyRig)는 @tool이 아니라 play_vomit_face()를 부를 수 없고,
## Visual/Head의 텍스처를 직접 바꾸면 씬에 저장돼 게임에서도 토하는 얼굴이 되므로 **읽기만 하고 따로 그린다**
func _build_vomit_face() -> void:
	var holder: Node2D = _holder(FACE_HOLDER)
	if not holder.visible:
		return
	var visual: Node2D = get_parent().get_node_or_null("Visual") if get_parent() else null
	if visual == null:
		return
	var head: Sprite2D = visual.get_node_or_null("Head")
	# 껍데기 인스턴스에서도 export 값은 get()으로 읽힌다 (그 표정이 없는 캐릭터면 null)
	var face: Texture2D = visual.get("vomit_head_texture")
	if head == null or face == null:
		return
	var face_scale: Vector2 = visual.get("vomit_head_scale") if visual.get("vomit_head_scale") != null else Vector2.ZERO
	if face_scale == Vector2.ZERO:
		face_scale = head.scale
	var face_offset: Vector2 = visual.get("vomit_head_offset") if visual.get("vomit_head_offset") != null else Vector2.ZERO

	var sprite := Sprite2D.new()
	sprite.texture = face
	sprite.scale = face_scale * vomit_face_scale
	# 머리는 Visual의 자식이므로 Fighter 기준 좌표로 옮긴 뒤, 이 노드 기준으로 다시 뺀다
	sprite.position = visual.position + head.position + face_offset - position
	holder.add_child(sprite)

func _build_cone_preview() -> void:
	var holder: Node2D = _holder(CONE_HOLDER)
	if not holder.visible:
		return
	var skill := _skill("SkillUltimate") as ScreamConeUltimate
	if skill == null or skill.cone_scene == null:
		return
	var cone := skill.cone_scene.instantiate() as ScreamCone
	holder.add_child(cone)
	cone.position = skill.mouth_offset
	cone.build_preview(1.0)

## `토하기N` 홀더를 뷰포트에서 끌고/늘려 맞춰둔 모양을 Skill2의 값으로 옮긴다.
##
## 홀더는 미리보기를 담는 껍데기라 **게임은 홀더 트랜스폼을 전혀 안 본다.**
## 그래서 에디터에서 아무리 맞춰도 게임에서는 원래 크기로 나왔다 — 이 버튼이 그 간극을 메운다.
##
## 옮기고 나면 홀더는 원점·1배로 되돌리지만, 같은 값을 스킬 쪽에서 다시 적용하므로 **보이는 모양은 그대로다.**
## 원래 값에 홀더 값을 곱해서 누적하므로 여러 번 눌러도 어긋나지 않는다
func _apply_holders() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var skill := _skill("Skill2") as VomitSkill
	if skill == null:
		push_warning("SkillRangePreview: 형제 노드 Skill2를 못 찾았다")
		return
	var mouth: Vector2 = skill.mouth_offset
	var scales: Array[Vector2] = []
	var offsets: Array[Vector2] = []
	for stacks in range(_max_stacks() + 1):
		var holder: Node2D = _holder(BEAM_HOLDER % stacks)
		var hs: Vector2 = holder.scale
		# 홀더 안에서 기둥은 (입 + 기존 조정값) 자리에 기존 배수 크기로 놓여 있다.
		# 홀더의 이동·확대까지 먹인 최종 자리와 크기를 구해서 그대로 스킬 값으로 바꿔 적는다
		var old_scale: Vector2 = _scale_of(skill, stacks)
		var old_offset: Vector2 = _whole_offset_of(skill, stacks)
		var origin: Vector2 = holder.position + hs * (mouth + old_offset)
		scales.append(old_scale * hs)
		offsets.append(origin - mouth)
		holder.position = Vector2.ZERO
		holder.scale = Vector2.ONE
	skill.set("stack_scales", scales)
	skill.set("stack_offsets", offsets)
	# 값이 제대로 안 들어갔을 때 손으로 옮겨 적을 수 있도록 항상 찍어둔다
	print("[SkillRangePreview] 홀더 -> Skill2 적용")
	print("  stack_scales  = ", scales)
	print("  stack_offsets = ", offsets)
	if Engine.has_singleton("EditorInterface"):
		var ei: Object = Engine.get_singleton("EditorInterface")
		if ei.has_method("mark_scene_as_unsaved"):
			ei.call("mark_scene_as_unsaved")
	_rebuild()
