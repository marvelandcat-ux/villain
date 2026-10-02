extends Node2D

## 튜토리얼 맵(2026-10-01) — 군 시험장 풀밭. 처음 켠 사람은 타이틀 다음에 여기로 온다(GameState.tutorial_seen).
## 배경: 하늘 < 랜덤 구름 < 산 < 숲 < 건물·막사·국기 < 땅. 훈련 더미 하나를 플레이어가 움직여 본다.
## TODO: 칸별로 군인이 조작을 설명하는 진행

## 훈련 더미 stats는 샌드백용이라 move_speed가 0 — 조작용으로 복제해 이 속도를 넣는다
@export var player_move_speed: float = 411.75
## 이 아래로 떨어지면 스폰 자리로 되돌린다
@export var fall_limit_y: float = 900.0
## 태양은 맵 가운데(월드 x=0)에 걸려 있는 느낌 — 카메라가 맵 끝까지 가면 화면에서 이만큼(UV) 어긋난다. 작을수록 미묘
@export var sun_parallax: float = 0.1
## 어긋남을 재는 기준 반폭(월드 px, 벽 간격의 절반)
@export var sun_map_half_width: float = 1200.0
## 입장 연출 시작 x(맨 왼쪽 벽 -1200에서 100px 안쪽). 여기서 투명하게 나타나 걸어온다
@export var intro_start_x: float = -1100.0
## 이 거리(px)만큼 걸어오는 동안 투명도가 0 → 100%로 차오른다
@export var intro_fade_distance: float = 500.0

## 교관(해병)과 이 거리(px) 안에 들어오면 훈련 안내가 시작된다
@export var instructor_trigger_range: float = 500.0

var _fighter: Fighter
var _sun_mat: ShaderMaterial
var _sun_base: Vector2 = Vector2(0.5, -1.0)
## 입장 연출(왼쪽에서 걸어오며 페이드인) 진행 중이면 true — 그동안은 조작을 막고 직접 걷게 한다
var _intro_active: bool = false
## 걸어와서 멈출 목표 x(스폰 자리)
var _intro_target_x: float = 0.0
## 교관 머리 위 말풍선(씬에 InstructorBubble로 배치 — 에디터에서 위치·크기 조절 가능, say()는 덕타이핑)
@onready var _bubble = $InstructorBubble

## 훈련 안내 진행 단계
enum Step { NONE, TALK, DONE }
var _step: int = Step.NONE
## 교관 대사 목록(스페이스바로 한 줄씩 넘긴다). _ready에서 강조를 입혀 채운다
var _lines: Array[String] = []
var _line_idx: int = -1

## 강조(빨간색 굵게). 기본 글꼴이 이미 Bold라 굵기 차이는 거의 없고 빨간색으로 튄다
const EM_COLOR := "e22020"
func _em(s: String) -> String:
	return "[color=#%s][b]%s[/b][/color]" % [EM_COLOR, s]

func _ready() -> void:
	GameState.mark_tutorial_seen()
	_spawn_player()
	_lines = [
		"아쌔이 지금 부터 신병 훈련을 시작한다",
		"%s %s 로 움직일 수 있다. 움직인다 실시!" % [_em("A"), _em("D")],
		"좋다 아쌔이",
		"%s로 점프를 할 수 있다, 최대 더블 점프까지 가능하다." % _em("W"),
		"하지만 너무 높이 점프 하면 %s할 때 %s이 있다 조심하도록해라!" % [_em("착지"), _em("경직")],
	]
	var rays := $Sunlight/Rays as ColorRect
	if rays and rays.material is ShaderMaterial:
		_sun_mat = rays.material
		_sun_base = _sun_mat.get_shader_parameter("sun_pos")

func _process(delta: float) -> void:
	if not (_fighter and is_instance_valid(_fighter)):
		return
	var camera: Camera2D = $Camera2D
	camera.global_position.x = lerpf(camera.global_position.x, _fighter.global_position.x, 5.0 * minf(delta, 0.05))
	# 훈련 안내가 진행 중일 땐 교관(말풍선)이 화면 밖으로 밀려나지 않게 카메라를 교관 근처로 묶는다
	# (안 그러면 좌우로 움직여 판정될 때 카메라가 따라가 "좋다 아썌이" 같은 대사가 화면 밖에서 뜬다)
	if _step != Step.NONE and _step != Step.DONE:
		var inst := $Instructor as Node2D
		if inst:
			camera.global_position.x = clampf(camera.global_position.x, inst.global_position.x - 450.0, inst.global_position.x + 450.0)
	# 맵 가운데(x=0)에 박힌 태양이 카메라가 움직이는 만큼 화면에서 반대로 미묘하게 밀린다
	if _sun_mat:
		var shift := clampf(camera.global_position.x / sun_map_half_width, -1.0, 1.0) * sun_parallax
		_sun_mat.set_shader_parameter("sun_pos", Vector2(_sun_base.x - shift, _sun_base.y))
	if _fighter.global_position.y > fall_limit_y:
		_fighter.global_position = $PlayerSpawn.global_position
		_fighter.velocity = Vector2.ZERO
	_update_tutorial(delta)

## 교관 가까이(기본 500px) 오면 대사를 시작한다. 이후 진행은 스페이스바로(_advance).
func _update_tutorial(_delta: float) -> void:
	if _intro_active or _bubble == null or _step != Step.NONE:
		return
	var instructor := $Instructor as Node2D
	if instructor and _fighter.global_position.distance_to(instructor.global_position) <= instructor_trigger_range:
		_step = Step.TALK
		_line_idx = 0
		_say_current()

## 지금 줄을 말풍선에 띄운다. 마지막 줄이 아니면 "계속" 힌트(▼)를 켠다.
func _say_current() -> void:
	var is_last := _line_idx >= _lines.size() - 1
	_bubble.say(_lines[_line_idx], not is_last)

## 스페이스바: 타이핑 중이면 즉시 다 띄우고, 다 떴으면 다음 줄로(마지막이면 끝).
func _advance() -> void:
	if _step != Step.TALK or _bubble == null:
		return
	if _bubble.is_typing():
		_bubble.finish_typing()
		return
	_line_idx += 1
	if _line_idx >= _lines.size():
		_step = Step.DONE
		return
	_say_current()

func _spawn_player() -> void:
	var scene: PackedScene = load("res://characters/dummy/TrainingDummy.tscn")
	_fighter = scene.instantiate()
	# add_child 전에 stats를 바꿔 끼워야 _ready()가 새 값으로 시작한다
	var stats: CharacterStats = _fighter.stats.duplicate()
	stats.move_speed = player_move_speed
	_fighter.stats = stats
	add_child(_fighter)
	# 입장 연출: 왼쪽 끝에서 투명하게 시작해 스폰 자리까지 걸어오며 나타난다. 컨트롤러는 도착 후에 붙인다
	_intro_target_x = $PlayerSpawn.position.x
	_fighter.global_position = Vector2(intro_start_x, $PlayerSpawn.global_position.y)
	var visual := _fighter.get_node_or_null("Visual") as CanvasItem
	if visual:
		visual.modulate.a = 0.0
	_intro_active = true
	$Camera2D.global_position.x = _fighter.global_position.x

## 연출 동안은 컨트롤러 없이 직접 오른쪽으로 걷게 하고(apply_physics는 컨트롤러가 없으니 여기서 호출),
## 걸어온 거리에 비례해 투명도를 올린다. 목표 x에 닿으면 멈추고 조작을 넘긴다
func _physics_process(delta: float) -> void:
	if not _intro_active:
		return
	if not (_fighter and is_instance_valid(_fighter)):
		return
	_fighter.move(1.0)
	_fighter.apply_physics(delta)
	var visual := _fighter.get_node_or_null("Visual") as CanvasItem
	if visual:
		var progress := (_fighter.global_position.x - intro_start_x) / maxf(intro_fade_distance, 1.0)
		visual.modulate.a = clampf(progress, 0.0, 1.0)
	if _fighter.global_position.x >= _intro_target_x:
		_end_intro()

## 입장 연출을 끝내고 플레이어 조작을 시작한다
func _end_intro() -> void:
	_intro_active = false
	_fighter.global_position.x = _intro_target_x
	_fighter.velocity.x = 0.0
	_fighter.move(0.0)
	var visual := _fighter.get_node_or_null("Visual") as CanvasItem
	if visual:
		visual.modulate.a = 1.0
	var controller := PlayerController.new()
	controller.player_index = 1
	_fighter.add_child(controller)

## ESC = 메인 메뉴로. 스페이스바 = 교관 대사 넘기기
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file("res://ui/MainMenu.tscn")
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		_advance()
