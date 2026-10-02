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
## 열차가 출발하는 x와 끝나는 x (World 기준, 화면 밖 -> 화면 밖).
## **열차 길이 절반(약 6116) + 화면 반폭(약 1032)보다 커야** 화면 안에서 툭 나타나지 않는다
@export var train_from_x: float = 7500.0
@export var train_to_x: float = -7500.0
## 달리는 동안 칸이 **위아래로 덜덜 떠는 폭(px)**과 떠는 빠르기.
## 좌우로는 일부러 안 떤다 — 진행 방향으로 떨면 속도가 들쭉날쭉해 보여서 "일자로 쭉"이 깨진다
@export var train_rattle: float = 7.0
@export var train_rattle_speed: float = 44.0
## 열차가 지나가는 동안 화면이 흔들리는 폭(px)과 떠는 속도
@export var train_shake: float = 10.0
@export var train_shake_speed: float = 46.0
## **열차 꼬리가 아저씨를 이만큼 지나쳐야** 모습이 드러난다(px).
## 시간으로 재면 차량 크기를 바꿀 때마다 어긋나서, 열차 오른쪽 끝 위치로 직접 잰다 —
## 이래야 "두 번째 차량까지 완전히 지나간 뒤에" 보인다
@export var reveal_margin: float = 170.0

@export_group("바람 / 배경 흐리기")
## 열차가 가르는 바람(속도선)의 세기 — 0이면 안 그린다. 줄 개수·길이·색은 씬의 `World/Wind`에서 잡는다
@export var train_wind: float = 1.0
## **역(배경)만** 흐리게 한다 — 열차·아저씨는 또렷해서 멀고 가까움이 생긴다(화면 높이 720 기준 px).
## 카메라가 멀 때 / 코앞까지 다가왔을 때의 값. 실제 렌즈처럼 **가까이 볼수록 배경이 더 날아간다**
@export var blur_far: float = 1.1
@export var blur_near: float = 3.0

@export_group("칸 사이 실루엣")
## 열차에 가려져 있는 동안 아저씨를 덮어씌우는 색 — **칸 사이 틈으로 실루엣만 번쩍** 보이게 한다.
## 아저씨는 원래부터 열차보다 뒤에 그려지므로, 틈이 그를 지나가는 순간에만 저절로 보인다
@export var silhouette_color: Color = Color(0.05, 0.05, 0.08, 1.0)
## 꼬리가 지나간 뒤 실루엣이 제 색으로 돌아오는 거리(px). 0이면 톡 하고 바로 색이 돌아온다
@export var silhouette_release: float = 320.0

@export_group("머리 위 조명")
## 열차가 다 지나가는 순간 머리 위로 떨어지는 빛줄기의 세기(0이면 아예 안 켠다).
## **켜지는 타이밍은 따로 안 잰다** — 실루엣이 풀리는 정도(위 silhouette_release)를 그대로 쓴다.
## 그래야 "열차가 지나감 = 색이 돌아옴 = 조명이 켜짐"이 한 박자로 맞는다.
## 빛줄기 모양·자리·색은 전부 씬의 `World/Spotlight`(삼각형 Polygon2D)에서 잡는다
@export var spotlight_alpha: float = 0.75

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

@export_group("선글라스 반짝")
## 클로즈업이 들이닥치고 나서 선글라스가 번쩍이기까지 기다리는 시간(초).
## 0이면 들이닥치는 순간과 겹쳐서 휙 하는 밀림에 묻힌다 — 멈춰 선 뒤에 번쩍여야 눈에 들어온다.
## 빛줄기 굵기·기울기·반짝별 크기는 씬의 `ClosePose/Head/LensGlintL`·`LensGlintR`에서 잡는다
@export var glint_delay: float = 0.12

@export_group("등장 뒤 들썩임")
## 나타난 뒤 팔·악기가 계속 살짝 흔들린다 — 가만히 서 있으면 그림 한 장 붙여 둔 것처럼 보인다
@export var sway_degrees: float = 4.5
@export var sway_shift: float = 7.0
@export var sway_speed: float = 7.5
## 발이 흔들리는 정도(손·악기 대비 비율). 발은 바닥을 딛고 있어서 손만큼 흔들면 붕 떠 보인다
@export var foot_sway_ratio: float = 0.5

@onready var _world: Node2D = $World
@onready var _station: Node2D = $World/Station
@onready var _train: Node2D = $World/Train
@onready var _back_pose: Node2D = $World/BackPose
@onready var _hand_l: Sprite2D = $World/BackPose/HandL
@onready var _hand_r: Sprite2D = $World/BackPose/HandR
@onready var _hand_l_up: Node2D = $World/BackPose/HandLRaised
@onready var _hand_r_up: Node2D = $World/BackPose/HandRRaised
@onready var _spotlight: Polygon2D = $World/Spotlight
@onready var _wind: WindStreaks = $World/Wind
@onready var _cam_far: Node2D = $World/CamFar
@onready var _cam_near: Node2D = $World/CamNear
@onready var _close_pose: Node2D = $ClosePose
@onready var _close_hand_l: Sprite2D = $ClosePose/HandL
@onready var _close_hand_r: Sprite2D = $ClosePose/HandR
@onready var _close_foot_l: Sprite2D = $ClosePose/FootL
@onready var _close_foot_r: Sprite2D = $ClosePose/FootR
## 선글라스 두 알 — 들이닥친 뒤 한 번 같이 번쩍인다
@onready var _glints: Array[Node] = [$ClosePose/Head/LensGlintL, $ClosePose/Head/LensGlintR]

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
## 열차 원점에서 오른쪽 끝(꼬리)/왼쪽 끝(앞머리)까지 거리 — 이 값으로 "가리기 시작했는지 / 다 지나갔는지"를 잰다
var _train_tail: float = 0.0
var _train_head: float = 0.0
## 칸 스프라이트와 각자의 제자리 — 덜컹임이 여기서 벗어났다 돌아온다
var _cars: Array[Sprite2D] = []
var _car_home: Array[Vector2] = []
## 클로즈업에서 들썩이는 파츠와 각자의 제자리·각도·세기 — 들썩임이 여기서 벗어났다 돌아온다
var _sway_parts: Array[Sprite2D] = []
var _sway_home: Array[Vector2] = []
var _sway_rot: Array[float] = []
var _sway_amount: Array[float] = []
## 이번 연출에서 선글라스를 이미 번쩍였는지 — 한 번만 쏘려고 들고 있는다
var _glinted: bool = false

func _ready() -> void:
	# 흐리기 재질은 씬이 공유하는 자원이라 복제해서 쓴다 — 매 프레임 값을 바꾸므로 원본을 건드리면 안 된다
	if _station.material:
		_station.material = _station.material.duplicate()
	_station_home = _station.position
	_back_home = _back_pose.position
	_hand_l_home = _hand_l.position
	_hand_r_home = _hand_r.position
	_close_home = _close_pose.position
	_measure_train()
	# **악기는 등록하지 않는다** — 리코더·단소는 쥔 손의 자식이라 손만 흔들면 그대로 따라온다.
	# 따로 흔들었더니 각자 제 축으로 돌아서 손에서 떨어져 나와 보였다(2026-10-01 사용자 신고)
	for part in [_close_hand_l, _close_hand_r]:
		_add_sway_part(part, 1.0)
	# 발도 같은 박자로 조금씩 — 아예 안 움직이면 아래쪽만 그림을 붙여 둔 것처럼 굳어 보인다
	_add_sway_part(_close_foot_l, foot_sway_ratio)
	_add_sway_part(_close_foot_r, foot_sway_ratio)
	play()

## UltimateCutIn이 띄우자마자 불러 준다. 여기서 처음 상태로 되돌린다
func play() -> void:
	_time = 0.0
	_playing = true
	_glinted = false
	_back_pose.visible = false
	_close_pose.visible = false
	_back_pose.position = _back_home
	_back_pose.modulate = Color.WHITE
	_hand_l.position = _hand_l_home
	_hand_r.position = _hand_r_home
	_close_pose.position = _close_home
	_station.position = _station_home
	_spotlight.visible = false
	_wind.power = 0.0
	_wind.restart()
	_apply_train(0.0)
	_apply_camera(0.0)

## 열차가 실제로 차지하는 오른쪽 끝을 잰다. 차량 크기를 바꿔도 알아서 따라간다
func _measure_train() -> void:
	_train_tail = 0.0
	_train_head = 0.0
	_cars.clear()
	_car_home.clear()
	for child in _train.get_children():
		var car := child as Sprite2D
		if car == null or car.texture == null:
			continue
		var width: float = car.region_rect.size.x if car.region_enabled else float(car.texture.get_width())
		var half: float = width * absf(car.scale.x) * 0.5
		_train_tail = maxf(_train_tail, car.position.x + half)
		_train_head = minf(_train_head, car.position.x - half)
		_cars.append(car)
		_car_home.append(car.position)

func _process(delta: float) -> void:
	if not _playing:
		return
	_time += delta
	var train_t: float = clampf((_time - train_start_at) / maxf(train_time, 0.01), 0.0, 1.0)
	_apply_train(train_t)
	_apply_shake(train_t)
	_apply_wind(train_t)
	_apply_camera(clampf((_time - push_in_at) / maxf(push_in_time, 0.01), 0.0, 1.0))
	_apply_poses(train_t)
	_apply_impact()
	_apply_sway()
	_apply_glint()

## 열차를 오른쪽에서 왼쪽으로 **일정한 속도로** 흘려보낸다.
## 가속·감속을 넣으면 역에 서는 열차처럼 보여서 "쫙 지나간다"가 안 된다
func _apply_train(t: float) -> void:
	# 경로는 **완전한 수평 직선**이다. y를 조금이라도 섞으면 바로 사선으로 흐르는 것처럼 보인다 —
	# 흔들림은 아래 _rattle_cars가 칸마다 따로 넣는다
	_train.position.x = lerpf(train_from_x, train_to_x, t)
	_train.visible = t > 0.0 and t < 1.0
	_rattle_cars(t)

## 칸마다 위아래로 조금씩 **어긋나게** 떤다 — 대차 위에서 덜컹거리는 느낌.
## 위상을 어긋내지 않으면 열차가 통째로 오르내려서 "떤다"가 아니라 "출렁인다"가 된다
func _rattle_cars(t: float) -> void:
	var running: bool = t > 0.0 and t < 1.0
	for i in _cars.size():
		var offset: float = 0.0
		if running:
			var phase: float = _time * train_rattle_speed + float(i) * 2.1
			offset = (sin(phase) * 0.6 + sin(phase * 1.73 + 1.1) * 0.4) * train_rattle
		_cars[i].position.y = _car_home[i].y + offset

## 열차가 가르는 바람 — 들어올 때 세지고 빠져나갈 때 잦아든다(흔들림과 같은 박자)
func _apply_wind(t: float) -> void:
	_wind.power = 0.0 if (t <= 0.0 or t >= 1.0) else sin(PI * t) * train_wind

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
	# 배경 흐림도 카메라를 따라간다 — 다가올수록 더 날아가야 "가까이서 본다"가 산다
	var mat := _station.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("blur_px", lerpf(blur_far, blur_near, eased))

## 아저씨를 보여줄지 정하고, 손 올리기와 휙 하는 순간의 밀림·흐려짐을 입힌다
func _apply_poses(train_t: float) -> void:
	# 손만 올라간다 — 포즈 한 벌을 더 두고 갈아 끼울 일이 아니다
	var up: float = clampf((_time - raise_at) / maxf(raise_time, 0.01), 0.0, 1.0)
	var lifted: float = 1.0 - pow(1.0 - up, 3.0)
	_hand_l.position = _hand_l_home.lerp(_hand_l_up.position, lifted)
	_hand_r.position = _hand_r_home.lerp(_hand_r_up.position, lifted)
	# 휙 사라짐 — 오른쪽으로 쭉 밀리면서 흐려진다
	var out: float = clampf((_time - vanish_at) / maxf(whoosh_time, 0.01), 0.0, 1.0)
	# **열차 앞머리가 그를 지나친 순간부터** 선로 위에 서 있다. 그래도 열차가 앞을 막고 있어서
	# (BackPose는 Train보다 먼저 그려진다) **칸 사이 틈이 지나갈 때만 실루엣이 번쩍** 보인다
	var head_x: float = _train.position.x + _train_head
	var tail_x: float = _train.position.x + _train_tail
	var entered: bool = _time > train_start_at and head_x <= _back_home.x
	_back_pose.visible = entered and out < 1.0
	_back_pose.position = _back_home + Vector2(vanish_slide * out, 0.0)
	# 꼬리가 reveal_margin을 지나면서 실루엣이 제 색으로 풀린다 —
	# 시간이 아니라 **꼬리 위치**로 재야 칸 수를 바꿔도 안 어긋난다
	var lit: float = clampf((_back_home.x - reveal_margin - tail_x) / maxf(silhouette_release, 1.0), 0.0, 1.0)
	var tint: Color = silhouette_color.lerp(Color.WHITE, lit)
	tint.a = 1.0 - out
	_back_pose.modulate = tint
	# 조명도 같은 박자로 켜지고, **휙 사라질 때 같이 꺼진다**(혼자 남으면 빈 무대에 빛만 떠 있다).
	# 끄는 건 제곱으로 — 휙은 0.06초라 선형으로 줄이면 그가 사라진 뒤에도 빛이 한두 프레임 남는다
	var beam: float = lit * pow(1.0 - out, 2.0) * spotlight_alpha
	_spotlight.visible = beam > 0.002
	_spotlight.modulate.a = beam
	# 휙 나타남 — 오른쪽 밖에서 코앞으로 들어온다
	var into: float = clampf((_time - appear_at) / maxf(whoosh_time, 0.01), 0.0, 1.0)
	_close_pose.visible = _time >= appear_at
	if _close_pose.visible:
		_close_pose.position = _close_home + Vector2(appear_slide * (1.0 - into), 0.0)
		_close_pose.modulate.a = into

## 들이닥쳐 멈춘 뒤 선글라스 두 알이 **한 번** 번쩍인다 — 눈이 안 보이는 캐릭터의 "눈빛" 몫.
## 번쩍임 자체는 리그에서 쓰던 `LensGlint`가 그대로 그린다(`always_show`로 리그 검사만 건너뛴다)
func _apply_glint() -> void:
	if _glinted or _time < appear_at + glint_delay:
		return
	_glinted = true
	for g in _glints:
		if g and g.has_method("blink_now"):
			g.blink_now()

## 클로즈업이 들이닥치는 순간 화면이 쿵 하고 흔들린다. 처음이 제일 세고 빠르게 잦아든다
func _apply_impact() -> void:
	var since: float = _time - appear_at
	if since < 0.0 or since > impact_time:
		position = Vector2.ZERO
		return
	var decay: float = pow(1.0 - since / maxf(impact_time, 0.01), 2.0)
	var phase: float = since * impact_speed
	position = Vector2(sin(phase), cos(phase * 1.6) * 0.6) * impact_shake * decay

## 들썩일 파츠 하나를 등록한다. 제자리·각도를 지금 값으로 기억하므로 **씬에서 옮겨 놓은 자리가 기준**이 된다
func _add_sway_part(part: Sprite2D, amount: float) -> void:
	if part == null:
		return
	_sway_parts.append(part)
	_sway_home.append(part.position)
	_sway_rot.append(part.rotation)
	_sway_amount.append(amount)

## 나타난 뒤 팔·악기·발이 계속 살짝 흔들린다. 좌우가 반대로 흔들려야 들썩이는 느낌이 난다
func _apply_sway() -> void:
	if not _close_pose.visible or _sway_parts.is_empty():
		return
	var wave: float = sin(_time * sway_speed)
	var wave2: float = sin(_time * sway_speed * 1.3 + 1.1)
	for i in _sway_parts.size():
		# 짝/홀로 박자와 방향을 엇갈리게 한다 — 다 같이 움직이면 그림 한 장이 통째로 떠는 것처럼 보인다
		var even: bool = i % 2 == 0
		var w: float = (wave if even else wave2) * (1.0 if even else -1.0) * _sway_amount[i]
		_sway_parts[i].rotation = _sway_rot[i] + deg_to_rad(sway_degrees) * w
		_sway_parts[i].position = _sway_home[i] + Vector2(0.0, sway_shift * w)
