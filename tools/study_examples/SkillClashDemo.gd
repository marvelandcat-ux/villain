extends SceneTree

## 포트폴리오 예제 — 스킬 베이스 클래스(skills/Skill.gd)와 동시 사용 판정(combat/SkillClashManager.gd).
##
## 실행 방법 (프로젝트 루트에서):
##   <Godot 실행 파일> --headless --path . --script res://tools/study_examples/SkillClashDemo.gd
##
## 보여주는 것 두 가지:
## 1) 쿨타임·사용 가능 확인은 부모(Skill)에 한 번만 짜고, 자식 스킬은 _execute()만 오버라이드한다
## 2) 두 사람이 match_window(0.15초) 안에 "같은 슬롯"을 쓰면 클래시 — 이긴 쪽만 발동, 진 쪽은 쿨타임만 소모
##
## 실제 코드는 Timer 노드와 연타 팝업(SkillClashPopup)을 쓰지만, 여기서는 시간을 직접 흘려서(tick)
## 판정 흐름만 뽑아냈다. 연타 미니게임 결과는 "누른 횟수 비교"로 대신한다.

const DT := 1.0 / 60.0


## --- 1) 모든 스킬의 공용 베이스 (skills/Skill.gd 단순화) ---
class Skill:
	var skill_name := ""
	var cooldown := 1.0
	var cooldown_left := 0.0

	func can_use() -> bool:
		return cooldown_left <= 0.0

	## 쿨타임 확인·시작은 여기서 한 번만 — 자식 스킬은 신경 쓸 필요가 없다
	func use(user: String) -> void:
		if not can_use():
			return
		cooldown_left = cooldown
		_execute(user)

	## 클래시에서 졌을 때 — 효과는 안 나가고 쿨타임만 소모된다
	func cancel_use(user: String) -> void:
		cooldown_left = cooldown
		print("    [%s] %s 불발! (쿨타임 %.0f초만 소모)" % [user, skill_name, cooldown])

	func tick(delta: float) -> void:
		cooldown_left = maxf(cooldown_left - delta, 0.0)

	## 자식 클래스가 실제 효과를 구현하는 곳
	func _execute(_user: String) -> void:
		pass


## --- 2) 자식 스킬: _execute()만 새로 쓴다 ---
class DashSkill extends Skill:
	func _init() -> void:
		skill_name = "자전거 돌진"
		cooldown = 6.0

	func _execute(user: String) -> void:
		print("    [%s] 자전거 돌진 발동! 앞으로 224px 달려나간다" % user)


class ShoulderChargeSkill extends Skill:
	func _init() -> void:
		skill_name = "어깨 들이박기"
		cooldown = 6.0

	func _execute(user: String) -> void:
		print("    [%s] 어깨 들이박기 발동! 맞으면 1초 기절" % user)


## --- 3) 동시 사용 판정 (combat/SkillClashManager.gd 단순화) ---
class ClashManager:
	var match_window := 0.15
	## 슬롯 이름 -> 먼저 도착해서 기다리는 요청 하나 {user, skill, wait}
	var _pending := {}
	## 연타 미니게임 대신 승자를 정하는 함수 (a가 이기면 true)
	var decide_winner: Callable

	func request(user: String, slot: String, skill: Skill) -> void:
		if not skill.can_use():
			print("    [%s] %s: 쿨타임 %.1f초 남음 -> 무시" % [user, skill.skill_name, skill.cooldown_left])
			return
		if _pending.has(slot):
			var waiting: Dictionary = _pending[slot]
			if waiting["user"] == user:
				print("    [%s] 대기 중에 또 누름 -> 중복 입력 무시" % user)
				return
			# 상대가 같은 슬롯으로 이미 기다리고 있었다 -> 클래시
			_pending.erase(slot)
			_clash(waiting["user"], waiting["skill"], user, skill)
			return
		# 먼저 온 쪽은 match_window 동안 상대를 기다린다
		_pending[slot] = {"user": user, "skill": skill, "wait": match_window}

	func tick(delta: float) -> void:
		for slot in _pending.keys():
			var req: Dictionary = _pending[slot]
			req["wait"] -= delta
			if req["wait"] <= 0.0:
				# 상대가 안 왔다 -> 평소처럼 발동
				_pending.erase(slot)
				req["skill"].use(req["user"])

	func _clash(user_a: String, skill_a: Skill, user_b: String, skill_b: Skill) -> void:
		print("    !! 클래시 발생: %s(%s) vs %s(%s) -> 연타 미니게임" % [user_a, skill_a.skill_name, user_b, skill_b.skill_name])
		var a_won: bool = decide_winner.call(user_a, user_b)
		var winner := user_a if a_won else user_b
		print("    !! %s 승리" % winner)
		if a_won:
			skill_a.use(user_a)
			skill_b.cancel_use(user_b)
		else:
			skill_b.use(user_b)
			skill_a.cancel_use(user_a)


var _manager := ClashManager.new()
var _p1_skill := DashSkill.new()
var _p2_skill := ShoulderChargeSkill.new()
var _clock := 0.0


func _advance(seconds: float) -> void:
	var steps := int(round(seconds / DT))
	for i in range(steps):
		_clock += DT
		_manager.tick(DT)
		_p1_skill.tick(DT)
		_p2_skill.tick(DT)


func _say(text: String) -> void:
	print("[%.2f초] %s" % [_clock, text])


func _init() -> void:
	# 연타 미니게임 결과 대신: P1이 12번, P2가 9번 눌렀다고 치고 많이 누른 쪽 승리
	_manager.decide_winner = func(_a: String, _b: String) -> bool: return 12 > 9

	print("=== 1. 혼자 쓰면: 0.15초 기다렸다가 평소처럼 발동 ===")
	_say("P1 스킬1 입력")
	_manager.request("P1", "skill_1", _p1_skill)
	_advance(0.2)

	print("\n=== 2. 둘이 0.15초 안에 같은 슬롯을 쓰면: 클래시 ===")
	_advance(7.0)
	_say("P1 스킬1 입력")
	_manager.request("P1", "skill_1", _p1_skill)
	_advance(0.1)
	_say("P2 스킬1 입력 (0.1초 뒤 — 판정 시간 안)")
	_manager.request("P2", "skill_1", _p2_skill)

	print("\n=== 3. 진 쪽은 쿨타임이 돌고 있다 ===")
	_advance(1.0)
	_say("P2 스킬1 다시 입력")
	_manager.request("P2", "skill_1", _p2_skill)

	print("\n=== 4. 같은 사람이 대기 중에 또 누르면 무시 ===")
	_advance(6.0)
	_say("P1 스킬1 입력")
	_manager.request("P1", "skill_1", _p1_skill)
	_advance(0.05)
	_say("P1 스킬1 한 번 더")
	_manager.request("P1", "skill_1", _p1_skill)
	_advance(0.2)

	print("\n핵심:")
	print("- 쿨타임 코드는 Skill 한 곳에만 있다. 새 스킬은 _execute()만 쓰면 된다 (실제 게임엔 스킬 20개 이상).")
	print("- 클래시는 '어떤 스킬이냐'가 아니라 '어느 슬롯이냐'로 판정한다. 그래서 캐릭터가 달라도 동작한다.")
	print("- 기본공격은 일부러 이 판정을 안 거친다(Fighter.use_basic_attack). 자주 쓰는 잽까지 걸리면")
	print("  마주칠 때마다 화면이 멈춰서 게임이 끊기기 때문이다 — '넣지 않은 이유'도 설계다.")
	quit()
