extends Node2D

## **헬스장 배경 보기 씬** — `maps/GymBackdropLayers.tscn`을 맵과 **똑같은 치수** 위에 올려 놓고,
## 기구와 캐릭터까지 세워서 크기·자리가 맞는지 눈으로 본다. F6으로 열면 바로 뜬다.
##
## ⚠️ 배경을 **고치는 곳은 여기가 아니라** `maps/GymBackdropLayers.tscn`이다. 거기서 노드를 끌어
## 옮기고 저장하면 이 씬과 실제 대전 양쪽에 그대로 반영된다 — 둘 다 같은 씬을 띄우기 때문이다.
##
## 예전에는 이 씬이 배경을 코드로 만들어 냈는데, 그러면 에디터에서 집어 옮길 수가 없어서
## 실제 노드가 박힌 씬으로 바꿨다(2026-10-06 사용자 요청).
##
## 조작
##   방향키      : 카메라 옮기기(Shift면 크게)
##   마우스 휠   : 당기고 밀기

## 띄울 배경 씬. 비워 두면 `maps/GymBackdropLayers.tscn`을 쓴다
@export var backdrop_scene: PackedScene

@export_group("맵 치수 (Gym.tscn과 맞출 것)")
## 1층 바닥 윗면 y
@export var ground_y: float = 280.0
## 2층 슬래브 윗면 y
@export var upper_y: float = 100.0
## 2층 슬래브가 걸쳐 있는 좌우 끝
@export var upper_half_width: float = 640.0
## 벽 안쪽 좌우 끝
@export var wall_half_width: float = 1228.0

@export_group("견주개")
## **크기를 견주려고 세워 둘 캐릭터** 자리. 네모를 깔아 두니 배경 건물과 색이 비슷해
## 기둥처럼 보여서, 진짜 몸을 세운다(2026-10-06)
@export var dummy_spots: PackedVector2Array = PackedVector2Array([
	Vector2(-500.0, 280.0), Vector2(320.0, 100.0), Vector2(500.0, 280.0)])
## 세울 캐릭터의 몸 장면. 비워 두면 악플러를 쓴다
@export var dummy_rig: PackedScene
## 기구를 어디에 놓고 볼지
@export var curl_spot: Vector2 = Vector2(-900.0, 280.0)
@export var squat_spot: Vector2 = Vector2(900.0, 280.0)
@export var treadmill_spot: Vector2 = Vector2(0.0, 100.0)

@export_group("카메라")
@export var zoom: float = 0.7
@export var camera_y: float = 55.0

var _camera: Camera2D = null

func _ready() -> void:
	_build_backdrop()
	_build_stage()
	_build_machines()
	_build_dummies()
	_camera = Camera2D.new()
	_camera.zoom = Vector2(zoom, zoom)
	_camera.position = Vector2(0.0, camera_y)
	add_child(_camera)
	_camera.make_current()

## 배경은 **만들지 않고 띄우기만 한다** — 실제 맵이 쓰는 바로 그 씬이다
func _build_backdrop() -> void:
	var packed: PackedScene = backdrop_scene
	if packed == null:
		packed = load("res://maps/GymBackdropLayers.tscn")
	if packed == null:
		return
	add_child(packed.instantiate())

# --------------------------------- 맵 치수 ---------------------------------

## 바닥·2층·벽을 맵과 같은 자리에 그린다. 배경보다 **앞**에 와야
## 창틀이나 벽이 2층을 얼마나 가리는지 보인다
func _build_stage() -> void:
	_fill(PackedVector2Array([
		Vector2(-3000, ground_y), Vector2(3000, ground_y), Vector2(3000, 2400), Vector2(-3000, 2400)]),
		Color(0.0941, 0.0941, 0.0941))
	_fill(PackedVector2Array([
		Vector2(-upper_half_width, upper_y), Vector2(upper_half_width, upper_y),
		Vector2(upper_half_width, upper_y + 22.0), Vector2(-upper_half_width, upper_y + 22.0)]),
		Color(0.2196, 0.2235, 0.2588))
	for x in [-wall_half_width, wall_half_width]:
		_line(Vector2(x, ground_y), Vector2(x, ground_y - 900.0), Color(0.5, 0.52, 0.6, 0.7), 4.0)
	_line(Vector2(-upper_half_width, upper_y), Vector2(upper_half_width, upper_y),
		Color(0.6, 0.63, 0.71), 4.0)

func _fill(points: PackedVector2Array, color: Color) -> void:
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = color
	add_child(poly)

func _line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.default_color = color
	line.width = width
	add_child(line)

## 기구 한 벌을 맵 씬에서 떠다 놓는다 — 배경이 기구를 얼마나 먹는지 같이 봐야 한다
func _build_machines() -> void:
	var map: Node = load("res://maps/Gym.tscn").instantiate()
	var equipment: Node = map.get_node_or_null("Equipment")
	if equipment:
		var spots := {"BarbellCurl": curl_spot, "Squat": squat_spot, "Treadmill": treadmill_spot}
		for child in equipment.get_children():
			if not (child is GymMachine) or not spots.has(child.name):
				continue
			child.owner = null   # 떼기 전에 풀어 둬야 "주인이 안 맞는다" 경고가 안 뜬다
			equipment.remove_child(child)
			child.position = spots[child.name] + Vector2(0.0, child.ground_sink)
			add_child(child)
	map.queue_free()

func _build_dummies() -> void:
	var rig_scene: PackedScene = dummy_rig
	if rig_scene == null:
		rig_scene = load("res://characters/akpeulleo/AkpeulleoRig.tscn")
	if rig_scene == null:
		return
	for spot in dummy_spots:
		var rig: Node2D = rig_scene.instantiate()
		# 몸의 원점은 발보다 30px쯤 위에 있다 — 그만큼 올려야 바닥을 딛고 선 꼴이 된다
		rig.position = spot - Vector2(0.0, 30.0)
		add_child(rig)

# --------------------------------- 조작 ---------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _camera == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.zoom *= 1.1
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.zoom /= 1.1
		return
	if not (event is InputEventKey) or not event.pressed:
		return
	var key := event as InputEventKey
	var step: float = 120.0 if key.shift_pressed else 40.0
	match key.keycode:
		KEY_LEFT:
			_camera.position.x -= step
		KEY_RIGHT:
			_camera.position.x += step
		KEY_UP:
			_camera.position.y -= step
		KEY_DOWN:
			_camera.position.y += step
