class_name ChokbeopsonyeonCutIn
extends Node2D

## 촉법소년(잼민이) 궁극기 "엄마가 부르면 집 가서 밥 먹고 옴" 컷인. 전체 3초.
##
## 다른 캐릭터 컷인은 파츠를 코드로 흔들지만, 이건 러프 그림 3장을 순서대로 넘기는 플립북이다.
## 배경 3장이 완전히 같은 그림이라 넘어가도 이어져 보이고, 그 위에 움직이는 것만 따로 얹는다.
##  - 1번(0~42%): 놀이터에서 BB탄을 세 발 쏜다. 총구에서 총알(Pellet0~2)이 실제로 날아가고
##                한 발마다 화면이 반동으로 밀린다
##  - 2번(42~72%): 집에서 엄마가 "밥먹어라~" 하고 부른다(그림에 있음). 조금 뒤 머리 위로
##                 느낌표(Exclaim)가 튀어나오고, 그 순간 화면이 한 번 확 당겨졌다 돌아온다
##  - 3번(72~100%): 총을 내던지고 집 쪽(왼쪽)으로 달려간다. 화면이 당겨지며 달리는 리듬으로
##                  들썩이고, 발밑에서 먼지(Dust0~2)가 뒤로 피어오른다
##
## 느낌표는 원래 2번 그림에 같이 그려져 있던 것을 따로 떼어낸 스프라이트다 —
## "밥먹어라가 먼저 뜨고 느낌표가 나중에 뜨는" 순서를 만들려고 분리했다(sprite/축법소년/궁극기컷인/느낌표.png).
##
## 길이는 cutin_duration으로 자기가 정한다 — UltimateCutIn이 이 값을 보고 컷인 표시 시간을 맞춰준다.
## 에디터에서 그냥 열면 1번 프레임만 보이고 가만히 있는다.

## 이 컷인이 필요로 하는 표시 시간(초). UltimateCutIn이 기본 hold_time 대신 이 값을 쓴다
@export var cutin_duration: float = 3.0
## 연출 전체 길이(초). UltimateCutIn이 실제 표시 시간으로 덮어쓴다
@export var ramp_time: float = 3.0

@export_group("장면 전환")
## 2번(엄마가 부름)으로 넘어가는 시점 (전체 길이 대비 비율)
@export_range(0.0, 1.0, 0.01) var frame2_at: float = 0.42
## 3번(집으로 달려감)으로 넘어가는 시점 (전체 길이 대비 비율)
@export_range(0.0, 1.0, 0.01) var frame3_at: float = 0.72

@export_group("1번 - BB탄 발사")
## 1번 장면 동안 몇 발 쏘는지 (총알 스프라이트 수만큼만 실제로 날아간다)
@export var shot_count: int = 3
## 총구 위치 (컷인 한가운데가 원점). 그림의 총구 픽셀(1440, 642)을 배율 0.82로 옮긴 값
@export var muzzle: Vector2 = Vector2(517.0, 151.0)
## 총알이 날아가는 속도(px/초)
@export var pellet_speed: float = 560.0
## 날아가면서 위로 살짝 뜨는 정도(px/초). 음수가 위쪽
@export var pellet_rise: float = -26.0
## 총알 하나가 보이는 시간(초). 이 시간이면 화면 밖으로 나간다
@export var pellet_life: float = 0.40
## 한 발당 화면이 밀리는 거리(px)
@export var shot_kick: float = 9.0
## 반동이 잦아드는 속도. 클수록 톡톡 끊어져 보인다
@export var shot_decay: float = 15.0

@export_group("2번 - 밥먹어라 / 느낌표")
## 느낌표가 튀어나오는 시점 (전체 길이 대비 비율). frame2_at보다 뒤여야 한다
@export_range(0.0, 1.0, 0.01) var exclaim_at: float = 0.55
## 느낌표가 다 튀어나오는 데 걸리는 시간(초)
@export var exclaim_pop: float = 0.22
## 튀어나올 때 제 크기보다 얼마나 크게 부풀었다 돌아오는지 (0.6 = 1.6배까지)
@export var exclaim_overshoot: float = 0.6
## 튀어나오며 아래에서 위로 솟는 거리(px)
@export var exclaim_rise: float = 18.0
## 느낌표가 뜰 때 화면이 당겨지는 정도 (0.05 = 5% 확대)
@export var notice_punch: float = 0.05
## 당겨진 화면이 제자리로 돌아오는 데 걸리는 시간(초)
@export var notice_settle: float = 0.35

@export_group("3번 - 달려감")
## 달려가는 동안 화면이 당겨지는 정도 (0.06 = 6% 확대)
@export var run_zoom: float = 0.06
## 화면이 따라 흐르는 거리(px). 집이 왼쪽이라 그림은 오른쪽으로 밀린다
@export var run_drift: float = 26.0
## 달리는 리듬으로 화면이 들썩이는 폭(px)
@export var run_bob: float = 3.0
## 1초에 몇 번 들썩일지
@export var run_bob_speed: float = 11.0
## 먼지가 피어오르는 자리 (컷인 한가운데가 원점). 그림의 발밑 픽셀(1139, 868)을 옮긴 값
@export var dust_origin: Vector2 = Vector2(270.0, 330.0)
## 먼지 한 뭉치씩 뒤로 벌어지는 간격(px)
@export var dust_gap: float = 34.0
## 먼지가 하나씩 늦게 피는 간격(초)
@export var dust_delay: float = 0.12
## 먼지 한 뭉치가 사라지기까지 걸리는 시간(초)
@export var dust_life: float = 0.45
## 먼지가 퍼지며 커지는 정도
@export var dust_grow: float = 1.5

## 장면 3장 (1번 -> 2번 -> 3번 순서). 씬에 없는 장면은 건너뛴다
var _frames: Array[Sprite2D] = []
## 날아가는 BB탄들
var _pellets: Array[Sprite2D] = []
## 발밑에서 피어오르는 먼지들
var _dusts: Array[Node2D] = []
var _exclaim: Sprite2D
## 느낌표가 씬에 놓여 있던 제자리 — 튀어나오는 연출이 여기서 시작해 여기로 끝난다
var _exclaim_rest: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _playing: bool = false

func _ready() -> void:
	for i in range(1, 4):
		var frame: Sprite2D = get_node_or_null("Frame%d" % i)
		if frame:
			_frames.append(frame)
	for i in range(3):
		var pellet: Sprite2D = get_node_or_null("Pellets/Pellet%d" % i)
		if pellet:
			_pellets.append(pellet)
		var dust: Node2D = get_node_or_null("Dust/Dust%d" % i)
		if dust:
			_dusts.append(dust)
	_exclaim = get_node_or_null("Exclaim")
	if _exclaim:
		_exclaim_rest = _exclaim.position
	_reset()

## 컷인 재생을 시작한다 (UltimateCutIn이 호출한다)
func play() -> void:
	_time = 0.0
	_playing = true
	_reset()

## 아직 아무 일도 안 일어난 상태로 되돌린다
func _reset() -> void:
	_show_frame(0)
	position = Vector2.ZERO
	scale = Vector2.ONE
	for pellet in _pellets:
		pellet.visible = false
	for dust in _dusts:
		dust.visible = false
	if _exclaim:
		_exclaim.visible = false

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
	_update_pellets(index, total)
	_update_exclaim(index, progress, total)
	_update_dust(index, total)

	# 그림 자체는 정지 화면이라, 화면을 어떻게 흔드느냐가 곧 연출이 된다.
	# 스프라이트를 화면보다 크게 잡아둬서(배율 0.82) 이만큼 밀려도 가장자리가 안 드러난다
	var offset: Vector2 = Vector2.ZERO
	var zoom: float = 1.0
	match index:
		0:
			var kick: float = _recoil(total)
			offset = Vector2(-kick, -kick * 0.25)
		1:
			zoom = 1.0 + notice_punch * _notice_left(total)
		2:
			var run: float = clampf((progress - frame3_at) / maxf(1.0 - frame3_at, 0.001), 0.0, 1.0)
			# 달리는 리듬 — 위로만 튀도록 sin의 절댓값을 쓴다
			var bob: float = -absf(sin(_time * run_bob_speed * TAU)) * run_bob
			offset = Vector2(run_drift * run, bob)
			zoom = 1.0 + run_zoom * run
	position = offset
	scale = Vector2.ONE * zoom

## i번째 총알이 발사되는 시각(초). 세 발이 1번 장면 안에 고르게 퍼지되
## 마지막 발이 장면 끝에 붙지 않도록 앞쪽 90% 안에서 쏜다
func _fire_time(i: int, total: float) -> float:
	return frame2_at * total * (float(i) + 0.5) / float(maxi(shot_count, 1)) * 0.9

## 총구에서 총알이 날아간다. 1번 장면이 아니면 전부 숨긴다
func _update_pellets(index: int, total: float) -> void:
	for i in range(_pellets.size()):
		var pellet: Sprite2D = _pellets[i]
		if index != 0:
			pellet.visible = false
			continue
		var since: float = _time - _fire_time(i, total)
		if since < 0.0 or since > pellet_life:
			pellet.visible = false
			continue
		pellet.visible = true
		pellet.position = muzzle + Vector2(pellet_speed * since, pellet_rise * since)

## 지금까지 쏜 총알들의 반동을 합친 값. 한 발 쏘면 확 밀렸다가 shot_decay 속도로 잦아든다
func _recoil(total: float) -> float:
	var kick: float = 0.0
	for i in range(shot_count):
		var since: float = _time - _fire_time(i, total)
		if since < 0.0:
			continue
		kick += shot_kick * exp(-since * shot_decay)
	return kick

## "밥먹어라~"가 먼저 뜨고, 조금 뒤에 느낌표가 툭 튀어나온다
func _update_exclaim(index: int, progress: float, total: float) -> void:
	if _exclaim == null:
		return
	if index != 1 or progress < exclaim_at:
		_exclaim.visible = false
		return
	_exclaim.visible = true
	var u: float = clampf((_time - exclaim_at * total) / maxf(exclaim_pop, 0.001), 0.0, 1.0)
	# 작게 시작해 제 크기보다 크게 부풀었다가(60%) 제자리로 돌아온다
	var s: float = 0.0
	if u < 0.6:
		s = lerpf(0.2, 1.0 + exclaim_overshoot, u / 0.6)
	else:
		s = lerpf(1.0 + exclaim_overshoot, 1.0, (u - 0.6) / 0.4)
	_exclaim.scale = Vector2.ONE * s
	_exclaim.position = _exclaim_rest + Vector2(0.0, exclaim_rise * (1.0 - u))
	_exclaim.modulate.a = clampf(u * 4.0, 0.0, 1.0)

## 느낌표가 뜬 직후면 1, 시간이 지나 가라앉았으면 0
func _notice_left(total: float) -> float:
	var since: float = _time - exclaim_at * total
	if since < 0.0:
		return 0.0
	return clampf(1.0 - since / maxf(notice_settle, 0.001), 0.0, 1.0)

## 달려가는 발밑에서 먼지가 하나씩 늦게 피어올라 뒤로 흩어진다
func _update_dust(index: int, total: float) -> void:
	for i in range(_dusts.size()):
		var dust: Node2D = _dusts[i]
		if index != 2:
			dust.visible = false
			continue
		var since: float = _time - (frame3_at * total + dust_delay * float(i))
		if since < 0.0 or since > dust_life:
			dust.visible = false
			continue
		var u: float = since / dust_life
		dust.visible = true
		dust.position = dust_origin + Vector2(dust_gap * float(i) + 40.0 * u, -10.0 * u)
		dust.scale = Vector2.ONE * (0.4 + dust_grow * u)
		dust.modulate.a = 1.0 - u

## i번째 장면만 보이게 한다
func _show_frame(i: int) -> void:
	for k in range(_frames.size()):
		_frames[k].visible = (k == i)
