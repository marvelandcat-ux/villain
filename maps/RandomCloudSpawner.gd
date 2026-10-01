extends Node2D

## 구름을 랜덤으로 계속 만들어 왼쪽 → 오른쪽으로 흘려보낸다(튜토리얼 맵, 2026-10-01).
## 매번 textures 중 하나를 골라 크기·높이·속도·좌우 반전을 랜덤으로 정하고, 화면 왼쪽 밖에서 출발해
## 오른쪽 밖으로 다 나가면 지운다. 화면 범위는 매 프레임 이 노드 좌표로 다시 구하므로
## 부모에 ParallaxFollow가 붙어 있어도 맞는다

## 고를 구름 그림들
@export var textures: Array[Texture2D] = []
## 크기 배율 범위(최소, 최대)
@export var scale_range: Vector2 = Vector2(0.25, 0.42)
## 구름 중심 높이 범위(이 노드 좌표, 위가 음수)
@export var y_range: Vector2 = Vector2(-170.0, -40.0)
## 흘러가는 속도 범위(px/초)
@export var speed_range: Vector2 = Vector2(12.0, 30.0)
## 다음 구름이 나올 때까지 간격 범위(초)
@export var spawn_interval: Vector2 = Vector2(5.0, 10.0)
## 시작할 때 화면 안에 미리 깔아 둘 구름 수
@export var start_count: int = 4

var _clouds: Array[Sprite2D] = []
var _speeds: Array[float] = []
var _spawn_left: float = 0.0
var _last_texture: int = -1
## 첫 _process에서 화면 범위를 알 수 있을 때 미리 깔기
var _initialized: bool = false

func _process(delta: float) -> void:
	var view: Vector2 = _view_x()
	if not _initialized:
		_initialized = true
		for i in start_count:
			_spawn(randf_range(view.x, view.y))
		_spawn_left = randf_range(spawn_interval.x, spawn_interval.y)

	_spawn_left -= minf(delta, 0.05)
	if _spawn_left <= 0.0:
		_spawn_left = randf_range(spawn_interval.x, spawn_interval.y)
		_spawn(view.x, true)

	for i in range(_clouds.size() - 1, -1, -1):
		var cloud: Sprite2D = _clouds[i]
		cloud.position.x += _speeds[i] * delta
		if cloud.position.x - _half_width(cloud) > view.y:
			cloud.queue_free()
			_clouds.remove_at(i)
			_speeds.remove_at(i)

## 화면 왼쪽·오른쪽 끝의 x (이 노드 좌표)
func _view_x() -> Vector2:
	var to_local_xf: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var view_w: float = get_viewport_rect().size.x
	return Vector2((to_local_xf * Vector2.ZERO).x, (to_local_xf * Vector2(view_w, 0.0)).x)

## x에 구름 하나를 만든다. off_left면 x를 왼쪽 끝으로 보고 구름 전체가 화면 밖에 있게 민다
func _spawn(x: float, off_left: bool = false) -> void:
	if textures.is_empty():
		return
	var index: int = randi() % textures.size()
	# 바로 앞 구름과 같은 그림은 피한다
	if textures.size() > 1 and index == _last_texture:
		index = (index + 1 + randi() % (textures.size() - 1)) % textures.size()
	_last_texture = index
	var cloud := Sprite2D.new()
	cloud.texture = textures[index]
	cloud.scale = Vector2.ONE * randf_range(scale_range.x, scale_range.y)
	cloud.flip_h = randf() < 0.5
	add_child(cloud)
	if off_left:
		x -= _half_width(cloud)
	cloud.position = Vector2(x, randf_range(y_range.x, y_range.y))
	_clouds.append(cloud)
	_speeds.append(randf_range(speed_range.x, speed_range.y))

func _half_width(cloud: Sprite2D) -> float:
	return cloud.texture.get_width() * cloud.scale.x * 0.5
