class_name Stage
extends Node2D

## 모든 맵 씬의 공용 베이스. GameState에서 선택된 P1/P2 캐릭터를 스폰 지점에 생성하고,
## 컨트롤러를 붙이고, HUD를 연결하고, 승패를 판정한다. 새 맵은 바닥·벽·PlayerSpawn1/2·Camera2D·CombatHUD만
## 배치하면 이 스크립트가 나머지를 전부 처리한다

## 스테이지 좌우 폭 (플레이어 이동 가능 범위)
@export var stage_width: float = 960.0
## 이 높이보다 아래로 떨어지면 "맵 밖"으로 보고 처음 자리로 되돌린다(예전 링아웃 판정선).
## 죽이는 게 아니라 구해주는 선이다
@export var fall_rescue_y: float = 900.0
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
@export var debug_story_skip_key: bool = false

## 왼쪽 일시정지 버튼 (스토리 장면과 같은 것을 쓴다)
const PAUSE_BUTTON_SCENE := "res://ui/PauseButton.tscn"

## 화면 왼쪽에 일시정지 버튼을 띄울지
@export var pause_button: bool = true
## 그 버튼이 화면 왼쪽 위에서 떨어지는 거리(px).
## **체력바가 화면 아래로 내려가면서 위쪽이 비어서 맨 위로 올렸다**(2026-09-28)
@export var pause_button_margin: Vector2 = Vector2(20.0, 18.0)

@export_group("처치 연출")
## 켜면 **패배한 캐릭터가 화면이 느려진 채 날아가는 연출**을 보여준 뒤에 결과창이 뜬다.
## 마지막으로 맞은 방향의 반대쪽(=넉백 방향)으로 빙글 돌며 날아간다
@export var knockout_effect: bool = true
## 이 연출을 쓸 캐릭터 이름 (CharacterStats.character_name). **비우면 전원**.
## 2026-09-30 사용자 요청으로 전원·일반 대전에서도 켬(예전엔 스토리 잼민이 전용 ["금쪽이"])
@export var knockout_characters: Array[String] = []
## 스토리 모드에서만 연출을 쓸지. 끄면 일반 대전에서도 나온다
@export var knockout_story_only: bool = false
## 체력·스킬 판(`CombatHUD`의 선수 판 둘)을 **화면 위쪽 좌·우 구석**으로 올릴지.
## 놀이터처럼 아래쪽에 발판·모래밭이 있어서 평소 자리(아래)에 두면 바닥 기믹을 가리는 맵에서 켠다
@export var hud_panels_top: bool = false
## 연출 동안의 시간 배속 (0.35 = 35% 속도). 아래 시간들은 **이 느려진 시간 기준**이다
@export var knockout_time_scale: float = 0.35
## 라운드 승리 띠(평행사변형 배너) 장면. 비워 두면 기본 띠(`ui/RoundWinBanner.tscn`)를 쓴다
@export var round_banner_scene: PackedScene = null
## **승리 띠 미리보기 키.** 싸우는 중에 이 키를 누르면 라운드를 안 끝내고 띠만 한 번 지나간다 —
## 누를 때마다 P1 쪽·P2 쪽이 번갈아 나온다. 자리 잡을 때 쓰라고 둔 것이라 끄려면 false로.
## 띠가 지나가는 동안에도 조작은 그대로 되고 라운드 진행에는 아무 영향이 없다
@export var debug_banner_preview: bool = true
## 그 키(기본 B)
@export var debug_banner_key: Key = KEY_B
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
## 라운드 승리 띠의 기본 장면
const DEFAULT_ROUND_BANNER := "res://ui/RoundWinBanner.tscn"

## 미리보기 키를 누를 때 번갈아 보여 줄 쪽
var _banner_preview_p1: bool = false

var _round_over: bool = false
## 처치 연출을 재생하는 중 — 끝날 때까지 승패 판정을 멈춰둔다
var _knockout_playing: bool = false
## "3, 2, 1, FIGHT!" 카운트다운이 끝날 때까지 true — HP/링아웃 판정과 제한시간 감소를 같이 멈춰둔다
var _countdown_active: bool = true
## 이번 라운드 남은 시간 (GameState.time_limit_seconds가 0이면 시간 제한 없음)
var _round_time_left: float = 0.0
var _combat_hud: CombatHUD
## **타이틀 구경 모드**(`GameState.game_mode == "attract"`, 2026-09-28) — 타이틀 화면 뒤에서 AI 둘이 싸우는 장면.
## 두 캐릭터 모두 AI, 체력바·카운트다운·일시정지·연타 대결·궁극기 컷인 없음(화면을 멈추거나 UI를 띄우므로),
## 판이 끝나도 결과 화면·재시작을 하지 않는다 — 카메라를 흘리고 새 조합으로 바꾸는 건 TitleScreen이 한다
var _attract: bool = false

func _ready() -> void:
	_attract = GameState.game_mode == "attract"
	if _attract:
		_start_attract()
		return
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
	# 대전 모드도 방 설정에서 "상대: 컴퓨터"를 골랐으면 P2를 AI가 조종한다
	var p2_is_ai: bool = GameState.game_mode == "story" or GameState.vs_ai
	_p2 = _spawn_fighter(GameState.p2_character_path, "PlayerSpawn2", p2_is_ai, 2)
	# 컨트롤러가 붙자마자 바로 얼려서, 아래 await로 프레임이 넘어가는 순간에도
	# 입력을 못 받게 한다 (여기서 안 얼리면 그 한 프레임 동안 is_active 기본값(true)이라
	# 카운트다운이 뜨기도 전에 스킬이 나가버리는 틈이 생겼었다)
	_freeze_controllers()

	# 스폰된 Fighter들의 _ready()가 끝날 때까지 한 프레임 기다렸다가 연결한다
	await get_tree().process_frame

	_combat_hud = get_node_or_null("CombatHUD")
	if _combat_hud:
		if _combat_hud.has_method("set_panels_top"):
			_combat_hud.set_panels_top(hud_panels_top)
		_combat_hud.setup(_p1, _p2)
		_combat_hud.update_round_info(GameState.p1_round_wins, GameState.p2_round_wins, _round_time_left)

	# 스토리 VS 화면이 **화면을 덮어 둔 채로** 끝난다 — 캐릭터가 다 자리잡은 지금 걷어낸다.
	# 덮어 둔 게 없으면(대전 모드) 그냥 지나간다
	await SceneTransition.uncover()

	var round_start: RoundStart = load("res://ui/RoundStart.tscn").instantiate()
	add_child(round_start)
	await round_start.finished
	_countdown_active = false
	_unfreeze_controllers()

## 타이틀 구경 모드 시작 — 두 캐릭터를 AI로 세우고 HUD를 숨긴 채 바로 싸우게 한다
func _start_attract() -> void:
	_p1 = _spawn_fighter(GameState.p1_character_path, "PlayerSpawn1", true, 1)
	_p2 = _spawn_fighter(GameState.p2_character_path, "PlayerSpawn2", true, 2)
	var hud: Node = get_node_or_null("CombatHUD")
	if hud is CanvasLayer:
		hud.visible = false
	# 게임을 멈추고 화면을 덮는 맵 연출(놀이터 왕관 획득 컷인)도 뺀다 — 없으면 Crown이 그냥 넘어간다
	for n in get_tree().get_nodes_in_group("crown_cutin"):
		if is_ancestor_of(n):
			n.remove_from_group("crown_cutin")
			n.queue_free()
	_countdown_active = false

## 맵 밖으로 떨어진 캐릭터를 처음 자리(PlayerSpawn 마커)로 되돌린다.
## **링아웃을 없애면서 생긴 안전장치다** — 죽이지도, 점수를 주지도 않고 그냥 제자리에 놓는다.
## 마커를 못 찾으면 맵 한가운데 위쪽에 놓는다
func _rescue_fallen(fighter: Fighter) -> void:
	var marker_name: String = "PlayerSpawn1" if fighter == _p1 else "PlayerSpawn2"
	var marker: Node2D = get_node_or_null(marker_name)
	fighter.global_position = marker.global_position if marker else Vector2(0.0, 0.0)
	fighter.velocity = Vector2.ZERO

## died 시그널에 즉시 반응하지 않고 매 프레임 HP를 직접 확인한다.
## 신호에 반응하면 같은 프레임에 양쪽이 동시에 쓰러져도 먼저 처리된 시그널 순서에 따라
## 이미 죽은 쪽이 승자로 판정되는 문제가 있어서, 그 프레임의 데미지가 전부 반영된 뒤 한 번에 판정한다
func _process(delta: float) -> void:
	if _round_over or _countdown_active or _knockout_playing:
		return
	# **링아웃(낙사)은 없다**(2026-09-25 사용자 결정) — 맵 밖으로 떨어져도 지지 않는다.
	# 좌우 벽을 바닥까지 높게 세워서 애초에 나갈 수 없지만, 혹시 어떤 기믹이 몸을 맵 밖으로
	# 보내버렸을 때 영원히 떨어지지 않도록 처음 자리로 되돌려 놓기만 한다 (체력은 그대로)
	for f in [_p1, _p2]:
		if f and is_instance_valid(f) and f.global_position.y > fall_rescue_y:
			_rescue_fallen(f)
	# 구경 모드는 승패 판정·결과 화면·재시작을 하지 않는다(체력 0이 돼도 계속 싸운다)
	if _attract:
		return
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
	# 방금 딴 점수를 HUD에도 바로 반영한다 — _process가 라운드 종료로 멈춰서
	# 그냥 두면 결과창이 떠 있는 내내 **이기기 직전 점수**가 남아 있는다
	if _combat_hud:
		_combat_hud.update_round_info(GameState.p1_round_wins, GameState.p2_round_wins, _round_time_left)
	var match_decided: bool = GameState.p1_round_wins >= GameState.rounds_to_win or GameState.p2_round_wins >= GameState.rounds_to_win
	if match_decided:
		var result_screen: MatchResult = load("res://ui/MatchResult.tscn").instantiate()
		add_child(result_screen)
		_show_final_result(result_screen, p1_won, is_draw)
		return
	# **라운드 중간은 결과창 대신 띠 하나가 지나간다** — 창이 뜨면 흐름이 끊겨서
	# "로그가 찍힌다"는 느낌이 났다(2026-10-02 사용자 요청)
	await _play_round_banner(p1_won, is_draw)
	if not is_inside_tree():
		return   # 띠가 지나가는 사이에 맵이 사라졌으면(메뉴로 나감 등) 아무 것도 안 한다
	get_tree().reload_current_scene()

## 라운드 승리 띠를 띄우고 끝날 때까지 기다린다. 띠를 못 찾으면 잠깐 쉬고 넘어간다
func _play_round_banner(p1_won: bool, is_draw: bool) -> void:
	var scene: PackedScene = round_banner_scene
	if scene == null and ResourceLoader.exists(DEFAULT_ROUND_BANNER):
		scene = load(DEFAULT_ROUND_BANNER)
	var band: Node = null
	var banner: Node = null
	if scene != null:
		banner = scene.instantiate()
		add_child(banner)
		band = banner.get_node_or_null("Band")
	if band == null or not band.has_method("play"):
		if banner:
			banner.queue_free()
		await get_tree().create_timer(1.2).timeout
		return
	band.play(p1_won, is_draw)
	await band.finished
	banner.queue_free()

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
	# 구경 모드는 키 입력을 전부 타이틀 화면에 맡긴다(ESC로 일시정지가 뜨면 안 된다)
	if _attract:
		return
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
	# 승리 띠 미리보기 — 라운드는 그대로 두고 띠만 한 번 띄운다
	if debug_banner_preview and event is InputEventKey:
		var bk: InputEventKey = event
		var hit: bool = bk.keycode == debug_banner_key or bk.physical_keycode == debug_banner_key
		if bk.pressed and not bk.echo and hit:
			get_viewport().set_input_as_handled()
			_banner_preview_p1 = not _banner_preview_p1
			_play_round_banner(_banner_preview_p1, false)
			return
	if event.is_action_pressed("ui_cancel"):
		open_pause_menu()

## 화면 왼쪽에 일시정지 버튼을 붙인다 (스토리 장면과 같은 것).
## ESC만 있으면 처음 하는 사람은 멈출 방법을 모른다는 피드백을 받아서 넣었다(2026-09-15).
## 체력바는 화면 **아래쪽**으로 내려갔으므로(ui/CombatHUD.tscn) 이 버튼은 왼쪽 맨 위 구석에 둔다
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
	# ⚠️ 체력·공격력 손보기는 **add_child 전에** 해야 한다 — Fighter._ready()가 current_hp를 stats.max_hp로 잡는다
	if is_ai and GameState.game_mode == "story":
		_apply_story_handicap(fighter)
	add_child(fighter)
	var spawn: Marker2D = get_node_or_null(spawn_marker_name)
	if spawn:
		fighter.global_position = spawn.global_position
	if is_ai:
		# 스토리는 Claude API가 전략을 얹는 AI, 대전 모드 컴퓨터 상대는 규칙 기반 AI만(사용자 결정 — API 비용 없음)
		if GameState.game_mode == "story":
			var brain := ClaudeAIController.new()
			_tune_story_ai(brain)
			fighter.add_child(brain)
		else:
			fighter.add_child(AIController.new())
	else:
		var controller := PlayerController.new()
		controller.player_index = player_index
		fighter.add_child(controller)
	if map_skill_scene:
		var skill: Skill = map_skill_scene.instantiate()
		fighter.add_child(skill)
		fighter.map_skill = skill
	return fighter

## 스토리 상대의 체력·공격력을 그 에피소드가 정한 배수로 조정한다.
## ⚠️ **`stats`는 씬이 공유하는 Resource라 반드시 복제해서 고친다** — 그냥 고치면 훈련장·대전에서
## 같은 캐릭터를 골랐을 때도 체력이 두 배인 채로 나온다(디스크의 .tres까지 더럽혀질 수 있다)
func _apply_story_handicap(fighter: Fighter) -> void:
	var hp_scale: float = GameState.story_enemy_hp_scale
	var dmg_scale: float = GameState.story_enemy_damage_scale
	if fighter.stats == null or (is_equal_approx(hp_scale, 1.0) and is_equal_approx(dmg_scale, 1.0)):
		return
	fighter.stats = fighter.stats.duplicate()
	fighter.stats.max_hp = maxi(int(round(fighter.stats.max_hp * hp_scale)), 1)
	# 공격력은 `compute_damage()`가 곱하는 `stats.attack_multiplier`로 깎는다 —
	# 임시 디버프(`attack_debuff_multiplier`)에 걸면 다른 스킬이 풀어 버릴 수 있다
	fighter.stats.attack_multiplier *= dmg_scale

## 스토리 상대 AI의 솜씨를 `GameState.story_ai_skill`(0~1)로 낮춘다.
## **1이면 평소 대전 AI 그대로**, 0이면 아래 "둔한 값"까지 쭉 끌어내린다.
## 값 하나로 반응속도·방어·회피·스킬 사용을 한꺼번에 움직여야 "조금만 약하게"가 쉬워진다
func _tune_story_ai(ai: ClaudeAIController) -> void:
	var skill: float = clampf(GameState.story_ai_skill, 0.0, 1.0)
	if is_equal_approx(skill, 1.0):
		return
	# 사람 반응속도가 0.2~0.25초다. 기본 0.09는 사람보다 빠르다 — 둔하게 하려면 그보다 한참 늦춘다
	ai.reaction_time = lerpf(0.45, ai.reaction_time, skill)
	ai.guard_react_chance = lerpf(0.10, ai.guard_react_chance, skill)
	ai.dodge_react_chance = lerpf(0.15, ai.dodge_react_chance, skill)
	ai.skill_commit_chance = lerpf(0.15, ai.skill_commit_chance, skill)
	ai.skill_think_interval = lerpf(0.60, ai.skill_think_interval, skill)
	ai.bait_chance = lerpf(0.0, ai.bait_chance, skill)
	# 멀어도 잘 안 달려든다 — 플레이어가 거리를 잡을 틈이 생긴다
	ai.dash_approach_distance = lerpf(520.0, ai.dash_approach_distance, skill)
	# Claude에게 전략을 묻는 주기도 늘린다(판단이 늦게 갱신 = 상황 대응이 굼뜸)
	ai.decision_interval = lerpf(6.0, ai.decision_interval, skill)

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
