class_name StoryZoomView
extends Node2D

## 스토리 장면의 "카메라" — 그림 한 장(과 그 위 레이어들)을 화면에 꽉 채우고, **아주 천천히 확대**한다.
##
## 이 노드 밑의 모든 것이 원본 그림 픽셀 좌표로 놓여 있고, 이 노드가 통째로 키우고 옮긴다.
## `pivot`(그림 좌표)이 항상 화면 가운데에 오게 한다.
## 1.0배가 아니라 `zoom_from`(1.05배)부터 시작하는 이유: 화면 밖으로 위아래 수십 px씩 여유가 생겨서,
## 캔버스 아래 끝에서 잘린 사람이 위로 조금 걸어가도 잘린 단면이 화면에 안 드러난다.
## 창 비율이 16:9가 아니어도(stretch aspect = expand) 빈틈 없이 덮도록 매 프레임 뷰포트로 다시 맞춘다.

## 원본 그림 크기(px)
@export var canvas_size: Vector2 = Vector2(1672, 941)
## 화면 가운데에 고정할 그림 좌표
@export var pivot: Vector2 = Vector2(836, 470.5)
## 시작 배율(화면을 꽉 채우는 크기 기준)
@export var zoom_from: float = 1.05
## 끝 배율
@export var zoom_to: float = 1.08
## 확대에 걸리는 시간(초). 끝나면 그 배율로 멈춘다
@export var zoom_time: float = 8.0

var _t: float = 0.0

func _ready() -> void:
	_apply()

func _process(delta: float) -> void:
	_t += delta
	_apply()

func _apply() -> void:
	var view: Vector2 = get_viewport_rect().size
	var fit: float = maxf(view.x / canvas_size.x, view.y / canvas_size.y)
	var u: float = clampf(_t / maxf(zoom_time, 0.01), 0.0, 1.0)
	var eased: float = 0.5 - 0.5 * cos(u * PI)   # 천천히 시작해서 천천히 멈춘다
	var s: float = fit * lerpf(zoom_from, zoom_to, eased)
	scale = Vector2(s, s)
	position = view * 0.5 - pivot * s
