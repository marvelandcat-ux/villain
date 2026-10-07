extends Control

## **사건 파일 한 장** — 부모 칸 안에 **비율을 지킨 채 꽉 맞춰 가운데** 놓는다
## (예전 사건 파일 그림의 TextureRect "비율 유지 + 가운데"와 같은 모양).
## 사진·글자·도장은 전부 이 종이 크기(`sheet_size`) 기준 좌표라 화면 비율이 달라도(21:9 등) 자리가 안 어긋난다.
## 글자를 고치려면 이 씬(`AkpeulleoCaseFile.tscn`)을 열어 라벨을 바로 고치면 된다

## 종이 그림(사건파일양식.png) 크기
@export var sheet_size: Vector2 = Vector2(1748, 900)

func _ready() -> void:
	var parent := get_parent() as Control
	if parent == null:
		return
	parent.resized.connect(_fit)
	_fit()

func _fit() -> void:
	var parent := get_parent() as Control
	if parent == null or sheet_size.x <= 0.0 or sheet_size.y <= 0.0:
		return
	var area: Vector2 = parent.size
	var k: float = minf(area.x / sheet_size.x, area.y / sheet_size.y)
	size = sheet_size
	scale = Vector2(k, k)
	position = (area - sheet_size * k) * 0.5
