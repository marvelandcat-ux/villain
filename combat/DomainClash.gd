class_name DomainClash
extends RefCounted

## **영역 싸움** — 남의 영역에 갇힌 쪽이 자기 영역 궁을 쓰면 벌어지는 다툼(2026-10-07 사용자 설계).
##
## | 결과 | 어떻게 되는가 |
## |---|---|
## | **영역 주인이 이김** | 영역이 그대로 유지된다. **미니게임 동안 시간도 안 흐른다** |
## | **도전자가 이김** | 주인의 영역이 깨지고 **도전자의 영역이 전개된다** |
##
## 어느 쪽이 져도 **체력은 안 깎인다**(2026-10-07 사용자: 영역을 잃는 것 자체가 벌이다).
## 먼저 전개한 쪽은 "상대 궁을 아무것도 못 하게 하고 뺏는" 이득을 이미 가져간 셈이다.
##
## ⚠️ **미니게임은 새로 만들지 않고 `SkillClashPopup`을 그대로 쓴다**(2026-10-07 사용자: "기존 거 재탕").
## 같은 슬롯 동시 사용 때 뜨는 그 연타 대결이다 — 거는 조건만 다르다.
##
## ⚠️ **시간이 안 흐르는 건 따로 구현하지 않았다.** 팝업이 `get_tree().paused = true`로 화면을 멈추고,
## 영역 궁들은 `process_mode`를 안 건드려서 `_process`가 통째로 쉰다 — 남은 시간(`_left`)이 저절로 안 준다.
## 영역 궁에 `PROCESS_MODE_ALWAYS`를 주면 이 약속이 깨진다

## 지금 **돌고 있는** 영역 궁이 들어가는 그룹. 영역 궁이 스스로 들고 난다
const GROUP := &"running_domain"

## 그 스킬이 영역 궁인지 — 영역 궁은 `break_domain()`을 들고 있다
static func is_domain(skill: Node) -> bool:
	return skill != null and skill.has_method("break_domain")

## `challenger`를 가두고 있는 **남의 영역**(없으면 null)
static func running_enemy(tree: SceneTree, challenger: Fighter) -> Node:
	if tree == null or not is_instance_valid(challenger):
		return null
	for node in tree.get_nodes_in_group(GROUP):
		if not node.has_method("domain_owner"):
			continue
		var owner: Fighter = node.domain_owner()
		if is_instance_valid(owner) and owner != challenger:
			return node
	return null

## 영역을 걸고 한 판 붙는다. **도전자가 이기면 true.**
##
## 팝업이 화면을 멈추고 돌리므로 이 함수는 `await`해야 한다
static func fight(host: Node, challenger: Fighter) -> bool:
	if not is_instance_valid(host) or not is_instance_valid(challenger):
		return false
	var owner: Fighter = host.domain_owner()
	var tree: SceneTree = host.get_tree()
	if not is_instance_valid(owner) or tree == null:
		return false
	var popup: SkillClashPopup = load("res://ui/SkillClashPopup.tscn").instantiate()
	# **데미지 없음** — 숫자가 뜨면 체력이 깎인 줄 안다
	popup.punish_damage_number = false
	host.add_child(popup)
	# ⚠️ **start() 보다 먼저 멈춘다.** `start()`가 몇 프레임 쉬었다 오기 때문에,
	# 뒤에 멈추면 그 사이 영역 남은 시간이 0.2초쯤 깎인다(2026-10-07 실측)
	tree.paused = true
	# A = 영역 주인, B = 도전자
	popup.start(owner, challenger, "ultimate")
	var owner_won: bool = await popup.finished
	tree.paused = false
	# ⚠️ `apply_clash_damage()`를 **일부러 안 부른다** — 그게 체력을 깎는 곳이다
	popup.queue_free()
	return not owner_won
