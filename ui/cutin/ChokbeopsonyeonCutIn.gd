class_name ChokbeopsonyeonCutIn
extends Node2D

## 촉법소년(잼민이) 궁극기 "엄마가 부르면 집 가서 밥 먹고 옴" 컷인. 전체 2.4초.
##
## 다른 캐릭터 컷인은 파츠를 코드로 흔들지만, 이건 러프 그림 3장을 순서대로 넘기는 플립북이다.
## 배경이 세 장 다 같은 놀이터라 넘어가도 이어져 보이고, 그 위에 움직이는 것만 따로 얹는다.
##  - 1번(0~26%): 놀이터에서 비비탄을 세 발 쏜다. 총구에서 총알(Pellet0~2)이 실제로 날아가고
##                한 발마다 화면이 반동으로 밀린다
##  - 2번(26~64%): 집에서 엄마가 부르는 대사(ShoutText)와 빨간 말줄(ShoutMark)이 같이 툭 떠오르고,
##                 곧바로 머리 위로 느낌표(Exclaim)가 튀어나온다. 느낌표가 뜨는 순간 화면이 한 번 확 당겨졌다 돌아온다
##  - 3번(64~100%): 총을 내던지고 집 쪽(왼쪽)으로 달려간다. 여기만 통짜 그림이 아니라
##                  **캐릭터 없는 배경(3번배경) + 인게임 리그(Runner = ChokbeopsonyeonRig)** 로 나뉘어 있다.
##                  리그가 그대로 들어가 있으므로 팔·다리가 BodyRig의 걷기 코드로 실제로 움직이고,
##                  잼민이가 화면을 가로질러 달려나가며 지나간 자리마다 먼지가 남는다
##
## 대사와 느낌표는 원래 2번 그림에 손글씨로 같이 그려져 있던 것이다. 대사는 그림에서 지우고
## Label(ShoutText)로 바꿔서 문구를 바로 고칠 수 있게 했고, 느낌표만 그림째 떼어내 스프라이트로 남겼다
## (sprite/축법소년/궁극기컷인/느낌표.png). "대사가 먼저 뜨고 느낌표가 나중에 뜨는" 순서를 만들려는 분리다.
##
## 길이는 cutin_duration으로 자기가 정한다 — UltimateCutIn이 이 값을 보고 컷인 표시 시간을 맞춰준다.
## 에디터에서 그냥 열면 1번 프레임만 보이고 가만히 있는다.

## 이 컷인이 필요로 하는 표시 시간(초). UltimateCutIn이 기본 hold_time 대신 이 값을 쓴다
@export var cutin_duration: float = 2.4
## 연출 전체 길이(초). UltimateCutIn이 실제 표시 시간으로 덮어쓴다
@export var ramp_time: float = 2.4

@export_group("장면 전환")
## 2번(엄마가 부름)으로 넘어가는 시점 (전체 길이 대비 비율)
@export_range(0.0, 1.0, 0.01) var frame2_at: float = 0.26
## 3번(집으로 달려감)으로 넘어가는 시점 (전체 길이 대비 비율)
@export_range(0.0, 1.0, 0.01) var frame3_at: float = 0.64

@export_group("1번 - 비비탄 발사")
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
## 세 발을 1번 장면의 앞쪽 몇 %까지 안에서 쏠지. 1에 가까울수록 마지막 발이 장면 끝에 붙는다 —
## 너무 늦게 쏘면 총알이 화면 밖으로 나가기 전에 장면이 넘어가서 총알이 공중에서 사라져 보인다
@export_range(0.1, 1.0, 0.05) var shot_spread: float = 0.8

@export_group("2번 - 엄마 대사 / 느낌표")
## 대사가 툭 떠오르는 데 걸리는 시간(초)
@export var shout_pop: float = 0.18
## 대사가 떠오를 때 작게 시작하는 비율 (0.75면 75% 크기에서 시작해 제 크기로 커진다)
@export var shout_from: float = 0.75
## 느낌표가 튀어나오는 시점 (전체 길이 대비 비율). frame2_at보다 뒤여야 한다.
## 0.31이면 대사가 뜨고 0.12초 뒤 — 대사가 다 떠오르는 순간 바로 이어서 튀어나온다
@export_range(0.0, 1.0, 0.01) var exclaim_at: float = 0.31
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
## 잼민이가 왼쪽으로 달려가는 거리(px). 1100이면 끝나기 직전에 화면 왼쪽으로 완전히 사라진다
@export var run_distance: float = 1100.0
## 달리기 가속 (1이면 등속, 클수록 처음엔 느리다가 확 튀어나간다)
@export var run_accel: float = 1.5
## 달리는 리듬으로 몸 전체가 위아래로 튀는 폭(px).
## 팔다리 흔들림과 몸통 들썩임은 리그(BodyRig)가 알아서 하므로 여기서는 살짝만 얹는다
@export var run_bob: float = 5.0
## 달려가는 동안 몇 번 튀는지
@export var run_bob_cycles: float = 7.0
## 앞으로 기울어진 각도(도). 리그를 scale.x 음수로 뒤집어 놨기 때문에 화면에서는 좌우가 반대로 보인다 —
## 양수가 진행 방향(왼쪽)으로 숙이는 방향이다. 기울기가 반대로 보이면 부호만 뒤집으면 된다
@export var run_lean_deg: float = 7.0
## 튈 때마다 기울기가 흔들리는 폭(도)
@export var run_sway_deg: float = 3.0
## 달려가는 동안 화면이 당겨지는 정도 (0.06 = 6% 확대)
@export var run_zoom: float = 0.06
## 화면이 잼민이를 따라가는 거리(px). 그림이 오른쪽으로 밀리는 만큼 카메라가 왼쪽으로 따라가는 셈
@export var run_drift: float = 18.0
## 먼지가 피어오르는 높이 (컷인 한가운데가 원점). 그림의 발밑 픽셀 y=868을 옮긴 값
@export var dust_ground: float = 330.0
## 먼지가 발보다 얼마나 뒤(오른쪽)에서 피는지(px)
@export var dust_back: float = 40.0
## 먼지가 하나씩 늦게 피는 간격(초)
@export var dust_delay: float = 0.14
## 먼지 한 뭉치가 사라지기까지 걸리는 시간(초)
@export var dust_life: float = 0.5
## 먼지가 퍼지며 커지는 정도
@export var dust_grow: float = 1.8

## 장면 3장 (1번 -> 2번 -> 3번 순서). 씬에 없는 장면은 건너뛴다
var _frames: Array[Sprite2D] = []
## 날아가는 비비탄들
var _pellets: Array[Sprite2D] = []
## 발밑에서 피어오르는 먼지들
var _dusts: Array[Node2D] = []
var _exclaim: Sprite2D
## 엄마가 부르는 대사 (문구는 씬의 ShoutText에서 고친다)
var _shout: Label
var _shout_rest_scale: Vector2 = Vector2.ONE
## 대사 옆에 붙는 빨간 말줄 두 획 — 소리가 저쪽에서 온다는 표시. 대사와 같이 떠오른다
var _shout_mark: Sprite2D
var _mark_rest_scale: Vector2 = Vector2.ONE
## 3번 장면에서 실제로 달려가는 잼민이 (인게임과 같은 파츠 리그)
var _runner: Node2D
## 달리는 표정으로 바꿨는지 (한 번만 부르면 되는 것들)
var _runner_started: bool = false
## 러너가 씬에 놓여 있던 제자리 — 3번 그림에서 원래 서 있던 자리다
var _runner_rest: Vector2 = Vector2.ZERO
## 느낌표가 씬에 놓여 있던 제자리와 제 크기 — 튀어나오는 연출이 여기서 시작해 여기로 끝난다.
## 씬 배율(0.82)을 무시하고 1.0으로 덮어쓰면 느낌표만 커져 버린다
var _exclaim_rest: Vector2 = Vector2.ZERO
var _exclaim_rest_scale: Vector2 = Vector2.ONE
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
		_exclaim_rest_scale = _exclaim.scale
	_shout = get_node_or_null("ShoutText")
	if _shout:
		_shout_rest_scale = _shout.scale
		# 대사가 떠오를 때 한가운데를 축으로 커지도록 — 에디터에서 상자 크기를 바꿔도 알아서 맞는다
		_shout.pivot_offset = _shout.size * 0.5
	_shout_mark = get_node_or_null("ShoutMark")
	if _shout_mark:
		_mark_rest_scale = _shout_mark.scale
	_runner = get_node_or_null("Runner")
	if _runner:
		_runner_rest = _runner.position
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
	if _shout:
		_shout.visible = false
		_shout.scale = _shout_rest_scale
	if _shout_mark:
		_shout_mark.visible = false
		_shout_mark.scale = _mark_rest_scale
	if _runner:
		_runner.visible = false
		_runner.position = _runner_rest
		_runner.rotation = 0.0
		_runner_started = false
		if _runner.has_method("set_action_face"):
			_runner.set_action_face(false)

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
	_update_shout(index, total)
	_update_exclaim(index, progress, total)
	_update_runner(index, progress)
	_update_dust(index, progress)

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
			# 잼민이가 왼쪽으로 뛰는 만큼 화면도 살짝 따라간다(=그림이 오른쪽으로 밀린다)
			var run: float = _run_progress(progress)
			offset = Vector2(run_drift * run, 0.0)
			zoom = 1.0 + run_zoom * run
	position = offset
	scale = Vector2.ONE * zoom

## i번째 총알이 발사되는 시각(초). 세 발이 1번 장면 안에 고르게 퍼지되
## 마지막 발이 장면 끝에 붙지 않도록 shot_spread 비율 안에서 쏜다
func _fire_time(i: int, total: float) -> float:
	return frame2_at * total * (float(i) + 0.5) / float(maxi(shot_count, 1)) * shot_spread

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

## 2번 장면에 들어서는 순간 엄마 대사가 작게 시작해 제 크기로 툭 떠오른다
func _update_shout(index: int, total: float) -> void:
	if _shout == null:
		return
	if index != 1:
		_shout.visible = false
		if _shout_mark:
			_shout_mark.visible = false
		return
	_shout.visible = true
	var u: float = clampf((_time - frame2_at * total) / maxf(shout_pop, 0.001), 0.0, 1.0)
	var grow: float = lerpf(shout_from, 1.0, u)
	var fade: float = clampf(u * 3.0, 0.0, 1.0)
	_shout.scale = _shout_rest_scale * grow
	_shout.modulate.a = fade
	# 빨간 말줄도 대사와 같은 박자로 같이 떠오른다
	if _shout_mark:
		_shout_mark.visible = true
		_shout_mark.scale = _mark_rest_scale * grow
		_shout_mark.modulate.a = fade

## 대사가 먼저 뜨고, 조금 뒤에 느낌표가 툭 튀어나온다
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
	_exclaim.scale = _exclaim_rest_scale * s
	_exclaim.position = _exclaim_rest + Vector2(0.0, exclaim_rise * (1.0 - u))
	_exclaim.modulate.a = clampf(u * 4.0, 0.0, 1.0)

## 느낌표가 뜬 직후면 1, 시간이 지나 가라앉았으면 0
func _notice_left(total: float) -> float:
	var since: float = _time - exclaim_at * total
	if since < 0.0:
		return 0.0
	return clampf(1.0 - since / maxf(notice_settle, 0.001), 0.0, 1.0)

## 3번 장면이 시작하고 얼마나 달렸는지 (0~1)
func _run_progress(progress: float) -> float:
	return clampf((progress - frame3_at) / maxf(1.0 - frame3_at, 0.001), 0.0, 1.0)

## 달린 시간 u일 때 제자리에서 왼쪽으로 얼마나 갔는지(px). 처음엔 느리다가 확 튀어나간다
func _run_shift(u: float) -> float:
	return -run_distance * pow(u, run_accel)

## 잼민이가 왼쪽으로 달려나간다. 뛸 때마다 위로 튀고 몸이 앞뒤로 흔들린다
func _update_runner(index: int, progress: float) -> void:
	if _runner == null:
		return
	if index != 2:
		_runner.visible = false
		return
	_runner.visible = true
	if not _runner_started:
		_runner_started = true
		# 달릴 때만 쓰는 표정으로 바꾼다 (리그에 action_head_texture가 있는 캐릭터만 반응한다)
		if _runner.has_method("set_action_face"):
			_runner.set_action_face(true)
	var u: float = _run_progress(progress)
	# 위로만 튀도록 sin의 절댓값을 쓴다 (땅을 딛는 순간이 아래쪽)
	var hop: float = absf(sin(u * run_bob_cycles * PI))
	_runner.position = _runner_rest + Vector2(_run_shift(u), -run_bob * hop)
	_runner.rotation = deg_to_rad(run_lean_deg + run_sway_deg * sin(u * run_bob_cycles * PI * 2.0))

## 잼민이가 지나간 자리마다 먼지가 하나씩 남아 퍼지며 사라진다
func _update_dust(index: int, progress: float) -> void:
	var u: float = _run_progress(progress)
	var span: float = maxf(1.0 - frame3_at, 0.001) * maxf(ramp_time, 0.001)
	for i in range(_dusts.size()):
		var dust: Node2D = _dusts[i]
		if index != 2:
			dust.visible = false
			continue
		# 이 먼지가 피어난 시점의 잼민이 자리에 그대로 남는다
		var born_u: float = dust_delay * float(i) / span
		var since: float = (u - born_u) * span
		if since < 0.0 or since > dust_life:
			dust.visible = false
			continue
		var life: float = since / dust_life
		dust.visible = true
		dust.position = Vector2(_runner_rest.x + _run_shift(born_u) + dust_back + 30.0 * life, dust_ground - 12.0 * life)
		dust.scale = Vector2.ONE * (0.4 + dust_grow * life)
		dust.modulate.a = 1.0 - life

## i번째 장면만 보이게 한다
func _show_frame(i: int) -> void:
	for k in range(_frames.size()):
		_frames[k].visible = (k == i)
