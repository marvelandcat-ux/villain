@tool
extends Node2D

## **배경 전체의 가로 폭을 한 손잡이로 늘리고 줄인다** — 맵 폭을 바꿨을 때 창·벽·도시를
## 하나씩 다시 끌어 놓지 않아도 되게 만든 것이다(2026-10-06 사용자 요청).
##
## 각 노드가 처음 있던 자리를 기억해 두고 거기에 배수를 곱한다. 그래서 값을 여러 번 바꿔도
## 누적되지 않고, 1로 되돌리면 원래대로 돌아온다.
##
## **창 한 칸의 크기는 안 건드린다** — 창이 커지면 캐릭터와의 비율이 깨지기 때문이다.
## 가로로 더 넓어지면 창 **사이가 벌어지고**, 벽이 그만큼 더 깔린다.
##
## 창 칸 수까지 바꾸고 싶으면 `Frame*` 노드를 직접 복사하거나 지우면 된다

## 배경이 덮는 **가로 폭 배수**. 1이면 지금 만들어 둔 그대로다
@export var width_scale: float = 1.0:
	set(value):
		width_scale = maxf(value, 0.05)
		_apply()
## 창 **사이 간격**만 따로 늘리고 싶을 때. 위의 가로 배수에 곱해진다
@export var window_gap_scale: float = 1.0:
	set(value):
		window_gap_scale = maxf(value, 0.05)
		_apply()
## 창 **한 칸의 크기** 배수. 캐릭터와의 비율이 걸려 있으니 함부로 키우지 말 것
@export var window_size_scale: float = 1.0:
	set(value):
		window_size_scale = maxf(value, 0.05)
		_apply()

## 처음 값 — [창 x], [창 scale], [벽 네모], [도시 자리·크기·폭]
var _base_frame_x: Dictionary = {}
var _base_frame_scale: Dictionary = {}
var _base_wall: Dictionary = {}
var _base_city: Array = []

func _ready() -> void:
	_remember()
	_apply()

## 노드마다 **처음 자리**를 한 번만 적어 둔다. 이게 없으면 배수를 곱할 때마다 누적된다
func _remember() -> void:
	_base_frame_x.clear()
	_base_frame_scale.clear()
	_base_wall.clear()
	_base_city.clear()
	for child in get_children():
		var key: int = child.get_instance_id()
		if child.name.begins_with("Frame") and child is Node2D:
			_base_frame_x[key] = (child as Node2D).position.x
			_base_frame_scale[key] = (child as Node2D).scale
		elif child.name.begins_with("Wall") and child is Control:
			var box: Control = child
			_base_wall[key] = Rect2(box.offset_left, box.offset_top,
				box.offset_right - box.offset_left, box.offset_bottom - box.offset_top)
		elif child.name == "City" and child is Sprite2D:
			var city: Sprite2D = child
			_base_city = [city.position.x, city.scale.x, city.region_rect.size.x]

func _apply() -> void:
	if not is_inside_tree():
		return
	if _base_frame_x.is_empty() and _base_wall.is_empty():
		_remember()
	var gap: float = width_scale * window_gap_scale
	for child in get_children():
		var key: int = child.get_instance_id()
		if _base_frame_x.has(key):
			# 창은 **자리만** 벌어지고 크기는 따로 논다
			(child as Node2D).position.x = _base_frame_x[key] * gap
			(child as Node2D).scale = _base_frame_scale[key] * window_size_scale
		elif _base_wall.has(key):
			var box: Rect2 = _base_wall[key]
			var node: Control = child
			node.offset_left = box.position.x * width_scale
			node.offset_right = box.end.x * width_scale
		elif child.name == "City" and not _base_city.is_empty():
			var city: Sprite2D = child
			city.position.x = _base_city[0] * width_scale
			# 도시는 좌우로 이어지는 그림이라, **잘라 내는 폭만 늘리면** 그만큼 더 반복된다
			city.region_rect.size.x = _base_city[2] * width_scale
	queue_redraw()

## 창을 옮기거나 지운 뒤, 그 상태를 **새 기준**으로 삼고 싶을 때 부른다
func rebase() -> void:
	width_scale = 1.0
	window_gap_scale = 1.0
	window_size_scale = 1.0
	_remember()
