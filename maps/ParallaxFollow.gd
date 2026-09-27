extends Node2D

## 붙인 노드(층)를 카메라 움직임에 비례해 덜/더 움직여 거리감을 준다(parallax, 2026-09-26).
## factor 1 = 싸우는 층과 같이 움직임 / 1보다 작으면 덜 움직여 멀리 있는 것처럼 / 크면 앞에 있는 것처럼.
## 카메라 화면 중심이 reference에 있을 때 에디터에 놓인 그대로 보이고, 거기서 벗어난 만큼만 밀린다.
## 지하철 맵 뒷벽(DecoBackground)에 붙어 있다. 앞 기둥(ForegroundPillars)도 같은 식을 쓴다

## 이 층이 카메라를 따라 움직이는 비율
@export var factor: Vector2 = Vector2(0.8, 0.8)
## 기준 카메라 중심 — 카메라가 여기 있으면 이 층은 제자리
@export var reference: Vector2 = Vector2(0.0, 150.0)

var _rest: Vector2

func _ready() -> void:
	_rest = position

func _process(_delta: float) -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	var offset: Vector2 = cam.get_screen_center_position() - reference
	position = _rest + offset * (Vector2.ONE - factor)
