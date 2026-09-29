class_name ComboMeleeAttack
extends MeleeAttack

## 히트 확인식 3타 기본 콤보.
## - 누르면 평타가 나간다. 그 스윙의 결과가 나올 때까지 다음 입력은 "예약"만 해둔다.
## - 맞으면 → 예약된 입력이 있으면 즉시 다음 타로 이어진다(최대 3타). 늦게 눌러도 chain_window 안이면 이어진다.
## - 어느 타에서든 헛발질(빗맞음) 하면 → 예약 입력은 버려지고, 기본공격 쿨타임(cooldown)이 돌고 콤보가 1타로 리셋된다.
##   (그래서 헛치고 연타해도 2·3타가 나가지 않는다. 3타를 다 맞추려면 날아가는 상대를 따라가는 컨트롤이 필요하다.)
## - 3타까지 다 맞추면 마무리 회복 쿨이 붙는다.
##
## 명중 여부는 Hitbox.connected 신호로 감지한다. 훈련장은 cooldown이 0으로 꺼져 있어 허공 연습은 쿨 없이 자유롭다.

## **새 방식(2026-09-17): 타마다 AttackData 파일 하나.** 여기에 순서대로 넣으면 그게 곧 콤보다 —
## 목록 길이가 타 수이고 마지막 칸이 마무리 타다. 데미지·모션 길이·회전·푸시백·파고들기·넉백·구르기·히트스톱을
## 전부 그 파일에서 읽고, **판정 시각은 몸(BodyRig.strike_time)에게 물어서** 모션과 자동으로 맞춘다.
## **비어 있으면 아래 옛 배열(combo_damage 등)과 windup·finisher_windup·pushback_*·launch_*를 그대로 쓴다** —
## 아직 옮기지 않은 캐릭터는 예전과 똑같이 동작한다
@export var hits: Array[AttackData] = []

## 타별 데미지 (총 3타) — hits가 비어 있을 때만 쓴다
@export var combo_damage: Array[int] = [3, 4, 7]
## 타별 넉백 (x는 앞 방향 자동반전, y는 띄우기)
## **1·2타는 조금만 민다(2026-09-17 확정 콤보 정리).** 예전엔 세 타 다 (220, -90)이었는데,
## 1타에 약 30px 밀리고 위로 뜬 상대가 2타 판정(캐릭터 앞 40px의 30x30 상자) 밖으로 빠져서
## **서 있는 상대에게 연타해도 7명 중 5명이 2타를 못 맞혔다**(헤드리스 실측). 앞 타는 붙잡아 두고 마무리 타만 날린다
@export var combo_knockback: Array[Vector2] = [
	Vector2(60, 0),
	Vector2(60, 0),
	Vector2(220, -90),
]
## 타별로 상대를 위로 띄우는 힘(px/s). 0=지상 유지, 음수=기본 팝업(위로 붕 뜬다).
## 앞 타를 띄우면 상대가 판정 높이(±15px) 위로 떠서 다음 타가 허공을 친다 — 그래서 1·2타는 0이다
@export var combo_pop: Array[float] = [0.0, 0.0, -1.0]
## 1·2타가 맞으면 **다음 타가 들어갈 때까지 상대 경직을 최소한 보장**하는 여유(초).
## 보장 경직 = 다음 타의 예비동작(windup) + 이 값. 가장 빠르게 이어 치면 상대가 풀려나기 전에 맞는다 = 확정 콤보.
## 늦게 누르면(chain_window 안이라도) 그만큼 상대가 먼저 풀려나 막거나 피할 수 있다 — 빨리 이어야 확정이다.
## 0 이하로 두면 보장하지 않는다(넉백 크기로 정해지는 경직만 쓴다)
@export var link_stun_margin: float = 0.12
## 타별로 휘두르는 동안 **앞으로 파고드는 거리(px)**. 0이면 제자리에서 친다(기본값 — 다른 캐릭터 영향 없음).
## 앞 타의 넉백으로 밀려난 상대를 따라붙어 치는 격투게임식 연출이다(촉법소년 2026-09-17).
## 이동은 예비동작(windup) 동안에 끝나고, 판정은 **도착한 자리** 기준으로 나간다 — 그래서 밀린 상대에게 닿는다.
## 드롭킥 마무리 타는 스스로 앞으로 뛰므로 그 칸은 무시된다
@export var combo_lunge: Array[float] = [0.0, 0.0, 0.0]

## --- 데미지 비례 푸시백 (앞 타 1·2타) ---
## 둘 다 0이면 꺼진다(기본값 — 예전처럼 combo_knockback의 x로 민다).
## 켜면 앞 타에 맞은 상대가 **기본 거리 + 실제 데미지 x 데미지당 거리(px)** 만큼 미끄러진다.
## 실제 데미지(버프 반영, `compute_damage` 결과)를 쓰므로 왕관·열등감 같은 공격력 버프가 걸리면 더 멀리 밀린다
@export var pushback_base: float = 0.0
@export var pushback_per_damage: float = 0.0
## 켜면 다음 타에 파고드는 거리가 **직전 타에 상대가 밀린 거리**를 따라간다(combo_lunge 칸 값은 여기에 더해진다).
## 푸시백만 키우고 파고들기를 안 맞추면 다음 타가 판정 밖으로 빗나가는데, 그 짝을 자동으로 맞춰준다
@export var lunge_follows_pushback: bool = false
## 한 타가 맞은 뒤 다음 타를 눌러 이어갈 수 있는 시간(초)
@export var chain_window: float = 1.0
## 헛발질(빗맞음)했을 때만 도는 쿨타임(초). 음수면 기본 cooldown을 그대로 쓴다.
## 3타 마무리 쿨은 cooldown이라, 이 값으로 "못 맞췄을 때만" 더 크게 벌칙을 줄 수 있다
@export var miss_cooldown: float = -1.0
## 히트박스의 debris_scene(주정뱅이 술방울)을 **마무리 3타에서만** 뿌릴지.
## 매 타 뿌리면 한 병으로 세 번 깨지는 꼴이라 어색하고 바닥에 계속 쌓인다
@export var debris_final_hit_only: bool = true
## 이만큼 맞히면 손에 든 무기가 부서진 그림으로 바뀐다(주정뱅이 소주병 -> 깨진 소주병). 0이면 안 부서진다.
## 맞힌 횟수만 세고 헛친 건 안 센다. 라운드가 바뀌면 씬이 새로 만들어지면서 0부터 다시 센다
@export var break_after_hits: int = 0
## 부서진 뒤로 갈아끼울 그림. 원래 그림과 캔버스 크기가 같아야 손에 쥔 자리가 안 어긋난다
@export var broken_item_texture: Texture2D
## 부서지는 순간 명중 지점에 터뜨릴 파편 장면과 개수 (주정뱅이는 유리조각 5개)
@export var break_debris_scene: PackedScene
@export var break_debris_count: int = 5

## --- 마무리 타로 멀리 날려보내기 (촉법소년 3타 발차기) ---
## 0보다 크면 마무리 타에 맞은 상대가 이 시간(초) 동안 조작을 못 한 채 날아간다.
## **날아가는 거리를 정하는 건 combo_knockback의 마지막 칸이고**, 이 값은 "날아가는 동안 못 움직이는 시간"이다 —
## 짧으면 넉백이 한창 실려 있는데 조작이 돌아와 공중에서 제자리걸음을 한다. 0이면 평소대로(넉백 세기에 비례)
@export var launch_stun: float = 0.0
## 날아가는 동안 몸이 도는 바퀴 수 (0이면 안 돈다). 바닥에 닿으면 그 자리에서 일어선다
@export var launch_spin_turns: float = 0.0
## 날아가는 동안 뒤에 연기 꼬리를 남길지
@export var launch_smoke: bool = false
## 마무리 타 넉백 가로 세기에 곱하는 배수 — 3타로 더 멀리 날린다(2026-09-26 사용자 요청 "거리 1.5배", 전 캐릭터 공통). 1이면 예전과 같다.
## **거리가 아니라 속도 배수다** — 바닥에서 미끄러지는 거리는 속도의 제곱에 비례해서, 1.5를 주면 거리가 1.8~2.1배가 됐다(실측).
## 1.25일 때 거리 약 1.5배(금쪽이 3타 몫 194 -> 280px, 악플러 38 -> 57px)
@export var finisher_distance_scale: float = 1.25
## 마무리 타에 맞은 상대에게 날아가는 이펙트(충격·바람 줄기·먼지 고리, `combat/LaunchTrail.gd`)를 붙일지
@export var finisher_trail: bool = true

## --- 키보드 회전 난무 (악플러: 그랩으로 끌어온 직후 다음 기본공격) ---
## 켜면, 상대를 그랩으로 끌어온 직후(custom_data["keyboard_spin_charged"]가 켜져 있을 때) 다음 기본공격이
## 두 손으로 무기를 빙빙 돌리는 회전 난무로 바뀐다 — 몸 주변 원형 다단히트, 도는 동안 좌우 이동 가능.
## 기본 꺼짐(다른 캐릭터 영향 없음). 시각은 BodyRig.play_keyboard_fan이 맡는다
@export var spin_flurry_enabled: bool = false
## 회전 난무가 지속되는 시간(초)
@export var spin_flurry_duration: float = 2.0
## 다단히트 간격(초) — 이 간격마다 주변 상대에게 한 번씩 들어간다
@export var spin_flurry_interval: float = 0.18
## 한 번의 타격 데미지
@export var spin_flurry_damage: int = 2
## 판정 반경(px) — 도는 무기가 닿는 몸 주변 원
@export var spin_flurry_radius: float = 70.0
## 한 대마다의 넉백(x는 바라보는 쪽 자동반전, y는 띄우기) — 원형이라 세게 밀면 상대가 판정 밖으로
## 나가 다음 타가 헛치므로 살짝만 준다
@export var spin_flurry_knockback: Vector2 = Vector2(30, 0)

## 타입을 안 붙이고 preload로 가져온다 — 새로 만든 class_name은 전역 클래스 캐시가 갱신되기 전엔
## 못 찾아서 파싱 에러가 난다 (Fighter._shield, ShoulderChargeSkill의 ChargeWind와 같은 이유)
const LAUNCH_SMOKE := preload("res://combat/LaunchSmoke.gd")
const LAUNCH_TRAIL := preload("res://combat/LaunchTrail.gd")

## --- 드롭킥 마무리 (촉법소년 3타) ---
## 켜면 마무리 타가 "뛰어올라 두 발로 차고 넘어졌다 일어나는" 드롭킥이 된다.
## 꺼져 있으면(기본값) 지금까지처럼 제자리에서 때린다 — 다른 캐릭터는 영향이 없다
@export var dropkick_finisher: bool = false
## 뛰어오를 때 위로 솟는 속도(px/초). 중력 1150에서 280이면 체공 약 0.49초
@export var dropkick_lift: float = 280.0
## 공중에서 앞으로 나가는 속도(px/초). 0.49초 x 130 = 약 60px 전진한다.
## **전진 거리를 바꾸려면 이 값을 고칠 것** — lift를 건드리면 체공이 같이 변해 거리도 따라 변한다
@export var dropkick_speed: float = 130.0
## 착지해서 일어나는 동안 움직이지도 때리지도 못하는 시간(초) — 빗나갔을 때의 대가
@export var dropkick_getup: float = 0.5
## 마무리 타만 쓰는 예비동작(초). -1이면 windup을 그대로 쓴다. 드롭킥이 아니어도 쓴다(촉법소년 뒤돌려차기 0.25 = 리그 kick_duration 0.55 x kick_spin_end 0.62 x kick_spin_hit 0.72).
## **두 발이 다 뻗은 뒤에 판정이 켜져야 한다** — 뛰어오르는 도중에 켜지면 몸통으로 때리는 꼴이 된다
@export var finisher_windup: float = -1.0

## 뛰어오른 직후 이만큼(초)은 바닥 판정을 보지 않는다 — 그 프레임엔 아직 발이 땅에 붙어 있어서
## 바로 검사하면 뛰자마자 착지한 것으로 친다
const DROPKICK_GROUND_GRACE := 0.1
## 어떤 이유로든 착지를 못 잡았을 때(맵 밖으로 떨어지는 중 등) 강제로 끝내는 시간(초)
const DROPKICK_MAX_AIR := 1.5

## 지금 낼 타 (0=1타, 1=2타, 2=3타)
var _step: int = 0
## 지금 스윙이 진행 중인지 (발동~명중/헛발 판정까지). 이 동안 들어온 입력은 예약된다
var _swinging: bool = false
## 이번 스윙의 판정이 끝났는지 (명중/헛발을 두 번 처리하지 않도록)
var _resolved: bool = false
## 스윙 중에 다음 타 입력이 들어왔는지 (맞으면 즉시 다음 타로 소모, 헛발이면 버림)
var _queued: bool = false
## 지금 스윙이 몇 번째 타였는지
var _swing_step: int = 0
## 맞은 뒤 다음 입력을 기다리는 여유 시간
var _chain_left: float = 0.0
## 켜둔 히트박스를 끄기까지 남은 시간
var _active_left: float = 0.0
var _fighter: Fighter = null
## 이 라운드에 술병으로 맞힌 횟수 / 이미 부서졌는지
var _hits_landed: int = 0
var _broken: bool = false
## 드롭킥이 도는 중인지 / 아직 공중인지
var _dk_active: bool = false
var _dk_air: bool = false
## 착지 판정을 미루는 시간 / 지금까지 뜬 시간 / 일어나기까지 남은 시간 / 뛰어든 방향
var _dk_grace: float = 0.0
var _dk_airtime: float = 0.0
var _dk_getup_left: float = 0.0
var _dk_dir: float = 1.0
## 파고들기(combo_lunge) 남은 시간 / 속도 / 방향
var _lunge_left: float = 0.0
var _lunge_speed: float = 0.0
## 파고들기 전체 시간 — 속도를 처음엔 빠르게, 끝으로 갈수록 줄이는 데 쓴다
var _lunge_time: float = 0.0
var _lunge_dir: float = 1.0
## 파고드는 시간 중 발만 먼저 나가는 앞부분 비율 (0이면 처음부터 몸이 나간다)
var _lunge_lead: float = 0.0
## 직전 앞 타에 상대가 밀린 거리(px) — lunge_follows_pushback이 다음 타 파고들기에 쓴다
var _last_pushback: float = 0.0
## 키보드 회전 난무가 도는 중인지 / 남은 시간(초) / 회전 중 바꿔둔 히트박스 원래 모양(끝나면 복구)
var _spin_active: bool = false
var _spin_left: float = 0.0
var _spin_saved_shape: Shape2D = null

## 이만큼보다 짧은 시간에 파고들지는 않는다 — 예비동작이 0인 캐릭터가 한 프레임에 순간이동하지 않게
const LUNGE_MIN_TIME := 0.08

## --- 타별 값 읽기 (hits가 있으면 파일에서, 없으면 옛 배열에서) ---

func _hit_count() -> int:
	return hits.size() if not hits.is_empty() else combo_damage.size()

func _is_final(step: int) -> bool:
	return step >= _hit_count() - 1

func _hit_data(step: int) -> AttackData:
	if hits.is_empty() or step < 0 or step >= hits.size():
		return null
	return hits[step]

## 이 타를 누른 뒤 몇 초 뒤에 판정을 켤지.
## 새 방식은 몸에게 물어본다 — 모션 길이만 바꿔도 판정이 따라오게(예전엔 finisher_windup을 손으로 맞춰야 했다)
func _windup_for(step: int, fighter: Fighter) -> float:
	var d: AttackData = _hit_data(step)
	if d != null:
		var visual: Node = fighter.get_node_or_null("Visual") if is_instance_valid(fighter) else null
		if visual and visual.has_method("strike_time"):
			return visual.strike_time(d.anim_duration, d.spin)
		return d.anim_duration * 0.4
	if _is_final(step) and finisher_windup >= 0.0:
		return finisher_windup
	return windup

func _ready() -> void:
	super()   # start_on_cooldown 처리 (기본공격은 꺼져 있지만 규칙을 깨지 않는다)
	# 명중하는 순간(스윙 진행 중이면) 곧바로 "맞음"으로 판정한다
	hitbox.connected.connect(_on_hitbox_connected)

func _on_hitbox_connected(victim: Node) -> void:
	_count_hit_for_break()
	if _swinging and not _resolved:
		# **_resolve보다 먼저 부른다** — _resolve는 예약 입력이 있으면 그 자리에서 다음 타를 시작하면서
		# _swing_step을 바꿔버려, 뒤에 부르면 "몇 번째 타였는지"를 잘못 보게 된다
		_hold_for_next_hit(victim)
		_launch_finisher(victim)
		_resolve(true)

## 앞 타(1·2타)가 맞았을 때 — 다음 타가 들어갈 때까지 상대가 못 움직이게 경직을 보장한다.
## 넉백에서 나온 경직이 이미 더 길면 그대로 둔다(apply_hitstun이 큰 쪽을 남긴다)
func _hold_for_next_hit(victim: Node) -> void:
	if _is_final(_swing_step):
		return
	if not (victim is Fighter) or not is_instance_valid(victim):
		return
	var target: Fighter = victim
	# 막은 쪽은 맞지 않았으므로 붙잡지 않는다
	if target.is_guarding:
		return
	# **앞 타에 밀리던 속도를 지우고 이번 넉백만 남긴다.** Fighter.take_damage는 넉백을 기존 속도에 더해서,
	# 1타에 밀리는 중에 2타를 맞으면 두 넉백이 겹쳐 상대가 한참 더 미끄러졌다(촉법소년 실측: 3타 준비 동안 약 70px).
	# 격투게임처럼 "한 대에 한 칸씩" 일정하게 밀리게 한다
	var d: AttackData = _hit_data(_swing_step)
	var push_base: float = d.pushback_base if d != null else pushback_base
	var push_per: float = d.pushback_per_damage if d != null else pushback_per_damage
	if push_base > 0.0 or push_per > 0.0:
		_apply_pushback(target, push_base, push_per)
	elif hitbox.knockback.x != 0.0:
		target.velocity.x = hitbox.knockback.x * Fighter.KNOCKBACK_MULTIPLIER
	if d != null and d.hitstun > 0.0:
		target.apply_hitstun(d.hitstun)
	if link_stun_margin <= 0.0:
		return
	# 다음 타가 들어갈 때까지 붙잡아 둔다 — 다음 타의 판정 시각은 _windup_for가 안다(새 방식이면 몸에게 물어본다)
	target.apply_hitstun(_windup_for(_swing_step + 1, _fighter) + link_stun_margin)

## 데미지에 비례한 거리만큼 상대를 밀어낸다.
## 경직 중 마찰(HITSTUN_FRICTION)로 멈추므로 "distance만큼 가서 멈추는 첫 속도"를 거꾸로 구한다: v = sqrt(2 x 마찰 x 거리).
## **다 미끄러질 때까지 경직을 보장한다** — 경직이 먼저 풀리면 그 순간 속도가 0이 돼서 덜 밀린다
func _apply_pushback(target: Fighter, base: float, per_damage: float) -> void:
	var distance: float = maxf(base + float(hitbox.damage) * per_damage, 0.0)
	_last_pushback = distance
	var dir: float = 1.0
	if is_instance_valid(_fighter) and not is_zero_approx(_fighter.facing):
		dir = signf(_fighter.facing)
	var speed: float = sqrt(2.0 * Fighter.HITSTUN_FRICTION * distance)
	target.velocity.x = dir * speed
	target.apply_hitstun(speed / Fighter.HITSTUN_FRICTION)

## 마무리 타에 맞은 상대를 멀리 날려보낸다. 데미지·넉백은 히트박스가 이미 줬고 여기서는
## **날아가는 동안의 경직·구르기·연기만** 얹는다. 가드로 막혔으면 아무것도 안 한다
func _launch_finisher(victim: Node) -> void:
	if not _is_final(_swing_step):
		return
	var d: AttackData = _hit_data(_swing_step)
	var stun: float = d.hitstun if d != null else launch_stun
	var turns: float = d.tumble_turns if d != null else launch_spin_turns
	var smoke: bool = d.launch_smoke if d != null else launch_smoke
	if not (victim is Fighter) or not is_instance_valid(victim):
		return
	var target: Fighter = victim
	# 막은 쪽은 넉백도 데미지도 안 받았으므로 날아가지도 않는다 (막았는데 구르면 어긋나 보인다)
	if target.is_guarding:
		return
	var dir: float = 1.0
	if is_instance_valid(_fighter) and not is_zero_approx(_fighter.facing):
		dir = signf(_fighter.facing)
	# 날아가는 이펙트는 경직·구르기 설정과 상관없이 모든 캐릭터의 마무리 타에 붙인다
	if finisher_trail:
		_spawn_launch_trail(target, Vector2(dir, -0.35))
	if stun <= 0.0 and turns <= 0.0 and not smoke:
		return
	if stun > 0.0:
		target.apply_hitstun(stun)
	if turns > 0.0 and target.has_method("play_launch_tumble"):
		# 도는 시간은 못 움직이는 시간과 맞춘다 — 경직이 없으면 짧게 한 번 굴리고 만다
		target.play_launch_tumble(turns, stun if stun > 0.0 else 0.6, dir)
	if smoke:
		_spawn_launch_smoke(target, maxf(stun, 0.45))

## 마무리 타 이펙트(충격·바람 줄기·먼지 고리)를 **맵에** 붙인다 — 연기와 같은 이유(자식이면 좌우 반전에 뒤집힌다)
func _spawn_launch_trail(target: Fighter, dir: Vector2) -> void:
	var parent: Node = target.get_parent()
	if parent == null:
		return
	var trail = LAUNCH_TRAIL.new()
	parent.add_child(trail)
	trail.setup(target, dir)

## 날아가는 사람을 따라다니며 연기를 흘리는 노드를 **맵에** 붙인다 (맞은 사람의 자식으로 달면
## 그 사람이 좌우로 뒤집힐 때 연기까지 뒤집힌다)
func _spawn_launch_smoke(target: Fighter, duration: float) -> void:
	var parent: Node = target.get_parent()
	if parent == null:
		return
	var smoke = LAUNCH_SMOKE.new()
	parent.add_child(smoke)
	smoke.setup(target, duration)

## 맞힌 횟수를 세다가 break_after_hits에 닿으면 무기를 깨뜨린다 — 한 라운드에 한 번뿐이다.
## 방어에 막힌 한 방도 센다(병이 방패에 부딪힌 것도 부딪힌 것이다)
func _count_hit_for_break() -> void:
	if _broken or break_after_hits <= 0:
		return
	_hits_landed += 1
	if _hits_landed < break_after_hits:
		return
	_broken = true
	_swap_to_broken()
	_spawn_break_debris()

## 손에 든 무기 그림을 부서진 것으로 갈아끼운다 (리그에 그 기능이 없으면 그냥 넘어간다)
func _swap_to_broken() -> void:
	if broken_item_texture == null or not is_instance_valid(_fighter):
		return
	var visual: Node = _fighter.get_node_or_null("Visual")
	if visual and visual.has_method("swap_held_texture"):
		visual.swap_held_texture(broken_item_texture)

## 깨지는 순간 명중 지점에 파편을 한꺼번에 터뜨린다. 떨어지고 사라지는 처리는 파편 쪽이 맡는다
func _spawn_break_debris() -> void:
	if break_debris_scene == null:
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	for i in break_debris_count:
		var piece: Node = break_debris_scene.instantiate()
		scene_root.add_child(piece)
		if piece.has_method("setup"):
			piece.setup(hitbox.global_position)
		elif piece is Node2D:
			piece.global_position = hitbox.global_position

## 스윙 중(예약용)이거나 이어치기 여유가 있거나 쿨이 없으면 입력을 받아준다.
## 그랩 충전이 걸려 있으면 쿨과 상관없이 회전 난무를 받아준다(끌어온 직후 바로 나가야 하므로)
func can_use() -> bool:
	if spin_flurry_enabled and not _spin_active and _fighter != null and is_instance_valid(_fighter) and _fighter.custom_data.get("keyboard_spin_charged", false):
		return true
	return _swinging or _chain_left > 0.0 or cooldown_left <= 0.0

func use(fighter: Fighter) -> void:
	_fighter = fighter
	# 그랩으로 끌어온 직후 다음 기본공격 1번은 키보드 회전 난무로 바뀐다(악플러 강화). 쓰면 충전이 소모된다
	if spin_flurry_enabled and not _spin_active and fighter.custom_data.get("keyboard_spin_charged", false):
		fighter.custom_data["keyboard_spin_charged"] = false
		_start_spin_flurry(fighter)
		return
	# 스윙 판정이 아직 안 났으면, 지금 입력을 예약만 해둔다 (맞으면 다음 타, 헛발이면 버림)
	if _swinging:
		_queued = true
		return
	if not can_use():
		return
	# 이어치기 창이 지났으면 새 콤보이므로 1타부터
	if _chain_left <= 0.0:
		_step = 0
	_begin_swing(fighter, _step)

## 스킬 클래시에서 밀렸을 때 — 콤보를 끊고 기본공격 쿨만 소모
func cancel_use() -> void:
	_reset(effective_cooldown())

## 이 스킬이 타별 스윙을 직접 재생하므로 Fighter는 기본 스윙을 덧대지 않는다
func handles_own_visual() -> bool:
	return true

func _process(delta: float) -> void:
	super._process(delta)  # 쿨타임 감소
	# 키보드 회전 난무가 도는 중이면 히트박스를 몸 중심에 붙여 따라다니게 하고, 시간이 다 되면 끝낸다.
	# (도는 동안은 아래 일반 콤보 판정 로직을 건너뛴다)
	if _spin_active:
		if not is_instance_valid(_fighter):
			_end_spin_flurry()
			return
		hitbox.global_position = _fighter.global_position
		hitbox.knockback = Vector2(spin_flurry_knockback.x * _fighter.facing, spin_flurry_knockback.y)
		_spin_left = maxf(_spin_left - delta, 0.0)
		if _spin_left <= 0.0:
			_end_spin_flurry()
		return
	# 판정 창(active_duration)이 지날 때까지 안 맞았으면 헛발로 확정한다
	if _active_left > 0.0:
		# **판정이 켜져 있는 동안 캐릭터를 따라간다.** 드롭킥·파고들기처럼 때리는 중에 앞으로 나가면
		# 판정만 켜진 자리에 남아서, 발이 닿아도 판정은 뒤에서 허공을 쳤다
		if is_instance_valid(_fighter):
			hitbox.global_position = _fighter.global_position + Vector2(range * _fighter.facing, 0.0)
		_active_left = maxf(_active_left - delta, 0.0)
		if _active_left <= 0.0 and _swinging and not _resolved:
			_resolve(false)
	# 맞고 나서 다음 타를 안 눌러 창이 지나면 콤보만 조용히 리셋(맞췄으니 쿨 없음)
	if _chain_left > 0.0:
		_chain_left = maxf(_chain_left - delta, 0.0)
		if _chain_left <= 0.0 and _step > 0 and not _swinging:
			_reset(0.0)

## 한 타를 시작한다
func _begin_swing(fighter: Fighter, step: int) -> void:
	_swinging = true
	_resolved = false
	_queued = false
	_chain_left = 0.0
	_swing_step = step
	_fire(fighter, step)

## 스윙 판정을 마무리한다 — 맞으면 이어치기, 헛발이면 기본 쿨 + 1타 리셋
func _resolve(hit: bool) -> void:
	if _resolved:
		return
	_resolved = true
	_swinging = false
	_active_left = 0.0
	# 명중 시그널(area_entered) 콜백 안에서 호출될 수 있는데, 그때 monitoring을 바로 끄면
	# Godot이 물리 연산 중이라 막아버려 히트박스가 켜진 채 남는다(그 자리를 지나가면 계속 맞는 버그).
	# set_deferred로 물리 스텝이 끝난 뒤에 안전하게 끈다
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	if hit:
		if not _is_final(_swing_step):
			_step = _swing_step + 1
			cooldown_left = 0.0
			if _queued:
				_begin_swing(_fighter, _step)   # 예약된 입력이 있으면 즉시 다음 타
			else:
				_chain_left = chain_window       # 늦게 눌러도 이어지도록 창을 연다
		else:
			_reset(effective_cooldown())   # 3타까지 다 맞춤 → 마무리 회복 쿨
	else:
		# 헛발 → 헛발 전용 쿨(miss_cooldown, 없으면 기본 cooldown) + 1타 리셋 (예약 입력은 버림)
		_reset(_effective_miss_cooldown())

## 헛발질했을 때 실제로 돌 쿨타임.
## **쿨타임 덮어쓰기(악플러 열등감)가 걸려 있으면 헛쳐도 그 값으로 묶인다** — 안 그러면
## "쿨 0.3초 고정" 버프를 켜고도 한 번 헛치는 순간 1초를 쉬게 돼서 버프가 체감되지 않는다.
## 방 설정의 전역 쿨타임 배율도 effective_cooldown()과 똑같이 마지막에 곱한다
func _effective_miss_cooldown() -> float:
	var base: float = cooldown_override if cooldown_override > 0.0 else (miss_cooldown if miss_cooldown >= 0.0 else cooldown)
	return base * GameState.cooldown_multiplier

## 실제로 히트박스를 켜서 때린다 (windup만큼만 판정을 늦춘다)
func _fire(fighter: Fighter, step: int) -> void:
	var d: AttackData = _hit_data(step)
	var visual := fighter.get_node_or_null("Visual")
	if visual and visual.has_method("play_attack_swing"):
		if d != null:
			visual.play_attack_swing(d.anim_variant if d.anim_variant >= 0 else step, d.anim_duration, d.spin)
		else:
			visual.play_attack_swing(step)
	var is_final: bool = _is_final(step)
	# 마무리 타가 드롭킥이면 판정보다 먼저 뛰어오른다 — 뛰는 동안 두 발이 뻗고 그 뒤에 판정이 켜진다
	if dropkick_finisher and is_final:
		_start_dropkick(fighter)
	var wind: float = _windup_for(step, fighter)
	if not (dropkick_finisher and is_final):
		var lunge: float
		var follows: bool
		var lunge_time: float = wind
		var lead: float = 0.0
		if d != null:
			lunge = d.lunge_extra
			follows = d.lunge_follows_pushback
			if d.lunge_time > 0.0:
				lunge_time = d.lunge_time
			lead = d.lunge_foot_lead
		else:
			lunge = combo_lunge[step] if step < combo_lunge.size() else 0.0
			follows = lunge_follows_pushback
		# 직전 타에 밀린 만큼 따라붙는다 (1타는 직전 타가 없으니 칸 값만)
		if follows and step > 0:
			lunge += _last_pushback
		if lunge > 0.0:
			_start_lunge(fighter, lunge, lunge_time, lead)
	# 두 물리 프레임(약 0.034초)보다 짧으면 타이머 대신 프레임을 기다린다 — 아래 설명과 같은 이유
	if wind > 0.04:
		await get_tree().create_timer(wind).timeout
	else:
		# **예비동작이 0이어도 물리 프레임 두 번은 미룬다(2026-09-17).** 판정이 꺼진 채로 물리 계산이 한 번은
		# 돌아야 엔진이 "겹침이 풀렸다"고 기록하고, 다시 켰을 때 area_entered가 새로 나온다.
		# 앞 타가 맞은 순간 바로 다음 타 판정을 켜면 상대가 코앞에 그대로 겹쳐 있어도 "새로 닿았다"가 안 잡혀서
		# 캣맘·층간소음(windup 0)만 2타를 헛쳤다(헤드리스 실측). 한 번만 기다리면 끄는 예약이 아직 안 돌아 부족하다
		await get_tree().physics_frame
		await get_tree().physics_frame
	# 그 사이 스윙이 끝났거나(판정됨) 캐릭터가 사라졌으면 접는다
	# (드롭킥은 여기서 접어도 착지·일어나기는 after_physics가 끝까지 마무리한다)
	if not is_instance_valid(fighter) or not _swinging or _resolved:
		return
	# 마무리 타는 가로 넉백에 finisher_distance_scale을 곱해 더 멀리 날린다
	var push_scale: float = finisher_distance_scale if is_final else 1.0
	if d != null:
		hitbox.damage = fighter.compute_damage(d.damage)
		hitbox.knockback = Vector2(d.knockback.x * fighter.facing * push_scale, d.knockback.y)
		hitbox.pop_override = d.pop
		hitbox.hitstop_multiplier = d.hitstop_scale
		hitbox.shake_multiplier = d.shake_scale
	else:
		hitbox.damage = fighter.compute_damage(combo_damage[step])
		hitbox.knockback = Vector2(combo_knockback[step].x * fighter.facing * push_scale, combo_knockback[step].y)
		hitbox.pop_override = combo_pop[step]
		hitbox.hitstop_multiplier = 1.0
		hitbox.shake_multiplier = 1.0
	hitbox.debris_enabled = (not debris_final_hit_only) or is_final
	hitbox.source_fighter = fighter
	hitbox.global_position = fighter.global_position + Vector2(range * fighter.facing, 0.0)
	# 이미 겹쳐 있는 상대도 이번 타에 다시 맞도록 잠깐 껐다 켜서 area_entered가 새로 발생하게 한다
	hitbox.monitoring = false
	hitbox.monitorable = false
	hitbox.clear_repeat_state()
	hitbox.monitoring = true
	hitbox.monitorable = true
	_active_left = d.active_time if d != null else active_duration

func _reset(cd: float) -> void:
	_step = 0
	_last_pushback = 0.0
	_queued = false
	_chain_left = 0.0
	cooldown_left = cd

## --- 키보드 회전 난무 (악플러 그랩 후 강화 평타) ---
## 두 손으로 무기를 빙빙 돌리며 몸 주변을 spin_flurry_duration초 동안 다단히트한다.
## 히트박스(BasicAttack/Hitbox)를 잠깐 큰 원형 + repeat_interval로 바꿔 재활용하고, 끝나면 원래대로 되돌린다
func _start_spin_flurry(fighter: Fighter) -> void:
	_spin_active = true
	_spin_left = spin_flurry_duration
	# 진행 중이던 콤보 상태를 깨끗이 정리한다
	_swinging = false
	_resolved = true
	_queued = false
	_active_left = 0.0
	_chain_left = 0.0
	_step = 0
	# 다른 공격·스킬은 막고 이동은 계속 가능하게(start_busy 규칙) — 도는 동안 좌우로 움직일 수 있다
	fighter.start_busy(spin_flurry_duration)
	# 히트박스를 몸 주변 원형 다단히트로 바꾼다(끝나면 _end_spin_flurry가 원래 모양으로 복구)
	var shape_node := hitbox.get_node_or_null("HitboxCollision") as CollisionShape2D
	if shape_node:
		_spin_saved_shape = shape_node.shape
		var circle := CircleShape2D.new()
		circle.radius = spin_flurry_radius
		shape_node.shape = circle
	hitbox.damage = fighter.compute_damage(spin_flurry_damage)
	hitbox.knockback = Vector2(spin_flurry_knockback.x * fighter.facing, spin_flurry_knockback.y)
	hitbox.pop_override = 0.0            # 원형 난무는 위로 안 띄운다(뜨면 판정 밖으로 빠진다)
	hitbox.source_fighter = fighter
	hitbox.repeat_interval = spin_flurry_interval
	hitbox.debris_enabled = false
	hitbox.global_position = fighter.global_position
	hitbox.clear_repeat_state()
	hitbox.monitoring = true
	hitbox.monitorable = true
	# 시각 — 두 손으로 키보드를 선풍기처럼 돌린다(리그에 기능이 없으면 그냥 넘어간다)
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("play_keyboard_fan"):
		visual.play_keyboard_fan(spin_flurry_duration)

## 회전 난무를 끝내고 히트박스를 원래 상태(사각형 · 단발)로 되돌린다
func _end_spin_flurry() -> void:
	_spin_active = false
	_spin_left = 0.0
	# 명중 콜백 안에서 불릴 수 있으므로 monitoring은 물리 스텝 뒤에 안전하게 끈다(_resolve와 같은 이유)
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	hitbox.repeat_interval = 0.0
	hitbox.clear_repeat_state()
	hitbox.debris_enabled = true
	hitbox.pop_override = -1.0
	if _spin_saved_shape != null:
		var shape_node := hitbox.get_node_or_null("HitboxCollision") as CollisionShape2D
		if shape_node:
			shape_node.shape = _spin_saved_shape
		_spin_saved_shape = null
	_reset(effective_cooldown())
	var visual: Node = _fighter.get_node_or_null("Visual") if is_instance_valid(_fighter) else null
	if visual and visual.has_method("end_keyboard_fan"):
		visual.end_keyboard_fan()

## --- 파고들기 (combo_lunge) ---
## 예비동작 동안 distance만큼 앞으로 미끄러진다. 이동 권한을 잠깐 가져가므로 그동안 걷기·대시는 안 먹는다
func _start_lunge(fighter: Fighter, distance: float, duration: float, lead: float = 0.0) -> void:
	# 다른 스킬(자전거 돌진 등)이 이동을 쥐고 있으면 끼어들지 않는다
	if fighter.movement_override != null and fighter.movement_override != self:
		return
	# 앞 타의 파고들기가 아직 덜 끝났으면(연타로 다음 타가 바로 이어진 경우) 남은 거리를 이번 걸음에 얹는다 —
	# 안 얹으면 앞 걸음이 중간에 잘려 덜 나가고, 몸이 뚝 멈췄다 다시 출발한다
	if _lunge_left > 0.0 and fighter.movement_override == self:
		distance += _lunge_remaining_distance()
		lead *= 0.5   # 이미 발이 나가 있는 중이라 "발만 먼저" 구간을 짧게 해서 덜 멈칫하게
	var time: float = maxf(duration, LUNGE_MIN_TIME)
	_lunge_left = time
	_lunge_time = time
	_lunge_lead = clampf(lead, 0.0, 0.6)
	# (lead 0) 시작 속도를 평균의 두 배로 잡고 끝에서 0이 되게 줄이면 이동 거리가 정확히 distance가 된다(삼각형 넓이).
	# (lead > 0) 평균 속도만 기억해 두고, 곡선 모양은 get_move_velocity_x가 매 프레임 계산한다
	_lunge_speed = (2.0 * distance / time) if _lunge_lead <= 0.0 else (distance / time)
	_lunge_dir = signf(fighter.facing)
	if is_zero_approx(_lunge_dir):
		_lunge_dir = 1.0
	fighter.movement_override = self
	# 발이 앞으로 내딛는 모양도 같이 (리그에 기능이 없으면 그냥 미끄러지기만 한다)
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("play_lunge_step"):
		visual.play_lunge_step(time, _lunge_lead)

## 지금 파고들기에서 아직 못 간 거리(px) — get_move_velocity_x의 곡선을 적분한 위치로 계산한다
func _lunge_remaining_distance() -> float:
	var remain: float = _lunge_left / maxf(_lunge_time, 0.001)
	if _lunge_lead <= 0.0:
		return _lunge_speed * _lunge_time * 0.5 * remain * remain
	var s: float = clampf((1.0 - remain - _lunge_lead) / (1.0 - _lunge_lead), 0.0, 1.0)
	return _lunge_speed * _lunge_time * (1.0 - s * s * (3.0 - 2.0 * s))

func _end_lunge(fighter: Fighter) -> void:
	_lunge_left = 0.0
	if is_instance_valid(fighter) and fighter.movement_override == self and not _dk_active:
		fighter.movement_override = null

## --- 드롭킥 마무리 ---
## 뛰어올라 앞으로 나가기 시작한다. 착지 판정·일어나기는 after_physics가 이어서 맡는다
func _start_dropkick(fighter: Fighter) -> void:
	_lunge_left = 0.0
	_dk_active = true
	_dk_air = true
	_dk_grace = DROPKICK_GROUND_GRACE
	_dk_airtime = 0.0
	_dk_getup_left = 0.0
	_dk_dir = signf(fighter.facing)
	if is_zero_approx(_dk_dir):
		_dk_dir = 1.0
	fighter.velocity.y = -dropkick_lift
	# 이동은 이 스킬이 가져가고(걷기·대시·방어가 다 막힌다), 공격·스킬은 start_busy로 막는다.
	# 끝나는 시점이 "언제 땅에 닿느냐"에 달려 있어 넉넉히 걸어두고 끝날 때 end_busy()로 바로 푼다
	fighter.movement_override = self
	fighter.start_busy(DROPKICK_MAX_AIR + dropkick_getup)
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("play_dropkick"):
		visual.play_dropkick()

## Fighter.apply_physics가 이동 속도를 물어볼 때 — 공중에선 앞으로 나가고, 넘어진 뒤엔 제자리다
func get_move_velocity_x() -> float:
	if _dk_active and _dk_air:
		return _dk_dir * dropkick_speed
	if _lunge_left > 0.0:
		var remain: float = _lunge_left / maxf(_lunge_time, 0.001)
		if _lunge_lead <= 0.0:
			return _lunge_dir * _lunge_speed * remain
		# 발 먼저, 몸이 따라감: 앞쪽 lead 동안은 멈춰 있다가, 남은 구간을 smoothstep 곡선(천천히-빠르게-천천히)으로 간다.
		# smoothstep의 기울기 6s(1-s)를 구간 길이로 나누면 전체 면적이 1이라 이동 거리가 distance로 맞는다
		var s: float = clampf((1.0 - remain - _lunge_lead) / (1.0 - _lunge_lead), 0.0, 1.0)
		return _lunge_dir * _lunge_speed * 6.0 * s * (1.0 - s) / (1.0 - _lunge_lead)
	return 0.0

## move_and_slide 직후 매 프레임 호출된다 (movement_override로 등록돼 있는 동안만)
func after_physics(fighter: Fighter, delta: float) -> void:
	if not _dk_active:
		if _lunge_left > 0.0:
			# 파고드는 도중에 맞으면 끊는다 — 안 끊으면 넉백을 이 속도가 덮어써서 맞고도 앞으로 미끄러진다
			if fighter.is_in_hitstun():
				_end_lunge(fighter)
				return
			fighter.facing = _lunge_dir
			_lunge_left = maxf(_lunge_left - delta, 0.0)
			if _lunge_left <= 0.0:
				_end_lunge(fighter)
		elif fighter.movement_override == self:
			fighter.movement_override = null
		return
	# 도중에 맞으면 드롭킥이 끊긴다 — 안 끊으면 넉백으로 밀려나야 할 속도를 이 스킬이 매 프레임 덮어써서
	# 맞고도 제자리에서 계속 날아가는 꼴이 된다
	if fighter.is_in_hitstun():
		_end_dropkick(fighter)
		return
	# 뛰는 동안 방향키를 눌러도 몸이 홱 돌지 않게 매 프레임 되돌린다 —
	# Fighter.move()는 이동을 못 하는 상태에서도 facing은 바꾸기 때문이다 (대시와 같은 함정)
	fighter.facing = _dk_dir
	if _dk_air:
		_dk_grace = maxf(_dk_grace - delta, 0.0)
		_dk_airtime += delta
		if (_dk_grace <= 0.0 and fighter.is_on_floor()) or _dk_airtime >= DROPKICK_MAX_AIR:
			_land_dropkick(fighter)
		return
	_dk_getup_left = maxf(_dk_getup_left - delta, 0.0)
	if _dk_getup_left <= 0.0:
		_end_dropkick(fighter)

## 땅에 닿았다 — 넘어진 자세로 바꾸고 dropkick_getup 동안 아무것도 못 하게 둔다
func _land_dropkick(fighter: Fighter) -> void:
	_dk_air = false
	_dk_getup_left = dropkick_getup
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("dropkick_land"):
		visual.dropkick_land(dropkick_getup)

## 드롭킥을 끝내고 이동 권한·행동 잠금·자세를 되돌린다
func _end_dropkick(fighter: Fighter) -> void:
	_dk_active = false
	_dk_air = false
	_dk_getup_left = 0.0
	if not is_instance_valid(fighter):
		return
	if fighter.movement_override == self:
		fighter.movement_override = null
	fighter.end_busy()
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("dropkick_end"):
		visual.dropkick_end()
