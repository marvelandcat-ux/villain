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
@export var foot_stride: float = 11.0
## 걸을 때 앞으로 옮겨지는 발이 들리는 높이(px). 바닥을 디딘 발은 안 뜬다 — 한 발씩 들었다 놓는 걸음(2026-09-25).
## 0이면 예전처럼 두 발이 바닥에 붙은 채 미끄러진다
@export var foot_step_lift: float = 5.0
## 몸이 들썩이는 높이(px)
@export var body_bob: float = 4.0
## 손이 앞뒤로 흔들리는 거리(px)
@export var hand_swing: float = 7.0
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
## Fighter 없이 리그만 띄워놓고(궁극기 컷인 등) 걷기/달리기를 강제로 돌리고 싶을 때 쓴다.
## 0이면 가만히 서 있고 1이면 최고 속도로 달리는 것으로 친다. 음수(기본)면 예전처럼 가만히 서 있는다.
## Fighter가 있으면 이 값은 무시된다 — 인게임 동작은 그대로다
@export var manual_speed_ratio: float = -1.0
## 점프하는 순간 몸이 세로로 늘어나는 정도 (x가 작을수록 홀쭉, y가 클수록 길쭉). 세로 약 1.33배
@export var jump_stretch: Vector2 = Vector2(0.75, 1.33)
## 착지하는 순간 몸이 납작해지는 정도 (x가 클수록 넓적, y가 작을수록 납작)
@export var land_squash: Vector2 = Vector2(1.33, 0.75)
## 스쿼시/스트레치가 원래 크기(1,1)로 돌아오는 속도 (클수록 빨리 복구)
@export var squash_recover_speed: float = 2.5
## 스쿼시·스트레치의 기준점(리그 기준 y, 발바닥) — 몸 중심 기준으로 누르면 발이 바닥에서 뜨므로
## 이 높이가 제자리에 남도록 리그를 위아래로 보정한다(2026-09-26). 캡슐 반지름 20 + 절반 30 = 발바닥 +30
@export var squash_pivot_y: float = 30.0

## --- 자전거 타기 (촉법소년 돌진) ---
## 자전거가 "탄 위치"에서 이만큼 떨어진 곳(캐릭터 뒤쪽)에서 슬라이드해 들어온다. x가 음수면 진행 반대쪽(뒤)
@export var ride_enter_offset: Vector2 = Vector2(-70, 0)
## 자전거가 들어오고/빠져나가는 빠르기 (클수록 빨리)
@export var ride_blend_speed: float = 12.0
## 자전거 탈 때 리그 전체(사람+자전거)를 이만큼(px) 올린다 — 바퀴가 몸 콜라이더 바닥(발끝 +30) 아래로 파묻히지 않게
@export var ride_lift: float = 0.0
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
## --- 스킬 클래시 대치 자세 ---
## 두 손을 앞으로 뻗어 상대 손과 맞대는 자리(리그 원점 기준). 오른손이 여기서 gap의 절반만큼 위,
## 왼손이 절반만큼 아래로 간다
@export var clash_hand_target: Vector2 = Vector2(27, -8)
## 맞댄 두 손이 위아래로 벌어지는 간격(px)
@export var clash_hand_gap: float = 13.0
## 밀당에 따라 몸이 기우는 최대 각도(도). 밀어붙이면 앞으로, 밀리면 뒤로
@export var clash_lean_deg: float = 15.0
## 몸에 더해 고개가 추가로 꺾이는 각도(도). 밀리는 쪽 고개가 뒤로 젖혀지는 게 이 값이다
@export var clash_head_deg: float = 12.0
## 손이 앞뒤로 밀릴 때 몸통·머리가 따라가는 비율 (0이면 손만 움직인다)
@export_range(0.0, 1.0, 0.05) var clash_body_follow: float = 0.5
## 대치 자세로 들어가고 풀리는 빠르기
@export var clash_blend_speed: float = 10.0
## --- 스킬 클래시 주먹 러시 (2026-09-12) ---
## 연타 한 번마다 주먹이 번갈아 나간다 — 누르는 속도가 그대로 주먹질 속도가 된다.
## 예전엔 두 손을 맞대고 앞뒤로 밀었는데, "서로 미친 듯이 주먹을 내지르는" 그림으로 바꿨다
## 주먹 한 번을 뻗었다 거두는 데 걸리는 시간(초)
@export var clash_punch_time: float = 0.055
## 연타 한 번에 나가는 주먹 수. 2면 양손이 한 번씩 — 초당 8타면 주먹은 초당 16번
@export var clash_punches_per_press: int = 2
## 쌓일 수 있는 주먹 수 상한 — 너무 쌓이면 손을 뗀 뒤에도 한참 주먹질을 계속한다
@export var clash_punch_queue_max: int = 4
## 거둔 주먹이 머무는 자리(맞대는 자리 clash_hand_target 기준, 앞=+x)
@export var clash_punch_guard: Vector2 = Vector2(-14, 5)
## 주먹이 맞대는 자리보다 더 뻗어나가는 거리(px)
@export var clash_punch_overshoot: float = 5.0
## 주먹마다 높이가 위아래로 흩어지는 폭(px) — 같은 자리만 치면 기계처럼 보인다
@export var clash_punch_spread: float = 9.0
## 주먹을 뻗을 때 몸이 앞으로 들썩이는 양(px) — 팔로만 치면 가벼워 보인다
@export var clash_punch_body_kick: float = 2.0
## 주먹 잔상 개수 / 남아 있는 시간(초) / 처음 불투명도.
## 다 뻗은 순간마다 그 자리에 잔상을 남겨서 주먹이 여러 개로 보이게 한다
@export var clash_ghost_count: int = 8
@export var clash_ghost_life: float = 0.14
@export_range(0.0, 1.0, 0.05) var clash_ghost_alpha: float = 0.55

## 중력으로 떨어지는 동안(하강 중) 고개를 아래로 숙이는 각도(도). 양수가 아래를 보는 방향(마시기와 같은 규칙)
@export var fall_head_tilt_deg: float = 18.0
## 하강 자세로 바뀌고 풀리는 빠르기
@export var fall_blend_speed: float = 10.0

## 가만히 있을 때 나오는 idle 모션(머리 긁기 / 뒤돌아보기)을 아예 끈다.
## 일진 궁극기의 패거리처럼 **가만히 서 있어야 하는 몸**은 이걸 꺼둔다 — 배경 인물이 혼자
## 머리를 긁고 뒤를 돌아보면 시선을 뺏는다
@export var idle_gestures: bool = true
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
## 캐릭터별 특수 idle 몸짓 — 머리 긁기·뒤돌아보기와 번갈아 랜덤으로 나온다(2026-09-26 사용자 요청, 눈이 안 보이는 캐릭터의 생동감용).
## 1 안경 치켜올리기(악플러) / 2 딸꾹질(주정뱅이)
@export_enum("없음", "안경 올리기", "딸꾹질") var idle_special: int = 0
## 특수 몸짓 하나의 전체 길이(초)
@export var special_duration: float = 1.0
## 안경 올리기: 왼손이 가는 자리(리그 좌표 — 안경 코받침 근처)와 손 각도(도)
@export var glasses_hand_pos: Vector2 = Vector2(15, -27)
@export var glasses_hand_deg: float = -60.0
## 안경을 밀어 올릴 때 손이 더 올라가는 거리(px), 머리가 들리는 정도(px)·젖혀지는 각도(도)
@export var glasses_push: float = 3.0
@export var glasses_push_lift: float = 1.5
@export var glasses_push_deg: float = -4.0
## 딸꾹질: 횟수, 머리가 튀는 높이(px)·젖혀지는 각도(도), 머리 위에 뜨는 글자(비우면 안 뜸)
@export var hiccup_count: int = 2
@export var hiccup_hop: float = 4.0
@export var hiccup_deg: float = -9.0
@export var hiccup_text: String = "딸꾹!"
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
## 두 손으로 잡는 자세가 붙고 풀리는 속도(1/초). 예비동작(0.18초) 안에 다 붙어야 하므로
## 9 밑으로 내리면 때리는 순간에 아직 한 손인 것처럼 보인다
@export var attack_grip_speed: float = 12.0
## 두 손으로 잡을 때 왼손이 오른손에서 떨어져 있는 거리(px). 오른손보다 살짝 뒤·아래를 잡는다
@export var attack_grip_offset: Vector2 = Vector2(-10, 4)
## 켜면 위 간격을 **오른손이 돌아간 만큼 같이 돌린다** — 경봉처럼 긴 막대를 머리 위로 넘겨 잡을 때,
## 간격이 고정이면 왼손이 손잡이가 아니라 허공을 잡는다. 거의 안 도는 무기(악플러 키보드)는 끌 것
@export var grip_offset_follows_rotation: bool = false
## 두 손으로 잡는 동안 왼손이 올라가는 z_index. 악플러 키보드가 z_index 1이라, 왼손이 그 뒤에 그려져
## "한 손으로 잡은" 것처럼 보이던 문제를 막는다 — 잡는 동안만 키보드보다 앞(2)으로 올리고 끝나면 원래대로.
## 안경 올리기(z 3)와 동시에 나올 일이 없어 서로 안 싸운다. 대시 잔상(Visual째 z -2 복제)은 잡는 중이 아닐 때 나와 무관
@export var attack_grip_hand_z: int = 2
## 켜면 공격할 때만이 아니라 **평소에도** 두 손으로 무기를 잡고 있는다(악플러가 키보드를 판때기처럼 앞으로 들고 다님).
## 손을 따로 쓰는 스킬(마우스 던지기·되감기·마시기·총·잡기·돌 던지기) 중에는 저절로 풀려 그 동작을 안 방해한다.
## attack_two_handed도 같이 켜져 있어야 한다
@export var two_handed_always: bool = false
## 0 이상이면 **그 번째 타(0=1타)에만** 두 손으로 잡는다(지하철 아저씨 1타 단소 찌르기). -1이면 모든 타.
## attack_two_handed도 같이 켜져 있어야 한다
@export var grip_hit_index: int = -1
## 이 번째 타(0=1타)는 **오른손(HandRHold)을 축으로 손에 든 무기가 빠르게 한 바퀴 돈다**(악플러 3타 키보드 돌리기).
## 손·몸은 제자리에 두고 무기만 공전한다 — 도는 동안 반대 손(왼손 grip)은 잠깐 떨어졌다가 다 돌면 다시 잡는다.
## -1이면 안 돈다(기본 — 다른 캐릭터 영향 없음). 판정 시각(보통 40%)은 그대로라 "돌면서 맞는" 그림이 된다
@export var weapon_spin_hit: int = -1
## 무기가 도는 바퀴 수(1 = 한 바퀴)
@export var weapon_spin_turns: float = 1.0
## 도는 방향(+1 시계 / -1 반시계). 보는 방향에 따라 뒤집히면 부호를 바꾼다
@export var weapon_spin_dir: float = 1.0

## --- 키보드 선풍기 회전 (악플러 그랩 후 회전 난무) ---
## play_keyboard_fan(초)으로 켜면 두 손을 몸 앞에 모으고 무기를 그 자리에서 아주 빠르게 계속 돌린다.
## 회전 난무 공격(ComboMeleeAttack.spin_flurry) 동안의 시각 연출이다
## 두 손을 모으는 자리(리그 원점 기준, +x가 앞). 여기가 회전 축이 된다
@export var fan_hand_pos: Vector2 = Vector2(8, -6)
## 왼손이 오른손(축)에서 떨어져 잡는 거리 — 두 손이 겹치지 않게 벌린다
@export var fan_hand_l_offset: Vector2 = Vector2(-16, 2)
## 무기가 도는 속도(라디안/초). 크게 줄수록 빨라져 "선풍기 팬처럼" 끝이 안 보인다
@export var fan_spin_speed: float = 40.0
## 회전 중 무기를 원래 크기의 몇 배로 키울지(1이면 그대로). 도는 동안만 커졌다가 끝나면 원래 크기로
@export var fan_weapon_scale: float = 1.5
## 도는 무기의 잔상 개수 / 남는 시간(초) / 처음 투명도 — 빠르게 도는 키보드가 원반처럼 보이게 겹쳐 그린다
@export var fan_ghost_count: int = 6
@export var fan_ghost_life: float = 0.09
@export_range(0.0, 1.0, 0.05) var fan_ghost_alpha: float = 0.4
## 후려치는 구간에서 손이 직선이 아니라 이동 방향의 아래쪽으로 부풀며 호를 그리는 정도(px).
## 0이면 예전처럼 곧장 직선으로 간다. 아래로 훑어서 올려치는 스윙(악플러 키보드)에서 쓴다
@export var attack_swing_arc: float = 0.0
## 기본공격을 "휘두르기"가 아니라 "찌르기"로 바꾼다 (촉법소년 막대사탕).
## 켜면 콤보 2·3타 변주가 위아래로 크게 후리는 대신, 각도는 거의 그대로 두고
## 손이 뒤로 빠졌다가 앞으로 곧게 내질러진다. 기본은 꺼짐(다른 캐릭터 영향 없음)
@export var attack_thrust: bool = false

## --- 맨손/무기 전환 (경찰 경봉, 2026-09-30) ---
## **이 캐릭터가 무기를 들었다 넣었다 하는지.** 켜야 아래 `held_item_armed`가 무기 그림을 켜고 끈다 —
## 안 켜면 예전처럼 씬에 놓인 대로 늘 들고 있다(다른 캐릭터 영향 없음)
@export var weapon_switch: bool = false

## **손에 든 무기를 지금 들고 있는지.** `weapon_switch`가 켜졌을 때만 쓴다 —
## 경찰은 평소엔 맨손으로 싸우다 궁극기를 쓴 뒤 15초만 경봉을 든다
@export var held_item_armed: bool = true:
	set(value):
		held_item_armed = value
		queue_redraw()
## 무기를 안 든 동안엔 휘두르기 대신 **곧게 내지르는 잽**으로 친다(`attack_thrust`와 같은 궤적).
## 무기를 들면 다시 휘두른다 — 맨손으로 크게 후리면 허공을 긁는 것처럼 보인다
@export var unarmed_thrust: bool = false
## 잽을 뻗는 동안 **반대 손을 얼굴 앞에 올려 가드**한다(권투 자세). 무기를 들면 안 한다
@export var unarmed_guard_hand: bool = false
## 그때 반대 손이 가는 자리(쉬는 자리 기준)와 각도(도)
@export var unarmed_guard_offset: Vector2 = Vector2(10, -14)
@export var unarmed_guard_deg: float = -25.0
## 가드 자세로 들고 내리는 빠르기(초당 블렌드 양) — 10이면 0.1초에 다 올라간다.
## 손이 가드 자리로 한 프레임에 순간이동하지 않게, 잽을 뻗던 손도 가드에서 출발해 뻗는다
@export var unarmed_guard_blend_speed: float = 10.0

@export_group("쌍 악기 자세 (지하철 아저씨 궁)")
## **왼손에도 악기를 들었는지.** 궁(`DualInstrumentUltimate`)이 켜고 끈다 —
## 켜면 `HandLHold` 자식(검은 리코더)이 보이고, 서 있기·걷기·방어·대시 자세가 통째로 바뀐다
@export var held_item_l_armed: bool = false
## **왼손 물건을 지금 던져서 손에 없다.** 켜면 `held_item_l_armed`여도 리코더가 안 보인다 —
## 던진 리코더(`ThrownRecorder`)가 날아가는 동안 켜지고, 품에 돌아오면 그쪽이 다시 끈다
var held_item_l_thrown: bool = false
## 자세가 섞여 드는 속도(1/초). 궁을 켠 순간 뚝 바뀌지 않고 스르르 잡힌다
@export var dual_blend_speed: float = 11.0
## **서 있기·걷기** — 단소(오른손)는 뒤로 낮게, 리코더(왼손)는 앞 위로 세운다(사용자 그림 3)
@export var dual_hand_r_pos: Vector2 = Vector2(20, 4)
@export var dual_hand_r_deg: float = -127.0
@export var dual_hand_l_pos: Vector2 = Vector2(10, -8)
@export var dual_hand_l_deg: float = -45.0
## **방어** — 두 악기를 몸 앞에서 X자로 교차한다(사용자 그림 1). 숙이는 정도는 평소 방어(`guard_crouch`)와 같다
@export var dual_guard_hand_r_pos: Vector2 = Vector2(20, 2)
@export var dual_guard_hand_r_deg: float = -92.0
@export var dual_guard_hand_l_pos: Vector2 = Vector2(-12, 2)
@export var dual_guard_hand_l_deg: float = -40.0
## **대시(돌진 공격)** — 몸을 앞으로 기울이고 두 악기를 뒤로 눕혀 지나간다(사용자 그림 2 첫 프레임)
@export var dual_dash_hand_r_pos: Vector2 = Vector2(6, -2)
@export var dual_dash_hand_r_deg: float = -168.0
@export var dual_dash_hand_l_pos: Vector2 = Vector2(-10, -6)
@export var dual_dash_hand_l_deg: float = -176.0
## 대시 중 상체가 앞으로 기우는 각도(도). **facing 부호는 코드가 곱한다**
@export var dual_dash_lean_deg: float = 26.0
## ⚠️ 쌍 악기 동안 **왼손과 리코더를 머리 앞으로** 올리는 z. 리그 순서가 …왼손 → 머리라서,
## 안 올리면 위로 세운 리코더가 머리 그림에 통째로 가린다(실측). 손이 악기보다 앞이다
@export var dual_hand_l_z: int = 3
@export var dual_hold_l_z: int = 2
## 단소(오른손 쪽)도 같이 올린다 — X자로 교차할 때 한쪽만 머리에 가리면 X가 안 읽힌다
@export var dual_hold_r_z: int = 2
## **오른손도 머리 앞으로 올린다.** 리그 그리는 순서가 …오른손 → 머리라서, 안 올리면
## 손을 머리 높이로 들어올리는 자세(3타 X자)에서 **오른손만 머리 뒤에 숨는다**(실측).
## 왼손은 `dual_hand_l_z`가 이미 올리고 있었는데 오른손만 빠져 있었다
@export var dual_hand_r_z: int = 3

## --- 자세를 **씬 파일로** 잡기 (2026-10-02) ---
## 아래 네 자세는 숫자 export 대신 **포즈 씬**으로 잡는다. 씬 안에서 머리·몸·두 손·두 발·
## 리코더·단소를 직접 끌어다 놓으면 그 **위치와 각도**가 그대로 게임에 쓰인다.
## 비워 두면 위쪽 숫자 export(`dual_guard_*`, `dual_dash_*`)로 돌아간다 — 그래서 중간에 지워도 안 깨진다.
## 크기(scale)는 안 읽는다 — 걷기·머리 돌리기가 크기를 건드리기 때문에 서로 싸우게 된다
@export var dual_guard_pose: PackedScene = null
## **평소 방어 자세를 씬 파일로 잡는다.** 쌍 악기와 무관하게 이 리그를 쓰는 캐릭터면 적용된다.
## 위의 쌍 악기용 칸이 채워져 있고 지금 쌍 악기를 들었으면 그쪽이 먼저다.
## 비워 두면 예전처럼 숫자 export(`guard_hand_*`, `guard_crouch` 등)로 잡는다
@export var guard_pose: PackedScene = null
## 돌진 **준비**(뒤로 물러나는 동안) / **돌진 중**(앞으로 내지르는 동안) / **끝난 직후**(마무리) 세 장
@export var dual_dash_ready_pose: PackedScene = null
@export var dual_dash_run_pose: PackedScene = null
@export var dual_dash_end_pose: PackedScene = null

@export_group("박수 (층간소음 빌런 2번)")
## 손이 **떨어졌을 때** 자세 씬과 **붙었을 때** 자세 씬. 둘 사이를 왔다 갔다 하며 박수가 된다
@export var clap_open_pose: PackedScene = null
@export var clap_close_pose: PackedScene = null
## 1초에 치는 박수 횟수
@export var clap_rate: float = 3.2
## 박수 자세가 섞여 들고 빠지는 빠르기(1/초)
@export var clap_blend_speed: float = 14.0
## 박수 자세가 **다리와 몸통까지 붙잡을지.** 꺼 두면(기본) **두 손과 머리만** 잡고
## 다리·몸통은 걷기에 맡긴다 — 그래야 박수를 치면서 걸을 때 발이 움직인다.
## 켜면 자세 씬에 잡아 둔 다리 자리로 굳는다(제자리에서만 칠 때 쓴다)
@export var clap_holds_legs: bool = false
## 박수 박자에 맞춰 **머리가 위아래로 까딱이는 폭(px)**. 손뼉이 마주칠 때 아래로, 벌어질 때 위로 간다.
## 0이면 머리는 가만히 있는다
@export var clap_head_bob: float = 1.6

@export_group("아이 우는 얼굴")
## 1번 스킬(악쓰기) 동안 아이 머리에 끼울 **우는 얼굴** 그림. 비워 두면 얼굴은 안 바뀐다
@export var kid_cry_texture: Texture2D = null
## 우는 얼굴일 때 쓸 크기. (0,0)이면 평소 아이 머리 크기를 그대로 쓴다
@export var kid_cry_scale: Vector2 = Vector2.ZERO

@export_group("기본 자세 씬")
## **가만히 서 있을 때의 자리를 씬 파일로 잡는다.** 넣어 두면 켜질 때 그 씬에서
## 머리·몸·두 손·두 발·안고 있는 것의 **자리와 각도를 읽어 제자리로 삼는다**.
##
## 리그를 직접 안 건드려도 되고, 포즈 씬은 크게 띄워 놓고 잡을 수 있어서 눈대중이 쉽다.
## 비워 두면(기본) 예전처럼 리그에 저장된 자리를 그대로 쓴다 — 다른 캐릭터는 영향이 없다.
## 씬에 없는 조각은 안 건드린다
@export var rest_pose: PackedScene = null

@export_group("안고 있기 (층간소음 빌런)")
## **한쪽 팔로 안고 있는 것**을 보일지. 리그에 `Carry` 노드를 자식으로 달아 두면 이 값에 따라 보였다 숨었다 한다.
## 쌍 악기(`held_item_l_armed`)와 달리 **자세는 하나도 안 바꾼다** — 그냥 들고 다니는 것일 뿐이다.
## 층간소음 빌런 2번 스킬이 아이를 내려놓는 동안 이걸 꺼서 품에서 사라지게 한다
@export var carrying: bool = true
## 걸을 때 몸이 들썩이는 만큼 아이도 같이 들썩일지. 끄면 제자리에 고정된다
@export var carry_follows_body: bool = true
## **아이가 옆에서 같이 걷게 할지.** 엄마가 걷는 박자에 맞춰 아이 발이 앞뒤로 오가고 몸이 들썩인다.
## 끄면 아이가 뻣뻣하게 끌려만 다닌다
@export var carry_walks: bool = true
## 아이 발이 앞뒤로 오가는 폭(px)과 디딜 때 들리는 높이(px)
@export var kid_step_swing: float = 3.0
@export var kid_step_lift: float = 2.0
## 아이 손이 발과 **반대로** 흔들리는 폭(px) — 걷는 사람은 팔과 다리가 엇갈린다
@export var kid_hand_swing: float = 2.2
## 아이 몸·머리가 한 걸음마다 들썩이는 높이(px)
@export var kid_bob: float = 1.2
## **엄마가 뛰면 아이도 같이 뛴다** — 두 발이 모여 접히고 몸이 살짝 뜬다.
## 공중에 뜬 정도(`_air_blend`)를 그대로 쓰므로 엄마가 착지하면 아이도 같이 내려온다
@export var kid_jump_lift: float = 4.0
## 뛸 때 두 발이 가운데로 모이는 폭(px)과 접히는 각도(도)
@export var kid_jump_tuck: float = 2.5
@export var kid_jump_deg: float = 38.0
## 뛸 때 두 손이 위로 들리는 높이(px)
@export var kid_jump_hand: float = 3.0

@export_subgroup("품으로 안기기")
## **아이가 폴짝 뛰어 품에 안긴 자세**를 잡아 둔 씬. 1번 스킬(악쓰기)을 쓰면 옆에서 걷던 아이가
## 여기 적어 둔 자리로 뛰어올라 안기고, 소리를 다 지르면 제자리로 내려온다.
##
## `Carry` 하나만 옮겨 두면 아이가 통째로 따라온다 — 아이 조각을 따로 잡으면 안긴 자세까지 바뀐다.
## 비워 두면 안기는 연출 없이 옆에서 그냥 소리만 지른다
@export var hug_pose: PackedScene = null
## 뛰어올라 안기는 데 걸리는 시간(초)과 다시 내려서는 데 걸리는 시간(초)
@export var hug_rise_time: float = 0.22
@export var hug_fall_time: float = 0.2
## 뛰는 동안 **위로 솟는 높이(px)**. 가는 길 가운데에서 가장 높이 뜬다 — 0이면 미끄러져 올라간다
@export var hug_arc: float = 16.0
## 안긴 자세가 **엄마 다리와 몸통까지 붙잡을지.** 꺼 두면(기본) 아이와 두 손·머리만 잡고
## 다리는 걷기에 맡긴다 — 아이를 안은 채로도 걸어다닐 수 있다
@export var hug_holds_legs: bool = false
## **아이를 안고 있는 동안 지을 표정**(우쭈쭈 얼굴). 스킬 키를 누르는 순간 바뀌고 아이를 내려놓으면 돌아온다.
## 박수 표정(`action_head_texture`)과 **다른 칸**이다 — 둘 다 켜져 있으면 이쪽이 이긴다.
## 비워 두면 표정은 안 바뀐다
@export var hug_head_texture: Texture2D = null
## 그 표정일 때 머리 배율. (0,0)이면 평소 머리 배율을 그대로 쓴다
@export var hug_head_scale: Vector2 = Vector2.ZERO

@export_subgroup("아이 드롭킥")
## **평타 마무리에서 아이가 앞으로 날아가 발길질**하고 **왔던 길 그대로** 돌아온다.
## 나갔다 들어오는 한 번이 이 시간(초) 안에 다 끝난다
@export var kid_kick_time: float = 0.4
## 앞으로 나가는 거리(px)와 뜨는 높이(px), 날아가는 동안 **눕는 각도**(도).
## 높이는 캐릭터 허리쯤까지 올라가야 "아래를 내려찍는" 게 아니라 **정면으로 날아가는** 드롭킥이 된다.
## 각도도 −70도쯤 줘야 몸이 눕고 발이 앞으로 나간다(2026-10-04 사용자 요청)
@export var kid_kick_reach: float = 62.0
@export var kid_kick_lift: float = 34.0
@export var kid_kick_deg: float = -72.0
## **얼마나 빨리 다 올라가 눕는지**(작을수록 빠르다). 1이면 앞으로 나가는 것과 같은 박자로 천천히 올라가
## 포물선처럼 보이고, 0.3쯤이면 **먼저 솟아 눕고 그 높이로 쭉 날아간다**
@export_range(0.1, 1.0, 0.05) var kid_kick_rise: float = 0.3
## **아이가 도는 축**으로 삼을 조각 이름. 비워 두면 `Carry` 원점을 축으로 도는데,
## 그 원점은 아이 몸에서 멀찍이 떨어져 있어서 돌리면 아이가 큰 호를 그리며 휙 휘둘린다(2026-10-04 지적)
@export var kid_kick_pivot: String = "KidBody"
## 날아가는 동안 두 발이 앞으로 뻗는 양(px)과 각도(도)
@export var kid_kick_legs: float = 11.0
@export var kid_kick_leg_deg: float = -45.0

@export_subgroup("영역 점프 자세")
## **궁극기(영역전개) 안에서 뛸 때**만 쓰는 세 장 — 준비(굽힘) → 최고점 → 착지.
## 엄마와 아이를 **한 씬에서 같이** 잡는다(아이는 Carry 밑 조각들).
## 비워 둔 칸은 건너뛰므로 세 장을 다 안 채워도 된다
@export var domain_jump_ready_pose: PackedScene = null
@export var domain_jump_peak_pose: PackedScene = null
@export var domain_jump_land_pose: PackedScene = null
## 자세가 다 넘어가는 기준 속도(px/s). 뛰어오르는 속도가 이 값이면 준비 자세, 0이면 최고점 자세다
@export var domain_jump_speed: float = 450.0
## 착지하고 착지 자세가 풀리는 데 걸리는 시간(초)
@export var domain_jump_land_time: float = 0.16

@export_group("평타 자세 씬")
## **기본공격 1·2·3타**를 각각 세 장으로 잡는다 — 준비(ready) → 중간(mid) → 마무리(end).
## 세 장을 **키프레임**으로 두고 그 사이를 이어 붙여 궤도를 만든다(중간 장이 궤도를 정한다).
##
## 비워 둔 칸은 그냥 건너뛴다 — 두 장만 채우면 그 둘 사이를 잇고, 한 장만 채우면 치는 내내 그 자세로 굳고,
## 한 타를 통째로 비우면 그 타는 **원래 휘두르기 동작** 그대로 간다. 9장을 다 안 써도 된다.
## 채워 둔 타는 발차기·무기 돌리기 같은 기본 동작을 덮어쓴다(씬에 잡아 둔 게 전부 이긴다)
@export var hit1_ready_pose: PackedScene = null
@export var hit1_mid_pose: PackedScene = null
@export var hit1_end_pose: PackedScene = null
@export var hit2_ready_pose: PackedScene = null
@export var hit2_mid_pose: PackedScene = null
@export var hit2_end_pose: PackedScene = null
@export var hit3_ready_pose: PackedScene = null
@export var hit3_mid_pose: PackedScene = null
@export var hit3_end_pose: PackedScene = null
## **4타는 궁(쌍 악기)을 쓴 동안에만 나온다** — 평소 콤보는 3타에서 끝난다.
## 늘리는 건 `ComboMeleeAttack.bonus_hits`가 하고, 여기는 그 타의 자세만 맡는다
@export var hit4_ready_pose: PackedScene = null
@export var hit4_mid_pose: PackedScene = null
@export var hit4_end_pose: PackedScene = null

## **세 장을 곡선으로 잇는다(기본).** 끄면 장과 장 사이를 곧은 선으로 잇는다.
## 켜면 세 점을 지나는 부드러운 곡선이 되어 **반원을 그리며 휘두르는 궤도**가 나온다 —
## 단, 곡선도 세 장을 **지나가는** 것이라 **가운데 장이 곧 호(弧)의 바닥**이어야 한다.
## 가운데 장을 몸 옆에 두면 곡선이든 직선이든 몸 아래로 안 내려간다
@export var attack_pose_curve: bool = true

@export_group("평타 자세 씬 (쌍 악기 = 궁 중)")
## **궁(쌍 악기)을 쓴 동안의 평타 자세.** 위 칸과 똑같은 구조인데, 왼손에 리코더가 있는 동안만 이쪽을 쓴다.
## 평소 콤보(발차기·단소)와 궁 콤보(리코더 던지기·두 손 가격·한 바퀴)는 동작이 아예 달라서 따로 잡는다.
## **비워 두면 위의 평소 칸을 그대로 쓴다** — 궁 중에만 바뀌는 타만 채우면 된다
@export var dual_hit1_ready_pose: PackedScene = null
@export var dual_hit1_mid_pose: PackedScene = null
@export var dual_hit1_end_pose: PackedScene = null
@export var dual_hit2_ready_pose: PackedScene = null
@export var dual_hit2_mid_pose: PackedScene = null
@export var dual_hit2_end_pose: PackedScene = null
@export var dual_hit3_ready_pose: PackedScene = null
@export var dual_hit3_mid_pose: PackedScene = null
@export var dual_hit3_end_pose: PackedScene = null

## 잽을 **정면으로 곧게** 내지른다 — 살짝 당겼다가(raise) 앞으로 쭉. 위아래로 안 흔들린다
@export var jab_raise_off: Vector2 = Vector2(-7, 0)
## **다 뻗었을 때 주먹이 닿는 x(리그 기준 절대값).** 두 손은 쉬는 자리가 서로 달라서
## 같은 거리만큼 밀면 뻗은 끝이 어긋난다 — **어느 손으로 쳐도 여기까지** 와야 1타·2타 사거리가 같다
@export var jab_reach_x: float = 62.0
## 잽은 주먹 각도를 거의 안 바꾼다(휘두르는 게 아니라 내지르는 것이라)
@export var jab_raise_deg: float = 0.0
@export var jab_swing_deg: float = 0.0
## **1타와 2타를 서로 다른 손으로 친다**(원투). 켜면 홀수 타는 반대 손이 나가고, 쉬는 손이 가드를 잡는다
@export var unarmed_alternate_hands: bool = true

## 특정 타를 치는 동안 **몸통 그림을 이걸로 갈아 끼운다**(경찰 2타 = 측면 몸통, 2026-09-30).
## 앞손으로 칠 땐 몸이 옆을 보고 있어야 뻗는 맛이 사는데, 정면 몸통 그림으로는 그게 안 보인다
@export var attack_body_texture: Texture2D = null
## 갈아 끼울 타 번호(0부터). 비어 있으면 안 바꾼다
@export var attack_body_hits: Array[int] = []
## 그중 **좌우를 뒤집어 쓸** 타 번호 — 같은 측면 그림으로 반대쪽에서 친 것처럼 보이게 한다
@export var attack_body_flip_hits: Array[int] = []

## **한 타 동안 순서대로 넘길 몸통 그림**(2026-09-30). 넣은 장수만큼 **균등하게 나눠서** 차례로 보여준다 —
## 예: [정면, 45도, 측면]이면 치는 동안 몸이 정면에서 옆으로 돌아가는 세 프레임이 된다.
## 비워 두면 위 `attack_body_*` 규칙을 따른다
@export var uppercut_body_textures: Array[Texture2D] = []
## 그 그림 순서를 쓸 타 번호(0부터). 경찰은 1타와 어퍼컷(3타)이 여기 들어간다
@export var attack_frame_hits: Array[int] = []

## --- 맨손 마무리 = 어퍼컷 (경찰 3타, 2026-09-30 러프) ---
## 켜면 맨손일 때 **마무리 타(`final_hit_index` 이상)만** 잽 대신 어퍼컷이 된다 —
## 주먹이 아래에서 앞으로 크게 휘어 올라가고, 그 사이 고개와 상체가 점점 돌아간다
@export var unarmed_uppercut: bool = false
## **어퍼컷을 시작하는 주먹 자리**(리그 기준 절대 좌표). 러프처럼 **몸 앞 배 높이**에서 출발한다 —
## 쉬는 자리(뒷손은 x=-27)에서 그냥 내리면 주먹이 몸통과 다리 사이를 파고든다
@export var uppercut_start: Vector2 = Vector2(-15, -38)
## **올려친 주먹이 멈추는 자리**(리그 기준 절대 좌표). 시작점과 이 점, 그리고 `uppercut_arc`가 궤도를 만든다
@export var uppercut_end: Vector2 = Vector2(58, -55)
## 감을 때/올려칠 때 주먹 각도(도). 음수가 위로 젖히는 쪽이다
@export var uppercut_raise_deg: float = -15.0
@export var uppercut_swing_deg: float = -75.0
## 궤도가 얼마나 볼록하게 휘는지(px). 클수록 아래로 크게 돌아 올라온다
## 궤도가 휘는 정도(px). **너무 크면 주먹이 몸 안쪽으로 파고든다** — 앞에서 올려치는 호만 남긴다
@export var uppercut_arc: float = 48.0
## 켜면 **어퍼컷 궤도를 화면에 그려준다**(시작점·끝점·휘는 길). 자리를 잡을 때만 켜고 끄면 된다
@export var uppercut_debug_path: bool = false:
	set(value):
		uppercut_debug_path = value
		queue_redraw()
## **머리+몸통을 한 덩어리로 묶어 돌릴 때 쓰는 축**(리그 기준 좌표, 머리 위).
## 각자 제자리에서 돌리면 목이 꺾이는 것처럼 보인다 — 머리 위 한 점에 매달린 것처럼 같이 돌아야 상체가 통째로 넘어간다
@export var uppercut_pivot: Vector2 = Vector2(0, -62)
## **감을 때** 그 축을 중심으로 도는 각도(도, 양수 = 시계 방향) — 몸을 말아 넣는 구간
@export var uppercut_turn_deg: float = 38.0
## **칠 때** 반대로 젖히는 각도(도, 음수 = 반시계) — 말았던 몸을 펴면서 올려친다
@export var uppercut_turn_back_deg: float = -30.0
## 다 감은 자세를 그대로 **버티는 구간**(때리는 구간 중 앞 몇 %).
## **0이면 몸이 돌아가는 것과 주먹이 나가는 것이 딱 같이 시작하고 같이 끝난다**(2026-09-30 사용자 지정) —
## 0보다 크면 몸이 잠깐 버틴 뒤에 펴지므로 주먹이 먼저 나가는 것처럼 보인다
@export_range(0.0, 0.8, 0.05) var uppercut_hold: float = 0.0
## 머리만 추가로 더 기울이고 싶을 때(0이면 몸통과 똑같이 돈다)
@export var uppercut_head_extra_deg: float = 0.0
## 상체가 같이 돌아가는 각도(도)와 앞으로 나가는 거리(px)
## **어퍼컷 때 발 보폭**(px) — 앞발은 앞으로, 뒷발은 뒤로 이만큼 벌어진다(높이는 그대로)
## **어퍼컷을 시작할 때 앞발(오른발)이 내딛는 거리(px).** 뒷발은 제자리에 둔다 —
## 한 발짝 들어가면서 치는 그림(2026-09-30 러프)
@export var uppercut_step: float = 14.0
@export var uppercut_body_forward: float = 11.0
## **감는 동안 이미 몇 %까지 젖혀 둘지**(0~1). 러프 1프레임이 벌써 크게 돌아가 있어서,
## 때리는 순간에야 돌기 시작하면 그 그림이 안 나온다 — 미리 이만큼 돌려놓고 치면서 마저 돈다
@export_range(0.0, 1.0, 0.05) var uppercut_windup_lean: float = 0.75
## **감을 때 몸이 내려앉는 깊이(px)와, 칠 때 솟아오르는 높이(px).**
## 어퍼컷은 낮췄다가 올라오는 힘으로 치는 동작이라, 몸통이 같이 내려갔다 올라와야 맛이 산다(러프 2->3프레임)
@export var uppercut_crouch: float = 9.0
@export var uppercut_rise: float = 12.0
## --- 맨손 마무리 = 박치기 (황근출 해병 3타, 2026-10-01) ---
## 켜면 맨손일 때 **마무리 타(`final_hit_index` 이상)**가 주먹 대신 박치기가 된다 —
## 상체를 뒤로 젖혀 머리를 치켜들었다가(감기) 앞 아래로 내리찍고(치기) 돌아온다. 어퍼컷보다 먼저 본다
@export var unarmed_headbutt: bool = false
## 상체(몸통·머리·두 손)를 통째로 돌리는 축(리그 기준, 엉덩이 근처) — 발은 안 움직인다
@export var headbutt_pivot: Vector2 = Vector2(0, 22)
## 감을 때 뒤로 젖히는 각도(도, 음수 = 뒤) / 박을 때 앞으로 숙이는 각도(도, 양수 = 앞 아래)
@export var headbutt_back_deg: float = -22.0
@export var headbutt_slam_deg: float = 30.0
## 머리만 더 끄덕이는 각도(도) — 박는 순간 고개가 한 번 더 꺾여 "쿵" 하는 맛을 낸다
@export var headbutt_nod_deg: float = 12.0
## 젖힐 때 솟는 높이(px) / 박을 때 앞으로 나가는 거리(px)
@export var headbutt_rise: float = 4.0
@export var headbutt_forward: float = 8.0
## 박는 동안 치는 손은 뒤로 젖혀 균형을 잡는다(쉬는 자리에서 더하는 값)
@export var headbutt_hand_back: Vector2 = Vector2(-8, 3)

## 마지막 타에만 오른손 무기를 쥔다 — 평소·앞 타에는 `idle_weapon`(반대 손에 늘어뜨린 물건)이 보인다.
## 일진처럼 "가방을 옆에 들고 다니다 주먹으로 때리고, 마지막에 가방으로 후려치는" 캐릭터용
@export var weapon_on_final_hit: bool = false
## 평소에 들고 있는 쪽 물건 노드 (weapon_on_final_hit이 켜져 있을 때만 쓴다)
@export var idle_weapon: NodePath
## 몇 번째 타를 마지막으로 볼지 (0=1타). 3타 콤보면 2
@export var final_hit_index: int = 2
## 마지막 타에만 보일 무기 노드 (비워 두면 HandRHold 전체를 숨긴다).
## HandRHold에 담배처럼 따로 껐다 켜는 물건이 같이 달려 있으면 이걸 지정해야 그 물건이 안 딸려 숨는다
@export var weapon_node: NodePath
## 찌르기 캐릭터의 2타 — "아래에서 위로 올려치기". 1타 찌르기와 완전히 다른 궤적이어야
## 세 타가 한 동작으로 안 보인다. 각도 부호는 위와 같다(양수 raise=무기가 위로 감김)
@export var thrust2_raise_deg: float = -40.0
@export var thrust2_swing_deg: float = -55.0
@export var thrust2_raise_offset: Vector2 = Vector2(-10, 14)
@export var thrust2_slam_offset: Vector2 = Vector2(14, -20)
## 찌르기 캐릭터의 3타 — "머리 뒤로 크게 넘겼다가 바닥까지 내려찍기" (마무리 타)
@export var thrust3_raise_deg: float = 100.0
@export var thrust3_swing_deg: float = 130.0
@export var thrust3_raise_offset: Vector2 = Vector2(-26, -22)
@export var thrust3_slam_offset: Vector2 = Vector2(16, 6)

## --- 격투게임식 끊어 치기 (2026-09-25) ---
## 켜면 기본공격 자세가 부드럽게 흐르지 않고 **"멈칫 -> 휙 -> 버팀 -> 툭"** 으로 끊긴다.
## 예비동작 자세에 빨리 도달해 잠깐 멈추고, 후려치기는 짧게 끝내 뻗은 자세로 버티다가, 마지막에 확 제자리로 돌아온다.
## 판정 시각(40% 지점)은 그대로라 콤보 타이밍은 안 바뀐다. 기본 꺼짐(다른 캐릭터 영향 없음)
@export var attack_snap: bool = false
## 예비동작 구간(0~40%) 중 이 비율 안에 감기 자세가 완성되고, 나머지는 그 자세로 멈춰 있다
@export_range(0.1, 1.0, 0.05) var snap_windup_reach: float = 0.55
## 후려치기 구간(40~62%) 중 이 비율 안에 다 뻗는다 — 작을수록 빠르게 튀어나간다
@export_range(0.1, 1.0, 0.05) var snap_strike_reach: float = 0.45
## 복귀 구간(62~100%) 중 이 비율 동안은 뻗은 자세로 버티고, 남은 시간에 확 돌아온다
@export_range(0.0, 0.95, 0.05) var snap_recovery_hold: float = 0.6

## --- 대치 자세 (2026-09-25) ---
## 켜면 평소에 두 손을 가슴 앞으로 조금 내밀고 있는다(격투게임 대기 자세). 걷기·공격 자세 위에 **더해지므로**
## 공격도 이 자세에서 출발해 이 자세로 돌아온다. 손을 따로 쓰는 동작(마시기·총·잡기·던지기·방어·돌진·자전거·클래시·머리 긁기) 중엔 풀린다.
## 기본 꺼짐(다른 캐릭터 영향 없음)
@export var fight_stance: bool = false
## 제자리에서 더 옮기는 거리(px, +x가 바라보는 쪽, -y가 위)
@export var stance_hand_r_offset: Vector2 = Vector2(5, -9)
@export var stance_hand_l_offset: Vector2 = Vector2(36, -6)
## 더 돌리는 각도(도). 음수면 손에 든 물건이 위로 선다
@export var stance_hand_r_deg: float = -10.0
@export var stance_hand_l_deg: float = 15.0
## 자세가 켜지고 풀리는 속도(1/초)
@export var stance_blend_speed: float = 8.0

## --- 착지 경직 자세 (2026-09-25) ---
## 높은 데서 떨어져 착지 경직이 걸렸을 때(`Fighter.landing_lag_*`) 쪼그려 굳은 자세.
## 다리 파츠가 없어서 **발은 제자리에 두고 몸통·머리·손만 발 쪽으로 내려** 몸과 다리가 가까워지게 한다
## (처음엔 두 발을 벌려 비틀었는데 "다리 각도가 이상하다"고 해서 뺐다 — 2026-09-25 사용자 요청)
## 몸이 내려가는 깊이(px)
@export var land_crouch_depth: float = 7.0
## 고개를 아래로 숙이는 각도(도) — 방어·피격 움찔과 같은 방향(양수 = 숙임)
@export var land_crouch_head_deg: float = 10.0
## 착지 경직 동안 몸 전체가 눌리는 정도(x 넓적, y 납작) — 주저앉는 박자에 맞춰 눌렸다가 일어설 때 펴진다(2026-09-26 사용자 요청).
## 착지 순간의 짧은 스쿼시(land_squash)보다 약하지만 경직 내내 유지돼서 "쿵 주저앉았다"로 보인다
@export var land_lag_squash: Vector2 = Vector2(1.15, 0.86)

## --- 피격 움찔 자세 (2026-09-25) ---
## 맞은 순간 배를 맞은 것처럼 **상체를 앞으로 숙이고(ㄱ자) 엉덩이는 뒤로 빼고 두 손은 앞으로 모은다.**
## 모든 오프셋은 바라보는 쪽 기준(+x가 앞)이다. 조각의 로컬 좌표라 좌우 반전은 저절로 맞는다
## 전체 시간(초) — 앞 15%에 확 숙이고, 40%까지 버티다가, 나머지 동안 펴진다
@export var hit_flinch_duration: float = 0.32
## 몸통이 앞으로 숙는 각도(도) — 몸통 한가운데를 축으로 돌아서 위는 앞으로, 아래(엉덩이)는 뒤로 간다
@export var hit_flinch_lean_deg: float = 16.0
## 몸통을 뒤로 더 빼는 거리(px) — 엉덩이가 뒤로 빠진 느낌을 키운다
@export var hit_flinch_hip_back: float = 4.0
## 머리가 숙여진 상체를 따라 앞·아래로 가는 거리(px)와 숙이는 각도(도)
@export var hit_flinch_head_offset: Vector2 = Vector2(5, 4)
@export var hit_flinch_head_deg: float = 12.0
## 두 손이 앞으로 모이는 거리(px). 왼손은 몸 뒤에 있어서 더 많이 나온다
@export var hit_flinch_hand_r_offset: Vector2 = Vector2(8, 4)
@export var hit_flinch_hand_l_offset: Vector2 = Vector2(24, 3)
## 맞는 순간 몸 전체(발 포함)가 잠깐 떠오르는 높이(px). **그림만 뜨고 실제 위치·판정은 그대로**라
## 콤보(1·2타 팝업 0으로 지상에 붙잡아 두는 것)가 깨지지 않는다. 움찔 시간의 앞 30%에 올라가 60%에 내려앉는다
@export var hit_flinch_hop: float = 10.0
## 맞는 순간 몸 전체(발 포함)가 넉백 쪽으로 휙 밀렸다 돌아오는 거리(px). **그림만 밀리고 실제 위치·판정은 그대로**라
## 콤보 간격이 안 바뀐다(2026-09-25 사용자 요청 "뒤로 밀려나는 느낌")
@export var hit_flinch_push: float = 8.0
## 움찔할 때 두 발이 꺾이는 각도(도) — 양수면 발끝이 아래로 떨어진다(공중 자세와 같은 방향)
@export var hit_flinch_foot_deg: float = 25.0
## 엉덩이를 따라 두 발이 뒤로 빠지는 거리(px)
@export var hit_flinch_foot_back: float = 3.0

## --- 뒤돌아보기 때 머리 돌리기 (2026-09-25) ---
## 가만히 있다 나오는 뒤돌아보기(idle)에서 머리가 옆 -> 측면1 -> 측면2 -> 정면 -> 측면2 -> 측면1 -> 반대쪽 옆으로 돌았다가
## 같은 길로 돌아온다. 비워 두면(기본) 예전처럼 머리 가로 크기를 뒤집어 돌아본다.
## 평소 얼굴(Head의 처음 그림)일 때만 쓴다 — 다른 표정은 옆모습 그림뿐이라서.
## (처음엔 방향을 바꿀 때 돌게 만들었다가 사용자 요청으로 뒤돌아보기로 옮겼다 — 방향 전환은 예전처럼 탁 뒤집힌다)
## 돌아가는 그림들 — 옆에서 조금 돈 것부터 차례로, **마지막 장이 정면**이다(예: [측면1, 측면2, 측면3, 정면]).
## 장수는 몇 장이든 된다 — 뒤돌아보기가 장수에 맞춰 단계를 나눈다
@export var head_turn_textures: Array[Texture2D] = []
## 그림마다 머리 공(두개골)의 (중심 x, 중심 y, 지름) — 그림 픽셀. 프로펠러·챙·코·혀를 뺀 둥근 머리만 잰 값이다.
## **0번은 Head의 원래 옆모습**, 1번부터 head_turn_textures 순서다(그림 수 + 1칸). 머리 공 중심이 같은 자리, 지름이 같은 크기가 되도록
## 배율·위치를 계산한다. 그림을 바꾸면 다시 잴 것(처음엔 구슬 x·턱 끝 y로 맞췄는데 각도마다 중심이 흔들렸다)
@export var head_turn_anchors: Array[Vector3] = []
## 그림이 원래 **왼쪽**을 보고 그려졌는지(0번 포함, 그림 수 + 1칸). 왼쪽을 보는 그림은 좌우로 뒤집어 쓴다
@export var head_turn_faces_left: Array[bool] = []
## 액션 표정(action_head_texture)일 때 대신 쓸 머리 돌리기 그림·머리 공·방향 — 위 세 개와 같은 모양이고 **0번은 action_head_texture**다.
## 비워 두면 액션 표정 중엔 머리를 안 돌린다(예전과 같음). 악플러 열등감(분노 얼굴), 2026-10-02
@export var action_head_turn_textures: Array[Texture2D] = []
@export var action_head_turn_anchors: Array[Vector3] = []
@export var action_head_turn_faces_left: Array[bool] = []
## 머리가 도는 **도중에만** 몸통에 끼울 그림들 — 평소와 머리가 정면일 때는 Body 원래 그림(정면 몸통) 그대로고,
## 그 사이 단계(머리 측면1~측면3)에 이 그림들을 순서대로 나눠 끼운다(예: [3/4, 거의 정면]). 2026-09-26 금쪽이, 사용자 결정.
## 그림은 전부 **오른쪽을 보고** 그리고 Body 원래 그림과 같은 캔버스여야 한다(배율은 그대로 쓰고 바닥 가운데만 맞춘다)
@export var body_turn_textures: Array[Texture2D] = []
## **마지막 단계(머리가 정면일 때)까지 몸통 그림을 쓸지.** 꺼 두면(기본) 머리가 정면인 순간에는
## 원래 몸통 그림으로 돌아간다 — 평소 몸통이 **정면**인 캐릭터(금쪽이·악플러)용이다.
## 층간소음 빌런처럼 평소 몸통이 **측면**이면 켠다. 그러면 단계마다 body_turn_textures를 차례로 쓴다
@export var body_turn_full: bool = false
## 켜면 몸통 그림마다 불투명 영역 **높이**를 원래 몸통과 같게 배율을 맞춘다 — 캔버스·그린 크기가 원래 몸통과 다른 그림용
## (악플러: 원래 344x270, 측면 그림 887x887에 크게 그려짐, 2026-09-28). 금쪽이처럼 같은 캔버스로 그렸으면 끈다
@export var body_turn_match_height: bool = false
## body_turn_textures 칸마다 그 그림이 **왼쪽을 보고** 그려졌는지(head_turn_faces_left와 같은 뜻). 켠 그림은 좌우를 뒤집어 쓴다.
## 비워 두거나 칸이 모자라면 오른쪽으로 친다(금쪽이·악플러). 주정뱅이 몸 측면 2가 왼쪽을 봐서 넣었다(2026-09-30)
@export var body_turn_faces_left: Array[bool] = []
## 방향을 바꿀 때도 머리가 위 그림들을 넘기며 돈다(2026-09-26 시험) — 몸은 예전처럼 바로 뒤집히고,
## 머리가 옛 방향 쪽 측면1 -> ... -> 정면 -> ... -> 새 방향 옆모습으로 따라 돌아온다. 끄면 머리도 몸과 같이 탁 뒤집힌다
@export var head_turn_on_face: bool = false
## 방향 전환 때 머리가 다 돌아오는 데 걸리는 시간(초). 짧을수록 휙, 길수록 그림 한 장 한 장이 보인다.
## 몸은 이 시간의 절반(머리가 정면에 온 순간)에 뒤집힌다 — 그 전까지는 옛 방향을 본 채 움직인다
@export var face_turn_duration: float = 0.22
## 몸이 뒤집히는 순간 손·발을 몸 가운데로 얼마나 모으는지(0 = 안 모음, 1 = 한가운데까지). 앞뒤로 서서히 모였다 벌어진다
@export_range(0.0, 1.0) var face_turn_limb_gather: float = 0.7

## --- 휘두르기 잔상 (2026-09-25) ---
## 켜면 후려치는 동안 오른손과 손에 든 물건이 지나간 자리에 옅은 잔상이 남는다(스미어).
## 잔상은 월드에 고정돼 그 자리에서 흐려진다. 기본 꺼짐
@export var attack_smear: bool = false
## 잔상이 사라지기까지 걸리는 시간(초)
@export var smear_life: float = 0.12
## 잔상 처음 투명도
@export_range(0.0, 1.0, 0.05) var smear_alpha: float = 0.45
## 프레임 사이에 끼워 넣는 잔상 수 — 휘두르기가 몇 프레임밖에 안 돼서, 안 채우면 뚝뚝 끊긴 도장처럼 보인다
@export var smear_fill: int = 2

## --- 평타 하얀 궤적 (2026-10-06) ---
## 평타 1·2·3타 때 무기 끝(맨손이면 치는 주먹, 발차기면 발)이 지나간 자리에 하얀 띠(combat/SwingTrail.gd)를 남긴다.
## ComboMeleeAttack이 휘두를 때 `play_swing_trail()`을 불러야 켜진다 — 스킬·카운터의 스윙엔 안 나온다
@export var swing_trail: bool = true

## --- 발차기 마무리 (촉법소년 3타) ---
## 몇 번째 타를 발로 찰지 (0=1타, 2=3타). **-1이면 안 찬다** — 기본값이 -1이라 다른 캐릭터는 영향이 없다.
## 켜면 그 타에서 손 스윙 대신 앞발이 뻗어나가고, 팔은 균형 잡는 동작만 한다
@export var attack_kick_hit: int = -1
## 차는 발(앞발)이 다 뻗었을 때 가 있는 자리 — 제자리 기준, +x가 바라보는 쪽
@export var kick_foot_offset: Vector2 = Vector2(30.0, -20.0)
## 다 뻗었을 때 발끝 각도(도). 음수면 발끝이 위로 들린다
@export var kick_foot_deg: float = -75.0
## 무릎을 접는 예비동작에서 발이 뒤로 당겨지는 양 (뻗는 거리에 대한 비율)
@export var kick_windup_ratio: float = 0.35
## 디디는 발(뒷발)이 버티느라 뒤로 밀리는 양
@export var kick_back_foot_offset: Vector2 = Vector2(-10.0, 2.0)
## 찰 때 몸이 뒤로 젖혀지는 각도(도). 음수가 뒤로 젖히는 쪽
@export var kick_lean_deg: float = -15.0
## 균형 잡느라 오른손이 뒤로 빠지는 양
@export var kick_hand_offset: Vector2 = Vector2(-16.0, -8.0)
## 발로 차는 타만 쓰는 전체 시간(초). 0 이하면 attack_duration을 그대로 쓴다.
## 뒤돌려차기처럼 몸이 도는 발차기는 준비 동작이 길어야 도는 게 눈에 보인다 — 차는 순간은 이 값의 40%(ATTACK_STRIKE_START)라
## **ComboMeleeAttack.finisher_windup을 이 값 x 0.4로 맞춰야** 발이 다 뻗은 순간에 판정이 나간다
@export var kick_duration: float = 0.0

## --- 한 바퀴 돌면서 치기 (어느 타든) ---
## 이 번째 타(0=1타)는 **몸 전체가 좌우로 한 번 뒤집혔다 돌아오는 동안** 친다 — 옆에서 보면 등을 한 번 보였다 앞으로 돌아오는 회전 공격.
## **-1이면 안 돈다**(기본값 — 다른 캐릭터 영향 없음). 발차기 타면 발이, 아니면 손(무기)이 회전 도중에 들어간다.
## 처음엔 발차기 전용(kick_spin_turn)이었는데 촉법소년 3타를 막대사탕으로 바꾸면서(2026-09-17) 어느 타에나 붙게 떼어냈다
@export var spin_hit_index: int = -1
## 도는 타의 전체 시간(초). 0 이하면 attack_duration. 짧으면 도는 게 안 보인다
@export var spin_duration: float = 0.0
## **한 바퀴를 다 도는 시점**(그 타 전체 시간 대비 비율). 이 뒤로는 제자리로 돌아온다
@export_range(0.2, 1.0, 0.01) var spin_end: float = 0.62
## 한 바퀴 중 **몇 % 돌았을 때 때리는지**. 1보다 작아야 "돌고 나서"가 아니라 "돌면서" 때린다.
## **판정 시각 = spin_duration x spin_end x 이 값** 이라 ComboMeleeAttack.finisher_windup을 여기에 맞출 것(0.55 x 0.62 x 0.72 = 0.25).
## 판정이 잡히는 데 1~2프레임 걸려서 0.85처럼 크게 주면 몸이 거의 다 돌아온 뒤에 맞아 "돌고 나서"로 보인다
@export_range(0.5, 1.0, 0.01) var spin_strike: float = 0.72
## 머리 돌리기 그림(head_turn_textures)이 있으면 몸을 얇게 누르는 대신 **방향 전환과 같은 방식**으로 돈다(2026-09-26):
## 앞 반 바퀴는 머리가 측면1 -> ... -> 정면 -> ... -> 반대쪽 옆으로 돌고 정면인 순간 몸이 뒤집힌다,
## 뒤 반 바퀴는 뒤통수 그림이 없어서 머리는 옆모습 그대로, spin_back_flip에서 몸이 다시 뒤집힌다. 뒤집힐 때마다 손·발이 가운데로 모인다.
## 끄거나 머리 그림이 없으면 예전처럼 몸 전체를 얇게 눌렀다 편다
@export var spin_uses_head_turn: bool = true
## 뒤 반 바퀴에서 몸이 다시 앞으로 뒤집히는 시점(한 바퀴 대비 비율). **spin_strike보다 작아야** 사탕을 휘두를 때 몸이 앞을 본다
@export_range(0.5, 1.0, 0.01) var spin_back_flip: float = 0.64
## 몸이 뒤집히는 순간 앞뒤로 손·발을 모으는 구간 폭(한 바퀴 대비 비율). spin_strike - spin_back_flip보다 작아야 휘두를 때 팔이 안 움츠러든다
@export_range(0.01, 0.25, 0.01) var spin_gather_width: float = 0.08
## 뒤통수 그림 — 있으면 뒤 반 바퀴에서 몸이 뒤집히는 순간(spin_back_flip) 앞뒤로 머리가 뒤통수를 보인다(옆 -> 뒤통수 -> 옆)
@export var head_back_texture: Texture2D
## 뒤통수 그림의 머리 공 (중심 x, 중심 y, 지름) — head_turn_anchors와 같은 방법으로 잰 그림 픽셀
@export var head_back_anchor: Vector3 = Vector3.ZERO
## 뒤통수를 보여주는 구간 반폭(한 바퀴 대비 비율) — spin_back_flip 앞뒤로 이만큼. **spin_back_flip + 이 값이 spin_strike보다 작아야** 때릴 때 얼굴(옆모습)이 보인다
@export_range(0.01, 0.2, 0.01) var spin_back_show: float = 0.07

## --- 파고들 때 내딛기 ---
## 콤보가 앞으로 파고드는 동안(ComboMeleeAttack.combo_lunge) 앞발이 먼저 나가고 뒷발이 따라붙는다.
## 발 모양만 바꾸는 연출이라 이동 거리와는 상관없다
@export var lunge_step_foot: float = 12.0
## 내딛는 발이 들리는 높이(px)
@export var lunge_step_lift: float = 5.0

## --- 드롭킥 (촉법소년 3타) ---
## 뛰어올라 몸을 눕히고 두 발을 모아 차는 자세. 스킬(`ComboMeleeAttack`)이 `play_dropkick()`으로 켜고,
## 실제로 땅에 닿은 순간 `dropkick_land()`로 알려주면 넘어졌다 일어난다.
## **몸을 눕히는 건 루트 rotation이 아니라 조각을 하나씩 돌려서 한다** — 루트 rotation은
## Fighter가 피격 기울기·구르기에 쓰고 있어서 같이 쓰면 서로 각도를 뺏어 덜덜 떨린다
## 공중에서 몸이 눕는 각도(도). 음수가 등을 뒤로 눕히는 쪽 (0이면 선 채로 찬다)
@export var dropkick_air_deg: float = -65.0
## 착지해서 넘어졌을 때 각도(도). 여기서부터 0도(선 자세)까지 일어난다
@export var dropkick_down_deg: float = -86.0
## 눕는 자세가 완성되기까지 걸리는 시간(초)
@export var dropkick_lay_time: float = 0.12
## 누운 동안 몸 전체가 아래로 내려가는 양 — 안 내리면 허리 높이에 붕 뜬 것처럼 보인다
@export var dropkick_shift: Vector2 = Vector2(0.0, 6.0)
## 넘어져 있는 동안 더 내려가는 양 (바닥에 누운 높이)
@export var dropkick_down_shift: Vector2 = Vector2(0.0, 16.0)
## 일어나기 전에 바닥에 누워 있는 구간 (일어나는 전체 시간 대비 비율)
@export var dropkick_down_hold: float = 0.3
## 앞발이 뻗어나가는 자리 (제자리 기준, +x가 바라보는 쪽)
@export var dropkick_foot_offset: Vector2 = Vector2(16.0, -8.0)
## 뒷발을 앞발 옆에 붙이는 보정 — 두 발을 모으는 값이라 앞발 오프셋에 더해진다
@export var dropkick_foot_gap: Vector2 = Vector2(18.0, -5.0)
## 모아 뻗은 두 발의 각도(도)
@export var dropkick_foot_deg: float = -8.0
## 두 손이 뒤로 빠지는 양
@export var dropkick_hand_offset: Vector2 = Vector2(-14.0, -4.0)
## 몸이 도는 중심 (리그 원점 기준 — 대략 허리)
@export var dropkick_pivot: Vector2 = Vector2(0.0, 4.0)

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

## --- 총 쏘기 (촉법소년 비비탄) : 주머니에서 총을 휙 꺼내 두 손을 모아 앞으로 겨눈다 ---
## (2026-09-29 사용자 요청 "주머니에서 바로 꺼내는 느낌") 꺼내는 시간 = 앞 gun_pocket_ratio 동안 빈손이 주머니로 내려가고,
## 나머지 동안 총을 쥔 채 총구가 아래를 보던 각도(gun_pocket_deg)에서 수평으로 돌며 조준 자리까지 뽑아 올린다
## 오른손이 총을 꺼내는 주머니 자리(허리 앞쪽, 리그 원점 기준)
@export var gun_pocket_offset: Vector2 = Vector2(9, 12)
## 꺼내는 시간 중 빈손이 주머니로 내려가는 앞부분 비율(이 동안 총은 안 보인다)
@export_range(0.0, 0.9, 0.05) var gun_pocket_ratio: float = 0.35
## 주머니에서 막 뽑을 때 총 각도(도, 양수 = 총구가 아래) — 올라오면서 0도(수평)로 돈다
@export var gun_pocket_deg: float = 95.0
## 뽑아 올릴 때 손이 위로 부푸는 정도(px) — 곧게 오지 않고 살짝 호를 그린다
@export var gun_pull_arc: float = 5.0
## 다 쏘고 다시 넣을 때(BBGunSkill.holster_time) 앞부분 비율 — 여기까지 총이 주머니로 들어가 사라지고, 나머지 동안 빈손이 제자리로 돌아온다
@export_range(0.05, 1.0, 0.05) var gun_holster_hide: float = 0.6
## 두 손을 모아 앞으로 겨누는 그립 위치(리그 원점 기준). x가 클수록 팔을 더 앞으로 뻗는다
@export var gun_aim_offset: Vector2 = Vector2(20, -6)
## 왼손이 오른손(그립)에서 떨어져 있는 거리 — 두 손을 살짝 어긋나게 모아 잡는다
@export var gun_hand_l_offset: Vector2 = Vector2(-4, 3)
## 총 스프라이트가 그립(손)보다 총구 쪽으로 나가 있는 거리
@export var gun_forward_offset: Vector2 = Vector2(10, 0)
## 꺼내는 시간을 따로 안 넘겨받았을 때(컷인 등) 전체 동작 중 "주머니에서 꺼내 조준까지" 구간 비율. 나머지는 겨눈 채 유지한다
@export var gun_draw_ratio: float = 0.2
## 발사 반동으로 총·손이 뒤로 밀리는 거리(px)
@export var gun_recoil_kick: float = 6.0
## 반동이 원래대로 돌아오는 속도(클수록 빨리 회복)
@export var gun_recoil_recover: float = 9.0
## 총을 겨누는 동안 손에 든 물건(촉법소년 막대사탕 등)을 숨긴다 —
## 같은 오른손으로 총을 잡기 때문에 그대로 두면 총과 겹친다. 기본은 꺼짐(다른 캐릭터 영향 없음)
@export var gun_hides_held_item: bool = false

## --- 짜장면 먹기 (황근출 해병 스킬2, 2026-10-01) : 주머니에서 그릇을 꺼내 왼손에 받치고, 오른손으로 떠서 입에 넣는다 ---
## 그릇 그림은 리그의 `EatBowl` 자식(Sprite2D, 평소 숨김). 없으면 동작 자체를 안 한다.
## 순서: ① 빈손이 주머니로 ② 그릇을 꺼내 가슴 앞으로 ③ 왼손이 받치고 오른손이 그릇 <-> 입을 eat_bites번 ④ 다시 주머니로
## 오른손이 그릇을 꺼내는 주머니 자리(리그 원점 기준)
@export var eat_pocket_offset: Vector2 = Vector2(10, 12)
## 전체 중 앞부분 비율 — 주머니에 손 넣기 + 그릇 꺼내기
@export_range(0.05, 0.6, 0.05) var eat_pull_ratio: float = 0.25
## 전체 중 끝부분 비율 — 그릇을 다시 주머니에 넣기
@export_range(0.05, 0.6, 0.05) var eat_put_ratio: float = 0.2
## 먹는 동안 그릇 가운데 자리(리그 원점 기준, 앞 = +x)
@export var eat_bowl_offset: Vector2 = Vector2(15, 2)
## 그릇을 받치는 왼손 자리(그릇 가운데 기준)
@export var eat_hand_l_offset: Vector2 = Vector2(-2, 7)
## 오른손이 떠 올리는 입 자리(리그 원점 기준)
@export var eat_mouth_offset: Vector2 = Vector2(12, -20)
## 먹는 구간 동안 입에 넣는 횟수
@export var eat_bites: float = 3.0
## 먹는 동안 고개를 숙이는 각도(도, 양수 = 앞으로 숙임)와 한 입마다 끄덕이는 폭(px)
@export var eat_head_tilt_deg: float = 8.0
@export var eat_head_bob: float = 2.0

## --- 백 서플렉스(주인공 스킬2): 손을 뻗어 잡고, 들어올려 버티다가, 등 뒤로 넘겨 꽂는다 ---
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

## --- 머리 잡아 패대기(고양이 아주머니 고양이 옷 3타): 두 손을 앞으로 뻗어 머리를 잡고, 머리 위로 넘겨 등 뒤 바닥에 꽂는다 ---
## 두 손이 모이는 자리(리그 원점 기준, +x = 앞) — 뻗어 잡는 곳 / 머리 위를 지나는 곳 / 등 뒤 바닥 쪽으로 꽂는 곳
@export var head_grab_reach: Vector2 = Vector2(44, -30)
@export var head_throw_top: Vector2 = Vector2(-2, -80)
@export var head_throw_end: Vector2 = Vector2(-48, 10)
## 넘기는 동안 몸이 뒤로 젖혀지는 각도(도, 음수 = 뒤로)
@export var head_throw_lean_deg: float = -22.0
## 넘기는 동안 **고개만 더** 뒤로 젖히는 각도(도, 음수 = 뒤로) — 브리지하듯 목이 꺾인다. 몸 젖힘에 더해진다
@export var head_throw_head_deg: float = -40.0
## 고개를 꺾는 축(목, 리그 원점 기준) — 머리 그림 가운데가 아니라 여기를 중심으로 돈다
@export var head_throw_neck: Vector2 = Vector2(0, -12)
## 두 손이 위아래로 벌어지는 간격(px) — 머리를 위아래에서 감싸 쥔다
@export var head_grab_hand_gap: float = 16.0

## --- 유선 마우스 던지기 (악플러 스킬1): 마우스를 어깨 뒤로 젖혀 들었다가 앞으로 뿌린다 ---
## 젖혀 들었을 때 오른손 위치(리그 원점 기준) — 어깨 높이로 뒤로 당긴 자세.
## y를 -6보다 위로 올리면 손과 마우스가 머리(55px)에 파묻히니 주의
@export var cast_windup_offset: Vector2 = Vector2(-8, -2)
## 뿌리는 순간 오른손이 뻗는 위치 — 앞으로 크게 내민다
@export var cast_release_offset: Vector2 = Vector2(36, -6)
## 젖혔을 때 손목이 뒤로 꺾이는 각도(도)
@export var cast_windup_deg: float = -45.0
## 뿌릴 때 손목이 앞으로 넘어가는 각도(도)
@export var cast_release_deg: float = 50.0
## 뿌린 뒤 손이 제자리로 돌아오기 시작하는 지점(뿌리는 구간 중 앞 몇 %가 실제로 뻗는 동작인지)
@export var cast_snap_ratio: float = 0.4

## --- 돌 던지기 (주인공 스토리 스킬2): 야구 투구처럼 크게 던진다 ---
## 마우스 던지기(cast)와 **완전히 별개**다. 마우스 던지기는 오른손만 움직이는 짧은 동작이고,
## 이쪽은 몸통·머리·양손·두 발이 전부 움직이는 큰 동작이다.
##
## 동작은 네 자세를 이어 붙여 만든다 (러프 4컷 그대로):
##   ① 셋업   — 돌 든 오른손을 몸 뒤로, 왼손은 앞으로, 몸은 똑바로. **여기서 앞발을 한 발 내딛는다**
##   ② 젖힘   — 오른손을 뒤 위로 치켜들고 몸을 뒤로 젖힌다
##   ③ 뿌림   — 손이 머리 위를 넘어오며 몸이 앞으로 쏟아진다. **이 지점에서 돌이 손을 떠난다**
##   ④ 마무리 — 뻗은 손이 몸 앞으로 내려오고 왼손은 몸쪽으로 당겨진다
## 아래 ratio 넷이 각 자세가 오는 시점(전체 동작 중 몇 %)이다
@export var throw_setup_ratio: float = 0.20
@export var throw_windup_ratio: float = 0.48
@export var throw_release_ratio: float = 0.62
@export var throw_follow_ratio: float = 0.80
## 각 자세에서 오른손이 가는 위치(리그 원점 기준, +x가 앞)
@export var throw_setup_hand: Vector2 = Vector2(-18, 2)
@export var throw_windup_hand: Vector2 = Vector2(-24, -24)
@export var throw_release_hand: Vector2 = Vector2(12, -30)
@export var throw_follow_hand: Vector2 = Vector2(26, 8)
## 각 자세에서 손목이 꺾이는 각도(도)
@export var throw_setup_deg: float = -25.0
@export var throw_windup_deg: float = -75.0
@export var throw_release_deg: float = 35.0
@export var throw_follow_deg: float = 70.0
## 왼손 — 던지기 전엔 앞으로 내밀어 겨누고(반대쪽 균형), 던진 뒤엔 몸쪽으로 당겨진다.
## 둘 다 제자리 기준 상대값이다
@export var throw_hand_l_front: Vector2 = Vector2(16, -6)
@export var throw_hand_l_pull: Vector2 = Vector2(-10, 4)
## 몸통 기울기(도) — 음수가 뒤로 젖힘, 양수가 앞으로 쏟아짐
@export var throw_body_windup_deg: float = -18.0
@export var throw_body_release_deg: float = 34.0
## 머리가 몸통 기울기를 따라가는 정도(0~1)
@export var throw_head_follow: float = 0.65
## --- 몸 숙이기 ---
## 기울기(회전)만으로는 "숙였다"가 잘 안 읽힌다. 뿌리는 순간부터 허리를 굽히듯
## 몸통과 머리를 이만큼 아래로 내려앉히고, 머리는 앞으로도 조금 내민다 (px)
@export var throw_body_crouch: float = 17.0
@export var throw_head_dip: float = 14.0
@export var throw_head_lead: float = 11.0
## **이 동작의 핵심** — 앞발이 제자리보다 이만큼 앞으로 나가 디딘다(px).
## 한 번 디디면 throw_foot_hold_ratio까지 그 자리에 못박혀 움직이지 않는다
@export var throw_step_foot: float = 14.0
## 발을 옮기는 동안만 살짝 드는 높이(px). 다 디딘 뒤엔 바닥에 붙어 있는다
@export var throw_step_lift: float = 6.0
## 뒷발이 뒤로 밀리는 거리(px) — 버티는 발이라 조금만 움직인다
@export var throw_back_foot: float = -4.0
## 디딘 발이 제자리로 돌아가기 시작하는 시점(전체 동작 중 몇 %)
@export var throw_foot_hold_ratio: float = 0.9
## 던지는 동안 손에 원래 들고 있던 물건(주인공 경봉)을 숨긴다
@export var throw_hides_held_item: bool = true

## --- 유선 마우스 끌어당기기: 두 손으로 줄을 잡고 박자에 맞춰 몸쪽으로 당긴다 ---
## 줄을 잡은 오른손의 기준 위치(리그 원점 기준) — 앞으로 내밀어 줄을 쥔 자세
@export var reel_hand_offset: Vector2 = Vector2(24, -6)
## 왼손이 오른손에서 떨어져 잡는 거리 — 줄을 앞뒤로 나눠 잡은 것처럼 보이게
@export var reel_hand_l_offset: Vector2 = Vector2(-12, 6)
## 한 번 당길 때 두 손이 몸쪽으로 끌려오는 거리(px)
@export var reel_tug_offset: Vector2 = Vector2(14, 4)
## 당기는 박자(라디안/초) — 클수록 빠르게 여러 번 당긴다
@export var reel_tug_speed: float = 11.0
## 당기는 자세로 옮겨가고 풀리는 빠르기 (클수록 뚝뚝 끊긴다)
@export var reel_blend_speed: float = 12.0

## --- 방어 자세 (아래 키 보호막) — 두 손을 몸 앞으로 올려 막고 살짝 움츠린다 ---
## 방어할 때 오른손이 가는 자리(리그 원점 기준). 앞(+x)이 바라보는 쪽이다.
## **x를 머리 오른쪽 끝(25)보다 더 안쪽으로 넣지 말 것** — 촉법소년은 손이 z_index 1이라 얼굴을 덮어버리고,
## 나머지 캐릭터는 반대로 머리 뒤로 숨어버린다. "얼굴에 붙이고 싶으면 x가 아니라 y를 올릴 것"
@export var guard_hand_r_pos: Vector2 = Vector2(29, -34)
## 왼손 자리 — 오른손보다 낮고 안쪽을 막는다(권투 가드처럼 위아래로 어긋나게)
@export var guard_hand_l_pos: Vector2 = Vector2(25, -17)
## 막는 손이 돌아가는 각도(도). 왼손은 반대로 돌아가 서로 마주 보게 된다.
## 음수(반시계)라야 손에 든 물건이 몸 쪽으로 눕는다 — 악플러는 키보드가 얼굴 앞에 가로로 서서
## 그대로 방패가 되고, 양수로 주면 머리 위로 치솟아 우스워진다
@export var guard_hand_deg: float = -45.0
## 방어할 때 몸과 머리가 아래로 움츠러드는 거리(px)
@export var guard_crouch: float = 5.0
## 방어할 때 고개를 앞으로 숙이는 각도(도)
@export var guard_head_deg: float = 6.0
## 방어 자세가 켜지고 꺼지는 빠르기 (클수록 즉각적)
@export var guard_blend_speed: float = 16.0

## --- 카운터 자세 (지하철 아저씨 스킬2, 2026-09-30 사용자 레퍼런스 — 지하철에서 단소 든 아저씨) ---
## **두 손으로 단소를 얼굴 높이에 들고 앞 아래로 찌를 듯 겨눈다**(사용자 그림, 창·당구 큐 자세). 몸은 똑바로.
## 앞손(오른손, 단소가 매달린 손)은 턱 앞, 뒷손(왼손)은 단소 뒤끝을 잡는다 — 게임 단소가 짧아서(약 47px, 앞손 기준 뒤 8 ~ 앞 36px)
## 두 손 간격이 좁다(사용자 결정). 뒷손은 원래 머리 뒤에 그려지는데 그림처럼 머리 위로 보이게 자세 동안 z를 올린다(attack_grip_hand_z).
## 손 자리는 **숙이기 전** 기준(리그 원점, 앞이 +x) — 숙이는 회전은 그 뒤에 엉덩이를 축으로 몸·머리·손에 같이 건다
@export var counter_hand_r_pos: Vector2 = Vector2(-6, -18)
## 오른손 각도(도) — 단소가 제자리에서 앞 위(약 -46도)라 +67이면 앞 아래 약 21도를 겨눈다
@export var counter_hand_r_deg: float = 67.0
## 왼손(뒷손) 자리 — 단소 뒤끝(앞손 + (-8, -6) 근처)
@export var counter_hand_l_pos: Vector2 = Vector2(-15, -24)
@export var counter_hand_l_deg: float = 67.0
## 상체를 앞으로 숙이는 각도(도). 0이면 똑바로
@export var counter_lean_deg: float = 0.0
## 찌를 듯 들썩이기 — 단소 방향으로 두 손이 이만큼(px) 당겼다 내밀기를 반복한다. 0이면 멈춰 있음
@export var counter_poke_amount: float = 3.0
## 들썩이는 빠르기(라디안/초)
@export var counter_poke_speed: float = 11.0
## 들썩이는 방향 — 단소가 겨누는 쪽(앞 아래 21도)
@export var counter_poke_dir: Vector2 = Vector2(0.934, 0.358)
## 숙일 때 도는 축(엉덩이, 리그 원점 기준)
@export var counter_lean_pivot: Vector2 = Vector2(0, 16)
## 자세가 섞이는 빠르기(1/초)
@export var counter_blend_speed: float = 16.0

## --- 어깨 들이박기 자세 (일진 스킬2) ---
## 돌진할 때 두 손을 모으는 자리 (앞이 +x — 리그 전체가 좌우 반전되므로 방향 부호는 안 곱한다)
@export var charge_hand_r_pos: Vector2 = Vector2(31.0, 0.0)
@export var charge_hand_l_pos: Vector2 = Vector2(24.0, 7.0)
## 모은 손의 각도(도)
@export var charge_hand_deg: float = -25.0
## 몸·머리가 앞으로 기우는 각도(도)
@export var charge_lean_deg: float = 15.0
## 자세가 섞이는 빠르기(1/초)
@export var charge_blend_speed: float = 16.0
## --- 무릎 꿇기 (황근출 드롭킥 준비) ---
## 몸통·머리·손이 내려가는 양(px)
@export var kneel_depth: float = 6.0
## 상체가 앞으로 숙이는 각도(도, 양수 = 앞)
@export var kneel_lean_deg: float = 14.0
## 상체를 숙이는 축(리그 기준, 엉덩이 근처)
@export var kneel_pivot: Vector2 = Vector2(0, 22)
## 앞발(오른발)이 가는 자리(쉬는 자리 기준)와 각도 — 무릎을 세운 다리
@export var kneel_front_foot: Vector2 = Vector2(14.0, 0.0)
@export var kneel_front_foot_deg: float = 0.0
## 뒷발(왼발)이 가는 자리와 각도 — 무릎을 땅에 댄 다리(뒤로 빼고 눕힌다)
@export var kneel_back_foot: Vector2 = Vector2(-12.0, 0.0)
@export var kneel_back_foot_deg: float = 12.0
## 두 손이 가는 자리(쉬는 자리 기준, 내려가는 양은 따로 더한다) — 무릎 위로 내린다
@export var kneel_hand_offset: Vector2 = Vector2(4.0, 6.0)
## 자세가 섞이는 빠르기(1/초)
@export var kneel_blend_speed: float = 12.0
## --- 망치질 (고양이 아주머니 스킬1 집 짓기 — 무릎 꿇기 위에 얹는다) ---
## 한 번 내리치는 데 걸리는 시간(초). 켠 순간부터 이 간격마다 망치가 땅에 닿는다(스킬이 같은 값으로 먼지를 낸다)
@export var hammer_period: float = 0.4
## 망치를 치켜든 오른손 자리(쉬는 자리 기준)와 각도
@export var hammer_raise_offset: Vector2 = Vector2(-6.0, -16.0)
@export var hammer_raise_deg: float = -60.0
## 내리친 오른손 자리와 각도 — 망치 머리가 앞쪽 땅에 닿는다
@export var hammer_strike_offset: Vector2 = Vector2(8.0, 12.0)
@export var hammer_strike_deg: float = 75.0
## 한 박자 중 치켜드는 데 쓰는 비율 — 나머지 동안 빠르게 내리친다
@export var hammer_raise_ratio: float = 0.65
## --- 두 손 번쩍 들기 / 다리 내려찍기 (황근출 내무반 스킬2 `BarracksSlamSkill`) ---
## 두 손이 가는 자리(리그 로컬, +x = 바라보는 쪽)와 각도 — 머리 위로 번쩍
@export var lift_hand_r_pos: Vector2 = Vector2(18.0, -52.0)
@export var lift_hand_l_pos: Vector2 = Vector2(4.0, -55.0)
@export var lift_hand_deg: float = -70.0
## 들어 올리며 상체를 뒤로 젖히는 각도(도, 양수 = 뒤로)
@export var lift_lean_deg: float = 8.0
## 내려찍는 다리(오른발)가 가는 자리와 각도 — 발바닥을 아래로 쭉 뻗는다
@export var stomp_foot_pos: Vector2 = Vector2(8.0, 44.0)
@export var stomp_foot_deg: float = 0.0
## 접는 다리(왼발)가 가는 자리와 각도
@export var stomp_tuck_pos: Vector2 = Vector2(-14.0, 16.0)
@export var stomp_tuck_deg: float = -25.0
## 균형 잡는 두 손 자리
@export var stomp_hand_r_pos: Vector2 = Vector2(28.0, -28.0)
@export var stomp_hand_l_pos: Vector2 = Vector2(-28.0, -30.0)
## 두 자세가 섞이는 빠르기(1/초)
@export var slam_blend_speed: float = 20.0
## 줄을 잡은 두 손이 돌아가는 각도(도)
@export var reel_hand_deg: float = -22.0
## 마우스를 던지고 줄을 당기는 동안 손에 든 물건(악플러 키보드 등)을 숨긴다 —
## 같은 오른손으로 던지기 때문에 그대로 두면 키보드와 마우스가 겹친다. 기본은 꺼짐(다른 캐릭터 영향 없음)
@export var cast_hides_held_item: bool = false

## 토하기 스킬을 쓸 때 잠깐 이 얼굴(토하는 표정)로 머리를 바꾼다. 비어 있으면 아무 일도 안 한다(주정뱅이만 지정)
@export var vomit_head_texture: Texture2D
## 토하는 얼굴을 보여주는 시간(초)
@export var vomit_face_duration: float = 0.6
## 토하는 얼굴일 때 머리 배율. (0,0)이면 원래 머리 배율을 그대로 쓴다(원본 크기가 달라 안 맞을 때만 조정)
@export var vomit_head_scale: Vector2 = Vector2.ZERO
## 토하는 얼굴일 때 머리 위치 보정(px) — 입이 게워내는 위치에 안 맞으면 조정
@export var vomit_head_offset: Vector2 = Vector2.ZERO

## 맞았을 때 잠깐 이 얼굴(아파하는 표정)로 머리를 바꾼다. 비어 있으면 아무 일도 안 한다(촉법소년만 지정)
@export var hurt_head_texture: Texture2D
## 아파하는 얼굴을 보여주는 시간(초)
## --- 방어에 막혔을 때 때린 손·무기가 빨갛게 깜빡이는 연출 ---
## 깜빡임 길이(초) — **평소엔 안 쓰인다.** 실제 길이는 Fighter가 기본공격 잠금 시간
## (Fighter.blocked_attack_lock)을 넘겨주므로, 시간을 바꾸려면 그쪽을 고칠 것.
## 이 값은 Fighter 없이 몸만 띄웠을 때(미리보기 도구)의 예비값이다
@export var blocked_flash_duration: float = 3.0
## 깜빡일 때 가장 진해지는 색. modulate라 원래 그림 색에 곱해진다
@export var blocked_flash_color: Color = Color(1.0, 0.2, 0.2)
## 그 시간 동안 원래색 <-> 빨강을 몇 번 왕복하는지
@export var blocked_flash_cycles: float = 6.0
## 가장 옅어졌을 때의 투명도 (1이면 투명도는 안 변하고 색만 바뀐다)
@export_range(0.0, 1.0, 0.05) var blocked_flash_min_alpha: float = 0.3
## 기본공격이 잠긴 동안 **몸 전체**에 두르는 빨간 테두리 색 (2026-09-14 추가 — 손만 빨개지니 잘 안 보였다).
## 손·무기만 깜빡이던 예전 연출은 그대로 있고 그 위에 테두리가 더해진다
@export var blocked_outline_color: Color = Color(1.0, 0.12, 0.12)
## 테두리 두께 — **화면 픽셀 기준**이다. 파츠마다 배율이 달라서(머리 0.048 / 손 0.11 / 몸 0.035)
## 코드가 각 파츠의 배율로 나눠 셰이더에 넣는다. 0으로 두면 테두리 없이 예전 연출만 나간다
@export var blocked_outline_px: float = 3.0
## 깜빡임이 가장 옅을 때의 테두리 진하기. 0이면 완전히 사라졌다 나타나서 "잠겨 있다"가 끊겨 보인다
@export_range(0.0, 1.0, 0.05) var blocked_outline_min: float = 0.45

@export var hurt_face_duration: float = 0.45
## 아파하는 얼굴일 때 머리 배율. (0,0)이면 원래 머리 배율을 그대로 쓴다
@export var hurt_head_scale: Vector2 = Vector2.ZERO
## 아파하는 얼굴일 때 머리 위치 보정(px) — 원본 여백이 달라 얼굴이 어긋날 때만 조정
@export var hurt_head_offset: Vector2 = Vector2.ZERO

## 술 스택이 남아있는 동안(몸이 빨간 동안) 머리를 이 얼굴(술 머금은 표정)로 유지한다. 비어 있으면 안 바꾼다
@export var drunk_head_texture: Texture2D
## 술 머금은 얼굴일 때 머리 배율. (0,0)이면 원래 머리 배율을 그대로 쓴다
@export var drunk_head_scale: Vector2 = Vector2.ZERO

## 스킬(자전거 돌진·총 쏘기)을 쓰는 동안 이 표정으로 머리를 바꾼다. 비어 있으면 안 바꾼다(촉법소년만 지정)
@export var action_head_texture: Texture2D
## 액션 표정일 때 머리 배율. (0,0)이면 원래 머리 배율을 그대로 쓴다
@export var action_head_scale: Vector2 = Vector2.ZERO

## 처치당했을 때(HP 0) 바뀌는 표정 — 눈이 X로 변한 얼굴. 비워두면 표정이 안 바뀐다.
## 처치 연출(`Stage`가 부르는 `play_knockout`)에서만 쓴다
@export var ko_head_texture: Texture2D
## 그 그림의 배율 (0,0이면 원래 머리 배율 그대로)
@export var ko_head_scale: Vector2 = Vector2.ZERO
## 처치 연출에서 파츠가 흩어지는 정도 — 사진 포즈처럼 머리는 위로, 손·발은 뒤로 처진다.
## 리그 전체가 회전하며 날아가므로 이 값은 로컬 좌표 기준이다
@export var ko_head_offset: Vector2 = Vector2(0, -6)
@export var ko_hand_offset: Vector2 = Vector2(-10, 8)
@export var ko_foot_offset: Vector2 = Vector2(-12, 6)

@onready var _foot_l: Sprite2D = get_node_or_null("FootL")
@onready var _foot_r: Sprite2D = get_node_or_null("FootR")
@onready var _body: Sprite2D = get_node_or_null("Body")
@onready var _head: Sprite2D = get_node_or_null("Head")
@onready var _hand_l: Sprite2D = get_node_or_null("HandL")
@onready var _hand_r: Sprite2D = get_node_or_null("HandR")
## 오른손이 든 물건(소주병 등)을 매다는 빈 노드 — 손의 위치·회전을 그대로 따라간다
@onready var _hand_r_hold: Node2D = get_node_or_null("HandRHold")
## 왼손에 드는 물건걸이 — 오른손 것과 같은 방식으로 왼손을 따라간다(지하철 아저씨 검은 리코더).
## 평소에는 비어 있고, `held_item_l_armed`가 켜질 때만 자식 그림이 보인다
@onready var _hand_l_hold: Node2D = get_node_or_null("HandLHold")
## 한쪽 팔로 안고 있는 것(층간소음 빌런의 아이). 없는 리그면 null이라 그냥 넘어간다
@onready var _carry: Node2D = get_node_or_null("Carry")
## 자전거 노드(있으면 촉법소년) — 돌진 중에만 보인다
@onready var _bike: Sprite2D = get_node_or_null("Bike")
## 총 노드(있으면 촉법소년) — 총 쏘는 스킬 중에만 보인다
@onready var _gun: Sprite2D = get_node_or_null("Gun")
@onready var _eat_bowl: Sprite2D = get_node_or_null("EatBowl")

@export_group("헬스장 스펙")
## **팔(손) 그림이 커지는 배율** — 헬스장 바벨 컬로 쌓은 스펙이 올려 준다(`WorkoutSkill`).
## 1이면 평소 크기라 다른 맵에선 아무 일도 안 일어난다
@export var muscle_arm: float = 1.0
## **다리(발) 그림이 커지는 배율** — 스쿼트·런닝머신이 올려 준다
@export var muscle_leg: float = 1.0

var _fighter: Fighter
## 손·발의 원래 크기 — 부풀렸다 되돌릴 기준점(`_ready`에서 기억한다)
var _hand_rest_scale: Vector2 = Vector2.ONE
var _foot_rest_scale: Vector2 = Vector2.ONE
## 지금 화면에 반영해 둔 배율 — 바뀔 때만 다시 쓰려고 들고 있는다
var _muscle_arm_shown: float = 1.0
var _muscle_leg_shown: float = 1.0
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
# 스쿼시 중 발바닥을 제자리에 두려고 리그 y에 더해 둔 값
var _squash_lift: float = 0.0
## 직전 프레임에 바닥에 있었는지 (착지 순간 감지용)
var _was_on_floor: bool = true
## 자전거를 탄(보이는) 정도 0~1. set_riding으로 목표를 정하고 서서히 오간다
var _ride_blend: float = 0.0
var _ride_target: float = 0.0
## 대치 자세로 들어간 정도 0~1. set_clash로 목표를 정하고 서서히 오간다
var _clash_blend: float = 0.0
var _clash_target: float = 0.0
## 밀당 상황 -1(완전히 밀림) ~ +1(완전히 밀어붙임). SkillClashPopup이 매 프레임 넣어준다
var _clash_push: float = 0.0
## 맞댄 손이 앞뒤로 밀고 밀리는 양(px). **화면(월드) 기준 가로 오프셋**이라 왼쪽을 보는 캐릭터는
## 안에서 부호를 뒤집어 쓴다 — 두 캐릭터가 같은 값을 받아야 손이 같은 방향으로 함께 움직인다
var _clash_shove: float = 0.0
## --- 주먹 러시 상태 ---
## 앞으로 나갈 주먹 수 (연타가 쌓아준다)
var _punch_queue: int = 0
## 지금 주먹의 진행 0(거둠)~1(다시 거둠). 음수면 쉬는 중
var _punch_t: float = -1.0
## 이번 주먹이 오른손인지 — 매번 번갈아 나간다
var _punch_right: bool = false
## 이번 주먹의 높이 흩어짐
var _punch_y: float = 0.0
## 이번 주먹의 잔상을 이미 남겼는지 (한 주먹에 하나만)
var _punch_ghosted: bool = false
## 주먹 잔상 — 처음 쓸 때 만들어두고 계속 재활용한다. owner를 안 줘서 씬에 저장되지 않는다
var _ghosts: Array[Sprite2D] = []
var _ghost_life: Array[float] = []
## 기본공격 잔상 칸(클래시 주먹 잔상과 따로 쓴다) — 처음 쓸 때 만든다
var _smears: Array[Sprite2D] = []
var _smear_left: Array[float] = []
## 잔상 원본별 직전 프레임 자세(리그 기준 변환) — 프레임 사이를 채울 때 쓴다
var _smear_prev: Dictionary = {}
## 평타 하얀 궤적 — 지금 긋는 띠(맵에 붙어 있음), 그 띠를 켠 스윙 번호, 따라가는 조각과 그 조각 안의 끝점
var _swing_trail_node = null
## play_attack_swing이 불릴 때마다 1씩 는다 — 다음 타가 나가면 앞 타의 띠를 끊는다
var _swing_serial: int = 0
## 띠를 켠 스윙 번호(-1 = 꺼짐)
var _trail_serial: int = -1
var _trail_src: Node2D = null
var _trail_tip := Vector2.ZERO
## 직전 프레임 조각 자세(리그 기준) — 프레임 사이를 채운다(_smear_prev와 같은 이유)
var _trail_prev := Transform2D()
var _trail_has_prev: bool = false
## 끊어 치기가 출발하는 손 자세 — 앞 타가 끝나기 전에 다음 타가 나가도 손이 제자리로 툭 튀지 않게
var _swing_from_off := Vector2.ZERO
var _swing_from_deg: float = 0.0
## 맨손 잽 가드 블렌드(손마다 0 = 원래 자세, 1 = 가드 자세)
var _jab_guard_l: float = 0.0
var _jab_guard_r: float = 0.0
## 대치 자세가 얼마나 들어가 있는지(0~1)
var _stance_blend: float = 0.0
## 착지 경직 자세 남은 시간 / 전체 시간(초)
var _crouch_time: float = 0.0
var _crouch_len: float = 0.0
## 피격 움찔 남은 시간 / 전체 시간(초) / 세기(0~1)
var _flinch_time: float = 0.0
var _flinch_len: float = 0.0
var _flinch_power: float = 1.0
## 이번 움찔에서 밀리는 방향 — 리그 로컬 x 부호(-1 = 바라보는 반대쪽 = 뒤)
var _flinch_push_dir: float = -1.0
## 뒤돌아보기 중 머리 그림을 돌리는 그림으로 바꿔 끼웠는지 — 끝날 때 평소 머리로 되돌려야 하는지 판단한다
var _turn_applied: bool = false
# 방향 전환 머리 돌리기 남은 시간, 직전 프레임에 바라보던 방향 부호(0 = 아직 모름), 돌기 전 방향 부호
var _face_turn_time: float = 0.0
var _face_sign: float = 0.0
var _face_turn_from: float = 0.0
## 클래시 동안 손에 든 물건(소주병·키보드 등)을 숨겼는지 — 끝나면 다시 보여주려고 기억한다
var _hold_hidden_by_clash: bool = false
## 페달 회전 각도 (계속 커짐)
var _pedal_phase: float = 0.0
## 자전거의 "탄 위치"(씬에 저장된 제자리) — 여기서 뒤로 밀어 슬라이드 연출한다
var _bike_mounted_pos: Vector2
## 조작 없이 가만히 있은 시간(초). idle_motion_delay를 넘으면 idle 모션이 하나 시작된다
var _idle_time: float = 0.0
## 머리 긁는 동작에 남은 시간(초). 0보다 크면 긁는 중이다
var _scratch_time: float = 0.0
# 특수 idle 몸짓(안경 올리기·딸꾹질) 남은 시간, 이번에 띄운 딸꾹 수, 왼손 원래 그리는 순서
var _special_time: float = 0.0
var _hiccups_fired: int = 0
var _hand_l_rest_z: int = 0
## 오른손의 원래 z_index — 선풍기 회전 중 두 손을 키보드 앞으로 올렸다가 끝나면 되돌린다
var _hand_r_rest_z: int = 0
var _hand_r_hold_rest_z: int = 0
var _hand_l_hold_rest_z: int = 0
## 뒤돌아보는 동작에 남은 시간(초). 0보다 크면 돌아보는 중이다
var _lookback_time: float = 0.0
## 기본공격 스윙에 남은 시간(초). 0보다 크면 휘두르는 중이다
var _attack_time: float = 0.0
## 지금 재생 중인 스윙 종류 (콤보 평타의 타 번호). 0=기본 내려찍기, 1=앞으로 후려치기, 2=크게 올려치기
var _attack_variant: int = 0
## 이번 프레임에 **평타 포즈 씬**이 자세를 잡았는지. true면 발차기·무기 돌리기 같은 기본 동작을 건너뛴다
var _attack_pose_on: bool = false
## 지금 스윙의 전체 길이(초) — 발차기 타는 kick_duration, 나머지는 attack_duration
var _attack_len: float = 0.4
## 뒤돌기 전에 루트 scale.x가 얼마였는지 — 다음 프레임 시작에 되돌려야 _face_moving_direction이
## 얇아진 크기를 원래 크기로 착각하지 않는다
var _spin_base_x: float = 0.0
var _spin_applied: bool = false
## 지금 휘두르는 타가 한 바퀴 도는 타인지 (play_attack_swing이 정한다)
var _spin_now: bool = false
## 파고들며 내딛는 발동작의 남은 시간 / 전체 시간
var _step_time: float = 0.0
var _step_len: float = 0.0
## 발 먼저 나가는 앞부분 비율 (0이면 옛 내딛기 모양)
var _step_lead: float = 0.0
## 술 마시기 동작에 남은 시간(초). 0보다 크면 마시는 중이다
var _drink_time: float = 0.0
## 총 조준 동작에 남은 시간(초). 0보다 크면 총을 겨누는 중이다
var _gun_time: float = 0.0
## 총 조준 동작 전체 길이(스킬이 넘겨준다) — 진행도 계산용
var _gun_duration: float = 0.5
## 그중 주머니에서 꺼내 조준까지 걸리는 시간(초)
var _gun_draw_time: float = 0.1
## 그중 맨 끝에서 총을 다시 주머니에 넣는 시간(초). 0이면 넣는 동작 없이 사라진다(컷인)
var _gun_holster_time: float = 0.0
## 총 스프라이트 원래 배율 — 꺼낼 때 살짝 작게 시작했다 돌아오므로 기억해 둔다(처음 꺼낼 때 잰다)
var _gun_rest_scale: Vector2 = Vector2.ZERO
## 발사 반동 세기 0~1 — 쏠 때마다 1로 튀었다가 서서히 0으로 줄어든다
var _recoil: float = 0.0
## 짜장면 먹기 동작에 남은 시간·전체 길이(초). 0보다 크면 먹는 중이다
var _eat_time: float = 0.0
var _eat_duration: float = 1.0
## 그릇 그림 원래 배율 — 꺼내고 넣을 때 작아졌다 커진다
var _eat_bowl_rest_scale: Vector2 = Vector2.ONE
## 파일드라이버 동작에 남은 시간(초). 0보다 크면 잡기~내리꽂기 동작 중이다
var _grab_time: float = 0.0
var _grab_duration: float = 1.0
## 전체 동작 중 "뻗어서 잡기"가 끝나는 지점, "들고 버티기"가 끝나는 지점(그 뒤는 내리꽂기)의 진행도 비율
var _grab_reach_ratio: float = 0.2
var _grab_slam_ratio: float = 0.8
## 잡기 동작 종류 — `_grab_time`을 같이 써서 방향 전환 막기 등 조건이 그대로 따라온다
enum GrabMode { SUPLEX, HEAD_REACH, HEAD_THROW }
var _grab_mode: GrabMode = GrabMode.SUPLEX
## 머리 잡기 중 두 손 가운데(리그 로컬) — 잡힌 상대를 손에 붙여 옮기는 쪽이 읽는다
var _head_grab_point: Vector2 = Vector2.ZERO
## 마우스 던지기 동작에 남은 시간(초). 0보다 크면 젖혔다 뿌리는 중이다
var _cast_time: float = 0.0
var _cast_duration: float = 0.34
## 전체 던지기 동작 중 "뒤로 젖히는" 구간의 비율 (play_cast_motion이 두 시간에서 계산한다)
var _cast_windup_ratio: float = 0.4
## 돌 던지기 동작에 남은 시간(초). 0보다 크면 던지는 중이다 (마우스 던지기 _cast_time과 별개)
var _throw_time: float = 0.0
var _throw_duration: float = 0.5
## 던지는 동안 손에 쥐여주는 그림(돌). set_throw_item이 처음 부를 때 만들어진다
var _throw_item: Sprite2D = null
## 지금 던지기 때문에 손에 든 물건을 숨겨놓은 상태인지 (다시 보여줄 때만 손대려고 기억해둔다)
var _held_hidden_by_throw: bool = false
## 줄을 당기는 자세 세기 0~1. set_reeling으로 목표를 정하고 서서히 오간다
var _reel_blend: float = 0.0
var _reel_target: float = 0.0
## 줄을 당기는 박자 위상 — 계속 커지며 sin()으로 당겼다 놓는 왕복을 만든다
var _reel_phase: float = 0.0
## 토하는 얼굴을 보여줄 남은 시간(초). 0보다 크면 토하는 표정이다
var _vomit_time: float = 0.0
## 아파하는 얼굴을 보여줄 남은 시간(초). 0보다 크면 피격 표정이다
var _hurt_time: float = 0.0
## 방어에 막힌 뒤 무기가 깜빡이는 데 남은 시간(초)
var _blocked_flash_left: float = 0.0
## 두 손으로 잡은 정도 (0=제자리, 1=완전히 잡음). **스윙 진행도가 아니라 따로 블렌드하는 이유:**
## 타별 진행도를 쓰면 1타가 끝날 때 왼손이 풀렸다가 2타에서 다시 붙어서, 콤보 내내
## 잡았다 놨다를 반복하는 어색한 그림이 된다. 공격이 이어지는 동안은 계속 1로 유지된다
var _grip_blend: float = 0.0
## 키보드 선풍기 회전에 남은 시간(초). 0보다 크면 회전 난무 중이다
var _fan_time: float = 0.0
## 도는 위상 — 계속 커지며 무기(HandRHold) 회전에 더해진다
var _fan_phase: float = 0.0
## 선풍기 회전 잔상 칸(주먹·스미어 잔상과 따로 쓴다) — 처음 쓸 때 만든다
var _fan_ghosts: Array[Sprite2D] = []
var _fan_ghost_left: Array[float] = []
## 선풍기 회전 중 무기 자식의 원래 위치(끝나면 복구) — 회전축을 손 중심에 맞추려고 잠깐 (0,0)으로 옮긴다.
## 이러면 무기 중심이 손(HandRHold 원점)에 와서, 손 주위를 공전하지 않고 그 자리에서 제자리로 자전한다
var _fan_child_rest: Dictionary = {}
## 선풍기 회전 중 무기 자식의 원래 크기(끝나면 복구) — 도는 동안 fan_weapon_scale만큼 키운다
var _fan_child_scale: Dictionary = {}
## 이번 깜빡임의 전체 길이(초) — Fighter가 넘겨준 잠금 시간이 들어온다
var _blocked_flash_span: float = 0.0
## --- 머리 부들부들 떨기 (악플러 열등감) ---
## 좌우로 까딱거리는 각도(도). "약간 떨리는" 정도라 크게 주면 고개를 젓는 것처럼 보인다
@export var head_shake_angle_deg: float = 4.0
## 같이 흔들리는 거리(px). x는 좌우, y는 위아래
@export var head_shake_offset: Vector2 = Vector2(1.6, 1.1)
## 떨리는 빠르기(라디안/초). 클수록 잘게 부들거린다
@export var head_shake_speed: float = 34.0

## 기본공격이 잠긴 동안 파츠에 붙였다 떼는 빨간 테두리 셰이더
const BLOCKED_OUTLINE_SHADER := preload("res://combat/BlockedOutline.gdshader")
## 평타 하얀 궤적(combat/SwingTrail.gd) — 새 class_name이라 무타입 preload로 쓴다
const SWING_TRAIL_SCRIPT := preload("res://combat/SwingTrail.gd")
## 프레임 사이에 끼워 넣는 궤적 점 수 — 많을수록 호가 매끈하다
const SWING_TRAIL_FILL: int = 4
## 지금 빨간 테두리가 걸려 있는 파츠들 (끝날 때 material을 떼어내야 해서 들고 있는다)
var _blocked_outline_parts: Array = []
## 머리 떨림 남은 시간과 전체 시간(초)
var _head_shake_left: float = 0.0
var _head_shake_span: float = 0.0
## 머리 조준 각도(라디안) — 밖에서 넣어준다
var _head_aim: float = 0.0
## 방어 자세를 얼마나 취하고 있는지 (0=평소, 1=완전히 막는 자세). 목표값으로 서서히 간다
var _guard_blend: float = 0.0
## 박수 — 섞인 정도 / 목표 / 흐른 시간(손이 붙었다 떨어지는 위상)
var _clap_blend: float = 0.0
var _clap_target: float = 0.0
var _clap_time: float = 0.0
## 쌍 악기 자세가 섞인 정도(0~1)
var _dual_blend: float = 0.0
## 돌진 공격이 어느 구간인지 — **궁(`DualInstrumentUltimate`)이 넣어 준다.**
## -1 = 준비동작으로 뒤로 물러나는 중(상체가 뒤로 젖혀진다) / 1 = 앞으로 내지르는 중 / 0 = 평소
var dual_dash_phase: float = 0.0
var _guard_target: float = 0.0
var _counter_blend: float = 0.0
var _counter_target: float = 0.0
var _counter_phase: float = 0.0
## 돌진 자세 섞임(0~1)과 목표값
var _charge_blend: float = 0.0
var _charge_target: float = 0.0
## 무릎 꿇기 자세 섞임(0~1)과 목표값
var _kneel_blend: float = 0.0
var _kneel_target: float = 0.0
## 망치질 자세 섞임(0~1)·목표값·켠 뒤 흐른 시간, 손에 쥐여주는 임시 망치 그림
var _hammer_blend: float = 0.0
var _hammer_target: float = 0.0
var _hammer_time: float = 0.0
var _hammer: Node2D = null
var _lift_blend: float = 0.0
var _lift_target: float = 0.0
var _stomp_blend: float = 0.0
var _stomp_target: float = 0.0
## 드롭킥 단계 (0=안 함, 1=공중에서 두 발 뻗기, 2=넘어졌다 일어나는 중)
var _dk_stage: int = 0
## 드롭킥 자세 섞임(0~1) / 몸이 누운 각도(라디안) / 몸이 내려간 양
var _dk_blend: float = 0.0
var _dk_angle: float = 0.0
var _dk_shift: Vector2 = Vector2.ZERO
## 일어나기까지 남은 시간과 전체 시간(초)
var _dk_getup_left: float = 0.0
var _dk_getup_total: float = 0.0
## 지금 술 머금은 얼굴 상태인지 (술 스택이 남아있는 동안 true)
var _drunk_head_on: bool = false
## 지금 스킬 액션 표정 상태인지 (자전거 돌진·총 쏘기 동안 true) — 취함/맨정신보다 우선한다
var _action_face_on: bool = false
## 토하기 전 원래 머리 텍스처/배율 — 토하기가 끝나면 이걸로 되돌린다
## 처치 연출 중인지 — 켜지면 걷기·표정 갱신을 전부 멈추고 쓰러진 자세를 유지한다
var _knocked_out: bool = false
var _head_rest_texture: Texture2D
var _head_rest_scale: Vector2
# 몸통 돌리기용 — 원래 몸통 그림·배율
var _body_rest_texture: Texture2D
var _body_rest_scale: Vector2
## 그림별 "확실히 보이는 영역"(Rect2) — 리그끼리 공유해 그림마다 게임 전체에서 한 번만 잰다
static var _opaque_rect_cache: Dictionary = {}
## 씬에 저장돼 있던 각 조각의 제자리 위치 {Sprite2D: Vector2}
var _rest_positions: Dictionary = {}
## 손에 든 악기의 제자리 {Node2D: [위치, 각도]} — 포즈 씬이 건드린 뒤 되돌리는 데 쓴다
var _held_rest: Dictionary = {}
## 안고 있는 것의 제자리 — 몸 들썩임을 여기에 더한다
var _carry_rest: Vector2 = Vector2.ZERO
## 아이가 품에 안긴 정도(0 옆에서 걷기 → 1 품에 안김)와, 지금 안기려는 중인지
var _hug_blend: float = 0.0
var _hug_want: bool = false
## 지금 우쭈쭈 표정을 짓고 있는지 — 안기는 동작(hug_pose)이 없어도 표정은 따로 켜진다
var _hug_face_on: bool = false
## 영역전개 점프 자세를 쓰는 중인지(궁극기가 켜고 끈다)와 착지 자세가 남은 시간
var _domain_jump: bool = false
var _domain_land_left: float = 0.0
## 아이 드롭킥이 남은 시간(0이면 안 하는 중)
var _kid_kick_left: float = 0.0
## 아이 조각들의 제자리 {이름: 위치} — 걷기 흔들림을 여기에 더한다
var _kid_rest: Dictionary = {}
## 아이 조각들의 제자리 각도 {이름: 라디안}
var _kid_rest_rot: Dictionary = {}
## 아이 머리의 평소 그림·크기 — 우는 얼굴에서 되돌릴 때 쓴다
var _kid_head_rest_texture: Texture2D = null
var _kid_head_rest_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	# Visual로 붙는 자리가 Fighter의 자식이라 부모가 곧 조종 대상이다.
	# 미리보기 도구처럼 Fighter 없이 띄우면 null이고, 그때는 가만히 서 있는다
	_fighter = get_parent() as Fighter
	# **기본 자세 씬이 있으면 먼저 입힌다** — 그 다음에 제자리를 기억해야
	# 걷기·공격이 돌아올 자리가 씬에 잡아 둔 자리가 된다
	_apply_rest_pose()
	for part in [_foot_l, _foot_r, _body, _head, _hand_l, _hand_r]:
		if part:
			_rest_positions[part] = part.position
	# 손에 든 악기(리코더·단소)의 제자리 값도 따로 기억한다.
	# **포즈 씬이 이 둘의 자리까지 바꾸기 때문이다** — 안 기억해 두면 던지는 자세(1타)가 리코더를
	# 손에서 멀찍이 밀어 놓은 그 자리에 **영영 남아서**, 돌아와도 손에 안 붙은 것처럼 보인다
	if _carry:
		_carry_rest = _carry.position
		for kid_name in ["KidHead", "KidBody", "KidFootL", "KidFootR", "KidHandL", "KidHandR"]:
			var kid_part: Node2D = _carry.get_node_or_null(kid_name) as Node2D
			if kid_part:
				_kid_rest[kid_name] = kid_part.position
				_kid_rest_rot[kid_name] = kid_part.rotation
		var kid_head := _carry.get_node_or_null("KidHead") as Sprite2D
		if kid_head:
			_kid_head_rest_texture = kid_head.texture
			_kid_head_rest_scale = kid_head.scale
	for part_name in ["Recorder", "Danso"]:
		var held: Node2D = _pose_part(part_name)
		if held:
			_held_rest[held] = [held.position, held.rotation]
	# 토하기가 끝나면 되돌릴 수 있게 원래 머리 그림/배율을 기억해둔다
	if _head:
		_head_rest_texture = _head.texture
		_head_rest_scale = _head.scale
	if _body:
		_body_rest_texture = _body.texture
		_body_rest_scale = _body.scale
	if _hand_l:
		_hand_l_rest_z = _hand_l.z_index
		# 헬스장에서 팔이 부풀었다 되돌아올 기준 크기(두 손은 같은 크기로 그려져 있다)
		_hand_rest_scale = _hand_l.scale
	if _foot_l:
		_foot_rest_scale = _foot_l.scale
	if _hand_r:
		_hand_r_rest_z = _hand_r.z_index
	if _hand_r_hold:
		_hand_r_hold_rest_z = _hand_r_hold.z_index
	if _hand_l_hold:
		_hand_l_hold_rest_z = _hand_l_hold.z_index
	# 자전거는 평소엔 숨기고, "탄 위치"를 기억해둔다 (여기서 뒤로 밀어 슬라이드 연출)
	if _bike:
		_bike_mounted_pos = _bike.position
		_bike.visible = false
	# 그릇은 몸 앞·두 손 뒤에 그린다 — 순서는 씬 파일에서 HandL 앞(index)에 둘 것.
	# ⚠️ 여기서 move_child로 옮기면 duplicate()(대시 잔상)가 자식 속성을 순서로 복사해 잔상 머리가 커진다
	if _eat_bowl:
		_eat_bowl_rest_scale = _eat_bowl.scale
		_eat_bowl.visible = false

## 헬스장 단계만큼 손·발 그림을 키운다(기획서 "강화된 부위가 변해 한눈에 보임") — `set_limb_stage()`가 값을 넣는다.
## **원래 크기에 곱한다** — 캐릭터마다 손·발 그림 크기가 달라서 절대값으로 쓰면 다 어긋난다.
## 리그의 다른 곳은 손·발 `scale`을 건드리지 않으므로 여기서만 쓰면 안 싸운다
func _apply_muscle() -> void:
	if is_equal_approx(muscle_arm, _muscle_arm_shown) and is_equal_approx(muscle_leg, _muscle_leg_shown):
		return
	_muscle_arm_shown = muscle_arm
	_muscle_leg_shown = muscle_leg
	# _tex_fit: 단계 그림(금빛 주먹 등)으로 바꿔 꼈을 때 원래 손·발과 같은 크기로 보이게 맞추는 배율
	if _hand_l:
		_hand_l.scale = _hand_rest_scale * muscle_arm * _hand_tex_fit
	if _hand_r:
		_hand_r.scale = _hand_rest_scale * muscle_arm * _hand_tex_fit
	if _foot_l:
		_foot_l.scale = _foot_rest_scale * muscle_leg * _foot_tex_fit
	if _foot_r:
		_foot_r.scale = _foot_rest_scale * muscle_leg * _foot_tex_fit

func _process(delta: float) -> void:
	if _knocked_out:
		return   # 쓰러진 자세를 코드가 매 프레임 되돌리지 않도록 리그 갱신을 통째로 멈춘다
	var speed_ratio: float = 0.0
	# Fighter 없이(미리보기 도구 등) 띄운 경우엔 그냥 바닥에 서 있는 것으로 친다
	var on_floor: bool = true
	if _fighter and is_instance_valid(_fighter):
		on_floor = _fighter.is_on_floor()
		# 지금 속도가 그 캐릭터 최고 속도의 몇 %인지 — 느리게 걸으면 발도 덜 흔들리게 하려고 쓴다
		var max_speed: float = _fighter.stats.move_speed * _fighter.move_speed_multiplier
		if max_speed > 0.0:
			speed_ratio = clampf(absf(_fighter.velocity.x) / max_speed, 0.0, 1.0)
	elif manual_speed_ratio >= 0.0:
		# Fighter 없이 띄운 경우 — 바깥에서 넣어준 값으로 걷기 동작을 돌린다
		speed_ratio = clampf(manual_speed_ratio, 0.0, 1.0)

	# 숨쉬기 위상은 항상 진행 (가만히 서 있을 때만 화면에 반영된다)
	_breathe_phase += delta * breathe_speed
	# 헬스장에서 쌓은 스펙만큼 팔·다리를 부풀린다 — 다른 맵에선 둘 다 1이라 그냥 지나간다
	_apply_muscle()
	_update_blocked_flash(delta)
	# 두 손 잡기 — 공격이 도는 동안은 1로, 콤보가 끝나면 0으로 서서히 돌아간다.
	# weapon_on_final_hit이 켜져 있으면 **마지막 타에만** 왼손이 합류한다(앞 타는 한 손 주먹)
	if attack_two_handed:
		var want_grip: bool = _attack_time > 0.0
		# **없는 무기를 두 손으로 잡을 수는 없다** — 경찰처럼 무기를 넣었다 뺐다 하는 캐릭터는
		# 맨손일 때 두 손 잡기를 풀어야 권투 자세(unarmed_guard_hand)와 안 싸운다
		if weapon_switch and not held_item_armed:
			want_grip = false
		# 평소에도 두 손으로 잡는 캐릭터(악플러) — 손을 따로 쓰는 스킬 중에만 푼다
		if two_handed_always and _cast_time <= 0.0 and _reel_blend <= 0.01 and _drink_time <= 0.0 and _gun_time <= 0.0 and _eat_time <= 0.0 and _grab_time <= 0.0 and _throw_time <= 0.0:
			want_grip = true
		if weapon_on_final_hit:
			want_grip = want_grip and _attack_variant >= final_hit_index
		if grip_hit_index >= 0:
			want_grip = want_grip and _attack_variant == grip_hit_index
		_grip_blend = move_toward(_grip_blend, 1.0 if want_grip else 0.0, delta * attack_grip_speed)
		# 두 손으로 잡는 동안엔 왼손을 키보드(z 1)보다 앞으로 올려 두 손이 다 보이게 한다.
		# 잡기가 풀리면 원래 z로 되돌린다(안경 올리기가 세팅한 z 3은 건드리지 않는다 — 동시에 안 나온다)
		if _hand_l:
			if _grip_blend > 0.5:
				_hand_l.z_index = attack_grip_hand_z
			elif _hand_l.z_index == attack_grip_hand_z:
				_hand_l.z_index = _hand_l_rest_z
	# 베는 동안엔 손·무기를 머리 앞으로 올린다(머리 위로 넘기는 구간에서 안 가려지게). 끝나면 되돌린다
	_apply_slash_z(_attack_time > 0.0 and _attack_variant >= SLASH_VARIANT_BASE)

	if _attack_time > 0.0:
		_attack_time = maxf(_attack_time - delta, 0.0)
	# 키보드 선풍기 회전 — 도는 동안 위상이 계속 커진다
	if _fan_time > 0.0:
		_fan_time = maxf(_fan_time - delta, 0.0)
		_fan_phase += delta * fan_spin_speed
	if _step_time > 0.0:
		_step_time = maxf(_step_time - delta, 0.0)
	if _crouch_time > 0.0:
		_crouch_time = maxf(_crouch_time - delta, 0.0)
	if _flinch_time > 0.0:
		_flinch_time = maxf(_flinch_time - delta, 0.0)
	if _drink_time > 0.0:
		_drink_time = maxf(_drink_time - delta, 0.0)
	if _vomit_time > 0.0:
		_vomit_time = maxf(_vomit_time - delta, 0.0)
		# 시간이 다 되면 원래 얼굴로 되돌린다
		if is_zero_approx(_vomit_time):
			_restore_head()
	if _hurt_time > 0.0:
		_hurt_time = maxf(_hurt_time - delta, 0.0)
		if is_zero_approx(_hurt_time):
			_restore_head()
	# 총 조준 시간 카운트다운 — 끝나면 총을 다시 숨긴다
	if _gun_time > 0.0:
		_gun_time = maxf(_gun_time - delta, 0.0)
		if is_zero_approx(_gun_time) and _gun:
			_gun.visible = false
	if _eat_time > 0.0:
		_eat_time = maxf(_eat_time - delta, 0.0)
		if is_zero_approx(_eat_time):
			stop_eat_motion()
	# 발사 반동은 매 프레임 서서히 잦아든다
	if _recoil > 0.0:
		_recoil = maxf(_recoil - delta * gun_recoil_recover, 0.0)
	if _grab_time > 0.0:
		_grab_time = maxf(_grab_time - delta, 0.0)
		if is_zero_approx(_grab_time):
			rotation = 0.0   # 내리꽂기가 끝나면 뒤로/앞으로 기울였던 몸을 원래대로
	if _cast_time > 0.0:
		_cast_time = maxf(_cast_time - delta, 0.0)
	if _throw_time > 0.0:
		_throw_time = maxf(_throw_time - delta, 0.0)
	# 줄 당기는 자세는 목표로 서서히 오가고, 당기는 박자는 그 자세일 때만 진행된다
	_reel_blend = move_toward(_reel_blend, _reel_target, delta * reel_blend_speed)
	_guard_blend = move_toward(_guard_blend, _guard_target, delta * guard_blend_speed)
	_clap_blend = move_toward(_clap_blend, _clap_target, delta * clap_blend_speed)
	if _clap_target > 0.0:
		_clap_time += delta
	# 쌍 악기 자세는 궁을 켠 동안 1로 차오른다. 공격 중에는 손을 스윙이 가져가야 하므로 잠깐 0으로 빠진다
	var dual_want: float = 1.0 if (held_item_l_armed and _attack_time <= 0.0) else 0.0
	_dual_blend = move_toward(_dual_blend, dual_want, delta * dual_blend_speed)
	_charge_blend = move_toward(_charge_blend, _charge_target, delta * charge_blend_speed)
	_kneel_blend = move_toward(_kneel_blend, _kneel_target, delta * kneel_blend_speed)
	_hammer_blend = move_toward(_hammer_blend, _hammer_target, delta * kneel_blend_speed)
	if _hammer_target > 0.0:
		_hammer_time += delta
	_lift_blend = move_toward(_lift_blend, _lift_target, delta * slam_blend_speed)
	_stomp_blend = move_toward(_stomp_blend, _stomp_target, delta * slam_blend_speed)
	_counter_blend = move_toward(_counter_blend, _counter_target, delta * counter_blend_speed)
	_counter_phase = _counter_phase + delta * counter_poke_speed if _counter_blend > 0.001 else 0.0
	_update_dropkick(delta)
	if _head_shake_left > 0.0:
		_head_shake_left = maxf(_head_shake_left - delta, 0.0)
	if _reel_blend > 0.001:
		_reel_phase += delta * reel_tug_speed
	else:
		_reel_phase = 0.0

	# 공중이면 점프 자세로, 바닥이면 원래 자세로 서서히 옮겨간다
	var air_target: float = 0.0 if on_floor else 1.0
	_air_blend = move_toward(_air_blend, air_target, delta * jump_blend_speed)

	# 공중에서 아래로 떨어지는 중(velocity.y > 0)이면 고개를 숙인다 — 올라가는 중엔 숙이지 않는다
	var falling: bool = not on_floor and _fighter != null and is_instance_valid(_fighter) and _fighter.velocity.y > 0.0
	_fall_blend = move_toward(_fall_blend, 1.0 if falling else 0.0, delta * fall_blend_speed)

	# 바닥에서 조작 없이(안 걷고·안 뛰고·안 때리고) 가만히 있으면 일정 시간마다 머리를 긁는다
	# idle_gestures를 끄면 여기서 바로 false가 되어 아래 "취소" 가지로 빠진다 — 모션이 아예 안 나온다
	# 카운터 자세 중엔 몸짓 금지 — 뒤돌아보기가 끼면 몸은 앞을 보는데 머리만 뒤를 봐서 단소가 뒤통수 뒤로 간 것처럼 보였다(2026-09-30)
	# 운동(헬스장) 중에는 몸짓을 안 한다 — 바벨을 든 채 뒤를 돌아보면 봉이 따라 돌아 이상하다
	var idle: bool = idle_gestures and not _workout_on and _curl_blend <= 0.001 and _squat_blend <= 0.001 and _run_blend <= 0.001 and on_floor and speed_ratio < 0.05 and _attack_time <= 0.0 and _drink_time <= 0.0 and _vomit_time <= 0.0 and _gun_time <= 0.0 and _eat_time <= 0.0 and _grab_time <= 0.0 and _cast_time <= 0.0 and _throw_time <= 0.0 and _reel_blend <= 0.01 and _hurt_time <= 0.0 and _counter_target <= 0.0
	if not idle:
		# 움직이거나 다른 동작이 시작되면 idle 모션 즉시 취소. 돌아보던 중이면 머리를 반드시 앞으로 되돌린다
		_idle_time = 0.0
		_scratch_time = 0.0
		_end_lookback()
		_end_special()
	elif _scratch_time > 0.0:
		_scratch_time = maxf(_scratch_time - delta, 0.0)
	elif _special_time > 0.0:
		_special_time = maxf(_special_time - delta, 0.0)
		if is_zero_approx(_special_time):
			_end_special()
	elif _lookback_time > 0.0:
		_lookback_time = maxf(_lookback_time - delta, 0.0)
		if is_zero_approx(_lookback_time):
			_end_lookback()   # 정상 종료 — 머리를 앞으로 되돌린다
	else:
		_idle_time += delta
		if _idle_time >= idle_motion_delay:
			_idle_time = 0.0
			# 특수 몸짓이 있으면 셋 중 하나, 없으면 머리 긁기 / 뒤돌아보기 중 하나를 랜덤으로 고른다
			if idle_special != 0 and randf() < 0.34:
				_start_special()
			elif randf() < 0.5:
				_scratch_time = scratch_duration
			elif _head:
				_lookback_time = lookback_duration

	# 방향 전환 머리 돌리기 — 다 돌면 평소 머리로 되돌린다.
	# 공격·스킬 같은 동작이 시작되면 그 자리에서 끝내 몸을 새 방향으로 맞춘다(그림은 옛 방향인데 공격은 새 방향으로 나가면 안 된다)
	if _face_turn_time > 0.0:
		_face_turn_time = maxf(_face_turn_time - delta, 0.0)
		if _face_turn_blocked():
			_face_turn_time = 0.0
		if is_zero_approx(_face_turn_time):
			_clear_head_frame()

	# 점프/착지 스쿼시&스트레치 — 착지하는 순간(공중→바닥)을 감지해 몸을 납작하게 눌렀다 편다
	if on_floor and not _was_on_floor:
		_squash = land_squash
		_squashing = true
	_was_on_floor = on_floor
	# 튄 크기는 시간이 지나며 원래(1,1)로 돌아온다
	if _squashing and not _squash.is_equal_approx(Vector2.ONE):
		_squash = _squash.move_toward(Vector2.ONE, delta * squash_recover_speed)
	# 착지 경직 중엔 주저앉는 정도만큼 계속 납작하게 누른다 — 착지 순간 스쿼시가 더 세면 그게 풀릴 때까지 그쪽을 따른다
	if _crouch_time > 0.0 and _crouch_len > 0.0:
		var hold: Vector2 = Vector2.ONE.lerp(land_lag_squash, _land_crouch_amount())
		_squash = Vector2(maxf(_squash.x, hold.x), minf(_squash.y, hold.y))
		_squashing = true

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

	# 대치 자세 — 손을 따로 쓰는 동작 중에는 풀었다가 끝나면 다시 든다
	var stance_on: bool = fight_stance and _drink_time <= 0.0 and _gun_time <= 0.0 and _eat_time <= 0.0 and _grab_time <= 0.0 \
		and _cast_time <= 0.0 and _reel_blend <= 0.01 and _guard_target <= 0.0 and _clap_target <= 0.0 and _charge_target <= 0.0 and _kneel_target <= 0.0 \
		and _lift_target <= 0.0 and _stomp_target <= 0.0 and _counter_target <= 0.0 and _ride_target <= 0.0 and _clash_target <= 0.0 and _scratch_time <= 0.0 and _dk_stage == 0
	_stance_blend = move_toward(_stance_blend, 1.0 if stance_on else 0.0, delta * stance_blend_speed)

	# 스킬 클래시 대치 — 목표(_clash_target)로 서서히 오간다
	_clash_blend = move_toward(_clash_blend, _clash_target, delta * clash_blend_speed)
	_tick_clash_punches(delta)

	# 맨손 잽 가드 — 이번 타의 반대 손만 가드로, 나머지는 원래 자세로 서서히
	var guard_hand_now: Sprite2D = null
	if _attack_time > 0.0 and unarmed_guard_hand and not held_item_armed and not _is_headbutt():
		guard_hand_now = _guard_hand()
	_jab_guard_l = move_toward(_jab_guard_l, 1.0 if guard_hand_now != null and guard_hand_now == _hand_l else 0.0, delta * unarmed_guard_blend_speed)
	_jab_guard_r = move_toward(_jab_guard_r, 1.0 if guard_hand_now != null and guard_hand_now == _hand_r else 0.0, delta * unarmed_guard_blend_speed)

	if on_floor and speed_ratio > 0.05:
		_phase += delta * step_speed * maxf(speed_ratio, 0.3)
		_blend = minf(_blend + delta * blend_speed, 1.0)
	else:
		_blend = maxf(_blend - delta * blend_speed, 0.0)
		if is_zero_approx(_blend):
			# 완전히 멈췄으면 다음 걸음이 항상 같은 자세에서 시작하도록 위상을 초기화
			_phase = 0.0

	# 아이가 품으로 뛰어오르거나 내려서는 진행도
	_update_hug(delta)
	# 헬스장 바벨 컬 — 켜고 끄는 진행도와 한 번(올렸다 내리기) 안의 위치
	_update_curl(delta)
	# 헬스장 스쿼트 — 앉았다 서는 진행도
	_update_squat(delta)
	# 헬스장 런닝머신 — 달리는 진행도
	_update_run(delta)
	# 영역전개 점프 — 공중에 있는 동안은 착지 자세 시간을 가득 채워 둔다
	_update_domain_jump(delta)
	# 아이 드롭킥 — 나갔다 들어오는 시간
	_kid_kick_left = maxf(_kid_kick_left - delta, 0.0)
	# 런닝머신 장비 단계면 머리·몸·손 제자리를 그 자리(+ 로켓은 공중에 뜬 높이)로
	_update_gear_lift(delta)
	_apply_pose(speed_ratio)
	# 헬스장 런닝머신 단계 장비(바퀴·로켓 신발) — 발 자세가 다 정해진 뒤에 따라붙는다
	_update_treadmill_gear(delta)
	_update_smear(delta)
	_update_swing_trail()
	_update_fan_ghosts(delta)

func _apply_pose(speed_ratio: float) -> void:
	# **손에 든 악기를 먼저 제자리로 되돌린다.** 발·손처럼 매 프레임 제자리에서 다시 계산되는 조각과 달리
	# 리코더·단소는 아무도 안 건드리면 지난 포즈가 남긴 자리에 그대로 굳는다
	_reset_held_items()
	# 지난 프레임에 뒤돌기로 얇게 눌러둔 가로 크기를 먼저 되돌린다
	if _spin_applied:
		scale.x = _spin_base_x
		_spin_applied = false
	_face_moving_direction()

	var amount: float = _blend * maxf(speed_ratio, 0.4)
	# 자전거를 타는 동안엔 걷기 흔들림을 줄인다 (발은 아래에서 페달 동작으로 덮어쓴다)
	amount *= (1.0 - _ride_blend)

	# 두 발은 반 바퀴 어긋난 채로 계속 앞뒤를 오간다 — 한쪽이 앞으로 나가면 다른 쪽은 뒤로 밀리고,
	# 반 바퀴 뒤에 앞발과 뒷발이 뒤바뀐다
	var swing: float = sin(_phase)

	# 앞으로 나가는 동안(swing이 양수)에만 발끝을 들고, 뒤로 밀리는 동안엔 바닥을 딛는 것처럼 눕힌다.
	# 공중에서는 걷기 쪽이 0으로 잦아들고 대신 두 발이 함께 점프 각도로 뻗는다
	# 들어 올리기는 "앞으로 옮겨지는 중"인 발에만 — 앞뒤 위치가 sin이라 그 변화 방향(cos)이 양수인 동안이다.
	# 가운데를 지나며 가장 높이 뜨고 앞에 닿을 때 내려앉는다. 그동안 다른 발은 바닥을 디딘 채 뒤로 밀린다
	var stepping: float = cos(_phase)
	# 런닝머신 장비(바퀴·로켓 신발)를 끼웠으면 걷지 않고 미끄러진다 — 발걸음·들썩임을 끈다
	var step_amount: float = amount * (1.0 - _gear_glide)
	_pose_foot(_foot_l, maxf(swing, 0.0) * step_amount, swing * step_amount, maxf(stepping, 0.0) * step_amount)
	_pose_foot(_foot_r, maxf(-swing, 0.0) * step_amount, -swing * step_amount, maxf(-stepping, 0.0) * step_amount)

	# 발이 가장 높이 들렸을 때 몸도 같이 뜨게 해서 한 걸음마다 한 번씩 들썩인다. 위쪽이 음수라 빼준다
	var bob: float = -absf(swing) * body_bob * step_amount
	# 가만히 서 있을 때(바닥·안 걷는 중)만 몸/머리/손이 숨쉬듯 위아래로 미묘하게 움직인다. 걷기 시작하면 서서히 사라진다.
	# 손은 몸통과 다른 박자(위상 차이)로, 좌우 손도 살짝 어긋나게 해서 같이 움직이는 어색함을 없앤다
	var on_floor_now: bool = _fighter == null or (is_instance_valid(_fighter) and _fighter.is_on_floor())
	var idle_f: float = (1.0 - _blend) if on_floor_now else 0.0
	# 바벨 컬 중엔 숨쉬기를 죽인다 — 컬 박자로 몸이 오르내리는 것과 겹치면 박자가 둘이 되어 떨려 보인다
	if _curl_blend > 0.001 and curl_breath_mute > 0.0:
		idle_f *= 1.0 - clampf(curl_breath_mute, 0.0, 1.0) * _curl_blend
	if _squat_blend > 0.001 and squat_breath_mute > 0.0:
		idle_f *= 1.0 - clampf(squat_breath_mute, 0.0, 1.0) * _squat_blend
	if _run_blend > 0.001 and run_breath_mute > 0.0:
		idle_f *= 1.0 - clampf(run_breath_mute, 0.0, 1.0) * _run_blend
	var body_breathe: float = sin(_breathe_phase) * breathe_amount * idle_f
	var hand_amt: float = breathe_amount * breathe_hand_ratio * idle_f
	for part in [_body, _head]:
		if part:
			# **x도 같이 제자리로 되돌린다.** 예전엔 y만 잡았는데, 머리·몸통의 x를 매 프레임 건드리는
			# 자세(드롭킥처럼 조각을 통째로 돌리는 것)가 생기면 그 값이 프레임마다 쌓여서
			# 머리가 화면 밖으로 날아간다. 손·발은 원래 x를 매 프레임 다시 잡아 이 문제가 없었다
			part.position = Vector2(_rest_positions[part].x, _rest_positions[part].y + bob + body_breathe)
	if _hand_r:
		_hand_r.position.y = _rest_positions[_hand_r].y + bob + sin(_breathe_phase + breathe_hand_phase) * hand_amt
	if _hand_l:
		_hand_l.position.y = _rest_positions[_hand_l].y + bob + sin(_breathe_phase + breathe_hand_phase + 0.5) * hand_amt
	# 몸통 기울기도 머리·오른손과 같이 매 프레임 제자리로 되돌린다 — 아래에서 발차기·돌진 자세가
	# 덮어쓰고, 그 동작이 끝나면 기울기가 남지 않고 저절로 풀린다
	if _body:
		_body.rotation = 0.0
	# 술 마시기·두 손 잡기가 매 프레임 덮어쓰므로, 오른손 회전과 마찬가지로 여기서 한 번 제자리로 되돌려둔다
	if _head:
		# 하강 중이면 고개를 아래로 숙인다 (마시기 동작이 있으면 아래에서 덮어써서 그쪽이 우선한다)
		_head.rotation = deg_to_rad(fall_head_tilt_deg) * _fall_blend
		# 표정이 바뀐 동안에는 얼굴 위치를 맞추기 위한 보정만 더한다(누적되지 않게 절대 위치로 잡는다)
		if _hurt_time > 0.0:
			_head.position = _rest_positions[_head] + Vector2(0.0, bob) + hurt_head_offset
		elif _vomit_time > 0.0:
			_head.position = _rest_positions[_head] + Vector2(0.0, bob) + vomit_head_offset
	if _hand_l:
		_hand_l.rotation = 0.0

	# 손은 발과 반대로 흔들린다. sin은 앞쪽 절반(왼발이 나가는 동안)에 양수라
	# 그때 오른손이 앞으로 나가고 왼손이 뒤로 빠진다
	var arm: float = sin(_phase) * amount * hand_swing
	# 바퀴로 달리는 동안(런닝머신 위 포함)엔 걷기 박자 대신 바퀴 박자로 손을 앞뒤로 흔든다
	if _gear_ride > 0.0:
		arm = lerpf(arm, sin(_gear_ride_phase) * hand_swing * gear_ride_hand_scale, _gear_ride)
	if _hand_l:
		_hand_l.position.x = _rest_positions[_hand_l].x - arm
	if _hand_r:
		_hand_r.position.x = _rest_positions[_hand_r].x + arm
		_hand_r.rotation = 0.0

	# 줄을 당기는 중이면 두 손으로 줄을 잡은 자세를 잡는다.
	# **다른 동작들보다 먼저 적용해서 일부러 우선순위를 가장 낮게 뒀다** — 줄을 되감는 도중에
	# 공격이나 스킬을 쓰면 그 동작이 보여야 하기 때문이다(줄 자체는 자세와 상관없이 계속 감긴다).
	# 예전에는 이 블록이 맨 아래라 당기는 자세가 모든 동작을 덮어써서, 되감는 동안 아무 모션도 안 나왔다
	if _reel_blend > 0.001:
		_pose_reel()

	# 파고드는 중이면 앞발이 먼저 나가고 뒷발이 따라붙는다 (걷기 발 자세 위에 덮어쓴다)
	if _step_time > 0.0:
		_pose_lunge_step()

	# 휘두르는 중이면 오른손 자세를 공격 동작으로 덮어쓴다.
	# **그 타에 포즈 씬을 잡아 뒀으면 그게 이긴다** — 머리부터 발까지 씬에 잡아 둔 그대로 간다
	_attack_pose_on = false
	if _attack_time > 0.0:
		_attack_pose_on = _pose_attack_scenes()
		if not _attack_pose_on:
			_pose_attack_hand()
	# 맨손 잽이면 반대 손을 얼굴 앞에 올린다 — 한 손은 막고 한 손은 뻗는 권투 자세.
	# 지금 자세(걷기·잽) 위에 블렌드만큼 섞어서, 타가 바뀌거나 끝날 때 손이 미끄러지듯 오간다
	if not _attack_pose_on:
		_blend_jab_guard(_hand_l, _jab_guard_l)
		_blend_jab_guard(_hand_r, _jab_guard_r)
	if _attack_time > 0.0 and not _attack_pose_on:
		# 어퍼컷이면 고개와 상체가 치는 내내 점점 돌아간다
		if _is_headbutt():
			_pose_headbutt()
		elif _attack_variant >= SLASH_VARIANT_BASE:
			# 베기는 상체가 같이 넘어간다 — 손만 움직이면 "툭 친다"로 보인다
			_pose_slash_lean()
		elif unarmed_uppercut and not held_item_armed and _attack_variant >= final_hit_index:
			_pose_uppercut_lean()
	# 몸통 그림 갈아 끼우기 — 치는 타가 목록에 있으면 그 그림, 아니면 원래대로.
	# 매 프레임 확인한다(공격이 도중에 끊겨도 원래 그림으로 돌아오게)
	# (원래 그림은 몸통 돌리기 기능이 이미 `_body_rest_texture`에 담아 둔다 — 같은 값이라 그걸 쓴다)
	if _body and attack_body_texture != null and not attack_body_hits.is_empty():
		var want_side: bool = _attack_time > 0.0 and attack_body_hits.has(_attack_variant)
		var want: Texture2D = attack_body_texture if want_side else _body_rest_texture
		if want != null and _body.texture != want:
			_body.texture = want
		# 좌우 반전은 그림을 바꾼 타에서만 — 평소엔 항상 원래대로 돌려둔다
		_body.flip_h = want_side and attack_body_flip_hits.has(_attack_variant)

	# **여러 장을 차례로 넘기는 타**(경찰 1타·어퍼컷) — 한 타 안에서 몸이 돌아가는 걸 보여준다.
	# 위 한 장짜리 규칙보다 나중에 둬서, 목록에 있는 타에서는 이쪽이 이긴다
	if _body and not uppercut_body_textures.is_empty() and _attack_time > 0.0 			and attack_frame_hits.has(_attack_variant) and not held_item_armed:
		var up_prog: float = 1.0 - _attack_time / maxf(_attack_len, 0.001)
		# 감기+치기 구간(복귀 전까지)을 장수만큼 균등하게 쪼개 차례로 넘긴다.
		# 복귀 구간에서는 마지막 장을 유지한다 — 치자마자 정면으로 튀면 돌아간 게 안 보인다
		var span: float = maxf(ATTACK_STRIKE_END, 0.01)
		var k: float = clampf(up_prog / span, 0.0, 0.999)
		var idx: int = int(k * float(uppercut_body_textures.size()))
		idx = clampi(idx, 0, uppercut_body_textures.size() - 1)
		var up_tex: Texture2D = uppercut_body_textures[idx]
		if up_tex != null and _body.texture != up_tex:
			_body.texture = up_tex
		_body.flip_h = false
	elif _body and _body_rest_texture != null and body_turn_textures.is_empty() 			and attack_body_texture == null and _body.texture != _body_rest_texture:
		# 그림을 바꾸는 타가 끝났으면 원래 몸통으로 돌려둔다 —
		# 안 돌려놓으면 다음 타·평소 자세까지 마지막 프레임(측면)이 남는다
		_body.texture = _body_rest_texture
		_body.flip_h = false

	# 그 타가 발차기면 두 발·몸통도 차는 자세로 덮어쓴다 (손은 위에서 이미 균형 자세를 잡았다).
	# 드롭킥이 돌고 있으면 건너뛴다 — 아래 드롭킥 자세가 두 발을 따로 잡으므로 두 번 손대면 싸운다
	if _attack_time > 0.0 and not _attack_pose_on and attack_kick_hit >= 0 and _attack_variant == attack_kick_hit and _dk_blend <= 0.001:
		_pose_kick()

	# 마시는 중이면 머리와 오른손을 술 마시는 자세로 덮어쓴다 (공격보다 나중이라 우선한다)
	if _drink_time > 0.0:
		_pose_drink()

	# 총을 겨누는 중이면 두 손을 모아 총을 잡은 자세로 덮어쓴다 (걷기·공격보다 우선한다)
	if _gun_time > 0.0:
		_pose_gun()

	# 짜장면을 먹는 중이면 두 손과 고개를 먹는 자세로 덮어쓴다
	if _eat_time > 0.0:
		_pose_eat()

	# 파일드라이버 중이면 오른손과 몸 전체 기울기를 잡기~내리꽂기 자세로 덮어쓴다
	if _grab_time > 0.0:
		_pose_grab()

	# 마우스를 던지는 중이면 오른손을 젖혔다 뿌리는 자세로 덮어쓴다
	if _cast_time > 0.0:
		_pose_cast()

	# 돌을 던지는 중이면 양손·몸통·머리·두 발을 전부 던지기 자세로 덮어쓴다 (마우스 던지기보다 큰 동작이라 나중에 적용)
	if _throw_time > 0.0:
		_pose_throw()

	# 가만히 있을 때는 왼손으로 머리를 긁는다 (idle 생동감). 왼손만 건드려서 다른 동작과 안 겹친다
	if _scratch_time > 0.0:
		_pose_scratch()

	# 캐릭터별 특수 idle 몸짓(안경 올리기·딸꾹질) — 다른 자세 위에 더하거나 왼손만 쓴다
	if _special_time > 0.0:
		_pose_special()

	# 두 손으로 무기를 잡는 자세 (악플러 키보드) — 공격이 끝난 뒤에도 블렌드가 남아 있으므로
	# 스윙 안이 아니라 여기서 매 프레임 적용한다. 왼손만 건드리므로 오른손 동작과 안 겹친다.
	# 선풍기 회전 중엔 아래 _pose_keyboard_fan이 두 손을 따로 잡으므로 건너뛴다
	if attack_two_handed and _grip_blend > 0.001 and _fan_time <= 0.0:
		_pose_grip_hand()

	# 뒤돌아보는 중이면 몸은 그대로 두고 머리만 반대쪽을 본다
	if _lookback_time > 0.0:
		_pose_lookback()

	# 방금 방향을 바꿨으면 머리가 그림을 넘기며 새 방향으로 따라 돈다 (뒤돌아보기보다 나중이라 우선한다)
	if _face_turn_time > 0.0:
		_pose_face_turn()

	# 방어 중이면 두 손을 몸 앞으로 올려 막는다 (다른 자세보다 나중이라 우선한다 —
	# 방어 중에는 이동·공격·스킬이 다 막히므로 실제로 겹칠 일도 거의 없다)
	# 쌍 악기(궁) 자세 — 서 있기·걷기·대시. 방어보다 **먼저** 섞는다(막는 자세가 이겨야 한다)
	if _dual_blend > 0.001:
		_pose_dual()
	if _guard_blend > 0.001:
		_pose_guard()

	# 박수 — 아이를 풀어놓고 신나서 손뼉을 친다 (방어보다 나중이지만 방어 중엔 애초에 안 켜진다)
	if _clap_blend > 0.001:
		_pose_clap()

	# 카운터 자세 — 단소를 앞 아래로 겨누고 한 손은 얼굴 옆, 상체를 숙인다 (방어 자세 다음이라 우선한다)
	if _counter_blend > 0.001:
		_pose_counter_stance()

	# 어깨 들이박기 — 두 손을 앞으로 모으고 몸·머리를 앞으로 기울인다 (방어 자세 다음이라 우선한다)
	if _charge_blend > 0.001:
		_pose_charge()

	# 무릎 꿇기(드롭킥 준비) — 앞발은 세우고 뒷발은 무릎을 땅에 대고 몸을 낮춘다
	if _kneel_blend > 0.001:
		_pose_kneel()

	# 망치질(고양이 집 짓기) — 무릎 꿇기가 내려놓은 오른손을 치켜들었다 내리친다
	if _hammer_blend > 0.001:
		_pose_hammer()

	# 두 손 번쩍 들기 / 다리 내려찍기 (황근출 내무반 스킬2)
	if _lift_blend > 0.001:
		_pose_lift()
	if _stomp_blend > 0.001:
		_pose_stomp()

	# 드롭킥 — 두 발을 모아 앞으로 뻗고 두 손은 뒤로 뺀다 (몸을 눕히는 건 맨 아래에서 한꺼번에)
	if _dk_blend > 0.001:
		_pose_dropkick()

	# 머리 부들부들 (악플러 열등감) — 다른 자세가 잡아놓은 머리 위에 떨림만 **더한다**.
	# 자세를 덮어쓰지 않고 더하기만 하므로 걷다가 써도, 공격 중에 써도 그대로 얹힌다
	if _head_shake_left > 0.0:
		_pose_head_shake()

	# 머리 조준 (일진 친구가 상대를 겨눌 때) — 위아래 각도만 더한다
	if not is_zero_approx(_head_aim) and _head:
		_head.rotation += _head_aim

	# 자전거를 타는 동안엔 두 발이 페달을 밟고, 두 손이 핸들바를 잡는다 (걷기 동작을 덮어쓴다)
	if _bike and _ride_blend > 0.3:
		_pose_pedal()
		_pose_ride_hands()

	# 스킬 클래시 대치 자세 — 다른 모든 동작보다 우선한다(클래시 중엔 다른 동작이 나올 일이 없다)
	if _clash_blend > 0.001:
		_pose_clash()

	# 착지 경직 — 무릎을 굽힌다(걷기·숨쉬기 위에 더한다)
	if _crouch_time > 0.0:
		_pose_land_crouch()

	# 피격 움찔 — 상체를 앞으로 숙이고 엉덩이를 뺀다(다른 자세 위에 더한다)
	if _flinch_time > 0.0:
		_pose_hit_flinch()

	# 방향 전환 중이면 손·발을 몸 가운데로 모았다가 벌린다(손에 든 물건이 복사해가기 전에)
	if _face_turn_time > 0.0:
		_pose_face_turn_limbs()

	# 대치 자세 — 위에서 잡힌 손 자세에 더하기만 한다(두 손 잡기 중엔 왼손은 오른손을 따라가므로 뺀다)
	if _stance_blend > 0.001:
		if _hand_r:
			_hand_r.position += stance_hand_r_offset * _stance_blend
			_hand_r.rotation += deg_to_rad(stance_hand_r_deg) * _stance_blend
		if _hand_l:
			var l: float = _stance_blend * (1.0 - _grip_blend)
			_hand_l.position += stance_hand_l_offset * l
			_hand_l.rotation += deg_to_rad(stance_hand_l_deg) * l

	# 키보드 선풍기 회전 — 두 손을 몸 앞에 모은다(회전은 아래 HandRHold에서 더한다)
	if _fan_time > 0.0:
		_pose_keyboard_fan()

	# 안고 있는 것(아이) — 보였다 숨었다 하고, 몸이 들썩이는 만큼 같이 들썩인다
	_pose_carry()
	# 영역전개 안에서 뛰는 동안은 엄마와 아이를 통째로 점프 자세로 덮는다
	_pose_domain_jump()
	# 헬스장에서 바벨을 들었다 놨다 하는 자세(운동 중에만 켜진다)
	_pose_curl()
	# 헬스장에서 어깨에 봉을 메고 앉았다 서는 자세
	_pose_squat()
	# 런닝머신 위에서 달리는 자세
	_pose_run()

	# 손에 든 물건이 손을 그대로 따라가게 한다
	# 왼손 물건걸이도 왼손을 그대로 따라간다(오른손 것과 같은 방식).
	# 보이고 안 보이고는 **매 프레임 확인한다** — 씬에 저장된 상태나 setter 순서에 안 휘둘린다
	if _hand_l_hold and _hand_l:
		_hand_l_hold.position = _hand_l.position
		_hand_l_hold.rotation = _hand_l.rotation
		# 던져서 손에 없는 동안은 안 보인다 — 손에도 있고 날아가기도 하면 두 개가 된다
		var show_l: bool = held_item_l_armed and not held_item_l_thrown
		for child in _hand_l_hold.get_children():
			if child is CanvasItem and child.visible != show_l:
				child.visible = show_l
		# 머리 앞으로 올렸다 되돌린다 — 위로 세운 리코더가 머리에 안 가리게
		_hand_l_hold.z_index = dual_hold_l_z if held_item_l_armed else _hand_l_hold_rest_z
		if _hand_l and _grip_blend <= 0.5:
			_hand_l.z_index = dual_hand_l_z if held_item_l_armed else _hand_l_rest_z
		# 오른손도 같은 규칙으로 올린다(두 손 잡기 중에는 아래 잡기 쪽이 z를 정하므로 건드리지 않는다)
		if _hand_r and _grip_blend <= 0.5:
			_hand_r.z_index = dual_hand_r_z if held_item_l_armed else _hand_r_rest_z
		# 쌍 악기를 든 동안엔 **치는 중에도** 단소를 머리 앞에 둔다 —
		# 손만 앞이고 단소는 뒤면 3타 X자에서 한 획이 머리에 잘린다.
		# 쌍 악기가 아닐 때는 예전 그대로(치는 중엔 안 건드린다)
		if _hand_r_hold and (_attack_time <= 0.0 or held_item_l_armed):
			_hand_r_hold.z_index = dual_hold_r_z if held_item_l_armed else _hand_r_hold_rest_z
	if _hand_r_hold and _hand_r:
		_hand_r_hold.position = _hand_r.position
		_hand_r_hold.rotation = _hand_r.rotation
		# 무기 스핀 타(악플러 3타) — 오른손 위치를 축으로 HandRHold를 통째로 돌린다.
		# HandRHold 원점 = 오른손이라, 자식 무기가 오른손 주위를 공전하며 한 바퀴 돈다(손·몸은 안 돎)
		if _attack_time > 0.0 and not _attack_pose_on and weapon_spin_hit >= 0 and _attack_variant == weapon_spin_hit:
			var sp: float = 1.0 - _attack_time / maxf(_attack_len, 0.001)
			_hand_r_hold.rotation += weapon_spin_dir * TAU * weapon_spin_turns * clampf(sp, 0.0, 1.0)
		# 선풍기 회전 — 손이 무기 중심을 잡고 그 자리에서 돌리는 느낌(봉 돌리기).
		# 무기 자식을 손(HandRHold 원점)으로 당겨 회전축=손 중심으로 만들고, 도는 동안 크기를 키운 뒤 HandRHold를 통째로 빠르게 돌린다
		if _fan_time > 0.0:
			for child in _hand_r_hold.get_children():
				if child is Sprite2D:
					child.position = Vector2.ZERO
					if _fan_child_scale.has(child):
						# 가로(x)만 키운다 — 키보드 긴 쪽만 늘어난다(세로는 원래대로)
						var s: Vector2 = _fan_child_scale[child]
						child.scale = Vector2(s.x * fan_weapon_scale, s.y)
			_hand_r_hold.rotation += _fan_phase
		if cast_hides_held_item or gun_hides_held_item:
			# 마우스를 던지거나 줄을 당기는 동안엔 손에 든 물건(악플러 키보드)이 마우스와 겹치고,
			# 총을 드는 동안엔 총과 겹친다(촉법소년 막대 사탕) — 그동안 숨긴다
			var hide_cast: bool = cast_hides_held_item and (_cast_time > 0.0 or _reel_blend > 0.001)
			var hide_gun: bool = gun_hides_held_item and _gun_time > 0.0
			# 던지기·되감기가 도는 중이라도 다른 동작이 자세를 가져갔으면 물건을 다시 보여준다.
			# 안 그러면 되감는 중에 기본공격을 했을 때 안 보이는 키보드를 휘두르는 꼴이 된다
			if _attack_time > 0.0 or _drink_time > 0.0 or _grab_time > 0.0:
				hide_cast = false
			_hand_r_hold.visible = not (hide_cast or hide_gun)
		# **운동하는 동안엔 양손에 든 물건을 숨긴다** — 키보드·막대사탕이 봉·원판과 겹쳐 보인다
		if _curl_blend > 0.001 or _squat_blend > 0.001 or _run_blend > 0.001:
			_hand_r_hold.visible = false
			if _hand_l_hold:
				_hand_l_hold.visible = false
		# 돌을 던지는 동안엔 **원래 들고 있던 물건(경봉)만** 숨긴다.
		# HandRHold 자체를 끄면 그 자식으로 붙인 돌까지 같이 사라지므로 자식별로 끄고 켠다
		var throwing: bool = throw_hides_held_item and _throw_time > 0.0
		if throwing or _held_hidden_by_throw:
			_held_hidden_by_throw = throwing
			for child in _hand_r_hold.get_children():
				if child != _throw_item:
					child.visible = not throwing
			if throwing:
				_hand_r_hold.visible = true
	# **무기를 들었다 넣었다 하는 캐릭터(경찰 경봉)는 여기서 그림을 켜고 끈다.**
	# 던지기 처리가 자식들을 다시 켜기 때문에 그 뒤에 둔다 — 순서를 바꾸면 돌을 던진 뒤 경봉이 되살아난다.
	# 던지는 중에는 던지기 쪽 판단을 그대로 둔다(던진 돌까지 건드리면 안 된다)
	if _hand_r_hold and weapon_switch and not _held_hidden_by_throw:
		for child in _hand_r_hold.get_children():
			if child != _throw_item:
				child.visible = held_item_armed

	# 클래시 주먹 러시 중엔 손에 든 물건을 숨긴다 — 잔상은 손만 복사하므로 물건만 덩그러니 따라다니면 어색하다
	if _hand_r_hold:
		if _clash_blend > 0.5:
			if _hand_r_hold.visible:
				_hand_r_hold.visible = false
				_hold_hidden_by_clash = true
		elif _hold_hidden_by_clash:
			_hand_r_hold.visible = true
			_hold_hidden_by_clash = false
	# 마지막 타에만 무기를 쥐는 캐릭터(일진 가방): 휘두르는 동안만 오른손 무기가 보이고,
	# 그 외에는 반대 손에 늘어뜨린 쪽이 보인다 — 위의 숨기기 규칙보다 이쪽이 우선한다
	if weapon_on_final_hit and _hand_r_hold:
		var swinging_final: bool = _attack_time > 0.0 and _attack_variant >= final_hit_index
		var weapon: Node = _hand_r_hold if weapon_node.is_empty() else get_node_or_null(weapon_node)
		if weapon is CanvasItem:
			weapon.visible = swinging_final
		var idle: Node = get_node_or_null(idle_weapon)
		if idle is CanvasItem:
			idle.visible = not swinging_final

	# 드롭킥: 위에서 잡아놓은 자세를 통째로 눕힌다. 손에 든 물건(HandRHold)이 손 위치를 이미 복사해간
	# 다음이라 여기서 같이 돌려야 사탕이 몸에서 떨어져 나가지 않는다
	if absf(_dk_angle) > 0.0001 or _dk_shift.length_squared() > 0.0001:
		_lay_down(_dk_angle, _dk_shift)

	# 점프/착지 스쿼시를 루트 크기에 반영한다 (몸 전체가 늘거나 눌린다). 좌우 방향(scale.x 부호)은 유지한다
	if _squashing:
		var sgn: float = signf(_fighter.facing) if (_fighter != null and is_instance_valid(_fighter)) else 1.0
		if _squash.is_equal_approx(Vector2.ONE):
			scale = Vector2(sgn, 1.0)   # 정확히 원래 크기로 스냅하고 종료
			_squashing = false
		else:
			scale = Vector2(_squash.x * sgn, _squash.y)
	# 발바닥(squash_pivot_y)이 제자리에 남게 리그를 위아래로 보정한다 — 위치를 통째로 덮지 않고
	# 지난번에 더한 만큼 빼고 새로 더한다(수플렉스처럼 리그 위치를 잠깐 쓰는 스킬과 안 싸우게)
	var lift: float = squash_pivot_y * (1.0 - scale.y) if _squashing else 0.0
	lift -= ride_lift * _ride_blend
	if not is_equal_approx(lift, _squash_lift):
		position.y += lift - _squash_lift
		_squash_lift = lift

	_apply_spin_turn()

## 한 바퀴 돌면서 치기 — 그 타 시작부터 spin_end까지 가로 크기를 cos 한 바퀴로 곱한다.
## 1 -> 0(옆모습) -> -1(등) -> 0 -> 1(다시 앞). **손/발은 앞으로 돌아오는 도중(spin_strike) 들어가고 회전은 그대로 이어진다** — "돌고 나서"가 아니라 "돌면서" 때린다.
## 곱하기 전 값을 기억해 두고 다음 프레임 _apply_pose 첫머리에서 되돌린다 —
## 안 그러면 _face_moving_direction이 absf(scale.x)로 크기를 읽어 얇아진 몸을 원래 크기로 굳혀버린다
func _apply_spin_turn() -> void:
	if not _spin_now or _attack_time <= 0.0:
		return
	var progress: float = 1.0 - _attack_time / maxf(_attack_len, 0.001)
	var s_end: float = maxf(spin_end, 0.01)
	if progress >= s_end:
		return
	# **일정한 속도로 돈다** — 중간에 느려지면 "돌고 멈췄다가 때린다"로 보인다. 손/발은 이 회전 도중(spin_strike)에 들어간다
	var p: float = progress / s_end
	if spin_uses_head_turn and _can_head_turn():
		_apply_spin_head_turn(p)
		return
	var turn: float = cos(p * TAU)
	# 정확히 0이면 몸 크기가 0이 돼 자식 변환이 깨진다 — 아주 얇게만 남긴다
	if absf(turn) < 0.04:
		turn = 0.04 if turn >= 0.0 else -0.04
	_spin_base_x = scale.x
	scale.x = _spin_base_x * turn
	_spin_applied = true

## 머리 그림으로 한 바퀴 돌기(p = 한 바퀴 진행도 0~1).
## 0 ~ 0.5: 머리가 측면1 -> ... -> 정면 -> ... -> 옆모습(방향 전환과 같은 길), 0.25(머리 정면)에 몸이 뒤집힌다
## 0.5 ~ : 머리는 옆모습 그대로(뒤통수 그림이 없다), spin_back_flip에 몸이 다시 앞으로 뒤집힌다
## 몸 뒤집기는 가로 부호만 바꾸고 다음 프레임 첫머리에서 되돌린다(얇게 누르던 예전 방식과 같은 장치)
func _apply_spin_head_turn(p: float) -> void:
	var back_flip: float = clampf(spin_back_flip, 0.5, 0.99)
	var mirrored: bool = p >= 0.25 and p < back_flip
	if p < 0.5:
		var front: int = _turn_textures().size()
		var shown: int = front * 2
		var step: int = clampi(int(p / 0.5 * shown), 0, shown - 1)
		_set_head_frame(step + 1 if step < front else shown - 1 - step, 1.0)
	elif head_back_texture != null and head_back_anchor.z > 0.0 and absf(p - back_flip) < spin_back_show:
		# 몸이 다시 앞으로 뒤집히는 순간 앞뒤로 뒤통수를 보인다 — 옆 -> 뒤통수 -> 옆
		_set_head_image(head_back_texture, head_back_anchor, false, 1.0)
	else:
		_clear_head_frame()
	# 뒤집히는 두 순간(0.25, back_flip) 앞뒤로 손·발을 가운데로 모은다 — 사탕(HandRHold)은 이미 손을 복사해 갔으니 같이 모은다
	var width: float = maxf(spin_gather_width, 0.001)
	var gather: float = maxf(1.0 - absf(p - 0.25) / width, 1.0 - absf(p - back_flip) / width)
	if gather > 0.0:
		var squeeze: float = 1.0 - face_turn_limb_gather * gather
		for part in [_hand_l, _hand_r, _hand_r_hold, _foot_l, _foot_r]:
			if part:
				part.position.x *= squeeze
	if mirrored:
		_spin_base_x = scale.x
		scale.x = -_spin_base_x
		_spin_applied = true

## 발 하나의 자세를 잡는다.
## lift는 발끝을 드는 정도(0~1), slide는 제자리에서 앞뒤로 얼마나 나가 있는지(-1~1)
## raise: 앞으로 옮겨지는 중인 정도(0~1) — foot_step_lift만큼 발을 들어 올린다
func _pose_foot(foot: Sprite2D, lift: float, slide: float, raise: float = 0.0) -> void:
	if foot == null:
		return
	# 걷기는 발끝이 위로 들리게(각도 양수 = 시계 방향이라 부호를 뒤집는다),
	# 점프는 반대로 발끝이 아래로 뻗게 해서 서로 반대 방향으로 돈다
	foot.rotation = deg_to_rad(-foot_swing_deg * lift + jump_foot_deg * _air_blend)
	foot.position.x = _rest_positions[foot].x + foot_stride * slide
	# 세로 위치는 항상 제자리로 되돌린다 — 페달 동작(자전거)이 바꿔놓은 발 Y가 돌진 후에 남지 않게
	foot.position.y = _rest_positions[foot].y - foot_step_lift * raise

## 콤보가 앞으로 파고드는 동안 발을 내딛는다 — duration은 파고드는 시간과 같게 준다
## lead: 앞쪽 이 비율 동안은 발만 먼저 나가고 몸은 그 뒤에 따라온다(ComboMeleeAttack의 이동 곡선과 같은 값을 준다)
func play_lunge_step(duration: float, lead: float = 0.0) -> void:
	_step_len = maxf(duration, 0.01)
	_step_time = _step_len
	_step_lead = clampf(lead, 0.0, 0.6)

## 내딛기 자세 — 몸은 이미 앞으로 미끄러지고 있으니 발은 "먼저 나갔다가(앞발) 뒤에 남았다가 따라붙는(뒷발)" 모양만 잡는다.
## 앞발(오른발)은 앞쪽 70% 동안 들려서 앞으로 뻗었다 내려앉고, 뒷발(왼발)은 뒤에 끌리다가 뒤쪽 60% 동안 들려 따라온다
func _pose_lunge_step() -> void:
	var t: float = 1.0 - _step_time / _step_len
	if _step_lead > 0.0:
		_pose_lead_step(t)
		return
	var front: float = sin(PI * clampf(t / 0.7, 0.0, 1.0))
	var back_lift: float = sin(PI * clampf((t - 0.4) / 0.6, 0.0, 1.0))
	var back_drag: float = sin(PI * t)
	if _foot_r:
		_foot_r.position = _rest_positions[_foot_r] + Vector2(lunge_step_foot * front, -lunge_step_lift * front)
		_foot_r.rotation = deg_to_rad(-18.0) * front
	if _foot_l:
		_foot_l.position = _rest_positions[_foot_l] + Vector2(-lunge_step_foot * 0.8 * back_drag, -lunge_step_lift * 0.6 * back_lift)
		_foot_l.rotation = deg_to_rad(12.0) * back_drag

## 발 먼저, 몸이 따라감 — ① lead 동안 앞발이 들려 앞으로 뻗고(몸은 제자리) ② 몸이 미끄러져 오는 만큼
## 앞발은 몸 아래로 되돌아온다(발이 땅에 붙어 있는 것처럼 보인다) ③ 뒷발은 제자리에 남아 뒤로 벌어졌다가 끝에 들려 따라붙는다
func _pose_lead_step(t: float) -> void:
	var reach_end: float = maxf(_step_lead, 0.15)
	var reach: float = smoothstep(0.0, reach_end, t)
	var s: float = clampf((t - _step_lead) / (1.0 - _step_lead), 0.0, 1.0)
	var body: float = s * s * (3.0 - 2.0 * s)   # 몸이 간 비율 — 이동 곡선(smoothstep)의 위치와 같다
	var front: float = reach * (1.0 - body)
	var front_lift: float = sin(PI * clampf(t / reach_end, 0.0, 1.0))
	var catch_up: float = smoothstep(0.75, 1.0, t)
	var back: float = body * (1.0 - catch_up)
	var back_lift: float = sin(PI * clampf((t - 0.75) / 0.25, 0.0, 1.0))
	if _foot_r:
		_foot_r.position = _rest_positions[_foot_r] + Vector2(lunge_step_foot * front, -lunge_step_lift * front_lift)
		_foot_r.rotation = deg_to_rad(-18.0) * front
	if _foot_l:
		_foot_l.position = _rest_positions[_foot_l] + Vector2(-lunge_step_foot * 0.8 * back, -lunge_step_lift * 0.6 * back_lift)
		_foot_l.rotation = deg_to_rad(12.0) * back

## 기본공격 스윙 — 오른손(과 손에 든 물건)을 뒤로 살짝 젖혔다가 앞으로 획 휘두르고 돌아온다.
## Fighter가 기본공격을 실제로 발동시킨 순간 호출한다
## duration: 이 타의 모션 길이(초). 0 이하면 리그 설정값(attack_duration / kick_duration / spin_duration)을 쓴다.
## spin: 켜면 이 타는 한 바퀴 돌면서 친다. 꺼져 있어도 spin_hit_index 번째 타면 돈다(옛 방식)
## --- 검사처럼 긋는 베기 (경찰 경관봉 난무, 2026-10-01 "모션 좀 맛있게") ---
## 평범한 내려찍기를 반복하면 "툭툭 친다"로 보인다. 베는 방향을 돌아가며 바꿔야 칼싸움처럼 보여서
## 궤도가 다른 베기를 차례로 돌려 쓴다. **각도 부호는 스윙과 같다** — 감을 땐 `-raise_deg`,
## 후릴 땐 `+swing_deg`(음수 = 반시계 = 무기가 위로 / 양수 = 시계 = 아래로).
## `arc`는 손이 지나는 길이 바깥으로 휘는 정도, `slash_deg`는 그 베기의 **참격 자국 기울기**(도)다.
## 값을 바꾸고 싶으면 이 표만 고치면 된다 — 칸을 더 넣으면 그만큼 돌아가며 나온다
const SLASHES := [
	# ① 내려찍기 ↓ — **머리 위로 두 손으로 넘겼다가 앞 아래로 강하게 내려친다**(2026-10-01 사용자 그림).
	# 감았을 때 경봉이 뒤로 수평(그림 1프레임), 내려쳤을 때 앞 아래를 향한다(그림 2프레임).
	# 경봉 그림은 손에서 -38도(앞 위쪽)를 보고 있어서, 손 각도 = 원하는 각도 + 38이 된다
	{"raise_deg": 142.0, "swing_deg": 98.0, "raise_off": Vector2(-18, -66), "slam_off": Vector2(12, 18), "arc": 26.0, "slash_deg": 40.0, "lean_deg": 18.0},
	# ② 올려베기 ↗ — 아래 뒤로 감았다가 앞 위로 쳐올린다(각도 부호가 ①의 반대)
	{"raise_deg": -74.0, "swing_deg": -104.0, "raise_off": Vector2(-16, 30), "slam_off": Vector2(44, -36), "arc": -20.0, "slash_deg": -30.0, "lean_deg": -12.0},
	# ③ 수평 베기 → — 허리에서 앞으로 쭉 긋는다. 호 없이 곧게 지나간다
	{"raise_deg": 54.0, "swing_deg": 66.0, "raise_off": Vector2(-36, -2), "slam_off": Vector2(50, -6), "arc": 0.0, "slash_deg": 86.0, "lean_deg": 10.0},
	# ④ 역사선 ↙ — 바깥 위에서 안쪽 아래로 짧고 빠르게 긋는다
	{"raise_deg": 96.0, "swing_deg": 86.0, "raise_off": Vector2(14, -36), "slam_off": Vector2(34, 18), "arc": -14.0, "slash_deg": 54.0, "lean_deg": 13.0},
]
## 베기 번호를 `_attack_variant`에 담을 때 더하는 값 — 평소 콤보 타 번호(0·1·2…)와 섞이지 않게 멀리 띄운다
const SLASH_VARIANT_BASE := 100

## 베기 전체 크기 배수 — 한 번에 키우거나 줄이고 싶을 때
@export var slash_scale: float = 1.0
## 베는 동안 **무기와 두 손을 머리보다 앞으로** 올리는 z. 머리 위로 넘기는 동작은 이게 없으면
## 머리 그림에 가려 경봉이 통째로 사라진다(리그 순서가 …손 → 머리라서). 손이 무기보다 앞이다
@export var slash_weapon_z: int = 2
@export var slash_hand_z: int = 3
## 벨 때 상체가 따라 넘어가는 정도의 배수. 0이면 몸은 가만히 있고 손만 움직인다(밋밋해진다)
@export var slash_lean_scale: float = 1.0

## 베는 동안 손·무기 z를 올렸다 되돌린다
func _apply_slash_z(on: bool) -> void:
	if _hand_r_hold:
		_hand_r_hold.z_index = slash_weapon_z if on else _hand_r_hold_rest_z
	if _hand_r:
		_hand_r.z_index = slash_hand_z if on else _hand_r_rest_z
	if _hand_l and on:
		_hand_l.z_index = slash_hand_z

## 베기 한 번. index는 위 SLASHES 차례(넘치면 처음으로 돌아간다)
func play_weapon_slash(index: int, duration: float = -1.0) -> void:
	play_attack_swing(SLASH_VARIANT_BASE + (index % SLASHES.size()), duration)

## 이번 베기의 참격 자국 기울기(라디안) — 자국을 뿌리는 쪽이 물어본다
static func slash_angle(index: int) -> float:
	return deg_to_rad(float(SLASHES[index % SLASHES.size()]["slash_deg"]))

func play_attack_swing(variant: int = 0, duration: float = -1.0, spin: bool = false) -> void:
	_attack_len = attack_duration
	if attack_kick_hit >= 0 and variant == attack_kick_hit and kick_duration > 0.0:
		_attack_len = kick_duration
	if spin_hit_index >= 0 and variant == spin_hit_index and spin_duration > 0.0:
		_attack_len = spin_duration
	if duration > 0.0:
		_attack_len = duration
	_spin_now = spin or (spin_hit_index >= 0 and variant == spin_hit_index)
	_attack_time = _attack_len
	_attack_variant = variant
	_swing_serial += 1
	if _hand_r and _rest_positions.has(_hand_r):
		# 대치 자세는 공격 자세 위에 따로 더해지므로 출발 자세에서는 빼 둔다 — 안 빼면 두 번 더해져 손이 튄다
		_swing_from_off = _hand_r.position - _rest_positions[_hand_r] - stance_hand_r_offset * _stance_blend
		_swing_from_deg = rad_to_deg(_hand_r.rotation) - stance_hand_r_deg * _stance_blend

## 이 모션으로 휘두르면 **시작부터 몇 초 뒤에 맞는지** — 콤보가 판정을 켤 시각이다(AttackData는 이 값을 따른다).
## 보통 타는 내리치기 시작 지점(40%), 회전 타는 회전 도중 후려치는 지점(spin_end x spin_strike).
## 판정 시각을 따로 적어두지 않고 여기서 계산하므로, 모션 길이를 바꿔도 모션과 판정이 어긋나지 않는다
func strike_time(duration: float, spin: bool = false) -> float:
	var length: float = duration if duration > 0.0 else attack_duration
	if spin:
		return length * spin_end * spin_strike
	return length * ATTACK_STRIKE_START

## 예비동작이 끝나고 실제로 내리치기 시작하는 시점 (전체 시간 대비 비율)
const ATTACK_STRIKE_START: float = 0.4
## 내리치기가 끝나는 시점 — 이 뒤로는 원래 자세로 돌아온다
const ATTACK_STRIKE_END: float = 0.62

## 스윙 진행도에 따라 오른손의 각도와 위치를 잡는다 (걷기 동작보다 우선한다).
## 각도는 음수가 반시계 방향(무기가 위로 올라감), 양수가 시계 방향(아래로 내리침)이다
## 이번 타를 **어느 손으로** 치는지 — 맨손이면 **왼-오-왼**으로 번갈아 친다.
## 마무리(어퍼컷)도 **뒤쪽(왼쪽) 손**이다(2026-09-30 사용자 지정) —
## 앞손으로 치면 손이 이미 앞에 있어서 올라오는 궤도가 안 보이고, 뒷손이라야 크게 휘어 올라온다
func _attack_hand() -> Sprite2D:
	if unarmed_alternate_hands and unarmed_thrust and not held_item_armed and _hand_l:
		if _attack_variant % 2 == 0:
			return _hand_l
	return _hand_r

## 치는 손의 반대 손(가드를 잡는 손)
func _guard_hand() -> Sprite2D:
	return _hand_r if _attack_hand() == _hand_l else _hand_l

func _blend_jab_guard(hand: Sprite2D, blend: float) -> void:
	if blend <= 0.001 or hand == null or not _rest_positions.has(hand):
		return
	var w: float = smoothstep(0.0, 1.0, blend)
	hand.position = hand.position.lerp(_rest_positions[hand] + unarmed_guard_offset, w)
	hand.rotation = lerp_angle(hand.rotation, deg_to_rad(unarmed_guard_deg), w)

func _pose_attack_hand() -> void:
	var progress: float = 1.0 - _attack_time / maxf(_attack_len, 0.001)
	# 타별로 감는 각도·내려치는 각도·손 이동 경로가 달라진다 (콤보 1·2·3타 스윙 변주)
	var v: Dictionary = _attack_variant_params()
	var raise_deg: float = v["raise_deg"]
	var swing_deg: float = v["swing_deg"]
	var raise_off: Vector2 = v["raise_off"]
	var slam_off: Vector2 = v["slam_off"]
	# 타별로 호(arc)를 다르게 줄 수 있다 — 안 담겨 있으면 씬 export(attack_swing_arc)를 쓴다(기존 동작 유지)
	var arc: float = v.get("arc", attack_swing_arc)
	var angle: float
	var offset: Vector2
	if attack_snap:
		_snap_attack_pose(progress, raise_deg, swing_deg, raise_off, slam_off, arc)
		return
	if progress < ATTACK_STRIKE_START:
		# ① 예비동작 — 손을 감는다 (끝으로 갈수록 느려지게)
		var p: float = 1.0 - (1.0 - progress / ATTACK_STRIKE_START) * (1.0 - progress / ATTACK_STRIKE_START)
		angle = lerpf(0.0, -raise_deg, p)
		offset = Vector2.ZERO.lerp(raise_off, p)
	elif progress < ATTACK_STRIKE_END:
		# ② 빠르게 후려친다 (실제로 때리는 구간)
		var p: float = (progress - ATTACK_STRIKE_START) / (ATTACK_STRIKE_END - ATTACK_STRIKE_START)
		angle = lerpf(-raise_deg, swing_deg, p * p)
		offset = raise_off.lerp(slam_off, p * p) + _swing_arc(p * p, raise_off, slam_off, arc)
	else:
		# ③ 원래 자세로 복귀
		var p: float = (progress - ATTACK_STRIKE_END) / (1.0 - ATTACK_STRIKE_END)
		angle = lerpf(swing_deg, 0.0, p)
		offset = slam_off.lerp(Vector2.ZERO, p)
	var hand: Sprite2D = _attack_hand()
	if hand and _rest_positions.has(hand):
		hand.rotation = deg_to_rad(angle)
		hand.position = _rest_positions[hand] + offset
	# 두 손 잡기는 스윙이 끝난 뒤에도 블렌드가 남아 있어야 하므로 _apply_pose에서 따로 부른다

## 격투게임식 끊어 치기(attack_snap) — 구간 나누는 지점(40% / 62%)은 원래 스윙과 같고, 구간 안의 흐름만 다르다.
## ① 감기: 앞 snap_windup_reach 안에 감기 자세 완성 -> 나머지는 멈칫
## ② 후려치기: 앞 snap_strike_reach 안에 다 뻗음(감속 곡선이라 확 튀어나가 탁 멈춘다) -> 나머지는 뻗은 채
## ③ 복귀: snap_recovery_hold 동안 뻗은 자세로 버티다가 남은 시간에 제자리로 툭
func _snap_attack_pose(progress: float, raise_deg: float, swing_deg: float, raise_off: Vector2, slam_off: Vector2, arc: float) -> void:
	var angle: float
	var offset: Vector2
	if progress < ATTACK_STRIKE_START:
		var t: float = clampf(progress / ATTACK_STRIKE_START / maxf(snap_windup_reach, 0.01), 0.0, 1.0)
		var p: float = 1.0 - (1.0 - t) * (1.0 - t)
		# 앞 타가 뻗은 자리에서 출발한다 — 제자리에서 출발하면 연타할 때 손이 툭 튄다
		angle = lerpf(_swing_from_deg, -raise_deg, p)
		offset = _swing_from_off.lerp(raise_off, p)
	elif progress < ATTACK_STRIKE_END:
		var t: float = clampf((progress - ATTACK_STRIKE_START) / (ATTACK_STRIKE_END - ATTACK_STRIKE_START) / maxf(snap_strike_reach, 0.01), 0.0, 1.0)
		var p: float = 1.0 - pow(1.0 - t, 3.0)
		angle = lerpf(-raise_deg, swing_deg, p)
		offset = raise_off.lerp(slam_off, p) + _swing_arc(p, raise_off, slam_off, arc)
	else:
		var q: float = (progress - ATTACK_STRIKE_END) / (1.0 - ATTACK_STRIKE_END)
		var t: float = clampf((q - snap_recovery_hold) / maxf(1.0 - snap_recovery_hold, 0.01), 0.0, 1.0)
		var p: float = t * t * (3.0 - 2.0 * t)
		angle = lerpf(swing_deg, 0.0, p)
		offset = slam_off.lerp(Vector2.ZERO, p)
	var hand: Sprite2D = _attack_hand()
	if hand and _rest_positions.has(hand):
		hand.rotation = deg_to_rad(angle)
		hand.position = _rest_positions[hand] + offset

## 착지 경직 자세를 duration초 동안 잡는다 — Fighter가 높은 데서 떨어져 착지한 순간 부른다
## 0 이하를 주면 자세를 그 자리에서 푼다
func play_land_crouch(duration: float) -> void:
	if duration <= 0.0:
		_crouch_time = 0.0
		return
	_crouch_len = duration
	_crouch_time = _crouch_len

## 굽힌 정도: 착지 순간 확 주저앉고(앞 12%) -> 버티다가 -> 끝 35% 동안 일어난다
func _land_crouch_amount() -> float:
	var progress: float = 1.0 - _crouch_time / _crouch_len
	if progress < 0.12:
		var t: float = progress / 0.12
		return 1.0 - (1.0 - t) * (1.0 - t)
	if progress < 0.65:
		return 1.0
	var t2: float = (progress - 0.65) / 0.35
	return 1.0 - t2 * t2 * (3.0 - 2.0 * t2)

## 몸통·머리·손을 발 쪽으로 내린다. 발은 바닥에 붙어 있어야 하므로 안 건드린다
func _pose_land_crouch() -> void:
	var k: float = _land_crouch_amount()
	var down: float = land_crouch_depth * k
	if _body:
		_body.position.y += down
	if _head:
		_head.position.y += down
		_head.rotation += deg_to_rad(land_crouch_head_deg) * k
	if _hand_r:
		_hand_r.position.y += down * 0.85
	if _hand_l:
		_hand_l.position.y += down * 0.85

## 맞은 순간 움찔 자세를 시작한다. power(0~1)가 클수록 크게 숙인다 — Fighter가 데미지로 정해 넘긴다.
## 이미 움찔하는 중에 또 맞으면 처음부터 다시(연타를 맞을 때마다 다시 꺾인다)
## push_dir: 그림이 밀리는 쪽(리그 로컬 x 부호) — -1이 뒤(바라보는 반대쪽), +1이 앞(등 뒤에서 맞았을 때)
func play_hit_flinch(power: float = 1.0, push_dir: float = -1.0) -> void:
	_flinch_len = maxf(hit_flinch_duration, 0.01)
	_flinch_time = _flinch_len
	_flinch_power = clampf(power, 0.0, 1.0)
	_flinch_push_dir = -1.0 if push_dir < 0.0 else 1.0

## 숙인 정도: 앞 15%에 확 숙이고 -> 40%까지 버티고 -> 나머지 동안 부드럽게 펴진다
func _hit_flinch_amount() -> float:
	var progress: float = 1.0 - _flinch_time / _flinch_len
	var k: float
	if progress < 0.15:
		var t: float = progress / 0.15
		k = 1.0 - (1.0 - t) * (1.0 - t)
	elif progress < 0.4:
		k = 1.0
	else:
		var t2: float = (progress - 0.4) / 0.6
		k = 1.0 - t2 * t2 * (3.0 - 2.0 * t2)
	return k * _flinch_power

func _pose_hit_flinch() -> void:
	var k: float = _hit_flinch_amount()
	if _body:
		_body.position.x -= hit_flinch_hip_back * k
		_body.rotation += deg_to_rad(hit_flinch_lean_deg) * k
	if _head:
		_head.position += hit_flinch_head_offset * k
		_head.rotation += deg_to_rad(hit_flinch_head_deg) * k
	if _hand_r:
		_hand_r.position += hit_flinch_hand_r_offset * k
	if _hand_l:
		_hand_l.position += hit_flinch_hand_l_offset * k
	# 발도 손처럼 꺾인다 — 발끝이 아래로 떨어지고 엉덩이를 따라 뒤로 빠진다
	for foot in [_foot_l, _foot_r]:
		if foot:
			foot.rotation += deg_to_rad(hit_flinch_foot_deg) * k
			foot.position.x -= hit_flinch_foot_back * k
	# 잠깐 떠오르기 — 숙이는 곡선과 따로, 앞 60% 동안 sin 반주기로 떴다 내려앉는다
	var progress: float = 1.0 - _flinch_time / _flinch_len
	var lift: float = hit_flinch_hop * _flinch_power * sin(PI * clampf(progress / 0.6, 0.0, 1.0))
	# 밀려나기 — 숙이는 곡선(k)과 같은 박자라 확 밀렸다가 버티고 돌아온다. k에 이미 세기가 곱해져 있다
	var push: float = hit_flinch_push * k * _flinch_push_dir
	if lift > 0.001 or absf(push) > 0.001:
		for part in [_body, _head, _hand_r, _hand_l, _foot_l, _foot_r]:
			if part:
				part.position += Vector2(push, -lift)

## 잔상을 남길 구간인지 — 후려치는 동안(끊어 치기면 다 뻗을 때까지)만 남긴다
func _smear_window() -> bool:
	if _attack_time <= 0.0:
		return false
	# 발차기 타는 손이 균형만 잡으므로 잔상을 안 남긴다
	if attack_kick_hit >= 0 and _attack_variant == attack_kick_hit:
		return false
	var progress: float = 1.0 - _attack_time / maxf(_attack_len, 0.001)
	var end: float = ATTACK_STRIKE_END
	if attack_snap:
		end = ATTACK_STRIKE_START + (ATTACK_STRIKE_END - ATTACK_STRIKE_START) * snap_strike_reach
	# 한 프레임 여유 — 다 뻗는 순간의 자세까지 잔상에 들어가야 궤적이 끝까지 이어진다
	return progress >= ATTACK_STRIKE_START and progress <= end + 0.06

## 잔상의 원본 — 오른손 + 손에 든 물건 중 보이는 스프라이트
func _smear_sources() -> Array[Sprite2D]:
	var list: Array[Sprite2D] = []
	if _hand_r and _hand_r.visible:
		list.append(_hand_r)
	if _hand_r_hold and _hand_r_hold.visible:
		for child in _hand_r_hold.get_children():
			if child is Sprite2D and child.visible:
				list.append(child)
	return list

## 매 프레임: 남아 있는 잔상을 흐리게 하고, 후려치는 중이면 새 잔상을 남긴다.
## 자세 계산(_apply_pose)이 끝난 뒤에 불러야 이번 프레임 손 자리를 찍는다
func _update_smear(delta: float) -> void:
	for i in _smears.size():
		if _smear_left[i] <= 0.0:
			continue
		_smear_left[i] -= delta
		if _smear_left[i] <= 0.0:
			_smears[i].visible = false
		else:
			_smears[i].modulate.a = smear_alpha * (_smear_left[i] / maxf(smear_life, 0.001))
	if not attack_smear or not _smear_window():
		_smear_prev.clear()
		return
	var rig_xf: Transform2D = get_global_transform()
	var rig_inv: Transform2D = rig_xf.affine_inverse()
	for src in _smear_sources():
		# 리그 기준 변환으로 저장·보간한다 — 월드 변환은 왼쪽을 볼 때 배율이 음수라 보간하면 뒤집힐 수 있다
		var now: Transform2D = rig_inv * src.get_global_transform()
		if _smear_prev.has(src):
			var prev: Transform2D = _smear_prev[src]
			for k in range(1, smear_fill + 1):
				var w: float = float(k) / float(smear_fill + 1)
				# 앞(오래된) 쪽일수록 조금 더 빨리 사라지게 해서 끝이 가늘어지는 꼬리가 된다
				_spawn_smear(src, rig_xf * prev.interpolate_with(now, w), 0.7 + 0.3 * w)
		_spawn_smear(src, rig_xf * now, 1.0)
		_smear_prev[src] = now

## 잔상 하나를 월드 변환 xf 자리에 남긴다 — 가장 오래된 칸을 재활용한다
func _spawn_smear(src: Sprite2D, xf: Transform2D, life_ratio: float) -> void:
	if _smears.is_empty():
		_build_smears()
	var idx: int = 0
	for i in _smear_left.size():
		if _smear_left[i] < _smear_left[idx]:
			idx = i
	var g: Sprite2D = _smears[idx]
	g.texture = src.texture
	g.centered = src.centered
	g.offset = src.offset
	g.flip_h = src.flip_h
	g.flip_v = src.flip_v
	g.region_enabled = src.region_enabled
	g.region_rect = src.region_rect
	g.z_index = src.z_index
	g.global_transform = xf
	_smear_left[idx] = smear_life * life_ratio
	g.modulate.a = smear_alpha * life_ratio
	g.visible = true

## 잔상 칸을 만든다. top_level이라 리그가 움직여도 그 자리에 남고,
## 오른손·손에 든 물건보다 앞 순서에 끼워 진짜 손·무기 뒤에 그려진다. owner를 안 줘서 씬에 저장되지 않는다
func _build_smears() -> void:
	var at: int = get_child_count()
	if _hand_r:
		at = mini(at, _hand_r.get_index())
	if _hand_r_hold:
		at = mini(at, _hand_r_hold.get_index())
	for i in 48:
		var g := Sprite2D.new()
		g.top_level = true
		g.visible = false
		add_child(g)
		move_child(g, at + i)
		_smears.append(g)
		_smear_left.append(0.0)

## 평타 하얀 궤적을 켠다 — ComboMeleeAttack이 play_attack_swing/play_weapon_slash **바로 다음에** 부른다.
## 예비동작 동안은 기다렸다가 후려치는 구간에만 긋는다(_update_swing_trail)
## 캐릭터가 아닌 몸(악플러집 엄마 등)도 휘두를 때 직접 부르면 된다
func play_swing_trail() -> void:
	if not swing_trail or _swing_trail_body() == null:
		return
	_end_swing_trail()
	_trail_serial = _swing_serial

## 이 리그를 Visual로 쓰는 몸 — 캐릭터면 그 캐릭터, 아니면(맵 기믹 엄마 등) 리그의 부모
func _swing_trail_body() -> Node2D:
	if _fighter != null and is_instance_valid(_fighter):
		return _fighter
	return get_parent() as Node2D

## 궤적을 그을 구간인지 — 잔상(_smear_window)과 같은 후려치는 구간. 회전 타는 몸이 돌며 후려치는 동안
func _swing_trail_window() -> bool:
	if _attack_time <= 0.0:
		return false
	var progress: float = 1.0 - _attack_time / maxf(_attack_len, 0.001)
	if _spin_now:
		return progress >= spin_end * 0.45 and progress <= spin_end + 0.06
	var end: float = ATTACK_STRIKE_END
	if attack_snap:
		end = ATTACK_STRIKE_START + (ATTACK_STRIKE_END - ATTACK_STRIKE_START) * snap_strike_reach
	return progress >= ATTACK_STRIKE_START and progress <= end + 0.06

## 궤적이 따라갈 조각과 그 조각 안의 끝점(조각 로컬 좌표)을 고른다.
## 발차기·드롭킥 = 오른발 가운데 / 무기를 든 손으로 치면 = 무기 그림에서 손잡이(손)에서 가장 먼 모서리 / 맨손 = 치는 주먹 가운데
func _pick_swing_trail_source() -> void:
	_trail_src = null
	var kick: bool = (attack_kick_hit >= 0 and _attack_variant == attack_kick_hit) or _dk_blend > 0.001
	if kick and _foot_r:
		_trail_src = _foot_r
		_trail_tip = _foot_r.get_rect().get_center()
		return
	var hand: Sprite2D = _attack_hand()
	if hand == _hand_r and _hand_r_hold and _hand_r_hold.visible:
		# 손에 든 그림 중 가장 큰 것(무기 본체)
		var item: Sprite2D = null
		var best: float = 0.0
		for child in _hand_r_hold.get_children():
			if child is Sprite2D and child.visible and child.texture:
				var area: float = child.get_rect().get_area() * absf(child.scale.x * child.scale.y)
				if area > best:
					best = area
					item = child
		if item:
			_trail_src = item
			_trail_tip = _far_corner_from_grip(item)
			return
	if hand:
		_trail_src = hand
		_trail_tip = hand.get_rect().get_center()

## 무기 그림에서 **보이는 영역**의 네 모서리 중 손잡이(HandRHold 원점)에서 가장 먼 곳 — 무기 끝으로 쓴다(그림 로컬 좌표)
func _far_corner_from_grip(item: Sprite2D) -> Vector2:
	var rect: Rect2 = item.get_rect()
	if not item.region_enabled:
		var opaque: Rect2 = _opaque_rect_of(item.texture)
		var tex_size: Vector2 = item.texture.get_size()
		var x: float = tex_size.x - opaque.end.x if item.flip_h else opaque.position.x
		var y: float = tex_size.y - opaque.end.y if item.flip_v else opaque.position.y
		rect = Rect2(rect.position + Vector2(x, y), opaque.size)
	var grip: Vector2 = item.transform.affine_inverse() * Vector2.ZERO
	var best := rect.position
	for c in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		if c.distance_squared_to(grip) > best.distance_squared_to(grip):
			best = c
	return best

## 매 프레임(자세 계산 뒤): 후려치는 구간이면 끝점 자리를 띠에 더한다. 다음 타가 나가거나 구간이 끝나면 띠를 놓는다
func _update_swing_trail() -> void:
	if _trail_serial < 0:
		return
	if _trail_serial != _swing_serial or _attack_time <= 0.0:
		_end_swing_trail()
		return
	if not _swing_trail_window():
		# 예비동작 중이면 기다리고, 이미 긋고 있었으면(구간이 끝났으면) 놓는다
		if _swing_trail_node != null:
			_end_swing_trail()
		return
	if _swing_trail_node == null:
		var body: Node2D = _swing_trail_body()
		var map: Node = body.get_parent() if body != null else null
		if map == null:
			_end_swing_trail()
			return
		_pick_swing_trail_source()
		if _trail_src == null:
			_end_swing_trail()
			return
		var trail = SWING_TRAIL_SCRIPT.new()
		map.add_child(trail)
		# 캐릭터 뒤, 배경 앞 — z는 캐릭터와 같게, 트리 순서만 캐릭터 바로 앞(대시 잔상과 같은 방식)
		trail.z_index = body.z_index
		map.move_child(trail, body.get_index())
		_swing_trail_node = trail
		_trail_has_prev = false
	if not is_instance_valid(_trail_src) or not is_instance_valid(_swing_trail_node):
		_end_swing_trail()
		return
	# 리그 기준 변환으로 저장·보간한다 — 휘두르기가 몇 프레임뿐이라 사이를 안 채우면 띠가 꺾은선이 된다
	var rig_xf: Transform2D = get_global_transform()
	var now: Transform2D = rig_xf.affine_inverse() * _trail_src.get_global_transform()
	if _trail_has_prev:
		for k in range(1, SWING_TRAIL_FILL + 1):
			var w: float = float(k) / float(SWING_TRAIL_FILL + 1)
			_swing_trail_node.add_point(rig_xf * (_trail_prev.interpolate_with(now, w) * _trail_tip))
	_swing_trail_node.add_point(rig_xf * (now * _trail_tip))
	_trail_prev = now
	_trail_has_prev = true

## 지금 띠를 놓는다 — 띠는 남은 꼬리가 사라질 때까지 맵에 남았다가 스스로 지워진다
func _end_swing_trail() -> void:
	if _swing_trail_node != null and is_instance_valid(_swing_trail_node):
		_swing_trail_node.finish()
	_swing_trail_node = null
	_trail_serial = -1
	_trail_src = null
	_trail_has_prev = false

## 스윙 타 번호(_attack_variant)에 따른 감기 각도/후리기 각도/손 경로.
## 기본값(variant 0)은 씬의 export 값 그대로라 예전 동작·다른 캐릭터에 영향이 없다.
## 각도 부호: 음수=반시계(무기가 위로), 양수=시계(아래로)
func _attack_variant_params() -> Dictionary:
	# 베기(경관봉 난무)는 제일 먼저 가로챈다 — 잽·어퍼컷 같은 맨손 규칙을 타면 안 된다
	if _attack_variant >= SLASH_VARIANT_BASE:
		var sl: Dictionary = SLASHES[(_attack_variant - SLASH_VARIANT_BASE) % SLASHES.size()]
		return {
			"raise_deg": sl["raise_deg"],
			"swing_deg": sl["swing_deg"],
			"raise_off": sl["raise_off"] * slash_scale,
			"slam_off": sl["slam_off"] * slash_scale,
			"arc": sl["arc"] * slash_scale,
		}
	# 발로 차는 타에서는 손에 든 무기를 휘두르지 않는다 — 팔은 균형만 잡는다
	if attack_kick_hit >= 0 and _attack_variant == attack_kick_hit:
		return _kick_arm_params()
	# 맨손 박치기 — 치는 손은 앞으로 안 나가고 뒤로 젖혀 균형만 잡는다(몸은 _pose_headbutt가 돌린다)
	if _is_headbutt():
		return {
			"raise_deg": 0.0,
			"swing_deg": 0.0,
			"raise_off": headbutt_hand_back * 0.5,
			"slam_off": headbutt_hand_back,
			"arc": 0.0,
		}
	# 맨손 마무리는 어퍼컷 — 잽보다 먼저 판단한다(마무리 타만 궤도가 다르다)
	if unarmed_uppercut and not held_item_armed and _attack_variant >= final_hit_index:
		var up_hand: Sprite2D = _attack_hand()
		var up_rest: Vector2 = _rest_positions[up_hand] if (up_hand and _rest_positions.has(up_hand)) else Vector2.ZERO
		# 시작·끝을 **절대 좌표로** 정하고 쉬는 자리와의 차이로 바꾼다 — 어느 손으로 쳐도 같은 궤도가 된다
		return {
			"raise_deg": uppercut_raise_deg,
			"swing_deg": uppercut_swing_deg,
			"raise_off": uppercut_start - up_rest,
			"slam_off": uppercut_end - up_rest,
			"arc": uppercut_arc,
		}
	# 맨손 잽은 정면으로 곧게 — 호(arc) 0이라 위아래로 안 휜다.
	# 뻗는 끝점은 **손마다 다른 쉬는 자리에서 같은 x까지** 오도록 그 자리에서 계산한다
	if unarmed_thrust and not held_item_armed:
		var hand: Sprite2D = _attack_hand()
		var rest_x: float = _rest_positions[hand].x if (hand and _rest_positions.has(hand)) else 0.0
		return {
			"raise_deg": jab_raise_deg,
			"swing_deg": jab_swing_deg,
			"raise_off": jab_raise_off,
			"slam_off": Vector2(jab_reach_x - rest_x, 0.0),
			"arc": 0.0,
		}
	if attack_thrust:
		return _thrust_variant_params()
	if attack_two_handed:
		return _two_handed_variant_params()
	match _attack_variant:
		1:
			# 2타 — 앞쪽으로 낮고 빠르게 후려치기 (내려찍기와 다른 궤적: 감기 작게, 앞으로 길게)
			return {
				"raise_deg": attack_raise_deg * 0.45,
				"swing_deg": attack_swing_deg * 0.8,
				"raise_off": Vector2(attack_raise_offset.x * 0.3, -6.0),
				"slam_off": Vector2(attack_slam_offset.x * 1.6, 0.0),
			}
		2:
			# 3타 — 아래로 감았다가 크게 올려친다 (마무리 타). 후리기 각도가 음수라 무기가 위로 솟는다
			return {
				"raise_deg": -attack_raise_deg * 0.6,
				"swing_deg": -attack_swing_deg * 1.05,
				"raise_off": Vector2(attack_raise_offset.x * 0.2, 24.0),
				"slam_off": Vector2(attack_slam_offset.x * 0.7, -42.0),
			}
		_:
			# 1타 — 기존 내려찍기 (씬 export 값 그대로)
			return {
				"raise_deg": attack_raise_deg,
				"swing_deg": attack_swing_deg,
				"raise_off": attack_raise_offset,
				"slam_off": attack_slam_offset,
			}

## 두 손으로 잡는 무기(악플러 키보드)의 타별 동작. **1·2타는 앞으로 밀치고(찌르기), 3타만 크게 옆으로 휘두른다**
## (2026-09-29 사용자 요청). 밀치기는 키보드가 상대 쪽(앞)으로 나가므로 얼굴을 안 가리고, 두 손으로 잡은 게 잘 보인다.
##  - 1·2타 밀치기: 회전을 거의 안 주고(각도 작게) 손을 뒤로 살짝 뺐다가 앞으로 쭉 내민다. "arc" 0이라 곧게 나간다
##  - 3타 휘두르기: 뒤 위로 크게 감았다가 앞 아래로 후려친다. "arc"로 호를 그려 야구방망이처럼 휘두른다
##
## 각도 부호: 음수 raise=무기가 위로 감김, 양수 swing=아래로 후려침. arc는 타별로 다르므로 Dictionary에 담아 넘긴다.
## **휘두르는 3타는 총 회전각(raise+swing)을 120도 밑으로 유지할 것** — 넘으면 키보드가 얼굴을 가로지른다
func _two_handed_variant_params() -> Dictionary:
	match _attack_variant:
		1:
			# 2타 — 두 손으로 키보드를 위로 쳐올린다 (올려치기).
			# 예비는 가슴 높이에서 살짝만 내렸다가(아래로 크게 감으면 "아래로 치는" 것처럼 보임) 위로 크게 솟는다
			return {
				"raise_deg": -4.0,
				"swing_deg": -36.0,
				"raise_off": Vector2(-6.0, 4.0),
				"slam_off": Vector2(14.0, -40.0),
				"arc": 0.0,
			}
		2:
			# 3타 — 키보드가 오른손을 축으로 한 바퀴 돈다(회전은 _apply_pose에서 HandRHold에 더한다).
			# 손 자체는 돌지 않고 앞으로 살짝 내밀기만 한다(손 회전 0이라야 키보드 스핀만 깔끔하게 보인다)
			return {
				"raise_deg": 0.0,
				"swing_deg": 0.0,
				"raise_off": Vector2(-4.0, 0.0),
				"slam_off": Vector2(16.0, 0.0),
				"arc": 0.0,
			}
		_:
			# 1타 — 앞으로 짧게 밀치기 (키보드를 거의 수평으로 쭉 내민다)
			return {
				"raise_deg": 5.0,
				"swing_deg": 3.0,
				"raise_off": Vector2(-8.0, -2.0),
				"slam_off": Vector2(28.0, 0.0),
				"arc": 0.0,
			}

## 찌르기(attack_thrust)일 때의 타별 동작. 세 타가 서로 다른 궤적이어야 한 동작을 세 번
## 반복하는 것처럼 안 보이므로, 2·3타는 1타 값에서 파생시키지 않고 따로 지정한다.
## 1타 앞으로 찌르기 → 2타 아래에서 위로 올려치기 → 3타 머리 뒤로 넘겨 바닥까지 내려찍기
func _thrust_variant_params() -> Dictionary:
	match _attack_variant:
		1:
			return {
				"raise_deg": thrust2_raise_deg,
				"swing_deg": thrust2_swing_deg,
				"raise_off": thrust2_raise_offset,
				"slam_off": thrust2_slam_offset,
			}
		2:
			return {
				"raise_deg": thrust3_raise_deg,
				"swing_deg": thrust3_swing_deg,
				"raise_off": thrust3_raise_offset,
				"slam_off": thrust3_slam_offset,
			}
		_:
			return {
				"raise_deg": attack_raise_deg,
				"swing_deg": attack_swing_deg,
				"raise_off": attack_raise_offset,
				"slam_off": attack_slam_offset,
			}

## 발로 차는 타의 팔 동작. 무기를 휘두르는 대신 오른손이 뒤로 빠졌다가 돌아온다 —
## 차는 발과 반대쪽으로 팔이 빠져야 균형을 잡는 것처럼 보인다
func _kick_arm_params() -> Dictionary:
	return {
		"raise_deg": 0.0,
		"swing_deg": -16.0,
		"raise_off": kick_hand_offset * 0.4,
		"slam_off": kick_hand_offset,
	}

## 발차기 자세 — 앞발(오른발)이 무릎을 접었다가(①) 앞으로 쭉 뻗고(②) 제자리로 돌아온다(③).
## 손 스윙과 **같은 구간 비율**(ATTACK_STRIKE_START/END)을 쓰므로, 히트박스가 켜지는 순간에
## 발이 가장 멀리 뻗어 있다. 뻗는 정도(reach)는 예비동작에서 음수(뒤로 접음)가 된다
func _pose_kick() -> void:
	var progress: float = 1.0 - _attack_time / maxf(_attack_len, 0.001)
	var reach: float
	if _spin_now:
		reach = _spin_kick_reach(progress)
	elif progress < ATTACK_STRIKE_START:
		# ① 무릎을 뒤로 접는다 (끝으로 갈수록 느려지게)
		var p: float = 1.0 - (1.0 - progress / ATTACK_STRIKE_START) * (1.0 - progress / ATTACK_STRIKE_START)
		reach = lerpf(0.0, -kick_windup_ratio, p)
	elif progress < ATTACK_STRIKE_END:
		# ② 확 뻗어 찬다 (실제로 때리는 구간)
		var p: float = (progress - ATTACK_STRIKE_START) / (ATTACK_STRIKE_END - ATTACK_STRIKE_START)
		reach = lerpf(-kick_windup_ratio, 1.0, p * p)
	else:
		# ③ 발을 내리고 제자리로
		var p: float = (progress - ATTACK_STRIKE_END) / (1.0 - ATTACK_STRIKE_END)
		reach = lerpf(1.0, 0.0, p)
	# 뻗은 만큼만(음수 구간은 0) 발끝을 들고 몸을 젖힌다 — 접는 동안 발끝까지 돌면 어색하다
	var out: float = maxf(reach, 0.0)
	if _foot_r:
		_foot_r.position = _rest_positions[_foot_r] + kick_foot_offset * reach
		_foot_r.rotation = deg_to_rad(kick_foot_deg) * out
	if _foot_l:
		_foot_l.position = _rest_positions[_foot_l] + kick_back_foot_offset * out
	# **기울기에 facing 부호를 곱한다** — 좌우 반전이 scale.x = -1이라 회전 각도는 그대로 남기 때문에,
	# 안 곱하면 왼쪽을 보는 캐릭터가 반대로 젖혀진다 (돌진·클래시 자세와 같은 이유)
	var sgn: float = 1.0
	if _fighter != null and is_instance_valid(_fighter) and not is_zero_approx(_fighter.facing):
		sgn = signf(_fighter.facing)
	var lean: float = deg_to_rad(kick_lean_deg) * out * sgn
	if _body:
		_body.rotation = lean
	if _head:
		_head.rotation += lean * 0.5

## 뒤돌려차기의 발 뻗기 — **도는 흐름 안에서** 발이 나간다.
## 등을 보이기 전까지는 발을 붙이고 있다가, 반대편으로 넘어가는 동안 뻗기 시작해 후려치는 순간(spin_strike) 다 뻗고,
## 한 바퀴를 마저 도는 동안 뻗은 채 휘두르다가 다 돈 뒤에 내린다. 무릎을 뒤로 접는 준비 동작은 없다(회전이 곧 준비 동작)
func _spin_kick_reach(progress: float) -> float:
	var s_end: float = maxf(spin_end, 0.01)
	var hit_at: float = s_end * spin_strike
	var start_at: float = spin_end * 0.45
	if progress < start_at:
		return 0.0
	if progress < hit_at:
		var p: float = (progress - start_at) / maxf(hit_at - start_at, 0.001)
		return p * p
	if progress < spin_end:
		return 1.0
	return lerpf(1.0, 0.0, (progress - spin_end) / maxf(1.0 - spin_end, 0.001))

## 머리를 조준 각도만큼 더 기울인다(라디안). 0이면 원래대로.
##
## **각도는 "바라보는 쪽을 0으로 본 위아래 각"을 그대로 주면 된다** — 좌우 반전이 `scale.x = -1`이라
## 로컬 회전도 같이 뒤집혀서, 왼쪽을 볼 때도 같은 값이 같은 방향(아래=양수)으로 보인다.
## 다른 자세를 덮어쓰지 않고 **더하기만** 하므로 걷기·떨림과 같이 나갈 수 있다
func set_head_aim(radians: float) -> void:
	_head_aim = radians

## 머리를 duration(초) 동안 부들부들 떨게 한다 (악플러 열등감). 이미 떨고 있으면 시간을 다시 채운다
func play_head_shake(duration: float) -> void:
	if duration <= 0.0:
		return
	_head_shake_span = duration
	_head_shake_left = duration

## 떨림을 머리 자세에 **더한다**(덮어쓰지 않는다). 시작·끝에서 부드럽게 커졌다 잦아든다
func _pose_head_shake() -> void:
	if _head == null:
		return
	# 남은 시간 비율로 봉우리 하나(sin)를 그려서, 시작 0 -> 가운데 최대 -> 끝 0이 되게 한다.
	# 이게 없으면 발동하는 순간과 끝나는 순간에 머리가 툭 튄다
	var env: float = sin(clampf(_head_shake_left / maxf(_head_shake_span, 0.001), 0.0, 1.0) * PI)
	var phase: float = (_head_shake_span - _head_shake_left) * head_shake_speed
	_head.rotation += deg_to_rad(head_shake_angle_deg) * sin(phase) * env
	# 가로·세로를 서로 어긋난 주기로 흔들어야 한 방향으로 까딱거리지 않고 "부들부들"해 보인다
	_head.position += Vector2(
		head_shake_offset.x * sin(phase * 1.37),
		head_shake_offset.y * sin(phase * 0.83)) * env

## 드롭킥을 시작한다 — 뛰어오른 순간 스킬이 부른다. 땅에 닿으면 `dropkick_land()`로 알려줘야 한다
func play_dropkick() -> void:
	_dk_stage = 1

## 착지했다고 알린다 — getup_time(초) 동안 바닥에 넘어졌다가 일어난다
func dropkick_land(getup_time: float) -> void:
	_dk_stage = 2
	_dk_getup_total = maxf(getup_time, 0.05)
	_dk_getup_left = _dk_getup_total
	_dk_blend = 1.0

## 드롭킥을 도중에 끊는다 (맞아서 취소됐을 때) — 남은 자세가 빠르게 풀린다
func dropkick_end() -> void:
	_dk_stage = 0

## 드롭킥 단계에 따라 누운 각도·내려간 양·자세 섞임을 매 프레임 갱신한다
func _update_dropkick(delta: float) -> void:
	match _dk_stage:
		1:
			# 뛰어올라 두 발을 뻗는다 — dropkick_lay_time 안에 자세가 완성된다
			_dk_blend = minf(_dk_blend + delta / maxf(dropkick_lay_time, 0.01), 1.0)
			_dk_angle = deg_to_rad(dropkick_air_deg) * _dk_blend
			_dk_shift = dropkick_shift * _dk_blend
		2:
			# 넘어졌다 일어난다 — 앞쪽 dropkick_down_hold 동안은 누워 있고 나머지 시간에 몸을 세운다
			_dk_getup_left = maxf(_dk_getup_left - delta, 0.0)
			var done: float = 1.0 - _dk_getup_left / maxf(_dk_getup_total, 0.001)
			var rise: float = clampf((done - dropkick_down_hold) / maxf(1.0 - dropkick_down_hold, 0.001), 0.0, 1.0)
			rise = rise * rise * (3.0 - 2.0 * rise)   # 시작·끝이 부드럽게
			_dk_angle = lerpf(deg_to_rad(dropkick_down_deg), 0.0, rise)
			_dk_shift = dropkick_down_shift.lerp(Vector2.ZERO, rise)
			_dk_blend = 1.0 - rise   # 일어나면서 뻗었던 두 발도 같이 접힌다
			if _dk_getup_left <= 0.0:
				_dk_stage = 0
		_:
			# 안 쓰는 동안엔 남은 자세가 빠르게 풀린다 (도중에 끊겼을 때도 부드럽게 돌아온다)
			_dk_blend = maxf(_dk_blend - delta * 8.0, 0.0)
			_dk_angle = move_toward(_dk_angle, 0.0, delta * 12.0)
			_dk_shift = _dk_shift.move_toward(Vector2.ZERO, delta * 90.0)

## 두 발을 모아 앞으로 뻗고 두 손은 뒤로 뺀 자세. 눕히는 건 `_lay_down()`이 따로 맡는다
func _pose_dropkick() -> void:
	var t: float = _dk_blend
	if _foot_r:
		_foot_r.position = _foot_r.position.lerp(_rest_positions[_foot_r] + dropkick_foot_offset, t)
		_foot_r.rotation = lerpf(_foot_r.rotation, deg_to_rad(dropkick_foot_deg), t)
	if _foot_l:
		# 뒷발은 앞발 옆에 붙는다 — 제자리가 뒤쪽(x가 음수)이라 gap만큼 더 당겨야 두 발이 모인다
		_foot_l.position = _foot_l.position.lerp(_rest_positions[_foot_l] + dropkick_foot_offset + dropkick_foot_gap, t)
		_foot_l.rotation = lerpf(_foot_l.rotation, deg_to_rad(dropkick_foot_deg), t)
	if _hand_r:
		_hand_r.position = _hand_r.position.lerp(_rest_positions[_hand_r] + dropkick_hand_offset, t)
	if _hand_l:
		_hand_l.position = _hand_l.position.lerp(_rest_positions[_hand_l] + dropkick_hand_offset, t)

## 지금 잡혀 있는 자세를 통째로 `angle`만큼 눕히고 `shift`만큼 내린다.
## 조각의 **로컬 좌표**에서 돌리므로 좌우 반전(scale.x = -1)에 저절로 맞는다 — 방향 부호를 곱하면 안 된다
func _lay_down(angle: float, shift: Vector2) -> void:
	var c: float = cos(angle)
	var s: float = sin(angle)
	for part in [_foot_l, _foot_r, _body, _head, _hand_l, _hand_r, _hand_r_hold]:
		if part == null:
			continue
		var p: Vector2 = part.position - dropkick_pivot
		part.position = dropkick_pivot + Vector2(p.x * c - p.y * s, p.x * s + p.y * c) + shift
		part.rotation += angle

## 후려치는 동안 손이 지나가는 길을 아래로 부풀린다. 예비동작 위치에서 내려찍는 위치로 가는
## 직선의 수직(아래쪽) 방향으로 밀어내며, sin이라 출발·도착에서는 0이라 튀지 않는다
func _swing_arc(t: float, raise_off: Vector2, slam_off: Vector2, arc_amount: float) -> Vector2:
	if is_zero_approx(arc_amount):
		return Vector2.ZERO
	var travel: Vector2 = slam_off - raise_off
	if travel.length() < 0.001:
		return Vector2.ZERO
	return Vector2(-travel.y, travel.x).normalized() * arc_amount * sin(t * PI)

## 두 손으로 잡는 캐릭터는 왼손이 오른손 옆으로 붙는다. **콤보가 이어지는 동안은 계속 붙어 있고**
## 마지막 타가 끝난 뒤에야 풀린다 — 타마다 놨다 잡으면 손이 덜덜거리는 것처럼 보인다.
## 무기는 오른손(HandRHold)에 매달려 있으므로 왼손은 위치·회전만 따라가면 같이 잡은 것처럼 보인다
func _pose_grip_hand() -> void:
	if _hand_l == null:
		return
	var grip: float = _grip_blend
	# 무기 스핀 타 중엔 도는 동안 왼손을 뗀다 — 무기가 오른손 축으로 돌 때 왼손이 따라가면 이상하다.
	# 시작·끝에서는 다시 잡아 "돌린 뒤 다시 두 손으로 잡는" 그림이 된다
	if _attack_time > 0.0 and weapon_spin_hit >= 0 and _attack_variant == weapon_spin_hit:
		var sp: float = 1.0 - _attack_time / maxf(_attack_len, 0.001)
		grip *= 1.0 - _weapon_spin_release(sp)
	var off: Vector2 = attack_grip_offset
	if grip_offset_follows_rotation:
		off = off.rotated(_hand_r.rotation)
	_hand_l.position = _rest_positions[_hand_l].lerp(_hand_r.position + off, grip)
	_hand_l.rotation = _hand_r.rotation * grip

## 무기 스핀 중 왼손을 떼는 정도(0=잡음, 1=완전히 뗌). 가운데(도는 구간)엔 1, 시작·끝 15%엔 서서히 다시 잡는다
func _weapon_spin_release(progress: float) -> float:
	var t: float = clampf(progress, 0.0, 1.0)
	if t < 0.15:
		return t / 0.15
	if t > 0.85:
		return (1.0 - t) / 0.15
	return 1.0

## --- 키보드 선풍기 회전 (악플러 그랩 후 회전 난무) ---
## duration초 동안 두 손을 몸 앞에 모으고 무기를 아주 빠르게 계속 돌린다. 0 이하면 그 자리에서 끝낸다
func play_keyboard_fan(duration: float) -> void:
	_fan_time = maxf(duration, 0.0)
	_fan_phase = 0.0
	# 무기 자식의 원래 위치·크기를 기억해 둔다 — 도는 동안 (0,0)으로 옮기고 키웠다가 끝나면 되돌린다
	_fan_child_rest.clear()
	_fan_child_scale.clear()
	if _hand_r_hold:
		for child in _hand_r_hold.get_children():
			if child is Sprite2D:
				_fan_child_rest[child] = child.position
				_fan_child_scale[child] = child.scale
	# 도는 동안 두 손을 키보드(z 1)보다 앞으로 올려 둘 다 보이게 한다(어떤 방향에서도 손이 안 가려지게)
	if _hand_r:
		_hand_r.z_index = attack_grip_hand_z
	if _hand_l:
		_hand_l.z_index = attack_grip_hand_z

func end_keyboard_fan() -> void:
	_fan_time = 0.0
	# 회전 때문에 (0,0)으로 옮기고 키운 무기를 원래 자리·크기로 되돌린다
	for child in _fan_child_rest:
		if is_instance_valid(child):
			child.position = _fan_child_rest[child]
			if _fan_child_scale.has(child):
				child.scale = _fan_child_scale[child]
	_fan_child_rest.clear()
	_fan_child_scale.clear()
	# 손 z_index를 원래대로 되돌린다
	if _hand_r:
		_hand_r.z_index = _hand_r_rest_z
	if _hand_l:
		_hand_l.z_index = _hand_l_rest_z

## 두 손을 몸 앞 축(fan_hand_pos)으로 모은다 — 무기 회전은 _apply_pose의 HandRHold에서 더한다.
## 로컬 좌표라 좌우 반전(scale.x = -1)에 저절로 맞는다
func _pose_keyboard_fan() -> void:
	if _hand_r:
		_hand_r.position = fan_hand_pos
		_hand_r.rotation = 0.0
	if _hand_l:
		_hand_l.position = fan_hand_pos + fan_hand_l_offset
		_hand_l.rotation = 0.0

## 빠르게 도는 무기가 원반(선풍기 팬)처럼 보이게, 매 프레임 현재 모습을 잔상으로 남기고 서서히 지운다.
## _apply_pose가 끝난 뒤(이번 프레임 무기 위치 확정 후) 호출한다 — _update_smear와 같은 방식
func _update_fan_ghosts(delta: float) -> void:
	for i in _fan_ghosts.size():
		if _fan_ghost_left[i] <= 0.0:
			continue
		_fan_ghost_left[i] -= delta
		if _fan_ghost_left[i] <= 0.0:
			_fan_ghosts[i].visible = false
		else:
			_fan_ghosts[i].modulate.a = fan_ghost_alpha * (_fan_ghost_left[i] / maxf(fan_ghost_life, 0.001))
	if _fan_time <= 0.0 or _hand_r_hold == null:
		return
	for child in _hand_r_hold.get_children():
		if child is Sprite2D and child.visible:
			_spawn_fan_ghost(child)

func _spawn_fan_ghost(src: Sprite2D) -> void:
	if _fan_ghosts.is_empty():
		_build_fan_ghosts()
	var idx: int = 0
	for i in _fan_ghost_left.size():
		if _fan_ghost_left[i] < _fan_ghost_left[idx]:
			idx = i
	var g: Sprite2D = _fan_ghosts[idx]
	g.texture = src.texture
	g.centered = src.centered
	g.offset = src.offset
	g.flip_h = src.flip_h
	g.flip_v = src.flip_v
	g.region_enabled = src.region_enabled
	g.region_rect = src.region_rect
	g.z_index = src.z_index
	g.global_transform = src.get_global_transform()
	_fan_ghost_left[idx] = fan_ghost_life
	g.modulate = Color(1, 1, 1, fan_ghost_alpha)
	g.visible = true

## 잔상 칸을 만든다 — top_level이라 리그가 움직여도 그 자리에 남는다. owner를 안 줘서 씬에 저장되지 않는다
func _build_fan_ghosts() -> void:
	var at: int = get_child_count()
	if _hand_r_hold:
		at = mini(at, _hand_r_hold.get_index())
	for i in maxi(fan_ghost_count, 1) * 2:
		var g := Sprite2D.new()
		g.top_level = true
		g.visible = false
		add_child(g)
		move_child(g, at + i)
		_fan_ghosts.append(g)
		_fan_ghost_left.append(0.0)

## 점프하는 순간 몸을 세로로 늘린다 (squash & stretch). Fighter.jump()이 호출한다
func play_jump_stretch() -> void:
	play_squash(jump_stretch)

## 몸 전체를 잠깐 늘렸다/눌렀다 원래대로 돌린다 (x=가로 배율, y=세로 배율).
## **스킬 연출에서 캐릭터 크기를 건드릴 때는 반드시 이걸 쓸 것.**
##
## 스킬이 `Visual.scale`을 직접 트윈하면 **좌우 반전이 깨진다** — 이 리그는 왼쪽을 볼 때
## `scale.x`를 음수로 두는데, 트윈이 양수 목표값으로 끌고 가면서 0을 지나 오른쪽으로 뒤집힌다.
## (열등감·촉법소년 궁에서 실제로 겪었다: "쓰면 자꾸 오른쪽 돌아본다")
## 여기서는 리그가 매 프레임 `_squash`에 방향 부호를 곱해 적용하므로 보는 방향이 안 바뀐다.
## 원래 크기로 돌아오는 속도는 `squash_recover_speed`(2.5/초)를 그대로 쓴다
func play_squash(amount: Vector2) -> void:
	_squash = amount
	_squashing = true

## 스킬 클래시 대치 자세를 켜고 끈다 (SkillClashPopup이 부른다).
## 켜져 있는 동안 연타가 들어올 때마다 주먹을 번갈아 내지르고(clash_punch), 밀당에 따라 몸과 고개가 앞뒤로 기운다
func set_clash(on: bool) -> void:
	_clash_target = 1.0 if on else 0.0
	if not on:
		# 자세가 풀리는 동안 기울기·밀림이 남아 있으면 몸이 삐뚤어진 채로 서서히 돌아온다.
		# 바로 0으로 지워서 "제자리 자세로 스르륵"만 남긴다
		_clash_push = 0.0
		_clash_shove = 0.0
		# 주먹질도 멈추고 남은 잔상은 치운다
		_punch_queue = 0
		_punch_t = -1.0
		for g in _ghosts:
			g.visible = false
		for i in _ghost_life.size():
			_ghost_life[i] = 0.0

## 지금 밀당이 어느 쪽으로 기울었는지 넣어준다. -1이면 완전히 밀리는 중, +1이면 완전히 밀어붙이는 중
func set_clash_push(push: float) -> void:
	_clash_push = clampf(push, -1.0, 1.0)

## 맞댄 손을 화면 가로 방향으로 이만큼(px) 밀어준다. **두 캐릭터에게 같은 값을 넣어야 한다** —
## 서로 마주 본 상태라 각자 "앞으로"를 쓰면 손이 서로를 파고들어 버린다.
## 화면 기준으로 받아서 캐릭터가 보는 방향에 맞춰 안에서 뒤집는다
func set_clash_shove(world_dx: float) -> void:
	_clash_shove = world_dx

## 주먹을 번갈아 내지르고, 밀당만큼 몸과 고개를 기울인다.
##
## **기울기에 facing 부호를 곱하는 이유:** 좌우 반전은 `scale.x = -1`로 하는데,
## Node2D 변환이 `회전 * 크기` 순서라 x축은 뒤집혀도 회전 각도는 그대로 남는다.
## 그래서 왼쪽을 보는 캐릭터에 같은 각도를 주면 "앞으로 기울기"가 아니라 "뒤로 넘어가기"가 된다
func _pose_clash() -> void:
	var t: float = _clash_blend
	var sgn: float = signf(_fighter.facing) if (_fighter != null and is_instance_valid(_fighter)) else 1.0
	if sgn == 0.0:
		sgn = 1.0
	# 화면 기준 오프셋을 이 캐릭터의 로컬 기준으로 바꾼다. 리그가 scale.x로 뒤집히므로
	# 부호를 곱해두면 두 캐릭터가 화면에서 같은 방향으로 함께 밀린다(이기는 쪽이 전진한다)
	var shove := Vector2(_clash_shove * sgn, 0.0)
	var impact: Vector2 = clash_hand_target + shove
	var guard: Vector2 = impact + clash_punch_guard
	var half_gap := Vector2(0.0, clash_hand_gap * 0.5)
	# 쉬는 손은 가드 자리에서 기다린다 (오른손은 조금 위, 왼손은 조금 아래·뒤)
	var r_rest: Vector2 = guard - half_gap
	var l_rest: Vector2 = guard + half_gap + Vector2(-3.0, 0.0)
	var hit: Vector2 = impact + Vector2(clash_punch_overshoot, _punch_y)
	# 뻗는 정도 0(거둠) -> 1(다 뻗음) -> 0. sin 반주기라 빠르게 나갔다 빠르게 돌아온다.
	# **각 손의 쉬는 자리에서 출발한다** — 가운데 한 점에서 출발하면 주먹이 나가는 순간 손이 톡 튄다
	var ext: float = sin(clampf(_punch_t, 0.0, 1.0) * PI) if _punch_t >= 0.0 else 0.0
	var r_target: Vector2 = r_rest.lerp(hit, ext if _punch_right else 0.0)
	var l_target: Vector2 = l_rest.lerp(hit, 0.0 if _punch_right else ext)
	if _hand_r:
		_hand_r.position = _hand_r.position.lerp(r_target, t)
		_hand_r.rotation = 0.0
	if _hand_l:
		_hand_l.position = _hand_l.position.lerp(l_target, t)
		_hand_l.rotation = 0.0
	# 주먹을 뻗을 때 몸이 조금 앞으로 들썩인다 — 팔로만 치면 가벼워 보인다.
	# 이기는 쪽으로 쏠리는 밀림(shove)도 몸이 절반쯤 따라간다
	var kick: float = clash_punch_body_kick * ext
	if _body:
		_body.position.x = _rest_positions[_body].x + (shove.x * clash_body_follow + kick) * t
	if _head:
		_head.position.x = _rest_positions[_head].x + (shove.x * clash_body_follow + kick * 0.6) * t
	rotation = deg_to_rad(clash_lean_deg) * _clash_push * t * sgn
	if _head:
		_head.rotation = deg_to_rad(clash_head_deg) * _clash_push * t * sgn

## 연타 한 번에 주먹을 쌓아준다 (SkillClashPopup이 누를 때마다 부른다). 누르는 속도가 곧 주먹질 속도다
func clash_punch() -> void:
	_punch_queue = mini(_punch_queue + clash_punches_per_press, clash_punch_queue_max)

## 주먹 러시를 한 프레임 진행한다 — 쌓인 주먹을 하나씩 번갈아 내보내고, 잔상을 흐리게 지운다
func _tick_clash_punches(delta: float) -> void:
	if _punch_t >= 0.0:
		_punch_t += delta / maxf(clash_punch_time, 0.001)
		# 다 뻗은 순간 그 자리에 잔상을 하나 남긴다 — 주먹이 거둬진 뒤에도 잠깐 남아서 여러 개로 보인다
		if not _punch_ghosted and _punch_t >= 0.5:
			_punch_ghosted = true
			_spawn_ghost(_punch_right)
		if _punch_t >= 1.0:
			_punch_t = -1.0
	if _punch_t < 0.0 and _punch_queue > 0 and _clash_target > 0.0:
		_punch_queue -= 1
		_punch_t = 0.0
		_punch_right = not _punch_right
		_punch_y = randf_range(-clash_punch_spread, clash_punch_spread)
		_punch_ghosted = false
	for i in _ghosts.size():
		if _ghost_life[i] <= 0.0:
			continue
		_ghost_life[i] -= delta
		var g: Sprite2D = _ghosts[i]
		if _ghost_life[i] <= 0.0:
			g.visible = false
		else:
			g.modulate.a = clash_ghost_alpha * (_ghost_life[i] / maxf(clash_ghost_life, 0.001))

## 주먹 잔상 하나를 지금 손 자리에 남긴다 — 가장 오래된 잔상 칸을 재활용한다
func _spawn_ghost(right: bool) -> void:
	var src: Sprite2D = _hand_r if right else _hand_l
	if src == null or clash_ghost_count <= 0:
		return
	if _ghosts.is_empty():
		_build_ghosts()
	var idx: int = 0
	for i in _ghost_life.size():
		if _ghost_life[i] < _ghost_life[idx]:
			idx = i
	var g: Sprite2D = _ghosts[idx]
	g.texture = src.texture
	g.centered = src.centered
	g.offset = src.offset
	g.flip_h = src.flip_h
	g.region_enabled = src.region_enabled
	g.region_rect = src.region_rect
	g.z_index = src.z_index
	g.scale = src.scale
	g.rotation = src.rotation
	# 조금씩 어긋나게 남겨야 주먹이 여러 개로 보인다 (같은 자리에 겹치면 하나로 보인다)
	g.position = src.position + Vector2(randf_range(-5.0, 2.0), randf_range(-4.0, 4.0))
	g.modulate.a = clash_ghost_alpha
	g.visible = true
	_ghost_life[idx] = clash_ghost_life

## 잔상용 스프라이트를 만든다. 오른손 바로 뒤 순서에 끼워서 몸보다는 앞, 머리보다는 뒤에 그려지게 한다.
## owner를 안 주므로 씬 파일에는 저장되지 않는다
func _build_ghosts() -> void:
	var at: int = (_hand_r.get_index() + 1) if _hand_r else get_child_count()
	for i in clash_ghost_count:
		var g := Sprite2D.new()
		g.visible = false
		add_child(g)
		move_child(g, mini(at + i, get_child_count() - 1))
		_ghosts.append(g)
		_ghost_life.append(0.0)

## 자전거를 탄다/내린다 (촉법소년 돌진). 자전거 노드가 없는 캐릭터에선 아무 일도 안 한다.
## DashSkill이 돌진 시작에 true, 끝에 false로 부른다
## 자전거가 부서졌다(DashSkill이 조각을 맵에 따로 띄운다) — 타던 자전거를 그 자리에서 바로 감춘다.
## 다음에 set_riding(true)가 오면 새 자전거가 평소처럼 뒤에서 들어온다
func break_bike() -> void:
	if _bike == null:
		return
	_ride_target = 0.0
	_ride_blend = 0.0
	_bike.visible = false

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

## 총 쏘기 동작 시작 — 주머니에서 총을 꺼내 두 손을 모아 앞으로 겨눈다.
## BBGunSkill이 발동하는 순간 전체 지속시간과 꺼내는 시간(draw_time, 첫 발 전까지)을 넘겨서 호출한다.
## draw_time을 안 주면 전체의 gun_draw_ratio만큼 꺼낸다(컷인). holster_time > 0이면 전체의 맨 끝 그만큼 다시 주머니에 넣는다.
## 총 노드가 없으면 아무 일도 안 한다
func play_gun_motion(duration: float, draw_time: float = -1.0, holster_time: float = 0.0) -> void:
	if _gun == null:
		return
	if _gun_rest_scale == Vector2.ZERO:
		_gun_rest_scale = _gun.scale
	_gun_duration = maxf(duration, 0.05)
	_gun_time = _gun_duration
	_gun_draw_time = draw_time if draw_time > 0.0 else _gun_duration * gun_draw_ratio
	_gun_holster_time = clampf(holster_time, 0.0, maxf(_gun_duration - _gun_draw_time, 0.0))

## 한 발 쏠 때마다 반동을 준다 — BBGunSkill이 총알을 발사한 순간 호출한다
func gun_recoil() -> void:
	_recoil = 1.0

## 짜장면 먹기 동작 시작 — JjajangEatSkill이 먹기 시작할 때 먹는 시간을 넘겨서 부른다. 그릇(EatBowl)이 없으면 아무 일도 안 한다
func play_eat_motion(duration: float) -> void:
	if _eat_bowl == null:
		return
	_eat_duration = maxf(duration, 0.05)
	_eat_time = _eat_duration

## 먹기 동작을 그 자리에서 끝낸다(다 먹었거나 맞아서 끊김) — 그릇을 숨기면 다음 프레임부터 원래 자세로 돌아간다
func stop_eat_motion() -> void:
	_eat_time = 0.0
	if _eat_bowl:
		_eat_bowl.visible = false
		_eat_bowl.scale = _eat_bowl_rest_scale

## 백 서플렉스 동작 시작 — 손을 뻗어 잡고, 뒤로 젖히며 들어올려, 등 뒤로 넘겨 꽂는다.
## BackSuplexSkill이 잡기가 성립한 순간 세 구간(뻗기/들어올리기/넘겨꽂기)의 길이를 넘겨서 호출한다
func play_grab_motion(reach_duration: float, hold_duration: float, slam_duration: float) -> void:
	_grab_duration = maxf(reach_duration + hold_duration + slam_duration, 0.05)
	_grab_reach_ratio = clampf(reach_duration / _grab_duration, 0.01, 0.98)
	_grab_slam_ratio = clampf((reach_duration + hold_duration) / _grab_duration, _grab_reach_ratio + 0.01, 0.99)
	_grab_time = _grab_duration
	_grab_mode = GrabMode.SUPLEX

## 머리 잡기 — 두 손을 앞으로 뻗어(reach) 잡은 채 버티다가(hold) 빈손으로 돌아온다(back).
## 맞으면 그 자리에서 `play_head_throw`로 이어진다
func play_head_grab(reach_duration: float, hold_duration: float, back_duration: float) -> void:
	_grab_duration = maxf(reach_duration + hold_duration + back_duration, 0.05)
	_grab_reach_ratio = clampf(reach_duration / _grab_duration, 0.01, 0.98)
	_grab_slam_ratio = clampf((reach_duration + hold_duration) / _grab_duration, _grab_reach_ratio + 0.01, 0.99)
	_grab_time = _grab_duration
	_grab_mode = GrabMode.HEAD_REACH

## 머리 잡아 패대기 — 잡은 자리에서 머리 위로 넘겨(throw) 등 뒤 바닥에 꽂고, 제자리로 돌아온다(recover)
func play_head_throw(throw_duration: float, recover_duration: float) -> void:
	_grab_duration = maxf(throw_duration + recover_duration, 0.05)
	_grab_reach_ratio = clampf(throw_duration / _grab_duration, 0.01, 0.99)
	_grab_time = _grab_duration
	_grab_mode = GrabMode.HEAD_THROW

## 넘기는 진행도(0~1)에 따른 두 손 가운데 — 뻗은 자리 → 머리 위 → 등 뒤 바닥을 잇는 곡선(2차 베지어)
func _head_throw_path(t: float) -> Vector2:
	var a: Vector2 = head_grab_reach.lerp(head_throw_top, t)
	var b: Vector2 = head_throw_top.lerp(head_throw_end, t)
	return a.lerp(b, t)

## 지금 두 손이 쥐고 있는 머리 자리(리그 로컬). 머리 잡기 중이 아니면 뻗는 자리를 돌려준다
func head_grab_point() -> Vector2:
	return _head_grab_point if _grab_time > 0.0 and _grab_mode != GrabMode.SUPLEX else head_grab_reach

## 머리 잡기·패대기 자세 — 두 손을 한 점(가운데)에 위아래로 모으고, 넘기는 동안 몸을 뒤로 젖힌다
func _pose_head_grab() -> void:
	var progress: float = 1.0 - _grab_time / _grab_duration
	var point: Vector2
	var lean: float = 0.0
	var head_bend: float = 0.0
	if _grab_mode == GrabMode.HEAD_REACH:
		var mid: Vector2 = (_rest_positions[_hand_r] + _rest_positions[_hand_l]) * 0.5 if (_hand_r and _hand_l) else Vector2.ZERO
		if progress < _grab_reach_ratio:
			# ① 앞으로 확 뻗는다(끝으로 갈수록 느려지게)
			var t: float = progress / _grab_reach_ratio
			point = mid.lerp(head_grab_reach, 1.0 - (1.0 - t) * (1.0 - t))
		elif progress < _grab_slam_ratio:
			# ② 뻗은 채 움켜쥔다
			point = head_grab_reach
		else:
			# ③ 빈손으로 돌아온다
			var t2: float = (progress - _grab_slam_ratio) / (1.0 - _grab_slam_ratio)
			point = head_grab_reach.lerp(mid, t2 * t2 * (3.0 - 2.0 * t2))
	else:
		if progress < _grab_reach_ratio:
			# ① 머리 위로 넘겨 등 뒤 바닥에 꽂는다 — 처음엔 무겁게, 끝에서 확 내리꽂게(가속)
			var t: float = progress / _grab_reach_ratio
			point = _head_throw_path(t * t)
			lean = sin(PI * t) * head_throw_lean_deg
			# 고개는 몸보다 빨리 젖혀져 머리 위를 지날 때 가장 많이 꺾이고, 꽂을 때 돌아온다
			head_bend = sin(PI * minf(t * 1.3, 1.0)) * head_throw_head_deg
		else:
			# ② 꽂은 자리에서 제자리로
			var t2: float = (progress - _grab_reach_ratio) / (1.0 - _grab_reach_ratio)
			var mid2: Vector2 = (_rest_positions[_hand_r] + _rest_positions[_hand_l]) * 0.5 if (_hand_r and _hand_l) else Vector2.ZERO
			point = head_throw_end.lerp(mid2, t2 * t2 * (3.0 - 2.0 * t2))
	_head_grab_point = point
	var gap := Vector2(0, head_grab_hand_gap * 0.5)
	if _hand_r:
		_hand_r.position = point - gap
		_hand_r.rotation = 0.0
	if _hand_l:
		_hand_l.position = point + gap
		_hand_l.rotation = 0.0
	rotation = deg_to_rad(lean)
	if _head and not is_zero_approx(head_bend):
		var a: float = deg_to_rad(head_bend)
		_head.position = head_throw_neck + (_head.position - head_throw_neck).rotated(a)
		_head.rotation += a

## 백 서플렉스 진행도에 따라 두 손과 몸 전체 기울기를 잡는다 (걷기·공격보다 우선한다).
## 두 손을 옆으로 뻗어 위아래로 겹쳐 잡는다(오른손 위/왼손 아래) — 한 손이 아니라 두 손으로
## 붙잡는 그림이라 왼손도 오른손과 같은 목표로 모은다
func _pose_grab() -> void:
	if _grab_mode != GrabMode.SUPLEX:
		_pose_head_grab()
		return
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

## 유선 마우스 던지기 동작 시작 — 어깨 뒤로 젖혀 들었다가 앞으로 뿌리고 제자리로 돌아온다.
## MouseGrabSkill이 젖히는 시간과 뿌리고 돌아오는 시간을 나눠서 넘긴다.
## 젖히는 시간은 마우스가 손을 떠나는 시점과 같아야 한다 — 그래야 "손에 들었다가 던진다"로 보인다
func play_cast_motion(windup_duration: float, release_duration: float) -> void:
	_cast_duration = maxf(windup_duration + release_duration, 0.05)
	_cast_windup_ratio = clampf(windup_duration / _cast_duration, 0.05, 0.95)
	_cast_time = _cast_duration

## 줄을 당기는 자세를 켜고 끈다 — 마우스가 상대를 잡은 순간 true, 놓아줄 때 false (MouseGrab이 부른다)
func set_reeling(on: bool) -> void:
	_reel_target = 1.0 if on else 0.0

## 오른손(물건을 드는 손)의 화면상 위치.
## 손에서 뻗어나가는 연출(마우스 유선 등)이 팔을 그대로 따라가게 할 때 쓴다
func get_hand_position() -> Vector2:
	if _hand_r_hold:
		return _hand_r_hold.global_position
	if _hand_r:
		return _hand_r.global_position
	return global_position

## 던지기 자세 — 뒤로 젖혀 들기(앞 _cast_windup_ratio) → 앞으로 뿌리기 → 제자리로 돌아오기
func _pose_cast() -> void:
	if _hand_r == null:
		return
	var rest: Vector2 = _rest_positions[_hand_r]
	var progress: float = 1.0 - _cast_time / _cast_duration
	var pos: Vector2
	var deg: float
	if progress < _cast_windup_ratio:
		# ① 뒤로 당겨 든다 (이 동안 마우스는 아직 손에 쥐어져 있다)
		var t: float = progress / _cast_windup_ratio
		var smooth_t: float = t * t * (3.0 - 2.0 * t)
		pos = rest.lerp(cast_windup_offset, smooth_t)
		deg = cast_windup_deg * smooth_t
	else:
		var t: float = (progress - _cast_windup_ratio) / (1.0 - _cast_windup_ratio)
		if t < cast_snap_ratio:
			# ② 앞으로 확 뿌린다
			var f: float = t / maxf(cast_snap_ratio, 0.001)
			pos = cast_windup_offset.lerp(cast_release_offset, f)
			deg = lerpf(cast_windup_deg, cast_release_deg, f)
		else:
			# ③ 뻗은 손이 제자리로 돌아온다
			var f: float = (t - cast_snap_ratio) / maxf(1.0 - cast_snap_ratio, 0.001)
			pos = cast_release_offset.lerp(rest, f)
			deg = lerpf(cast_release_deg, 0.0, f)
	_hand_r.position = pos
	_hand_r.rotation = deg_to_rad(deg)

## 돌 던지기 동작 시작 — 전체 길이(초)를 받는다. 돌이 손을 떠나는 시점은 throw_release_ratio 지점이라,
## 부르는 쪽(StoneThrowSkill)은 `duration * throw_release_ratio`만큼 기다렸다가 돌을 만들면 손과 맞는다
func play_throw_motion(duration: float) -> void:
	_throw_duration = maxf(duration, 0.05)
	_throw_time = _throw_duration

## 던지는 동안 손에 쥐여줄 그림(돌 등)을 넣는다. 손에 원래 들고 있던 물건(경봉)은 그동안 자동으로 숨는다
func set_throw_item(texture: Texture2D, item_scale: float = 0.02) -> void:
	if _hand_r_hold == null or texture == null:
		return
	if _throw_item == null:
		_throw_item = Sprite2D.new()
		_throw_item.name = "ThrowItem"
		_hand_r_hold.add_child(_throw_item)
	_throw_item.texture = texture
	_throw_item.scale = Vector2(item_scale, item_scale)
	_throw_item.visible = true

## 손에 쥔 던질 물건을 치운다 — 돌이 손을 떠나는 순간에 부른다
func clear_throw_item() -> void:
	if _throw_item:
		_throw_item.visible = false

## 0~1을 부드럽게 만든다 (시작·끝이 느리고 가운데가 빠른 곡선)
func _ease01(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)

## 돌 던지기 자세 — 러프 4컷(셋업 → 젖힘 → 뿌림 → 마무리)을 이어 붙인다.
## 오른손·왼손·몸통·머리·두 발을 전부 건드리는 큰 동작이다
func _pose_throw() -> void:
	if _hand_r == null:
		return
	var rest_r: Vector2 = _rest_positions[_hand_r]
	var p: float = 1.0 - _throw_time / _throw_duration
	var hand: Vector2
	var deg: float
	var body_deg: float
	if p < throw_setup_ratio:
		# ① 셋업 — 돌 든 손을 몸 뒤로 가져간다
		var t: float = _ease01(p / maxf(throw_setup_ratio, 0.001))
		hand = rest_r.lerp(throw_setup_hand, t)
		deg = lerpf(0.0, throw_setup_deg, t)
		body_deg = 0.0
	elif p < throw_windup_ratio:
		# ② 젖힘 — 손을 뒤 위로 치켜들고 몸을 뒤로 젖힌다
		var t: float = _ease01((p - throw_setup_ratio) / maxf(throw_windup_ratio - throw_setup_ratio, 0.001))
		hand = throw_setup_hand.lerp(throw_windup_hand, t)
		deg = lerpf(throw_setup_deg, throw_windup_deg, t)
		body_deg = lerpf(0.0, throw_body_windup_deg, t)
	elif p < throw_release_ratio:
		# ③ 뿌림 — 가장 짧은 구간이라 제일 빨라 보인다. t를 제곱해서 뒤로 갈수록 확 넘어오게 한다
		var t: float = clampf((p - throw_windup_ratio) / maxf(throw_release_ratio - throw_windup_ratio, 0.001), 0.0, 1.0)
		hand = throw_windup_hand.lerp(throw_release_hand, t * t)
		deg = lerpf(throw_windup_deg, throw_release_deg, t * t)
		body_deg = lerpf(throw_body_windup_deg, throw_body_release_deg, t)
	elif p < throw_follow_ratio:
		# ④ 마무리 — 뻗은 손이 몸 앞으로 내려온다
		var t: float = _ease01((p - throw_release_ratio) / maxf(throw_follow_ratio - throw_release_ratio, 0.001))
		hand = throw_release_hand.lerp(throw_follow_hand, t)
		deg = lerpf(throw_release_deg, throw_follow_deg, t)
		body_deg = throw_body_release_deg
	else:
		# 제자리로 — 몸통 기울기도 같이 풀린다
		var t: float = _ease01((p - throw_follow_ratio) / maxf(1.0 - throw_follow_ratio, 0.001))
		hand = throw_follow_hand.lerp(rest_r, t)
		deg = lerpf(throw_follow_deg, 0.0, t)
		body_deg = lerpf(throw_body_release_deg, 0.0, t)
	_hand_r.position = hand
	_hand_r.rotation = deg_to_rad(deg)
	_pose_throw_hand_l(p)
	# 몸통·머리 기울기. 머리는 몸통을 따라가되 덜 돈다.
	# 여기에 더해 뿌리는 순간부터 허리를 굽혀(crouch) 몸을 실제로 낮춘다
	var crouch: float = _throw_crouch(p)
	if _body:
		_body.rotation = deg_to_rad(body_deg)
		_body.position.y += throw_body_crouch * crouch
	if _head:
		_head.rotation += deg_to_rad(body_deg) * throw_head_follow
		_head.position += Vector2(throw_head_lead * crouch, throw_head_dip * crouch)
	_pose_throw_feet(p)

## 허리를 굽힌 정도 0~1 — 젖힘이 끝나는 지점부터 차오르고, 디딘 발이 풀릴 때 같이 풀린다
func _throw_crouch(p: float) -> float:
	if p < throw_windup_ratio:
		return 0.0
	if p < throw_release_ratio:
		return clampf((p - throw_windup_ratio) / maxf(throw_release_ratio - throw_windup_ratio, 0.001), 0.0, 1.0)
	if p < throw_foot_hold_ratio:
		return 1.0
	return 1.0 - _ease01((p - throw_foot_hold_ratio) / maxf(1.0 - throw_foot_hold_ratio, 0.001))

## 왼손 — 던지기 전엔 앞으로 내밀어 겨누고, 돌이 떠난 뒤엔 몸쪽으로 당긴다 (오른팔의 반대 균형)
func _pose_throw_hand_l(p: float) -> void:
	if _hand_l == null:
		return
	var rest_l: Vector2 = _rest_positions[_hand_l]
	var target: Vector2 = throw_hand_l_front if p < throw_release_ratio else throw_hand_l_pull
	# 동작 앞머리에서 들어갔다가 맨 끝에서 빠진다
	var blend: float = _ease01(p / maxf(throw_setup_ratio, 0.001))
	if p > throw_follow_ratio:
		blend = 1.0 - _ease01((p - throw_follow_ratio) / maxf(1.0 - throw_follow_ratio, 0.001))
	_hand_l.position = rest_l.lerp(rest_l + target, blend)

## 두 발 — **앞발이 한 발 앞으로 나가 디딘 뒤 동작이 끝날 때까지 그 자리에 못박힌다.**
## 이게 이 동작에서 제일 중요한 부분이다(사용자 지정). 뒷발은 버티는 발이라 조금만 뒤로 밀린다
func _pose_throw_feet(p: float) -> void:
	var step: float
	if p < throw_windup_ratio:
		# ①→② 사이에 내딛는다
		step = _ease01(p / maxf(throw_windup_ratio, 0.001))
	elif p < throw_foot_hold_ratio:
		step = 1.0   # 디딘 채로 정지 — 여기서 발이 흔들리면 동작이 가벼워 보인다
	else:
		step = 1.0 - _ease01((p - throw_foot_hold_ratio) / maxf(1.0 - throw_foot_hold_ratio, 0.001))
	# 발을 옮기는 동안만 살짝 들린다. 다 디딘 뒤(p >= throw_windup_ratio)엔 sin(PI)=0이라 바닥에 붙는다
	var lift: float = sin(clampf(p / maxf(throw_windup_ratio, 0.001), 0.0, 1.0) * PI) * throw_step_lift
	if _foot_r:
		_foot_r.position = _rest_positions[_foot_r] + Vector2(throw_step_foot * step, -lift)
		_foot_r.rotation = deg_to_rad(-10.0) * step
	if _foot_l:
		_foot_l.position = _rest_positions[_foot_l] + Vector2(throw_back_foot * step, 0.0)
		_foot_l.rotation = deg_to_rad(8.0) * step

## 줄 당기기 자세 — 두 손으로 줄을 잡고 박자에 맞춰 몸쪽으로 당겼다 놓는다.
## 걷기·던지기 자세에서 _reel_blend만큼 섞으므로 켜지고 꺼질 때 툭 끊기지 않는다
func _pose_reel() -> void:
	# sin을 0~1로 옮겨서, 한 박자에 한 번 몸쪽(-x)으로 당겼다가 다시 내민다
	var tug: float = (sin(_reel_phase) + 1.0) * 0.5
	var grip: Vector2 = reel_hand_offset - reel_tug_offset * tug
	var deg: float = deg_to_rad(reel_hand_deg)
	if _hand_r:
		_hand_r.position = _hand_r.position.lerp(grip, _reel_blend)
		_hand_r.rotation = lerpf(_hand_r.rotation, deg, _reel_blend)
	if _hand_l:
		_hand_l.position = _hand_l.position.lerp(grip + reel_hand_l_offset, _reel_blend)
		_hand_l.rotation = lerpf(_hand_l.rotation, deg, _reel_blend)

## 토하기 동작 — 잠깐 토하는 표정으로 머리를 바꾼다. VomitSkill이 토한 순간 호출한다.
## vomit_head_texture가 비어 있으면(주정뱅이 외 캐릭터) 아무 일도 안 한다
func play_vomit_face() -> void:
	if _head == null or vomit_head_texture == null:
		return
	_head.texture = vomit_head_texture
	if vomit_head_scale != Vector2.ZERO:
		_head.scale = vomit_head_scale
	_vomit_time = vomit_face_duration

## 상대 방어에 기본공격이 막혔을 때 — 때린 오른손과 거기 든 무기를 빨갛게 깜빡이게 한다.
## Fighter.play_weapon_blocked()가 **기본공격이 잠기는 시간을 그대로 넘겨주므로**
## "빨간 동안엔 못 때린다"가 항상 맞아떨어진다. 인자를 안 주면 이 노드의 export 값을 쓴다.
## 손은 모든 캐릭터에 있으므로 무기가 없는 캐릭터(고양이 아주머니 등)도 눈에 보인다
func play_weapon_blocked(duration: float = -1.0) -> void:
	_blocked_flash_span = duration if duration > 0.0 else blocked_flash_duration
	_blocked_flash_left = _blocked_flash_span
	# 3초 안에 또 막히면 여기로 다시 들어온다 — 붙어 있던 셰이더를 떼고 새로 붙인다
	_set_blocked_outline(true)

## 깜빡임을 매 프레임 갱신한다. 원래색(흰색 modulate) <-> blocked_flash_color를 오가면서
## 투명도도 같이 오르내린다 — 색이 진해질 때 가장 옅어져서 "지지직거리는" 느낌이 난다.
## **오른손(HandR)과 무기 걸이(HandRHold)에 따로 건다** — 둘은 부모-자식이 아니라 형제라서
## 한쪽에만 걸면 나머지가 안 물들고, 겹쳐 걸어도 색이 두 번 곱해지지 않는다
func _update_blocked_flash(delta: float) -> void:
	if _blocked_flash_left <= 0.0:
		return
	_blocked_flash_left = maxf(_blocked_flash_left - delta, 0.0)
	var tint: Color = Color.WHITE   # 끝났으면 원래 색으로 되돌린다
	var wave: float = 0.0
	if not is_zero_approx(_blocked_flash_left):
		# 0(원래색) -> 1(빨강) -> 0 을 blocked_flash_cycles번 왕복. cos이라 양 끝에서 부드럽게 멈춘다
		var elapsed: float = _blocked_flash_span - _blocked_flash_left
		var span: float = maxf(_blocked_flash_span, 0.001)
		wave = 0.5 - 0.5 * cos(elapsed / span * TAU * blocked_flash_cycles)
		tint = Color.WHITE.lerp(blocked_flash_color, wave)
		tint.a = lerpf(1.0, blocked_flash_min_alpha, wave)
	if _hand_r:
		_hand_r.modulate = tint
	if _hand_r_hold:
		_hand_r_hold.modulate = tint
	# 몸 전체 빨간 테두리도 같은 박자로 진해졌다 옅어진다. 다 끝나면 셰이더를 떼어낸다
	if _blocked_flash_left <= 0.0:
		_set_blocked_outline(false)
	else:
		_update_blocked_outline(lerpf(blocked_outline_min, 1.0, wave))

## 테두리를 두를 대상 — **손에 든 무기만**(2026-09-14 사용자 요청으로 몸 전체에서 줄였다).
## 머리·몸·손은 빼고, 오른손에 매달린 물건(소주병·키보드·사탕)과 평소 반대 손에 들고 있는
## 무기(일진 가방)만 두른다. 손 자체가 빨개지는 건 예전 `modulate` 깜빡임이 그대로 맡는다
func _blocked_outline_targets() -> Array:
	var list: Array = []
	# HandRHold는 Node2D라 자기 그림이 없다 — 매달린 자식 스프라이트를 넣는다
	if _hand_r_hold:
		for child in _hand_r_hold.get_children():
			if child is Sprite2D:
				list.append(child)
	# 마지막 타에만 무기를 쥐는 캐릭터는 평소엔 반대 손에 늘어뜨린 쪽이 보인다(일진 가방)
	if not idle_weapon.is_empty():
		var idle: Node = get_node_or_null(idle_weapon)
		if idle is Sprite2D:
			list.append(idle)
	return list

## 빨간 테두리를 켜고 끈다. 켤 때 파츠마다 ShaderMaterial을 새로 붙이고 끌 때 떼어낸다 —
## 잠기지 않은 동안에는 material이 아예 없으므로 평소 셰이더 비용이 0이다
func _set_blocked_outline(on: bool) -> void:
	for part in _blocked_outline_parts:
		if is_instance_valid(part):
			part.material = null
	_blocked_outline_parts.clear()
	if not on or blocked_outline_px <= 0.0:
		return
	_blocked_outline_parts = _blocked_outline_targets()
	for part in _blocked_outline_parts:
		var mat := ShaderMaterial.new()
		mat.shader = BLOCKED_OUTLINE_SHADER
		mat.set_shader_parameter("outline_color", blocked_outline_color)
		part.material = mat

## 깜빡임에 맞춰 테두리 진하기를 갱신한다. **두께는 매 프레임 다시 넣는다** —
## 표정이 바뀌면 머리 배율이 달라져서(hurt_head_scale 등) 화면상 두께가 같이 변하기 때문이다
func _update_blocked_outline(amount: float) -> void:
	for part in _blocked_outline_parts:
		if not is_instance_valid(part):
			continue
		var mat: ShaderMaterial = part.material as ShaderMaterial
		if mat == null:
			continue
		mat.set_shader_parameter("outline_width", blocked_outline_px / maxf(absf(part.scale.x), 0.0001))
		mat.set_shader_parameter("outline_alpha", amount)

## --- 림 라이트(윤곽광) ---
## 맵의 `RimLight` 노드가 매 프레임 `set_rim_light()`로 켜고 방향을 갱신한다(2026-10-08). 리그 전체가 **재질 하나를 같이 쓴다**.
## 빨간 테두리(`_set_blocked_outline`)·황금 손(`GOLD_SHADER`)이 파츠 material을 바꿨다가 null로 되돌리므로,
## 여기선 **material이 비어 있는 파츠에만** 붙이고 뗄 때도 **내 재질일 때만** 뗀다 — 그 둘이 끝나면 다음 호출에서 저절로 다시 붙는다
const RIM_LIGHT_SHADER := preload("res://characters/RimLight.gdshader")
var _rim_material: ShaderMaterial = null
## 지금 림 라이트 재질이 붙어 있는 파츠들
var _rim_parts: Array = []

## 림 라이트를 켜거나 갱신한다. params = {셰이더 uniform 이름: 값} — `light_dir`(캐릭터→광원, 월드), `rim_color`,
## `rim_strength`, `rim_px`, `shade_color`, `shade_strength`, `gradient_strength` …(`RimLight.gdshader` 참고). 매 프레임 불러도 된다
func set_rim_light(params: Dictionary) -> void:
	if _rim_material == null:
		_rim_material = ShaderMaterial.new()
		_rim_material.shader = RIM_LIGHT_SHADER
	for key in params:
		_rim_material.set_shader_parameter(key, params[key])
	_apply_rim_materials(self)

## 림 라이트를 끈다 — 내 재질이 붙은 파츠만 되돌린다
func clear_rim_light() -> void:
	for part in _rim_parts:
		if is_instance_valid(part) and part.material == _rim_material:
			part.material = null
	_rim_parts.clear()

## 그림이 있는 파츠(Sprite2D) 전부에 재질을 붙인다. 스크립트가 달린 스프라이트(핏줄·반짝이 표시)와
## 다른 재질이 이미 붙은 파츠는 건드리지 않는다
func _apply_rim_materials(node: Node) -> void:
	for child in node.get_children():
		if child is Sprite2D and child.get_script() == null:
			if child.material == null:
				child.material = _rim_material
				if not _rim_parts.has(child):
					_rim_parts.append(child)
		_apply_rim_materials(child)

## 피격 표정 — 맞은 순간 잠깐 아파하는 얼굴로 바꾼다. Fighter.take_damage가 호출한다.
## hurt_head_texture가 비어 있으면(그 표정이 없는 캐릭터) 아무 일도 안 한다
func play_hurt_face() -> void:
	if _head == null or hurt_head_texture == null:
		return
	_head.texture = hurt_head_texture
	# (0,0)이면 원래 머리 배율 — 안 넣으면 직전 표정(술 머금은 얼굴 등)의 배율이 남아 피격 머리가 커졌다(2026-09-29 주정뱅이)
	_head.scale = hurt_head_scale if hurt_head_scale != Vector2.ZERO else _head_rest_scale
	_hurt_time = hurt_face_duration

## 잠깐 바뀌었던 표정이 끝났을 때 — 아직 남아있는 다른 표정이 있으면 그쪽으로,
## 없으면 현재 상태(액션/취함/맨정신)에 맞는 기본 머리로 돌아간다.
## 피격 > 토하기 순으로 우선한다(맞는 게 더 급한 상황이라)
func _restore_head() -> void:
	if _head == null or _knocked_out:
		return
	if _hurt_time > 0.0 and hurt_head_texture != null:
		_head.texture = hurt_head_texture
		_head.scale = hurt_head_scale if hurt_head_scale != Vector2.ZERO else _head_rest_scale
		return
	if _vomit_time > 0.0 and vomit_head_texture != null:
		_head.texture = vomit_head_texture
		if vomit_head_scale != Vector2.ZERO:
			_head.scale = vomit_head_scale
		return
	_apply_base_head()

## 술 스택 유무에 따라 "기본 머리"를 정한다 (맨정신=원래 얼굴 / 취함=술 머금은 얼굴).
## DrinkSkill이 true, VomitSkill이 false로 부른다. 토하는 표정이 떠 있는 동안엔 건드리지 않고,
## 그 표정이 끝나면 _restore_head가 여기서 정한 기본 머리로 돌아간다
func set_drunk_head(on: bool) -> void:
	_drunk_head_on = on
	if _vomit_time <= 0.0 and _hurt_time <= 0.0:
		_apply_base_head()

## 스킬(자전거 돌진·총 쏘기)을 쓰는 동안 액션 표정으로 머리를 바꾼다. on=false면 원래 상태로 되돌린다.
## action_head_texture가 비어 있으면(그 표정이 없는 캐릭터) 아무 일도 안 한다
func set_action_face(on: bool) -> void:
	if _head == null or action_head_texture == null:
		return
	_action_face_on = on
	if _vomit_time <= 0.0 and _hurt_time <= 0.0:   # 잠깐 바뀐 표정이 떠 있으면 그게 끝난 뒤 반영된다
		_apply_base_head()

## 현재 상태에 맞는 머리 그림·배율을 머리에 적용한다 (액션 표정 > 취함 > 맨정신 순 우선).
## 액션 표정이 맨 위인 이유: 스킬을 쓰는 순간만큼은 그 표정이 보여야 한다.
## (HP가 적을 때의 지친 얼굴은 2026-09-26 사용자 요청으로 전 캐릭터에서 뺐다)
func _apply_base_head() -> void:
	if _head == null or _knocked_out:
		return
	var run_face_tex: Texture2D = _run_face_now()
	if run_face_tex != null:
		# 런닝머신에서 달리는 동안은 한 가지 얼굴만 쓴다
		_head.texture = run_face_tex
		var run_base: Vector2 = run_face_scale if run_face_scale != Vector2.ZERO else _head_rest_scale
		_head.scale = run_base * _curl_face_fit(run_face_tex)
		return
	var squat_face: Texture2D = _squat_face()
	if squat_face != null:
		# 스쿼트 중에는 **허리를 펴고 선 순간만** 쉬는 얼굴이고 나머지는 힘주는 얼굴이다
		_head.texture = squat_face
		var sq_base: Vector2 = squat_face_scale if squat_face_scale != Vector2.ZERO else _head_rest_scale
		_head.scale = sq_base * _curl_face_fit(squat_face)
		return
	var curl_face: Texture2D = _curl_face()
	if curl_face != null:
		# 바벨을 드는 동안은 올릴 때·내릴 때 얼굴이 다르다 — 제일 위에 둔다
		_head.texture = curl_face
		var base: Vector2 = curl_face_scale if curl_face_scale != Vector2.ZERO else _head_rest_scale
		_head.scale = base * _curl_face_fit(curl_face)
	elif _hug_face_on and hug_head_texture != null:
		# 아이를 안고 어르는 표정이 제일 위다 — 안고 있는 동안은 다른 표정이 끼어들 일이 없다
		_head.texture = hug_head_texture
		_head.scale = hug_head_scale if hug_head_scale != Vector2.ZERO else _head_rest_scale
	elif _action_face_on and action_head_texture != null:
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

## 총 조준 자세 — 주머니에서 총을 꺼내(꺼내는 시간 _gun_draw_time) 두 손을 모아 앞으로 겨눈다.
## ① 빈손이 주머니로 쑥 내려간다(총 안 보임) ② 총을 쥔 채 총구가 아래를 보던 각도에서 수평으로 돌며 조준 자리까지 휙 뽑아 올리고,
## 왼손이 따라와 그립을 받친다 ③ 겨눈 채 유지. 발사 반동이 있으면 뒤로 살짝 밀어낸다 (걷기 동작보다 우선)
func _pose_gun() -> void:
	var elapsed: float = _gun_duration - _gun_time
	var t: float = clampf(elapsed / maxf(_gun_draw_time, 0.001), 0.0, 1.0)
	var rest_r: Vector2 = _rest_positions[_hand_r] if _hand_r else Vector2.ZERO
	var rest_l: Vector2 = _rest_positions[_hand_l] if _hand_l else Vector2.ZERO
	var grip: Vector2
	var gun_deg: float = 0.0
	var show_gun: bool = true
	var gun_pop: float = 1.0
	var left_t: float = 1.0
	var pocket_ratio: float = clampf(gun_pocket_ratio, 0.0, 0.9)
	if t < pocket_ratio:
		# ① 빈손이 주머니로
		var k: float = t / maxf(pocket_ratio, 0.001)
		grip = rest_r.lerp(gun_pocket_offset, k * k * (3.0 - 2.0 * k))
		show_gun = false
		left_t = 0.0
	else:
		# ② 휙 뽑아 올리기 — 끝에서 감속(ease out)해 조준 자리에 탁 멈춘다
		var k: float = (t - pocket_ratio) / maxf(1.0 - pocket_ratio, 0.001)
		var e: float = 1.0 - pow(1.0 - k, 3.0)
		grip = gun_pocket_offset.lerp(gun_aim_offset, e) + Vector2(0.0, -gun_pull_arc * sin(PI * k))
		gun_deg = gun_pocket_deg * (1.0 - e)
		# 주머니에서 막 나올 때 살짝 작게 시작해 커진다(꺼내는 느낌)
		gun_pop = lerpf(0.75, 1.0, clampf(k / 0.35, 0.0, 1.0))
		left_t = e
	# ④ 다 쏘면 다시 주머니에 넣는다(2026-09-29 사용자 요청) — 동작 맨 끝 _gun_holster_time 동안 꺼낼 때를 거꾸로:
	# 총구가 아래로 돌며 주머니 자리로 쑥 내려가 작아지고, 왼손은 놓고 제자리로. 앞 gun_holster_hide 비율에서 총이 사라지고 빈손만 돌아온다
	if _gun_holster_time > 0.0 and _gun_time < _gun_holster_time and t >= 1.0:
		var h: float = 1.0 - _gun_time / _gun_holster_time
		var hide_at: float = clampf(gun_holster_hide, 0.05, 1.0)
		if h < hide_at:
			var k: float = h / hide_at
			var e: float = k * k   # 처음엔 천천히, 넣을 때 쑥
			grip = gun_aim_offset.lerp(gun_pocket_offset, e)
			gun_deg = gun_pocket_deg * e
			gun_pop = lerpf(1.0, 0.75, e)
			left_t = 1.0 - clampf(k * 1.6, 0.0, 1.0)
		else:
			var k: float = (h - hide_at) / maxf(1.0 - hide_at, 0.001)
			grip = gun_pocket_offset.lerp(rest_r, k * k * (3.0 - 2.0 * k))
			show_gun = false
			left_t = 0.0
	# 발사 반동 — 뒤(-x)로 밀리며 살짝 들린다(-y)
	grip += Vector2(-gun_recoil_kick, -gun_recoil_kick * 0.4) * _recoil
	if _hand_r:
		_hand_r.position = grip
		_hand_r.rotation = 0.0
	if _hand_l:
		_hand_l.position = rest_l.lerp(grip + gun_hand_l_offset, left_t)
		_hand_l.rotation = 0.0
	if _gun:
		var rad: float = deg_to_rad(gun_deg)
		_gun.visible = show_gun
		_gun.position = grip + gun_forward_offset.rotated(rad)
		_gun.rotation = rad
		if _gun_rest_scale != Vector2.ZERO:
			_gun.scale = _gun_rest_scale * gun_pop

## 짜장면 먹기 자세 — 앞 eat_pull_ratio: 빈손이 주머니로 갔다 그릇을 쥐고 가슴 앞으로 꺼낸다(작게 시작해 커짐),
## 가운데: 왼손이 그릇 밑을 받치고 오른손이 그릇 <-> 입을 오가며 고개를 숙여 끄덕인다,
## 끝 eat_put_ratio: 그릇을 다시 주머니로 넣고(작아지며 사라짐) 빈손이 제자리로
func _pose_eat() -> void:
	if _eat_bowl == null:
		return
	var p: float = 1.0 - _eat_time / maxf(_eat_duration, 0.001)
	var pull: float = clampf(eat_pull_ratio, 0.05, 0.6)
	var put: float = clampf(eat_put_ratio, 0.05, 0.6)
	var rest_r: Vector2 = _rest_positions[_hand_r] if _hand_r else Vector2.ZERO
	var rest_l: Vector2 = _rest_positions[_hand_l] if _hand_l else Vector2.ZERO
	var bowl_at: Vector2 = eat_bowl_offset
	var hand_r: Vector2 = eat_bowl_offset
	var left_t: float = 1.0   # 왼손이 그릇 밑으로 와 있는 정도
	var head_t: float = 1.0   # 고개를 숙인 정도
	var bob: float = 0.0
	var bowl_shown: bool = true
	var pop: float = 1.0
	if p < pull:
		var k: float = p / pull
		if k < 0.4:
			# ① 빈손이 주머니로
			var a: float = k / 0.4
			hand_r = rest_r.lerp(eat_pocket_offset, a * a * (3.0 - 2.0 * a))
			bowl_shown = false
			left_t = 0.0
		else:
			# ② 그릇을 꺼내 가슴 앞으로 — 끝에서 감속
			var a: float = (k - 0.4) / 0.6
			var e: float = 1.0 - pow(1.0 - a, 3.0)
			bowl_at = eat_pocket_offset.lerp(eat_bowl_offset, e)
			hand_r = bowl_at
			pop = lerpf(0.5, 1.0, e)
			left_t = e
		head_t = clampf((k - 0.4) / 0.6, 0.0, 1.0)
	elif p > 1.0 - put:
		var k: float = (p - (1.0 - put)) / put
		if k < 0.6:
			# ④ 그릇을 주머니로 — 처음엔 천천히, 넣을 때 쑥
			var a: float = k / 0.6
			bowl_at = eat_bowl_offset.lerp(eat_pocket_offset, a * a)
			hand_r = bowl_at
			pop = lerpf(1.0, 0.5, a)
			left_t = 1.0 - clampf(a * 1.6, 0.0, 1.0)
		else:
			# 빈손이 제자리로
			var a: float = (k - 0.6) / 0.4
			hand_r = eat_pocket_offset.lerp(rest_r, a * a * (3.0 - 2.0 * a))
			bowl_shown = false
			left_t = 0.0
		head_t = 1.0 - clampf(k / 0.6, 0.0, 1.0)
	else:
		# ③ 떠먹기 — 그릇(0) <-> 입(1)을 eat_bites번. 입에 닿는 순간 고개가 끄덕
		var k: float = (p - pull) / maxf(1.0 - pull - put, 0.001)
		var lift: float = 0.5 - 0.5 * cos(k * TAU * eat_bites)
		hand_r = eat_bowl_offset.lerp(eat_mouth_offset, lift)
		bob = lift * eat_head_bob
	if _hand_r:
		_hand_r.position = hand_r
		_hand_r.rotation = 0.0
	if _hand_l:
		_hand_l.position = rest_l.lerp(bowl_at + eat_hand_l_offset, left_t)
		_hand_l.rotation = 0.0
	if _head:
		_head.rotation = deg_to_rad(eat_head_tilt_deg * head_t)
		_head.position = _rest_positions[_head] + Vector2(0.0, bob)
	_eat_bowl.visible = bowl_shown
	_eat_bowl.position = bowl_at
	_eat_bowl.rotation = 0.0
	_eat_bowl.scale = _eat_bowl_rest_scale * pop

## 어퍼컷을 치는 동안 고개·상체가 점점 돌아가는 부분.
## **발은 건드리지 않는다**(러프: 발 위치 고정) — 돌아가는 건 상체와 고개뿐이다.
## 각도는 `scale.x = -1`로 좌우를 뒤집어도 같이 안 뒤집히므로, 바라보는 방향 부호를 곱해준다
## 베기 한 번 동안 상체·고개가 따라 넘어간다 — 감을 땐 뒤로 젖혔다가 후릴 때 확 넘어가고 천천히 돌아온다.
## 손 궤도(`_pose_attack_hand`)와 **같은 구간 비율**(40% / 62%)을 쓰므로 둘이 따로 놀지 않는다
func _pose_slash_lean() -> void:
	var sl: Dictionary = SLASHES[(_attack_variant - SLASH_VARIANT_BASE) % SLASHES.size()]
	var progress: float = 1.0 - _attack_time / maxf(_attack_len, 0.001)
	var t: float
	if progress < ATTACK_STRIKE_START:
		# ① 감기 — 반대쪽으로 살짝 젖힌다
		t = -0.55 * (progress / ATTACK_STRIKE_START)
	elif progress < ATTACK_STRIKE_END:
		# ② 후리기 — 젖힌 데서 확 넘어간다(가속 곡선이라 손과 같은 박자)
		var p: float = (progress - ATTACK_STRIKE_START) / (ATTACK_STRIKE_END - ATTACK_STRIKE_START)
		t = lerpf(-0.55, 1.0, p * p)
	else:
		# ③ 복귀
		var p: float = (progress - ATTACK_STRIKE_END) / (1.0 - ATTACK_STRIKE_END)
		t = lerpf(1.0, 0.0, p)
	# **기울기에 facing 부호를 곱한다** — 좌우 반전이 scale.x = -1이라 각도는 그대로 남는다(발차기·돌진과 같은 이유)
	var sgn: float = 1.0
	if _fighter != null and is_instance_valid(_fighter) and not is_zero_approx(_fighter.facing):
		sgn = signf(_fighter.facing)
	var lean: float = deg_to_rad(float(sl.get("lean_deg", 12.0)) * slash_lean_scale) * t * sgn
	if _body:
		_body.rotation += lean
	if _head:
		_head.rotation += lean * 0.6

func _pose_uppercut_lean() -> void:
	var progress: float = 1.0 - _attack_time / maxf(_attack_len, 0.001)
	var sgn: float = signf(_fighter.facing) if (_fighter != null and is_instance_valid(_fighter)) else 1.0
	if sgn == 0.0:
		sgn = 1.0

	# 어퍼컷은 세 박자다(2026-09-30 러프 3프레임):
	#  ① 감기 — **시계로 말면서 몸을 낮춘다**
	#  ② 버티기 — 낮은 자세 그대로 잠깐 멈춘다(`uppercut_hold`)
	#  ③ 올려치기 — **반시계로 젖히면서 솟는다**. 말았던 몸을 펴는 힘으로 친다
	var turn_deg: float
	var lift: float
	var reach: float   # 발 보폭·앞으로 나가기에 쓰는 0~1 진행도
	if progress < ATTACK_STRIKE_START:
		var w: float = progress / ATTACK_STRIKE_START
		w = w * w * (3.0 - 2.0 * w)
		turn_deg = uppercut_turn_deg * w
		lift = uppercut_crouch * w
		reach = w * 0.5
	else:
		# 때리는 구간(0~1)과 복귀 구간(1~2)을 한 줄로 이어서 센다
		var m: float = (progress - ATTACK_STRIKE_START) / (ATTACK_STRIKE_END - ATTACK_STRIKE_START)
		if progress >= ATTACK_STRIKE_END:
			m = 1.0 + (progress - ATTACK_STRIKE_END) / (1.0 - ATTACK_STRIKE_END)
		if m <= uppercut_hold:
			turn_deg = uppercut_turn_deg
			lift = uppercut_crouch
			reach = 0.5
		elif m <= 1.0:
			var k: float = (m - uppercut_hold) / maxf(1.0 - uppercut_hold, 0.01)
			k = k * k   # 끝으로 갈수록 확 펴진다
			turn_deg = lerpf(uppercut_turn_deg, uppercut_turn_back_deg, k)
			lift = lerpf(uppercut_crouch, -uppercut_rise, k)
			reach = lerpf(0.5, 1.0, k)
		else:
			var r: float = clampf(m - 1.0, 0.0, 1.0)
			var e: float = 1.0 - (1.0 - r) * (1.0 - r)
			turn_deg = lerpf(uppercut_turn_back_deg, 0.0, e)
			lift = lerpf(-uppercut_rise, 0.0, e)
			reach = 1.0 - e

	# **머리 위 축을 중심으로 머리와 몸통을 통째로 돌린다.** 두 파츠의 "지금 자리"를 축 기준으로
	# 같이 회전시키므로, 매달린 상체가 한 덩어리로 넘어가는 그림이 된다
	var angle: float = deg_to_rad(turn_deg) * sgn
	var pivot: Vector2 = Vector2(uppercut_pivot.x * sgn, uppercut_pivot.y)
	var shift := Vector2(uppercut_body_forward * reach * sgn, lift)
	# **치는 손도 같이 돈다** — 몸 따로 손 따로 돌면 팔만 휘젓는 것처럼 보인다.
	# 손은 자기 궤도(_pose_attack_hand가 잡아 둔 자리)를 가진 채로, 그 자리를 축 기준으로 같이 돌린다
	var parts: Array = [_body, _head]
	var punch: Sprite2D = _attack_hand()
	if punch:
		parts.append(punch)
	for part in parts:
		if part == null:
			continue
		var here: Vector2 = part.position + (shift if part != punch else Vector2.ZERO)
		part.position = pivot + (here - pivot).rotated(angle)
		part.rotation = angle
	if _head and not is_zero_approx(uppercut_head_extra_deg):
		_head.rotation += deg_to_rad(uppercut_head_extra_deg * reach) * sgn

	# **앞발(오른발)이 한 발짝 내딛는다.** 감는 동안에 다 내딛고, 치는 동안엔 그 자리를 지킨다.
	# 뒷발과 높이는 안 건드린다 — 디딘 발이 땅에 붙어 있어야 버티고 치는 그림이 된다
	if not is_zero_approx(uppercut_step) and _foot_r and _rest_positions.has(_foot_r):
		var step_t: float = clampf(reach / 0.5, 0.0, 1.0)
		_foot_r.position.x = _rest_positions[_foot_r].x + uppercut_step * step_t * sgn

## 이번 타가 맨손 박치기인지
func _is_headbutt() -> bool:
	return unarmed_headbutt and not held_item_armed and _attack_time > 0.0 and _attack_variant >= final_hit_index

## 박치기 동안 상체(몸통·머리·두 손)를 엉덩이 축으로 통째로 돌린다 — 뒤로 젖혀 머리를 치켜들었다가
## 앞 아래로 내리찍고 돌아온다. 발은 안 건드린다.
## 조각의 **로컬 좌표**에서 돌리므로 좌우 반전(리그 scale.x = -1)에 저절로 맞는다 — 방향 부호를 곱하면 안 된다(_lay_down과 같은 이유)
func _pose_headbutt() -> void:
	var progress: float = 1.0 - _attack_time / maxf(_attack_len, 0.001)
	var turn_deg: float
	var lift: float
	var reach: float
	var nod: float = 0.0
	if progress < ATTACK_STRIKE_START:
		# 감기 — 뒤로 젖히며 살짝 솟는다(끝으로 갈수록 천천히)
		var w: float = progress / ATTACK_STRIKE_START
		w = 1.0 - (1.0 - w) * (1.0 - w)
		turn_deg = headbutt_back_deg * w
		lift = -headbutt_rise * w
		reach = 0.0
	elif progress < ATTACK_STRIKE_END:
		# 치기 — 젖힌 몸을 앞 아래로 확 내리찍는다(끝으로 갈수록 빨라짐)
		var k: float = (progress - ATTACK_STRIKE_START) / (ATTACK_STRIKE_END - ATTACK_STRIKE_START)
		k = k * k
		turn_deg = lerpf(headbutt_back_deg, headbutt_slam_deg, k)
		lift = lerpf(-headbutt_rise, 0.0, k)
		reach = k
		nod = k
	else:
		# 복귀 — 숙인 자세에서 천천히 일어난다
		var r: float = clampf((progress - ATTACK_STRIKE_END) / (1.0 - ATTACK_STRIKE_END), 0.0, 1.0)
		var e: float = r * r * (3.0 - 2.0 * r)
		turn_deg = lerpf(headbutt_slam_deg, 0.0, e)
		lift = 0.0
		reach = 1.0 - e
		nod = 1.0 - e
	var angle: float = deg_to_rad(turn_deg)
	var pivot: Vector2 = headbutt_pivot
	var shift := Vector2(headbutt_forward * reach, lift)
	for part in [_body, _head, _hand_l, _hand_r]:
		if part == null:
			continue
		var here: Vector2 = part.position + shift
		part.position = pivot + (here - pivot).rotated(angle)
		part.rotation += angle
	if _head:
		_head.rotation += deg_to_rad(headbutt_nod_deg * nod)

## 어퍼컷 궤도를 눈으로 보여준다 — `uppercut_debug_path`를 켜면 시작점(초록)·끝점(빨강)과
## 휘어 가는 길(노랑)을 그린다. 값을 고치고 바로 확인하라고 만든 것이라 게임에서는 꺼 둔다
func _draw() -> void:
	if not uppercut_debug_path:
		return
	var a: Vector2 = uppercut_start
	var b: Vector2 = uppercut_end
	var pts := PackedVector2Array()
	for i in range(21):
		var k: float = float(i) / 20.0
		var base: Vector2 = a.lerp(b, k)
		# _swing_arc와 같은 방식으로 휜다 — 직선에 수직으로 볼록하게
		var dir: Vector2 = (b - a).normalized()
		var normal := Vector2(-dir.y, dir.x)
		pts.append(base + normal * uppercut_arc * sin(PI * k))
	draw_polyline(pts, Color(1, 0.9, 0.2, 0.9), 2.0)
	draw_circle(a, 4.0, Color(0.2, 1.0, 0.3, 0.95))
	draw_circle(b, 4.0, Color(1.0, 0.3, 0.3, 0.95))
	draw_circle(uppercut_pivot, 3.0, Color(0.4, 0.7, 1.0, 0.95))

## 특수 idle 몸짓을 시작한다
func _start_special() -> void:
	_special_time = special_duration
	_hiccups_fired = 0

## 특수 idle 몸짓을 끝낸다 — 앞으로 끌어낸 왼손 그리는 순서를 되돌린다
func _end_special() -> void:
	_special_time = 0.0
	if _hand_l:
		_hand_l.z_index = _hand_l_rest_z

## 특수 idle 몸짓을 지금 바로 한다(훈련장 테스트 버튼용). 몸짓이 없는 캐릭터면 false
func play_special() -> bool:
	if idle_special == 0:
		return false
	_end_lookback()
	_scratch_time = 0.0
	_idle_time = 0.0
	_start_special()
	return true

func _pose_special() -> void:
	var elapsed: float = special_duration - _special_time
	var progress: float = elapsed / maxf(special_duration, 0.001)
	match idle_special:
		1:
			_pose_glasses_push(progress)
		2:
			_pose_hiccup(elapsed)

## 안경 치켜올리기 — 왼손이 코받침으로 올라가(0~30%) 쓱 밀어 올리고(35~55%) 잠깐 머물다(~75%) 내려온다.
## 왼손은 원래 머리 뒤에 그려지므로 올라가 있는 동안만 머리 앞으로 끌어낸다
func _pose_glasses_push(progress: float) -> void:
	if _hand_l == null:
		return
	var reach: float
	if progress < 0.3:
		var p: float = progress / 0.3
		reach = 1.0 - (1.0 - p) * (1.0 - p)
	elif progress < 0.75:
		reach = 1.0
	else:
		var p2: float = (progress - 0.75) / 0.25
		reach = 1.0 - p2 * p2 * (3.0 - 2.0 * p2)
	var push: float = sin(PI * clampf((progress - 0.35) / 0.2, 0.0, 1.0))
	_hand_l.position = _hand_l.position.lerp(glasses_hand_pos + Vector2(0.0, -glasses_push * push), reach)
	_hand_l.rotation = lerpf(_hand_l.rotation, deg_to_rad(glasses_hand_deg), reach)
	_hand_l.z_index = 3 if reach > 0.05 else _hand_l_rest_z
	if _head:
		_head.position.y -= glasses_push_lift * push
		_head.rotation += deg_to_rad(glasses_push_deg) * push

## 딸꾹질 — 몸짓 시간 안에 hiccup_count번, 딸꾹할 때마다 머리가 톡 튀며 젖혀지고 몸·손도 살짝 따라 뜬다.
## 딸꾹할 때마다 머리 위에 글자를 띄운다
func _pose_hiccup(elapsed: float) -> void:
	var count: int = maxi(hiccup_count, 1)
	var pulse: float = 0.0
	for k in count:
		var at: float = special_duration * (0.12 + 0.72 * float(k) / count)
		var local: float = (elapsed - at) / 0.28
		if local >= 0.0 and k >= _hiccups_fired:
			_hiccups_fired = k + 1
			_spawn_hiccup_text()
		if local >= 0.0 and local < 1.0:
			# 순식간에 튀고(앞 20%) 천천히 내려앉는다
			var v: float = local / 0.2 if local < 0.2 else 1.0 - (local - 0.2) / 0.8
			pulse = maxf(pulse, v)
	if pulse <= 0.0:
		return
	if _head:
		_head.position.y -= hiccup_hop * pulse
		_head.rotation += deg_to_rad(hiccup_deg) * pulse
	if _body:
		_body.position.y -= hiccup_hop * 0.4 * pulse
	for hand in [_hand_l, _hand_r]:
		if hand:
			hand.position.y -= hiccup_hop * 0.5 * pulse

## 머리 위에 "딸꾹!"을 띄워 올렸다가 흐리게 사라지게 한다 — 리그가 좌우로 뒤집혀도 글자는 안 뒤집히게 top_level로 둔다
func _spawn_hiccup_text() -> void:
	if hiccup_text.is_empty() or _head == null or Engine.is_editor_hint():
		return
	var label := Label.new()
	label.text = hiccup_text
	label.top_level = true
	label.z_index = 60
	label.add_theme_font_override("font", load("res://fonts/Jua-Regular.ttf"))
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.04))
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	label.reset_size()
	var start: Vector2 = _head.global_position + Vector2(8.0 * signf(scale.x), -44.0) - label.size * 0.5
	label.global_position = start
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", start + Vector2(0.0, -18.0), 0.65).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.35)
	tween.chain().tween_callback(label.queue_free)

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

## 머리를 돌리는 그림으로 바꿔 끼울 준비가 됐는지 — 그림마다 기준점·방향이 다 있고(0번 옆모습 포함), 머리가 평소 얼굴(또는 이미 돌리는 중)일 때만
func _can_head_turn() -> bool:
	var count: int = _turn_textures().size()
	if _head == null or count < 1 or _turn_anchors().size() < count + 1 or _turn_faces_left().size() < count + 1:
		return false
	return _is_turn_texture(_head.texture)

## 액션 표정 전용 머리 돌리기 세트가 다 채워져 있는지
func _has_action_turn_set() -> bool:
	var count: int = action_head_turn_textures.size()
	return action_head_texture != null and count >= 1 and action_head_turn_anchors.size() >= count + 1 and action_head_turn_faces_left.size() >= count + 1

## 지금 쓸 머리 돌리기 세트인지 — 액션 표정이 켜져 있고 전용 세트가 있으면 그쪽
func _use_action_turn_set() -> bool:
	return _action_face_on and _has_action_turn_set()

func _turn_textures() -> Array[Texture2D]:
	return action_head_turn_textures if _use_action_turn_set() else head_turn_textures

func _turn_anchors() -> Array[Vector3]:
	return action_head_turn_anchors if _use_action_turn_set() else head_turn_anchors

func _turn_faces_left() -> Array[bool]:
	return action_head_turn_faces_left if _use_action_turn_set() else head_turn_faces_left

## 돌기 전 옆모습(0번) 그림과 그 배율 — 액션 표정 세트면 액션 표정 그림
func _turn_rest_texture() -> Texture2D:
	return action_head_texture if _use_action_turn_set() else _head_rest_texture

func _turn_rest_scale() -> Vector2:
	if _use_action_turn_set() and action_head_scale != Vector2.ZERO:
		return action_head_scale
	return _head_rest_scale

## 평소 얼굴이거나 머리 돌리기용 그림(측면·정면·뒤통수)인지 — 이 밖의 그림이면 다른 표정이 들어온 것이다.
## 액션 표정은 전용 세트가 있을 때만 돌리기 그림으로 친다(돌던 중에 표정이 켜지고 꺼져도 이어서 돌도록 두 세트를 다 본다)
func _is_turn_texture(tex: Texture2D) -> bool:
	if tex == null:
		return false
	if tex == _head_rest_texture or head_turn_textures.has(tex) or tex == head_back_texture:
		return true
	return _has_action_turn_set() and (tex == action_head_texture or action_head_turn_textures.has(tex))

## 머리를 돌리는 단계 그림 하나로 바꿔 끼운다. frame: 0 옆 / 1~ head_turn_textures 순서(마지막이 정면).
## dir: 1이면 바라보는 쪽, -1이면 그 반대쪽(그림을 한 번 더 뒤집는다 = 뒤를 본다).
## 머리 공 중심이 평소 옆모습과 같은 자리, 지름이 같은 크기가 되도록 배율·위치를 계산한다.
## 걷기 들썩임·움찔 같은 앞선 자세 오프셋은 그대로 두고 제자리 차이만 더한다
## body_dir을 따로 주면 **몸통만 다른 쪽**을 보게 할 수 있다 —
## 뒤돌아보기는 "몸은 그대로, 머리만 반대쪽"이라 몸통까지 뒤집으면 안 된다.
## 평소 몸통이 정면인 캐릭터는 뒤집혀도 티가 안 났지만, 층간소음 빌런처럼 **측면 몸통**이면
## 뒤돌아볼 때마다 몸이 홱 뒤집혀 보인다(2026-10-04 지적)
func _set_head_frame(frame: int, dir: float, body_dir: float = NAN) -> void:
	var tex: Texture2D = _turn_rest_texture() if frame == 0 else _turn_textures()[frame - 1]
	_set_head_image(tex, _turn_anchors()[frame], _turn_faces_left()[frame], dir)
	_set_body_frame(frame, dir if is_nan(body_dir) else body_dir)

## 머리 단계(frame, 0 = 옆 ~ 머리 그림 수 = 정면)에 맞춰 몸통 그림을 바꿔 끼운다.
## 머리가 옆(0)이거나 정면(마지막)이면 원래 몸통(정면), 그 사이 단계에만 body_turn_textures를 나눠 끼운다 —
## 사이 단계 수와 그림 수가 달라도 내림 비율로 맞춘다(머리 측면1·2 -> 3/4, 측면3 -> 거의 정면).
## 몸통 그림은 전부 오른쪽을 보고 그려져 있어 dir(반대쪽이면 -1)만큼 뒤집고, **바닥 가운데**가 원래 자리에 오게 위치를 더한다
func _set_body_frame(head_frame: int, dir: float) -> void:
	if _body == null or body_turn_textures.is_empty() or _body_rest_texture == null:
		return
	var nh: int = maxi(_turn_textures().size(), 1)
	var tex: Texture2D = _body_rest_texture
	# 이 그림을 좌우로 뒤집을 양 — 보통 dir, 왼쪽을 보고 그린 그림이면 그 반대
	var flip: float = dir
	if head_frame > 0 and (body_turn_full or head_frame < nh):
		# 마지막 단계까지 쓰는 캐릭터는 단계 수를 하나 더 쳐서 그림을 끝까지 나눠 쓴다
		var middle: int = nh if body_turn_full else maxi(nh - 1, 1)
		var i: int = clampi(int(floor(float(head_frame - 1) * body_turn_textures.size() / middle)), 0, body_turn_textures.size() - 1)
		tex = body_turn_textures[i]
		if i < body_turn_faces_left.size() and body_turn_faces_left[i]:
			flip = -dir
	var sx: float = absf(_body_rest_scale.x)
	var sy: float = _body_rest_scale.y
	var rest_anchor: Vector2 = _body_anchor_of(_body_rest_texture)
	var here: Vector2 = _body_anchor_of(tex)
	# 캔버스가 다른 그림이면 불투명 영역 높이를 원래 몸통에 맞춘다(바닥 가운데 계산도 그 배율로)
	var k: float = 1.0
	if body_turn_match_height and tex != _body_rest_texture:
		k = _body_height_of(_body_rest_texture) / maxf(_body_height_of(tex), 1.0)
	_body.texture = tex
	_body.scale = Vector2(sx * k * flip, sy * k)
	_body.position += Vector2((rest_anchor.x - here.x * k * flip) * sx, (rest_anchor.y - here.y * k) * sy)
	_turn_applied = true

## 몸통 그림의 "바닥 가운데"(불투명 영역 가로 가운데·맨 아래)가 캔버스 가운데에서 얼마나 떨어졌는지 — 그림마다 한 번만 잰다
func _body_anchor_of(tex: Texture2D) -> Vector2:
	if tex == null:
		return Vector2.ZERO
	var used: Rect2 = _opaque_rect_of(tex)
	return Vector2(used.position.x + used.size.x * 0.5 - tex.get_width() * 0.5, used.end.y - tex.get_height() * 0.5)

## 몸통 그림의 불투명 영역 높이(px)
func _body_height_of(tex: Texture2D) -> float:
	if tex == null:
		return 1.0
	return maxf(_opaque_rect_of(tex).size.y, 1.0)

## 그림에서 **확실히 보이는(알파 절반 이상)** 영역 — 그림마다 한 번만 잰다.
## Image.get_used_rect()는 알파가 0만 아니면 세서, 눈에 안 보이는 점 하나(알파 1/255)에도 영역이 늘어난다
## (악플러 몸 측면 3 맨 아래 점 하나 때문에 높이가 120px 크게 재져 몸통이 떠 보였다, 2026-09-28).
## 4px 간격으로만 훑는다(887px 그림 기준 한 번 20만 번 -> 5만 번) — 게임 배율(~0.03)에선 오차가 안 보인다
func _opaque_rect_of(tex: Texture2D) -> Rect2:
	# 그림 자체가 아니라 경로로 기억한다 — static 사전에 그림을 넣어 두면 게임을 끌 때 "resources still in use" 경고가 난다
	var key: String = tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id())
	if _opaque_rect_cache.has(key):
		return _opaque_rect_cache[key]
	var rect := Rect2(Vector2.ZERO, tex.get_size())
	var img: Image = tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		const STEP := 4
		var w: int = img.get_width()
		var h: int = img.get_height()
		var min_x: int = w
		var min_y: int = h
		var max_x: int = -1
		var max_y: int = -1
		for y in range(0, h, STEP):
			for x in range(0, w, STEP):
				if img.get_pixel(x, y).a >= 0.5:
					min_x = mini(min_x, x)
					max_x = maxi(max_x, x)
					min_y = mini(min_y, y)
					max_y = maxi(max_y, y)
		if max_x >= 0:
			rect = Rect2(min_x, min_y, max_x - min_x + STEP, max_y - min_y + STEP)
	_opaque_rect_cache[key] = rect
	return rect

## 몸통을 원래 그림·배율로 되돌린다(위치는 매 프레임 _apply_pose가 제자리로 다시 잡는다)
func _clear_body_frame() -> void:
	if _body == null or _body_rest_texture == null or body_turn_textures.is_empty():
		return
	_body.texture = _body_rest_texture
	_body.scale = _body_rest_scale

## 지금 입은 몸통(그림·배율·제자리·몸 돌리기 그림) — set_body_outfit()으로 되돌릴 때 쓴다
func get_body_outfit() -> Dictionary:
	if _body == null:
		return {}
	return {"texture": _body_rest_texture, "scale": _body_rest_scale, "position": _rest_positions.get(_body, _body.position), "turn": body_turn_textures}

## 몸통을 통째로 갈아입힌다(황근출 궁 옷 벗기, 2026-10-02) — 평소 그림·배율·제자리·몸 돌리기 그림을 한 번에 바꾼다.
## outfit은 get_body_outfit()과 같은 모양
func set_body_outfit(outfit: Dictionary) -> void:
	if _body == null or outfit.is_empty():
		return
	_clear_body_frame()
	_body_rest_texture = outfit["texture"]
	_body_rest_scale = outfit["scale"]
	_rest_positions[_body] = outfit["position"]
	body_turn_textures = outfit["turn"]
	_body.texture = _body_rest_texture
	_body.scale = _body_rest_scale
	_body.position = _rest_positions[_body]

## 지금 쓴 머리(평소 그림·배율·제자리·머리 돌리기 세트) — set_head_outfit()으로 되돌릴 때 쓴다
func get_head_outfit() -> Dictionary:
	if _head == null:
		return {}
	return {"texture": _head_rest_texture, "scale": _head_rest_scale, "position": _rest_positions.get(_head, _head.position),
		"turn": head_turn_textures, "anchors": head_turn_anchors, "faces_left": head_turn_faces_left,
		"hurt": hurt_head_texture, "hurt_scale": hurt_head_scale, "hurt_offset": hurt_head_offset}

## 머리를 통째로 바꿔 쓴다(고양이 아주머니 주황 궁 고양이 옷, 2026-10-05) — 평소 그림·배율·제자리·머리 돌리기 세트를 한 번에 바꾼다.
## outfit은 get_head_outfit()과 같은 모양. 돌던 중이면 먼저 평소 머리로 되돌린 뒤 바꾼다
func set_head_outfit(outfit: Dictionary) -> void:
	if _head == null or outfit.is_empty():
		return
	_clear_head_frame()
	_head_rest_texture = outfit["texture"]
	_head_rest_scale = outfit["scale"]
	_rest_positions[_head] = outfit["position"]
	head_turn_textures = outfit["turn"]
	head_turn_anchors = outfit["anchors"]
	head_turn_faces_left = outfit["faces_left"]
	# 피격 얼굴도 옷마다 따로(없으면 원래 것을 그대로 둔다)
	if outfit.has("hurt"):
		hurt_head_texture = outfit["hurt"]
		hurt_head_scale = outfit.get("hurt_scale", Vector2.ZERO)
		hurt_head_offset = outfit.get("hurt_offset", Vector2.ZERO)
	_head.position = _rest_positions[_head]
	_apply_base_head()

## 머리를 그림 한 장(tex, 머리 공 here, 왼쪽을 보는지 faces_left)으로 바꿔 끼운다 — _set_head_frame과 뒤통수가 같이 쓴다
func _set_head_image(tex: Texture2D, here: Vector3, faces_left: bool, dir: float) -> void:
	_turn_applied = true
	var base: Vector3 = _turn_anchors()[0]
	var rest_scale: Vector2 = _turn_rest_scale()
	var base_size: Vector2 = _turn_rest_texture().get_size()
	var size: Vector2 = tex.get_size()
	var ratio: float = base.z / maxf(here.z, 1.0)
	var sx: float = absf(rest_scale.x) * ratio
	var sy: float = rest_scale.y * ratio
	var mirror: float = (-1.0 if faces_left else 1.0) * dir
	var rest_pos: Vector2 = _rest_positions[_head]
	# 평소 옆모습의 머리 공 중심이 리그의 어디에 있는지 — 반대쪽을 볼 땐 좌우 대칭 자리로 간다
	var center_x: float = (rest_pos.x + (base.x - base_size.x * 0.5) * absf(rest_scale.x)) * dir
	var center_y: float = rest_pos.y + (base.y - base_size.y * 0.5) * rest_scale.y
	var target := Vector2(
		center_x - (here.x - size.x * 0.5) * sx * mirror,
		center_y - (here.y - size.y * 0.5) * sy)
	_head.texture = tex
	_head.scale = Vector2(sx * mirror, sy)
	_head.position += target - rest_pos

## 머리 돌리기로 바꿔 끼운 그림을 평소 머리로 되돌린다. 그사이 다른 표정(피격 등)이 들어왔으면 그대로 둔다
func _clear_head_frame() -> void:
	if not _turn_applied or _head == null:
		return
	_turn_applied = false
	# 반대쪽을 볼 땐 옆모습 그림을 뒤집어 쓰므로, 그림이 같아도 배율은 꼭 되돌린다 — 액션 표정 중이면 그 얼굴로(_apply_base_head)
	if _is_turn_texture(_head.texture):
		_apply_base_head()
	_clear_body_frame()

## 왼쪽(-x)으로 갈 때는 몸 전체를 좌우로 뒤집는다.
## 궁극기 연출 등에서 Visual의 scale을 잠깐 늘였다 줄이는 경우가 있어서,
## 크기는 건드리지 않고 x의 부호만 바라보는 방향에 맞춘다
func _face_moving_direction() -> void:
	if not (_fighter and is_instance_valid(_fighter)):
		return
	var facing_sign: float = signf(_fighter.facing)
	# 방향이 뒤집힌 순간 머리 돌리기를 시작한다(처음 한 번은 원래 방향을 기억만 한다)
	if head_turn_on_face and _face_sign != 0.0 and facing_sign != _face_sign:
		if _face_turn_time > 0.0 and facing_sign == _face_turn_from and _face_turn_progress() < 0.5:
			# 몸이 아직 옛 방향인 채 도로 돌아왔다 — 몸은 그대로 맞으니 머리만 제자리로 둔다
			_face_turn_time = 0.0
			_clear_head_frame()
		elif _can_head_turn() and not _face_turn_blocked():
			_face_turn_from = _face_sign
			_face_turn_time = face_turn_duration
	_face_sign = facing_sign
	# 머리가 정면에 오기 전(앞 절반)엔 몸이 아직 옛 방향을 본다 — 고개가 먼저 돌고 몸이 따라간다
	var shown_sign: float = facing_sign
	if _face_turn_time > 0.0 and _face_turn_progress() < 0.5:
		shown_sign = _face_turn_from
	var facing_x: float = absf(scale.x) * shown_sign
	if not is_equal_approx(scale.x, facing_x):
		scale.x = facing_x

## 방향 전환 진행도(0 = 막 시작, 1 = 다 돔)
func _face_turn_progress() -> float:
	return 1.0 - _face_turn_time / maxf(face_turn_duration, 0.001)

## 방향 전환을 그 자리에서 끝내야 하는 동작 중인지 — 손·몸을 따로 쓰는 동작이 시작되면 몸을 바로 새 방향으로 맞춘다
func _face_turn_blocked() -> bool:
	return _attack_time > 0.0 or _drink_time > 0.0 or _gun_time > 0.0 or _eat_time > 0.0 or _grab_time > 0.0 or _cast_time > 0.0 \
		or _step_time > 0.0 or _hurt_time > 0.0 or _guard_target > 0.0 or _charge_target > 0.0 or _kneel_target > 0.0 or _hammer_target > 0.0 or _counter_target > 0.0 \
		or _lift_target > 0.0 or _stomp_target > 0.0 or _ride_target > 0.0 or _clash_target > 0.0 or _dk_stage != 0

## 방향 전환 머리 돌리기 — 앞 절반은 몸이 옛 방향인 채 머리가 측면1 -> ... -> 정면으로 돌고,
## 머리가 정면을 본 순간 몸이 뒤집힌 뒤 뒤 절반은 새 방향에서 측면3 -> ... -> 옆모습으로 마저 돈다.
## 몸이 뒤집히는 걸 머리가 정면인 순간에 숨긴다. 옛 방향 옆모습(첫 단계)은 뒤집기 전과 같은 그림이라 건너뛴다
func _pose_face_turn() -> void:
	# 도는 도중 다른 표정(피격 등)이 들어오면 그쪽에 양보하고 멈춘다
	if not _can_head_turn():
		_face_turn_time = 0.0
		return
	var front: int = _turn_textures().size()
	var shown: int = front * 2
	var step: int = clampi(int(_face_turn_progress() * shown), 0, shown - 1)
	# 그림 n장이면: 앞 절반 1, 2, ..., n(정면) / 뒤 절반 n-1, ..., 0(옆모습). 둘 다 "그때 몸이 보는 쪽" 기준이라 dir은 1
	var frame: int = step + 1 if step < front else shown - 1 - step
	_set_head_frame(frame, 1.0)

## 방향 전환 중 손·발을 몸 가운데(x = 0)로 모았다가 벌린다 — 몸이 뒤집히는 순간(진행도 절반) 가장 많이 모인다.
## 그림 크기는 안 건드리고 위치만 좁혀서, 종이처럼 납작해지지 않고 "몸을 돌리며 팔다리가 모인다"로 보이게 한다
func _pose_face_turn_limbs() -> void:
	var squeeze: float = 1.0 - face_turn_limb_gather * sin(_face_turn_progress() * PI)
	for part in [_hand_l, _hand_r, _foot_l, _foot_r]:
		if part:
			part.position.x *= squeeze

## 몸은 그대로 두고 머리만 반대쪽을 돌아본다 — 머리 scale.x가 옆모습(0)을 지나 부호가 뒤집혔다가 돌아온다.
## 머리 세로 크기(scale.y)는 안 뒤집으므로 그게 곧 원래 크기다 — 가로를 거기에 맞춰 부호만 바꾼다
func _pose_lookback() -> void:
	if _head == null:
		return
	# 돌리는 그림이 있으면 옆 -> 측면1 -> ... -> 정면 -> ... -> 측면1 -> 반대쪽 옆으로 돈다(돌아올 땐 거꾸로).
	# 그림이 n장이면 단계는 2n+1개 — 정면(n번)까지는 바라보는 쪽, 그 뒤로는 뒤집어서 반대쪽 그림이 된다
	if _can_head_turn():
		var front: int = _turn_textures().size()
		var steps: int = front * 2 + 1
		var step: int = clampi(int(_lookback_reach() * steps), 0, steps - 1)
		# 몸통은 1.0으로 고정 — 머리만 넘어가고 몸은 보던 쪽 그대로 있는다
		_set_head_frame(front - absi(step - front), 1.0 if step <= front else -1.0, 1.0)
		return
	_head.scale.x = _head.scale.y * (1.0 - 2.0 * _lookback_reach())

## 방어 보호막이 켜지고 꺼질 때 Fighter가 호출한다. 자세는 _guard_blend로 서서히 섞인다
func set_guarding(on: bool) -> void:
	_guard_target = 1.0 if on else 0.0

## 포즈 씬에서 읽어 오는 조각 이름들. 씬에 같은 이름의 노드가 있으면 그 자리·각도를 쓰고, 없으면 안 건드린다
const POSE_PART_NAMES: Array[String] = ["FootL", "FootR", "Body", "Head", "HandL", "HandR", "Recorder", "Danso",
	"Carry", "KidHead", "KidBody", "KidFootL", "KidFootR", "KidHandL", "KidHandR"]
## 이미 읽어 둔 포즈 {씬 경로: {조각 이름: [위치, 각도]}} — 리그끼리 공유해 씬마다 한 번만 읽는다
static var _pose_cache: Dictionary = {}

## 포즈 씬을 읽어 조각별 자리·각도를 뽑아낸다. **씬을 화면에 올리지 않는다** —
## 복제본을 만들어 좌표만 베끼고 바로 버리므로 스크립트(@tool 미리보기)도 돌지 않는다
static func read_pose(scene: PackedScene) -> Dictionary:
	if scene == null:
		return {}
	var key: String = scene.resource_path
	if key != "" and _pose_cache.has(key):
		return _pose_cache[key]
	var out: Dictionary = {}
	var root: Node = scene.instantiate()
	if root:
		for part_name in POSE_PART_NAMES:
			var part := root.find_child(part_name, true, false) as Node2D
			if part:
				# [자리, 각도, 크기, 좌우뒤집힘] — 뒤의 둘은 **기본 자세 씬만** 쓴다.
				# 평타·방어 포즈는 앞의 둘만 보므로 지금까지와 똑같이 동작한다
				var flipped: bool = (part as Sprite2D).flip_h if part is Sprite2D else false
				out[part_name] = [part.position, part.rotation, part.scale, flipped]
		root.free()
	if key != "":
		_pose_cache[key] = out
	return out

## 포즈에 적힌 이름을 실제 리그 조각으로 바꿔 준다. 없는 조각은 null
func _pose_part(part_name: String) -> Node2D:
	match part_name:
		"FootL":
			return _foot_l
		"FootR":
			return _foot_r
		"Body":
			return _body
		"Head":
			return _head
		"HandL":
			return _hand_l
		"HandR":
			return _hand_r
		"Recorder":
			return _hand_l_hold.get_node_or_null("Recorder") as Node2D if _hand_l_hold else null
		"Danso":
			return _hand_r_hold.get_node_or_null("Danso") as Node2D if _hand_r_hold else null
		"Carry":
			return _carry
		"KidHead", "KidBody", "KidFootL", "KidFootR", "KidHandL", "KidHandR":
			# 안고 있는 것(아이)의 **조각들**. 자세 씬에서 머리·몸·두 발을 따로 끌어 잡을 수 있게 열어 둔다
			return _carry.get_node_or_null(part_name) as Node2D if _carry else null
	return null

## 기본 자세 씬에 적어 둔 **자리·각도·크기·좌우뒤집힘**을 리그 조각에 그대로 입힌다.
## 씬이 없으면 아무 일도 안 한다.
##
## **크기까지 읽는 건 여기뿐이다.** 평타·방어 포즈 씬은 자리와 각도만 쓴다 —
## 그쪽은 치는 도중에 섞이는 값이라 크기까지 건드리면 걷기·머리 돌리기와 싸운다.
## 기본 자세는 켤 때 딱 한 번 입히는 것이라 그냥 리그에 적어 둔 것과 같다
func _apply_rest_pose() -> void:
	if rest_pose == null:
		return
	var pose: Dictionary = read_pose(rest_pose)
	for part_name in pose:
		var part: Node2D = _pose_part(part_name)
		if part == null:
			continue
		var data: Array = pose[part_name]
		part.position = data[0] as Vector2
		part.rotation = data[1] as float
		if data.size() > 2:
			part.scale = data[2] as Vector2
		if data.size() > 3 and part is Sprite2D:
			(part as Sprite2D).flip_h = data[3] as bool

## **아이 얼굴을 우는 얼굴로 바꾸고 되돌린다.** 우는 얼굴 그림이 없으면 아무 일도 안 한다.
## 아이가 밖에 나가 있을 때도 그대로 먹는다 — 품에 있든 없든 머리는 같은 조각이다
func set_kid_crying(on: bool) -> void:
	if _carry == null or kid_cry_texture == null:
		return
	var kid_head := _carry.get_node_or_null("KidHead") as Sprite2D
	if kid_head == null:
		return
	if on:
		kid_head.texture = kid_cry_texture
		kid_head.scale = kid_cry_scale if kid_cry_scale != Vector2.ZERO else _kid_head_rest_scale
	else:
		if _kid_head_rest_texture != null:
			kid_head.texture = _kid_head_rest_texture
		kid_head.scale = _kid_head_rest_scale

## 아이 머리의 지금 월드 자리 — 1번 스킬이 **아이 얼굴에서** 비명을 터뜨릴 때 쓴다
func kid_head_position() -> Vector2:
	if _carry == null:
		return global_position
	var kid_head := _carry.get_node_or_null("KidHead") as Node2D
	return kid_head.global_position if kid_head else _carry.global_position

## 안고 있는 것을 보이고 숨기고, 몸의 들썩임을 따라가게 한다
func _pose_carry() -> void:
	if _carry == null:
		return
	if _carry.visible != carrying:
		_carry.visible = carrying
	if not carrying:
		return
	if carry_follows_body and _body != null and _rest_positions.has(_body):
		_carry.position = _carry_rest + (_body.position - (_rest_positions[_body] as Vector2))
	else:
		_carry.position = _carry_rest
	_pose_kid_walk()
	# 막는 중이면 아이도 가드 자세 씬에 잡아 둔 자리로 간다
	_pose_kid_guard()
	# 평타 마무리 — 아이가 앞으로 날아가 발길질한다
	_pose_kid_kick()
	# 뛰어올라 안겨 있는 동안은 걷기 자세 위에 안긴 자세를 덮는다
	_pose_hug()

## 자세 씬에서 **아이가 아닌** 조각들 — 아이만 따로 입힐 때 건너뛸 이름이다
const NON_CARRY_PART_NAMES: Array[String] = ["FootL", "FootR", "Body", "Head", "HandL", "HandR", "Recorder", "Danso"]

## **막는 자세의 아이 부분.** 가드 자세 씬에 잡아 둔 아이 조각 자리를 아이에게만 입힌다.
##
## 몸 전체 가드(`_pose_guard`)는 걷기보다 **먼저** 돌기 때문에, 거기서 아이를 같이 잡아도
## 뒤따라 도는 걷기 자세(`_pose_kid_walk`)가 그대로 덮어써 버린다. 그래서 여기서 한 번 더 입힌다
func _pose_kid_guard() -> void:
	if _guard_blend <= 0.001:
		return
	var scene: PackedScene = guard_pose
	if held_item_l_armed and dual_guard_pose != null:
		scene = dual_guard_pose
	if scene == null:
		return
	_apply_pose_scene(read_pose(scene), _guard_blend, true, NON_CARRY_PART_NAMES)

## **영역전개 점프 자세를 켜고 끈다** — 궁극기가 영역에 들어갈 때 켜고 나올 때 끈다
func set_domain_jump(on: bool) -> void:
	_domain_jump = on
	if not on:
		_domain_land_left = 0.0

## 공중에 떠 있는 동안은 착지 자세 시간을 가득 채워 두고, 바닥에 닿으면 그때부터 깎는다
func _update_domain_jump(delta: float) -> void:
	if not _domain_jump or _fighter == null or not is_instance_valid(_fighter):
		return
	if _fighter.is_on_floor():
		_domain_land_left = maxf(_domain_land_left - delta, 0.0)
	else:
		_domain_land_left = domain_jump_land_time

## 뛰는 높이에 맞춰 세 장을 이어 붙인다 — 올라갈 땐 준비 → 최고점, 내려올 땐 최고점 → 착지.
## 바닥에 닿은 뒤로는 착지 자세가 잠깐 남았다가 풀린다.
##
## **걷기·안기기 자세보다 뒤에** 돈다 — 그래야 아이까지 통째로 이 자세가 이긴다
func _pose_domain_jump() -> void:
	if not _domain_jump or _fighter == null or not is_instance_valid(_fighter):
		return
	if domain_jump_ready_pose == null and domain_jump_peak_pose == null and domain_jump_land_pose == null:
		return
	if _fighter.is_on_floor():
		if _domain_land_left > 0.0 and domain_jump_land_pose != null:
			var t: float = clampf(_domain_land_left / maxf(domain_jump_land_time, 0.01), 0.0, 1.0)
			_apply_pose_scene(read_pose(domain_jump_land_pose), t)
		return
	var vy: float = _fighter.velocity.y
	var speed: float = maxf(domain_jump_speed, 1.0)
	if vy < 0.0:
		# 솟아오르는 중 — 빠를수록 준비 자세, 느려질수록 최고점 자세
		var t: float = 1.0 - clampf(-vy / speed, 0.0, 1.0)
		if domain_jump_ready_pose != null:
			_apply_pose_scene(read_pose(domain_jump_ready_pose), 1.0)
		if domain_jump_peak_pose != null:
			_apply_pose_scene(read_pose(domain_jump_peak_pose), t, false)
	else:
		# 떨어지는 중 — 빠를수록 착지 자세
		var t: float = clampf(vy / speed, 0.0, 1.0)
		if domain_jump_peak_pose != null:
			_apply_pose_scene(read_pose(domain_jump_peak_pose), 1.0)
		if domain_jump_land_pose != null:
			_apply_pose_scene(read_pose(domain_jump_land_pose), t, false)

## **아이 드롭킥을 시작한다.** 평타 마무리 타(`KidDropkick` 노드)가 불러 준다.
## 0 이하를 주면 리그에 적어 둔 `kid_kick_time`을 쓴다
func play_kid_dropkick(duration: float = -1.0) -> void:
	_kid_kick_left = duration if duration > 0.0 else kid_kick_time

## 아이가 앞으로 쭉 날아갔다가 **왔던 길 그대로** 돌아온다 — 나가는 양을 sin으로 재서
## 0 → 1 → 0으로 움직이기 때문에 가는 궤도와 오는 궤도가 같다(2026-10-04 사용자 요청)
func _pose_kid_kick() -> void:
	if _carry == null:
		return
	if _kid_kick_left <= 0.0:
		if not is_zero_approx(_carry.rotation):
			_carry.rotation = 0.0
		return
	var k: float = clampf(1.0 - _kid_kick_left / maxf(kid_kick_time, 0.01), 0.0, 1.0)
	# 앞으로 나가는 양 — 0 → 1 → 0이라 가는 길과 오는 길이 같다
	var out: float = sin(k * PI)
	# 높이와 눕는 각도는 **먼저** 다 차오른다 — 그래야 솟아서 눕고 그 높이로 쭉 날아간다
	var rise: float = pow(out, clampf(kid_kick_rise, 0.1, 1.0))
	var spin: float = deg_to_rad(kid_kick_deg) * rise
	_carry.position += Vector2(kid_kick_reach * out, -kid_kick_lift * rise)
	_carry.rotation = spin
	# **아이 몸통을 축으로 돌린다** — 돌면서 생긴 어긋남만큼 되밀어 준다.
	# 안 그러면 멀리 있는 Carry 원점을 축으로 돌아서 아이가 호를 그리며 끌려간다
	if _kid_rest.has(kid_kick_pivot):
		var pivot: Vector2 = _kid_rest[kid_kick_pivot] as Vector2
		_carry.position += pivot - pivot.rotated(spin)
	# 두 발을 앞으로 쭉 뻗는다 — 뒷발이 조금 더 나간다
	var leg: float = deg_to_rad(kid_kick_leg_deg) * rise
	_set_kid("KidFootL", Vector2(kid_kick_legs * rise, -kid_kick_legs * 0.4 * rise), leg)
	_set_kid("KidFootR", Vector2(kid_kick_legs * 1.3 * rise, -kid_kick_legs * 0.2 * rise), leg)
	_set_kid("KidHandL", Vector2(-kid_kick_legs * 0.6 * rise, kid_kick_legs * 0.3 * rise))
	_set_kid("KidHandR", Vector2(-kid_kick_legs * 0.4 * rise, kid_kick_legs * 0.3 * rise))

## **아이를 품으로 불러올리거나 내려놓는다.** 1번 스킬(악쓰기)이 켜고 끈다.
## 자세 씬(`hug_pose`)이 비어 있으면 아무 일도 안 한다 — 아이는 계속 옆에서 걷는다
func set_kid_hug(on: bool) -> void:
	_hug_want = on and hug_pose != null
	# 표정은 자세 씬과 따로 논다 — 씬을 안 넣어 둔 캐릭터도 표정은 바뀔 수 있어야 한다
	if _hug_face_on != on:
		_hug_face_on = on
		if _vomit_time <= 0.0 and _hurt_time <= 0.0:   # 잠깐 바뀐 표정이 떠 있으면 그게 끝난 뒤 반영된다
			_apply_base_head()

## 지금 아이가 품에 안겨 있는지(뛰어오르는 중에는 아직 false)
func is_kid_hugged() -> bool:
	return _hug_blend > 0.99

## 아이 머리 **조각 자체**를 돌려준다 — 카메라가 아이를 따라다니며 확대할 때 쓴다.
## `kid_head_position()`은 그 순간 자리만 주지만, 이쪽은 계속 따라갈 수 있다
func kid_head_node() -> Node2D:
	if _carry == null:
		return self
	var kid_head := _carry.get_node_or_null("KidHead") as Node2D
	return kid_head if kid_head else _carry

## 안기는 진행도를 시간에 따라 밀어 준다. 올라갈 때와 내려올 때 빠르기를 따로 둔다
func _update_hug(delta: float) -> void:
	var want: float = 1.0 if _hug_want else 0.0
	if is_equal_approx(_hug_blend, want):
		_hug_blend = want
		return
	var span: float = hug_rise_time if _hug_want else hug_fall_time
	_hug_blend = move_toward(_hug_blend, want, delta / maxf(span, 0.01))

## 걷던 아이를 품에 안긴 자리로 끌어올린다. 가는 길 가운데에서 **위로 솟아** 폴짝 뛰는 모양이 된다.
## 다리·몸통은 기본적으로 건너뛴다(`hug_holds_legs`) — 안고도 걸을 수 있어야 한다
func _pose_hug() -> void:
	if _hug_blend <= 0.001 or hug_pose == null:
		return
	var skip: Array = [] if hug_holds_legs else ["FootL", "FootR", "Body"]
	# 때리는 중에는 두 손을 안 잡는다 — 안고 있다고 평타 동작까지 굳으면 안 때린 것처럼 보인다
	if _attack_time > 0.0:
		skip = skip + ["HandL", "HandR"]
	_apply_pose_scene(read_pose(hug_pose), _hug_blend, true, skip)
	# 뛰는 중에만 뜬다 — 다 안기면(1) 솟음이 0으로 돌아와 품에 딱 붙는다
	if _carry and hug_arc != 0.0:
		_carry.position.y -= sin(clampf(_hug_blend, 0.0, 1.0) * PI) * hug_arc

## 옆에서 같이 걷는 아이의 걸음. 엄마 걸음 위상(`_phase`)과 세기(`_blend`)를 그대로 쓰므로
## 엄마가 멈추면 아이도 멈추고, 빨리 걸으면 아이도 빨라진다.
## 두 발은 서로 반 바퀴 엇갈리고, 두 손은 발과 **반대로** 흔들린다
func _pose_kid_walk() -> void:
	if _kid_rest.is_empty():
		return
	if not carry_walks:
		for kid_name in _kid_rest:
			_set_kid(kid_name, Vector2.ZERO, 0.0)
		return
	# 공중에 뜬 만큼 걷기 흔들림은 줄고 점프 자세가 들어온다
	var air: float = clampf(_air_blend, 0.0, 1.0)
	var ground: float = 1.0 - air
	var swing: float = sin(_phase) * _blend * ground
	var bob: float = absf(sin(_phase)) * _blend * ground
	_set_kid("KidFootL", Vector2(kid_step_swing * swing + kid_jump_tuck * air,
		-kid_step_lift * maxf(swing, 0.0) - kid_jump_lift * air), deg_to_rad(-kid_jump_deg) * air)
	_set_kid("KidFootR", Vector2(-kid_step_swing * swing - kid_jump_tuck * air,
		-kid_step_lift * maxf(-swing, 0.0) - kid_jump_lift * air), deg_to_rad(-kid_jump_deg) * air)
	_set_kid("KidHandL", Vector2(-kid_hand_swing * swing, -kid_jump_hand * air))
	_set_kid("KidHandR", Vector2(kid_hand_swing * swing, -kid_jump_hand * air))
	_set_kid("KidBody", Vector2(0.0, -kid_bob * bob - kid_jump_lift * 0.4 * air))
	_set_kid("KidHead", Vector2(0.0, -kid_bob * bob - kid_jump_lift * 0.4 * air))

## 아이 조각 하나를 제자리에서 offset만큼 옮기고 각도를 더한다. 그 조각이 없으면 그냥 넘어간다.
## 각도는 **자세 씬에 잡아 둔 각도에 더한다** — 씬에서 기울여 둔 걸 지우지 않는다
func _set_kid(kid_name: String, offset: Vector2, extra_rot: float = 0.0) -> void:
	if not _kid_rest.has(kid_name):
		return
	var part: Node2D = _carry.get_node_or_null(kid_name) as Node2D
	if part == null:
		return
	part.position = (_kid_rest[kid_name] as Vector2) + offset
	if _kid_rest_rot.has(kid_name):
		part.rotation = (_kid_rest_rot[kid_name] as float) + extra_rot

## 손에 든 악기(리코더·단소)를 씬에 저장돼 있던 제자리로 돌려놓는다
func _reset_held_items() -> void:
	for held in _held_rest:
		if not is_instance_valid(held):
			continue
		var rest: Array = _held_rest[held]
		held.position = rest[0] as Vector2
		held.rotation = rest[1] as float

## 읽어 둔 포즈를 지금 자세에 t만큼 섞는다. 0이면 평소 자세, 1이면 포즈 그대로.
##
## `shortest`는 각도를 어느 쪽으로 돌릴지다.
##  - true(기본): **짧은 쪽으로** 돈다. 걷다가 막는 자세로 넘어갈 때처럼 "지금 각도에서 목표 각도까지"
##    자연스럽게 가야 하는 경우에 쓴다.
##  - false: **적어 둔 숫자 그대로** 보간한다. 평타 키프레임 사이에 쓴다 —
##    짧은 쪽으로 돌면 0도 → 180도 → 360도로 적어 둔 **한 바퀴 돌기**가 도로 되감긴다
func _apply_pose_scene(pose: Dictionary, t: float, shortest: bool = true, skip: Array = [],
		gear_aware: bool = false) -> void:
	for part_name in pose:
		if skip.has(part_name):
			continue
		var part: Node2D = _pose_part(part_name)
		if part == null:
			continue
		var data: Array = pose[part_name]
		var target: float = data[1] as float
		var want: Vector2 = data[0] as Vector2
		if gear_aware:
			want += _gear_offset(part)
		part.position = part.position.lerp(want, t)
		part.rotation = lerp_angle(part.rotation, target, t) if shortest else lerpf(part.rotation, target, t)

## **런닝머신 장비를 낀 동안 이 조각이 제자리에서 얼마나 비켜나 있는지.**
##
## 로켓을 신으면 머리·몸·손은 장비 단계 자리로 옮겨지고 거기에 뜬 높이(`hover` 16px)까지 더해진다.
## 그런데 운동 자세(`Gym*Pose.tscn`)에 적힌 자리는 **땅에 서 있을 때 기준**이라, 그냥 입히면
## 자세에 적힌 조각만 땅으로 내려오고 **자세에 없는 조각(컬의 머리)은 뜬 채로 남아 몸이 분리된다**
## (2026-10-06 실측: 머리 y -48, 몸 y 3). 그래서 자세를 이 어긋남 **위에 얹는다**.
##
## 장비 자리가 적힌 조각은 그 어긋남을, 안 적힌 조각(발)은 **뜬 높이만** 쓴다 — 발까지 같이 떠야
## 로켓이 몸에 붙어 따라다닌다(장비는 왼발 그림의 자식이다)
func _gear_offset(part: Node2D) -> Vector2:
	if part == null or _gear_glide <= 0.0:
		return Vector2.ZERO
	if _rest_layer_base.has(part) and _rest_positions.has(part):
		return _rest_positions[part] - _rest_layer_base[part]
	return _gear_lift() + _gear_orbit

## 돌진 구간에 맞는 포즈 씬 — -1 준비 / 1 돌진 중 / 2 끝난 직후. 안 넣어 둔 칸은 null
func _dual_dash_pose(phase: float) -> PackedScene:
	if phase < -0.5:
		return dual_dash_ready_pose
	if phase > 1.5:
		return dual_dash_end_pose
	return dual_dash_run_pose

## 세 장(시작·가운데·끝)을 **다 지나는 곡선**으로 자세를 잡는다.
##
## 2차 베지에를 쓰되 조종점을 `2*P1 - (P0+P2)/2`로 잡아서, t=0.5일 때 정확히 가운데 장을 지난다.
## 그래서 가운데 장을 몸 아래에 두면 손이 **몸 아래로 둥글게 쓸고 지나간다**(직선 두 토막이면 V자로 꺾인다).
## 각도도 같은 식으로 잇는다 — 짧은 쪽으로 안 돌리므로 적어 둔 숫자 그대로 돈다
func _apply_pose_curve(a: Dictionary, b: Dictionary, c: Dictionary, t: float) -> void:
	var u: float = 1.0 - t
	var w0: float = u * u
	var w1: float = 2.0 * u * t
	var w2: float = t * t
	for part_name in a:
		var part: Node2D = _pose_part(part_name)
		if part == null or not b.has(part_name) or not c.has(part_name):
			continue
		var p0: Vector2 = a[part_name][0]
		var p1: Vector2 = b[part_name][0]
		var p2: Vector2 = c[part_name][0]
		part.position = p0 * w0 + (p1 * 2.0 - (p0 + p2) * 0.5) * w1 + p2 * w2
		var r0: float = a[part_name][1]
		var r1: float = b[part_name][1]
		var r2: float = c[part_name][1]
		part.rotation = r0 * w0 + (r1 * 2.0 - (r0 + r2) * 0.5) * w1 + r2 * w2

## 그 타(0=1타 … 3=4타)에 잡아 둔 세 장. 다른 타 번호(베기·특수)는 빈 배열.
## **궁(쌍 악기) 중이면 쌍 악기용 칸을 먼저 본다** — 거기 비어 있는 자리는 평소 칸으로 메운다
func _attack_pose_set(variant: int) -> Array:
	var normal: Array = []
	var dual: Array = []
	match variant:
		0:
			normal = [hit1_ready_pose, hit1_mid_pose, hit1_end_pose]
			dual = [dual_hit1_ready_pose, dual_hit1_mid_pose, dual_hit1_end_pose]
		1:
			normal = [hit2_ready_pose, hit2_mid_pose, hit2_end_pose]
			dual = [dual_hit2_ready_pose, dual_hit2_mid_pose, dual_hit2_end_pose]
		2:
			normal = [hit3_ready_pose, hit3_mid_pose, hit3_end_pose]
			dual = [dual_hit3_ready_pose, dual_hit3_mid_pose, dual_hit3_end_pose]
		3:
			normal = [hit4_ready_pose, hit4_mid_pose, hit4_end_pose]
	if not held_item_l_armed:
		return normal
	var out: Array = []
	for i in range(normal.size()):
		var pick: PackedScene = dual[i] if i < dual.size() and dual[i] != null else normal[i]
		out.append(pick)
	return out

## 평타 자세를 포즈 씬으로 잡는다. 잡았으면 true(그 타의 기본 동작은 건너뛴다).
##
## 채워 둔 장만 모아서 **치는 시간에 균등하게 펼친다** — 세 장이면 0 / 0.5 / 1 지점에 놓이고
## 그 사이를 이어 붙인다. 이어 붙일 때 양 끝에서 속도를 줄여서(smoothstep) 장과 장이 툭툭 안 끊긴다
func _pose_attack_scenes() -> bool:
	var keys: Array[PackedScene] = []
	for scene in _attack_pose_set(_attack_variant):
		if scene != null:
			keys.append(scene)
	if keys.is_empty():
		return false
	if keys.size() == 1:
		_apply_pose_scene(read_pose(keys[0]), 1.0)
		return true
	var progress: float = clampf(1.0 - _attack_time / maxf(_attack_len, 0.001), 0.0, 1.0)
	# 세 장이면 **세 점을 다 지나는 곡선**으로 잇는다 — 직선 두 토막이면 가운데서 꺾여서
	# "반원을 그리며 휘두른다"가 안 나온다
	if keys.size() == 3 and attack_pose_curve:
		var eased: float = progress * progress * (3.0 - 2.0 * progress)
		_apply_pose_curve(read_pose(keys[0]), read_pose(keys[1]), read_pose(keys[2]), eased)
		return true
	var span: float = progress * float(keys.size() - 1)
	var i: int = clampi(int(span), 0, keys.size() - 2)
	var t: float = clampf(span - float(i), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	# 앞 장을 그대로 놓고(1.0) 뒤 장을 t만큼 섞으면 두 장 사이를 t로 오가는 것과 같다.
	# **뒤 장은 짧은 쪽으로 안 돌린다**(shortest=false) — 앞 장을 이미 정확히 놓았으므로
	# 적어 둔 각도 차이가 그대로 궤도가 된다. 그래야 "한 바퀴 돌며 치기"를 씬으로 잡을 수 있다
	_apply_pose_scene(read_pose(keys[i]), 1.0)
	_apply_pose_scene(read_pose(keys[i + 1]), t, false)
	return true

## 쌍 악기 자세 — 궁을 쓴 동안의 **서 있기·걷기**와 **대시**.
## 두 손 자리·각도만 잡는다. 손을 따라 `HandRHold`(단소)·`HandLHold`(리코더)가 같이 돈다.
## 방어는 `_pose_guard`가 뒤에서 덮어쓴다 — 막는 자세가 이겨야 하므로 순서를 바꾸지 말 것
func _pose_dual() -> void:
	var t: float = _dual_blend
	# 돌진 자세는 궁이 넣어 주는 `dual_dash_phase`가 우선이다 — 평소 대시(0.04초)보다 훨씬 오래 간다
	var dashing: bool = absf(dual_dash_phase) > 0.01
	var phase_now: float = dual_dash_phase
	if not dashing:
		dashing = _fighter != null and is_instance_valid(_fighter) and _fighter.has_method("is_dashing") and _fighter.is_dashing()
		if dashing:
			phase_now = 1.0   # 평소 대시(가로채기 없는 짧은 대시)는 "돌진 중"으로 본다
	# 포즈 씬을 넣어 뒀으면 그게 이긴다 — 머리부터 발까지 씬에 잡아 둔 그대로 간다
	if dashing:
		var dash_pose: PackedScene = _dual_dash_pose(phase_now)
		if dash_pose != null:
			_apply_pose_scene(read_pose(dash_pose), t)
			return
	var r_pos: Vector2 = dual_dash_hand_r_pos if dashing else dual_hand_r_pos
	var r_deg: float = dual_dash_hand_r_deg if dashing else dual_hand_r_deg
	var l_pos: Vector2 = dual_dash_hand_l_pos if dashing else dual_hand_l_pos
	var l_deg: float = dual_dash_hand_l_deg if dashing else dual_hand_l_deg
	if _hand_r:
		_hand_r.position = _hand_r.position.lerp(r_pos, t)
		_hand_r.rotation = lerp_angle(_hand_r.rotation, deg_to_rad(r_deg), t)
	if _hand_l:
		_hand_l.position = _hand_l.position.lerp(l_pos, t)
		_hand_l.rotation = lerp_angle(_hand_l.rotation, deg_to_rad(l_deg), t)
	if not dashing:
		return
	# 돌진하는 동안 상체가 앞으로 기운다. **facing 부호를 곱한다** — 좌우 반전이 scale.x = -1이라
	# 각도는 그대로 남아서, 안 곱하면 왼쪽으로 돌진할 때 뒤로 넘어간다(발차기·클래시와 같은 이유)
	var sgn: float = 1.0
	if _fighter != null and is_instance_valid(_fighter) and not is_zero_approx(_fighter.facing):
		sgn = signf(_fighter.facing)
	# 뒤로 물러나는 준비동작에선 상체가 **반대로** 젖혀진다(phase -1) — 활시위를 당기는 모양
	var phase: float = dual_dash_phase if absf(dual_dash_phase) > 0.01 else 1.0
	var lean: float = deg_to_rad(dual_dash_lean_deg) * t * sgn * phase
	if _body:
		_body.rotation += lean
	if _head:
		_head.rotation += lean * 0.7

## **박수를 치고 있는지** 밖에서 켜고 끈다. 켜면 활짝 웃는 얼굴(action_head_texture)로도 바뀐다 —
## 웃는 얼굴 그림이 없으면 자세만 바뀐다
func set_clapping(on: bool) -> void:
	if on and not (_clap_target > 0.0):
		_clap_time = 0.0
	_clap_target = 1.0 if on else 0.0
	set_action_face(on)

## 박수 자세 — 손이 **떨어진 자세**를 깔고, 그 위에 **붙은 자세**를 박자에 맞춰 섞는다.
## 0이면 벌어져 있고 1이면 손뼉이 마주친 상태다
func _pose_clap() -> void:
	if clap_open_pose == null and clap_close_pose == null:
		return
	var t: float = _clap_blend
	# 다리·몸통은 기본적으로 안 건드린다 — 붙잡으면 걸어도 발이 안 움직인다
	var skip: Array = [] if clap_holds_legs else ["FootL", "FootR", "Body"]
	if clap_open_pose != null:
		_apply_pose_scene(read_pose(clap_open_pose), t, true, skip)
	# 마주치는 순간이 짧고 벌어진 상태가 길어야 "짝짝" 하고 치는 맛이 난다 — 그래서 제곱을 건다
	var close: float = pow(sin(_clap_time * PI * clap_rate), 2.0)
	if clap_close_pose != null:
		_apply_pose_scene(read_pose(clap_close_pose), t * close, true, skip)
	# 머리는 손뼉 박자에 맞춰 까딱인다 — 자세 씬이 잡아 둔 자리 **위에 더한다**
	if _head != null and not is_zero_approx(clap_head_bob):
		_head.position.y += clap_head_bob * (close * 2.0 - 1.0) * t

## 방어 자세 — 두 손을 몸 앞으로 올려 막고, 몸과 머리를 살짝 움츠린다.
## 오른손은 얼굴 앞 높이, 왼손은 그보다 낮은 가슴 앞이라 권투 가드처럼 위아래로 어긋난다.
## 지금 값에서 목표 자세로 lerp하므로, 걷다가 막아도 그 자리에서 자연스럽게 이어진다
func _pose_guard() -> void:
	var t: float = _guard_blend
	# 쌍 악기를 들었으면 두 악기를 X자로 교차해 막는다(숙이는 건 아래에서 그대로)
	var dual: bool = held_item_l_armed
	# 쌍 악기 방어 자세를 포즈 씬으로 잡아 뒀으면 그게 이긴다
	if dual and dual_guard_pose != null:
		_apply_pose_scene(read_pose(dual_guard_pose), t)
		return
	if guard_pose != null:
		_apply_pose_scene(read_pose(guard_pose), t)
		return
	var r_pos: Vector2 = dual_guard_hand_r_pos if dual else guard_hand_r_pos
	var r_deg: float = dual_guard_hand_r_deg if dual else guard_hand_deg
	var l_pos: Vector2 = dual_guard_hand_l_pos if dual else guard_hand_l_pos
	var l_deg: float = dual_guard_hand_l_deg if dual else -guard_hand_deg
	if _hand_r:
		_hand_r.position = _hand_r.position.lerp(r_pos, t)
		_hand_r.rotation = lerp_angle(_hand_r.rotation, deg_to_rad(r_deg), t)
	if _hand_l:
		_hand_l.position = _hand_l.position.lerp(l_pos, t)
		_hand_l.rotation = lerp_angle(_hand_l.rotation, deg_to_rad(l_deg), t)
	# 몸과 머리를 같이 내려서 움츠린 느낌을 준다 (머리만 내리면 목이 들어간 것처럼 보인다)
	if _body:
		_body.position.y = lerpf(_body.position.y, _rest_positions[_body].y + guard_crouch, t)
	if _head:
		_head.position.y = lerpf(_head.position.y, _rest_positions[_head].y + guard_crouch, t)
		_head.rotation = lerpf(_head.rotation, deg_to_rad(guard_head_deg), t)

## 뒤돌아보기를 끝내고 머리를 앞 방향으로 되돌린다 (정상 종료·중단 공통).
## 세로 크기(scale.y)가 원래 크기이므로 가로를 거기에 양수로 맞춘다 — 끊겨도 머리가 뒤집힌 채 굳지 않는다
## 머리 긁기를 지금 바로 한다(훈련장 테스트 버튼용). 가만히 서 있을 때만 이어진다 — 움직이면 평소처럼 바로 끊긴다
func play_scratch() -> void:
	_end_lookback()
	_idle_time = 0.0
	_scratch_time = scratch_duration

## 뒤돌아보기를 지금 바로 한다(훈련장 테스트 버튼용). 가만히 서 있을 때만 이어진다
func play_lookback() -> void:
	if _head == null:
		return
	_scratch_time = 0.0
	_idle_time = 0.0
	_lookback_time = lookback_duration

## 머리에 붙은 눈 깜빡임(EyeBlink)을 지금 바로 한 번 깜빡이게 한다(훈련장 테스트 버튼용). 눈 깜빡임이 없으면 false
func play_blink() -> bool:
	if _head == null:
		return false
	var found: bool = false
	for child in _head.get_children():
		if child.has_method("blink_now"):
			child.blink_now()
			found = true
	return found

func _end_lookback() -> void:
	_lookback_time = 0.0
	# 방향 전환으로 머리가 도는 중이면(걷는 중이라 여기로 매 프레임 온다) 그 그림을 지우지 않는다
	if _face_turn_time > 0.0:
		return
	_clear_head_frame()
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

## 손에 든 물건의 그림을 갈아끼운다 (주정뱅이 소주병 -> 깨진 소주병).
## **위치·각도·배율은 그대로 두고 텍스처만 바꾼다** — 두 그림의 캔버스가 같아야 손에 쥔 자리가 안 어긋난다.
## 무기를 안 든 캐릭터면 그냥 넘어간다
func swap_held_texture(tex: Texture2D) -> void:
	if tex == null or _hand_r_hold == null:
		return
	for child in _hand_r_hold.get_children():
		if child is Sprite2D:
			child.texture = tex
			return

## 어깨 들이박기 자세를 켜고 끈다 (일진 스킬2). 자세는 _charge_blend로 서서히 섞인다
func set_charging(on: bool) -> void:
	_charge_target = 1.0 if on else 0.0

## 무릎 꿇는 자세를 켜고 끈다(DropkickSkill 준비 동작). 자세는 _kneel_blend로 서서히 섞인다
func set_kneeling(on: bool) -> void:
	_kneel_target = 1.0 if on else 0.0

## 망치질을 켜고 끈다(고양이 아주머니 집 짓기). 켜는 순간 손에 임시 망치가 나타나고, hammer_period마다 땅을 내리친다.
## 무릎 꿇기(set_kneeling)와 같이 켜는 걸 전제로 한다
func set_hammering(on: bool) -> void:
	_hammer_target = 1.0 if on else 0.0
	_hammer_time = 0.0
	if on and _hammer == null and _hand_r_hold:
		_hammer = _make_temp_hammer()
		_hand_r_hold.add_child(_hammer)
	if _hammer:
		_hammer.visible = on

## 임시 망치 그림(나무 자루 + 쇠 머리) — 손에서 위(-y)로 자루가 뻗는다. 손을 앞으로 돌리면 머리가 앞쪽 땅을 친다
func _make_temp_hammer() -> Node2D:
	var hammer := Node2D.new()
	hammer.name = "TempHammer"
	var handle := Polygon2D.new()
	handle.color = Color(0.55, 0.35, 0.18)
	handle.polygon = PackedVector2Array([Vector2(-1.5, 2), Vector2(1.5, 2), Vector2(1.5, -18), Vector2(-1.5, -18)])
	hammer.add_child(handle)
	var head := Polygon2D.new()
	head.color = Color(0.45, 0.47, 0.52)
	head.polygon = PackedVector2Array([Vector2(-7, -23), Vector2(7, -23), Vector2(7, -16), Vector2(-7, -16)])
	hammer.add_child(head)
	return hammer

## 망치질 — 오른손이 hammer_period 박자로 천천히 치켜들었다(hammer_raise_ratio) 빠르게 내리친다.
## 무릎 꿇기 다음에 불러 그 자세의 오른손만 덮어쓴다. 로컬 좌표라 방향 부호를 안 곱한다
func _pose_hammer() -> void:
	if _hand_r == null or not _rest_positions.has(_hand_r):
		return
	var p: float = fposmod(_hammer_time, maxf(hammer_period, 0.05)) / maxf(hammer_period, 0.05)
	var k: float
	if p < hammer_raise_ratio:
		k = _ease01(p / hammer_raise_ratio)
	else:
		var s: float = (p - hammer_raise_ratio) / maxf(1.0 - hammer_raise_ratio, 0.01)
		k = 1.0 - s * s
	var base: Vector2 = _rest_positions[_hand_r] + Vector2(0.0, kneel_depth * _kneel_blend)
	var pos: Vector2 = base + hammer_strike_offset.lerp(hammer_raise_offset, k)
	var deg: float = lerpf(hammer_strike_deg, hammer_raise_deg, k)
	_hand_r.position = _hand_r.position.lerp(pos, _hammer_blend)
	_hand_r.rotation = lerpf(_hand_r.rotation, deg_to_rad(deg), _hammer_blend)

## 두 손을 머리 위로 번쩍 드는 자세를 켜고 끈다(BarracksSlamSkill)
func set_lift_pose(on: bool) -> void:
	_lift_target = 1.0 if on else 0.0

## 한 다리를 아래로 쭉 뻗어 내려찍는 자세를 켜고 끈다(BarracksSlamSkill)
func set_stomp_pose(on: bool) -> void:
	_stomp_target = 1.0 if on else 0.0

## 두 손 번쩍 — 로컬 좌표라 좌우 반전에 저절로 맞는다(_pose_kneel과 같은 이유로 방향 부호를 안 곱한다)
func _pose_lift() -> void:
	var t: float = _lift_blend
	if _hand_r:
		_hand_r.position = _hand_r.position.lerp(lift_hand_r_pos, t)
		_hand_r.rotation = lerpf(_hand_r.rotation, deg_to_rad(lift_hand_deg), t)
	if _hand_l:
		_hand_l.position = _hand_l.position.lerp(lift_hand_l_pos, t)
		_hand_l.rotation = lerpf(_hand_l.rotation, deg_to_rad(lift_hand_deg), t)
	var angle: float = -deg_to_rad(lift_lean_deg) * t
	for part in [_body, _head]:
		if part:
			part.position = kneel_pivot + (part.position - kneel_pivot).rotated(angle)
			part.rotation += angle

## 다리 내려찍기 — 오른발은 아래로 쭉, 왼발은 접고, 두 손은 양옆으로 벌려 균형
func _pose_stomp() -> void:
	var t: float = _stomp_blend
	if _foot_r:
		_foot_r.position = _foot_r.position.lerp(stomp_foot_pos, t)
		_foot_r.rotation = lerpf(_foot_r.rotation, deg_to_rad(stomp_foot_deg), t)
	if _foot_l:
		_foot_l.position = _foot_l.position.lerp(stomp_tuck_pos, t)
		_foot_l.rotation = lerpf(_foot_l.rotation, deg_to_rad(stomp_tuck_deg), t)
	if _hand_r:
		_hand_r.position = _hand_r.position.lerp(stomp_hand_r_pos, t)
	if _hand_l:
		_hand_l.position = _hand_l.position.lerp(stomp_hand_l_pos, t)

## 무릎 꿇기 — 손을 무릎 위로 내린 뒤, 상체(몸통·머리·두 손)를 엉덩이 축(kneel_pivot)으로 **통째로** 앞으로 숙이고 낮춘다.
## 조각의 **로컬 좌표**에서 돌리므로 좌우 반전(리그 scale.x = -1)에 저절로 맞는다 — 방향 부호를 곱하면 안 된다(_pose_headbutt와 같은 이유)
func _pose_kneel() -> void:
	var t: float = _kneel_blend
	for hand in [_hand_r, _hand_l]:
		if hand and _rest_positions.has(hand):
			hand.position = hand.position.lerp(_rest_positions[hand] + kneel_hand_offset, t)
			hand.rotation = lerpf(hand.rotation, 0.0, t)
	var angle: float = deg_to_rad(kneel_lean_deg) * t
	var down := Vector2(0.0, kneel_depth * t)
	for part in [_body, _head, _hand_r, _hand_l]:
		if part == null:
			continue
		part.position = kneel_pivot + (part.position - kneel_pivot).rotated(angle) + down
		part.rotation += angle
	if _foot_r and _rest_positions.has(_foot_r):
		_foot_r.position = _foot_r.position.lerp(_rest_positions[_foot_r] + kneel_front_foot, t)
		_foot_r.rotation = lerpf(_foot_r.rotation, deg_to_rad(kneel_front_foot_deg), t)
	if _foot_l and _rest_positions.has(_foot_l):
		_foot_l.position = _foot_l.position.lerp(_rest_positions[_foot_l] + kneel_back_foot, t)
		_foot_l.rotation = lerpf(_foot_l.rotation, deg_to_rad(kneel_back_foot_deg), t)

## 카운터 자세를 켜고 끈다(CounterSkill). 자세는 _counter_blend로 서서히 섞인다
func set_counter_stance(on: bool) -> void:
	_counter_target = 1.0 if on else 0.0

## 카운터 자세 — 두 손을 단소 자리로 옮기고(찌를 듯 들썩임 포함), 숙이는 각도가 있으면
## 엉덩이(counter_lean_pivot)를 축으로 몸·머리·두 손을 같이 앞으로 숙인다.
## 위치는 로컬 +x가 늘 앞이라 부호 없이 돌리고, 스프라이트 회전은 **facing 부호를 곱한다**(_pose_charge와 같은 이유)
func _pose_counter_stance() -> void:
	var t: float = _counter_blend
	var sgn: float = 1.0
	if _fighter != null and is_instance_valid(_fighter) and not is_zero_approx(_fighter.facing):
		sgn = signf(_fighter.facing)
	var poke: Vector2 = counter_poke_dir * sin(_counter_phase) * counter_poke_amount
	if _hand_r:
		_hand_r.position = _hand_r.position.lerp(counter_hand_r_pos + poke, t)
		_hand_r.rotation = lerpf(_hand_r.rotation, deg_to_rad(counter_hand_r_deg), t)
	if _hand_l:
		_hand_l.position = _hand_l.position.lerp(counter_hand_l_pos + poke, t)
		_hand_l.rotation = lerpf(_hand_l.rotation, deg_to_rad(counter_hand_l_deg), t)
		# 뒷손은 원래 머리 뒤에 그려진다 — 자세가 반 넘게 섞이면 머리보다 앞으로 올려 단소를 쥔 게 보이게
		_hand_l.z_index = attack_grip_hand_z if t > 0.5 else _hand_l_rest_z
	# 앞손·단소도 몸 안쪽(머리 앞 끝 25보다 안)으로 들어와 있어 머리에 가려지므로 같이 올린다
	if _hand_r:
		_hand_r.z_index = attack_grip_hand_z if t > 0.5 else _hand_r_rest_z
	if _hand_r_hold:
		_hand_r_hold.z_index = attack_grip_hand_z if t > 0.5 else _hand_r_hold_rest_z
	var lean: float = deg_to_rad(counter_lean_deg) * t
	for part in [_body, _head, _hand_r, _hand_l]:
		if part:
			part.position = counter_lean_pivot + (part.position - counter_lean_pivot).rotated(lean)
	if _body:
		_body.rotation += lean * sgn
	if _head:
		_head.rotation += lean * sgn

## 두 손을 앞으로 모으고 몸·머리를 앞으로 기울인다.
## **기울기에 facing 부호를 곱한다** — 좌우 반전이 scale.x = -1이라 회전 각도는 그대로 남기 때문에,
## 안 곱하면 왼쪽을 보는 캐릭터가 뒤로 넘어간다(클래시 자세와 같은 이유)
func _pose_charge() -> void:
	var t: float = _charge_blend
	var sgn: float = 1.0
	if _fighter != null and is_instance_valid(_fighter) and not is_zero_approx(_fighter.facing):
		sgn = signf(_fighter.facing)
	if _hand_r:
		_hand_r.position = _hand_r.position.lerp(charge_hand_r_pos, t)
		_hand_r.rotation = lerpf(_hand_r.rotation, deg_to_rad(charge_hand_deg), t)
	if _hand_l:
		_hand_l.position = _hand_l.position.lerp(charge_hand_l_pos, t)
		_hand_l.rotation = lerpf(_hand_l.rotation, deg_to_rad(charge_hand_deg), t)
	var lean: float = deg_to_rad(charge_lean_deg) * t * sgn
	if _body:
		_body.rotation = lean
	if _head:
		_head.rotation = lerpf(_head.rotation, lean, t)

## 처치 연출 — HP가 0이 된 캐릭터를 "눈 X" 표정으로 바꾸고 파츠를 흩뜨린 뒤,
## 그 자세로 굳힌다(리그 갱신을 멈춘다). 실제로 날려보내는 건 Stage가 한다.
## `ko_head_texture`가 비어 있으면 표정만 그대로 두고 자세만 잡는다.
##
## `trail_dir`은 **손·발이 처질 방향(로컬 기준, -1이면 왼쪽)** 이다. 좌우 반전이 `scale.x = -1`이라
## 로컬 +x는 늘 바라보는 쪽이므로, Stage가 "날아가는 방향 x 바라보는 방향"을 계산해 넘겨준다
func play_knockout(trail_dir: float = 1.0) -> void:
	if _knocked_out:
		return
	_knocked_out = true
	var flip: float = -1.0 if trail_dir < 0.0 else 1.0
	if _head:
		if ko_head_texture:
			_head.texture = ko_head_texture
			_head.scale = ko_head_scale if ko_head_scale != Vector2.ZERO else _head_rest_scale
		_head.position += ko_head_offset
	# 손·발은 날아가는 반대쪽으로 처진다 — 관성이 남은 것처럼 보이게
	var hand_offset := Vector2(ko_hand_offset.x * flip, ko_hand_offset.y)
	var foot_offset := Vector2(ko_foot_offset.x * flip, ko_foot_offset.y)
	if _hand_l:
		_hand_l.position += hand_offset
	if _hand_r:
		_hand_r.position += hand_offset
	if _hand_r_hold:
		_hand_r_hold.position += hand_offset
	if _foot_l:
		_foot_l.position += foot_offset
	if _foot_r:
		_foot_r.position += foot_offset


## --- 헬스장 바벨 컬 (maps/GymMachine.gd, skills/WorkoutSkill.gd) ---

@export_group("헬스장 바벨 컬")
## 바벨 컬 자세 **세 장** — 아래(팔 편 자세) / 중간 / 위(다 올린 자세).
## **세 장을 다 꽂아야 움직인다.** 한 장이라도 비면 운동해도 평소 자세 그대로다(다른 캐릭터 리그에 안전하게).
## 자리는 `maps/GymCurlStudio.tscn`을 F6로 열어 **움직이는 걸 보면서** 맞추면 된다
@export var curl_down_pose: PackedScene
@export var curl_mid_pose: PackedScene
@export var curl_up_pose: PackedScene
## **런닝머신 장비(자전거 바퀴·로켓 신발 등)를 낀 동안 쓸 컬 자세 세 장.**
## 비워 두면 위의 평소 자세를 그대로 쓴다(뜬 높이는 `_gear_offset`이 알아서 얹는다).
## 발이 없어지고 몸이 떠 있는 상태라 팔다리 각이 달라야 자연스러워서 따로 둔다 — 2026-10-06
@export var curl_down_pose_gear: PackedScene
@export var curl_mid_pose_gear: PackedScene
@export var curl_up_pose_gear: PackedScene
## 한 번 올렸다 내리는 데 걸리는 시간(초)
@export var curl_cycle: float = 1.6
## 한 번 중에서 **올리는 데 쓰는 몫**(나머지가 내리는 시간). 0.45면 올릴 때가 조금 빠르다
@export_range(0.1, 0.9, 0.05) var curl_rise_ratio: float = 0.62
## 자세가 켜지고 꺼지는 데 걸리는 시간(초)
@export var curl_blend_time: float = 0.18
## 두 손 사이에 끼울 **바벨**. 비우면 `combat/GymBarbell.gd`가 도형으로 그려 준다
@export var curl_bar_scene: PackedScene
## **바벨 그림.** 꽂으면 도형 대신 이 그림을 쓴다(그림 가운데가 봉의 한가운데여야 한다).
## 여기 한 곳만 바꾸면 전 캐릭터가 같은 바벨을 든다
@export var curl_bar_texture: Texture2D
## 바벨 그림의 배율(바벨 노드의 Scale로 들어간다). 그림 가로가 1926px이고 봉 길이를 62px로 보이게 하려면 0.032쯤이다.
## **포즈 씬(아래 자세)에 보기용 바벨(`BarbellView`)이 있으면 그쪽 크기가 이긴다** —
## 포즈 씬을 에디터에서 열어 바벨을 키우면 게임에서도 그대로 커지라고 그렇게 뒀다.
## 포즈 씬에 바벨이 없을 때만 이 값을 쓴다
@export var curl_bar_texture_scale: float = 0.032
## 바벨이 두 손을 잇는 선에서 비켜나는 거리(px) — 손 그림 가운데가 손바닥이 아닐 때 맞춘다
@export var curl_bar_offset: Vector2 = Vector2.ZERO
## 바벨을 손보다 **앞**에 그릴지. 꺼 두면(기본) 몸통 바로 앞·손 뒤에 놓여
## **손이 봉 위에 올라온 것처럼** 보인다(2026-10-05 사용자 지정). 켜면 봉이 손을 덮는다
@export var curl_bar_in_front: bool = false
## **올릴 때 쓸 얼굴**(이 악문 표정)과 **내릴 때 쓸 얼굴**(지친 표정).
## 비워 두면 그 구간은 평소 얼굴 그대로다 — 한쪽만 넣어도 된다
@export var curl_face_rise: Texture2D
@export var curl_face_fall: Texture2D
## 컬 얼굴을 쓸 때의 크기. 0이면 평소 머리 크기를 그대로 쓴다
@export var curl_face_scale: Vector2 = Vector2.ZERO
## **컬 얼굴 크기를 평소 얼굴에 맞출지.** 그림마다 얼굴이 그려진 크기가 달라서, 같은 배율을 줘도
## 머리가 커졌다 작아졌다 한다(악플러: 힘든 얼굴이 올라잇보다 5%쯤 크게 그려져 있다).
## 켜면 **살색 부분의 높이**를 평소 얼굴과 같게 맞춘다 — 머리카락은 그림마다 퍼진 양이 달라 기준으로 못 쓴다.
## 살색을 못 찾으면(사람 얼굴이 아닌 캐릭터) 조용히 넘어간다
@export var curl_face_match_size: bool = true
## **바벨이 내려갈 때 몸도 같이 내려가는 깊이(px).** 바벨을 올리면 몸도 따라 올라온다.
## 무릎을 살짝 굽혔다 펴는 느낌이 나서 "들어 올린다"가 산다. 0이면 몸은 가만히 있다.
## 발은 땅에 붙어 있어야 하므로 안 움직인다
@export var curl_body_dip: float = 3.0
## **컬 중에 평소 숨쉬기를 얼마나 죽일지**(1이면 아예 끈다).
## 위 오르내림과 숨쉬기가 겹치면 박자가 둘이라 몸이 떨리는 것처럼 보인다
@export_range(0.0, 1.0, 0.05) var curl_breath_mute: float = 1.0
## **올리는 동안 몸이 떠는 폭(px)** — 다 올라갈수록 세진다. 0이면 안 떤다
@export var curl_shake: float = 0.7
## 떠는 빠르기(클수록 잘게 떤다)
@export var curl_shake_speed: float = 46.0
## **다 올린 순간 머리 위로 튀는 땀.** 비우면 `combat/SweatDrops.gd`가 그려 준다.
## 아예 안 나오게 하려면 `curl_sweat_on`을 끈다
@export var curl_sweat_on: bool = true
@export var curl_sweat_scene: PackedScene
## 땀이 튀는 자리 — 머리 위에서 이만큼 더 올린 곳(px)
@export var curl_sweat_lift: float = 12.0

## 0=평소, 1=컬 자세. 켜고 끌 때 이 사이를 오간다
var _curl_blend: float = 0.0
var _curl_target: float = 0.0
## 한 번(올렸다 내리기) 안에서 지금 어디쯤인지(0~1)
var _curl_time: float = 0.0
## 두 손 사이에 끼운 바벨 — 처음 쓸 때 만든다
var _curl_bar: Node2D = null
## 지금 올리는 중인지(내리는 중이면 false) — 얼굴과 떨림이 이걸 본다
var _curl_rising: bool = false
## 떨림에 쓰는 시계
var _curl_shake_t: float = 0.0
## 이번 한 번에서 땀을 이미 튀겼는지 — 한 번에 한 번만 나와야 한다
var _curl_sweat_done: bool = false
## **헬스장에서 운동하는 중인지**(기구 종류와 상관없이). 켜져 있으면 idle 몸짓을 쉰다
var _workout_on: bool = false
## 얼굴 그림마다 잰 살색 높이 {경로: px} — 그림마다 한 번만 잰다
static var _skin_height_cache: Dictionary = {}
## 포즈 씬마다 읽어 둔 바벨 크기 {경로: 배율}
static var _bar_scale_cache: Dictionary = {}

## 바벨 컬 자세를 켜고 끈다(`skills/WorkoutSkill.gd`가 부른다)
func set_curl(on: bool) -> void:
	_curl_target = 1.0 if on else 0.0
	# 켤 때는 늘 **아래(팔 편 자세)** 에서 시작한다 — 중간부터 시작하면 들던 걸 이어받은 것처럼 보인다
	if on and _curl_blend <= 0.001:
		_curl_time = 0.0
		_curl_rising = true
		_curl_sweat_done = false
	if curl_face_rise != null or curl_face_fall != null:
		_apply_base_head()

## 지금 컬 자세인지
func is_curling() -> bool:
	return _curl_target > 0.5

func _update_curl(delta: float) -> void:
	_curl_blend = move_toward(_curl_blend, _curl_target, delta / maxf(curl_blend_time, 0.01))
	if _curl_blend <= 0.001:
		_curl_rising = false
		return
	var before: float = _curl_time
	_curl_time = fposmod(_curl_time + delta / maxf(curl_cycle, 0.05), 1.0)
	_curl_shake_t += delta
	var rise: float = clampf(curl_rise_ratio, 0.1, 0.9)
	var was_rising: bool = _curl_rising
	_curl_rising = _curl_time < rise
	# **얼굴은 이벤트가 있을 때만 다시 칠한다** — 올림/내림이 바뀌는 순간에 한 번 불러 준다.
	# 매 프레임 부르면 다른 표정(피격·토하기)이 끼어든 사이에도 덮어써 버린다
	if was_rising != _curl_rising and (curl_face_rise != null or curl_face_fall != null):
		_apply_base_head()
	# **다 올린 순간**(올림 구간을 막 넘어선 때) 땀이 한 번 튄다
	if before < rise and _curl_time >= rise and not _curl_sweat_done:
		_curl_sweat_done = true
		_spawn_curl_sweat()
	# 한 바퀴를 돌아 처음으로 넘어가면 다음 번 땀을 풀어 준다
	if _curl_time < before:
		_curl_sweat_done = false

## **지금 써야 할 자세 세 장**(아래/중간/위 또는 서기/중간/앉기).
## 런닝머신 장비를 끼고 있고 그 쪽 자세가 채워져 있으면 그걸, 아니면 평소 것을 쓴다.
## **세 장이 다 채워져 있을 때만** 갈아탄다 — 한 장만 넣으면 섞여서 더 이상해진다
func _curl_poses() -> Array:
	if _gear_glide > 0.0 and curl_down_pose_gear and curl_mid_pose_gear and curl_up_pose_gear:
		return [curl_down_pose_gear, curl_mid_pose_gear, curl_up_pose_gear]
	return [curl_down_pose, curl_mid_pose, curl_up_pose]

func _squat_poses() -> Array:
	if _gear_glide > 0.0 and squat_up_pose_gear and squat_mid_pose_gear and squat_down_pose_gear:
		return [squat_up_pose_gear, squat_mid_pose_gear, squat_down_pose_gear]
	return [squat_up_pose, squat_mid_pose, squat_down_pose]

## 바벨 컬 — 세 자세를 **아래 -> 중간 -> 위 -> 중간 -> 아래**로 오간다
func _pose_curl() -> void:
	if _curl_blend <= 0.001 or curl_down_pose == null or curl_mid_pose == null or curl_up_pose == null:
		_show_curl_bar(false)
		return
	# 올릴 때와 내릴 때 길이가 달라서, 두 구간을 각각 0~1로 펴서 쓴다
	var rise: float = clampf(curl_rise_ratio, 0.1, 0.9)
	var k: float = _curl_time / rise if _curl_time < rise else 1.0 - (_curl_time - rise) / (1.0 - rise)
	# 양 끝에서 부드럽게 멎도록 사인 곡선을 한 번 태운다 — 등속이면 기계처럼 보인다
	k = 0.5 - cos(clampf(k, 0.0, 1.0) * PI) * 0.5
	# 아래 -> 중간 -> 위를 한 줄로 잇는다. 앞 자세를 깔고 뒤 자세로 덮는 방식은 영역전개 점프와 같다
	var poses: Array = _curl_poses()
	var a: PackedScene = poses[0] if k < 0.5 else poses[1]
	var b: PackedScene = poses[1] if k < 0.5 else poses[2]
	var t: float = k * 2.0 if k < 0.5 else (k - 0.5) * 2.0
	_apply_pose_scene(read_pose(a), _curl_blend, true, [], true)
	_apply_pose_scene(read_pose(b), _curl_blend * t, false, [], true)
	# **바벨이 내려가면 몸도 같이 내려간다** — k가 0(바벨이 제일 아래)일 때 가장 낮다.
	# 발은 빼고 위쪽 조각만 내린다(발이 같이 내려가면 땅을 뚫는다)
	if curl_body_dip != 0.0:
		var dip: float = (1.0 - k) * curl_body_dip * _curl_blend
		for part in [_body, _head, _hand_l, _hand_r]:
			if part:
				part.position.y += dip
	# **올리는 동안 부르르 떤다** — 다 올라갈수록(k가 클수록) 세진다
	if _curl_rising and curl_shake > 0.0:
		var amp: float = curl_shake * k * _curl_blend
		var shake := Vector2(
			sin(_curl_shake_t * curl_shake_speed) * amp,
			cos(_curl_shake_t * curl_shake_speed * 1.37) * amp * 0.6)
		for part in [_body, _head, _hand_l, _hand_r]:
			if part:
				part.position += shake
	_update_curl_bar()

## 두 손 사이에 바벨을 놓는다 — 손을 잇는 선 위에 얹고 각도도 그 선을 따른다.
## 그래서 손만 제대로 움직이면 바벨은 저절로 기울어진다
func _update_curl_bar() -> void:
	if _hand_l == null or _hand_r == null:
		return
	_ensure_curl_bar()
	if _curl_bar == null:
		return
	_curl_bar.visible = true
	var a: Vector2 = _hand_l.position
	var b: Vector2 = _hand_r.position
	_curl_bar.position = (a + b) * 0.5 + curl_bar_offset
	_curl_bar.rotation = (b - a).angle()

## 바벨을 처음 쓸 때 한 번 만든다
func _ensure_curl_bar() -> void:
	if _curl_bar != null and is_instance_valid(_curl_bar):
		return
	_curl_bar = (curl_bar_scene.instantiate() as Node2D) if curl_bar_scene != null else GymBarbell.new()
	if _curl_bar == null:
		return
	# **그림은 붙이기 전에 넘긴다** — 붙는 순간 _ready가 돌아서 나중에 넣으면 한 프레임 늦게 바뀐다
	if curl_bar_texture != null and "texture" in _curl_bar:
		_curl_bar.texture = curl_bar_texture
		_curl_bar.scale = curl_bar_scale()
	add_child(_curl_bar)
	if curl_bar_in_front:
		_curl_bar.z_as_relative = false
		_curl_bar.z_index = 6
	elif _body:
		# **몸통 바로 뒤에 끼워 넣는다** — 같은 z에서는 트리에 늦게 놓인 것이 위라서,
		# 손보다 앞에 두면 손이 봉 위에 올라온 것처럼 보인다
		move_child(_curl_bar, _body.get_index() + 1)

## 쓸 바벨 크기 — **포즈 씬에 놓인 보기용 바벨의 Scale**이 있으면 그걸 쓰고,
## 없으면 `curl_bar_texture_scale`을 쓴다. 포즈 씬에서 눈으로 맞춘 크기가 게임에 그대로 가라고 둔 길이다.
## **기준은 "중간" 자세**다(2026-10-05 사용자 지정). 중간 자세에 바벨이 없으면 아래 자세를 본다.
## 가로·세로를 따로 들고 오므로, 에디터에서 한쪽만 늘린 것도 그대로 반영된다
func curl_bar_scale() -> Vector2:
	for scene in [curl_mid_pose, curl_down_pose, curl_up_pose]:
		var from_pose: Vector2 = read_bar_scale(scene)
		if from_pose.x > 0.0:
			return from_pose
	return Vector2(curl_bar_texture_scale, curl_bar_texture_scale)

## 포즈 씬에 놓인 보기용 바벨(`BarbellView`)의 **Scale**을 읽는다 —
## 에디터에서 네모 핸들을 끌어 키운 그 크기가 그대로 게임으로 온다. 씬마다 한 번만 읽는다.
## 바벨이 없으면 (0,0)을 돌려준다
static func read_bar_scale(scene: PackedScene) -> Vector2:
	if scene == null:
		return Vector2.ZERO
	var key: String = scene.resource_path
	if key != "" and _bar_scale_cache.has(key):
		return _bar_scale_cache[key]
	var out: Vector2 = Vector2.ZERO
	var root: Node = scene.instantiate()
	if root:
		var bar := root.find_child("BarbellView", true, false) as Node2D
		if bar:
			out = bar.scale.abs()
		root.free()
	if key != "":
		_bar_scale_cache[key] = out
	return out

func _show_curl_bar(on: bool) -> void:
	if _curl_bar != null and is_instance_valid(_curl_bar) and _curl_bar.visible != on:
		_curl_bar.visible = on

## **헬스장에서 운동을 시작·종료할 때** 켜고 끈다(`skills/WorkoutSkill.gd`).
## 기구 종류와 상관없이 켜진다 — 운동 중엔 idle 몸짓을 쉬게 하는 것이 목적이다
func set_workout(on: bool) -> void:
	_workout_on = on
	if on:
		_end_lookback()
		_end_special()

## 컬 얼굴을 평소 얼굴과 같은 크기로 보이게 할 배수. 맞춤이 꺼져 있거나 못 재면 1
func _curl_face_fit(tex: Texture2D) -> float:
	if not curl_face_match_size or tex == null or _head_rest_texture == null or tex == _head_rest_texture:
		return 1.0
	var here: float = _skin_height_of(tex)
	var rest: float = _skin_height_of(_head_rest_texture)
	if here <= 1.0 or rest <= 1.0:
		return 1.0
	return rest / here

## 그림에서 **살색 부분의 높이**(px) — 얼굴이 실제로 얼마나 크게 그려졌는지를 재는 값.
## 머리카락·안경을 빼고 재려고 색으로 거른다. 4px 간격으로만 훑고 그림마다 한 번만 잰다
static func _skin_height_of(tex: Texture2D) -> float:
	if tex == null:
		return 0.0
	var key: String = tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id())
	if _skin_height_cache.has(key):
		return _skin_height_cache[key]
	var out: float = 0.0
	var img: Image = tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		const STEP := 4
		var top: int = -1
		var bottom: int = -1
		for y in range(0, img.get_height(), STEP):
			for x in range(0, img.get_width(), STEP):
				var c: Color = img.get_pixel(x, y)
				# 살색 — 밝고 붉은기가 도는 색. 머리카락(검정)·안경(흰색)은 걸러진다
				if c.a >= 0.5 and c.r > 0.85 and c.g > 0.7 and c.g < c.r and c.b > 0.55 and c.b < 0.95:
					if top < 0:
						top = y
					bottom = y
					break
		if top >= 0:
			out = float(bottom - top + STEP)
	_skin_height_cache[key] = out
	return out

## 지금 써야 할 컬 얼굴 — 컬 중이 아니거나 그림을 안 넣었으면 null(평소 얼굴로 돌아간다)
func _curl_face() -> Texture2D:
	if _curl_target <= 0.5:
		return null
	return curl_face_rise if _curl_rising else curl_face_fall

## 다 올린 순간 머리 위로 땀을 튀긴다
func _spawn_curl_sweat() -> void:
	if not curl_sweat_on:
		return
	var drops: Node2D = (curl_sweat_scene.instantiate() as Node2D) if curl_sweat_scene != null else SweatDrops.new()
	if drops == null:
		return
	# 머리 꼭대기에서 조금 더 위 — 머리 그림 높이를 재서 올린다
	var head_top: float = -26.0
	if _head:
		head_top = _head.position.y
		if _head.texture:
			head_top -= _head.texture.get_height() * absf(_head.scale.y) * 0.5
	drops.position = Vector2(_head.position.x if _head else 0.0, head_top - curl_sweat_lift)
	add_child(drops)


## --- 헬스장 스쿼트 (maps/GymMachine.gd, skills/WorkoutSkill.gd) ---

@export_group("헬스장 스쿼트")
## 스쿼트 자세 **세 장** — 서기(허리 편 기본) / 중간 / 앉기.
## 세 장을 다 꽂아야 움직인다. 자리는 `maps/GymSquatStudio.tscn`을 F6로 열어 맞춘다
@export var squat_up_pose: PackedScene
@export var squat_mid_pose: PackedScene
@export var squat_down_pose: PackedScene
## **장비를 낀 동안 쓸 스쿼트 자세 세 장**(비우면 위의 평소 자세를 쓴다) — 컬 쪽과 같은 이유
@export var squat_up_pose_gear: PackedScene
@export var squat_mid_pose_gear: PackedScene
@export var squat_down_pose_gear: PackedScene
## 한 번 앉았다 서는 데 걸리는 시간(초)
@export var squat_cycle: float = 1.8
## 한 번 중에서 **앉는 데 쓰는 몫**(나머지가 일어서는 시간)
@export_range(0.1, 0.9, 0.05) var squat_fall_ratio: float = 0.45
## 자세가 켜지고 꺼지는 데 걸리는 시간(초)
@export var squat_blend_time: float = 0.2
## **어깨에 멘 원판.** 비우면 `combat/SquatPlate.gd`가 검은 원으로 그려 준다
@export var squat_plate_scene: PackedScene
## 원판 그림(비우면 도형)
@export var squat_plate_texture: Texture2D
## 원판 크기. **포즈 씬(중간 자세)에 `SquatPlateView`가 있으면 그쪽 Scale이 이긴다**
@export var squat_plate_scale: Vector2 = Vector2(0.05, 0.05)
## 원판이 놓일 자리 — **몸통 자리에서 이만큼 떨어진 곳**이라 몸이 앉으면 같이 내려간다.
## 포즈 씬에 `SquatPlateView`가 있으면 그 자리를 자세마다 읽어 쓴다
@export var squat_plate_offset: Vector2 = Vector2(6, -22)
## 원판을 **머리보다 앞**에 그릴지 — 켜면 얼굴을 살짝 가린다(사용자 스케치)
@export var squat_plate_in_front: bool = true
## **힘주는 얼굴**(앉고 서는 내내)과 **쉬는 얼굴**(허리 펴고 선 순간만).
## 비워 두면 그 구간은 평소 얼굴 그대로다
@export var squat_face_move: Texture2D
@export var squat_face_rest: Texture2D
## 쉬는 얼굴을 쓸 구간 — 앉은 깊이가 이보다 얕으면(=거의 다 섰으면) 쉬는 얼굴이다
@export_range(0.0, 0.5, 0.01) var squat_rest_zone: float = 0.12
## 스쿼트 얼굴을 쓸 때의 크기. 0이면 평소 머리 크기를 그대로 쓴다(크기 맞춤은 컬과 같이 돈다)
@export var squat_face_scale: Vector2 = Vector2.ZERO
## **앉을 때 몸이 떠는 폭(px)** — 깊이 앉을수록 세진다. 0이면 안 떤다
@export var squat_shake: float = 0.5
@export var squat_shake_speed: float = 40.0
## 스쿼트 중에 평소 숨쉬기를 얼마나 죽일지(1이면 아예 끈다)
@export_range(0.0, 1.0, 0.05) var squat_breath_mute: float = 1.0
## **스쿼트 중에 손을 숨길지**(2026-10-05 사용자 지정) — 봉은 어깨에 메고 있어서
## 손이 몸 옆에 어중간하게 떠 보인다. 끄면 손이 그대로 보인다
@export var squat_hide_hands: bool = true

## **스쿼트 때 손을 감춰 둔 상태인지.** 켜 뒀으면 자세가 풀릴 때 반드시 되돌려야 한다 —
## 안 그러면 운동이 끝나도 손이 영영 안 보인다(2026-10-06 고침)
var _squat_hands_off: bool = false

## 0=평소, 1=스쿼트 자세
var _squat_blend: float = 0.0
var _squat_target: float = 0.0
## 한 번(앉았다 서기) 안에서 지금 어디쯤인지(0~1)
var _squat_time: float = 0.0
## 지금 앉는 중인지(일어서는 중이면 false)
var _squat_falling: bool = false
## 떨림 시계
var _squat_shake_t: float = 0.0
## 지금 쉬는 얼굴인지 — 바뀔 때만 얼굴을 다시 칠한다
var _squat_resting: bool = true
## 어깨에 멘 원판 — 처음 쓸 때 만든다
var _squat_plate: Node2D = null
## 포즈 씬마다 읽어 둔 원판 [자리, 크기]
static var _plate_cache: Dictionary = {}

## 스쿼트 자세를 켜고 끈다(`skills/WorkoutSkill.gd`가 부른다)
func set_squat(on: bool) -> void:
	_squat_target = 1.0 if on else 0.0
	if not on:
		_set_squat_hands(false)   # 자세가 아직 남아 있으면 다음 프레임에 다시 감춘다
	if on and _squat_blend <= 0.001:
		_squat_time = 0.0
		_squat_falling = true
		_squat_resting = true
	if squat_face_move != null or squat_face_rest != null:
		_apply_base_head()

## 지금 스쿼트 중인지
func is_squatting() -> bool:
	return _squat_target > 0.5

func _update_squat(delta: float) -> void:
	_squat_blend = move_toward(_squat_blend, _squat_target, delta / maxf(squat_blend_time, 0.01))
	if _squat_blend <= 0.001:
		_squat_falling = false
		return
	_squat_time = fposmod(_squat_time + delta / maxf(squat_cycle, 0.05), 1.0)
	_squat_shake_t += delta
	var fall: float = clampf(squat_fall_ratio, 0.1, 0.9)
	_squat_falling = _squat_time < fall
	# 허리를 펴고 선 순간에만 얼굴이 쉰다 — 바뀌는 순간에 한 번만 다시 칠한다
	var resting: bool = _squat_depth() <= squat_rest_zone
	if resting != _squat_resting:
		_squat_resting = resting
		if squat_face_move != null or squat_face_rest != null:
			_apply_base_head()

## 얼마나 앉았는지(0=허리 펴고 섬, 1=제일 깊이 앉음)
func _squat_depth() -> float:
	var fall: float = clampf(squat_fall_ratio, 0.1, 0.9)
	var k: float = _squat_time / fall if _squat_time < fall else 1.0 - (_squat_time - fall) / (1.0 - fall)
	# 양 끝에서 부드럽게 멎도록 사인 곡선을 한 번 태운다
	return 0.5 - cos(clampf(k, 0.0, 1.0) * PI) * 0.5

## 스쿼트 — 세 자세를 **서기 -> 중간 -> 앉기 -> 중간 -> 서기**로 오간다
## 스쿼트 중에만 손을 감춘다. 지금 상태와 같으면 아무것도 안 해서 다른 데서 건드린 걸 덮지 않는다
func _set_squat_hands(off: bool) -> void:
	if _squat_hands_off == off:
		return
	_squat_hands_off = off
	for hand in [_hand_l, _hand_r]:
		if hand:
			hand.visible = not off

func _pose_squat() -> void:
	if _squat_blend <= 0.001 or squat_up_pose == null or squat_mid_pose == null or squat_down_pose == null:
		_show_squat_plate(false)
		# **여기서 꼭 되돌려야 한다** — 자세가 다 풀리면 아래 코드가 안 돌기 때문에,
		# 감춰 둔 손을 돌려놓을 곳이 이 줄밖에 없다
		_set_squat_hands(false)
		return
	var k: float = _squat_depth()
	var poses: Array = _squat_poses()
	var a: PackedScene = poses[0] if k < 0.5 else poses[1]
	var b: PackedScene = poses[1] if k < 0.5 else poses[2]
	var t: float = k * 2.0 if k < 0.5 else (k - 0.5) * 2.0
	_apply_pose_scene(read_pose(a), _squat_blend, true, [], true)
	_apply_pose_scene(read_pose(b), _squat_blend * t, false, [], true)
	# **깊이 앉을수록 부르르 떤다**
	if squat_shake > 0.0:
		var amp: float = squat_shake * k * _squat_blend
		var shake := Vector2(
			sin(_squat_shake_t * squat_shake_speed) * amp,
			cos(_squat_shake_t * squat_shake_speed * 1.31) * amp * 0.6)
		for part in [_body, _head, _hand_l, _hand_r]:
			if part:
				part.position += shake
	_update_squat_plate(t, a, b)
	# 봉을 어깨에 멘 자세라 손은 안 보이는 게 낫다 — **스쿼트 중에만** 감춘다
	_set_squat_hands(squat_hide_hands)


## 어깨에 멘 원판을 자리에 놓는다.
## 포즈 씬에 `SquatPlateView`가 있으면 **그 자리를 자세마다 읽어 이어 준다**(몸과 같이 움직인다).
## 없으면 몸통 자리에서 `squat_plate_offset`만큼 떨어진 곳에 둔다
func _update_squat_plate(t: float, a: PackedScene, b: PackedScene) -> void:
	_ensure_squat_plate()
	if _squat_plate == null:
		return
	_squat_plate.visible = true
	var from: Vector2 = read_plate_spot(a)
	var to: Vector2 = read_plate_spot(b)
	if from.x < INF and to.x < INF:
		_squat_plate.position = from.lerp(to, clampf(t, 0.0, 1.0))
	elif _body:
		_squat_plate.position = _body.position + squat_plate_offset

## 원판을 처음 쓸 때 한 번 만든다
func _ensure_squat_plate() -> void:
	if _squat_plate != null and is_instance_valid(_squat_plate):
		return
	_squat_plate = (squat_plate_scene.instantiate() as Node2D) if squat_plate_scene != null else SquatPlate.new()
	if _squat_plate == null:
		return
	if squat_plate_texture != null and "texture" in _squat_plate:
		_squat_plate.texture = squat_plate_texture
	_squat_plate.scale = squat_plate_size()
	add_child(_squat_plate)
	if squat_plate_in_front:
		# 얼굴을 살짝 가리는 구도라 머리보다 앞에 둔다(사용자 스케치, 2026-10-05)
		_squat_plate.z_as_relative = false
		_squat_plate.z_index = 7

func _show_squat_plate(on: bool) -> void:
	if _squat_plate != null and is_instance_valid(_squat_plate) and _squat_plate.visible != on:
		_squat_plate.visible = on

## 쓸 원판 크기 — 포즈 씬(중간 자세)의 `SquatPlateView` Scale이 있으면 그걸 쓴다
func squat_plate_size() -> Vector2:
	for scene in [squat_mid_pose, squat_up_pose, squat_down_pose]:
		var from_pose: Vector2 = read_plate_scale(scene)
		if from_pose.x > 0.0:
			return from_pose
	return squat_plate_scale

## 포즈 씬의 `SquatPlateView` 크기 — 없으면 (0,0)
static func read_plate_scale(scene: PackedScene) -> Vector2:
	return _read_plate(scene)[1] as Vector2

## 포즈 씬의 `SquatPlateView` 자리 — 없으면 (INF, INF)
static func read_plate_spot(scene: PackedScene) -> Vector2:
	return _read_plate(scene)[0] as Vector2

## 포즈 씬에서 원판의 [자리, 크기]를 읽는다. 씬마다 한 번만 읽는다
static func _read_plate(scene: PackedScene) -> Array:
	if scene == null:
		return [Vector2.INF, Vector2.ZERO]
	var key: String = scene.resource_path
	if key != "" and _plate_cache.has(key):
		return _plate_cache[key]
	var out: Array = [Vector2.INF, Vector2.ZERO]
	var root: Node = scene.instantiate()
	if root:
		var plate := root.find_child("SquatPlateView", true, false) as Node2D
		if plate:
			out = [plate.position, plate.scale.abs()]
		root.free()
	if key != "":
		_plate_cache[key] = out
	return out

## 지금 써야 할 스쿼트 얼굴 — 스쿼트 중이 아니면 null
func _squat_face() -> Texture2D:
	if _squat_target <= 0.5:
		return null
	return squat_face_rest if _squat_resting else squat_face_move


## --- 헬스장 런닝머신 (maps/GymMachine.gd, skills/WorkoutSkill.gd) ---

@export_group("헬스장 런닝머신")
## 달리기 자세 **세 장** — 왼발 앞 / 두 발 모음 / 오른발 앞.
## **왼발앞 -> 모음 -> 오른발앞 -> 모음 -> 왼발앞**으로 오가며 한 걸음씩 번갈아 달린다.
## 자리는 `maps/GymRunStudio.tscn`을 F6로 열어 맞춘다
@export var run_left_pose: PackedScene
@export var run_mid_pose: PackedScene
@export var run_right_pose: PackedScene
## **두 걸음(왼발+오른발)에 걸리는 시간(초).** 짧을수록 빨리 달린다
@export var run_cycle: float = 0.52
## 자세가 켜지고 꺼지는 데 걸리는 시간(초)
@export var run_blend_time: float = 0.15
## 달리는 동안 몸이 위아래로 통통 튀는 폭(px) — 한 걸음에 한 번씩 뜬다. 0이면 안 튄다
@export var run_hop: float = 3.0
## **달리는 동안 쓸 얼굴.** 비워 두면 평소 얼굴 그대로다
@export var run_face: Texture2D
## 달리기 얼굴을 쓸 때의 크기. 0이면 평소 머리 크기를 그대로 쓴다
@export var run_face_scale: Vector2 = Vector2.ZERO
## 달리는 동안 평소 숨쉬기를 얼마나 죽일지(1이면 아예 끈다)
@export_range(0.0, 1.0, 0.05) var run_breath_mute: float = 1.0
## 두 걸음(한 바퀴)마다 머리 위로 땀이 튀게 할지. **꺼 둔다**(2026-10-05 사용자 판단) —
## 달리는 내내 땀이 나와서 시끄러웠다. 켜면 바벨 컬과 같은 땀이 나온다
@export var run_sweat_on: bool = false
## 땀이 튀는 자리 — 머리 꼭대기에서 이만큼 더 위(px)
@export var run_sweat_lift: float = 12.0
## **뒤로 간 손이 몸통 뒤로 숨을지.** 두 손이 다 몸 앞에 있으면 팔을 흔드는 게 아니라
## 몸 앞에서 왔다 갔다 하는 것처럼 보인다(2026-10-05 사용자 지적)
@export var run_hide_back_hand: bool = true
## 뒤로 간 손에 줄 z — 몸통(0)보다 작아야 뒤로 간다
@export var run_back_hand_z: int = -1

## 0=평소, 1=달리는 자세
var _run_blend: float = 0.0
var _run_target: float = 0.0
## 두 걸음 안에서 지금 어디쯤인지(0~1)
var _run_time: float = 0.0
## 손의 원래 z — 달리기가 끝나면 되돌린다. 아직 안 재 뒀으면 null
var _hand_rest_z: Dictionary = {}

## 달리기 자세를 켜고 끈다(`skills/WorkoutSkill.gd`가 부른다)
func set_run(on: bool) -> void:
	_run_target = 1.0 if on else 0.0
	if on and _run_blend <= 0.001:
		_run_time = 0.0
		_remember_hand_z()
	if not on:
		_restore_hand_z()
	if run_face != null:
		_apply_base_head()

## 손의 원래 z를 기억해 둔다(처음 한 번만)
func _remember_hand_z() -> void:
	for hand in [_hand_l, _hand_r]:
		if hand and not _hand_rest_z.has(hand):
			_hand_rest_z[hand] = hand.z_index

## 기억해 둔 z로 손을 되돌린다
func _restore_hand_z() -> void:
	for hand in [_hand_l, _hand_r]:
		if hand and _hand_rest_z.has(hand):
			hand.z_index = _hand_rest_z[hand]

## 지금 달리는 중인지
func is_running_machine() -> bool:
	return _run_target > 0.5

func _update_run(delta: float) -> void:
	_run_blend = move_toward(_run_blend, _run_target, delta / maxf(run_blend_time, 0.01))
	if _run_blend <= 0.001:
		return
	var before: float = _run_time
	_run_time = fposmod(_run_time + delta / maxf(run_cycle, 0.05), 1.0)
	# 한 바퀴를 돌아 처음으로 넘어가는 순간 땀이 한 번 튄다
	if run_sweat_on and _run_time < before:
		_spawn_run_sweat()

## 달리기 — **왼발앞 -> 모음 -> 오른발앞 -> 모음 -> 왼발앞**.
## 앞의 반(0~0.5)이 왼발, 뒤의 반(0.5~1)이 오른발 차례다
func _pose_run() -> void:
	if _run_blend <= 0.001 or run_left_pose == null or run_mid_pose == null or run_right_pose == null:
		return
	# **발 장비(바퀴·부스터)를 끼웠으면 달리지 않는다** — 발이 없으니 장비 자세 그대로 서서 바퀴만 돌고 불꽃만 뿜는다
	if _gear_glide > 0.0:
		return
	# 한 걸음 안에서의 진행도(0=발 앞, 1=두 발 모음)를 사인으로 부드럽게 편다
	var half: float = fposmod(_run_time * 2.0, 1.0)
	var k: float = 0.5 - cos(clampf(half, 0.0, 1.0) * PI) * 0.5
	var step_pose: PackedScene = run_left_pose if _run_time < 0.5 else run_right_pose
	# 발 앞 -> 모음 -> (다음 걸음) 발 앞. 모음을 한가운데 두고 양쪽으로 편다
	var a: PackedScene
	var b: PackedScene
	var t: float
	if k < 0.5:
		a = step_pose
		b = run_mid_pose
		t = k * 2.0
	else:
		a = run_mid_pose
		b = run_right_pose if _run_time < 0.5 else run_left_pose
		t = (k - 0.5) * 2.0
	_apply_pose_scene(read_pose(a), _run_blend)
	_apply_pose_scene(read_pose(b), _run_blend * t, false)
	# **한 걸음마다 한 번씩 통통 뜬다** — 두 발이 모일 때가 제일 높다
	if run_hop > 0.0:
		var lift: float = -k * run_hop * _run_blend
		for part in [_body, _head, _hand_l, _hand_r]:
			if part:
				part.position.y += lift
	# **뒤로 간 손은 몸통 뒤로 숨는다** — 뒤에 있는 쪽(x가 작은 쪽)을 가린다
	if run_hide_back_hand and _hand_l and _hand_r:
		_remember_hand_z()
		var left_is_back: bool = _hand_l.position.x < _hand_r.position.x
		_hand_l.z_index = run_back_hand_z if left_is_back else int(_hand_rest_z.get(_hand_l, 0))
		_hand_r.z_index = int(_hand_rest_z.get(_hand_r, 0)) if left_is_back else run_back_hand_z

## 달리면서 머리 위로 땀을 튀긴다 — 바벨 컬의 땀을 그대로 쓴다
func _spawn_run_sweat() -> void:
	var keep: float = curl_sweat_lift
	curl_sweat_lift = run_sweat_lift
	var keep_on: bool = curl_sweat_on
	curl_sweat_on = true
	_spawn_curl_sweat()
	curl_sweat_lift = keep
	curl_sweat_on = keep_on

## 지금 써야 할 달리기 얼굴 — 달리는 중이 아니면 null
## **발 장비(바퀴·부스터)를 달면 평소 얼굴** — 두 발로 달릴 때만 힘든 얼굴이다(2026-10-06 사용자)
func _run_face_now() -> Texture2D:
	return run_face if _run_target > 0.5 and _gear_glide <= 0.0 else null


## --- 헬스장 운동 단계가 옮기는 제자리 (런닝머신 장비·바벨 컬·스쿼트 단계가 같이 쓴다) ---
## 단계마다 머리·몸·손·발 제자리를 옮기는데, 여러 운동 단계가 겹칠 수 있어서(손을 옮기는 런닝머신 + 손을 옮기는 컬)
## **옮긴 만큼을 층별로 따로 들고 더한다** — 한 단계가 다른 단계 자리를 덮어쓰지 않는다

## {층 이름: {조각: 옮긴 만큼}}
var _rest_layers: Dictionary = {}
## {조각: 처음 옮기기 전 제자리} — 옮기는 층이 하나도 안 남으면 이 값으로 되돌린다
var _rest_layer_base: Dictionary = {}

## 아무 단계도 안 옮긴 원래 제자리
func _base_rest(part: Node2D) -> Vector2:
	if _rest_layer_base.has(part):
		return _rest_layer_base[part]
	return _rest_positions.get(part, part.position)

## 한 층이 옮기는 만큼을 바꾼다(빈 사전이면 그 층을 뺀다)
func _set_rest_layer(layer: String, shifts: Dictionary) -> void:
	for part in shifts:
		if not _rest_layer_base.has(part) and _rest_positions.has(part):
			_rest_layer_base[part] = _rest_positions[part]
	if shifts.is_empty():
		_rest_layers.erase(layer)
	else:
		_rest_layers[layer] = shifts
	_refresh_rest_layers()

## 층들을 더해 제자리를 다시 잡는다. 런닝머신 장비를 끼웠으면 뜬 높이·바퀴 궤도도 머리·몸·손에 더한다
func _refresh_rest_layers() -> void:
	var lift: Vector2 = _gear_lift() + _gear_orbit if _gear_glide > 0.0 else Vector2.ZERO
	var lifted: Array = [_head, _body, _hand_l, _hand_r]
	for part in _rest_layer_base.keys():
		var total := Vector2.ZERO
		var used: bool = false
		for shifts in _rest_layers.values():
			if shifts.has(part):
				total += shifts[part]
				used = true
		if used and _gear_glide > 0.0 and part in lifted:
			total += lift
		if used:
			_rest_positions[part] = _rest_layer_base[part] + total
		else:
			_rest_positions[part] = _rest_layer_base[part]
			_rest_layer_base.erase(part)

## 단계 기본 자리를 잡는 데 쓸 **원래 제자리** {조각 이름: {position, scale, texture, offset, centered}}
## (`TreadmillGearData`·`LimbStageData`의 `default_entry`가 받는 꼴)
func stage_rest_info() -> Dictionary:
	var info: Dictionary = {}
	for part_name in ["FootL", "FootR", "Head", "Body", "HandL", "HandR"]:
		var part := _pose_part(part_name) as Sprite2D
		if part == null or not _rest_positions.has(part):
			continue
		var is_foot: bool = part == _foot_l or part == _foot_r
		var is_hand: bool = part == _hand_l or part == _hand_r
		var scale_now: Vector2 = part.scale
		if is_foot:
			scale_now = _foot_rest_scale
		elif is_hand:
			scale_now = _hand_rest_scale
		info[part_name] = {
			"position": _base_rest(part),
			"scale": scale_now,
			"texture": _limb_saved_tex.get(part, part.texture),
			"offset": part.offset,
			"centered": part.centered,
		}
	return info


## --- 헬스장 런닝머신 단계 장비 (maps/workout/TreadmillGearData.gd, skills/WorkoutSkill.gd) ---
## 런닝머신 스택이 오르면 발이 자전거 바퀴 -> 스포츠카 바퀴 -> 로켓 부스터로 바뀐다.
## **장비는 하나다** — 두 발을 대신하는 외바퀴·부스터 하나(2026-10-06 사용자 디자인). 두 발 그림을 다 숨기고 그 자리에 세운다.
## 로켓 단계는 **공중에 떠서** 둥실거리며 다닌다(그림만 뜬다 — 판정은 땅 그대로).
## 자리는 `maps/workout/Treadmill*Studio.tscn`에서 캐릭터마다 맞춘다

const JET_FLAME_SCRIPT := preload("res://combat/JetFlame.gd")
const GEAR_BODY_PARTS: Array[String] = ["Head", "Body", "HandL", "HandR"]

## 지금 단계("" 없음 / bike / car / rocket)
var _gear_stage: String = ""
## 바퀴처럼 굴러가는 단계인지
var _gear_rolls: bool = false
## 장비를 끼운 동안 1 — 걷기 발걸음·들썩임·런닝머신 달리기 자세를 끈다(장비가 발을 대신한다)
var _gear_glide: float = 0.0
## 장비 {"L": Sprite2D} — 보통 "L" 하나다. **왼발 그림의 자식**으로 붙여 발과 같은 순서(몸통 뒤)에 그려진다.
## 자리표에 "R"까지 있으면(두 발 따로) 각 장비가 그 발의 움직임(발차기·내딛기)을 따라간다
var _gear_nodes: Dictionary = {}
## 장비의 제자리 {"L": [위치, 각도, 크기]}(리그 좌표)
var _gear_rest: Dictionary = {}
## 로켓 불꽃 {"L": Node2D}과 장비 그림 안 자리 {"L": [위치, 각도, 크기]} — 장비보다 먼저 붙여 장비 뒤에 그린다
var _gear_flames: Dictionary = {}
var _gear_flame_rest: Dictionary = {}
## 바퀴가 굴러간 각도(라디안)
var _gear_spin: float = 0.0
## 공중에 뜨는 높이(리그 px)와 둥실거림 폭(px)·빠르기(초당 왕복 수) — 로켓 단계만 0이 아니다
var _gear_hover: float = 0.0
var _gear_bob: float = 0.0
var _gear_bob_speed: float = 0.0
var _gear_bob_time: float = 0.0
## 바퀴로 달리는 정도(0 서 있음 ~ 1 달림)와 그 박자(라디안), 몸이 그리는 둥근 궤도 — 손 흔들기·몸 궤도가 같이 쓴다
var _gear_ride: float = 0.0
var _gear_ride_phase: float = 0.0
var _gear_orbit: Vector2 = Vector2.ZERO

@export_group("런닝머신 바퀴 몸짓")
## **바퀴로 달리는 동안**(땅에서 움직이거나 런닝머신 위) 손을 앞뒤로 흔들고 몸이 앞뒤로 둥근 궤도로 살짝 흔들린다(2026-10-06 사용자).
## 한 번 흔드는 데 걸리는 시간(초)
@export var gear_ride_cycle: float = 0.55
## 몸(머리·몸통·손)이 도는 둥근 궤도의 반지름(px) — 가로(앞뒤)·세로
@export var gear_ride_orbit: Vector2 = Vector2(1.8, 1.1)
## 손 흔드는 폭 — 걸을 때 폭(hand_swing)의 몇 배
@export var gear_ride_hand_scale: float = 1.0

## **런닝머신 단계 장비를 끼우거나 뺀다**(stage ""이면 뺀다).
## entry는 {조각 이름: [위치, 각도, 크기]} — 머리·몸·손은 **제자리를 옮긴다**(걷기·공격이 다 제자리 기준이라
## 같이 따라온다). 두 발 그림은 숨기고 장비 그림(texture, 없으면 원래 발 그림)을 세운다.
## hover > 0이면 그만큼 공중에 떠서 bob 폭으로 둥실거린다
func set_treadmill_gear(stage: String, entry: Dictionary, texture: Texture2D, rolls: bool,
		hover: float = 0.0, bob: float = 0.0, bob_speed: float = 0.0) -> void:
	_clear_treadmill_gear()
	if stage == "":
		return
	_gear_stage = stage
	_gear_rolls = rolls
	_gear_hover = hover
	_gear_bob = bob
	_gear_bob_speed = bob_speed
	_gear_bob_time = 0.0
	# 머리·몸·손을 장비 단계 자리로 — 안 적힌 조각도 0으로 넣어 둔다(같이 떠야 하므로)
	var shifts: Dictionary = {}
	for part_name in GEAR_BODY_PARTS:
		var part: Node2D = _pose_part(part_name)
		if part == null or not _rest_positions.has(part):
			continue
		shifts[part] = (entry[part_name][0] as Vector2) - _base_rest(part) if entry.has(part_name) else Vector2.ZERO
	# 장비·불꽃은 전부 왼발 그림 밑에 붙인다(그리는 순서 = 불꽃 -> 장비 -> 몸통)
	var host: Sprite2D = _foot_l if _foot_l else _foot_r
	if host == null:
		return
	for side in ["L", "R"]:
		if entry.has("Flame" + side) and entry.has("Gear" + side):
			var flame: Node2D = JET_FLAME_SCRIPT.new()
			flame.name = "JetFlame" + side
			host.add_child(flame)
			_gear_flames[side] = flame
			_gear_flame_rest[side] = entry["Flame" + side]
	for side in ["L", "R"]:
		if not entry.has("Gear" + side):
			continue
		var foot: Sprite2D = _foot_l if side == "L" else _foot_r
		var gear := Sprite2D.new()
		gear.name = "TreadmillGear" + side
		gear.texture = texture if texture != null else (foot.texture if foot else null)
		host.add_child(gear)
		_gear_nodes[side] = gear
		_gear_rest[side] = entry["Gear" + side]
	# 장비가 두 발을 대신한다 — 발 그림만 지운다(self_modulate는 자식인 장비에 안 번진다)
	if not _gear_nodes.is_empty():
		for foot in [_foot_l, _foot_r]:
			if foot:
				foot.self_modulate.a = 0.0
	_gear_glide = 1.0
	_gear_ride = 0.0
	_gear_orbit = Vector2.ZERO
	_set_rest_layer("treadmill", shifts)
	_sync_foot_marks()
	_update_treadmill_gear(0.0)
	_apply_base_head()

## 지금 낀 단계("" = 없음)
func treadmill_gear_stage() -> String:
	return _gear_stage

## 장비를 빼고 머리·몸·손 제자리와 발 그림을 되돌린다
func _clear_treadmill_gear() -> void:
	for node in _gear_nodes.values() + _gear_flames.values():
		if is_instance_valid(node):
			node.queue_free()
	_gear_nodes.clear()
	_gear_rest.clear()
	_gear_flames.clear()
	_gear_flame_rest.clear()
	for foot in [_foot_l, _foot_r]:
		if foot:
			foot.self_modulate.a = 1.0
	var had_gear: bool = _gear_glide > 0.0
	_gear_stage = ""
	_gear_glide = 0.0
	_gear_hover = 0.0
	_gear_bob = 0.0
	_gear_ride = 0.0
	_gear_orbit = Vector2.ZERO
	_set_rest_layer("treadmill", {})
	_sync_foot_marks()
	if had_gear:
		_apply_base_head()

## 지금 공중에 뜬 만큼(둥실거림 포함, 위가 음수) — 머리·몸·손·장비에 똑같이 더한다
func _gear_lift() -> Vector2:
	if is_zero_approx(_gear_hover) and is_zero_approx(_gear_bob):
		return Vector2.ZERO
	return Vector2(0.0, -_gear_hover + sin(_gear_bob_time * TAU * _gear_bob_speed) * _gear_bob)

## **자세 계산 전에** 뜬 높이·바퀴 궤도를 다시 재서 제자리에 반영한다 —
## 걷기·공격·손에 든 물건이 다 이 제자리 기준이라 통째로 같이 뜨고 흔들린다
func _update_gear_lift(delta: float) -> void:
	if _gear_glide <= 0.0:
		return
	_gear_bob_time += delta
	# 바퀴로 달리는 중인지 — 땅에서 움직이거나 런닝머신 위에서 달리는 중
	var riding: bool = false
	if _gear_rolls:
		if _run_target > 0.5:
			riding = true
		elif _fighter and is_instance_valid(_fighter):
			riding = _fighter.is_on_floor() and absf(_fighter.velocity.x) > 20.0
		elif manual_speed_ratio > 0.05:
			riding = true
	_gear_ride = move_toward(_gear_ride, 1.0 if riding else 0.0, delta * 5.0)
	if _gear_ride > 0.0:
		_gear_ride_phase = fposmod(_gear_ride_phase + delta * TAU / maxf(gear_ride_cycle, 0.05), TAU)
	# 몸이 앞뒤로 둥근 궤도를 그린다(앞으로 나갈 때 살짝 내려가고, 뒤로 올 때 살짝 올라온다)
	_gear_orbit = Vector2(cos(_gear_ride_phase) * gear_ride_orbit.x, sin(_gear_ride_phase) * gear_ride_orbit.y) * _gear_ride
	_refresh_rest_layers()

## 매 프레임 장비를 제자리에 맞춘다(자세 계산이 다 끝난 뒤).
## 바퀴는 움직인 거리만큼 굴리고, 불꽃은 빠를수록 길게 뿜는다.
## 장비 크기는 편집 씬에서 맞춘 그대로다 — 스쿼트로 발이 커져도 바퀴는 안 커진다
func _update_treadmill_gear(delta: float) -> void:
	if _gear_nodes.is_empty():
		return
	# 리그 좌표로 앞(+x)으로 얼마나 빨리 가는지 — 리그가 뒤집혀 있으면 화면 속도 부호도 뒤집힌다
	var gx: float = global_transform.x.x
	var forward: float = 0.0
	var power: float = 0.0
	if _fighter and is_instance_valid(_fighter) and not is_zero_approx(gx):
		var max_speed: float = _fighter.stats.move_speed * _fighter.move_speed_multiplier
		forward = _fighter.velocity.x / gx
		power = clampf(absf(_fighter.velocity.x) / maxf(max_speed, 1.0), 0.0, 1.0)
		# 런닝머신 위에선 제자리지만 벨트 위를 달린다 — 최고 속도로 굴리고 불꽃도 가득
		if _run_target > 0.5:
			forward = max_speed / absf(gx)
			power = 1.0
	elif manual_speed_ratio >= 0.0:
		power = clampf(manual_speed_ratio, 0.0, 1.0)
	var first: Sprite2D = _gear_nodes.values()[0]
	if _gear_rolls and first.texture != null:
		var first_scale: Vector2 = _gear_rest.values()[0][2]
		var radius: float = first.texture.get_width() * 0.5 * absf(first_scale.x)
		_gear_spin = fposmod(_gear_spin + forward * delta / maxf(radius, 0.5), TAU)
	# 장비가 하나면 두 발을 대신하는 것이라 한쪽 발 움직임을 따라가지 않는다
	var single: bool = _gear_nodes.size() == 1
	var lift: Vector2 = _gear_lift()
	for side in _gear_nodes:
		var gear: Sprite2D = _gear_nodes[side]
		var foot: Sprite2D = _foot_l if side == "L" else _foot_r
		if not is_instance_valid(gear):
			continue
		var rest: Array = _gear_rest[side]
		var rest_scale: Vector2 = rest[2]
		var moved: Vector2 = Vector2.ZERO
		var tilt: float = 0.0
		if not single and foot:
			moved = foot.position - _rest_positions[foot]
			tilt = foot.rotation
		var pos: Vector2 = rest[0] + moved + lift
		var angle: float = rest[1] + (_gear_spin if _gear_rolls else tilt)
		gear.global_transform = global_transform * Transform2D(angle, rest_scale, 0.0, pos)
		# 불꽃은 장비 그림 안 자리 — 바퀴처럼 돌지는 않게 굴린 각도는 빼고 붙인다
		var flame: Node2D = _gear_flames.get(side) as Node2D
		if flame and is_instance_valid(flame):
			var f: Array = _gear_flame_rest[side]
			var shoe: Transform2D = global_transform * Transform2D(rest[1] + tilt, rest_scale, 0.0, pos)
			flame.global_transform = shoe * Transform2D(f[1], f[2], 0.0, f[0])
			flame.power = power

## 레벨업 폭죽이 터질 부위 — "hands"면 두 손, "feet"면 두 발(장비를 끼웠으면 장비).
## 부르는 쪽이 이 목록의 **가운데에 하나만** 터뜨린다
func burst_anchors(part: String) -> Array[Node2D]:
	var out: Array[Node2D] = []
	if part == "hands":
		for hand in [_hand_l, _hand_r]:
			if hand:
				out.append(hand)
		return out
	if not _gear_nodes.is_empty():
		for gear in _gear_nodes.values():
			if is_instance_valid(gear):
				out.append(gear)
		return out
	for foot in [_foot_l, _foot_r]:
		if foot:
			out.append(foot)
	return out


## --- 헬스장 바벨 컬(손)·스쿼트(발) 단계 (maps/workout/LimbStageData.gd, skills/WorkoutSkill.gd) ---
## 두 운동은 부위만 다르고 똑같다(2026-10-06 사용자): 4스택부터 커지고 핏줄(💢) 하나가 울끈불끈,
## 7스택부터 1.5배에 핏줄 셋, 10스택은 금빛 + 주위에 다이아몬드 반짝이.
## 자리는 `maps/workout/Curl*Studio.tscn`·`Squat*Studio.tscn`에서 캐릭터마다 맞춘다

const PULSE_SCRIPT := preload("res://combat/PulseSprite.gd")
const GOLD_SHADER := preload("res://characters/GoldLimb.gdshader")

## 부위별 지금 단계 {"hands": "vein1" 등}
var _limb_stage: Dictionary = {}
## 부위별로 붙인 핏줄·반짝이 {"hands": [Sprite2D, ...]}
var _limb_marks: Dictionary = {}
## 그림을 바꿔 낀 조각의 원래 그림 {조각: Texture2D}
var _limb_saved_tex: Dictionary = {}
## 금빛 셰이더를 입힌 조각들
var _limb_gold_parts: Array = []
## 그림을 바꿔서 생긴 크기 보정 — 새 그림이 원래 손·발과 같은 크기로 보이게 곱한다
var _hand_tex_fit: float = 1.0
var _foot_tex_fit: float = 1.0

func _limb_parts(limb: String) -> Array:
	return [_hand_l, _hand_r] if limb == "hands" else [_foot_l, _foot_r]

## 지금 그 부위 단계("" = 없음)
func limb_stage(limb: String) -> String:
	return _limb_stage.get(limb, "")

## **바벨 컬(hands)·스쿼트(feet) 단계를 입히거나 벗긴다**(stage ""이면 벗긴다).
## entry: {"HandL": [위치, 각도, 크기], ..., "HandR/Vein1": [위치, 각도, 크기, 그림 경로], ...}
## — 손·발은 **제자리를 옮기고**, "조각/이름"은 그 조각의 자식으로 붙는 핏줄(Vein*)·반짝이(Spark*)다.
## size: 원래 크기의 몇 배 / texture: 바꿔 낄 그림(없으면 그대로) / fit: 그 그림을 원래 크기로 맞추는 배율 / gold: 금빛 셰이더
func set_limb_stage(limb: String, stage: String, entry: Dictionary, size: float,
		texture: Texture2D = null, fit: float = 1.0, gold: bool = false) -> void:
	_clear_limb_stage(limb)
	if stage == "":
		return
	_limb_stage[limb] = stage
	var shifts: Dictionary = {}
	var marks: Array = []
	for part in _limb_parts(limb):
		if part == null:
			continue
		var key: String = String(part.name)
		if entry.has(key) and _rest_positions.has(part):
			shifts[part] = (entry[key][0] as Vector2) - _base_rest(part)
		if texture != null:
			_limb_saved_tex[part] = part.texture
			part.texture = texture
		elif gold:
			var mat := ShaderMaterial.new()
			mat.shader = GOLD_SHADER
			part.material = mat
			_limb_gold_parts.append(part)
		# 핏줄·반짝이 — 이 조각 그림 안 좌표라 손·발이 커지고 움직이면 같이 따라간다
		for mark_key in entry:
			if not String(mark_key).begins_with(key + "/"):
				continue
			var data: Array = entry[mark_key]
			var mark: Sprite2D = PULSE_SCRIPT.new()
			mark.name = String(mark_key).get_slice("/", 1)
			if data.size() > 3 and String(data[3]) != "" and ResourceLoader.exists(String(data[3])):
				mark.texture = load(String(data[3]))
			mark.position = data[0]
			mark.rotation = data[1]
			mark.scale = data[2]
			mark.mode = 1 if mark.name.begins_with("Spark") else 0
			part.add_child(mark)
			marks.append(mark)
	_limb_marks[limb] = marks
	_set_rest_layer("limb_" + limb, shifts)
	if limb == "hands":
		muscle_arm = size
		_hand_tex_fit = fit if texture != null else 1.0
	else:
		muscle_leg = size
		_foot_tex_fit = fit if texture != null else 1.0
	_muscle_arm_shown = -1.0   # 크기를 바로 다시 입히게
	_apply_muscle()
	_sync_foot_marks()

## 그 부위 단계를 벗긴다 — 핏줄·반짝이를 떼고 그림·크기·제자리를 되돌린다
func _clear_limb_stage(limb: String) -> void:
	# 바로 떼어 낸다 — 같은 프레임에 다음 단계 핏줄을 같은 이름(Vein1)으로 붙이면 이름이 밀려 바뀐다
	for mark in _limb_marks.get(limb, []):
		if is_instance_valid(mark):
			if mark.get_parent():
				mark.get_parent().remove_child(mark)
			mark.queue_free()
	_limb_marks.erase(limb)
	for part in _limb_parts(limb):
		if part == null:
			continue
		if _limb_saved_tex.has(part):
			part.texture = _limb_saved_tex[part]
			_limb_saved_tex.erase(part)
		if part in _limb_gold_parts:
			part.material = null
			_limb_gold_parts.erase(part)
	_limb_stage.erase(limb)
	_set_rest_layer("limb_" + limb, {})
	if limb == "hands":
		muscle_arm = 1.0
		_hand_tex_fit = 1.0
	else:
		muscle_leg = 1.0
		_foot_tex_fit = 1.0
	_muscle_arm_shown = -1.0
	_apply_muscle()

## 런닝머신 장비가 발을 대신하는 동안엔 발에 붙은 핏줄·반짝이도 숨긴다(발 그림이 안 보이니까)
func _sync_foot_marks() -> void:
	for mark in _limb_marks.get("feet", []):
		if is_instance_valid(mark):
			mark.visible = _gear_nodes.is_empty()


## --- 2P 색 (maps/Stage.gd) ---

@export_group("2P 색")
## **2P가 쓸 몸통 그림.** 두 사람이 같은 캐릭터를 골랐을 때 누가 누군지 보이라고 색만 바꿔 둔 것이다.
## 비워 두면 2P도 평소 몸통을 그대로 쓴다(아직 색 그림이 없는 캐릭터)
@export var p2_body_texture: Texture2D
## 2P가 쓸 **몸통 돌리기** 그림들 — 비워 두면 머리를 돌리는 동안만 원래 색이 보인다.
## `body_turn_textures`와 장수를 맞춰 넣을 것
@export var p2_body_turn_textures: Array[Texture2D] = []

## 지금 2P 색인지
var _is_player_two: bool = false

## **2P 색으로 갈아입힌다**(`maps/Stage.gd`가 2P를 만들 때 부른다).
## 몸통은 걷기·돌기가 `_body_rest_texture`를 기준으로 삼으므로 그 기준까지 같이 바꾼다 —
## 안 그러면 한 걸음 걷는 순간 원래 색으로 되돌아간다
func set_player_two(on: bool) -> void:
	_is_player_two = on
	if not on or p2_body_texture == null:
		return
	_body_rest_texture = p2_body_texture
	if _body:
		_body.texture = p2_body_texture
	if not p2_body_turn_textures.is_empty():
		body_turn_textures = p2_body_turn_textures
	else:
		# **P2용 측면 몸통이 없으면 몸통 돌리기를 아예 끈다**(2026-10-05 사용자 판단) —
		# 안 끄면 머리를 돌리는 동안만 1P 색 몸통이 튀어나온다. 머리는 그대로 돌아간다
		body_turn_textures = []

## 2P 색을 쓰는 중인지 — 다른 연출이 물어볼 수 있게 열어 둔다
func is_player_two() -> bool:
	return _is_player_two
