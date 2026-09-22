extends SceneTree

## 공부용 예제 — ui/SkillClashPopup.gd의 연타 밀당(_tick_mash/_push/_decide_by_presses)을
## 그대로 옮겨와 몬테카를로 시뮬레이션으로 검증하는 스크립트. 화면·리그 연출 부분만 뺐다.
##
## 실행 방법 (프로젝트 루트에서):
##   <Godot 실행 파일> --headless --path . --script res://tools/study_examples/ClashMashSimulation.gd
##
## CLAUDE.md 기록: "사람 초당 8타 vs AI -> 98%가 약 1.6초에 끝까지 민다 / 9타 -> 100%, 1.1초 /
## 7타 -> 16%만 끝까지" 같은 수치가 어떻게 나왔는지 직접 재현해서 검증해본다.
##
## 핵심은 "감으로 값을 정하지 않고, 반복 실행으로 확률을 통계로 확인한다"는 방법론이다.

const PUSH_PER_PRESS := 0.09       # ui/SkillClashPopup.gd 실제 기본값
const BALANCE_RECENTER := 0.03     # 손을 놓으면 가운데로 되돌아오는 속도
const MASH_DURATION := 2.0         # 제한시간(초)
const AI_INTERVAL_MIN := 0.16      # AI 연타 간격(최소)
const AI_INTERVAL_MAX := 0.24      # AI 연타 간격(최대)
const DT := 1.0 / 60.0             # 60fps 기준 한 프레임
const TRIALS := 4000               # CLAUDE.md와 같은 판수


## 사람 쪽 연타를 "초당 N타"로 고정한 뒤, AI(SkillClashPopup 기본값)와 겨뤄서
## 한 판을 시뮬레이션한다. 반환값: 사람이 이겼는지, 걸린 시간(초)
func run_trial(human_presses_per_sec: float) -> Dictionary:
	var human_interval := 1.0 / human_presses_per_sec
	var human_wait := human_interval
	var ai_wait := randf_range(AI_INTERVAL_MIN, AI_INTERVAL_MAX)
	var balance := 0.5
	var presses_human := 0
	var presses_ai := 0
	var elapsed := 0.0
	var decided_early := false
	var human_won := false

	while elapsed < MASH_DURATION and not decided_early:
		elapsed += DT

		# 사람 쪽 연타 (SkillClashPopup._push와 동일한 규칙)
		human_wait -= DT
		if human_wait <= 0.0:
			presses_human += 1
			balance = clampf(balance + PUSH_PER_PRESS, 0.0, 1.0)
			human_wait += human_interval
			if balance >= 1.0:
				human_won = true
				decided_early = true

		# AI 쪽 연타
		if not decided_early:
			ai_wait -= DT
			if ai_wait <= 0.0:
				presses_ai += 1
				balance = clampf(balance - PUSH_PER_PRESS, 0.0, 1.0)
				ai_wait = randf_range(AI_INTERVAL_MIN, AI_INTERVAL_MAX)
				if balance <= 0.0:
					human_won = false
					decided_early = true

		# 손을 놓은 쪽으로는 안 밀리게, 매 프레임 가운데로 살짝 되돌아온다
		if not decided_early:
			balance = move_toward(balance, 0.5, BALANCE_RECENTER * DT)

	if not decided_early:
		# 시간 종료 -> 더 많이 누른 쪽이 승리 (SkillClashPopup._decide_by_presses와 동일)
		if presses_human != presses_ai:
			human_won = presses_human > presses_ai
		elif not is_equal_approx(balance, 0.5):
			human_won = balance > 0.5
		else:
			human_won = randf() < 0.5

	# decided_early = 1.0까지 완전히 밀어붙여서 즉시 끝난 경우 (CLAUDE.md의 "끝까지 민다")
	# 그렇지 않으면 시간 종료 후 "누른 횟수"로 판정된 경우다 — 이 둘을 구분해야
	# CLAUDE.md에 적힌 "7타 -> 16%만 끝까지, 나머지는 시간 종료 때 앞서서 승리"를 재현할 수 있다
	return {"won": human_won, "time": elapsed, "pushed_all_the_way": decided_early and human_won}


func _init() -> void:
	print("=== 클래시 미니게임 몬테카를로 시뮬레이션 (%d판씩) ===\n" % TRIALS)
	for rate in [6.0, 7.0, 8.0, 9.0, 10.0]:
		var wins := 0
		var pushed_all_the_way := 0
		var total_time_win := 0.0
		for i in range(TRIALS):
			var result := run_trial(rate)
			if result["won"]:
				wins += 1
				total_time_win += result["time"]
			if result["pushed_all_the_way"]:
				pushed_all_the_way += 1
		var win_rate := float(wins) / TRIALS * 100.0
		var early_rate := float(pushed_all_the_way) / TRIALS * 100.0
		var avg_time: float = (total_time_win / wins) if wins > 0 else 0.0
		print("사람 초당 %.0f타 -> 전체 승률 %.1f%% (그중 끝까지 밀어붙인 비율 %.1f%%, 이겼을 때 평균 %.2f초)" % [rate, win_rate, early_rate, avg_time])

	print("\nCLAUDE.md 기록과 비교해보자 (완전히 같은 숫자가 아니어도 괜찮다):")
	print("  '8타 -> 98%가 약 1.6초에 끝까지 민다' / '7타 -> 16%만 끝까지, 나머지는 시간 종료 때 앞서서 승리'")
	print("  -> 즉 7타에서도 '전체 승률'은 여전히 높을 수 있다 — '끝까지 밀어붙이는 비율'과")
	print("     '최종 승률'은 다른 지표라는 게 이 시뮬레이션의 핵심 교훈이다.")
	print("중요한 건 숫자를 외우는 게 아니라, '반복 실행으로 확률을 검증했다'는 접근 자체다.")
	print("\n직접 해볼 것: PUSH_PER_PRESS를 0.035로 낮춰서 다시 돌려보고,")
	print("CLAUDE.md에 적힌 '초당 10타로 쳐도 0%만 끝까지 민다'는 옛날 버그가 재현되는지 확인해보자.")
	quit()
