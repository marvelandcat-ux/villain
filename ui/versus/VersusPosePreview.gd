@tool
class_name VersusPosePreview
extends Node2D

## **에디터에서만 보이는 미리보기.** 포즈 씬(PoliceVersusPose 등)만 열어도
## 격돌 화면의 빨강·파랑 배경과 **반대편 캐릭터가 실제 자리에 같이** 보이게 해 준다.
## 부품 하나를 끌 때마다 화면에서 어디로 가는지, 상대와 견줘서 어떤지 바로 보인다.
##
## 게임에서는 VersusIntro가 이 노드를 통째로 지운다 — 화면에는 절대 안 나온다.
##
## **F6으로 포즈 씬만 돌리면** 진짜 격돌 화면이 모의로 돌아간다(끝나면 저절로 다시 돈다).
## 스페이스/R이면 바로 다시, Esc면 끝낸다
##
## 좌표 계산: 포즈의 원점(머리 한가운데)이 화면 `origin_on_screen`에 놓이고,
## `facing`이 -1이면 화면에서 좌우가 뒤집혀 나온다. 그래서 화면 좌표 -> 이 노드 안 좌표는
## `(화면x - 원점x) * facing` 이 된다(facing이 ±1이라 나누기와 곱하기가 같다).

## 격돌 화면 크기(px). VersusIntro가 쓰는 기준 해상도와 같아야 한다
@export var screen_size: Vector2 = Vector2(1280, 720):
	set(value):
		screen_size = value
		_refresh()
## 이 포즈의 원점이 화면 어디에 놓이는지
@export var origin_on_screen: Vector2 = Vector2(260, 223):
	set(value):
		origin_on_screen = value
		_refresh()
## 1이면 그대로, -1이면 화면에서 좌우가 뒤집혀 나온다 (오른쪽 캐릭터가 -1)
@export var facing: float = 1.0:
	set(value):
		facing = value
		_refresh()
## 가운데 빗변이 위아래로 벌어지는 거리(px). **VersusHalf의 lean과 같은 값**이어야 한다
@export var seam_lean: float = 190.0:
	set(value):
		seam_lean = value
		queue_redraw()
@export var left_color: Color = Color(0.17, 0.2, 0.76, 1.0)
@export var right_color: Color = Color(0.92, 0.11, 0.1, 1.0)
## 화면 테두리 색 — 화면 밖으로 삐져나갔는지 보라고 그어 준다
@export var frame_color: Color = Color(1.0, 1.0, 1.0, 0.85)

@export_group("반대편 캐릭터")
## 같이 띄울 상대 포즈 씬
@export_file("*.tscn") var opponent_pose: String = "":
	set(value):
		opponent_pose = value
		_refresh()
## 상대의 원점이 화면 어디에 놓이는지
@export var opponent_origin_on_screen: Vector2 = Vector2(1020, 223):
	set(value):
		opponent_origin_on_screen = value
		_refresh()
## 상대가 화면에서 보는 방향 (1 = 그대로, -1 = 뒤집힘)
@export var opponent_facing: float = -1.0:
	set(value):
		opponent_facing = value
		_refresh()

func _ready() -> void:
	if not Engine.is_editor_hint():
		# 혹시 게임에서 이 씬을 그냥 띄우더라도 미리보기는 안 보이게 한다
		visible = false
		# **F6(현재 씬 실행)으로 포즈 씬만 돌렸을 때**는 진짜 격돌 화면을 모의로 띄운다.
		# 에디터 미리보기는 멈춘 그림이라, 날아와 부딪히고 흔들릴 때 어떻게 보이는지는 못 본다
		if get_tree().current_scene == get_parent():
			_run_mock.call_deferred()
		return
	_refresh()

# ---------------------------------------------------------------- F6 모의 실행
## 모의로 띄운 격돌 화면(없으면 안 돌고 있는 것)
var _mock: CanvasLayer = null

## 포즈 씬 경로로 **그 포즈가 누구 것인지** 거꾸로 찾는다.
## 대진 전용 포즈는 열쇠가 "내 이름|상대 이름"이라 앞부분만 떼어 쓴다
func _name_for_pose(pose_path: String) -> String:
	for key in VersusIntro.VERSUS_POSES:
		if VersusIntro.VERSUS_POSES[key] == pose_path:
			return str(key)
	for key in VersusIntro.VERSUS_POSES_VS:
		if VersusIntro.VERSUS_POSES_VS[key] == pose_path:
			return str(key).get_slice("|", 0)
	return ""

func _run_mock() -> void:
	var stage: Node2D = get_parent() as Node2D
	if stage == null:
		return
	var mine: String = _name_for_pose(stage.scene_file_path)
	var other: String = _name_for_pose(opponent_pose)
	if mine == "":
		push_warning("VersusPosePreview: %s 는 VersusIntro.VERSUS_POSES에 없다 — 모의 실행 못 한다" % stage.scene_file_path)
		return
	if other == "":
		other = "주인공"   # 상대를 못 찾으면 주인공과 붙여 본다
	# facing이 -1이면 이 포즈는 **오른쪽(P2)** 자리다
	var left: String = other if facing < 0.0 else mine
	var right: String = mine if facing < 0.0 else other
	GameState.p1_character_path = GameState.character_path(left)
	GameState.p2_character_path = GameState.character_path(right)
	# 포즈 원본 스프라이트는 **치워 둔다** — 사다리꼴이 날아오기 전 0.3초 동안 바닥에 겹쳐 보인다
	for sibling in stage.get_children():
		if sibling != self and sibling is CanvasItem:
			(sibling as CanvasItem).visible = false
	_spawn_mock()

func _spawn_mock() -> void:
	const INTRO := "res://ui/VersusIntro.tscn"
	if not ResourceLoader.exists(INTRO):
		return
	_mock = (load(INTRO) as PackedScene).instantiate() as CanvasLayer
	get_parent().add_child(_mock)
	await _mock.finished
	# 연출이 끝나면 화면이 홀로그램 타일로 덮여 있다 — 걷어내고 처음부터 다시 돌린다
	SceneTransition.uncover()
	await get_tree().create_timer(0.45).timeout
	if is_instance_valid(_mock):
		_mock.queue_free()
	_mock = null
	_spawn_mock()

## 모의 실행 중에만 듣는다 — 스페이스/R로 바로 다시 보고, Esc로 끈다
func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _mock == null:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_ESCAPE:
		get_tree().quit()
	elif key.physical_keycode in [KEY_SPACE, KEY_R]:
		SceneTransition.uncover()
		_mock.queue_free()
		_mock = null
		_spawn_mock()

## 화면 좌표를 이 노드 안 좌표로 옮긴다
func _to_local_screen(point: Vector2) -> Vector2:
	return Vector2((point.x - origin_on_screen.x) * facing, point.y - origin_on_screen.y)

func _refresh() -> void:
	queue_redraw()
	if not Engine.is_editor_hint() or not is_node_ready():
		return
	_rebuild_opponent()

## 상대를 띄운다. **상대 안의 미리보기는 바로 지운다** — 안 지우면 상대가 또 나를 띄우고,
## 내가 또 상대를 띄우며 끝없이 겹친다
func _rebuild_opponent() -> void:
	var old: Node = get_node_or_null("Opponent")
	if old != null:
		remove_child(old)
		old.queue_free()
	if opponent_pose == "" or not ResourceLoader.exists(opponent_pose):
		return
	var scene: PackedScene = load(opponent_pose)
	if scene == null:
		return
	var other: Node2D = scene.instantiate() as Node2D
	if other == null:
		return
	other.name = "Opponent"
	for child in other.get_children():
		if child is VersusPosePreview:
			other.remove_child(child)
			child.queue_free()
	other.position = _to_local_screen(opponent_origin_on_screen)
	# 상대가 화면에서 보는 방향은 opponent_facing인데, 나도 이미 뒤집혀 있을 수 있으니
	# 내 뒤집힘을 되돌리는 값을 곱해 준다
	other.scale = Vector2(opponent_facing * facing, 1.0)
	add_child(other)
	# owner를 안 주면 씬에 저장되지 않는다 — 미리보기는 파일에 남으면 안 된다
	move_child(other, 0)

func _draw() -> void:
	var top_left: Vector2 = _to_local_screen(Vector2.ZERO)
	var top_right: Vector2 = _to_local_screen(Vector2(screen_size.x, 0.0))
	var bottom_left: Vector2 = _to_local_screen(Vector2(0.0, screen_size.y))
	var bottom_right: Vector2 = _to_local_screen(screen_size)
	var seam_top: Vector2 = _to_local_screen(Vector2(screen_size.x * 0.5 - seam_lean, 0.0))
	var seam_bottom: Vector2 = _to_local_screen(Vector2(screen_size.x * 0.5 + seam_lean, screen_size.y))
	draw_colored_polygon(PackedVector2Array([top_left, seam_top, seam_bottom, bottom_left]), left_color)
	draw_colored_polygon(PackedVector2Array([seam_top, top_right, bottom_right, seam_bottom]), right_color)
	draw_polyline(PackedVector2Array([top_left, top_right, bottom_right, bottom_left, top_left]), frame_color, 3.0)
