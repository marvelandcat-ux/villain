class_name SpringJumpPad
extends Area2D

## 어린이용 스프링 시소(스프링 목마)를 점프대로 쓰는 기믹.
## 이 판정 안에 들어와 있는 동안 Fighter의 jump_multiplier에 boost를 걸어서,
## 여기 올라가서 점프하면 훨씬 높이 뜬다. 판정에서 벗어나면 바로 원래대로 돌아온다.
##
## 버프·디버프와 같은 방식(set_modifier/clear_modifier)을 쓰므로 다른 점프 효과
## (주정뱅이 궁극기의 점프력 디버프 등)와 겹쳐도 서로 지우지 않고 곱해진다.
## 스프링대마다 다른 id를 쓰기 때문에 두 대에 동시에 걸려도 서로 안 꼬인다.

## 점프력이 몇 배가 되는지. 2.0이면 점프 높이가 4배가 된다(높이는 속도의 제곱에 비례)
@export var boost: float = 2.0
## 밟고 있는 동안 스프링 그림이 눌리는 정도(0이면 연출 없음)
@export var squash: float = 0.45
## 눌리는 스프링 그림. 비워두면 연출 없이 점프력만 올라간다
@export var spring_visual: NodePath

## 지금 이 판정 위에 올라와 있는 Fighter들 {Fighter: true}
var _boosted: Dictionary = {}
## set_modifier에 쓰는 이 스프링대만의 id (두 대가 서로 덮어쓰지 않게)
var _modifier_id: String = ""
var _spring: Node2D
var _spring_base_scale := Vector2.ONE

func _ready() -> void:
	_modifier_id = "spring_pad_%d" % get_instance_id()
	if spring_visual != NodePath():
		_spring = get_node_or_null(spring_visual)
		if _spring:
			_spring_base_scale = _spring.scale

## area_entered/exited 신호 대신 매 프레임 겹친 목록을 훑는다 —
## 캐릭터가 판정 안에서 사라지거나(라운드 리셋) 순간이동하면 exited가 안 오는 경우가 있어서,
## "지금 겹쳐 있는가"를 매 프레임 다시 보는 쪽이 확실하다 (HazardPlatform과 같은 방식)
func _process(_delta: float) -> void:
	var standing: Dictionary = {}
	for area in get_overlapping_areas():
		if not (area is Hurtbox):
			continue
		var fighter: Fighter = area.fighter
		if fighter == null or not is_instance_valid(fighter):
			continue
		standing[fighter] = true
		if not _boosted.has(fighter):
			fighter.set_modifier("jump_multiplier", _modifier_id, boost)
			_boosted[fighter] = true

	for fighter in _boosted.keys():
		if standing.has(fighter):
			continue
		if is_instance_valid(fighter):
			fighter.clear_modifier("jump_multiplier", _modifier_id)
		_boosted.erase(fighter)

	_update_spring_visual(not standing.is_empty())

## 누가 올라가 있으면 스프링을 눌린 모양으로, 아니면 원래대로
func _update_spring_visual(pressed: bool) -> void:
	if _spring == null:
		return
	var target: Vector2 = _spring_base_scale
	if pressed:
		target = Vector2(_spring_base_scale.x * (1.0 + squash * 0.5), _spring_base_scale.y * (1.0 - squash))
	_spring.scale = _spring.scale.lerp(target, 0.35)
