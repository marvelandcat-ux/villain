extends Node2D

## 튜토리얼 맵(2026-10-01) — 군 시험장 풀밭. 처음 켠 사람은 타이틀 다음에 여기로 온다(GameState.tutorial_seen).
## 배경: 하늘 < 랜덤 구름 < 산 < 숲 < 건물·막사·국기 < 땅. 훈련 더미 하나를 플레이어가 움직여 본다.
## TODO: 칸별로 군인이 조작을 설명하는 진행

## 훈련 더미 stats는 샌드백용이라 move_speed가 0 — 조작용으로 복제해 이 속도를 넣는다
@export var player_move_speed: float = 411.75
## 이 아래로 떨어지면 스폰 자리로 되돌린다
@export var fall_limit_y: float = 900.0

var _fighter: Fighter

func _ready() -> void:
	GameState.mark_tutorial_seen()
	_spawn_player()

func _process(delta: float) -> void:
	if not (_fighter and is_instance_valid(_fighter)):
		return
	var camera: Camera2D = $Camera2D
	camera.global_position.x = lerpf(camera.global_position.x, _fighter.global_position.x, 5.0 * minf(delta, 0.05))
	if _fighter.global_position.y > fall_limit_y:
		_fighter.global_position = $PlayerSpawn.global_position
		_fighter.velocity = Vector2.ZERO

func _spawn_player() -> void:
	var scene: PackedScene = load("res://characters/dummy/TrainingDummy.tscn")
	_fighter = scene.instantiate()
	# add_child 전에 stats를 바꿔 끼워야 _ready()가 새 값으로 시작한다
	var stats: CharacterStats = _fighter.stats.duplicate()
	stats.move_speed = player_move_speed
	_fighter.stats = stats
	add_child(_fighter)
	_fighter.global_position = $PlayerSpawn.global_position
	var controller := PlayerController.new()
	controller.player_index = 1
	_fighter.add_child(controller)
	$Camera2D.global_position.x = _fighter.global_position.x

## ESC = 메인 메뉴로
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file("res://ui/MainMenu.tscn")
