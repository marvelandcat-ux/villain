class_name BodyRig
extends Node2D

## 스프라이트 조각(머리/몸/손/발)을 붙여 만든 몸에 걷기 동작을 입히는 스크립트.
## 애니메이션 파일 없이, 부모 Fighter의 속도를 보고 매 프레임 각 조각의 위치/회전을 직접 계산한다.
##  - 발: 두 발이 반 바퀴 어긋난 채로 계속 앞뒤를 오간다 (앞발/뒷발이 번갈아 바뀌는 교차 걸음)
##  - 손: 발과 반대로 앞뒤로 흔들린다 (왼발이 나갈 때 오른손이 앞으로)
##  - 몸/머리/손: 한 걸음마다 위로 살짝 들썩 (bob)
##  - 공중에 뜨면: 두 발이 함께 크게 들렸다가, 착지하면 제자리로 돌아온다
##  - 기본공격을 쓰면 오른손이 머리 뒤까지 크게 넘어갔다가 앞으로 내려찍는다
##  - 술을 마시면 고개가 뒤로 젖혀지고, 술병을 입으로 가져가 꿀꺽거리며 위아래로 들썩인다
##  - attack_two_handed를 켜면 기본공격할 때 왼손이 오른손 쪽으로 모여 무기를 같이 잡는다 (악플러 키보드)
##
## 무기(소주병 등)는 "HandRHold" 노드의 자식으로 달면 오른손의 움직임/스윙을 그대로 따라간다.
## HandR 자체의 자식으로 달면 손 스프라이트의 축소 배율(0.11)까지 물려받아 좌표 잡기가 번거로워서,
## 배율 1인 빈 Node2D를 따로 두고 코드로 손 위치·회전만 복사해준다
## 각 조각의 "제자리" 값은 씬에 저장된 위치를 _ready에서 그대로 기억해두고 거기서부터 흔든다.
## 그래서 에디터에서 조각 위치를 옮겨도 애니메이션 코드는 손댈 필요가 없다.

## 걸을 때 발끝이 위로 들리는 최대 각도(도)
@export var foot_swing_deg: float = 36.0
## 발이 제자리에서 앞뒤로 움직이는 거리(px) — 클수록 보폭이 커지고 앞발/뒷발이 뚜렷하게 바뀐다
@export var foot_stride: float = 15.0
## 몸이 들썩이는 높이(px)
@export var body_bob: float = 4.0
## 손이 앞뒤로 흔들리는 거리(px)
@export var hand_swing: float = 12.0
## 가만히 서 있을 때 몸/머리/손이 위아래로 미묘하게 숨쉬는 폭(px). 걷기 시작하면 서서히 사라진다
@export var breathe_amount: float = 2.6
## 숨쉬기 속도(라디안/초) — 낮을수록 느긋하게 숨쉰다
@export var breathe_speed: float = 2.2
## 손이 몸통과 다른 박자로 숨쉬게 하는 위상 차이(라디안). 0이면 몸과 똑같이 움직여서 어색하다
@export var breathe_hand_phase: float = 1.4
## 손 숨쉬기 폭이 몸 대비 몇 배인지 (손이 조금 더 크게 움직이면 자연스럽다)
@export var breathe_hand_ratio: float = 1.3
## 걸음 빠르기 — 캐릭터가 최고 속도로 달릴 때 1초에 이 값(라디안)만큼 걸음 위상이 진행된다
@export var step_speed: float = 9.0
## 걷기 시작/멈출 때 동작이 켜지고 꺼지는 빠르기 (클수록 뚝뚝 끊긴다)
@export var blend_speed: float = 8.0
## 점프해서 공중에 떠 있는 동안 두 발이 아래로 뻗는 각도(도)
@export var jump_foot_deg: float = 60.0
## 점프 자세로 바뀌고 착지해서 풀리는 빠르기
@export var jump_blend_speed: float = 12.0
## 점프하는 순간 몸이 세로로 늘어나는 정도 (x가 작을수록 홀쭉, y가 클수록 길쭉). 세로 약 1.33배
@export var jump_stretch: Vector2 = Vector2(0.75, 1.33)
## 착지하는 순간 몸이 납작해지는 정도 (x가 클수록 넓적, y가 작을수록 납작)
@export var land_squash: Vector2 = Vector2(1.33, 0.75)
## 스쿼시/스트레치가 원래 크기(1,1)로 돌아오는 속도 (클수록 빨리 복구)
@export var squash_recover_speed: float = 2.5

## --- 자전거 타기 (촉법소년 돌진) ---
## 자전거가 "탄 위치"에서 이만큼 떨어진 곳(캐릭터 뒤쪽)에서 슬라이드해 들어온다. x가 음수면 진행 반대쪽(뒤)
@export var ride_enter_offset: Vector2 = Vector2(-70, 0)
## 자전거가 들어오고/빠져나가는 빠르기 (클수록 빨리)
@export var ride_blend_speed: float = 12.0
## 페달 밟을 때 두 발이 도는 중심(크랭크 위치, 리그 원점 기준)
@export var pedal_center: Vector2 = Vector2(1, 23)
## 페달 원의 반지름(px)
@export var pedal_radius: float = 7.0
## 페달 밟는 속도(라디안/초)
@export var pedal_speed: float = 14.0
## 자전거 탈 때 왼손이 가는 위치(핸들바 잡기, 리그 원점 기준)
@export var ride_hand_l_pos: Vector2 = Vector2(19, -4)
## 자전거 탈 때 오른손이 가는 위치(핸들바 잡기)
@export var ride_hand_r_pos: Vector2 = Vector2(25, -6)
## 중력으로 떨어지는 동안(하강 중) 고개를 아래로 숙이는 각도(도). 양수가 아래를 보는 방향(마시기와 같은 규칙)
@export var fall_head_tilt_deg: float = 18.0
## 하강 자세로 바뀌고 풀리는 빠르기
@export var fall_blend_speed: float = 10.0

## 조작 없이 가만히 서 있을 때, 이 시간(초)이 지나면 idle 모션(머리 긁기 또는 뒤돌아보기)이 랜덤으로 하나 나온다 (생동감용)
@export var idle_motion_delay: float = 5.0
## 머리 긁는 동작 하나의 전체 길이(초)
@export var scratch_duration: float = 1.0
## 긁을 때 왼손이 제자리에서 머리 쪽으로 옮겨가는 거리(px). 위(-y)로 올리되 뒤통수(-x쪽)를 긁도록 앞으로는 조금만 당긴다
@export var scratch_hand_offset: Vector2 = Vector2(6, -32)
## 긁을 때 왼손이 돌아가는 각도(도)
@export var scratch_hand_deg: float = -30.0
## 긁는 동안 손이 좌우로 떠는 횟수
@export var scratch_count: float = 4.0
## 긁는 손 떨림의 폭(px)
@export var scratch_amount: float = 3.0
## 뒤돌아보는 동작 하나의 전체 길이(초) — 돌아보기 → 잠깐 정지 → 다시 앞으로
@export var lookback_duration: float = 1.2
## 기본공격 예비동작에서 손이 돌아가는 각도(도) — 반시계 방향(무기가 뒤로 넘어간다)
@export var attack_raise_deg: float = 100.0
## 기본공격에서 손이 내려찍히는 각도(도) — 시계 방향
@export var attack_swing_deg: float = 130.0
## 예비동작에서 손이 제자리로부터 이동하는 거리(px) — 머리 뒤쪽 위로 크게 넘긴다
@export var attack_raise_offset: Vector2 = Vector2(-32, -34)
## 내려찍었을 때 손이 제자리로부터 이동하는 거리(px) — 앞쪽 아래로
@export var attack_slam_offset: Vector2 = Vector2(10, 16)
## 들어올리기 → 내리치기 → 복귀까지 걸리는 전체 시간(초)
@export var attack_duration: float = 0.4
## 기본공격할 때 왼손도 오른손 쪽으로 모아서 두 손으로 무기를 잡을지.
## 평소에는 한 손으로 들고 다니다가 때릴 때만 두 손으로 잡는 캐릭터(악플러 키보드)에서 켠다
@export var attack_two_handed: bool = false
## 두 손으로 잡을 때 왼손이 오른손에서 떨어져 있는 거리(px). 오른손보다 살짝 뒤·아래를 잡는다
@export var attack_grip_offset: Vector2 = Vector2(-10, 4)
## 후려치는 구간에서 손이 직선이 아니라 이동 방향의 아래쪽으로 부풀며 호를 그리는 정도(px).
## 0이면 예전처럼 곧장 직선으로 간다. 아래로 훑어서 올려치는 스윙(악플러 키보드)에서 쓴다
@export var attack_swing_arc: float = 0.0

## 술 마시기 동작 전체 길이(초). 올리기 → 마시기 → 내리기가 이 안에서 다 일어난다
@export var drink_duration: float = 1.1
## 마실 때 고개가 뒤로 젖혀지는 각도(도). 음수가 뒤로(얼굴이 위를 보게) 젖히는 방향
@export var drink_head_tilt_deg: float = -22.0
## 젖히면서 머리가 제자리에서 옮겨가는 거리(px)
@export var drink_head_offset: Vector2 = Vector2(-2, 0)
## 꿀꺽거릴 때 머리와 술병이 위아래로 움직이는 폭(px)
@export var drink_head_bob: float = 2.5
## 마시는 동안 꿀꺽거리는 횟수
@export var drink_gulp_count: float = 3.0
## 술병을 입으로 가져갈 때 오른손이 제자리에서 옮겨가는 거리(px). 얼굴 쪽이라 위(-y)·뒤(-x)로 간다
@export var drink_hand_offset: Vector2 = Vector2(-10, -25)
## 곧장 직선으로 올라가지 않고 바깥으로 부풀며 호를 그리는 정도(px). 0이면 직선
@export var drink_hand_arc: float = 12.0
## 술병을 추가로 기울이는 각도(도). 씬에 잡아둔 제자리 각도(-155도)가 이미 붓는 자세라 기본은 0이다
@export var drink_hand_deg: float = 0.0

## --- 총 쏘기 (촉법소년 BB탄) : 몸에서 총을 꺼내 두 손을 모아 앞으로 겨눈다 ---
## 총을 "몸에서 꺼내는" 시작점(허리/가슴 근처, 리그 원점 기준). 여기서 앞으로 뻗어 조준 자세로 간다
@export var gun_draw_offset: Vector2 = Vector2(2, -4)
## 두 손을 모아 앞으로 겨누는 그립 위치(리그 원점 기준). x가 클수록 팔을 더 앞으로 뻗는다
@export var gun_aim_offset: Vector2 = Vector2(20, -6)
## 왼손이 오른손(그립)에서 떨어져 있는 거리 — 두 손을 살짝 어긋나게 모아 잡는다
@export var gun_hand_l_offset: Vector2 = Vector2(-4, 3)
## 총 스프라이트가 그립(손)보다 총구 쪽으로 나가 있는 거리
@export var gun_forward_offset: Vector2 = Vector2(10, 0)
## 전체 동작 중 "몸에서 꺼내 조준까지" 올리는 구간 비율(앞 20%). 나머지는 겨눈 채 유지한다
@export var gun_draw_ratio: float = 0.2
## 발사 반동으로 총·손이 뒤로 밀리는 거리(px)
@export var gun_recoil_kick: float = 6.0
## 반동이 원래대로 돌아오는 속도(클수록 빨리 회복)
@export var gun_recoil_recover: float = 9.0

## --- 백 서플렉스(헬스장 죽돌이 스킬2): 손을 뻗어 잡고, 들어올려 버티다가, 등 뒤로 넘겨 꽂는다 ---
## 잡을 때 두 손이 함께 모이는 목표 위치(리그 원점 기준) — 옆으로, 머리 높이 정도로 뻗어서 겹쳐 잡는다
@export var grab_reach_target: Vector2 = Vector2(45, -28)
## 겹쳐 잡을 때 두 손이 위아래로 벌어지는 간격(px) — 오른손이 위 절반, 왼손이 아래 절반
@export var grab_hand_gap: float = 12.0
## 등 뒤로 넘겨 꽂는 순간 몸이 뒤로 젖혀지는 각도(도) — 잡고 들어올리는 동안은 몸을 안 기울이고,
## 마지막에 던지는 그 순간에만 확 젖혔다가 동작이 끝나면 제자리로 스냅
@export var grab_slam_deg: float = -32.0
## 넘겨 꽂는 순간 두 손이 잡은 지점(grab_reach_target)에서 추가로 더 이동하는 거리(px) — 위·뒤로
## 뿌리치듯 던지는 손짓
@export var grab_slam_hand_offset: Vector2 = Vector2(-14, -18)

## 토하기 스킬을 쓸 때 잠깐 이 얼굴(토하는 표정)로 머리를 바꾼다. 비어 있으면 아무 일도 안 한다(주정뱅이만 지정)
@export var vomit_head_texture: Texture2D
## 토하는 얼굴을 보여주는 시간(초)
@export var vomit_face_duration: float = 0.6
## 토하는 얼굴일 때 머리 배율. (0,0)이면 원래 머리 배율을 그대로 쓴다(원본 크기가 달라 안 맞을 때만 조정)
@export var vomit_head_scale: Vector2 = Vector2.ZERO
## 토하는 얼굴일 때 머리 위치 보정(px) — 입이 게워내는 위치에 안 맞으면 조정
@export var vomit_head_offset: Vector2 = Vector2.ZERO

## 술 스택이 남아있는 동안(몸이 빨간 동안) 머리를 이 얼굴(술 머금은 표정)로 유지한다. 비어 있으면 안 바꾼다
@export var drunk_head_texture: Texture2D
## 술 머금은 얼굴일 때 머리 배율. (0,0)이면 원래 머리 배율을 그대로 쓴다
@export var drunk_head_scale: Vector2 = Vector2.ZERO

## 스킬(자전거 돌진·총 쏘기)을 쓰는 동안 이 표정으로 머리를 바꾼다. 비어 있으면 안 바꾼다(촉법소년만 지정)
@export var action_head_texture: Texture2D
## 액션 표정일 때 머리 배율. (0,0)이면 원래 머리 배율을 그대로 쓴다
@export var action_head_scale: Vector2 = Vector2.ZERO

@onready var _foot_l: Sprite2D = get_node_or_null("FootL")
@onready var _foot_r: Sprite2D = get_node_or_null("FootR")
@onready var _body: Sprite2D = get_node_or_null("Body")
@onready var _head: Sprite2D = get_node_or_null("Head")
@onready var _hand_l: Sprite2D = get_node_or_null("HandL")
@onready var _hand_r: Sprite2D = get_node_or_null("HandR")
## 오른손이 든 물건(소주병 등)을 매다는 빈 노드 — 손의 위치·회전을 그대로 따라간다
@onready var _hand_r_hold: Node2D = get_node_or_null("HandRHold")
## 자전거 노드(있으면 촉법소년) — 돌진 중에만 보인다
@onready var _bike: Sprite2D = get_node_or_null("Bike")
## 총 노드(있으면 촉법소년) — 총 쏘는 스킬 중에만 보인다
@onready var _gun: Sprite2D = get_node_or_null("Gun")

var _fighter: Fighter
## 걸음 위상 — 계속 커지는 각도. sin()에 넣어서 앞뒤로 왔다갔다 하는 값을 만든다
var _phase: float = 0.0
## 숨쉬기 위상 — 계속 커지며 sin()으로 위아래 미묘한 움직임을 만든다 (idle breathing)
var _breathe_phase: float = 0.0
## 동작 세기 (0=제자리, 1=완전히 걷는 중). 멈출 때 툭 끊기지 않게 서서히 줄인다
var _blend: float = 0.0
## 점프 자세 세기 (0=바닥, 1=완전히 공중 자세). 뜨고 내릴 때 각도가 툭 튀지 않게 서서히 오간다
var _air_blend: float = 0.0
## 하강 자세 세기 (0=평소, 1=완전히 고개 숙임). 떨어지는 동안 서서히 오간다
var _fall_blend: float = 0.0
## 현재 스쿼시/스트레치 배율 (1,1이면 없음). 점프/착지 때 튀었다가 서서히 원래대로 돌아온다
var _squash: Vector2 = Vector2.ONE
## 스쿼시/스트레치가 진행 중인지 (원래 크기로 완전히 돌아오면 꺼진다)
var _squashing: bool = false
## 직전 프레임에 바닥에 있었는지 (착지 순간 감지용)
var _was_on_floor: bool = true
## 자전거를 탄(보이는) 정도 0~1. set_riding으로 목표를 정하고 서서히 오간다
var _ride_blend: float = 0.0
var _ride_target: float = 0.0
## 페달 회전 각도 (계속 커짐)
var _pedal_phase: float = 0.0
## 자전거의 "탄 위치"(씬에 저장된 제자리) — 여기서 뒤로 밀어 슬라이드 연출한다
var _bike_mounted_pos: Vector2
## 조작 없이 가만히 있은 시간(초). idle_motion_delay를 넘으면 idle 모션이 하나 시작된다
var _idle_time: float = 0.0
## 머리 긁는 동작에 남은 시간(초). 0보다 크면 긁는 중이다
var _scratch_time: float = 0.0
## 뒤돌아보는 동작에 남은 시간(초). 0보다 크면 돌아보는 중이다
var _lookback_time: float = 0.0
## 기본공격 스윙에 남은 시간(초). 0보다 크면 휘두르는 중이다
var _attack_time: float = 0.0
## 술 마시기 동작에 남은 시간(초). 0보다 크면 마시는 중이다
var _drink_time: float = 0.0
## 총 조준 동작에 남은 시간(초). 0보다 크면 총을 겨누는 중이다
var _gun_time: float = 0.0
## 총 조준 동작 전체 길이(스킬이 넘겨준다) — 진행도 계산용
var _gun_duration: float = 0.5
## 발사 반동 세기 0~1 — 쏠 때마다 1로 튀었다가 서서히 0으로 줄어든다
var _recoil: float = 0.0
## 파일드라이버 동작에 남은 시간(초). 0보다 크면 잡기~내리꽂기 동작 중이다
var _grab_time: float = 0.0
var _grab_duration: float = 1.0
## 전체 동작 중 "뻗어서 잡기"가 끝나는 지점, "들고 버티기"가 끝나는 지점(그 뒤는 내리꽂기)의 진행도 비율
var _grab_reach_ratio: float = 0.2
var _grab_slam_ratio: float = 0.8
## 토하는 얼굴을 보여줄 남은 시간(초). 0보다 크면 토하는 표정이다
var _vomit_time: float = 0.0
## 지금 술 머금은 얼굴 상태인지 (술 스택이 남아있는 동안 true)
var _drunk_head_on: bool = false
## 지금 스킬 액션 표정 상태인지 (자전거 돌진·총 쏘기 동안 true) — 취함/맨정신보다 우선한다
var _action_face_on: bool = false
## 토하기 전 원래 머리 텍스처/배율 — 토하기가 끝나면 이걸로 되돌린다
var _head_rest_texture: Texture2D
var _head_rest_scale: Vector2
## 씬에 저장돼 있던 각 조각의 제자리 위치 {Sprite2D: Vector2}
var _rest_positions: Dictionary = {}

func _ready() -> void:
	# Visual로 붙는 자리가 Fighter의 자식이라 부모가 곧 조종 대상이다.
	# 미리보기 도구처럼 Fighter 없이 띄우면 null이고, 그때는 가만히 서 있는다
	_fighter = get_parent() as Fighter
	for part in [_foot_l, _foot_r, _body, _head, _hand_l, _hand_r]:
		if part:
			_rest_positions[part] = part.position
	# 토하기가 끝나면 되돌릴 수 있게 원래 머리 그림/배율을 기억해둔다
	if _head:
		_head_rest_texture = _head.texture
		_head_rest_scale = _head.scale
	# 자전거는 평소엔 숨기고, "탄 위치"를 기억해둔다 (여기서 뒤로 밀어 슬라이드 연출)
	if _bike:
		_bike_mounted_pos = _bike.position
		_bike.visible = false

func _process(delta: float) -> void:
	var speed_ratio: float = 0.0
	# Fighter 없이(미리보기 도구 등) 띄운 경우엔 그냥 바닥에 서 있는 것으로 친다
	var on_floor: bool = true
	if _fighter and is_instance_valid(_fighter):
		on_floor = _fighter.is_on_floor()
		# 지금 속도가 그 캐릭터 최고 속도의 몇 %인지 — 느리게 걸으면 발도 덜 흔들리게 하려고 쓴다
		var max_speed: float = _fighter.stats.move_speed * _fighter.move_speed_multiplier
		if max_speed > 0.0:
			speed_ratio = clampf(absf(_fighter.velocity.x) / max_speed, 0.0, 1.0)

	# 숨쉬기 위상은 항상 진행 (가만히 서 있을 때만 화면에 반영된다)
	_breathe_phase += delta * breathe_speed

	if _attack_time > 0.0:
		_attack_time = maxf(_attack_time - delta, 0.0)
	if _drink_time > 0.0:
		_drink_time = maxf(_drink_time - delta, 0.0)
	if _vomit_time > 0.0:
		_vomit_time = maxf(_vomit_time - delta, 0.0)
		# 시간이 다 되면 원래 얼굴로 되돌린다
		if is_zero_approx(_vomit_time):
			_restore_head()
	# 총 조준 시간 카운트다운 — 끝나면 총을 다시 숨긴다
	if _gun_time > 0.0:
		_gun_time = maxf(_gun_time - delta, 0.0)
		if is_zero_approx(_gun_time) and _gun:
			_gun.visible = false
	# 발사 반동은 매 프레임 서서히 잦아든다
	if _recoil > 0.0:
		_recoil = maxf(_recoil - delta * gun_recoil_recover, 0.0)
	if _grab_time > 0.0:
		_grab_time = maxf(_grab_time - delta, 0.0)
		if is_zero_approx(_grab_time):
			rotation = 0.0   # 내리꽂기가 끝나면 뒤로/앞으로 기울였던 몸을 원래대로

	# 공중이면 점프 자세로, 바닥이면 원래 자세로 서서히 옮겨간다
	var air_target: float = 0.0 if on_floor else 1.0
	_air_blend = move_toward(_air_blend, air_target, delta * jump_blend_speed)

	# 공중에서 아래로 떨어지는 중(velocity.y > 0)이면 고개를 숙인다 — 올라가는 중엔 숙이지 않는다
	var falling: bool = not on_floor and _fighter != null and is_instance_valid(_fighter) and _fighter.velocity.y > 0.0
	_fall_blend = move_toward(_fall_blend, 1.0 if falling else 0.0, delta * fall_blend_speed)

	# 바닥에서 조작 없이(안 걷고·안 뛰고·안 때리고) 가만히 있으면 일정 시간마다 머리를 긁는다
	var idle: bool = on_floor and speed_ratio < 0.05 and _attack_time <= 0.0 and _drink_time <= 0.0 and _vomit_time <= 0.0 and _gun_time <= 0.0 and _grab_time <= 0.0
	if not idle:
		# 움직이거나 다른 동작이 시작되면 idle 모션 즉시 취소. 돌아보던 중이면 머리를 반드시 앞으로 되돌린다
		_idle_time = 0.0
		_scratch_time = 0.0
		_end_lookback()
	elif _scratch_time > 0.0:
		_scratch_time = maxf(_scratch_time - delta, 0.0)
	elif _lookback_time > 0.0:
		_lookback_time = maxf(_lookback_time - delta, 0.0)
		if is_zero_approx(_lookback_time):
			_end_lookback()   # 정상 종료 — 머리를 앞으로 되돌린다
	else:
		_idle_time += delta
		if _idle_time >= idle_motion_delay:
			_idle_time = 0.0
			# 머리 긁기 / 뒤돌아보기 중 하나를 랜덤으로 고른다
			if randf() < 0.5:
				_scratch_time = scratch_duration
			elif _head:
				_lookback_time = lookback_duration

	# 점프/착지 스쿼시&스트레치 — 착지하는 순간(공중→바닥)을 감지해 몸을 납작하게 눌렀다 편다
	if on_floor and not _was_on_floor:
		_squash = land_squash
		_squashing = true
	_was_on_floor = on_floor
	# 튄 크기는 시간이 지나며 원래(1,1)로 돌아온다
	if _squashing and not _squash.is_equal_approx(Vector2.ONE):
		_squash = _squash.move_toward(Vector2.ONE, delta * squash_recover_speed)

	# 자전거 타기 — 목표(_ride_target)로 서서히 오가며, 뒤에서 슬라이드해 들어오고 페이드된다
	if _bike:
		_ride_blend = move_toward(_ride_blend, _ride_target, delta * ride_blend_speed)
		if _ride_blend > 0.001:
			_bike.visible = true
			# blend 0이면 뒤(enter_offset)에 투명하게, 1이면 탄 위치에 선명하게
			_bike.position = _bike_mounted_pos + ride_enter_offset * (1.0 - _ride_blend)
			_bike.modulate.a = _ride_blend
			_pedal_phase += delta * pedal_speed
		else:
			_bike.visible = false

	if on_floor and speed_ratio > 0.05:
		_phase += delta * step_speed * maxf(speed_ratio, 0.3)
		_blend = minf(_blend + delta * blend_speed, 1.0)
	else:
		_blend = maxf(_blend - delta * blend_speed, 0.0)
		if is_zero_approx(_blend):
			# 완전히 멈췄으면 다음 걸음이 항상 같은 자세에서 시작하도록 위상을 초기화
			_phase = 0.0

	_apply_pose(speed_ratio)

func _apply_pose(speed_ratio: float) -> void:
	_face_moving_direction()

	var amount: float = _blend * maxf(speed_ratio, 0.4)
	# 자전거를 타는 동안엔 걷기 흔들림을 줄인다 (발은 아래에서 페달 동작으로 덮어쓴다)
	amount *= (1.0 - _ride_blend)

	# 두 발은 반 바퀴 어긋난 채로 계속 앞뒤를 오간다 — 한쪽이 앞으로 나가면 다른 쪽은 뒤로 밀리고,
	# 반 바퀴 뒤에 앞발과 뒷발이 뒤바뀐다
	var swing: float = sin(_phase)

	# 앞으로 나가는 동안(swing이 양수)에만 발끝을 들고, 뒤로 밀리는 동안엔 바닥을 딛는 것처럼 눕힌다.
	# 공중에서는 걷기 쪽이 0으로 잦아들고 대신 두 발이 함께 점프 각도로 뻗는다
	_pose_foot(_foot_l, maxf(swing, 0.0) * amount, swing * amount)
	_pose_foot(_foot_r, maxf(-swing, 0.0) * amount, -swing * amount)

	# 발이 가장 높이 들렸을 때 몸도 같이 뜨게 해서 한 걸음마다 한 번씩 들썩인다. 위쪽이 음수라 빼준다
	var bob: float = -absf(swing) * body_bob * amount
	# 가만히 서 있을 때(바닥·안 걷는 중)만 몸/머리/손이 숨쉬듯 위아래로 미묘하게 움직인다. 걷기 시작하면 서서히 사라진다.
	# 손은 몸통과 다른 박자(위상 차이)로, 좌우 손도 살짝 어긋나게 해서 같이 움직이는 어색함을 없앤다
	var on_floor_now: bool = _fighter == null or (is_instance_valid(_fighter) and _fighter.is_on_floor())
	var idle_f: float = (1.0 - _blend) if on_floor_now else 0.0
	var body_breathe: float = sin(_breathe_phase) * breathe_amount * idle_f
	var hand_amt: float = breathe_amount * breathe_hand_ratio * idle_f
	for part in [_body, _head]:
		if part:
			part.position.y = _rest_positions[part].y + bob + body_breathe
	if _hand_r:
		_hand_r.position.y = _rest_positions[_hand_r].y + bob + sin(_breathe_phase + breathe_hand_phase) * hand_amt
	if _hand_l:
		_hand_l.position.y = _rest_positions[_hand_l].y + bob + sin(_breathe_phase + breathe_hand_phase + 0.5) * hand_amt
	# 술 마시기·두 손 잡기가 매 프레임 덮어쓰므로, 오른손 회전과 마찬가지로 여기서 한 번 제자리로 되돌려둔다
	if _head:
		# 하강 중이면 고개를 아래로 숙인다 (마시기 동작이 있으면 아래에서 덮어써서 그쪽이 우선한다)
		_head.rotation = deg_to_rad(fall_head_tilt_deg) * _fall_blend
		# 토하는 얼굴일 때는 입 위치를 맞추기 위한 보정만 더한다(누적되지 않게 절대 위치로 잡는다)
		if _vomit_time > 0.0:
			_head.position = _rest_positions[_head] + Vector2(0.0, bob) + vomit_head_offset
	if _hand_l:
		_hand_l.rotation = 0.0

	# 손은 발과 반대로 흔들린다. sin은 앞쪽 절반(왼발이 나가는 동안)에 양수라
	# 그때 오른손이 앞으로 나가고 왼손이 뒤로 빠진다
	var arm: float = sin(_phase) * amount * hand_swing
	if _hand_l:
		_hand_l.position.x = _rest_positions[_hand_l].x - arm
	if _hand_r:
		_hand_r.position.x = _rest_positions[_hand_r].x + arm
		_hand_r.rotation = 0.0

	# 휘두르는 중이면 오른손 자세를 공격 동작으로 덮어쓴다
	if _attack_time > 0.0:
		_pose_attack_hand()

	# 마시는 중이면 머리와 오른손을 술 마시는 자세로 덮어쓴다 (공격보다 나중이라 우선한다)
	if _drink_time > 0.0:
		_pose_drink()

	# 총을 겨누는 중이면 두 손을 모아 총을 잡은 자세로 덮어쓴다 (걷기·공격보다 우선한다)
	if _gun_time > 0.0:
		_pose_gun()

	# 파일드라이버 중이면 오른손과 몸 전체 기울기를 잡기~내리꽂기 자세로 덮어쓴다
	if _grab_time > 0.0:
		_pose_grab()

	# 가만히 있을 때는 왼손으로 머리를 긁는다 (idle 생동감). 왼손만 건드려서 다른 동작과 안 겹친다
	if _scratch_time > 0.0:
		_pose_scratch()

	# 뒤돌아보는 중이면 몸은 그대로 두고 머리만 반대쪽을 본다
	if _lookback_time > 0.0:
		_pose_lookback()

	# 자전거를 타는 동안엔 두 발이 페달을 밟고, 두 손이 핸들바를 잡는다 (걷기 동작을 덮어쓴다)
	if _bike and _ride_blend > 0.3:
		_pose_pedal()
		_pose_ride_hands()

	# 손에 든 물건이 손을 그대로 따라가게 한다
	if _hand_r_hold and _hand_r:
		_hand_r_hold.position = _hand_r.position
		_hand_r_hold.rotation = _hand_r.rotation

	# 점프/착지 스쿼시를 루트 크기에 반영한다 (몸 전체가 늘거나 눌린다). 좌우 방향(scale.x 부호)은 유지한다
	if _squashing:
		var sgn: float = signf(_fighter.facing) if (_fighter != null and is_instance_valid(_fighter)) else 1.0
		if _squash.is_equal_approx(Vector2.ONE):
			scale = Vector2(sgn, 1.0)   # 정확히 원래 크기로 스냅하고 종료
			_squashing = false
		else:
			scale = Vector2(_squash.x * sgn, _squash.y)

## 발 하나의 자세를 잡는다.
## lift는 발끝을 드는 정도(0~1), slide는 제자리에서 앞뒤로 얼마나 나가 있는지(-1~1)
func _pose_foot(foot: Sprite2D, lift: float, slide: float) -> void:
	if foot == null:
		return
	# 걷기는 발끝이 위로 들리게(각도 양수 = 시계 방향이라 부호를 뒤집는다),
	# 점프는 반대로 발끝이 아래로 뻗게 해서 서로 반대 방향으로 돈다
	foot.rotation = deg_to_rad(-foot_swing_deg * lift + jump_foot_deg * _air_blend)
	foot.position.x = _rest_positions[foot].x + foot_stride * slide
	# 세로 위치는 항상 제자리로 되돌린다 — 페달 동작(자전거)이 바꿔놓은 발 Y가 돌진 후에 남지 않게
	foot.position.y = _rest_positions[foot].y

## 기본공격 스윙 — 오른손(과 손에 든 물건)을 뒤로 살짝 젖혔다가 앞으로 획 휘두르고 돌아온다.
## Fighter가 기본공격을 실제로 발동시킨 순간 호출한다
func play_attack_swing() -> void:
	_attack_time = attack_duration

## 예비동작이 끝나고 실제로 내리치기 시작하는 시점 (전체 시간 대비 비율)
const ATTACK_STRIKE_START: float = 0.4
## 내리치기가 끝나는 시점 — 이 뒤로는 원래 자세로 돌아온다
const ATTACK_STRIKE_END: float = 0.62

## 스윙 진행도에 따라 오른손의 각도와 위치를 잡는다 (걷기 동작보다 우선한다).
## 각도는 음수가 반시계 방향(무기가 위로 올라감), 양수가 시계 방향(아래로 내리침)이다
func _pose_attack_hand() -> void:
	var progress: float = 1.0 - _attack_time / attack_duration
	var angle: float
	var offset: Vector2
	if progress < ATTACK_STRIKE_START:
		# ① 손을 머리 뒤쪽 위까지 크게 넘긴다 (끝으로 갈수록 느려지게)
		var p: float = 1.0 - (1.0 - progress / ATTACK_STRIKE_START) * (1.0 - progress / ATTACK_STRIKE_START)
		angle = lerpf(0.0, -attack_raise_deg, p)
		offset = Vector2.ZERO.lerp(attack_raise_offset, p)
	elif progress < ATTACK_STRIKE_END:
		# ② 앞쪽 아래로 빠르게 내려찍는다 (실제로 때리는 구간)
		var p: float = (progress - ATTACK_STRIKE_START) / (ATTACK_STRIKE_END - ATTACK_STRIKE_START)
		angle = lerpf(-attack_raise_deg, attack_swing_deg, p * p)
		offset = attack_raise_offset.lerp(attack_slam_offset, p * p) + _swing_arc(p * p)
	else:
		# ③ 원래 자세로 복귀
		var p: float = (progress - ATTACK_STRIKE_END) / (1.0 - ATTACK_STRIKE_END)
		angle = lerpf(attack_swing_deg, 0.0, p)
		offset = attack_slam_offset.lerp(Vector2.ZERO, p)
	_hand_r.rotation = deg_to_rad(angle)
	_hand_r.position = _rest_positions[_hand_r] + offset
	_pose_grip_hand(progress)

## 후려치는 동안 손이 지나가는 길을 아래로 부풀린다. 예비동작 위치에서 내려찍는 위치로 가는
## 직선의 수직(아래쪽) 방향으로 밀어내며, sin이라 출발·도착에서는 0이라 튀지 않는다
func _swing_arc(t: float) -> Vector2:
	if is_zero_approx(attack_swing_arc):
		return Vector2.ZERO
	var travel: Vector2 = attack_slam_offset - attack_raise_offset
	if travel.length() < 0.001:
		return Vector2.ZERO
	return Vector2(-travel.y, travel.x).normalized() * attack_swing_arc * sin(t * PI)

## 두 손으로 잡는 캐릭터는 왼손이 오른손 옆으로 붙었다가, 내려찍고 나면 다시 풀린다.
## 무기는 오른손(HandRHold)에 매달려 있으므로 왼손은 위치·회전만 따라가면 같이 잡은 것처럼 보인다
func _pose_grip_hand(progress: float) -> void:
	if not attack_two_handed or _hand_l == null:
		return
	var grip: float
	if progress < ATTACK_STRIKE_START:
		# 예비동작 앞부분에서 왼손이 빠르게 붙는다 (때리기 전에 이미 두 손으로 잡고 있어야 한다)
		grip = minf(progress / (ATTACK_STRIKE_START * 0.6), 1.0)
	elif progress < ATTACK_STRIKE_END:
		grip = 1.0
	else:
		grip = 1.0 - (progress - ATTACK_STRIKE_END) / (1.0 - ATTACK_STRIKE_END)
	_hand_l.position = _rest_positions[_hand_l].lerp(_hand_r.position + attack_grip_offset, grip)
	_hand_l.rotation = _hand_r.rotation * grip

## 점프하는 순간 몸을 세로로 늘린다 (squash & stretch). Fighter.jump()이 호출한다
func play_jump_stretch() -> void:
	_squash = jump_stretch
	_squashing = true

## 자전거를 탄다/내린다 (촉법소년 돌진). 자전거 노드가 없는 캐릭터에선 아무 일도 안 한다.
## DashSkill이 돌진 시작에 true, 끝에 false로 부른다
func set_riding(on: bool) -> void:
	if _bike == null:
		return
	_ride_target = 1.0 if on else 0.0

## 자전거 탈 때 두 손을 앞(핸들바)으로 가져가 잡는다
func _pose_ride_hands() -> void:
	if _hand_l:
		_hand_l.position = ride_hand_l_pos
		_hand_l.rotation = 0.0
	if _hand_r:
		_hand_r.position = ride_hand_r_pos
		_hand_r.rotation = 0.0

## 두 발이 크랭크(pedal_center)를 중심으로 180도 어긋나게 원을 그리며 돈다 — 페달 밟기
func _pose_pedal() -> void:
	if _foot_l:
		_foot_l.position = pedal_center + Vector2(cos(_pedal_phase), sin(_pedal_phase)) * pedal_radius
		_foot_l.rotation = 0.0
	if _foot_r:
		_foot_r.position = pedal_center + Vector2(cos(_pedal_phase + PI), sin(_pedal_phase + PI)) * pedal_radius
		_foot_r.rotation = 0.0

## 술 마시기 동작 — 고개를 뒤로 젖히고 술병을 입으로 가져가 꿀꺽거린다.
## DrinkSkill이 술을 실제로 마신 순간 호출한다
func play_drink_motion() -> void:
	_drink_time = drink_duration

## 총 쏘기 동작 시작 — 몸에서 총을 꺼내 두 손을 모아 앞으로 겨눈다.
## BBGunSkill이 발동하는 순간 전체 지속시간을 넘겨서 호출한다 (총 노드가 없으면 아무 일도 안 한다)
func play_gun_motion(duration: float) -> void:
	if _gun == null:
		return
	_gun_duration = maxf(duration, 0.05)
	_gun_time = _gun_duration

## 한 발 쏠 때마다 반동을 준다 — BBGunSkill이 총알을 발사한 순간 호출한다
func gun_recoil() -> void:
	_recoil = 1.0

## 백 서플렉스 동작 시작 — 손을 뻗어 잡고, 뒤로 젖히며 들어올려, 등 뒤로 넘겨 꽂는다.
## BackSuplexSkill이 잡기가 성립한 순간 세 구간(뻗기/들어올리기/넘겨꽂기)의 길이를 넘겨서 호출한다
func play_grab_motion(reach_duration: float, hold_duration: float, slam_duration: float) -> void:
	_grab_duration = maxf(reach_duration + hold_duration + slam_duration, 0.05)
	_grab_reach_ratio = clampf(reach_duration / _grab_duration, 0.01, 0.98)
	_grab_slam_ratio = clampf((reach_duration + hold_duration) / _grab_duration, _grab_reach_ratio + 0.01, 0.99)
	_grab_time = _grab_duration

## 백 서플렉스 진행도에 따라 두 손과 몸 전체 기울기를 잡는다 (걷기·공격보다 우선한다).
## 두 손을 옆으로 뻗어 위아래로 겹쳐 잡는다(오른손 위/왼손 아래) — 한 손이 아니라 두 손으로
## 붙잡는 그림이라 왼손도 오른손과 같은 목표로 모은다
func _pose_grab() -> void:
	var progress: float = 1.0 - _grab_time / _grab_duration
	var hand_gap := Vector2(0, grab_hand_gap * 0.5)
	if progress < _grab_reach_ratio:
		# ① 두 손을 옆으로 뻗어 겹쳐 잡는다
		var p: float = progress / _grab_reach_ratio
		if _hand_r:
			_hand_r.position = _rest_positions[_hand_r].lerp(grab_reach_target - hand_gap, p)
		if _hand_l:
			_hand_l.position = _rest_positions[_hand_l].lerp(grab_reach_target + hand_gap, p)
		rotation = 0.0
	elif progress < _grab_slam_ratio:
		# ② 잡은 채로 들어올려 버틴다 — 몸은 안 기울이고 곧게 선 채 유지(손만 겹쳐 잡은 자세)
		if _hand_r:
			_hand_r.position = grab_reach_target - hand_gap
		if _hand_l:
			_hand_l.position = grab_reach_target + hand_gap
		rotation = 0.0
	else:
		# ③ 던지는 이 순간에만 몸을 뒤로 확 젖히며 상대를 등 뒤로 넘겨 꽂는다
		# (동작이 끝나면 _process가 제자리로 스냅)
		var p: float = (progress - _grab_slam_ratio) / (1.0 - _grab_slam_ratio)
		var target: Vector2 = grab_reach_target + grab_slam_hand_offset * p
		if _hand_r:
			_hand_r.position = target - hand_gap
		if _hand_l:
			_hand_l.position = target + hand_gap
		rotation = deg_to_rad(grab_slam_deg) * p
	if _hand_r:
		_hand_r.rotation = 0.0
	if _hand_l:
		_hand_l.rotation = 0.0

## 토하기 동작 — 잠깐 토하는 표정으로 머리를 바꾼다. VomitSkill이 토한 순간 호출한다.
## vomit_head_texture가 비어 있으면(주정뱅이 외 캐릭터) 아무 일도 안 한다
func play_vomit_face() -> void:
	if _head == null or vomit_head_texture == null:
		return
	_head.texture = vomit_head_texture
	if vomit_head_scale != Vector2.ZERO:
		_head.scale = vomit_head_scale
	_vomit_time = vomit_face_duration

## 토하는 표정이 끝나면 현재 상태(취함/맨정신)에 맞는 기본 머리로 돌아간다
func _restore_head() -> void:
	_apply_base_head()

## 술 스택 유무에 따라 "기본 머리"를 정한다 (맨정신=원래 얼굴 / 취함=술 머금은 얼굴).
## DrinkSkill이 true, VomitSkill이 false로 부른다. 토하는 표정이 떠 있는 동안엔 건드리지 않고,
## 그 표정이 끝나면 _restore_head가 여기서 정한 기본 머리로 돌아간다
func set_drunk_head(on: bool) -> void:
	_drunk_head_on = on
	if _vomit_time <= 0.0:
		_apply_base_head()

## 스킬(자전거 돌진·총 쏘기)을 쓰는 동안 액션 표정으로 머리를 바꾼다. on=false면 원래 상태로 되돌린다.
## action_head_texture가 비어 있으면(그 표정이 없는 캐릭터) 아무 일도 안 한다
func set_action_face(on: bool) -> void:
	if _head == null or action_head_texture == null:
		return
	_action_face_on = on
	if _vomit_time <= 0.0:   # 토하는 표정이 떠 있으면 그게 끝난 뒤 반영된다
		_apply_base_head()

## 현재 상태에 맞는 머리 그림·배율을 머리에 적용한다 (액션 표정 > 취함 > 맨정신 순 우선)
func _apply_base_head() -> void:
	if _head == null:
		return
	if _action_face_on and action_head_texture != null:
		_head.texture = action_head_texture
		_head.scale = action_head_scale if action_head_scale != Vector2.ZERO else _head_rest_scale
	elif _drunk_head_on and drunk_head_texture != null:
		_head.texture = drunk_head_texture
		_head.scale = drunk_head_scale if drunk_head_scale != Vector2.ZERO else _head_rest_scale
	else:
		_head.texture = _head_rest_texture
		_head.scale = _head_rest_scale

## 술병을 입까지 다 올리는 시점 (전체 시간 대비 비율)
const DRINK_RAISE_END: float = 0.25
## 다시 내리기 시작하는 시점
const DRINK_LOWER_START: float = 0.75

## 마시기 진행도에 따라 머리와 오른손 자세를 잡는다 (걷기·공격 동작보다 우선한다).
## reach는 "얼마나 다 마시는 자세인지"(0=제자리, 1=병이 입에 닿아 있음)
func _pose_drink() -> void:
	var progress: float = 1.0 - _drink_time / drink_duration
	var reach: float
	if progress < DRINK_RAISE_END:
		# ① 병을 입으로 올리며 고개를 젖힌다 (끝으로 갈수록 느리게)
		var p: float = progress / DRINK_RAISE_END
		reach = 1.0 - (1.0 - p) * (1.0 - p)
	elif progress < DRINK_LOWER_START:
		# ② 입에 댄 채로 마신다
		reach = 1.0
	else:
		# ③ 병을 내리고 고개를 제자리로
		var p: float = (progress - DRINK_LOWER_START) / (1.0 - DRINK_LOWER_START)
		reach = 1.0 - p * p

	# 꿀꺽거리는 들썩임. 머리와 병이 같이 움직여야 병이 입에서 안 떨어져 보인다
	var gulp: float = sin(progress * TAU * drink_gulp_count) * reach * drink_head_bob

	if _head:
		_head.rotation = deg_to_rad(drink_head_tilt_deg * reach)
		_head.position = _rest_positions[_head] + drink_head_offset * reach + Vector2(0.0, gulp)
	if _hand_r:
		# 이동 방향의 수직으로 부풀려서 호를 그리며 올라간다. sin이라 출발/도착에선 0이고 중간에 가장 크다
		var arc: Vector2 = Vector2(-drink_hand_offset.y, drink_hand_offset.x).normalized() 			* drink_hand_arc * sin(reach * PI)
		_hand_r.rotation = deg_to_rad(drink_hand_deg * reach)
		_hand_r.position = _rest_positions[_hand_r] + drink_hand_offset * reach + arc + Vector2(0.0, gulp)

## 총 조준 자세 — 몸에서 꺼내(앞 gun_draw_ratio 구간) 두 손을 모아 앞으로 겨눈다.
## 두 손과 총을 그립 위치에 두고, 발사 반동이 있으면 뒤로 살짝 밀어낸다 (걷기 동작보다 우선)
func _pose_gun() -> void:
	var progress: float = 1.0 - _gun_time / _gun_duration
	# 꺼내는 구간(0~draw_ratio)에서 그립이 몸에서 조준 위치로 부드럽게 이동, 이후엔 조준 위치 유지
	var t: float = clampf(progress / maxf(gun_draw_ratio, 0.001), 0.0, 1.0)
	var ease_t: float = t * t * (3.0 - 2.0 * t)   # smoothstep
	var grip: Vector2 = gun_draw_offset.lerp(gun_aim_offset, ease_t)
	# 발사 반동 — 뒤(-x)로 밀리며 살짝 들린다(-y)
	grip += Vector2(-gun_recoil_kick, -gun_recoil_kick * 0.4) * _recoil
	if _hand_r:
		_hand_r.position = grip
		_hand_r.rotation = 0.0
	if _hand_l:
		_hand_l.position = grip + gun_hand_l_offset
		_hand_l.rotation = 0.0
	if _gun:
		_gun.visible = true
		_gun.position = grip + gun_forward_offset
		_gun.rotation = 0.0

## 왼손을 머리로 올려 긁는 idle 동작 — 올리기(0~25%) → 긁기(25~75%) → 내리기(75~100%).
## reach는 "얼마나 머리에 닿은 자세인지"(0=제자리, 1=머리에 손이 닿음)
func _pose_scratch() -> void:
	if _hand_l == null:
		return
	var progress: float = 1.0 - _scratch_time / scratch_duration
	var reach: float
	if progress < 0.25:
		var p: float = progress / 0.25
		reach = 1.0 - (1.0 - p) * (1.0 - p)
	elif progress < 0.75:
		reach = 1.0
	else:
		var p: float = (progress - 0.75) / 0.25
		reach = 1.0 - p * p
	# 긁는 동안 손이 좌우로 잘게 떨린다 (출발·도착에선 reach가 0이라 안 떨림)
	var wiggle: float = sin(progress * TAU * scratch_count) * reach * scratch_amount
	_hand_l.position = _rest_positions[_hand_l] + scratch_hand_offset * reach + Vector2(wiggle, 0.0)
	_hand_l.rotation = deg_to_rad(scratch_hand_deg * reach)

## 왼쪽(-x)으로 갈 때는 몸 전체를 좌우로 뒤집는다.
## 궁극기 연출 등에서 Visual의 scale을 잠깐 늘였다 줄이는 경우가 있어서,
## 크기는 건드리지 않고 x의 부호만 바라보는 방향에 맞춘다
func _face_moving_direction() -> void:
	if not (_fighter and is_instance_valid(_fighter)):
		return
	var facing_x: float = absf(scale.x) * signf(_fighter.facing)
	if not is_equal_approx(scale.x, facing_x):
		scale.x = facing_x

## 몸은 그대로 두고 머리만 반대쪽을 돌아본다 — 머리 scale.x가 옆모습(0)을 지나 부호가 뒤집혔다가 돌아온다.
## 머리 세로 크기(scale.y)는 안 뒤집으므로 그게 곧 원래 크기다 — 가로를 거기에 맞춰 부호만 바꾼다
func _pose_lookback() -> void:
	if _head == null:
		return
	_head.scale.x = _head.scale.y * (1.0 - 2.0 * _lookback_reach())

## 뒤돌아보기를 끝내고 머리를 앞 방향으로 되돌린다 (정상 종료·중단 공통).
## 세로 크기(scale.y)가 원래 크기이므로 가로를 거기에 양수로 맞춘다 — 끊겨도 머리가 뒤집힌 채 굳지 않는다
func _end_lookback() -> void:
	_lookback_time = 0.0
	if _head:
		_head.scale.x = _head.scale.y

## 뒤돌아보기 진행도(0=앞을 봄, 1=완전히 뒤를 봄) — 돌아보기(0~30%) → 뒤를 본 채 정지(30~70%) → 앞으로(70~100%)
func _lookback_reach() -> float:
	var progress: float = 1.0 - _lookback_time / lookback_duration
	if progress < 0.3:
		return progress / 0.3
	elif progress < 0.7:
		return 1.0
	return (1.0 - progress) / 0.3
