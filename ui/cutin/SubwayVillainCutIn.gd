class_name SubwayVillainCutIn
extends Node2D

## 지하철 아저씨 궁극기 컷인.
##
## 연출 순서:
##  1) **카메라가 멀리서 뒤를 찍고 있다** — 아무도 없는 지하철역, 선로만 보인다
##  2) 열차가 쫙 지나간다. 그 사이에 아저씨가 선로 위에 선다(BackPose)
##  3) 열차가 다 지나가면 **카메라가 등 뒤로 점점 다가가다 멈춘다**
##  4) 손이 등 뒤 악기로 올라간다 — **손 두 개만 올라간다**(자리는 HandLRaised/HandRRaised 노드가 정한다)
##  5) **휙** 하고 사라졌다가, **휙** 하고 오른쪽에서 카메라 코앞에 나타난다(ClosePose)
##
## **자리는 전부 씬에서 잡는다.** 이 스크립트는 언제 무엇을 보여줄지와 카메라만 굴린다 —
## 역 조각도, 아저씨 팔다리도, 올린 손 자리도, 마지막 클로즈업도 전부 씬의 노드를 끌면 된다.
##
## 카메라는 `World`를 키우고 옮겨서 흉내 낸다. `CamFar`/`CamNear` 노드의 **자리**가 화면 한가운데에 올
## 지점이고, 그 노드의 **크기(scale)**가 배율이다. 둘 다 끌어서 잡으면 된다.

## 이 컷인이 화면에 머무는 시간(초). UltimateCutIn이 이 값을 읽어 간다
@export var cutin_duration: float = 4.8

@export_group("지나가는 열차")
## 열차가 들어오기 시작하는 시각(초). 그 전까지는 텅 빈 역만 보인다
@export var train_start_at: float = 0.45
## 열차가 화면을 가로지르는 데 걸리는 시간(초)
@export var train_time: float = 1.2
## 열차가 출발하는 x와 끝나는 x (World 기준, 화면 밖 -> 화면 밖)
@export var train_from_x: float = 5000.0
@export var train_to_x: float = -5000.0
## 열차가 지나가는 동안 화면이 흔들리는 폭(px)과 떠는 속도
@export var train_shake: float = 10.0
@export var train_shake_speed: float = 46.0
## **열차 꼬리가 아저씨를 이만큼 지나쳐야** 모습이 드러난다(px).
## 시간으로 재면 차량 크기를 바꿀 때마다 어긋나서, 열차 오른쪽 끝 위치로 직접 잰다 —
## 이래야 "두 번째 차량까지 완전히 지나간 뒤에" 보인다
@export var reveal_margin: float = 170.0

@export_group("카메라 다가가기")
## 다가가기 시작하는 시각(초). 기본은 열차가 다 지나간 직후다
@export var push_in_at: float = 1.7
## 다가가는 데 걸리는 시간(초). 끝나면 딱 멈춘다
@export var push_in_time: float = 0.75

@export_group("손 올리기 / 휙")
## 손이 악기로 올라가는 시각(초). **손 두 개가 HandLRaised/HandRRaised 자리로 올라간다** —
## 씬에서 그 두 노드를 끌어서 올라갈 자리를 잡으면 된다
@export var raise_at: float = 2.75
## 손이 다 올라가는 데 걸리는 시간(초)
@export var raise_time: float = 0.3
## 휙 하고 사라지는 시각(초)
@export var vanish_at: float = 3.35
## 휙 하고 오른쪽에서 나타나는 시각(초)
@export var appear_at: float = 3.48
## 휙 한 번에 걸리는 시간(초). 짧을수록 순간이동처럼 보인다
@export var whoosh_time: float = 0.06
## 사라질 때 오른쪽으로 밀려나는 거리(px). 짧은 시간에 멀리 가야 잔상처럼 쫙 빠진다
@export var vanish_slide: float = 1100.0
## 나타날 때 오른쪽 이만큼 밖에서 들어온다(px)
@export var appear_slide: float = 560.0

@export_group("등장 충격")
## 나타나는 순간 화면이 쿵 하고 흔들리는 폭(px)
@export var impact_shake: float = 30.0
## 그 흔들림이 잦아드는 시간(초)와 떠는 속도
@export var impact_time: float = 0.45
@export var impact_speed: float = 64.0

@export_group("등장 뒤 들썩임")
## 나타난 뒤 팔·악기가 계속 살짝 흔들린다 — 가만히 서 있으면 그림 한 장 붙여 둔 것처럼 보인다
@export var sway_degrees: float = 4.5
@export var sway_shift: float = 7.0
@export var sway_speed: float = 7.5

@onready var _world: Node2D = $World
@onready var _station: Node2D = $World/Station
@onready var _train: Node2D = $World/Train
@onready var _back_pose: Node2D = $World/BackPose
@onready var _hand_l: Sprite2D = $World/BackPose/HandL
@onready var _hand_r: Sprite2D = $World/BackPose/HandR
@onready var _hand_l_up: Node2D = $World/BackPose/HandLRaised
@onready var _hand_r_up: Node2D = $World/BackPose/HandRRaised
@onready var _cam_far: Node2D = $World/CamFar
@onready var _cam_near: Node2D = $World/CamNear
@onready var _close_pose: Node2D = $ClosePose
@onready var _close_recorder: Sprite2D = $ClosePose/Recorder
@onready var _close_danso: Sprite2D = $ClosePose/Danso
@onready var _close_hand_l: Sprite2D = $ClosePose/HandL
@onready var _close_hand_r: Sprite2D = $ClosePose/HandR

## 컷인이 시작된 뒤 지난 시간(초)
var _time: float = 0.0
var _playing: bool = false
## 씬에 놓인 제자리 — 흔들림·휙이 여기서 벗어났다 돌아온다
var _station_home: Vector2 = Vector2.ZERO
var _back_home: Vector2 = Vector2.ZERO
## 손이 내려와 있을 때의 자리 — 여기서 HandLRaised/HandRRaised 자리로 올라간다
var _hand_l_home: Vector2 = Vector2.ZERO
var _hand_r_home: Vector2 = Vector2.ZERO
var _close_home: Vector2 = Vector2.ZERO
## 열차 원점에서 오른쪽 끝(꼬리)까지 거리 — 이 값으로 "다 지나갔는지"를 잰다
var _train_tail: float = 0.0
## 클로즈업 팔·악기의 제자리와 각도 — 들썩임이 여기서 벗어났다 돌아온다
var _sway_home: Array[Vector2] = []
var _sway_rot: Array[float] = []

func _ready() -> void:
	_station_home = _station.position
	_back_home = _back_pose.position
	_hand_l_home = _hand_l.position
	_hand_r_home = _hand_r.position
	_close_home = _close_pose.position
	_measure_train()
	for part in [_close_recorder, _close_danso, _close_hand_l, _close_hand_r]:
		_sway_home.append(part.position)
		_sway_rot.append(part.rotation)
	play()

## UltimateCutIn이 띄우자마자 불러 준다. 여기서 처음 상태로 되돌린다
func play() -> void:
	_time = 0.0
	_playing = true
	_back_pose.visible = false
	_close_pose.visible = false
	_back_pose.position = _back_home
	_back_pose.modulate.a = 1.0
	_hand_l.position = _hand_l_home
	_hand_r.position = _hand_r_home
	_close_pose.position = _close_home
	_station.position = _station_home
	_apply_train(0.0)
	_apply_camera(0.0)

## 열차가 실제로 차지하는 오른쪽 끝을 잰다. 차량 크기를 바꿔도 알아서 따라간다
func _measure_train() -> void:
	_train_tail = 0.0
	for child in _train.get_children():
		var car := child as Sprite2D
		if car == null or car.texture == null:
			continue
		var width: float = car.region_rect.size.x if car.region_enabled else float(car.texture.get_width())
		_train_tail = maxf(_train_tail, car.position.x + width * absf(car.scale.x) * 0.5)

func _process(delta: float) -> void:
	if not _playing:
		return
	_time += delta
	var train_t: float = clampf((_time - train_start_at) / maxf(train_time, 0.01), 0.0, 1.0)
	_apply_train(train_t)
	_apply_shake(train_t)
	_apply_camera(clampf((_time - push_in_at) / maxf(push_in_time, 0.01), 0.0, 1.0))
	_apply_poses(train_t)
	_apply_impact()
	_apply_sway()

## 열차를 오른쪽에서 왼쪽으로 **일정한 속도로** 흘려보낸다.
## 가속·감속을 넣으면 역에 서는 열차처럼 보여서 "쫙 지나간다"가 안 된다
func _apply_train(t: float) -> void:
	_train.position.x = lerpf(train_from_x, train_to_x, t)
	_train.visible = t > 0.0 and t < 1.0

## 열차가 지나가는 동안만 화면이 떤다. 지나가고 나면 딱 멈춰서 아저씨가 또렷하게 보인다
func _apply_shake(t: float) -> void:
	if t <= 0.0 or t >= 1.0:
		_station.position = _station_home
		return
	var power: float = sin(PI * t)
	var phase: float = _time * train_shake_speed
	_station.position = _station_home + Vector2(sin(phase), cos(phase * 1.7) * 0.5) * train_shake * power

## 카메라를 CamFar에서 CamNear로 옮긴다. 그 노드의 자리가 화면 한가운데에 오고, 크기가 배율이다.
## 뒤로 갈수록 느려지게 해서 **스르르 다가가다 멈추는** 느낌을 낸다
func _apply_camera(t: float) -> void:
	var eased: float = 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)
	var zoom: float = lerpf(_cam_far.scale.x, _cam_near.scale.x, eased)
	var focus: Vector2 = _cam_far.position.lerp(_cam_near.position, eased)
	_world.scale = Vector2(zoom, zoom)
	_world.position = -focus * zoom

## 아저씨를 보여줄지 정하고, 손 올리기와 휙 하는 순간의 밀림·흐려짐을 입힌다
func _apply_poses(train_t: float) -> void:
	# 손만 올라간다 — 포즈 한 벌을 더 두고 갈아 끼울 일이 아니다
	var up: float = clampf((_time - raise_at) / maxf(raise_time, 0.01), 0.0, 1.0)
	var lifted: float = 1.0 - pow(1.0 - up, 3.0)
	_hand_l.position = _hand_l_home.lerp(_hand_l_up.position, lifted)
	_hand_r.position = _hand_r_home.lerp(_hand_r_up.position, lifted)
	# 휙 사라짐 — 오른쪽으로 쭉 밀리면서 흐려진다
	var out: float = clampf((_time - vanish_at) / maxf(whoosh_time, 0.01), 0.0, 1.0)
	# **열차 꼬리가 아저씨를 완전히 지나친 뒤에만** 보인다
	var tail_x: float = _train.position.x + _train_tail
	var uncovered: bool = tail_x < _back_home.x - reveal_margin
	_back_pose.visible = _time > train_start_at and uncovered and out < 1.0
	_back_pose.position = _back_home + Vector2(vanish_slide * out, 0.0)
	_back_pose.modulate.a = 1.0 - out
	# 휙 나타남 — 오른쪽 밖에서 코앞으로 들어온다
	var into: float = clampf((_time - appear_at) / maxf(whoosh_time, 0.01), 0.0, 1.0)
	_close_pose.visible = _time >= appear_at
	if _close_pose.visible:
		_close_pose.position = _close_home + Vector2(appear_slide * (1.0 - into), 0.0)
		_close_pose.modulate.a = into

## 클로즈업이 들이닥치는 순간 화면이 쿵 하고 흔들린다. 처음이 제일 세고 빠르게 잦아든다
func _apply_impact() -> void:
	var since: float = _time - appear_at
	if since < 0.0 or since > impact_time:
		position = Vector2.ZERO
		return
	var decay: float = pow(1.0 - since / maxf(impact_time, 0.01), 2.0)
	var phase: float = since * impact_speed
	position = Vector2(sin(phase), cos(phase * 1.6) * 0.6) * impact_shake * decay

## 나타난 뒤 팔과 악기가 계속 살짝 흔들린다. 좌우가 반대로 흔들려야 들썩이는 느낌이 난다
func _apply_sway() -> void:
	if not _close_pose.visible or _sway_home.size() < 4:
		return
	var wave: float = sin(_time * sway_speed)
	var wave2: float = sin(_time * sway_speed * 1.3 + 1.1)
	var parts: Array[Sprite2D] = [_close_recorder, _close_danso, _close_hand_l, _close_hand_r]
	var signs: Array[float] = [1.0, -1.0, 1.0, -1.0]
	for i in range(parts.size()):
		var w: float = wave if i % 2 == 0 else wave2
		parts[i].rotation = _sway_rot[i] + deg_to_rad(sway_degrees) * w * signs[i]
		parts[i].position = _sway_home[i] + Vector2(0.0, sway_shift * w * signs[i])
