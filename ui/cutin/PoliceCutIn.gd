class_name PoliceCutIn
extends Node2D

## 주인공(경찰) 궁극기 컷인 — **미란다의 원칙**.
##
## 움직이는 건 딱 두 가지다(2026-09-29 요청):
##  1) 미란다 원칙을 적은 종이를 든 손이 **화면 아래에서 위로 끌려 올라온다**
##  2) 올라온 뒤 **입이 움직이며 원칙을 읽는다**
## 여기에 배경(경찰차)과 빨강·파랑 경광등 번쩍임이 더해진다.
##
## 배경과 종이 그림은 나중에 갈아 끼울 것이라 지금은 비워 뒀다 —
## `paper_texture`를 넣으면 종이 그림이 나오고, 비어 있으면 대신 흰 종이(PaperPlaceholder)가 그려진다.
## 배경도 `Bg`에 그림을 넣으면 그 그림이, 없으면 `BgColor`의 단색이 깔린다.
##
## 입은 **얼굴 그림 두 장을 번갈아 끼워서** 움직인다(`head_closed_texture` = 입 다문 정면 얼굴, 일진 컷인과 같은 방식).
## 예전에는 원래 입을 피부색 판으로 덮고 그 위에 입을 그리는 방식(`PoliceMouth`)도 같이 들고 있었는데,
## 2026-09-29에 통째로 걷어냈다 — 얼굴 두 장 방식만 쓰는데도 노드가 남아 있어서 엉뚱한 자리에 입이 보일 여지가 있었다
##
## 배경의 빨강·파랑 경광등은 화면 전체에 **덧셈(add)으로 얹는 색판 두 장**을 번갈아 켜서 만든다 —
## 배경 그림은 가만히 있고 빛만 번쩍이므로 그림을 여러 장 그릴 필요가 없다.

## 이 컷인이 화면에 머무는 시간(초). UltimateCutIn이 이 값을 읽어 간다.
## 2026-09-29 사용자 지정으로 2.6 -> 1.3 (종이 올라오는 0.55초를 빼면 말하는 구간이 0.6초쯤 남는다)
@export var cutin_duration: float = 1.3

@export_group("경찰차 엔진 진동")
## 시동 걸린 차처럼 **배경만** 아주 조금 떠는 폭(px). 0이면 안 떤다.
## 경찰·종이는 안 떤다 — 배경만 떨어야 "차가 공회전 중"으로 읽힌다
@export var engine_shake: float = 0.55
## 떠는 빠르기(초당 사이클). 두 값이 서로 안 나누어떨어져야 같은 자리를 반복하지 않아
## 진짜 엔진처럼 불규칙하게 보인다
@export var engine_shake_hz: Vector2 = Vector2(11.0, 13.7)

@export_group("종이 끌어올리기")
## 종이가 화면 밖에서 제자리까지 올라오는 데 걸리는 시간(초)
@export var paper_rise_time: float = 0.55
## 시작할 때 제자리보다 이만큼 아래에 있다(px). 화면 밖으로 완전히 빠질 만큼 줘야 한다
@export var paper_start_below: float = 760.0
## 올라오다 살짝 지나쳤다 되돌아오는 정도 (0이면 그냥 멈춘다)
@export_range(0.0, 0.4, 0.01) var paper_overshoot: float = 0.12
## 올라오는 동안 기울었다 펴지는 각도(도)
@export var paper_tilt_deg: float = -9.0
## 넣으면 이 그림이 종이가 된다. 비워 두면 흰 종이(PaperPlaceholder)가 대신 그려진다
@export var paper_texture: Texture2D = null

@export_group("경광등")
## 파랑 -> 빨강 한 바퀴 도는 데 걸리는 시간(초). 짧을수록 다급해 보인다
@export var flash_period: float = 0.5
## 한 색이 켜져 있는 비율 (한 바퀴 중)
@export_range(0.05, 0.5, 0.01) var flash_on_ratio: float = 0.34
## 배경에 얹는 빛의 세기(덧셈). 배경만 밝히므로 좀 세도 괜찮다
@export_range(0.0, 1.0, 0.01) var flash_strength: float = 0.32
## 인물(경찰·종이)에 물드는 색. **덧셈이 아니라 곱셈(modulate)이다** —
## 인물까지 덧셈으로 밝히면 살색이 바로 하얗게 날아가서 얼굴이 안 보인다
@export var flash_tint_blue: Color = Color(0.78, 0.88, 1.08, 1.0)
@export var flash_tint_red: Color = Color(1.08, 0.8, 0.82, 1.0)

@export_group("입")
## **입 다문 정면 얼굴.** 이 그림과 원래 얼굴(입 벌린 그림)을 번갈아 끼워서 말하게 한다.
## 손그림 두 장을 바꾸는 쪽이 더 자연스러워서, 그림이 생기면 이쪽을 쓴다.
## 비워 두면 입은 안 움직이고 얼굴 한 장으로만 나온다.
## **두 장은 크기·위치가 똑같아야 한다** — 다르면 말할 때 얼굴이 통째로 들썩인다
@export var head_closed_texture: Texture2D = null
## 종이가 다 올라온 뒤 이만큼 있다가 말하기 시작한다(초)
@export var talk_delay: float = 0.12

## --- 반대 손 경관봉 (2026-09-30) ---
## 미란다 원칙을 읽는 동안 **종이 안 든 손이 경관봉을 들고 슥 올라온다.**
## 언제부터 올라오는지(초, 컷인 시작 기준)와 다 올라오는 시각(초) — 기본은 0.6초에 시작해 컷인이 끝나는 1.3초에 제자리
@export var baton_rise_start: float = 0.6
@export var baton_rise_end: float = 1.3
## 올라오기 전에 화면 아래 어디쯤 숨어 있는지(px). 손과 경봉이 같이 이만큼 내려가 있다
@export var baton_start_below: float = 300.0
## 입을 벌리고 있는 시간 / 다물고 있는 시간(초)
@export var talk_open_time: float = 0.13
@export var talk_close_time: float = 0.1
## 말할 때 고개가 까딱이는 폭(px). 0이면 고개는 안 움직인다
@export var talk_nod: float = 4.0

@onready var _bg: Sprite2D = $Bg
@onready var _baton: Sprite2D = $Police/Baton
@onready var _hand_r: Sprite2D = $Police/HandR
## 경봉·손이 다 올라왔을 때의 자리 — 씬에 놓인 값을 그대로 쓴다
var _baton_home: Vector2
var _hand_home: Vector2
## 배경 제자리 — 엔진 진동이 여기서 벗어났다 돌아온다
var _bg_home: Vector2
@onready var _bg_color: ColorRect = $BgColor
@onready var _police: Node2D = $Police
@onready var _head: Sprite2D = $Police/Head
@onready var _blue_wash: ColorRect = $Flash/BlueWash
@onready var _red_wash: ColorRect = $Flash/RedWash
@onready var _paper_group: Node2D = $PaperGroup
@onready var _paper: Sprite2D = $PaperGroup/Paper
@onready var _paper_placeholder: Node2D = $PaperGroup/PaperPlaceholder

## 컷인이 시작된 뒤 지난 시간(초)
var _time: float = 0.0
var _playing: bool = false
## 종이가 멈춰야 할 자리 (씬에 놓인 그대로)
var _paper_home: Vector2 = Vector2.ZERO
var _head_home: Vector2 = Vector2.ZERO
## 지금 입을 벌리고 있는지
var _mouth_open: bool = false
## 씬에 꽂혀 있는 입 벌린 얼굴 — 두 장 교대로 갈 때 되돌릴 그림
var _head_open_texture: Texture2D = null

func _ready() -> void:
	_paper_home = _paper_group.position
	_head_home = _head.position
	_bg_home = _bg.position
	_baton_home = _baton.position
	_hand_home = _hand_r.position
	_bg.visible = _bg.texture != null
	_bg_color.visible = _bg.texture == null
	if paper_texture != null:
		_paper.texture = paper_texture
	_paper.visible = _paper.texture != null
	_paper_placeholder.visible = _paper.texture == null
	_head_open_texture = _head.texture
	play()

## UltimateCutIn이 띄우자마자 불러 준다. 여기서 처음 상태로 되돌린다
func play() -> void:
	_time = 0.0
	_playing = true
	_mouth_open = false
	_set_mouth(false)
	_apply_paper(0.0)
	_head.position = _head_home

func _process(delta: float) -> void:
	if not _playing:
		return
	_time += delta
	_apply_paper(clampf(_time / maxf(paper_rise_time, 0.001), 0.0, 1.0))
	_update_mouth()
	_update_flash()
	_update_engine_shake()
	_update_baton()

## 경관봉을 든 손이 아래에서 슥 올라온다 — 다 올라오면 씬에 놓인 자리에 딱 멈춘다
func _update_baton() -> void:
	var span: float = maxf(baton_rise_end - baton_rise_start, 0.01)
	var t: float = clampf((_time - baton_rise_start) / span, 0.0, 1.0)
	# 끝에서 부드럽게 멈춘다(처음엔 빠르게 올라오다 천천히 자리 잡음)
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	var drop := Vector2(0.0, baton_start_below * (1.0 - eased))
	_baton.position = _baton_home + drop
	_hand_r.position = _hand_home + drop

## 시동 걸린 차의 공회전 떨림. 세로가 가로보다 크다 — 차가 위아래로 잘게 들썩인다.
## 주파수 두 개를 겹쳐 같은 자리를 반복하지 않게 한다(한 개면 규칙적으로 튕겨 기계처럼 보인다)
func _update_engine_shake() -> void:
	if engine_shake <= 0.0:
		return
	var x: float = sin(_time * engine_shake_hz.x * TAU) * engine_shake * 0.45
	var y: float = sin(_time * engine_shake_hz.y * TAU + 1.7) * engine_shake
	_bg.position = _bg_home + Vector2(x, y)

## 파랑과 빨강을 번갈아 켠다. 부드럽게 밝아졌다 어두워지는 게 아니라 **딱딱 켜졌다 꺼진다** —
## 경광등은 원래 그렇게 보이고, 부드럽게 하면 그냥 화면이 물드는 것처럼만 보인다
func _update_flash() -> void:
	var phase: float = fmod(_time, maxf(flash_period, 0.01)) / maxf(flash_period, 0.01)
	var blue_on: bool = phase < flash_on_ratio
	var red_on: bool = phase >= 0.5 and phase < 0.5 + flash_on_ratio
	_blue_wash.modulate.a = flash_strength if blue_on else 0.0
	_red_wash.modulate.a = flash_strength if red_on else 0.0
	var tint: Color = Color(1, 1, 1, 1)
	if blue_on:
		tint = flash_tint_blue
	elif red_on:
		tint = flash_tint_red
	_police.modulate = tint
	_paper_group.modulate = tint

## 종이를 아래에서 위로 끌어 올린다. t=0이면 화면 밖 아래, t=1이면 제자리.
## **살짝 지나쳤다 되돌아오게** 해야 손으로 쑥 끌어 올린 느낌이 난다 —
## 그냥 멈추면 화면이 스르륵 올라온 것처럼만 보인다
func _apply_paper(t: float) -> void:
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	# 끝부분에서 제자리를 조금 넘어갔다 돌아온다
	var over: float = paper_overshoot * sin(PI * clampf(t, 0.0, 1.0)) * (t if t > 0.5 else 0.0)
	_paper_group.position = _paper_home + Vector2(0.0, paper_start_below * (1.0 - eased) - paper_start_below * over * 0.06)
	_paper_group.rotation_degrees = paper_tilt_deg * (1.0 - eased)

## 종이가 다 올라온 뒤부터 입을 벌렸다 다물었다 한다.
## 두 얼굴 그림이 다 있어야 돈다 — 하나라도 없으면 아무것도 안 한다
func _update_mouth() -> void:
	var start: float = paper_rise_time + talk_delay
	if _time < start:
		if _mouth_open:
			_mouth_open = false
			_set_mouth(false)
		return
	# 벌림/다뭄 한 묶음이 한 주기다. 지금이 그 주기의 어디쯤인지로 정한다
	var cycle: float = maxf(talk_open_time + talk_close_time, 0.01)
	var into: float = fmod(_time - start, cycle)
	var open: bool = into < talk_open_time
	if open != _mouth_open:
		_mouth_open = open
		_set_mouth(open)

func _set_mouth(open: bool) -> void:
	if head_closed_texture != null:
		_head.texture = _head_open_texture if open else head_closed_texture
	# 말할 때 고개가 아주 조금 까딱인다 — 입만 움직이면 인형이 뻐끔거리는 것처럼 보인다
	_head.position = _head_home + Vector2(0.0, talk_nod if open else 0.0)
