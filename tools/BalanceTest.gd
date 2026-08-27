extends Node

## 캐릭터 조합을 규칙 기반 AI(AIController)끼리 자동으로 여러 판 맞붙여서 승률을 집계하는
## 밸런스 테스트 도구. Claude API는 쓰지 않는다(비용 없이 빠르게 많은 판을 돌리기 위함).
## 실제 맵 대신 벽·링아웃 없는 평평한 바닥 하나만 쓰고, RoundStart 카운트다운이나
## MatchResult 화면 없이 바로 대전을 시작하고 바로 다음 대전으로 넘어간다.
## 실행: Godot --headless --path <프로젝트> res://tools/BalanceTest.tscn --fixed-fps 60 --quit-after 999

## 매치업(캐릭터 조합)마다 몇 판씩 반복할지
const MATCHES_PER_PAIR := 5
## 한 판이 이 시간(게임 내 초)을 넘기면 무승부로 처리한다 (무한 대전 방지)
const MATCH_TIMEOUT := 30.0

var _wins: Dictionary = {}  # {character_name: win_count}
var _matches_played: Dictionary = {}  # {character_name: total_count}
var _matchup_log: Array[String] = []

func _ready() -> void:
	await _run_all_matchups()
	_print_report()
	get_tree().quit()

func _run_all_matchups() -> void:
	var names := GameState.CHARACTERS.keys()
	for i in range(names.size()):
		for j in range(i + 1, names.size()):
			var name_a: String = names[i]
			var name_b: String = names[j]
			for m in range(MATCHES_PER_PAIR):
				var winner := await _run_one_match(name_a, name_b)
				_matchup_log.append("%s vs %s (%d/%d) -> %s" % [
					name_a, name_b, m + 1, MATCHES_PER_PAIR,
					winner if winner != "" else "무승부",
				])
				print(_matchup_log[-1])

## 두 캐릭터를 한 판 붙이고 승자 이름을 반환한다 (무승부면 빈 문자열)
func _run_one_match(name_a: String, name_b: String) -> String:
	var arena := _make_floor()
	add_child(arena)

	var fighter_a := _spawn_fighter(GameState.CHARACTERS[name_a], Vector2(-150, 0))
	var fighter_b := _spawn_fighter(GameState.CHARACTERS[name_b], Vector2(150, 0))
	fighter_a.add_child(AIController.new())
	fighter_b.add_child(AIController.new())
	# Fighter._ready()가 "fighters" 그룹에 등록될 때까지 한 프레임 기다린다 (Stage.gd와 동일한 이유)
	await get_tree().process_frame

	var elapsed := 0.0
	var winner: String = ""
	var draw := false
	while elapsed < MATCH_TIMEOUT:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		var a_dead := fighter_a.current_hp <= 0
		var b_dead := fighter_b.current_hp <= 0
		if a_dead and b_dead:
			draw = true
			break
		elif a_dead:
			winner = name_b
			break
		elif b_dead:
			winner = name_a
			break

	_record_result(name_a, name_b, winner if not draw else "")

	fighter_a.queue_free()
	fighter_b.queue_free()
	arena.queue_free()
	await get_tree().process_frame
	return winner

func _record_result(name_a: String, name_b: String, winner: String) -> void:
	_matches_played[name_a] = _matches_played.get(name_a, 0) + 1
	_matches_played[name_b] = _matches_played.get(name_b, 0) + 1
	if winner != "":
		_wins[winner] = _wins.get(winner, 0) + 1

func _spawn_fighter(scene_path: String, spawn_pos: Vector2) -> Fighter:
	var fighter: Fighter = load(scene_path).instantiate()
	add_child(fighter)
	fighter.global_position = spawn_pos
	return fighter

## 벽도 링아웃도 없는 평평한 바닥 하나만 있는 테스트용 최소 아레나
func _make_floor() -> StaticBody2D:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2000, 40)
	shape.shape = rect
	body.add_child(shape)
	body.position = Vector2(0, 100)
	return body

func _print_report() -> void:
	print("\n===== 밸런스 테스트 결과 =====")
	print("-- 캐릭터별 종합 승률 --")
	for name in GameState.CHARACTERS.keys():
		var played: int = _matches_played.get(name, 0)
		var won: int = _wins.get(name, 0)
		var rate := (100.0 * won / played) if played > 0 else 0.0
		print("%s: %d전 %d승 (%.1f%%)" % [name, played, won, rate])
