@tool
extends Node2D

## **헬스장 크기 맞추기 씬의 안내선** — 바닥·2층 슬래브·벽을 맵과 같은 자리에 그린다.
##
## `@tool`이라 **에디터에서도 그려진다**. 그래야 기구나 캐릭터를 끌어 놓으면서
## "발이 바닥에 닿았나", "2층에 머리가 걸리나"를 바로 볼 수 있다.
##
## 치수는 `maps/Gym.tscn`에서 그대로 옮겨 온 것이다 — 저쪽을 고치면 여기도 고쳐야 한다

## 1층 바닥 윗면 y
@export var ground_y: float = 430.0:
	set(value):
		ground_y = value
		queue_redraw()
## 2층 슬래브 윗면 y와 두께
@export var upper_y: float = 100.0:
	set(value):
		upper_y = value
		queue_redraw()
@export var upper_thickness: float = 22.0:
	set(value):
		upper_thickness = value
		queue_redraw()
## 2층 슬래브가 걸쳐 있는 좌우 끝
@export var upper_half_width: float = 640.0:
	set(value):
		upper_half_width = value
		queue_redraw()
## 벽 안쪽 좌우 끝
@export var wall_half_width: float = 1228.0:
	set(value):
		wall_half_width = value
		queue_redraw()

@export_group("크기 맞추기")
## **세워 둔 캐릭터 전부**를 한꺼번에 키우고 줄인다. 1이면 지금 크기 그대로다.
## 여기서 맞춘 값을 실제 대전에 넣으려면 `maps/Stage.gd`의 `fighter_visual_scale`에 적어 주면 된다
@export var character_scale: float = 1.0:
	set(value):
		character_scale = maxf(value, 0.05)
		_apply_sizes()
## **기구 전부**를 한꺼번에 키우고 줄인다. 기구마다 원래 크기가 다르므로 **배수**로 곱한다.
## 맞춘 뒤에는 기구별 `size_scale`에 곱해서 `maps/Gym.tscn`에 적어 넣으면 된다
@export var machine_scale: float = 1.0:
	set(value):
		machine_scale = maxf(value, 0.05)
		_apply_sizes()

@export_group("눈금")
## **캐릭터 키 눈금**(px). 지금 캐릭터가 대략 이만하다 — 기구를 이 높이에 견주면 된다
@export var body_height: float = 125.0:
	set(value):
		body_height = value
		queue_redraw()
## 눈금을 세울 자리들
@export var ruler_spots: PackedFloat32Array = PackedFloat32Array([-1100.0, 1100.0]):
	set(value):
		ruler_spots = value
		queue_redraw()

@export_group("색")
@export var floor_color: Color = Color(0.0941, 0.0941, 0.0941, 1.0)
@export var slab_color: Color = Color(0.2196, 0.2235, 0.2588, 1.0)
@export var line_color: Color = Color(0.6, 0.63, 0.71, 1.0)
@export var ruler_color: Color = Color(0.95, 0.75, 0.25, 0.55)

## 처음 크기를 기억해 둔다 — 배수를 곱할 때마다 누적되면 안 된다
var _base_body: Dictionary = {}
var _base_machine: Dictionary = {}

func _ready() -> void:
	_remember()
	_apply_sizes()

## 자식들의 **원래 크기**를 한 번만 적어 둔다
func _remember() -> void:
	for child in get_children():
		if child is GymMachine:
			_base_machine[child.get_instance_id()] = child.size_scale
		elif child is Node2D and child.has_method("read_pose"):
			_base_body[child.get_instance_id()] = child.scale

func _apply_sizes() -> void:
	if not is_inside_tree():
		return
	if _base_body.is_empty() and _base_machine.is_empty():
		_remember()
	for child in get_children():
		var key: int = child.get_instance_id()
		if child is GymMachine and _base_machine.has(key):
			child.size_scale = _base_machine[key] * machine_scale
		elif _base_body.has(key):
			child.scale = _base_body[key] * character_scale
	queue_redraw()

func _draw() -> void:
	# 1층 바닥
	draw_rect(Rect2(-3000.0, ground_y, 6000.0, 2000.0), floor_color)
	# 2층 슬래브
	draw_rect(Rect2(-upper_half_width, upper_y, upper_half_width * 2.0, upper_thickness), slab_color)
	draw_line(Vector2(-upper_half_width, upper_y), Vector2(upper_half_width, upper_y), line_color, 4.0)
	# 벽 안쪽 끝
	for x in [-wall_half_width, wall_half_width]:
		draw_line(Vector2(x, ground_y), Vector2(x, ground_y - 900.0), Color(0.5, 0.52, 0.6, 0.7), 4.0)
	_draw_rulers()

## 캐릭터 키만 한 막대를 세워 둔다 — 기구가 사람보다 큰지 작은지 바로 보인다
func _draw_rulers() -> void:
	if body_height <= 0.0:
		return
	for x in ruler_spots:
		for base_y in [ground_y, upper_y]:
			var h: float = body_height * character_scale
			draw_rect(Rect2(x - 12.0, base_y - h, 24.0, h), ruler_color)
			draw_line(Vector2(x - 26.0, base_y - h), Vector2(x + 26.0, base_y - h), ruler_color, 2.0)
