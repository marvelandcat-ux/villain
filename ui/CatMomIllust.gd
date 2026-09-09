class_name CatMomIllust
extends Node2D

## 메인 메뉴에 서 있는 캣맘 일러스트. 주정꾼(MenuIllust)·잼민이(JaemminIllust)와 같은 파츠 방식이다.
##
## 흐름: **손으로 입을 가린 그림(내뱉기 전)** 으로 시작해서 spit_at초 뒤에
## **손을 내밀고 입을 오므린 파츠 조립체(내뱉은 후)** 로 넘어가고, 그 순간 하트가 입 앞에서 톡 튀어나온다.
## 그 뒤로는 계속 숨쉬기·기울기·머리 갸웃·치마 살랑·팔 까딱·하트 둥실·눈 깜빡임이 돈다.
## 메인 메뉴가 이 일러스트로 넘어올 때마다 restart()를 부르므로 나올 때마다 처음부터 재생된다.
##
## **내뱉기 전은 파츠가 아니라 통짜 그림 한 장이다.** 손 위치가 완전히 다른 포즈(입을 가림 vs 내밀음)라
## 같은 파츠로 표현할 수 없다. 그래서 `PreSpit`(통짜) <-> `Post`(파츠 조립체)를 짧게 겹쳐 바꾼다.
## **Post를 미리 켜두면 안 된다** — 내민 손이 PreSpit 그림 밖(x 289~350)까지 나가서 삐져나온다.
##
## 그림은 전부 **같은 캔버스(1140x1380)** 라, 각 Sprite2D는 centered = false에
## position = -축좌표로 두면 원본과 픽셀 단위로 같은 자리에 그려진다.
## 그 Sprite2D를 감싼 Node2D(= 축)를 돌리면 목·허리·어깨를 중심으로 회전한다.
##
## 노드 구조 — 안쪽일수록 바깥 움직임을 같이 받는다:
##   Rig (발 585,1372을 축으로 좌우로 살짝 기움)
##    └ Body (발을 축으로 세로 숨쉬기)
##       ├ Post ─ Sprite(몸통) / RightArm / Skirt / Head(+EyeClosed)
##       └ PreSpit (통짜 그림)
##   Heart — Rig 바깥. 허공에 뜬 물건이라 몸의 숨결·기울기에 안 딸려간다
##
## **밑그림 `캣맘_몸통.png`는 받은 `_0004_레이어-1`이 아니다.**
## 받은 파츠 4장은 전부 `_0004`와 알파가 100% 겹친다 — 즉 `_0004`는 파츠를 지운 몸통이 아니라
## 합쳐진 전체 그림이라, 그대로 깔면 머리를 움직일 때 밑에 원래 머리가 비쳐 두 겹으로 보인다(잼민이 때와 같은 함정).
## 그래서 머리/치마/오른팔의 알파를 2px 부풀려 지우고, 지운 자리를 **가장 가까운 남은 픽셀 색으로 번지게(BFS)**
## 메운 판을 만들어 썼다. 구멍 안쪽은 얼룩덜룩하지만 파츠가 덮어서 안 보이고,
## **경계 부근은 바로 옆 원래 색이 들어가므로** 파츠가 조금 움직여 드러나는 띠는 자연스럽다.
## 그래서 각도를 크게 주면 안 된다 — 안쪽 얼룩이 드러난다.

## 한 호흡에 걸리는 시간(초). 몸·머리·치마가 이 주기를 공유한다
@export var period: float = 3.8

@export_group("몸")
## 숨 들이쉴 때 세로로 늘어나는 비율 (0.01 = 1%). 축이 발이라 위로만 자란다
@export_range(0.0, 0.1, 0.002) var breath_stretch: float = 0.010
## 발을 축으로 좌우로 기우는 최대 각도(도). 키가 1360px이라 0.35도면 머리가 약 8px 움직인다
@export var sway_deg: float = 0.35
## 기울기가 숨결과 안 겹치도록 주기를 다르게 준다(배수). 1.0이면 통짜로 움직여 보인다
@export var sway_speed: float = 0.63

@export_group("머리")
## 목을 축으로 갸웃거리는 최대 각도(도). **1.5도를 넘기지 말 것** — 밑그림의 메운 자국이 드러난다
@export var head_tilt_deg: float = 1.0
## 숨결에 맞춰 오르내리는 폭(px, 원본 그림 기준)
@export var head_bob: float = 5.0
## 몸통보다 얼마나 늦게 따라오는지 (한 주기 대비 비율)
@export_range(0.0, 1.0, 0.01) var head_delay: float = 0.12

@export_group("치마")
## 허리를 축으로 살랑거리는 최대 각도(도)
@export var skirt_tilt_deg: float = 0.8
@export_range(0.0, 1.0, 0.01) var skirt_delay: float = 0.22

@export_group("손키스 하는 팔")
## 어깨(몸에 붙는 단면)를 축으로 까딱거리는 최대 각도(도)
@export var arm_tilt_deg: float = 1.1
## 한 번 까딱하는 데 걸리는 시간(초). 숨결과 따로 논다
@export var arm_period: float = 2.4

@export_group("하트 내뱉기")
## 나타난 뒤 몇 초 만에 입을 가린 손을 떼고 하트를 내뱉는지.
## 일러스트가 한 번에 10초(`MainMenu.illust_swap_seconds`)만 보이므로,
## 이 값 + `heart_rise`(0.55초) 뒤에도 하트를 감상할 시간이 남아야 한다 — 3초면 뒤에 6초 넘게 남는다
@export var spit_at: float = 3.0
## 내뱉기 전/후 그림이 겹치며 바뀌는 시간(초). 짧아야 "톡" 하고 바뀐 느낌이 난다
@export var spit_fade: float = 0.14
## 하트가 튀어나와 제자리에 앉기까지 걸리는 시간(초)
@export var heart_rise: float = 0.55
## 하트가 **입 쪽에서** 출발하는 거리. 제자리 기준 오프셋이라 x 양수 = 오른쪽(입 쪽)
@export var heart_from: Vector2 = Vector2(124.0, 22.0)
## 튀어나올 때의 시작 크기 배수
@export_range(0.05, 1.0, 0.05) var heart_pop_scale: float = 0.3

@export_group("하트 둥실거림")
## 제자리에 앉은 뒤 위아래로 오르내리는 폭(px, 원본 그림 기준)
@export var heart_bob: float = 9.0
## 커졌다 작아지는 비율 (0.05 = 5%)
@export_range(0.0, 0.3, 0.01) var heart_pulse: float = 0.05
## 둥실거리는 주기(초)
@export var heart_period: float = 2.2

@export_group("눈 깜빡임")
## 눈을 감고 있는 시간(초)
@export var blink_close: float = 0.12
## 깜빡임 사이 간격(초). 이 둘 사이에서 매번 무작위로 정해져서 기계처럼 안 보인다
@export var blink_interval_min: float = 2.6
@export var blink_interval_max: float = 5.8

## _ease_out_back이 쓰는 되돌아오기 세기 (표준 easeOutBack 값)
const BACK_C1 := 1.70158
const BACK_C3 := BACK_C1 + 1.0

@onready var _rig: Node2D = get_node_or_null("Rig")
@onready var _body: Node2D = get_node_or_null("Rig/Body")
## 내뱉은 후 파츠 조립체. 통째로 페이드해야 해서 Node2D로 한 번 묶었다
@onready var _post: Node2D = get_node_or_null("Rig/Body/Post")
@onready var _head: Node2D = get_node_or_null("Rig/Body/Post/Head")
@onready var _skirt: Node2D = get_node_or_null("Rig/Body/Post/Skirt")
@onready var _arm: Node2D = get_node_or_null("Rig/Body/Post/RightArm")
## 눈 감은 머리 — 머리 자식이라 머리가 갸웃해도 눈이 따라간다
@onready var _eye: Sprite2D = get_node_or_null("Rig/Body/Post/Head/EyeClosed")
## 입 가린 통짜 그림 (내뱉기 전)
@onready var _pre: Sprite2D = get_node_or_null("Rig/Body/PreSpit")
## 하트 축. 몸의 숨결·기울기에 안 딸려가도록 Rig 바깥에 둔다
@onready var _heart: Node2D = get_node_or_null("Heart")

var _time: float = 0.0
## 씬에 저장돼 있던 제자리 값 — 에디터에서 옮기거나 돌려놔도 코드는 안 고쳐도 된다
var _head_rest: Vector2 = Vector2.ZERO
var _head_rest_rot: float = 0.0
var _skirt_rest_rot: float = 0.0
var _arm_rest_rot: float = 0.0
var _heart_rest: Vector2 = Vector2.ZERO
## 다음 깜빡임까지 남은 시간 / 눈을 감고 있는 남은 시간
var _blink_wait: float = 0.0
var _blink_left: float = 0.0

func _ready() -> void:
	if _head:
		_head_rest = _head.position
		_head_rest_rot = _head.rotation
	if _skirt:
		_skirt_rest_rot = _skirt.rotation
	if _arm:
		_arm_rest_rot = _arm.rotation
	if _heart:
		_heart_rest = _heart.position
	_warn_missing()
	restart()

## 그림이 하나라도 비면 조용히 사라지는 대신 이유를 남긴다.
## `캣맘_몸통.png`·`캣맘_머리_눈감음.png`는 코드로 만든 파일이라 에디터를 한 번 열어
## 임포트하기 전에는 안 읽힌다 — 예전에 토 기둥에서 "없으면 옛 그림으로" 되돌아가게 했다가
## 엉뚱한 그림이 조용히 나와서 원인 찾기가 훨씬 어려웠다
func _warn_missing() -> void:
	for path in ["Rig/Body/Post/Sprite", "Rig/Body/Post/RightArm/Sprite",
			"Rig/Body/Post/Skirt/Sprite", "Rig/Body/Post/Head/Sprite",
			"Rig/Body/Post/Head/EyeClosed", "Rig/Body/PreSpit", "Heart/Sprite"]:
		var sprite: Sprite2D = get_node_or_null(path) as Sprite2D
		if sprite == null or sprite.texture == null:
			push_warning("CatMomIllust: %s 그림이 비었다 (임포트 전이거나 경로가 바뀜)" % path)

## 원본 그림 한 장의 크기. 메인 메뉴가 자동 배치를 켰을 때 이걸 보고 배율을 계산한다
func get_image_size() -> Vector2:
	if _pre and _pre.texture:
		return _pre.texture.get_size()
	return Vector2(1140, 1380)

## 이 일러스트가 화면에 나타난 순간 메인 메뉴가 부른다 — 내뱉기 연출을 처음부터 다시 돌린다
func restart() -> void:
	_time = 0.0
	_blink_left = 0.0
	_blink_wait = randf_range(blink_interval_min, blink_interval_max)
	if _pre:
		_pre.visible = true
		_pre.modulate.a = 1.0
	if _post:
		_post.visible = false
		_post.modulate.a = 0.0
	if _eye:
		_eye.visible = false
	if _heart:
		_heart.visible = false
		_heart.position = _heart_rest + heart_from
		_heart.scale = Vector2.ONE * heart_pop_scale
		_heart.modulate.a = 0.0

func _process(delta: float) -> void:
	_time += delta
	_animate_body()
	_animate_parts()
	_animate_spit()
	_update_blink(delta)

## 발을 축으로 세로로 살짝 늘었다 줄었다 하면서 아주 조금 좌우로 기운다.
## 기울기는 Rig(전체)에, 숨쉬기는 Body에 건다 — 파츠가 Body 자식이라 숨결을 같이 받아서
## 어깨가 올라가면 팔도 같이 올라간다(따로 두면 어깨에서 팔이 떨어져 보인다)
func _animate_body() -> void:
	var w: float = TAU / maxf(period, 0.01)
	if _rig:
		_rig.rotation = deg_to_rad(sway_deg) * sin(_time * w * sway_speed + 1.0)
	if _body:
		_body.scale = Vector2(1.0, 1.0 + breath_stretch * sin(_time * w))

## 머리·치마·팔은 같은 숨결을 조금씩 늦게 받는다 — 동시에 움직이면 통짜로 보인다
func _animate_parts() -> void:
	var w: float = TAU / maxf(period, 0.01)
	if _head:
		var phase: float = (_time - period * head_delay) * w
		_head.rotation = _head_rest_rot + deg_to_rad(head_tilt_deg) * sin(phase)
		_head.position = _head_rest + Vector2(0.0, -head_bob * 0.5 * (1.0 + sin(phase)))
	if _skirt:
		_skirt.rotation = _skirt_rest_rot + deg_to_rad(skirt_tilt_deg) * sin((_time - period * skirt_delay) * w)
	if _arm:
		_arm.rotation = _arm_rest_rot + deg_to_rad(arm_tilt_deg) * sin(_time * TAU / maxf(arm_period, 0.01))

## 내뱉기 전(통짜) -> 내뱉은 후(파츠 조립체)로 넘기고, 하트를 튀어나오게 한다
func _animate_spit() -> void:
	if _time < spit_at:
		return
	var since: float = _time - spit_at

	# 두 포즈를 짧게 겹쳐서 바꾼다. 팔과 입만 달라지는 그림이라 이 정도면 "톡" 하고 바뀐 것처럼 보인다
	var fade: float = clampf(since / maxf(spit_fade, 0.001), 0.0, 1.0)
	if _pre:
		_pre.modulate.a = 1.0 - fade
		_pre.visible = fade < 1.0
	if _post:
		_post.visible = true
		_post.modulate.a = fade

	if _heart == null:
		return
	_heart.visible = true
	var u: float = clampf(since / maxf(heart_rise, 0.001), 0.0, 1.0)
	if u < 1.0:
		# 튀어나오는 중 — 입 쪽에서 제자리로 날아오면서 커진다
		var e: float = _ease_out_back(u)
		_heart.position = _heart_rest + heart_from * (1.0 - e)
		_heart.scale = Vector2.ONE * lerpf(heart_pop_scale, 1.0, e)
		_heart.modulate.a = clampf(u * 3.0, 0.0, 1.0)
		return
	# 제자리에 앉은 뒤 — 천천히 오르내리며 커졌다 작아진다
	var hw: float = TAU / maxf(heart_period, 0.01)
	var phase: float = (since - heart_rise) * hw
	_heart.position = _heart_rest + Vector2(0.0, -heart_bob * 0.5 * (1.0 + sin(phase)))
	_heart.scale = Vector2.ONE * (1.0 + heart_pulse * sin(phase * 1.3))
	_heart.modulate.a = 1.0

## 목표를 살짝 지나쳤다가 되돌아오는 곡선 — 하트가 톡 튀어나온 느낌을 준다
func _ease_out_back(u: float) -> float:
	var t: float = u - 1.0
	return 1.0 + BACK_C3 * t * t * t + BACK_C1 * t * t

## 가끔 한 번씩 눈을 감았다 뜬다.
## **눈 감은 그림이 "내뱉은 후" 머리뿐이라** 아직 입을 가리고 있는 동안에는 깜빡이지 않는다
func _update_blink(delta: float) -> void:
	if _eye == null:
		return
	if _post == null or _post.modulate.a < 1.0:
		_eye.visible = false
		return
	if _blink_left > 0.0:
		_blink_left -= delta
		if _blink_left <= 0.0:
			_eye.visible = false
			_blink_wait = randf_range(blink_interval_min, blink_interval_max)
		return
	_blink_wait -= delta
	if _blink_wait <= 0.0:
		_blink_left = blink_close
		_eye.visible = true
