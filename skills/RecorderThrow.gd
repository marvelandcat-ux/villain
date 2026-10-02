class_name RecorderThrow
extends Node

## 지하철 아저씨 **쌍 악기 평타의 던지기 장치**. `BasicAttack`(ComboMeleeAttack)의 자식으로 달아 둔다.
##
## 콤보가 매 타의 판정 순간에 `on_combo_strike(fighter, step)`을 불러 주고,
## 여기서 **true를 돌려주면 그 타는 몸 판정을 안 켠다** — 날아간 리코더가 대신 때린다.
##
##  - `throw_step`(1타): 왼손의 검은 리코더를 던진다. 손에서는 사라지고 날아가며 때린다.
##  - 던진 리코더는 **알아서 곧바로 돌아온다**(`ThrownRecorder`가 혼자 한다). 돌아오는 길에 한 번 더 때리고,
##    **2타를 치기도 전에 손에 들어와 있다** — 그래서 2타부터는 두 악기가 다 손에 있다.
##  - 2타·3타는 아무것도 안 한다(false) — 평소처럼 몸으로 친다.
##
## **궁(쌍 악기)을 안 썼으면 통째로 빠진다** — 그때는 리코더가 손에 없으니 던질 것도 없고,
## 콤보도 평소 3타 그대로다

## 리코더를 던지는 타 번호(0부터). 기본 0 = 1타
@export var throw_step: int = 0
## 리코더를 **타에 맞춰 불러들이고 싶을 때** 쓰는 타 번호. **-1이면 안 쓴다**(기본) —
## 지금은 리코더가 끝까지 날아가면 스스로 돌아오므로 여기서 부를 일이 없다
@export var return_step: int = -1
## **이 타부터는 리코더가 무조건 손에 있어야 한다**(기본 2 = 3타). 그때까지 안 돌아왔으면
## 그 자리에서 거둬들인다 — 리코더 속도를 넉넉히 잡아 뒀으니 평소엔 쓸 일이 없는 안전장치다.
## -1이면 안 쓴다
@export var catch_step: int = 2
## 던져지는 리코더 장면
@export var recorder_scene: PackedScene
## 던지는 자리 — 캐릭터 중심에서 얼마나 떨어진 곳에서 손을 떠나는지(x는 보는 방향으로 자동 반전)
@export var throw_offset: Vector2 = Vector2(26, -14)

## 지금 날아가 있는 리코더(없으면 null)
var _flying: ThrownRecorder = null

## 콤보가 매 타의 판정 순간에 부른다. true면 "이 타는 내가 맡는다"는 뜻이라
## 콤보는 몸 판정을 안 켜고 `report_external_hit()`이 올 때까지 기다린다
func on_combo_strike(fighter: Fighter, step: int, src: Hitbox) -> bool:
	if not is_instance_valid(fighter) or recorder_scene == null:
		return false
	# 손에 리코더가 없으면(궁을 안 썼으면) 평소 평타 그대로 간다
	if not _is_armed(fighter):
		return false
	if step == throw_step:
		return _throw(fighter, src)
	if return_step >= 0 and step == return_step:
		return _recall(src)
	# 아직 안 돌아왔으면 여기서 거둬들인다 — 이 타부터는 두 악기가 다 손에 있어야 한다
	if catch_step >= 0 and step >= catch_step and is_instance_valid(_flying):
		_flying.catch_now()
	return false

## 왼손에 리코더를 들고 있는지(= 궁을 쓴 상태인지) 몸에게 물어본다
func _is_armed(fighter: Fighter) -> bool:
	var visual: Node = fighter.get_node_or_null("Visual")
	return visual != null and "held_item_l_armed" in visual and bool(visual.held_item_l_armed)

func _throw(fighter: Fighter, src: Hitbox) -> bool:
	# 이미 날아가 있으면 또 던질 게 없다 — 그 타는 평소대로 몸으로 친다
	if is_instance_valid(_flying):
		return false
	var node: Node = recorder_scene.instantiate()
	_flying = node as ThrownRecorder
	if _flying == null:
		node.queue_free()
		return false
	# 맵(캐릭터의 부모)에 붙인다 — 캐릭터 자식으로 달면 같이 움직여서 날아가는 게 안 보인다
	var parent: Node = fighter.get_parent()
	if parent == null:
		_flying.queue_free()
		_flying = null
		return false
	parent.add_child(_flying)
	var from: Vector2 = fighter.global_position + Vector2(throw_offset.x * fighter.facing, throw_offset.y)
	_flying.launch(fighter, from, fighter.facing, get_parent(), src)
	_set_hand_thrown(fighter, true)
	return true

func _recall(src: Hitbox) -> bool:
	if not is_instance_valid(_flying) or not _flying.is_out():
		return false
	_flying.recall(src)
	return true

## 몸에게 "왼손 물건은 지금 던져서 없다"고 알린다 — 손에 그려진 리코더가 사라진다.
## 다시 켜는 건 리코더 쪽(`ThrownRecorder._restore_hand`)이 돌아오면서 한다
func _set_hand_thrown(fighter: Fighter, on: bool) -> void:
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual and "held_item_l_thrown" in visual:
		visual.held_item_l_thrown = on
