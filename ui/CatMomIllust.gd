class_name CatMomIllust
extends Node2D

## 메인 메뉴에 서 있는 캣맘 일러스트.
##
## 흐름: **손으로 입을 가린 그림(내뱉기 전)** 으로 시작해서 spit_at초 뒤에
## **손을 내밀고 입을 오므린 그림(내뱉은 후)** 으로 넘어가고, 그 순간 하트가 입 앞에서 톡 튀어나온다.
## 그 뒤에는 계속 숨쉬기·흔들림·하트 둥실거림·눈 깜빡임이 돈다.
## 메인 메뉴가 이 일러스트로 넘어올 때마다 restart()를 부르므로 나올 때마다 처음부터 다시 재생된다.
##
## **주정꾼(MenuIllust)·잼민이(JaemminIllust)와 달리 파츠를 따로 안 움직인다.**
## 캣맘의 포토샵 파츠(머리/치마/오른팔/하트)는 밑그림 `캣맘일러스트_0004_레이어-1.png`와
## **알파가 100% 겹친다** — 즉 밑그림이 파츠를 지운 몸통이 아니라 합쳐진 전체 그림이다(실측 확인).
## 그래서 머리나 치마를 조금만 돌려도 밑에 깔린 원본이 그대로 비쳐 윤곽이 두 겹으로 보인다.
## 잼민이는 사용자가 `말썽꾸러기미남_몸통.png`(파츠 자리를 지우고 메운 그림)를 따로 그려줘서 가능했다.
## 캣맘도 그런 판이 생기면 머리 갸웃·치마 살랑을 여기에 추가할 수 있다.
##
## **하트만 예외다.** 하트는 허공에 떠 있어서 지운 자리가 그냥 투명이면 되므로,
## 전체 그림에서 하트만 지운 판(`캣맘_하트뺀판.png` / `캣맘_하트뺀판_눈감음.png`)을 만들어 두고
## 하트를 따로 얹었다. 그래서 하트는 마음껏 움직여도 밑에 원본 하트가 안 비친다.
##
## 그림은 전부 **같은 캔버스(1140x1380)** 라, 각 Sprite2D는 centered = false에
## position = -축좌표로 두면 원본과 픽셀 단위로 같은 자리에 그려진다.

## 한 호흡에 걸리는 시간(초)
@export var period: float = 3.8

@export_group("몸")
## 숨 들이쉴 때 세로로 늘어나는 비율 (0.01 = 1%). 축이 발이라 위로만 자란다
@export_range(0.0, 0.1, 0.002) var breath_stretch: float = 0.010
## 발을 축으로 좌우로 아주 살짝 기우는 최대 각도(도).
## 키가 1360px이라 0.35도면 머리가 약 8px 움직인다 — 이 이상은 휘청거려 보인다
@export var sway_deg: float = 0.35
## 흔들림이 숨결과 안 겹치도록 주기를 다르게 준다(배수). 1.0이면 통짜로 움직여 보인다
@export var sway_speed: float = 0.63

@export_group("하트 내뱉기")
## 나타난 뒤 몇 초 만에 입을 가린 손을 떼고 하트를 내뱉는지
@export var spit_at: float = 1.4
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
## 커졌다 작아지는 비율 (0.04 = 4%)
@export_range(0.0, 0.3, 0.01) var heart_pulse: float = 0.05
## 둥실거리는 주기(초)
@export var heart_period: float = 2.2

@export_group("눈 깜빡임")
## 눈을 감고 있는 시간(초)
@export var blink_close: float = 0.12
## 깜빡임 사이 간격(초). 이 둘 사이에서 매번 무작위로 정해져서 기계처럼 안 보인다
@export var blink_interval_min: float = 2.6
@export var blink_interval_max: float = 5.8

@onready var _body: Node2D = get_node_or_null("Body")
## 입 가린 그림 (내뱉기 전)
@onready var _pre: Sprite2D = get_node_or_null("Body/PreSpit")
## 손 내민 그림 (내뱉은 후) — 하트는 빠져 있다
@onready var _post: Sprite2D = get_node_or_null("Body/PostSpit")
## 눈 감은 그림 — 내뱉은 후 포즈만 있으므로 내뱉기 전에는 안 쓴다
@onready var _eye: Sprite2D = get_node_or_null("Body/EyeClosed")
## 하트를 감싼 축. 몸의 숨쉬기에 안 딸려가도록 Body 바깥에 둔다 (허공에 뜬 물건이라)
@onready var _heart: Node2D = get_node_or_null("Heart")

var _time: float = 0.0
## 씬에 저장돼 있던 제자리 값 — 에디터에서 옮겨도 코드는 안 고쳐도 된다
var _heart_rest: Vector2 = Vector2.ZERO
## 다음 깜빡임까지 남은 시간 / 눈을 감고 있는 남은 시간
var _blink_wait: float = 0.0
var _blink_left: float = 0.0

func _ready() -> void:
	if _heart:
		_heart_rest = _heart.position
	restart()

## 원본 그림 한 장의 크기. 메인 메뉴가 자동 배치를 켰을 때 이걸 보고 배율을 계산한다
func get_image_size() -> Vector2:
	if _post and _post.texture:
		return _post.texture.get_size()
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
	_animate_spit()
	_update_blink(delta)

## 발을 축으로 세로로 살짝 늘었다 줄었다 하면서 아주 조금 좌우로 기운다.
## 몸 전체를 한 덩어리로 움직이므로 파츠가 겹쳐 비칠 일이 없다
func _animate_body() -> void:
	if _body == null:
		return
	var w: float = TAU / maxf(period, 0.01)
	_body.scale = Vector2(1.0, 1.0 + breath_stretch * sin(_time * w))
	_body.rotation = deg_to_rad(sway_deg) * sin(_time * w * sway_speed + 1.0)

## 내뱉기 전 -> 내뱉은 후로 넘기고, 하트를 튀어나오게 한다
func _animate_spit() -> void:
	if _time < spit_at:
		return
	var since: float = _time - spit_at

	# 두 포즈를 짧게 겹쳐서 바꾼다. 팔만 움직이는 그림이라 이 정도면 "톡" 하고 바뀐 것처럼 보인다
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
	const C1 := 1.70158
	const C3 := C1 + 1.0
	var t: float = u - 1.0
	return 1.0 + C3 * t * t * t + C1 * t * t

## 가끔 한 번씩 눈을 감았다 뜬다.
## **눈 감은 그림이 "내뱉은 후" 포즈뿐이라** 아직 입을 가리고 있는 동안에는 깜빡이지 않는다
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
