class_name DriftingClouds
extends Node2D

## 스토리 장면 배경의 구름 — **자식 Sprite2D들을 전부 천천히 오른쪽으로 흘려보낸다.**
##
## 화면 오른쪽 밖으로 완전히 나간 구름은 화면 왼쪽 밖에서 다시 들어온다(끝없이 돈다).
## 화면 범위는 매 프레임 실제 뷰포트를 이 노드 좌표로 거꾸로 바꿔서 구하므로, 부모를 에디터에서 키우거나 옮겨도,
## 창 비율이 바뀌어도(stretch aspect = expand) 그대로 맞는다.
## 구름을 더 넣으려면 이 노드 밑에 Sprite2D를 하나 더 두기만 하면 된다.
## 에디터에선 안 움직인다(@tool 아님) — 배치는 에디터에서, 움직임은 실행해서 본다.
##
## 원본 캔버스 가장자리에서 잘린 구름은 노드 메타데이터 `cut_left` / `cut_right`를 true로 두면 단면을 흐린다(CloudEdge 셰이더).
## **처음엔 원본 그대로(흐림 0)** 두고, 잘린 단면이 화면 안으로 들어오는 만큼만 흐림 폭을 키운다 —
## 그림에 흐림을 미리 구워두면 시작 화면에서 화면 끝 구름이 깎여 보인다.
##  - cut_left: 오른쪽으로 가자마자 왼쪽 단면이 화면 안으로 들어오므로, 움직인 거리만큼 흐림이 자란다
##  - cut_right: 오른쪽 단면은 화면 밖으로 먼저 나가서 안 보이다가, 한 바퀴 돌아 왼쪽에서 다시 들어올 때
##    단면이 앞장서므로 그때부터 흐린다

## 흘러가는 속도(이 노드 좌표 기준 px/초 — 경찰서 그림 원본 픽셀 단위, 화면에선 0.83배)
@export var speed: float = 14.0
## 잘린 단면을 흐리는 최대 폭(px, 구름 그림 기준). 줄마다 이 값의 0.2~1.8배로 울퉁불퉁하다
@export var edge_fade: float = 60.0
## 움직인 거리 1px당 흐림 폭이 자라는 양 — 1보다 커야 단면이 화면에 드러나기 전에 흐려진다
@export var edge_fade_growth: float = 1.5
@export var edge_shader: Shader = preload("res://ui/story/CloudEdge.gdshader")

var _clouds: Array[Sprite2D] = []
var _start_x: Array[float] = []
## 잘린 구름만 머티리얼이 있고 나머지는 null
var _materials: Array[ShaderMaterial] = []
var _time: float = 0.0

func _ready() -> void:
	for child in get_children():
		if child is Sprite2D:
			var cloud: Sprite2D = child
			_clouds.append(cloud)
			_start_x.append(cloud.position.x)
			var mat: ShaderMaterial = null
			if cloud.get_meta("cut_left", false) or cloud.get_meta("cut_right", false):
				mat = ShaderMaterial.new()
				mat.shader = edge_shader
				cloud.material = mat
			_materials.append(mat)

func _process(delta: float) -> void:
	_time += delta
	# 화면 왼쪽·오른쪽 끝을 이 노드 좌표로 바꾼다
	var to_local_xf: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var view: Vector2 = get_viewport_rect().size
	var left: float = (to_local_xf * Vector2.ZERO).x
	var right: float = (to_local_xf * Vector2(view.x, 0.0)).x
	var travel: float = speed * _time
	for i in _clouds.size():
		var cloud: Sprite2D = _clouds[i]
		var rect: Rect2 = cloud.get_rect()
		var edge_offset: float = rect.position.x * cloud.scale.x   # 노드 위치 -> 구름 왼쪽 끝까지 거리
		var width: float = rect.size.x * cloud.scale.x
		# 구름 왼쪽 끝이 [left - width, right) 사이를 돈다 — 오른쪽 밖으로 다 나가면 왼쪽 밖에 붙어서 다시 들어온다
		var span: float = right - left + width
		var raw: float = _start_x[i] + edge_offset + travel
		var edge: float = left - width + fposmod(raw - (left - width), span)
		cloud.position.x = edge - edge_offset

		var mat: ShaderMaterial = _materials[i]
		if mat == null:
			continue
		var wrapped: bool = raw - edge > 1.0   # 한 바퀴 이상 돌아서 왼쪽에서 다시 들어왔다
		var fade_l: float = minf(travel * edge_fade_growth, edge_fade) if cloud.get_meta("cut_left", false) else 0.0
		var fade_r: float = edge_fade if (wrapped and cloud.get_meta("cut_right", false)) else 0.0
		mat.set_shader_parameter("fade_left", fade_l)
		mat.set_shader_parameter("fade_right", fade_r)
