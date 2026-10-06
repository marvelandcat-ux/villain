extends Node2D

## **바벨 컬 모션 조정 씬** — F6로 열면 캐릭터가 바벨 컬을 계속 반복한다.
## 포즈 씬(`characters/gym/GymCurl*Pose.tscn`)에서 F6를 눌러도 이 씬이 열린다.
##
## ## 키
## | 키 | 하는 일 |
## |---|---|
## | **스페이스** | 운동 멈춤/다시 시작 |
## | **R** | 처음부터 |
## | **1 / 2 / 3** | 아래 / 중간 / 위 자세를 **크게 띄워 손으로 고치기**(편집 모드) |
## | **0** | 편집 모드를 끝내고 움직이는 걸 다시 본다 |
## | **마우스 끌기** | (편집 모드) 제일 가까운 조각을 집어 옮긴다 |
## | **Q / E** | (편집 모드) 집은 조각을 돌린다 |
## | **[ / ]** | 바벨 크기 |
## | **S** | (편집 모드) 고친 자세를 **그 포즈 씬 파일에 저장** |
##
## 저장은 포즈 씬 파일을 **덮어쓴다.** 저장했으면 화면에 "저장함"이 잠깐 뜬다.
## 되돌리고 싶으면 깃으로 되돌리면 된다.
##
## **바벨 크기도 S로 같이 저장된다.** 포즈 씬에 놓인 보기용 바벨(`BarbellView`)의 Scale을
## 게임이 그대로 읽어 쓰기 때문이다 — 포즈 씬을 에디터에서 열어 바벨을 끌어 키워도 똑같이 반영된다.
## (세 장 중 **중간 자세**의 바벨이 기준이다)

## **어떤 운동을 볼지.** 컬이면 바벨을 두 손 사이에 끼우고, 스쿼트면 원판을 어깨에 멘다.
## 씬 파일만 다르고(`GymCurlStudio.tscn` / `GymSquatStudio.tscn`) 스크립트는 하나를 같이 쓴다
@export_enum("바벨 컬", "스쿼트", "런닝머신") var motion: int = 0
## 움직여 볼 캐릭터의 몸(BodyRig) 씬. **비우면 악플러 리그를 쓴다** —
## 기본 리그(`characters/BodyRig.tscn`)는 머리 그림이 없어서 목 위가 비어 보인다
@export var rig_scene: PackedScene
## 자세 세 장 — 컬이면 아래(팔 편) / 중간 / 위(다 올림), 스쿼트면 서기 / 중간 / 앉기
@export var pose_a: PackedScene
@export var pose_b: PackedScene
@export var pose_c: PackedScene

@export_group("시간")
## 한 번 올렸다 내리는 데 걸리는 시간(초)
@export var curl_cycle: float = 1.6
## 한 번 중에서 올리는 데 쓰는 몫(나머지가 내리는 시간)
@export_range(0.1, 0.9, 0.05) var curl_rise_ratio: float = 0.62
## 자세가 켜지고 꺼지는 데 걸리는 시간(초)
@export var curl_blend_time: float = 0.18

@export_group("보기")
## 움직이는 캐릭터를 얼마나 키워 볼지
@export var rig_scale: float = 5.0
## 움직이는 캐릭터가 설 자리(화면 가운데 기준)
@export var rig_at: Vector2 = Vector2(0, 30)
## 캐릭터를 **왼쪽 보게** 뒤집을지 — 런닝머신은 조작판을 보고 달린다
@export var rig_flip: bool = false
## 아래 줄에 자세 세 장을 정지로 늘어놓을지. **꺼 둔다**(2026-10-05 사용자 판단) —
## 1/2/3 으로 한 장씩 크게 띄워 고치는 편이 낫고, 깔아 두면 움직이는 쪽을 가린다
@export var show_frames: bool = false
## 정지 세 장의 배율과 간격(px)
@export var frame_scale: float = 2.6
@export var frame_gap: float = 200.0
## 정지 세 장이 놓일 높이(화면 가운데 기준)
@export var frame_y: float = 268.0
## **편집 모드**에서 자세 한 장을 얼마나 키워 볼지와, 놓을 자리
@export var edit_scale: float = 7.0
@export var edit_at: Vector2 = Vector2(0, -20)
## 배경색 — 어두운 조각이 묻히지 않게 밝게 둔다
@export var backdrop: Color = Color(0.58, 0.62, 0.70, 1.0)
## 땅 선을 그릴 높이(리그 기준 y). PosePreview의 ground_y와 같은 값
@export var ground_y: float = 33.0
## 바벨 크기를 [ ] 로 한 번 누를 때 **곱하는 비율**(1.04면 4%씩). 가로세로 비율은 그대로 지킨다
@export var bar_scale_step: float = 1.04

@export_group("기구")
## **기구를 같이 띄울지**(런닝머신처럼 그 위에 올라서는 기구를 볼 때). 자리 맞추기가 목적이다
@export var show_machine: bool = false
## 띄울 기구 종류 — `GymMachine.Kind`와 같은 번호(0 바벨 컬 / 1 스쿼트 / 2 런닝머신)
@export var machine_kind: int = 2
## 기구 그림과 그 배율·자리. **배율은 캐릭터와 같아야** 비율이 맞는다
@export var machine_texture: Texture2D
## 기구가 그림을 줄여 그리는 배율 — **맵에 놓인 기구와 같은 값**이어야 벨트 네모가 맞는다
@export var machine_size_scale: float = 0.1474
@export var machine_scale: Vector2 = Vector2(4, 4)
@export var machine_at: Vector2 = Vector2(-25, 260)
## 기구의 벨트 네모(런닝머신만) — 비워 두면 기구 기본값을 쓴다
@export var machine_belt_rect: Rect2 = Rect2(-74.9, -37, 162.5, 6.2)

## 손으로 집을 수 있는 조각들 — 포즈로 읽히는 이름과, 눈으로 맞추는 도구(바벨·원판)
const PART_NAMES: Array[String] = ["HandL", "HandR", "Body", "Head", "FootL", "FootR",
	"BarbellView", "SquatPlateView"]

## 지금 띄워 둔 움직이는 몸
var _rig: Node2D = null
## 운동 중인지(스페이스로 토글)
var _running: bool = true
## 편집 중인 자세(없으면 null)와 그 포즈 씬 경로
var _edit_node: Node2D = null
var _edit_path: String = ""
var _edit_label: String = ""
## 지금 집은 조각과, 집었을 때의 마우스-조각 거리
var _grabbed: Node2D = null
var _grab_offset: Vector2 = Vector2.ZERO
## 화면 위에 띄우는 안내·현재값
var _help: Label = null
var _info: Label = null
## 저장했다고 띄우는 글이 남아 있는 시간
var _saved_left: float = 0.0
## 지금 쓰는 바벨 배율(가로·세로) — 편집 모드에서 [ ] 로 바꾼다
var _bar_scale: Vector2 = Vector2.ZERO
## 띄워 둔 기구 — 크기·자리를 키로 맞춘다
var _machine: Node2D = null

func _ready() -> void:
	_build_backdrop()
	if show_machine:
		_build_machine()
	_build_rig()
	if show_frames:
		_build_frames()
	_build_labels()

## 밝은 배경판 — 제일 뒤에 깐다
func _build_backdrop() -> void:
	var rect := ColorRect.new()
	rect.color = backdrop
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer := CanvasLayer.new()
	layer.layer = -10
	layer.add_child(rect)
	add_child(layer)

## 기구를 캐릭터 **뒤에** 깐다 — 캐릭터가 기구 위 어디에 서는지 눈으로 맞추라고 띄운다.
## 리그보다 먼저 붙이므로 저절로 뒤에 깔린다
func _build_machine() -> void:
	var machine := Sprite2D.new()
	machine.set_script(load("res://maps/GymMachine.gd"))
	machine.kind = machine_kind
	machine.size_scale = machine_size_scale
	if machine_texture != null:
		machine.texture = machine_texture
	if machine_belt_rect.size.x > 0.0:
		machine.belt_rect = machine_belt_rect
	# 조정 씬에서는 **아무도 안 써도** 레일이 돌아야 어떻게 움직이는지 보인다
	machine.belt_always = true
	machine.position = machine_at
	machine.scale = machine_scale
	add_child(machine)
	_machine = machine

## 움직이는 몸 하나를 띄우고 바로 운동을 시작시킨다
func _build_rig() -> void:
	var scene: PackedScene = rig_scene if rig_scene != null else load("res://characters/akpeulleo/AkpeulleoRig.tscn")
	if scene == null:
		return
	_rig = scene.instantiate() as Node2D
	if _rig == null:
		return
	# **값은 붙이기 전에 다 넣는다** — 붙는 순간 _ready가 돌아서 나중에 넣으면 한 박자 늦는다
	var keys: Array = _rig_keys()
	for i in 3:
		if keys[i] in _rig:
			_rig.set(keys[i], [pose_a, pose_b, pose_c][i])
	var times: Array = _time_keys()
	var values: Array = [curl_cycle, curl_rise_ratio, curl_blend_time]
	for i in times.size():
		if times[i] != "" and times[i] in _rig:
			_rig.set(times[i], values[i])
	if motion == 0 and _rig.has_method("curl_bar_scale"):
		_bar_scale = _rig.curl_bar_scale()
	elif motion == 1 and _rig.has_method("squat_plate_size"):
		_bar_scale = _rig.squat_plate_size()
	_rig.position = rig_at
	_rig.scale = Vector2(-rig_scale if rig_flip else rig_scale, rig_scale)
	add_child(_rig)
	_set_motion(true)

## 자세 세 장을 정지로 늘어놓는다 — 어느 자세를 고쳐야 하는지 눈으로 고르라고
func _build_frames() -> void:
	var list: Array = _pose_list()
	for i in list.size():
		var item: Array = list[i]
		var at := Vector2((float(i) - 1.0) * frame_gap, frame_y)
		var scene: PackedScene = item[1]
		if scene != null:
			var node := _spawn_pose(scene, at, frame_scale)
			if node:
				node.name = "Frame%d" % i
		var label := Label.new()
		label.text = "%d. %s" % [i + 1, item[0]]
		label.position = at + Vector2(-40.0, 40.0)
		label.add_theme_color_override("font_color", Color(0.1, 0.12, 0.16))
		add_child(label)

## 포즈 씬 하나를 띄운다 — 배경판·안내선을 끄고 바벨을 두 손 사이로 옮겨 준다
func _spawn_pose(scene: PackedScene, at: Vector2, size_scale: float) -> Node2D:
	var node := scene.instantiate() as Node2D
	if node == null:
		return null
	# **포즈 씬이 각자 들고 있는 배경판·안내선을 끈다.**
	# 안 끄면 나중에 붙은 씬의 배경판이 앞서 붙은 씬과 움직이는 캐릭터를 덮어 버린다
	for key in ["show_backdrop", "show_guides"]:
		if key in node:
			node.set(key, false)
	if "alone_opens_scene" in node:
		node.alone_opens_scene = ""
	node.position = at
	node.scale = Vector2(size_scale, size_scale)
	add_child(node)
	_fit_barbell(node)
	return node

## [이름, 포즈 씬, 파일 경로] 세 줄
func _pose_list() -> Array:
	var names: Array = ["아래", "중간", "위"]
	if motion == 1:
		names = ["서기", "중간", "앉기"]
	elif motion == 2:
		names = ["왼발 앞", "두 발 모음", "오른발 앞"]
	return [
		[names[0], pose_a, _path_of(pose_a)],
		[names[1], pose_b, _path_of(pose_b)],
		[names[2], pose_c, _path_of(pose_c)],
	]

## 리그에 자세를 꽂을 때 쓰는 칸 이름
func _rig_keys() -> Array:
	if motion == 1:
		return ["squat_up_pose", "squat_mid_pose", "squat_down_pose"]
	if motion == 2:
		return ["run_left_pose", "run_mid_pose", "run_right_pose"]
	return ["curl_down_pose", "curl_mid_pose", "curl_up_pose"]

## 리그에 시간을 꽂을 때 쓰는 칸 이름
func _time_keys() -> Array:
	if motion == 1:
		return ["squat_cycle", "squat_fall_ratio", "squat_blend_time"]
	if motion == 2:
		# 런닝머신은 "올라가는 몫"이 없어서 가운데 칸을 안 쓴다
		return ["run_cycle", "", "run_blend_time"]
	return ["curl_cycle", "curl_rise_ratio", "curl_blend_time"]

## 운동을 켜고 끈다
func _set_motion(on: bool) -> void:
	if _rig == null or not is_instance_valid(_rig):
		return
	var fn: String = "set_curl"
	if motion == 1:
		fn = "set_squat"
	elif motion == 2:
		fn = "set_run"
	if _rig.has_method(fn):
		_rig.call(fn, on)

## 지금 모션에서 쓰는 도구(바벨/원판) 노드 이름
func _tool_name() -> String:
	if motion == 1:
		return "SquatPlateView"
	if motion == 2:
		return ""   # 런닝머신은 들고 있는 것이 없다
	return "BarbellView"

func _path_of(scene: PackedScene) -> String:
	return scene.resource_path if scene != null else ""

## 포즈 한 장의 바벨을 두 손 사이로 옮기고, 지금 쓰는 배율을 입힌다.
## `PosePreview`가 에디터에서만 도는 탓에, 게임으로 띄우면 바벨이 씬에 저장된 자리에 굳어 있다
func _fit_barbell(node: Node2D) -> void:
	if node == null:
		return
	if _tool_name() == "":
		return
	var bar: Node2D = node.get_node_or_null(_tool_name()) as Node2D
	if bar == null:
		return
	if _bar_scale.x > 0.0:
		bar.scale = _bar_scale
	# **스쿼트 원판은 자리도 포즈에 저장된다** — 손 사이로 끌어다 놓으면 안 된다
	if motion == 1:
		return
	var hand_l: Node2D = node.get_node_or_null("HandL") as Node2D
	var hand_r: Node2D = node.get_node_or_null("HandR") as Node2D
	if hand_l == null or hand_r == null:
		return
	bar.position = (hand_l.position + hand_r.position) * 0.5
	bar.rotation = (hand_r.position - hand_l.position).angle()

func _build_labels() -> void:
	_help = Label.new()
	_help.position = Vector2(-620.0, -330.0)
	_help.add_theme_color_override("font_color", Color(0.1, 0.12, 0.16))
	add_child(_help)
	_info = Label.new()
	_info.position = Vector2(-620.0, -290.0)
	_info.add_theme_color_override("font_color", Color(0.16, 0.08, 0.1))
	add_child(_info)
	_refresh_labels()

func _refresh_labels() -> void:
	if _help:
		_help.text = "스페이스: 멈춤/시작   R: 처음부터   1/2/3: 자세 고치기   0: 돌아가기"
		if _machine != null and _edit_node == null:
			_help.text += "   X/Y: 기구 가로·세로   [ / ]: 둘 다   방향키: 자리"
	if _info == null:
		return
	if _edit_node == null:
		if _machine != null:
			_info.text = "기구  Scale (%.3f, %.3f)   자리 (%.0f, %.0f)   X/Y 가로세로, [ ] 한꺼번에, 방향키 자리 (Shift=반대/크게)" % [
				machine_scale.x, machine_scale.y, machine_at.x, machine_at.y]
		elif _tool_name() == "":
			_info.text = "1/2/3 으로 자세를 고칠 수 있다"
		else:
			_info.text = "%s 크기 (%.4f, %.4f)  ([ / ] 로 조절, 2번(중간) 자세에서 S로 저장)" % [
				"원판" if motion == 1 else "바벨", _bar_scale.x, _bar_scale.y]
		return
	var line: String = "[%s 자세] 끌어서 옮기기 · Q/E 돌리기 · S 저장   %s (%.4f, %.4f)" % [
		_edit_label, "원판" if motion == 1 else "바벨", _bar_scale.x, _bar_scale.y]
	if _grabbed:
		line += "\n%s  위치 (%.1f, %.1f)  각도 %.1f도" % [
			_grabbed.name, _grabbed.position.x, _grabbed.position.y, rad_to_deg(_grabbed.rotation)]
	if _saved_left > 0.0:
		line += "\n>>> 저장함: " + _edit_path
	_info.text = line

## --- 편집 모드 ---

## 자세 한 장을 크게 띄우고 손으로 고칠 수 있게 한다
func _enter_edit(index: int) -> void:
	var item: Array = _pose_list()[index]
	if item[1] == null:
		return
	_leave_edit()
	_edit_label = item[0]
	_edit_path = item[2]
	# 움직이는 쪽과 정지 세 장은 잠깐 치운다 — 겹쳐 보이면 뭘 고치는지 헷갈린다
	_set_others_visible(false)
	_edit_node = _spawn_pose(item[1], edit_at, edit_scale)
	_refresh_labels()

func _leave_edit() -> void:
	if _edit_node and is_instance_valid(_edit_node):
		_edit_node.queue_free()
	_edit_node = null
	_grabbed = null
	_edit_path = ""
	_set_others_visible(true)
	_refresh_labels()

func _set_others_visible(on: bool) -> void:
	if _rig and is_instance_valid(_rig):
		_rig.visible = on
	for child in get_children():
		if child == _edit_node or child == _rig or child == _help or child == _info:
			continue
		if child is CanvasItem:
			child.visible = on

## 마우스에서 제일 가까운 조각을 집는다
func _grab_at(mouse: Vector2) -> void:
	if _edit_node == null:
		return
	var best: Node2D = null
	var best_d: float = INF
	for part_name in PART_NAMES:
		var part: Node2D = _edit_node.get_node_or_null(part_name) as Node2D
		if part == null:
			continue
		var d: float = part.global_position.distance_to(mouse)
		if d < best_d:
			best_d = d
			best = part
	# 너무 먼 데를 찍었으면 아무것도 안 집는다 — 빈 데를 끌다가 조각이 끌려오면 당황스럽다
	if best == null or best_d > 22.0 * edit_scale:
		return
	_grabbed = best
	_grab_offset = best.global_position - mouse
	_refresh_labels()

func _drag_to(mouse: Vector2) -> void:
	if _grabbed == null or _edit_node == null:
		return
	_grabbed.global_position = mouse + _grab_offset
	_fit_barbell(_edit_node)
	_refresh_labels()

## 고친 자세를 포즈 씬 파일에 덮어쓴다
func _save_edit() -> void:
	if _edit_node == null or _edit_path == "":
		return
	# 저장 전에 **보기용으로 바꿔 둔 것들을 되돌린다** — 배경판·안내선·F6 연결은 씬의 원래 값이어야 한다
	var keep_scale: Vector2 = _edit_node.scale
	var keep_pos: Vector2 = _edit_node.position
	for key in ["show_backdrop", "show_guides"]:
		if key in _edit_node:
			_edit_node.set(key, true)
	if "alone_opens_scene" in _edit_node:
		# **이 편집 씬 자신**을 적어 둔다 — 캐릭터별 편집 씬이 생겨서, 공용 씬 경로로 박아 두면
		# 저장하는 순간 그 자세의 F6가 엉뚱한 캐릭터 편집 씬으로 끌려간다(2026-10-06)
		var mine: String = scene_file_path
		_edit_node.alone_opens_scene = mine if mine != "" else "res://maps/GymCurlStudio.tscn"
	if "preview_scale" in _edit_node:
		_edit_node.scale = Vector2(_edit_node.preview_scale, _edit_node.preview_scale)
	_edit_node.position = Vector2.ZERO
	# 자식들이 이 씬에 속한 것으로 표시돼야 PackedScene에 담긴다
	for child in _edit_node.get_children():
		child.owner = _edit_node
	var packed := PackedScene.new()
	var err: int = packed.pack(_edit_node)
	if err == OK:
		err = ResourceSaver.save(packed, _edit_path)
	print("[저장] ", _edit_path, " 결과=", err)
	_saved_left = 2.0
	# 보기용 상태로 되돌려 계속 고칠 수 있게 한다
	for key in ["show_backdrop", "show_guides"]:
		if key in _edit_node:
			_edit_node.set(key, false)
	_edit_node.scale = keep_scale
	_edit_node.position = keep_pos
	_refresh_labels()

## --- 입력 ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_grab_at(get_global_mouse_position())
			else:
				_grabbed = null
		return
	if event is InputEventMouseMotion and _grabbed:
		_drag_to(get_global_mouse_position())
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = (event as InputEventKey).physical_keycode
	# **기구를 맞추는 키가 먼저다** — 기구가 떠 있고 자세를 고치는 중이 아닐 때만
	if _machine != null and _edit_node == null and _machine_key(key):
		return
	match key:
		KEY_SPACE:
			_running = not _running
			_set_motion(_running)
		KEY_R:
			_running = true
			_set_motion(false)
			_set_motion(true)
		KEY_1:
			_enter_edit(0)
		KEY_2:
			_enter_edit(1)
		KEY_3:
			_enter_edit(2)
		KEY_0:
			_leave_edit()
		KEY_S:
			_save_edit()
		KEY_Q, KEY_E:
			if _grabbed:
				_grabbed.rotation += deg_to_rad(2.0) * (-1.0 if key == KEY_Q else 1.0)
				_fit_barbell(_edit_node)
				_refresh_labels()
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
			var mul: float = (1.0 / maxf(bar_scale_step, 1.001)) if key == KEY_BRACKETLEFT else maxf(bar_scale_step, 1.001)
			_bar_scale *= mul
			_apply_bar_scale()
			_refresh_labels()

## 기구를 맞추는 키. 처리했으면 true.
##  **X / Y**: 가로·세로를 따로 줄인다(Shift를 같이 누르면 늘린다)
##  **[ / ]**: 가로세로를 한꺼번에
##  **방향키**: 자리를 1px씩(Shift면 10px씩)
func _machine_key(key: int) -> bool:
	var grow: bool = Input.is_key_pressed(KEY_SHIFT)
	var step: float = 1.03
	match key:
		KEY_X:
			_scale_machine(Vector2(step if grow else 1.0 / step, 1.0))
		KEY_Y:
			_scale_machine(Vector2(1.0, step if grow else 1.0 / step))
		KEY_BRACKETLEFT:
			_scale_machine(Vector2(1.0 / step, 1.0 / step))
		KEY_BRACKETRIGHT:
			_scale_machine(Vector2(step, step))
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			var move: float = 10.0 if grow else 1.0
			var d := Vector2.ZERO
			if key == KEY_LEFT:
				d.x = -move
			elif key == KEY_RIGHT:
				d.x = move
			elif key == KEY_UP:
				d.y = -move
			else:
				d.y = move
			machine_at += d
			_machine.position = machine_at
			_refresh_labels()
		_:
			return false
	return true

## 기구를 가로·세로 따로 늘렸다 줄인다. **노드 Scale을 쓰므로 벨트 네모도 저절로 같이 간다**
func _scale_machine(mul: Vector2) -> void:
	machine_scale = Vector2(maxf(machine_scale.x * mul.x, 0.01), maxf(machine_scale.y * mul.y, 0.01))
	_machine.scale = machine_scale
	_refresh_labels()

## 바뀐 바벨 크기를 움직이는 쪽·정지 세 장·편집 중인 자세에 모두 입힌다
func _apply_bar_scale() -> void:
	if _rig and is_instance_valid(_rig):
		if _tool_name() == "":
			return
		var bar: Node2D = _rig.get("_squat_plate" if motion == 1 else "_curl_bar") as Node2D
		if bar and is_instance_valid(bar):
			bar.scale = _bar_scale
	for child in get_children():
		if child is Node2D and child != _rig:
			_fit_barbell(child as Node2D)

func _process(delta: float) -> void:
	if _saved_left > 0.0:
		_saved_left = maxf(_saved_left - delta, 0.0)
		if is_zero_approx(_saved_left):
			_refresh_labels()
	queue_redraw()

## 땅 선 — 발이 바닥에 붙어 있는지 보려고
func _draw() -> void:
	var at: Vector2 = edit_at if _edit_node else rig_at
	var size_scale: float = edit_scale if _edit_node else rig_scale
	var y: float = at.y + ground_y * size_scale
	draw_line(Vector2(-320.0, y), Vector2(320.0, y), Color(0.10, 0.22, 0.34, 0.6), 2.0)
	draw_line(Vector2(at.x, y - 420.0), Vector2(at.x, y + 20.0), Color(0.72, 0.18, 0.30, 0.3), 1.5)
