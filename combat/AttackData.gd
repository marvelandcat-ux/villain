class_name AttackData
extends Resource

## 콤보 **한 타**의 모든 성질을 한 파일에 담는다(2026-09-17, 브롤할라식 평타 재설계).
##
## 예전엔 `ComboMeleeAttack`의 배열 여러 개(combo_damage·combo_knockback·combo_pop·combo_lunge...)에
## 타별 값이 흩어져 있어서, 4타를 추가하거나 한 타만 성질을 바꾸려면 배열을 전부 같이 고쳐야 했다.
## 이제 `ComboMeleeAttack.hits`에 이 파일을 순서대로 넣으면 그게 곧 콤보다 — 목록 길이가 곧 타 수이고,
## **마지막 칸이 마무리 타**(넉백으로 날리는 타)다.
##
## **판정 시각은 직접 적지 않는다.** 몸(BodyRig)에게 "이 모션이면 언제 맞느냐"를 물어서 정한다
## (`BodyRig.strike_time`) — 모션 길이만 바꾸면 판정이 저절로 따라온다.

@export_group("기본")
## 데미지 (공격력 버프가 곱해진다)
@export var damage: int = 5
## 휘두르는 모션의 전체 길이(초). **판정 시각은 이 값에서 자동으로 나온다** —
## 보통 타는 40% 지점, 회전 타는 회전 공식(spin_end x spin_strike) 지점. 짧을수록 빠른 잽이다
@export var anim_duration: float = 0.35
## 몸이 재생할 휘두르기 모양 번호. -1이면 콤보 안에서의 순서(0=1타, 1=2타...)를 그대로 쓴다
@export var anim_variant: int = -1
## 판정이 켜져 있는 시간(초). 이 안에 안 맞으면 헛친 것으로 친다
@export var active_time: float = 0.12

@export_group("연출")
## 켜면 이 타는 **한 바퀴 돌면서** 친다(몸이 좌우로 한 번 뒤집혔다 돌아오는 동안 무기·발이 들어간다)
@export var spin: bool = false
## 히트스톱(맞는 순간 화면 정지) 길이 배수. 마무리 타를 크게 주면 묵직해진다
@export var hitstop_scale: float = 1.0
## 화면 흔들림 배수
@export var shake_scale: float = 1.0

@export_group("앞 타 — 붙잡아 두기")
## 맞은 상대가 미끄러지는 거리(px) = pushback_base + 실제 데미지 x pushback_per_damage.
## **마지막 타(마무리)에서는 안 쓴다** — 마무리는 아래 넉백으로 날린다.
## 둘 다 0이면 knockback의 x로 민다
@export var pushback_base: float = 0.0
@export var pushback_per_damage: float = 0.0
## 이 타를 휘두르는 동안 **직전 타에 상대가 밀린 거리만큼** 따라붙는다
@export var lunge_follows_pushback: bool = true
## 따라붙는 거리에 더할 px (직전 타가 없어도 이만큼은 나간다)
@export var lunge_extra: float = 0.0
## 따라붙는 데 걸리는 시간(초). 0이면 판정 시각까지(예전 방식 — 짧으면 순간이동처럼 보인다).
## 판정보다 길게 주면 때린 뒤에도 조금 더 밀고 들어간다 (판정은 캐릭터를 따라가므로 헛치지 않는다)
@export var lunge_time: float = 0.0
## 앞쪽 이 비율(0~0.6) 동안은 **발만 먼저 내딛고 몸은 거의 안 움직인다** — 그 뒤 몸이 부드럽게 따라간다.
## 0이면 예전처럼 처음에 확 나가고 끝에서 멈춘다
@export_range(0.0, 0.6, 0.05) var lunge_foot_lead: float = 0.0

@export_group("마무리 타 — 날리기")
## 넉백 (x는 바라보는 방향 기준 앞, y는 음수가 위). 앞 타에서는 타격 섬광 방향으로만 쓰인다
@export var knockback: Vector2 = Vector2(60.0, 0.0)
## 위로 띄우는 힘(px/초). 0이면 안 띄우고, 음수면 데미지 비례 기본 팝업
@export var pop: float = 0.0
## 맞은 상대가 조작을 못 하는 시간(초). 0이면 넉백 세기로 자동
@export var hitstun: float = 0.0
## 날아가는 동안 몸이 구르는 바퀴 수 (0이면 안 구른다)
@export var tumble_turns: float = 0.0
## 날아가는 동안 연기 꼬리를 남길지
@export var launch_smoke: bool = false
