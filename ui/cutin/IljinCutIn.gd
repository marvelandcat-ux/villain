class_name IljinCutIn
extends Node2D

## 일진 궁극기 컷인 (2026-09-14) — **뒷골목에 서 있던 일진 패거리 중 친구 하나가 이쪽으로 걸어 나온다.**
##
## 화면 구성(뒤 -> 앞):
##  - `Bg` : 일진궁극기배경 (담벼락 골목)
##  - `Iljin` : 뒤쪽에서 담배 물고 웃고 있는 일진. 담배 연기가 피어오르고(`Iljin/Smoke`),
##    **정해진 박자로 입을 뻐끔거리며 뭐라고 지껄이고**(얼굴 그림 두 장을 번갈아 끼우는 방식),
##    다 지껄이면 **입을 다물고 천천히 숨만 쉰다**.
##    박자는 "한 번 벌렸다 닫고 -> `talk_pause`만큼 쉬고 -> 네 번 벌렸다 닫기"로,
##    `_ready`에서 입 벌리는 구간 목록을 미리 만들어 두고 시간만 보고 켠다(무작위 아님)
##  - `Girl` : 일진 여자친구. 임시 스프라이트라 동작은 없고 **머리만 부들부들 떤다**
##  - `Friend` : 앞으로 걸어오는 일진의 친구 — 이 컷인에서 유일하게 걸어오는 인물
##  - `ShoutText` : 화면 위쪽 문구. 잼민이 컷인과 같은 글꼴(Jua)·흰 글씨에 두꺼운 어두운 외곽선이다.
##    문구는 씬에서 바로 고칠 수 있다 — 지금은 팀원에게 보내는 인사말이 들어가 있다
##  - `ShoutMarkL` / `ShoutMarkR` : 일진 머리 양옆의 **빨간 말줄**(잼민이 컷인에 쓴 `말줄.png`).
##    같은 그림을 좌우로 뒤집어 한 쌍으로 놓았다 — 문구와 같이 툭 튀어나온다
##
## `Friend`의 연출은 그림을 여러 장 그리는 대신 **코드로 파츠를 흔들어서** 만든다(다른 컷인과 같은 방식):
##  0. **일진이 다 지껄일 때까지 정면을 보고 서 있다가**(`spit_after_talk`) 옆을 보고 침을 한 번 뱉는다.
##     침 모으는 얼굴 -> 뱉는 얼굴(둘 다 옆을 보는 그림)로
##     바꾸고, 그 순간 침(`Spit`)이 **일진이 없는 쪽(왼쪽)** 으로 날아가다 사라진다.
##     침 뱉는 두 얼굴은 **`Friend/SpitGatherPose` / `Friend/SpitFacePose` 노드에 그대로 놓여 있다** —
##     에디터에서 보이는 그 자리·각도·좌우반전·크기가 그대로 재생된다. 각도를 바꾸고 싶으면
##     그 노드를 에디터에서 돌리면 되고 코드는 손댈 필요가 없다(게임에선 시작할 때 숨긴다).
##     다 뱉으면 정면(화난 얼굴)으로 돌아와 걷기 시작한다
##  1. **제자리에서 점점 커지며 카메라 쪽으로 다가온다.** (2026-09-14) 처음엔 일진이 서 있는
##     오른쪽 뒤에서 비스듬히 걸어왔는데, 옆으로 미끄러지는 것처럼 보인다고 해서 **정면으로 다가오게** 바꿨다.
##     가로 이동은 없고 크기만 커진다 — 시작 자리는 `friend_start_offset`으로 살짝만 위로 띄워 둔다
##  2. 걸을 때마다 **머리가 위아래로 통통** 튄다(`step_rate`, `head_bob_height`).
##     (2026-09-14) 처음엔 몸 전체를 흔들었는데 통짜로 들썩여 어색해서, **몸은 다가오기만 하고
##     머리만 흔들도록** 바꿨다. 몸도 같이 흔들고 싶으면 `body_bob_height`를 올리면 된다
##  3. 두 손은 **번갈아 커졌다 작아진다** — 걸을 때 한쪽 팔은 앞으로(카메라 쪽 = 크게),
##     반대쪽 팔은 뒤로(작게) 가는 걸 **크기 차이로** 흉내낸 것이다. 앞으로 나온 손은 바깥·아래로
##     조금 나가고, 뒤로 간 손은 안쪽·위로 들어간다. 팔 그림이 없어도 이것만으로 걸어오는 것처럼 읽힌다.
##     (2026-09-14) 처음엔 세게 부딪치는 박수였는데 과하다고 해서 이 방식으로 바꿨다
##
## (2026-09-14 조정) **움직이는 건 손의 x축과 몸의 위아래 통통뿐이다.**
##  - 걸을 때 어깨가 좌우로 기우는 것(`sway_deg`)은 기본값 0으로 껐다 — 손의 좌우 움직임과 겹쳐서
##    "양옆으로 막 흔들며 온다"로 보였다
##  - **부딪힐 때 화면(루트)은 흔들지 않는다** — 몸만 살짝 부푼다
##  - **천천히 걸어온다.** 대신 시작 크기(`friend_start_scale`)를 크게 잡아서, 멀리서 조그맣게
##    시작해 확 커지는 게 아니라 **처음부터 어느 정도 크게 보이는 채로** 다가온다
##  - 몸의 위아래 통통(`step_rate`)은 느리게, 손뼉(`clap_rate`)은 그보다 빠르게 —
##    걸음보다 손이 바쁘게 움직여야 위협적으로 보인다
##
## 씬에 배치해 둔 위치가 "다 왔을 때"의 최종 자리다 — 크기·자리를 고치려면 `Friend`(와 그 자식들)를
## 에디터에서 옮기면 되고, 이 스크립트는 손댈 필요가 없다.

## 이 컷인이 필요로 하는 표시 시간(초). UltimateCutIn이 기본 hold_time 대신 이 값을 쓴다
@export var cutin_duration: float = 2.2

@export_group("다가오기")
## 걸어오기 시작하는 자리 — **씬에 배치해 둔 최종 자리에서 이만큼 떨어진 곳**.
## x를 0으로 두면 옆으로 안 새고 **정면으로만 다가온다**. y가 음수면 조금 위(=멀리)에서 시작한다.
## Friend 노드를 옮겨도 같이 따라오므로 다시 잡을 필요가 없다
@export var friend_start_offset: Vector2 = Vector2(0.0, -34.0)
## 시작할 때의 크기 배율 (1.0 = 씬에 배치해 둔 최종 크기)
@export var friend_start_scale: float = 0.82
## 다 도착하는 시점 (전체 길이 대비 비율). 나머지 시간은 코앞에서 계속 손을 내지른다
@export_range(0.1, 1.0, 0.01) var arrive_at: float = 0.85
## 다가오는 가속 정도. 1이면 등속, 클수록 뒤에선 느리다가 코앞에서 확 다가온다
@export var approach_curve: float = 1.4
## 처음에 스르륵 나타나는 시간 (전체 길이 대비 비율). 뒤쪽 일진 위에 갑자기 겹쳐 뜨는 걸 막는다
@export_range(0.0, 0.5, 0.01) var fade_in_at: float = 0.12

@export_group("침 뱉기")
## 출발 전에 침을 뱉을지
@export var spit_enabled: bool = true
## 침 모으는 자세 / 뱉는 자세를 담아 둔 Sprite2D. **에디터에 보이게 놓아둔 그 모습 그대로** 재생한다
## (그림·자리·각도·좌우반전·크기를 통째로 머리에 옮긴다). 게임이 시작되면 이 노드들은 숨긴다
@export var spit_gather_pose: NodePath
@export var spit_face_pose: NodePath
## 침 뱉기 전에 **정면을 보고 서 있는** 시간(초). `spit_after_talk`가 켜져 있으면 이 값 대신
## 일진이 다 지껄이는 시각을 쓴다
@export var spit_front_time: float = 0.4
## 켜면 **일진이 입을 다무는 순간** 침을 뱉기 시작한다 (위 `spit_front_time`은 무시)
@export var spit_after_talk: bool = true
## 침을 모으는 시간(초)과, 뱉고 나서 걷기 시작할 때까지의 시간(초)
@export var spit_gather_time: float = 0.4
@export var spit_hold_time: float = 0.26
## 날아갈 침 (CutInSpit). 씬에서 **입 앞**에 놓아둘 것
@export var spit_node: NodePath

@export_group("걸음")
## 1초에 몇 걸음 걷는지
@export var step_rate: float = 1.6
## 한 걸음마다 **몸 전체**가 떠오르는 높이(px). **0이면 몸은 안 흔들리고 다가오기만 한다**
@export var body_bob_height: float = 0.0
## 한 걸음마다 **머리**가 떠오르는 높이(px, Friend 로컬 기준이라 다가올수록 같이 커진다)
@export var head_bob_height: float = 20.0
## 머리가 몸보다 늦게 따라오는 시간(초). 아주 조금만 줘도 목이 있는 것처럼 보인다
@export var head_bob_lag: float = 0.06
## 걸음마다 좌우로 기우는 각도(도) — 어깨를 흔들며 걷는 느낌
@export var sway_deg: float = 0.0

@export_group("팔 젓기")
## 1초에 몇 바퀴 도는지 — 한 바퀴에 좌우 팔이 한 번씩 앞으로 나온다.
## **`step_rate`의 절반**으로 두면 한 걸음에 팔이 한 번 바뀌어서 걸음과 딱 맞는다
@export var arm_rate: float = 0.8
## 앞으로 나온 손이 커지는 비율 (0.22 = 22% 크게, 반대쪽은 22% 작게)
@export var arm_depth: float = 0.22
## 앞으로 나온 손이 바깥으로 나가는 거리(px). 뒤로 간 손은 같은 만큼 안쪽으로 들어간다
@export var arm_out: float = 12.0
## 앞으로 나온 손이 아래로 내려가는 거리(px). 뒤로 간 손은 같은 만큼 위로 올라간다
@export var arm_drop: float = 7.0

@export_group("문구")
## 문구가 뜨기 시작하는 시점(초)
@export var shout_delay: float = 0.12
## 문구가 툭 튀어나오는 시간(초)
@export var shout_pop_time: float = 0.22
## 튀어나올 때의 처음 크기 배율 (1보다 크면 크게 시작해 줄어들며 박힌다)
@export var shout_pop_scale: float = 1.2

@export_group("여자친구 떨기")
## 머리가 떨리는 폭(px). 0이면 안 떤다
@export var girl_shake: float = 1.1
## 1초에 몇 번 떠는지 — 30 근처면 "부들부들"로 읽힌다
@export var girl_shake_speed: float = 30.0
## 떨면서 같이 흔들리는 각도(도)
@export var girl_shake_deg: float = 0.45

@export_group("일진 말하기")
## 입 벌린 얼굴 그림. 비워두면 입을 안 움직인다.
## 다문 얼굴(`Iljin/Head`에 씬에서 지정해 둔 그림)과 **같은 캔버스**여야 자리가 안 튄다
@export var iljin_talk_texture: Texture2D
## 입을 한 번 벌렸다 닫는 데 걸리는 시간(초)
@export var talk_open_time: float = 0.13
@export var talk_close_time: float = 0.11
## 먼저 몇 번 벌렸다 닫는지 -> 얼마나 쉬는지(초) -> 그 뒤 몇 번 더 벌렸다 닫는지.
## 사용자가 정한 박자는 "한 번 -> 0.4초 -> 네 번"이다
@export var talk_first_count: int = 1
@export var talk_pause: float = 0.4
@export var talk_second_count: int = 4
@export var talk_nod: float = 2.5
@export var talk_nod_deg: float = 1.6
## 입 다문 뒤 숨쉴 때 머리가 오르내리는 폭(px)과 한 번 왕복하는 시간(초).
## 몸은 그 절반만 움직여서 어깨가 따라 들썩이는 것처럼 보이게 한다
@export var iljin_breath: float = 3.2
@export var iljin_breath_period: float = 2.4

@onready var _friend: Node2D = $Friend
@onready var _hand_l: Sprite2D = $Friend/HandL
@onready var _hand_r: Sprite2D = $Friend/HandR
@onready var _iljin_head: Sprite2D = get_node_or_null("Iljin/Head")
@onready var _iljin_body: Sprite2D = get_node_or_null("Iljin/Body")
@onready var _friend_head: Sprite2D = get_node_or_null("Friend/Head")
@onready var _girl_head: Sprite2D = get_node_or_null("Girl/Head")
@onready var _spit: Node = get_node_or_null(spit_node) if spit_node != NodePath() else null
@onready var _gather_pose: Sprite2D = get_node_or_null(spit_gather_pose) as Sprite2D
@onready var _face_pose: Sprite2D = get_node_or_null(spit_face_pose) as Sprite2D
@onready var _shout: Label = get_node_or_null("ShoutText")
@onready var _shout_marks: Array[Node] = [get_node_or_null("ShoutMarkL"), get_node_or_null("ShoutMarkR")]

var _time: float = 0.0
var _playing: bool = false
## 씬에 배치해 둔 값(=최종 모습). _ready에서 기억해 두고 여기로 다가온다
var _friend_rest_position: Vector2 = Vector2.ZERO
var _friend_rest_scale: Vector2 = Vector2.ONE
var _hand_l_rest: Vector2 = Vector2.ZERO
var _hand_r_rest: Vector2 = Vector2.ZERO
var _hand_l_rest_scale: Vector2 = Vector2.ONE
var _hand_r_rest_scale: Vector2 = Vector2.ONE
var _friend_head_rest: Vector2 = Vector2.ZERO
## 친구의 원래(화난) 얼굴 모습 — 침 뱉기가 끝나면 이걸로 돌아간다.
## 자리(position)는 걸음 코드가 매 프레임 다시 잡으므로 여기서 되돌리지 않는다
var _friend_head_rest_texture: Texture2D = null
var _friend_head_rest_flip: bool = false
var _friend_head_rest_rotation: float = 0.0
var _friend_head_rest_scale: Vector2 = Vector2.ONE
## 침을 이미 뱉었는지 (한 번만 날린다)
var _spit_done: bool = false
var _girl_head_rest: Vector2 = Vector2.ZERO
var _girl_head_rest_rotation: float = 0.0
## 말줄의 씬 저장 크기 — 문구와 같이 커졌다 줄어들게 하려고 기억해 둔다
var _shout_mark_rest_scale: Array[Vector2] = []
## 일진 입 모양 — 다문 얼굴(씬에 지정된 그림)과 제자리를 기억해 두고 두 장을 번갈아 끼운다
var _iljin_head_rest_texture: Texture2D = null
var _iljin_head_rest_position: Vector2 = Vector2.ZERO
var _iljin_head_rest_rotation: float = 0.0
var _iljin_body_rest_position: Vector2 = Vector2.ZERO
var _mouth_open: bool = false
## 입을 벌리고 있는 구간 목록 (x = 시작 시각, y = 끝 시각). _ready에서 박자대로 미리 만든다
var _mouth_windows: Array[Vector2] = []
## 마지막으로 입을 다무는 시각 — 이 뒤로는 숨만 쉬고, 친구도 이때부터 침을 뱉는다
var _talk_end: float = 0.0

func _ready() -> void:
	_friend_rest_position = _friend.position
	_friend_rest_scale = _friend.scale
	_hand_l_rest = _hand_l.position
	_hand_r_rest = _hand_r.position
	_hand_l_rest_scale = _hand_l.scale
	_hand_r_rest_scale = _hand_r.scale
	if _friend_head:
		_friend_head_rest = _friend_head.position
		_friend_head_rest_texture = _friend_head.texture
		_friend_head_rest_flip = _friend_head.flip_h
		_friend_head_rest_rotation = _friend_head.rotation
		_friend_head_rest_scale = _friend_head.scale
	# 자세 노드는 배치용이라 게임에선 숨긴다 (에디터에선 보인 채로 두고 각도를 맞추면 된다)
	for pose in [_gather_pose, _face_pose]:
		if pose:
			pose.visible = false
	if _girl_head:
		_girl_head_rest = _girl_head.position
		_girl_head_rest_rotation = _girl_head.rotation
	if _iljin_head:
		_iljin_head_rest_texture = _iljin_head.texture
		_iljin_head_rest_position = _iljin_head.position
		_iljin_head_rest_rotation = _iljin_head.rotation
	if _iljin_body:
		_iljin_body_rest_position = _iljin_body.position
	_build_mouth_windows()
	for mark in _shout_marks:
		_shout_mark_rest_scale.append((mark as Node2D).scale if mark else Vector2.ONE)

## UltimateCutIn이 컷인을 띄우면 호출한다. 에디터에서 그냥 열면 최종 자세로 가만히 서 있는다
func play() -> void:
	_time = 0.0
	_playing = true
	_friend.modulate.a = 0.0
	if _shout:
		_shout.modulate.a = 0.0
	for mark in _shout_marks:
		if mark:
			(mark as CanvasItem).modulate.a = 0.0

func _process(delta: float) -> void:
	if not _playing:
		return
	_time += delta
	_update_talk(delta)
	_update_girl_shake()
	_update_shout()
	var t: float = clampf(_time / maxf(cutin_duration, 0.01), 0.0, 1.0)

	# --- 다가오기 ---
	# 침을 다 뱉은 뒤부터 걷기 시작한다. 걷는 구간은 [침 끝난 시각 ~ 도착 시각]
	var walk_start: float = _spit_lead_time()
	var walk_end: float = maxf(cutin_duration * arrive_at, walk_start + 0.01)
	var walk: float = clampf((_time - walk_start) / (walk_end - walk_start), 0.0, 1.0)
	# 걷기 전에는 팔·머리도 가만히 있어야 한다 — 제자리에서 팔만 흔들면 어색하다
	var moving: float = clampf((_time - walk_start) / 0.15, 0.0, 1.0)
	# 뒤에선 천천히, 코앞에서 조금 더 빨리 (원근). approach_curve = 1이면 등속
	var eased: float = pow(walk, approach_curve)
	var scale_now: float = lerpf(friend_start_scale, 1.0, eased)   # 최종 scale은 아래 손뼉 반동까지 더해서 정한다
	_friend.modulate.a = clampf(t / maxf(fade_in_at, 0.001), 0.0, 1.0)

	# --- 걸음: 한 걸음마다 위로 떴다 내려온다 ---
	var step_phase: float = _time * PI * step_rate
	var hop: float = absf(sin(step_phase))
	var bob: float = -hop * body_bob_height * scale_now * moving
	var start_position: Vector2 = _friend_rest_position + friend_start_offset
	_friend.position = start_position.lerp(_friend_rest_position, eased) + Vector2(0.0, bob)
	_friend.rotation = deg_to_rad(sway_deg) * sin(step_phase * 0.5) * moving
	# 머리는 몸을 따라 움직인 뒤 **거기서 더** 튄다. 조금 늦게(head_bob_lag) 따라와서 목이 있는 것처럼 보인다
	if _friend_head:
		var head_hop: float = absf(sin((_time - head_bob_lag) * PI * step_rate))
		_friend_head.position = _friend_head_rest + Vector2(0.0, -head_hop * head_bob_height * moving)

	# --- 팔 젓기: 한쪽은 앞(크게), 반대쪽은 뒤(작게)로 번갈아 ---
	# swing = +1 -> 왼손이 앞, -1 -> 오른손이 앞
	var swing: float = sin(_time * TAU * arm_rate) * moving
	_hand_l.scale = _hand_l_rest_scale * (1.0 + arm_depth * swing)
	_hand_r.scale = _hand_r_rest_scale * (1.0 - arm_depth * swing)
	# 앞으로 나온 쪽이 바깥(왼손은 -x)·아래로, 뒤로 간 쪽이 안쪽·위로
	_hand_l.position = _hand_l_rest + Vector2(-arm_out, arm_drop) * swing
	_hand_r.position = _hand_r_rest + Vector2(arm_out, arm_drop) * -swing

	_friend.scale = _friend_rest_scale * scale_now
	# 침 뱉는 자세는 걸음 코드가 잡아 놓은 머리 자리를 덮어써야 하므로 맨 마지막에 적용한다
	_update_spit()

## 일진이 뭐라고 지껄이는 입 모양 — 얼굴 그림 두 장을 불규칙한 간격으로 번갈아 끼운다.
## 일정한 박자로 켰다 껐다 하면 기계처럼 보여서, 벌리는 시간과 다무는 시간을 매번 다르게 뽑는다
## 입 벌리는 구간을 박자대로 미리 만든다 — "한 번 -> 쉬고 -> 네 번".
## 매 프레임 무작위로 뽑는 대신 시각만 보고 켜서, 몇 번을 언제 벌릴지 정확히 맞출 수 있다
func _build_mouth_windows() -> void:
	_mouth_windows.clear()
	var cycle: float = talk_open_time + talk_close_time
	var at: float = 0.0
	for i in range(maxi(talk_first_count, 0)):
		_mouth_windows.append(Vector2(at, at + talk_open_time))
		at += cycle
	at += maxf(talk_pause, 0.0)
	for i in range(maxi(talk_second_count, 0)):
		_mouth_windows.append(Vector2(at, at + talk_open_time))
		at += cycle
	# 마지막으로 입을 닫는 시각 (마지막 벌림 + 닫는 시간)
	_talk_end = at - talk_close_time if not _mouth_windows.is_empty() else 0.0
	_talk_end = maxf(_talk_end, 0.0)

func _update_talk(_delta: float) -> void:
	if _iljin_head == null:
		return
	# 다 지껄였으면 입을 다물고 숨만 쉰다
	if _time >= _talk_end or iljin_talk_texture == null:
		_close_iljin_mouth()
		_breathe_iljin()
		return
	var open_now: bool = false
	for window in _mouth_windows:
		if _time >= window.x and _time < window.y:
			open_now = true
			break
	if open_now == _mouth_open:
		return
	_mouth_open = open_now
	if open_now:
		_iljin_head.texture = iljin_talk_texture
		# 말할 때마다 고개를 까딱 — 입만 움직이면 인형 같아서 목도 같이 움직여야 말하는 것처럼 보인다
		_iljin_head.position = _iljin_head_rest_position + Vector2(0.0, talk_nod)
		_iljin_head.rotation = _iljin_head_rest_rotation + deg_to_rad(talk_nod_deg)
	else:
		_iljin_head.texture = _iljin_head_rest_texture
		_iljin_head.position = _iljin_head_rest_position
		_iljin_head.rotation = _iljin_head_rest_rotation

## 입을 다문 기본 얼굴로 되돌린다 (이미 다물고 있으면 아무 일도 안 한다)
func _close_iljin_mouth() -> void:
	if not _mouth_open:
		return
	_mouth_open = false
	if _iljin_head_rest_texture:
		_iljin_head.texture = _iljin_head_rest_texture
	_iljin_head.rotation = _iljin_head_rest_rotation

## 입 다문 뒤의 숨 — 머리가 천천히 오르내리고 몸은 그 절반만 따라 움직인다.
## 아주 조금만 움직여야 "가만히 서서 숨 쉬는" 것으로 보인다
func _breathe_iljin() -> void:
	var wave: float = sin(_time * TAU / maxf(iljin_breath_period, 0.01)) * iljin_breath
	_iljin_head.position = _iljin_head_rest_position + Vector2(0.0, wave)
	if _iljin_body:
		_iljin_body.position = _iljin_body_rest_position + Vector2(0.0, wave * 0.5)

## 여자친구가 부들부들 떠는 연출 — 빠른 진동 두 개를 서로 다른 주기로 겹쳐서,
## 한 방향으로만 왕복하지 않고 자잘하게 떨리는 것처럼 보이게 한다
func _update_girl_shake() -> void:
	if _girl_head == null or girl_shake <= 0.0:
		return
	var phase: float = _time * girl_shake_speed * TAU
	_girl_head.position = _girl_head_rest + Vector2(sin(phase), sin(phase * 1.31 + 1.7) * 0.6) * girl_shake
	_girl_head.rotation = _girl_head_rest_rotation + deg_to_rad(girl_shake_deg) * sin(phase * 0.83)

## 문구 등장 — 크게 나타나 빠르게 줄어들며 박힌다(잼민이 컷인의 대사와 같은 느낌).
## 에디터에서 그냥 열면 완성된 모습으로 가만히 있는다
func _update_shout() -> void:
	if _shout == null:
		return
	var p: float = clampf((_time - shout_delay) / maxf(shout_pop_time, 0.01), 0.0, 1.0)
	_shout.modulate.a = p
	# 뒤로 갈수록 느려지게(EASE_OUT) — 툭 튀어나와 자리를 잡는 맛
	var settle: float = 1.0 - pow(1.0 - p, 3.0)
	var pop: float = lerpf(shout_pop_scale, 1.0, settle)
	_shout.scale = Vector2.ONE * pop
	# 말줄도 같이 — 씬에 저장해 둔 크기를 기준으로 부풀렸다 제자리로
	for i in range(_shout_marks.size()):
		var mark: Node2D = _shout_marks[i] as Node2D
		if mark == null:
			continue
		mark.modulate.a = p
		mark.scale = _shout_mark_rest_scale[i] * pop

## 걷기 시작하기까지 걸리는 시간(초) — 침을 안 뱉으면 0이라 바로 걷는다
## 친구가 정면을 보고 서 있는 시간 — 켜져 있으면 일진이 입을 다무는 시각에 맞춘다
func _front_wait_time() -> float:
	return _talk_end if spit_after_talk else spit_front_time

func _spit_lead_time() -> float:
	if not spit_enabled:
		return 0.0
	return _front_wait_time() + spit_gather_time + spit_hold_time

## 출발 전 침 뱉기 — 얼굴을 "모으기 -> 뱉기 -> 원래(화난)"로 바꾸고, 뱉는 순간 침을 날린다.
## **_process의 맨 끝에서 부른다** — 걸음 코드가 매 프레임 머리 자리를 다시 잡기 때문에,
## 먼저 부르면 침 뱉는 자세의 자리가 그 값에 덮어써진다
func _update_spit() -> void:
	if not spit_enabled or _friend_head == null:
		return
	var front: float = _front_wait_time()
	if _time < front:
		_restore_head_pose()   # 아직 정면 — 화난 얼굴로 가만히 서 있는다
		return
	if _time < front + spit_gather_time:
		_apply_head_pose(_gather_pose)
		return
	if _time < _spit_lead_time():
		_apply_head_pose(_face_pose)
		if not _spit_done:
			_spit_done = true
			if _spit and _spit.has_method("launch"):
				_spit.launch()
		return
	_restore_head_pose()

## 자세 노드에 놓아둔 모습을 머리에 그대로 옮긴다 (에디터에서 보이는 그대로가 게임 화면이 된다)
func _apply_head_pose(pose: Sprite2D) -> void:
	if pose == null:
		return
	if pose.texture:
		_friend_head.texture = pose.texture
	_friend_head.position = pose.position
	_friend_head.rotation = pose.rotation
	_friend_head.scale = pose.scale
	_friend_head.flip_h = pose.flip_h

## 원래 얼굴로 되돌린다. **자리는 안 건드린다** — 걸음 코드가 매 프레임 정하기 때문
func _restore_head_pose() -> void:
	if _friend_head_rest_texture:
		_friend_head.texture = _friend_head_rest_texture
	_friend_head.rotation = _friend_head_rest_rotation
	_friend_head.scale = _friend_head_rest_scale
	_friend_head.flip_h = _friend_head_rest_flip
