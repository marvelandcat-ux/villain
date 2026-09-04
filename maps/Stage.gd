class_name Stage
extends Node2D

## 모든 맵 씬의 공용 베이스. GameState에서 선택된 P1/P2 캐릭터를 스폰 지점에 생성하고,
## 컨트롤러를 붙이고, HUD를 연결하고, 승패를 판정한다. 새 맵은 바닥·벽·PlayerSpawn1/2·Camera2D·CombatHUD만
## 배치하면 이 스크립트가 나머지를 전부 처리한다

## 스테이지 좌우 폭 (플레이어 이동 가능 범위)
@export var stage_width: float = 960.0
## 이 값보다 아래로 떨어지면 링아웃으로 즉시 패배 처리 (벽이 없는 링아웃형 맵에서만 의미 있음)
@export var ring_out_y: float = 900.0

var _p1: Fighter
var _p2: Fighter
var _round_over: bool = false
## 이번 라운드 남은 시간 (GameState.time_limit_seconds가 0이면 시간 제한 없음)
var _round_time_left: float = 0.0
var _combat_hud: CombatHUD

func _ready() -> void:
	_round_time_left = GameState.time_limit_seconds
	# 궁극기 컷인 연출 (Fighter가 그룹으로 찾아 쓴다)
	add_child(load("res://ui/UltimateCutIn.tscn").instantiate())
	# 같은 스킬 슬롯을 동시에 쓰면 연타 미니게임(클래시)을 벌이는 매니저 (Fighter가 그룹으로 찾아 쓴다)
	add_child(SkillClashManager.new())
	_p1 = _spawn_fighter(GameState.p1_character_path, "PlayerSpawn1", false, 1)
	# 로컬 대전(pvp)은 P2도 사람이 직접 조작하고, 스토리 모드는 정해진 상대를 AI가 조작한다
	var p2_is_ai: bool = GameState.game_mode == "story"
	_p2 = _spawn_fighter(GameState.p2_character_path, "PlayerSpawn2", p2_is_ai, 2)

	# 스폰된 Fighter들의 _ready()가 끝날 때까지 한 프레임 기다렸다가 연결한다
	await get_tree().process_frame

	_combat_hud = get_node_or_null("CombatHUD")
	if _combat_hud:
		_combat_hud.setup(_p1, _p2)
		_combat_hud.update_round_info(GameState.p1_round_wins, GameState.p2_round_wins, _round_time_left)

	# "3, 2, 1, FIGHT!" 카운트다운이 끝날 때까지 양쪽 다 움직이거나 공격할 수 없게 막는다
	_freeze_controllers()
	var round_start: RoundStart = load("res://ui/RoundStart.tscn").instantiate()
	add_child(round_start)
	await round_start.finished
	_unfreeze_controllers()

## died 시그널에 즉시 반응하지 않고 매 프레임 HP를 직접 확인한다.
## 신호에 반응하면 같은 프레임에 양쪽이 동시에 쓰러져도 먼저 처리된 시그널 순서에 따라
## 이미 죽은 쪽이 승자로 판정되는 문제가 있어서, 그 프레임의 데미지가 전부 반영된 뒤 한 번에 판정한다
func _process(delta: float) -> void:
	if _round_over:
		return
	for f in [_p1, _p2]:
		if f and is_instance_valid(f) and f.global_position.y > ring_out_y:
			f.ring_out()
	if _p1.current_hp <= 0 or _p2.current_hp <= 0:
		var p1_dead: bool = _p1.current_hp <= 0
		var p2_dead: bool = _p2.current_hp <= 0
		if p1_dead and p2_dead:
			_end_round(false, true)
		else:
			_end_round(not p1_dead, false)
		return
	if GameState.time_limit_seconds > 0:
		_round_time_left -= delta
		if _combat_hud:
			_combat_hud.update_round_info(GameState.p1_round_wins, GameState.p2_round_wins, _round_time_left)
		if _round_time_left <= 0.0:
			# 시간 초과 — 그 순간 체력이 더 많은 쪽이 라운드 승리 (동률이면 무승부)
			if _p1.current_hp > _p2.current_hp:
				_end_round(true, false)
			elif _p2.current_hp > _p1.current_hp:
				_end_round(false, false)
			else:
				_end_round(false, true)

## 한 라운드가 끝났을 때 호출. 승수를 갱신하고, rounds_to_win에 도달했으면 최종 결과를,
## 아니면 라운드 중간 배너를 보여준 뒤 같은 맵에서 다음 라운드를 새로 시작한다(씬 리로드로 HP/위치 초기화)
func _end_round(p1_won: bool, is_draw: bool) -> void:
	_round_over = true
	_freeze_controllers()
	if not is_draw:
		if p1_won:
			GameState.p1_round_wins += 1
		else:
			GameState.p2_round_wins += 1
	var match_decided: bool = GameState.p1_round_wins >= GameState.rounds_to_win or GameState.p2_round_wins >= GameState.rounds_to_win
	var result_screen: MatchResult = load("res://ui/MatchResult.tscn").instantiate()
	add_child(result_screen)
	if match_decided:
		_show_final_result(result_screen, p1_won, is_draw)
	else:
		result_screen.show_round_result(p1_won, is_draw, GameState.p1_round_wins, GameState.p2_round_wins)
		await get_tree().create_timer(2.0).timeout
		get_tree().reload_current_scene()

func _show_final_result(result_screen: MatchResult, p1_won: bool, is_draw: bool) -> void:
	if is_draw:
		result_screen.show_draw()
		return
	if GameState.game_mode == "story" and p1_won:
		result_screen.queue_free()
		GameState.mark_story_cleared(GameState.story_index)
		get_tree().change_scene_to_file("res://ui/ReformCutscene.tscn")
		return
	var winner_name: String = _p1.stats.character_name if p1_won else _p2.stats.character_name
	result_screen.show_result(p1_won, winner_name)

## ESC(ui_cancel)를 누르면 언제든 대전을 중단하고 메인 메뉴로 나갈 수 있다
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

## player_index는 사람이 조작할 때 어느 쪽 키(1P: A/D/W/F/G/H/R, 2P: 방향키/L/K/J/P)를 읽을지 정한다
func _spawn_fighter(character_path: String, spawn_marker_name: String, is_ai: bool, player_index: int) -> Fighter:
	var scene: PackedScene = load(character_path)
	var fighter: Fighter = scene.instantiate()
	add_child(fighter)
	var spawn: Marker2D = get_node_or_null(spawn_marker_name)
	if spawn:
		fighter.global_position = spawn.global_position
	if is_ai:
		fighter.add_child(ClaudeAIController.new())
	else:
		var controller := PlayerController.new()
		controller.player_index = player_index
		fighter.add_child(controller)
	return fighter

func _freeze_controllers() -> void:
	_set_controllers_active(false)

func _unfreeze_controllers() -> void:
	_set_controllers_active(true)

func _set_controllers_active(active: bool) -> void:
	for f in [_p1, _p2]:
		if not (f and is_instance_valid(f)):
			continue
		for child in f.get_children():
			if child is PlayerController or child is AIController:
				child.is_active = active

## 씬에 배치된 PlayerSpawn 마커들을 이름 순으로 반환한다
func get_player_spawn_points() -> Array[Marker2D]:
	var spawns: Array[Marker2D] = []
	for child in get_children():
		if child is Marker2D and child.name.begins_with("PlayerSpawn"):
			spawns.append(child)
	spawns.sort_custom(func(a, b): return a.name < b.name)
	return spawns
