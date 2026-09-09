class_name JaemminIllust
extends Node2D

## 메인 메뉴에 서 있는 잼민이(말썽꾸러기 미남) 일러스트. 주정꾼(MenuIllust)과 같은 방식으로
## 포토샵에서 나눈 파츠를 코드로 따로 움직인다.
##  - 머리: 숨쉬듯 위아래로 들썩이고 아주 살짝 갸웃한다
##  - 오른쪽 다리: 허벅지를 축으로 돌려서 발을 탁탁 터는 동작 (쉬었다가 톡톡 두 번)
##  - 총 든 왼팔: 몸에 붙는 쪽(팔 단면)을 축으로 고정한 채 총구가 위아래로 까딱까딱
##  - 눈: 가끔 한 번씩 깜빡인다 (감은 눈 그림을 잠깐 덮어씌우는 방식)
##
## 파츠는 전부 **같은 캔버스 크기(1254x1254)** 로 내보낸 그림이라, 각 Sprite2D는 centered = false에
## position = -축좌표로 두면 원본과 픽셀 단위로 같은 자리에 그려진다.
## 그 Sprite2D를 감싼 Node2D(= 축)를 돌리면 원하는 지점(목/허벅지/팔 단면)을 중심으로 회전한다.
##
## **밑그림(Body)은 원본이 아니라 머리·다리·팔 자리를 지우고 메운 `말썽꾸러기미남_몸통.png`다.**
## 원본을 그대로 깔면 머리를 움직일 때 밑에 원래 머리가 비쳐 두 개로 보인다.

## 한 호흡에 걸리는 시간(초)
@export var period: float = 3.6

@export_group("머리")
## 숨결에 맞춰 위아래로 오르내리는 폭(px, 원본 그림 기준)
@export var head_bob: float = 7.0
## 목을 축으로 갸웃거리는 최대 각도(도)
@export var head_tilt_deg: float = 1.2
## 몸통보다 얼마나 늦게 따라오는지 (한 주기 대비 비율)
@export_range(0.0, 1.0, 0.01) var head_delay: float = 0.12

@export_group("오른쪽 다리 - 탁탁 털기")
## 한 번 털고 다음에 털기까지 걸리는 시간(초)
@export var leg_period: float = 2.6
## 한 번에 몇 번 터는지
@export var leg_taps: int = 2
## 털 때 허벅지를 축으로 돌아가는 최대 각도(도)
@export var leg_tap_deg: float = 4.5
## 주기 중 실제로 터는 구간의 비율. 나머지 시간은 가만히 있는다
@export_range(0.05, 1.0, 0.05) var leg_tap_ratio: float = 0.35

# 축(GunArm 노드 위치)은 어깨가 아니라 **팔이 몸에서 잘려나온 단면 한가운데 (430, 510)** 다.
# 총구 쪽(오른쪽 끝)에 축을 두면 팔 전체가 휘둘려서 까딱이 아니라 휘두르기가 된다
@export_group("총 든 왼팔 - 까딱까딱")
## 한 번 까딱하는 데 걸리는 시간(초)
@export var arm_period: float = 1.3
## 축을 중심으로 위아래로 까딱거리는 최대 각도(도). 총구까지 270px이라 4도면 총구가 19px 움직인다
@export var arm_deg: float = 4.0
## 까딱일 때 같이 오르내리는 폭(px). 0이면 축을 고정한 채 회전만 한다
@export var arm_bob: float = 0.0

@export_group("눈 깜빡임")
## 눈을 감고 있는 시간(초)
@export var blink_close: float = 0.11
## 깜빡임 사이 간격(초). 이 둘 사이에서 매번 무작위로 정해져서 기계처럼 안 보인다
@export var blink_interval_min: float = 2.5
@export var blink_interval_max: float = 5.5

@onready var _body: Node2D = get_node_or_null("Body")
@onready var _head: Node2D = get_node_or_null("Head")
@onready var _leg: Node2D = get_node_or_null("RightLeg")
@onready var _arm: Node2D = get_node_or_null("GunArm")
## 감은 눈 그림 — 평소엔 숨어 있다가 깜빡일 때만 잠깐 켠다. 머리 자식이라 머리를 따라 움직인다
@onready var _eye_closed: Sprite2D = get_node_or_null("Head/EyeClosed")

var _time: float = 0.0
## 씬에 저장돼 있던 제자리 값 — 에디터에서 위치를 옮겨도 코드는 고칠 필요가 없다
var _head_rest: Vector2 = Vector2.ZERO
var _arm_rest: Vector2 = Vector2.ZERO
## 씬에 저장된 제자리 각도 — 에디터에서 팔을 돌려놓으면 그 각도를 기준으로 까딱인다
var _head_rest_rot: float = 0.0
var _leg_rest_rot: float = 0.0
var _arm_rest_rot: float = 0.0
## 다음 깜빡임까지 남은 시간 / 눈을 감고 있는 남은 시간
var _blink_wait: float = 0.0
var _blink_left: float = 0.0

func _ready() -> void:
	if _head:
		_head_rest = _head.position
		_head_rest_rot = _head.rotation
	if _leg:
		_leg_rest_rot = _leg.rotation
	if _arm:
		_arm_rest = _arm.position
		_arm_rest_rot = _arm.rotation
	if _eye_closed:
		_eye_closed.visible = false
	_blink_wait = randf_range(blink_interval_min, blink_interval_max)

## 원본 그림 한 장의 크기. 메인 메뉴가 자동 배치를 켰을 때 이걸 보고 배율을 계산한다
func get_image_size() -> Vector2:
	var sprite: Sprite2D = get_node_or_null("Body/Sprite")
	if sprite and sprite.texture:
		return sprite.texture.get_size()
	return Vector2(1254, 1254)

## 숨결을 처음부터 다시 센다 (다른 일러스트에서 넘어와 화면에 나타난 순간 호출)
func restart() -> void:
	_time = 0.0
	_blink_left = 0.0
	_blink_wait = randf_range(blink_interval_min, blink_interval_max)
	if _eye_closed:
		_eye_closed.visible = false

func _process(delta: float) -> void:
	_time += delta
	var w: float = TAU / maxf(period, 0.01)

	# 머리 — 숨을 들이쉬면 살짝 올라갔다가 내쉬면 내려온다. 갸웃은 같은 숨결을 조금 늦게 받는다
	if _head:
		var phase: float = (_time - period * head_delay) * w
		_head.position = _head_rest + Vector2(0.0, -head_bob * 0.5 * (1.0 + sin(phase)))
		_head.rotation = _head_rest_rot + deg_to_rad(head_tilt_deg) * sin(phase)

	# 오른쪽 다리 — 주기의 앞부분에서만 톡톡 털고 나머지는 가만히 있는다
	if _leg:
		_leg.rotation = _leg_rest_rot + deg_to_rad(leg_tap_deg) * _tap_curve()

	_update_blink(delta)

	# 총 든 왼팔 — 몸에 붙는 단면을 축으로 고정한 채 위아래로 까딱까딱
	if _arm:
		var a: float = sin(_time * TAU / maxf(arm_period, 0.01))
		_arm.rotation = _arm_rest_rot + deg_to_rad(arm_deg) * a
		_arm.position = _arm_rest + Vector2(0.0, -arm_bob * absf(a))

## 가끔 한 번씩 눈을 감았다 뜬다
func _update_blink(delta: float) -> void:
	if _eye_closed == null:
		return
	if _blink_left > 0.0:
		_blink_left -= delta
		if _blink_left <= 0.0:
			_eye_closed.visible = false
			_blink_wait = randf_range(blink_interval_min, blink_interval_max)
		return
	_blink_wait -= delta
	if _blink_wait <= 0.0:
		_blink_left = blink_close
		_eye_closed.visible = true

## 다리를 터는 값(-1~1). 주기의 앞 leg_tap_ratio 구간에서 leg_taps번 흔들리고 점점 잦아든다
func _tap_curve() -> float:
	var t: float = fmod(_time, maxf(leg_period, 0.01)) / maxf(leg_period, 0.01)
	if t >= leg_tap_ratio:
		return 0.0
	var u: float = t / leg_tap_ratio
	# 뒤로 갈수록 약해지게 (1-u) — 마지막에 0으로 끝나야 다음 주기와 이어질 때 안 튄다
	return sin(u * TAU * float(maxi(leg_taps, 1))) * (1.0 - u)
