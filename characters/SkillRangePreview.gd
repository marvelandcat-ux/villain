@tool
extends Node2D

## 에디터에서만 동작하는 미리보기 — 토하기 기둥과 괴성 부채꼴이 몸의 어디에서 어떤 크기로 나가는지
## 캐릭터 씬 안에서 몸과 같이 보여준다. 게임 중에는 숨고 아무것도 하지 않는다.
##
## 모양을 새로 그리지 않고 실제 효과 씬(VomitBeam.tscn / ScreamCone.tscn)을 그대로 띄워서
## 같은 코드로 만들기 때문에, 여기 보이는 것이 곧 게임에서 나오는 모양이다.
## 붙이는 자식들은 owner를 지정하지 않으므로 씬 파일(.tscn)에는 저장되지 않는다.
##
## 사용법: 캐릭터 씬을 열고 형제 노드인 Skill2(토하기)/SkillUltimate(괴성)의 값을 인스펙터에서 바꾸면
## 화면의 미리보기가 그 자리에서 같이 움직인다. 효과 씬 자체(사거리 색·두께 등)를 고쳤을 때는 Refresh를 눌러 다시 읽는다.

## 미리보기에 쓸 술 스택 수. 0이면 코앞, 최대치면 맵 끝까지 나가는 기둥이 보인다
@export_range(0, 5, 1) var preview_stacks: int = 3:
	set(value):
		preview_stacks = value
		_rebuild()
## 토하기 기둥을 보여줄지
@export var show_vomit_beam: bool = true:
	set(value):
		show_vomit_beam = value
		_rebuild()
## 괴성 부채꼴을 보여줄지
@export var show_scream_cone: bool = true:
	set(value):
		show_scream_cone = value
		_rebuild()
## 효과 씬(VomitBeam.tscn / ScreamCone.tscn)에서 값을 고친 뒤 눌러서 다시 읽는다
@export var refresh: bool = false:
	set(value):
		refresh = false
		_rebuild()

var _beam: VomitBeam
var _cone: ScreamCone
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

## 인스펙터에서 값을 바꿨는지 알아보려고 스킬 노드의 값들을 모아둔다
func _snapshot() -> Array:
	var vomit := _skill("Skill2") as VomitSkill
	var scream := _skill("SkillUltimate") as ScreamConeUltimate
	var result: Array = []
	if vomit:
		result.append([vomit.mouth_offset, vomit.base_range, vomit.range_per_stack,
			vomit.base_height, vomit.height_per_stack])
	if scream:
		result.append([scream.mouth_offset])
	return result

func _skill(node_name: String) -> Node:
	var fighter: Node = get_parent()
	return fighter.get_node_or_null(node_name) if fighter else null

func _rebuild() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	for old in [_beam, _cone]:
		if is_instance_valid(old):
			remove_child(old)
			old.queue_free()
	_beam = null
	_cone = null
	_build_beam_preview()
	_build_cone_preview()

func _build_beam_preview() -> void:
	if not show_vomit_beam:
		return
	var skill := _skill("Skill2") as VomitSkill
	if skill == null or skill.beam_scene == null:
		return
	var stacks: int = mini(preview_stacks, _max_stacks())
	_beam = skill.beam_scene.instantiate() as VomitBeam
	add_child(_beam)
	_beam.position = skill.mouth_offset
	_beam.build_preview(1.0,
		skill.base_range + skill.range_per_stack * stacks,
		skill.base_height + skill.height_per_stack * stacks)

func _build_cone_preview() -> void:
	if not show_scream_cone:
		return
	var skill := _skill("SkillUltimate") as ScreamConeUltimate
	if skill == null or skill.cone_scene == null:
		return
	_cone = skill.cone_scene.instantiate() as ScreamCone
	add_child(_cone)
	_cone.position = skill.mouth_offset
	_cone.build_preview(1.0)

## 술 스택 상한은 마시기 스킬이 들고 있다. 미리보기 스택이 그보다 크면 상한으로 자른다
func _max_stacks() -> int:
	var drink := _skill("Skill1") as DrinkSkill
	return drink.max_stacks if drink else 3
