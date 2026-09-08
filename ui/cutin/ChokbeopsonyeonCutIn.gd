class_name ChokbeopsonyeonCutIn
extends Node2D

## 촉법소년(잼민이) 궁극기 "엄마가 부르면 집 가서 밥 먹고 옴" 컷인.
##
## 다른 캐릭터 컷인은 파츠를 코드로 흔들지만, 이건 러프 그림 3장을 순서대로 넘기는 플립북이다.
##  - 1번: 놀이터에서 BB탄을 세 발 쏜다 — 쏠 때마다 화면이 반동으로 튄다
##  - 2번: 집에서 엄마가 "밥먹어라~" 하고 부른다. 표정이 바뀌고 머리 위에 느낌표가 뜬다 —
##         뜨는 순간 화면이 한 번 확 당겨졌다 돌아온다("눈치챔")
##  - 3번: 총을 내던지고 집 쪽(왼쪽)으로 달려간다 — 화면이 따라가듯 흐른다
##
## 그림에는 이미 발사 섬광·느낌표·던져진 총이 그려져 있으므로, 코드는 **넘기는 타이밍과
## 화면 흔들림만** 담당한다. 세 장 다 배경이 같아서 흔들려도 이어져 보인다.
##
## 진행 속도는 ramp_time에 맞춘다 — UltimateCutIn이 컷인 표시 시간(hold_time)을 여기에 넣어준다.
## 에디터에서 그냥 열면 1번 프레임만 보이고 가만히 있는다.

## 연출 전체 길이(초). UltimateCutIn이 자기 hold_time으로 덮어쓴다
@export var ramp_time: float = 1.0

@export_group("장면 전환")
## 2번(엄마가 부름)으로 넘어가는 시점 (전체 길이 대비 비율)
@export_range(0.0, 1.0, 0.01) var frame2_at: float = 0.42
## 3번(집으로 달려감)으로 넘어가는 시점 (전체 길이 대비 비율)
@export_range(0.0, 1.0, 0.01) var frame3_at: float = 0.72

@export_group("1번 - BB탄 발사")
## 1번 장면 동안 몇 발 쏘는지 (그림은 한 장이고, 반동만 이 횟수로 튄다)
@export var shot_count: int = 3
## 한 발당 화면이 밀리는 거리(px)
@export var shot_kick: float = 7.0
## 반동이 잦아드는 속도. 클수록 톡톡 끊어져 보인다
@export var shot_decay: float = 15.0

@export_group("2번 - 눈치챔")
## 느낌표가 뜰 때 화면이 당겨지는 정도 (0.05 = 5% 확대)
@export var notice_punch: float = 0.05
## 당겨진 화면이 제자리로 돌아오는 데 걸리는 시간 (전체 길이 대비 비율)
@export_range(0.01, 1.0, 0.01) var notice_settle: float = 0.14

@export_group("3번 - 달려감")
## 달려가는 동안 화면이 따라 흐르는 거리(px). 집이 왼쪽이라 그림은 오른쪽으로 밀린다
@export var run_drift: float = 9.0

@onready var _frames: Array[Sprite2D] = [
	get_node_or_null("Frame1"),
	get_node_or_null("Frame2"),
	get_node_or_null("Frame3"),
]

var _time: float = 0.0
var _playing: bool = false

func _ready() -> void:
	_show_frame(0)

## 컷인 재생을 시작한다 (UltimateCutIn이 호출한다)
func play() -> void:
	_time = 0.0
	_playing = true
	_show_frame(0)
	position = Vector2.ZERO
	scale = Vector2.ONE

func _process(delta: float) -> void:
	if not _playing:
		return
	_time += delta
	var total: float = maxf(ramp_time, 0.001)
	var progress: float = clampf(_time / total, 0.0, 1.0)

	var index: int = 0
	if progress >= frame3_at:
		index = 2
	elif progress >= frame2_at:
		index = 1
	_show_frame(index)

	# 그림 자체는 정지 화면이라, 화면을 어떻게 흔드느냐가 곧 연출이 된다
	match index:
		0:
			position = Vector2(-_recoil(total), -_recoil(total) * 0.25)
			scale = Vector2.ONE
		1:
			position = Vector2.ZERO
			scale = Vector2.ONE * (1.0 + notice_punch * _notice_left(progress))
		2:
			var run: float = clampf((progress - frame3_at) / maxf(1.0 - frame3_at, 0.001), 0.0, 1.0)
			position = Vector2(run_drift * run, 0.0)
			scale = Vector2.ONE

## 지금까지 쏜 총알들의 반동을 합친 값. 한 발 쏘면 확 밀렸다가 shot_decay 속도로 잦아든다
func _recoil(total: float) -> float:
	var window: float = frame2_at * total
	var kick: float = 0.0
	for i in range(shot_count):
		# 세 발이 1번 장면 안에 고르게 퍼지도록 (마지막 발이 장면 끝에 붙지 않게 0.75 지점까지만)
		var fired_at: float = window * (float(i) + 0.5) / float(shot_count) * 0.9
		var since: float = _time - fired_at
		if since < 0.0:
			continue
		kick += shot_kick * exp(-since * shot_decay)
	return kick

## 느낌표가 뜬 직후면 1, 시간이 지나 가라앉았으면 0
func _notice_left(progress: float) -> float:
	var since: float = (progress - frame2_at) / maxf(notice_settle, 0.001)
	return clampf(1.0 - since, 0.0, 1.0)

## i번째 장면만 보이게 한다
func _show_frame(i: int) -> void:
	for k in range(_frames.size()):
		if _frames[k]:
			_frames[k].visible = (k == i)
