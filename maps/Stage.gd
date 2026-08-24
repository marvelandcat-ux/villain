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
var _match_over: bool = false

func _ready() -> void:
	_p1 = _spawn_fighter(GameState.p1_character_path, "PlayerSpawn1", false)
	_p2 = _spawn_fighter(GameState.p2_character_path, "PlayerSpawn2", true)

	# 스폰된 Fighter들의 _ready()가 끝날 때까지 한 프레임 기다렸다가 연결한다
	await get_tree().process_frame

	var combat_hud: CombatHUD = get_node_or_null("CombatHUD")
	if combat_hud:
		combat_hud.setup(_p1, _p2)

	# "3, 2, 1, FIGHT!" 카운트다운이 끝날 때까지 양쪽 다 움직이거나 공격할 수 없게 막는다
	_freeze_controllers()
	var round_start: RoundStart = load("res://ui/RoundStart.tscn").instantiate()
	add_child(round_start)
	await round_start.finished
	_unfreeze_controllers()

## died 시그널에 즉시 반응하지 않고 매 프레임 HP를 직접 확인한다.
## 신호에 반응하면 같은 프레임에 양쪽이 동시에 쓰러져도 먼저 처리된 시그널 순서에 따라
## 이미 죽은 쪽이 승자로 판정되는 문제가 있어서, 그 프레임의 데미지가 전부 반영된 뒤 한 번에 판정한다
func _process(_delta: float) -> void:
	if _match_over:
		return
	for f in [_p1, _p2]:
		if f and is_instance_valid(f) and f.global_position.y > ring_out_y:
			f.ring_out()
	if _p1.current_hp <= 0 or _p2.current_hp <= 0:
		_end_match()

func _end_match() -> void:
	_match_over = true
	_freeze_controllers()
	var result_screen: MatchResult = load("res://ui/MatchResult.tscn").instantiate()
	add_child(result_screen)
	if _p1.current_hp <= 0 and _p2.current_hp <= 0:
		result_screen.show_draw()
	elif _p1.current_hp <= 0:
		result_screen.show_result(false, _p2.stats.character_name)
	else:
		result_screen.show_result(true, _p1.stats.character_name)

## ESC(ui_cancel)를 누르면 언제든 대전을 중단하고 메인 메뉴로 나갈 수 있다
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

func _spawn_fighter(character_path: String, spawn_marker_name: String, is_ai: bool) -> Fighter:
	var scene: PackedScene = load(character_path)
	var fighter: Fighter = scene.instantiate()
	add_child(fighter)
	var spawn: Marker2D = get_node_or_null(spawn_marker_name)
	if spawn:
		fighter.global_position = spawn.global_position
	fighter.add_child(AIController.new() if is_ai else PlayerController.new())
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
