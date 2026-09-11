class_name DriftingClouds
extends Node2D

## 스토리 장면 배경의 구름 — **자식 Sprite2D들을 전부 천천히 오른쪽으로 흘려보낸다.**
##
## 화면 오른쪽 밖으로 완전히 나간 구름은 화면 왼쪽 밖에서 다시 들어온다(끝없이 돈다).
## 화면 범위는 매 프레임 실제 뷰포트를 이 노드 좌표로 거꾸로 바꿔서 구하므로, 부모를 에디터에서 키우거나 옮겨도,
## 창 비율이 바뀌어도(stretch aspect = expand) 그대로 맞는다.
## 구름을 더 넣으려면 이 노드 밑에 Sprite2D를 하나 더 두기만 하면 된다.
## 에디터에선 안 움직인다(@tool 아님) — 배치는 에디터에서, 움직임은 실행해서 본다.

## 흘러가는 속도(이 노드 좌표 기준 px/초 — 경찰서 그림 원본 픽셀 단위, 화면에선 0.83배)
@export var speed: float = 14.0

var _clouds: Array[Sprite2D] = []
var _start_x: Array[float] = []
var _time: float = 0.0

func _ready() -> void:
	for child in get_children():
		if child is Sprite2D:
			_clouds.append(child)
			_start_x.append(child.position.x)

func _process(delta: float) -> void:
	_time += delta
	# 화면 왼쪽·오른쪽 끝을 이 노드 좌표로 바꾼다
	var to_local_xf: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var view: Vector2 = get_viewport_rect().size
	var left: float = (to_local_xf * Vector2.ZERO).x
	var right: float = (to_local_xf * Vector2(view.x, 0.0)).x
	for i in _clouds.size():
		var cloud: Sprite2D = _clouds[i]
		var rect: Rect2 = cloud.get_rect()
		var edge_offset: float = rect.position.x * cloud.scale.x   # 노드 위치 -> 구름 왼쪽 끝까지 거리
		var width: float = rect.size.x * cloud.scale.x
		# 구름 왼쪽 끝이 [left - width, right) 사이를 돈다 — 오른쪽 밖으로 다 나가면 왼쪽 밖에 붙어서 다시 들어온다
		var span: float = right - left + width
		var edge: float = _start_x[i] + edge_offset + speed * _time
		edge = left - width + fposmod(edge - (left - width), span)
		cloud.position.x = edge - edge_offset
