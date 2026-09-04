class_name SkillClashManager
extends Node

## 두 Fighter가 같은 스킬 슬롯(기본공격/스킬1/스킬2/궁극기)을 짧은 시간 안에 함께 쓰면
## "동시 사용"으로 보고 연타 미니게임(SkillClashPopup)을 벌인다. 이긴 쪽만 실제 효과가 나가고
## 진 쪽은 Skill.cancel_use()로 쿨타임만 소모된 채 취소된다.
## Stage.gd가 _ready()에서 add_child로 심어두고, Fighter는 "skill_clash_manager" 그룹으로 찾아 쓴다.
## (훈련장처럼 상대가 없는 씬에는 심지 않으므로, 그런 씬의 Fighter는 클래시 없이 기존처럼 바로 발동한다)

## 이 시간(초) 안에 같은 슬롯을 상대와 함께 쓰면 "동시 사용"으로 본다.
## 클래시가 안 나는 경우에도 이 시간만큼은 실제 발동이 늦어진다 — 스킬 예비동작(windup)과 같은 종류의 지연이라 짧게 잡는다
@export var match_window: float = 0.15

class PendingRequest:
	var fighter: Fighter
	var on_win: Callable
	var on_lose: Callable
	var timer: Timer

## slot_id(String) -> PendingRequest — 슬롯 하나당 먼저 도착한 요청 하나만 대기시킨다
var _pending: Dictionary = {}

func _ready() -> void:
	add_to_group("skill_clash_manager")

## fighter가 slot_id 슬롯의 스킬을 쓰려고 한다.
## 상대가 같은 슬롯으로 이미 대기 중이면 즉시 클래시가 벌어지고, 아니면 match_window 동안 대기했다가
## 그때까지 상대가 안 오면 on_win이 실행되어 평소처럼 스킬이 나간다.
## on_win: 실제로 스킬을 발동시키는 Callable(인자 없음). on_lose: 클래시에서 졌을 때 실행할 Callable
func request(fighter: Fighter, slot_id: String, on_win: Callable, on_lose: Callable) -> void:
	var existing: PendingRequest = _pending.get(slot_id)
	if existing and is_instance_valid(existing.fighter):
		if existing.fighter == fighter:
			return  # 같은 사람이 대기 중에 또 눌렀다 — 중복 입력은 무시
		existing.timer.stop()
		existing.timer.queue_free()
		_pending.erase(slot_id)
		_start_clash(slot_id, existing.fighter, existing.on_win, existing.on_lose, fighter, on_win, on_lose)
		return

	var req := PendingRequest.new()
	req.fighter = fighter
	req.on_win = on_win
	req.on_lose = on_lose
	var timer := Timer.new()
	timer.wait_time = match_window
	timer.one_shot = true
	add_child(timer)
	req.timer = timer
	timer.timeout.connect(func():
		_pending.erase(slot_id)
		timer.queue_free()
		on_win.call()
	)
	timer.start()
	_pending[slot_id] = req

## 클래시를 실제로 진행한다 — 화면을 멈추고 연타 미니게임을 띄운 뒤, 결과에 따라 승자는 on_win, 패자는 on_lose를 부른다
func _start_clash(slot_id: String, fighter_a: Fighter, on_win_a: Callable, on_lose_a: Callable,
		fighter_b: Fighter, on_win_b: Callable, on_lose_b: Callable) -> void:
	if not (is_instance_valid(fighter_a) and is_instance_valid(fighter_b)):
		return
	var popup: SkillClashPopup = load("res://ui/SkillClashPopup.tscn").instantiate()
	add_child(popup)
	get_tree().paused = true
	popup.start(fighter_a, fighter_b, slot_id)
	var a_won: bool = await popup.finished
	get_tree().paused = false
	popup.queue_free()
	if is_instance_valid(fighter_a):
		(on_win_a if a_won else on_lose_a).call()
	if is_instance_valid(fighter_b):
		(on_win_b if not a_won else on_lose_b).call()
