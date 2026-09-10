class_name SubwayIllust
extends Node2D

## 메인 메뉴에 서 있는 지하철 아저씨 일러스트. 캣맘·주정꾼·잼민이와 같은 파츠 방식이다.
##
## 달려들며 소리치는 포즈라 다른 셋처럼 "가만히 숨쉬는" 느낌이 아니라 **들썩이며 위협하는** 느낌으로 잡았다:
##  - 몸: 발을 축으로 세로로 늘었다 줄고(숨), 아주 조금 좌우로 기운다
##  - 단소 든 팔: 팔뚝 단면을 축으로 까딱까딱 — 단소 끝이 축에서 636px이라 1도만 돌려도 끝이 11px 움직인다
##  - 뻗은 손: 손목을 축으로 **커졌다 제자리로** 돌아온다 (앞으로 들이미는 느낌)
##  - 조끼 자락: 어깨를 축으로 살랑
##  - 머리카락: 머리를 축으로 아주 조금
##
## **눈 깜빡임은 없다** — 선글라스를 껴서 눈이 안 보인다.
##
## 그림은 전부 **같은 캔버스(1140x1380)** 라, 각 Sprite2D는 centered = false에
## position = -축좌표로 두면 원본과 픽셀 단위로 같은 자리에 그려진다.
##
## **밑그림 `지하철아저씨_몸통.png`는 받은 `_0004_레이어-1`이 아니다.**
## 받은 파츠 4장은 전부 밑그림과 알파가 100% 겹친다(실측) — 즉 밑그림이 파츠를 지운 몸통이 아니라
## 합쳐진 전체 그림이라, 그대로 깔면 파츠를 움직일 때 원본이 비쳐 두 겹으로 보인다(캣맘·잼민이 때와 같은 함정).
## 그래서 파츠 알파를 2px 부풀려 지우고 **가장 가까운 남은 픽셀 색으로 번지게(BFS)** 메운 판을 만들어 썼다.
## 구멍 안쪽은 얼룩덜룩하지만 파츠가 덮어서 안 보이고, 경계 부근은 바로 옆 원래 색이라 자연스럽다 —
## **그래서 각도를 크게 주면 안 된다.** 안쪽 얼룩이 드러난다.
##
## **뻗은 손은 1.0배 밑으로 절대 안 줄인다.** 줄이면 손이 덮고 있던 자리가 드러나서 메운 얼룩이 보인다.
## 커지는 쪽으로만 움직이면 항상 제자리보다 넓게 덮으므로 무슨 배수를 줘도 안전하다.

## 한 호흡에 걸리는 시간(초). 몸·조끼·머리카락이 이 주기를 공유한다
@export var period: float = 3.2

@export_group("몸")
## 숨 들이쉴 때 세로로 늘어나는 비율 (0.01 = 1%). 축이 발이라 위로만 자란다
@export_range(0.0, 0.1, 0.002) var breath_stretch: float = 0.012
## 발을 축으로 좌우로 기우는 최대 각도(도)
@export var sway_deg: float = 0.4
## 기울기가 숨결과 안 겹치도록 주기를 다르게 준다(배수)
@export var sway_speed: float = 0.71

@export_group("단소 든 팔")
## 팔뚝 단면을 축으로 까딱거리는 최대 각도(도).
## 단소 끝이 축에서 636px이라 **1도에 끝이 11px** 움직인다. 2도를 넘기면 휘두르기가 된다
@export var danso_deg: float = 1.2
## 한 번 까딱하는 데 걸리는 시간(초). 숨결과 따로 논다
@export var danso_period: float = 1.9

@export_group("뻗은 손")
## 앞으로 들이밀 때 커지는 비율 (0.03 = 3%). **음수로 두지 말 것** — 줄어들면 메운 자국이 드러난다
@export_range(0.0, 0.15, 0.005) var hand_push: float = 0.035
## 한 번 들이미는 데 걸리는 시간(초)
@export var hand_period: float = 2.6

@export_group("조끼 자락")
## 어깨를 축으로 살랑거리는 최대 각도(도)
@export var vest_deg: float = 0.9
@export_range(0.0, 1.0, 0.01) var vest_delay: float = 0.2

@export_group("머리카락")
## 머리를 축으로 흔들리는 최대 각도(도). 머리는 안 움직이므로 크게 주면 머리카락만 따로 노는 게 티난다
@export var hair_deg: float = 0.6
@export_range(0.0, 1.0, 0.01) var hair_delay: float = 0.08

@onready var _rig: Node2D = get_node_or_null("Rig")
@onready var _body: Node2D = get_node_or_null("Rig/Body")
@onready var _danso: Node2D = get_node_or_null("Rig/Body/DansoArm")
@onready var _hand: Node2D = get_node_or_null("Rig/Body/LeftHand")
@onready var _vest: Node2D = get_node_or_null("Rig/Body/Vest")
@onready var _hair: Node2D = get_node_or_null("Rig/Body/Hair")

var _time: float = 0.0
## 씬에 저장돼 있던 제자리 각도 — 에디터에서 돌려놓으면 그 각도를 기준으로 움직인다
var _danso_rest_rot: float = 0.0
var _vest_rest_rot: float = 0.0
var _hair_rest_rot: float = 0.0

func _ready() -> void:
	if _danso:
		_danso_rest_rot = _danso.rotation
	if _vest:
		_vest_rest_rot = _vest.rotation
	if _hair:
		_hair_rest_rot = _hair.rotation
	_warn_missing()

## 그림이 하나라도 비면 조용히 사라지는 대신 이유를 남긴다.
## `지하철아저씨_몸통.png`는 코드로 만든 파일이라 에디터를 한 번 열어 임포트하기 전에는 안 읽힌다
func _warn_missing() -> void:
	for path in ["Rig/Body/Sprite", "Rig/Body/Vest/Sprite", "Rig/Body/Hair/Sprite",
			"Rig/Body/DansoArm/Sprite", "Rig/Body/LeftHand/Sprite"]:
		var sprite: Sprite2D = get_node_or_null(path) as Sprite2D
		if sprite == null or sprite.texture == null:
			push_warning("SubwayIllust: %s 그림이 비었다 (임포트 전이거나 경로가 바뀜)" % path)

## 원본 그림 한 장의 크기. 메인 메뉴가 자동 배치를 켰을 때 이걸 보고 배율을 계산한다
func get_image_size() -> Vector2:
	var sprite: Sprite2D = get_node_or_null("Rig/Body/Sprite") as Sprite2D
	if sprite and sprite.texture:
		return sprite.texture.get_size()
	return Vector2(1140, 1380)

## 이 일러스트가 화면에 나타난 순간 메인 메뉴가 부른다 — 움직임을 처음부터 다시 센다
func restart() -> void:
	_time = 0.0

func _process(delta: float) -> void:
	_time += delta
	var w: float = TAU / maxf(period, 0.01)

	if _rig:
		_rig.rotation = deg_to_rad(sway_deg) * sin(_time * w * sway_speed + 1.0)
	if _body:
		_body.scale = Vector2(1.0, 1.0 + breath_stretch * sin(_time * w))

	# 단소는 숨결과 따로, 조금 빠르게 까딱인다 — 위협하는 느낌
	if _danso:
		_danso.rotation = _danso_rest_rot + deg_to_rad(danso_deg) * sin(_time * TAU / maxf(danso_period, 0.01))

	# 뻗은 손 — **1.0배 아래로 안 내려간다.** 항상 제자리보다 크게 덮으므로 메운 자국이 안 드러난다
	if _hand:
		var push: float = 0.5 * (1.0 - cos(_time * TAU / maxf(hand_period, 0.01)))
		_hand.scale = Vector2.ONE * (1.0 + hand_push * push)

	# 조끼·머리카락은 같은 숨결을 조금씩 늦게 받는다
	if _vest:
		_vest.rotation = _vest_rest_rot + deg_to_rad(vest_deg) * sin((_time - period * vest_delay) * w)
	if _hair:
		_hair.rotation = _hair_rest_rot + deg_to_rad(hair_deg) * sin((_time - period * hair_delay) * w * 1.4)
