class_name KidRushSkill
extends Skill

## **아이 내려놓기** — 층간소음 빌런 2번 스킬. 품에 안고 있던 아이를 바닥에 내려놓으면
## 아이가 **앞으로 쿵쿵 달려갔다가 돌아와** 다시 품에 안긴다.
##
## 달리는 동안 몸에 닿는 상대는 밀려나며 피해를 입는다. 발이 땅에 닿을 때마다 화면이 울린다.
##
## 아이가 나가 있는 동안에는 **품에 아이가 없다** — 1번 스킬(아이 비명)도 그동안 못 쓴다.
## 아이는 알아서 돌아오므로 따로 거둬들일 필요가 없고, 라운드가 끝나면 그냥 사라진다

## 내려놓을 아이 장면(`RunningKid.tscn`)
@export var kid_scene: PackedScene
## 내려놓는 자리 — 캐릭터 중심에서 얼마나 떨어진 곳인지(x는 보는 방향으로 자동 반전).
## **평소에는 안 쓴다** — 옆에 걸어다니던 아이가 **서 있던 그 자리에서** 그대로 출발하기 때문이다.
## 몸(BodyRig)에 아이가 없는 캐릭터에서만 이 값이 쓰인다
@export var drop_offset: Vector2 = Vector2(22, 18)
## 아이가 서 있던 자리를 찾을 때 기준으로 삼는 조각 이름. 보통 몸통이면 된다
@export var kid_anchor: String = "KidBody"
## 부딪힌 상대가 받는 피해와 밀려나는 힘.
## ⚠️ **y는 작게 둔다.** 몸으로 들이받을 때 크게 띄우면 그 뒤 걸음의 충격파가 전부 빗나가서
## "쿵쿵쿵 → 데미지데미지데미지"가 끊긴다(실측: -150이면 상대가 50px까지 떠올랐다)
@export var damage: int = 7
@export var knockback: Vector2 = Vector2(150, -30)
## 품에 아이가 없으면(이미 내려놨으면) 못 쓰게 할지
@export var needs_kid: bool = true
## **아이가 나가 있는 동안 엄마를 제자리에 묶을지.** 켜면 걷기·점프·대시·방어가 다 막힌다 —
## 서서 손뼉만 치고 있는 그림이 된다. 아이가 돌아오면 저절로 풀린다
@export var locks_movement: bool = true

## 지금 나가 있는 아이(없으면 null)
var _kid: RunningKid = null
## 지금 엄마의 이동을 내가 붙잡고 있는지
var _locked: bool = false

func _execute(fighter: Fighter) -> void:
	if not is_instance_valid(fighter) or kid_scene == null:
		return
	if is_instance_valid(_kid):
		return   # 이미 나가 있으면 내려놓을 아이가 없다
	var parent: Node = fighter.get_parent()
	if parent == null:
		return
	var node: Node = kid_scene.instantiate()
	_kid = node as RunningKid
	if _kid == null:
		node.queue_free()
		return
	# 맵에 붙인다 — 엄마의 자식으로 달면 같이 움직여서 달려가는 게 안 보인다
	parent.add_child(_kid)
	var at: Vector2 = _kid_home(fighter)
	_kid.drop(fighter, at, fighter.facing,
		fighter.compute_damage(damage),
		Vector2(knockback.x * fighter.facing, knockback.y))
	_set_carrying(fighter, false)
	_lock(fighter)
	# 박수는 여기서 바로 안 친다 — **아이가 첫 발을 땅에 디디는 순간**(`RunningKid._stomp`)에 시작한다.
	# 내려놓자마자 치면 아직 준비 자세로 서 있는데 손뼉부터 쳐서 박자가 안 맞는다

## **옆에 걸어다니던 아이가 서 있던 자리**를 월드 좌표로 돌려준다.
## 그 자리에서 그대로 달려 나가야 "순간이동했다"가 안 된다(2026-10-04 사용자 요청).
## 몸에 아이가 없으면 예전처럼 `drop_offset`을 쓴다
func _kid_home(fighter: Fighter) -> Vector2:
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual:
		var carry: Node2D = visual.get_node_or_null("Carry") as Node2D
		if carry:
			var anchor: Node2D = carry.get_node_or_null(kid_anchor) as Node2D
			if anchor:
				# 몸통 조각 자리에서 조금 올린다 — 달리는 아이는 뿌리가 몸통보다 조금 위에 있다
				return anchor.global_position - Vector2(0.0, 4.0)
			return carry.global_position
	return fighter.global_position + Vector2(drop_offset.x * fighter.facing, drop_offset.y)

## 아이가 돌아왔으면 묶어 둔 이동을 풀어 준다. 아이는 스스로 돌아오므로 여기서 지켜본다
func _process(delta: float) -> void:
	super._process(delta)
	if not _locked:
		return
	if not is_instance_valid(_kid) or not _kid.is_out():
		_release()

## `Fighter.movement_override` 인터페이스 — 이 동안 가로 속도는 0이다(제자리에 선다)
func get_move_velocity_x() -> float:
	return 0.0

## `Fighter.movement_override` 인터페이스 — 매 물리 프레임 끝에 불린다. 할 일이 없다
func after_physics(_fighter: Fighter, _delta: float) -> void:
	pass

## 이 동안은 점프도 막는다
func blocks_jump() -> bool:
	return true

## 엄마를 제자리에 묶는다
func _lock(fighter: Fighter) -> void:
	if not locks_movement or _locked or not is_instance_valid(fighter):
		return
	if fighter.movement_override != null:
		return   # 다른 기술이 이미 이동을 잡고 있으면 건드리지 않는다
	fighter.movement_override = self
	_locked = true

## 묶어 둔 이동을 돌려준다. **내가 잡고 있을 때만** 푼다 — 그 사이 다른 기술이 잡았으면 그대로 둔다
func _release() -> void:
	_locked = false
	var fighter := get_parent() as Fighter
	if is_instance_valid(fighter) and fighter.movement_override == self:
		fighter.movement_override = null

## 쿨타임이 끝나도 **품에 아이가 있어야** 쓸 수 있다.
## 아이가 밖에 나가 있는데 또 눌러서 쿨만 날리는 걸 막는다
func can_use() -> bool:
	if not super.can_use():
		return false
	if is_instance_valid(_kid) and _kid.is_out():
		return false
	if not needs_kid:
		return true
	return _has_kid()

## 품에 아이가 있는지 몸(BodyRig)에게 물어본다. 리그에 그 기능이 없으면 "있다"로 친다
func _has_kid() -> bool:
	var fighter := get_parent() as Fighter
	if fighter == null:
		return true
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual == null or not ("carrying" in visual):
		return true
	return bool(visual.carrying)

## 몸에게 "지금 안고 있는지"를 알려 준다 — 품의 아이 그림이 보였다 숨었다 한다.
## 다시 켜는 건 아이 쪽(`RunningKid._restore_carry`)이 돌아오면서 한다
func _set_carrying(fighter: Fighter, on: bool) -> void:
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual and "carrying" in visual:
		visual.carrying = on

## 라운드가 끝날 때 아이가 밖에 남아 있으면 정리하고, 묶어 둔 이동도 돌려준다
func _exit_tree() -> void:
	if is_instance_valid(_kid):
		_kid.catch_now()
	_release()
