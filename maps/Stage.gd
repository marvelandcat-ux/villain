class_name Stage
extends Node2D

## 모든 맵 씬의 공용 베이스. GameState에서 선택된 P1/P2 캐릭터를 스폰 지점에 생성하고,
## 컨트롤러를 붙이고, HUD를 연결하고, 승패를 판정한다. 새 맵은 바닥·벽·PlayerSpawn1/2·Camera2D·CombatHUD만
## 배치하면 이 스크립트가 나머지를 전부 처리한다

## 스테이지 좌우 폭 (플레이어 이동 가능 범위)
@export var stage_width: float = 960.0
## 이 값보다 아래로 떨어지면 링아웃으로 즉시 패배 처리 (벽이 없는 링아웃형 맵에서만 의미 있음)
@export var ring_out_y: float = 900.0
## 이 맵에서만 쓸 수 있는 전용 스킬(예: 아파트 내리찍기). 지정하면 스폰되는 두 캐릭터 모두에게
## 자동으로 붙는다(Fighter.map_skill) — 캐릭터 씬 쪽은 전혀 안 건드려도 된다. Skill을 상속한
## 스크립트가 루트인 씬이어야 하고, 비워두면 그냥 일반 맵(맵 전용 스킬 없음)
@export var map_skill_scene: PackedScene
## 스토리 전투에서 이겼을 때 결과창을 보여주고 있는 시간(초). 지나면 이어지는 이야기 장면으로 넘어간다
@export var story_win_delay: float = 1.8
## (임시) 테스트용 — **스토리 전투 중 `S`를 누르면 이긴 것으로 치고 바로 다음 이야기로 넘어간다.**
## 스토리 장면의 건너뛰기(`StoryFadeScene.debug_skip_key`)와 같은 키다. 스토리를 다 만들면 같이 지울 것.
##
## **⚠️ `S`는 P1 방어 키(`p1_down`)이기도 하다.** 그래서 스토리 전투에서 방어하려고 S를 누르면 전투가 그 자리에서 끝난다 —
## 한 번 겪고 Shift+S로 바꿨다가, **테스트가 번거로워서 사용자가 다시 그냥 `S`로 돌려 달라고 했다**(2026-09-14).
## 스토리 전투에서 방어를 테스트해야 할 땐 맵 루트의 `debug_story_skip_key`를 잠깐 끄면 된다.
## **일반 대전에서는 아예 안 걸린다** — 스토리 모드이고 이어질 장면이 있을 때만 반응한다
@export var debug_story_skip_key: bool = true

## 왼쪽 일시정지 버튼 (스토리 장면과 같은 것을 쓴다)
const PAUSE_BUTTON_SCENE := "res://ui/PauseButton.tscn"

## 화면 왼쪽에 일시정지 버튼을 띄울지
@export var pause_button: bool = true
## 그 버튼이 화면 왼쪽 위에서 떨어지는 거리(px). 기본값은 P1 체력바 바로 아래
@export var pause_button_margin: Vector2 = Vector2(20.0, 104.0)

@export_group("처치 연출")
## 켜면 **패배한 캐릭터가 화면이 느려진 채 날아가는 연출**을 보여준 뒤에 결과창이 뜬다.
## 마지막으로 맞은 방향의 반대쪽(=넉백 방향)으로 빙글 돌며 날아간다
@export var knockout_effect: bool = true
## 이 연출을 쓸 캐릭터 이름 (CharacterStats.character_name). **비우면 전원**.
## 지금은 스토리에서 잼민이가 쓰러질 때만 쓰기로 해서 촉법소년만 넣어 뒀다
@export var knockout_characters: Array[String] = ["촉법소년"]
## 스토리 모드에서만 연출을 쓸지. 끄면 일반 대전에서도 나온다
@export var knockout_story_only: bool = true
## 연출 동안의 시간 배속 (0.35 = 35% 속도). 아래 시간들은 **이 느려진 시간 기준**이다
@export var knockout_time_scale: float = 0.35
## 맞은 순간 딱 멈춰 있는 시간(초) — 타격감을 주는 정지
@export var knockout_hitstop: float = 0.07
## 날아가는 시간(초)과 가로/세로 거리(px). 세로는 음수가 위로 뜨는 양이다
@export var knockout_fly_time: float = 0.62
@export var knockout_fly_x: float = 900.0
@export var knockout_fly_up: float = -260.0
## 날아가면서 도는 바퀴 수
@export var knockout_spin_turns: float = 1.2

var _p1: Fighter
var _p2: Fighter
var _round_over: bool = false
## 처치 연출을 재생하는 중 — 끝날 때까지 승패 판정을 멈춰둔다
var _knockout_playing: bool = false
## "3, 2, 1, FIGHT!" 카운트다운이 끝날 때까지 true — HP/링아웃 판정과 제한시간 감소를 같이 멈춰둔다
var _countdown_active: bool = true
## 이번 라운드 남은 시간 (GameState.time_limit_seconds가 0이면 시간 제한 없음)
var _round_time_left: float = 0.0
var _combat_hud: CombatHUD

func _ready() -> void:
	# 스토리 모드 한정: 캐릭터를 스폰하기도 전에 "주인공 VS 적" 매치업 화면부터 보여준다.
	# GameState.p1/p2_character_path만으로 채우므로 Fighter가 없어도 상관없다
	if GameState.game_mode == "story":
		var versus: VersusIntro = load("res://ui/VersusIntro.tscn").instantiate()
		add_child(versus)
		await versus.finished
	_round_time_left = GameState.time_limit_seconds
	# 궁극기 컷인 연출 (Fighter가 그룹으로 찾아 쓴다)
	add_child(load("res://ui/UltimateCutIn.tscn").instantiate())
	_add_pause_button()
	# 같은 스킬 슬롯을 동시에 쓰면 연타 미니게임(클래시)을 벌이는 매니저 (Fighter가 그룹으로 찾아 쓴다)
	add_child(SkillClashManager.new())
	_p1 = _spawn_fighter(GameState.p1_character_path, "PlayerSpawn1", false, 1)
	# 로컬 대전(pvp)은 P2도 사람이 직접 조작하고, 스토리 모드는 정해진 상대를 AI가 조작한다
	var p2_is_ai: bool = GameState.game_mode == "story"
	_p2 = _spawn_fighter(GameState.p2_character_path, "PlayerSpawn2", p2_is_ai, 2)
	# 컨트롤러가 붙자마자 바로 얼려서, 아래 await로 프레임이 넘어가는 순간에도
	# 입력을 못 받게 한다 (여기서 안 얼리면 그 한 프레임 동안 is_active 기본값(true)이라
	# 카운트다운이 뜨기도 전에 스킬이 나가버리는 틈이 생겼었다)
	_freeze_controllers()

	# 스폰된 Fighter들의 _ready()가 끝날 때까지 한 프레임 기다렸다가 연결한다
	await get_tree().process_frame

	_combat_hud = get_node_or_null("CombatHUD")
	if _combat_hud:
		_combat_hud.setup(_p1, _p2)
		_combat_hud.update_round_info(GameState.p1_round_wins, GameState.p2_round_wins, _round_time_left)

	var round_start: RoundStart = load("res://ui/RoundStart.tscn").instantiate()
	add_child(round_start)
	await round_start.finished
	_countdown_active = false
	_unfreeze_controllers()

## died 시그널에 즉시 반응하지 않고 매 프레임 HP를 직접 확인한다.
## 신호에 반응하면 같은 프레임에 양쪽이 동시에 쓰러져도 먼저 처리된 시그널 순서에 따라
## 이미 죽은 쪽이 승자로 판정되는 문제가 있어서, 그 프레임의 데미지가 전부 반영된 뒤 한 번에 판정한다
func _process(delta: float) -> void:
	if _round_over or _countdown_active or _knockout_playing:
		return
	for f in [_p1, _p2]:
		if f and is_instance_valid(f) and f.global_position.y > ring_out_y:
			f.ring_out()
	if _p1.current_hp <= 0 or _p2.current_hp <= 0:
		var p1_dead: bool = _p1.current_hp <= 0
		var p2_dead: bool = _p2.current_hp <= 0
		if p1_dead and p2_dead:
			_finish_round(false, true)
		else:
			_finish_round(not p1_dead, false)
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

## 라운드가 끝났을 때 제일 먼저 들어오는 곳 — 처치 연출이 있으면 그걸 먼저 보여주고 결과로 넘긴다.
## `_knockout_playing` 동안 `_process`의 판정을 멈춰서 연출 중에 같은 라운드가 두 번 끝나지 않게 한다
func _finish_round(p1_won: bool, is_draw: bool) -> void:
	var loser: Fighter = _p2 if p1_won else _p1
	if not is_draw and _wants_knockout(loser):
		_knockout_playing = true
		_freeze_controllers()
		await _play_knockout(loser)
		_knockout_playing = false
	_end_round(p1_won, is_draw)

## 이 캐릭터가 쓰러질 때 처치 연출을 쓸지
func _wants_knockout(loser: Fighter) -> bool:
	if not knockout_effect or loser == null or not is_instance_valid(loser):
		return false
	if knockout_story_only and GameState.game_mode != "story":
		return false
	if knockout_characters.is_empty():
		return true
	return loser.stats != null and loser.stats.character_name in knockout_characters

## 처치 연출 — **화면이 느려지면서, 마지막으로 맞은 반대 방향으로 빙글 돌며 날아간다.**
##
## 리그(`Visual`)의 표정을 "눈 X"로 바꾸고 파츠를 흩뜨린 뒤(`BodyRig.play_knockout`),
## 캐릭터의 물리를 끄고 **직접 자리를 옮긴다** — CharacterBody2D의 이동·중력에 맡기면 벽·바닥에 걸려서
## 화면 밖까지 안 나간다.
##
## 시간 배속(`Engine.time_scale`)을 낮추면 Tween도 같이 느려지므로, 아래 시간들은 **느려진 시간 기준**이다
## (0.35배속에서 0.62초짜리 트윈은 실제로 약 1.8초 걸린다). 연출이 끝나면 배속을 반드시 1로 되돌린다
func _play_knockout(loser: Fighter) -> void:
	var direction: float = loser.last_hit_direction
	if direction == 0.0:
		direction = -loser.facing
	var visual: Node = loser.get_node_or_null("Visual")
	if visual and visual.has_method("play_knockout"):
		# 리그는 좌우 반전(scale.x = -1)이라 로컬 +x가 늘 바라보는 쪽이다 —
		# 손·발이 날아가는 반대쪽으로 처지도록 방향을 바라보는 쪽 기준으로 바꿔 넘긴다
		visual.play_knockout(direction * loser.facing)
	loser.velocity = Vector2.ZERO
	loser.set_physics_process(false)
	# 카메라가 날아가는 쪽을 따라가면 승자가 화면 밖으로 밀려난다 —
	# "fighters" 그룹에서 빼면 CameraRig가 둘 다 못 찾아 그 자리에 멈춘다
	loser.remove_from_group("fighters")
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.7)
	Engine.time_scale = maxf(knockout_time_scale, 0.05)
	# 맞은 순간 딱 멈췄다가 날아간다. **트윈 안에서 tween_interval로 하면 안 된다** —
	# set_parallel(true) 뒤에 붙는 트위너들이 그 간격과도 병렬로 돌아서 멈춤이 무시된다
	if knockout_hitstop > 0.0:
		await get_tree().create_timer(knockout_hitstop).timeout
		if not is_instance_valid(loser):
			Engine.time_scale = 1.0
			return
	var start: Vector2 = loser.global_position
	var goal: Vector2 = start + Vector2(direction * knockout_fly_x, knockout_fly_up)
	var flight: Tween = loser.create_tween()
	flight.set_parallel(true)
	flight.tween_property(loser, "global_position", goal, knockout_fly_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flight.tween_property(loser, "rotation", deg_to_rad(direction * 360.0 * knockout_spin_turns), knockout_fly_time).set_trans(Tween.TRANS_LINEAR)
	flight.tween_property(loser, "modulate:a", 0.0, knockout_fly_time).set_delay(knockout_fly_time * 0.55)
	await flight.finished
	Engine.time_scale = 1.0

## 연출 도중에 맵을 벗어나도(메뉴로 나가기 등) 시간 배속이 느린 채로 남지 않게 한다
func _exit_tree() -> void:
	Engine.time_scale = 1.0

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
	var winner_name: String = _p1.stats.character_name if p1_won else _p2.stats.character_name
	result_screen.show_result(p1_won, winner_name)
	# 스토리 전투를 이겼으면 결과창을 잠깐 보여준 뒤 이야기를 이어간다 (졌으면 예전처럼 재시도/메뉴)
	if p1_won and GameState.game_mode == "story" and GameState.story_next_scene != "":
		result_screen.hide_buttons()
		await get_tree().create_timer(story_win_delay).timeout
		if not is_inside_tree():
			return   # 기다리는 동안 맵이 사라졌으면(재시도·메뉴 등) 아무 것도 하지 않는다
		var next_scene: String = GameState.story_next_scene
		GameState.story_next_scene = ""
		if ResourceLoader.exists(next_scene):
			get_tree().change_scene_to_file(next_scene)
		else:
			push_warning("Stage: 스토리 다음 장면을 못 찾았다 — %s" % next_scene)

## ESC(ui_cancel)를 누르면 일시정지 메뉴를 띄운다. 이 함수 자체가 get_tree().paused일 때는
## 호출되지 않으므로(Stage는 process_mode를 안 바꿔서 기본값인 "멈추면 같이 멈춤"이라),
## 메뉴가 떠 있는 동안 다시 ESC를 눌러도 여기서 중복으로 또 띄우는 일은 없다
func _unhandled_input(event: InputEvent) -> void:
	if debug_story_skip_key and event is InputEventKey:
		var key: InputEventKey = event
		var is_s: bool = key.keycode == KEY_S or key.physical_keycode == KEY_S
		if key.pressed and not key.echo and is_s:
			# **입력 처리 표시를 장면 전환보다 먼저 해야 한다** — change_scene_to_file 뒤에는
			# 이 노드가 트리에서 빠져서 get_viewport()가 null이 된다(실제로 그 에러를 봤다)
			if _can_debug_skip_story_battle():
				get_viewport().set_input_as_handled()
				_debug_skip_story_battle()
				return
	if event.is_action_pressed("ui_cancel"):
		open_pause_menu()

## 화면 왼쪽에 일시정지 버튼을 붙인다 (스토리 장면과 같은 것).
## ESC만 있으면 처음 하는 사람은 멈출 방법을 모른다는 피드백을 받아서 넣었다(2026-09-15).
## **P1 체력바(CombatHUD의 P1Panel, 20~330 x 16~90) 바로 아래**에 놓아 HUD와 안 겹치게 한다
func _add_pause_button() -> void:
	if not pause_button or not ResourceLoader.exists(PAUSE_BUTTON_SCENE):
		return
	var button: Node = load(PAUSE_BUTTON_SCENE).instantiate()
	button.margin = pause_button_margin
	button.hide_story_list = true   # 싸우는 중엔 다른 에피소드 목록까지 볼 이유가 없다
	button.hide_title = true        # "일시정지" 제목도 빼서 메뉴만 남긴다
	add_child(button)

## 일시정지 화면을 띄운다 (ESC와 왼쪽 버튼이 같이 쓴다).
## **대전 중에는 오른쪽 에피소드 목록과 왼쪽 "일시정지" 제목을 감춘다** — "진행 중인 스토리"만 남는다
func open_pause_menu() -> void:
	var menu: Node = load("res://ui/PauseMenu.tscn").instantiate()
	menu.show_story_list = false
	menu.show_title = false
	add_child(menu)

## 지금 `S`로 스토리 전투를 건너뛸 수 있는 상태인지. 스토리 모드가 아니거나 이어질 장면이 없으면 false —
## 그래야 일반 대전에서 `S`가 예전처럼 P1 방어 키로만 동작한다(`p1_down`이 S에 걸려 있다)
func _can_debug_skip_story_battle() -> bool:
	if _round_over or GameState.game_mode != "story" or GameState.story_next_scene == "":
		return false
	if not ResourceLoader.exists(GameState.story_next_scene):
		push_warning("Stage: 스토리 다음 장면을 못 찾았다 — %s" % GameState.story_next_scene)
		return false
	return true

## (임시) 스토리 전투를 이긴 것으로 치고 곧바로 다음 장면으로 넘어간다.
## 부르기 전에 반드시 _can_debug_skip_story_battle()로 확인할 것
func _debug_skip_story_battle() -> void:
	_round_over = true
	_freeze_controllers()
	GameState.p1_round_wins = GameState.rounds_to_win   # 이긴 것으로 기록해 둔다
	var next_scene: String = GameState.story_next_scene
	GameState.story_next_scene = ""
	get_tree().change_scene_to_file(next_scene)

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
	if map_skill_scene:
		var skill: Skill = map_skill_scene.instantiate()
		fighter.add_child(skill)
		fighter.map_skill = skill
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
