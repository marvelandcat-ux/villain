class_name MenuIllust
extends Node2D

## 메인 메뉴 오른쪽에 서 있는 캐릭터 일러스트. 포토샵에서 나눈 파츠를 코드로 따로 움직인다.
##
## 파츠는 전부 **같은 캔버스 크기(1230x1428)** 로 내보낸 그림이라, 각 Sprite2D는 centered = false에
## position = -축좌표로 두면 원본과 픽셀 단위로 같은 자리에 그려진다.
## 그 Sprite2D를 감싼 Node2D(= 축)를 돌리면 원하는 지점을 중심으로 회전한다.
##  - 몸통: 두 발 사이를 축으로 세로로만 아주 살짝 늘었다 줄었다 (숨쉬기). 발이 안 뜬다
##  - 아래쪽옷: 몸에 붙는 윗변을 축으로 살랑거림
##  - 머리: 목을 축으로 살짝 갸웃 + 숨결에 맞춰 미세하게 오르내림
##  - 띠 3조각: 묶인 지점을 축으로, 조각마다 시간차를 두고 흔들려 물결처럼 이어진다
##
## 메뉴가 뜨는 순간부터 계속 아래 숨쉬기를 돈다 (따로 시작 신호를 받지 않는다).

## 한 호흡에 걸리는 시간(초). 모든 움직임이 이 주기를 공유한다
@export var period: float = 3.6

@export_group("몸통")
## 숨 들이쉴 때 세로로 늘어나는 비율 (0.01 = 1%)
@export_range(0.0, 0.1, 0.002) var breath_stretch: float = 0.012

@export_group("머리")
## 목을 축으로 갸웃거리는 최대 각도(도)
@export var head_tilt_deg: float = 1.2
## 숨결에 맞춰 오르내리는 폭(px, 원본 그림 기준)
@export var head_bob: float = 5.0
## 몸통보다 얼마나 늦게 따라오는지 (한 주기 대비 비율)
@export_range(0.0, 1.0, 0.01) var head_delay: float = 0.12

@export_group("아래쪽옷")
## 살랑거리는 최대 각도(도)
@export var cloth_tilt_deg: float = 1.0
@export_range(0.0, 1.0, 0.01) var cloth_delay: float = 0.2

@export_group("머리띠")
## 띠가 흔들리는 최대 각도(도)
@export var ribbon_tilt_deg: float = 4.5
## 조각 사이의 시간차 (한 주기 대비 비율). 0이면 세 조각이 똑같이 움직여서 뻣뻣해 보인다
@export_range(0.0, 0.5, 0.01) var ribbon_delay: float = 0.16
## 띠는 몸보다 빠르게 팔랑거린다 (주기 배수)
@export var ribbon_speed: float = 1.7

@onready var _body: Node2D = $Body
@onready var _cloth: Node2D = $LowerCloth
@onready var _head: Node2D = $Head
@onready var _ribbons: Array[Node2D] = [$RibbonBottom, $RibbonMiddle, $RibbonTop]

var _time: float = 0.0
var _head_rest: Vector2

func _ready() -> void:
	_head_rest = _head.position

## 원본 그림 한 장의 크기. 메인 메뉴가 이걸 보고 배율·위치를 계산한다
func get_image_size() -> Vector2:
	var sprite: Sprite2D = $Body/Sprite
	return sprite.texture.get_size() if sprite.texture else Vector2(1230, 1428)

## 다른 일러스트에서 넘어와 화면에 나타난 순간 호출한다. 숨결을 처음부터 다시 센다
func restart() -> void:
	_time = 0.0

func _process(delta: float) -> void:
	_time += delta
	var w: float = TAU / maxf(period, 0.01)

	# 숨을 들이쉬면(사인이 +) 몸이 세로로 살짝 늘어난다. 축이 발이라 위로만 자란다
	var breath: float = sin(_time * w)
	_body.scale = Vector2(1.0, 1.0 + breath_stretch * breath)

	# 옷·머리는 같은 숨결을 조금 늦게 받는다 — 동시에 움직이면 통짜로 보인다
	_cloth.rotation = deg_to_rad(cloth_tilt_deg) * sin((_time - period * cloth_delay) * w)
	var head_phase: float = (_time - period * head_delay) * w
	_head.rotation = deg_to_rad(head_tilt_deg) * sin(head_phase)
	_head.position = _head_rest + Vector2(0.0, -head_bob * 0.5 * (1.0 + sin(head_phase)))

	# 띠는 조각마다 한 박자씩 늦게 흔들려서 뿌리에서 끝으로 물결이 지나간다
	for i in range(_ribbons.size()):
		var phase: float = (_time - period * ribbon_delay * float(i)) * w * ribbon_speed
		_ribbons[i].rotation = deg_to_rad(ribbon_tilt_deg) * sin(phase)
