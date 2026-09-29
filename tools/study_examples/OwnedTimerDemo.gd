extends SceneTree

## 포트폴리오 예제 — 주인이 사라지면 같이 사라지는 타이머 (Timers.gd).
##
## 실행 방법 (프로젝트 루트에서):
##   <Godot 실행 파일> --headless --path . --script res://tools/study_examples/OwnedTimerDemo.gd
##
## 실제로 겪은 버그: 대전 도중 "다시하기"로 씬이 통째로 정리되면, get_tree().create_timer()로
## 예약해 둔 콜백이 그대로 살아남아 이미 사라진 노드를 건드리다가
## "Lambda capture ... was freed" 에러가 났다. create_timer()는 SceneTree에 속해서 노드보다 오래 산다.
##
## 해결: 타이머를 그 노드의 "자식"으로 만든다. 부모가 사라지면 자식 타이머도 같이 사라지므로
## 콜백이 아예 실행되지 않는다. 여러 파일이 각자 들고 있던 이 코드를 Timers.after() 한 곳으로 모았다.
##
## 아래를 실행하면 옛 방식에서 "Lambda capture ... was freed" 에러가 한 줄 찍힌다 — 일부러 재현한 것이다.

const OwnedTimers := preload("res://Timers.gd")

var _elapsed := 0.0
var _owners_freed := false
var _old_fired := false
var _new_fired := false
var _old_owner: Node
var _new_owner: Node


func _initialize() -> void:
	_old_owner = Node.new()
	_old_owner.name = "OldOwner"
	root.add_child(_old_owner)
	_new_owner = Node.new()
	_new_owner.name = "NewOwner"
	root.add_child(_new_owner)

	# --- 옛 방식: 트리에 매인 타이머 — 주인이 사라져도 콜백은 그대로 불린다 ---
	var victim := _old_owner
	create_timer(0.3).timeout.connect(func() -> void:
		_old_fired = true
		print("[0.30초] 옛 방식 콜백 실행됨 — 주인은 살아 있나? ", is_instance_valid(victim)))

	# --- 새 방식: 주인의 자식 타이머 — 주인과 운명을 같이한다 ---
	OwnedTimers.after(_new_owner, 0.3, func() -> void:
		_new_fired = true
		print("[0.30초] 새 방식 콜백 실행됨"))

	print("[0.00초] 두 방식으로 0.3초 뒤 콜백 예약")


func _process(delta: float) -> bool:
	_elapsed += delta
	if not _owners_freed and _elapsed >= 0.1:
		_owners_freed = true
		print("[0.10초] 씬 정리! (다시하기를 눌렀다고 가정) 두 주인 노드 삭제")
		_old_owner.queue_free()
		_new_owner.queue_free()
	if _elapsed >= 0.5:
		print("\n=== 결과 ===")
		print("옛 방식(get_tree().create_timer): 콜백 실행됨 = ", _old_fired, "  <- 사라진 노드를 건드림(버그)")
		print("새 방식(Timers.after, 자식 Timer): 콜백 실행됨 = ", _new_fired, "  <- 주인과 함께 사라짐(정상)")
		print("\n왜 is_instance_valid() 검사로 막지 않았나?")
		print("- 콜백마다 검사를 넣어야 하고, 하나라도 빠뜨리면 같은 버그가 다시 난다.")
		print("- 자식 Timer 방식은 구조로 막기 때문에 콜백 안에 방어 코드가 필요 없다.")
		return true
	return false
