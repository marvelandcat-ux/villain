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

## 타별 데미지 (총 3타)
@export var combo_damage: Array[int] = [3, 4, 7]
## 타별 넉백 (x는 앞 방향 자동반전, y는 띄우기)
@export var combo_knockback: Array[Vector2] = [
	Vector2(220, -90),
	Vector2(220, -90),
	Vector2(220, -90),
]
## 타별로 상대를 위로 띄우는 힘(px/s). 0=지상 유지, 음수=기본 팝업(위로 붕 뜬다)
@export var combo_pop: Array[float] = [-1.0, -1.0, -1.0]
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

## 타입을 안 붙이고 preload로 가져온다 — 새로 만든 class_name은 전역 클래스 캐시가 갱신되기 전엔
## 못 찾아서 파싱 에러가 난다 (Fighter._shield, ShoulderChargeSkill의 ChargeWind와 같은 이유)
const LAUNCH_SMOKE := preload("res://combat/LaunchSmoke.gd")

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
## 마무리 타만 쓰는 예비동작(초). -1이면 windup을 그대로 쓴다.
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

func _ready() -> void:
	super()   # start_on_cooldown 처리 (기본공격은 꺼져 있지만 규칙을 깨지 않는다)
	# 명중하는 순간(스윙 진행 중이면) 곧바로 "맞음"으로 판정한다
	hitbox.connected.connect(_on_hitbox_connected)

func _on_hitbox_connected(victim: Node) -> void:
	_count_hit_for_break()
	if _swinging and not _resolved:
		# **_resolve보다 먼저 부른다** — _resolve는 예약 입력이 있으면 그 자리에서 다음 타를 시작하면서
		# _swing_step을 바꿔버려, 뒤에 부르면 "몇 번째 타였는지"를 잘못 보게 된다
		_launch_finisher(victim)
		_resolve(true)

## 마무리 타에 맞은 상대를 멀리 날려보낸다. 데미지·넉백은 히트박스가 이미 줬고 여기서는
## **날아가는 동안의 경직·구르기·연기만** 얹는다. 가드로 막혔으면 아무것도 안 한다
func _launch_finisher(victim: Node) -> void:
	if _swing_step < combo_damage.size() - 1:
		return
	if launch_stun <= 0.0 and launch_spin_turns <= 0.0 and not launch_smoke:
		return
	if not (victim is Fighter) or not is_instance_valid(victim):
		return
	var target: Fighter = victim
	# 막은 쪽은 넉백도 데미지도 안 받았으므로 날아가지도 않는다 (막았는데 구르면 어긋나 보인다)
	if target.is_guarding:
		return
	var dir: float = 1.0
	if is_instance_valid(_fighter) and not is_zero_approx(_fighter.facing):
		dir = signf(_fighter.facing)
	if launch_stun > 0.0:
		target.apply_hitstun(launch_stun)
	if launch_spin_turns > 0.0 and target.has_method("play_launch_tumble"):
		# 도는 시간은 못 움직이는 시간과 맞춘다 — 경직이 없으면 짧게 한 번 굴리고 만다
		target.play_launch_tumble(launch_spin_turns, launch_stun if launch_stun > 0.0 else 0.6, dir)
	if launch_smoke:
		_spawn_launch_smoke(target, dir)

## 날아가는 사람을 따라다니며 연기를 흘리는 노드를 **맵에** 붙인다 (맞은 사람의 자식으로 달면
## 그 사람이 좌우로 뒤집힐 때 연기까지 뒤집힌다)
func _spawn_launch_smoke(target: Fighter, _dir: float) -> void:
	var parent: Node = target.get_parent()
	if parent == null:
		return
	var smoke = LAUNCH_SMOKE.new()
	parent.add_child(smoke)
	smoke.setup(target, maxf(launch_stun, 0.45))

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

## 스윙 중(예약용)이거나 이어치기 여유가 있거나 쿨이 없으면 입력을 받아준다
func can_use() -> bool:
	return _swinging or _chain_left > 0.0 or cooldown_left <= 0.0

func use(fighter: Fighter) -> void:
	_fighter = fighter
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
	# 판정 창(active_duration)이 지날 때까지 안 맞았으면 헛발로 확정한다
	if _active_left > 0.0:
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
		if _swing_step < combo_damage.size() - 1:
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
	var visual := fighter.get_node_or_null("Visual")
	if visual and visual.has_method("play_attack_swing"):
		visual.play_attack_swing(step)
	var is_final: bool = step == combo_damage.size() - 1
	# 마무리 타가 드롭킥이면 판정보다 먼저 뛰어오른다 — 뛰는 동안 두 발이 뻗고 그 뒤에 판정이 켜진다
	if dropkick_finisher and is_final:
		_start_dropkick(fighter)
	var wind: float = windup
	if dropkick_finisher and is_final and finisher_windup >= 0.0:
		wind = finisher_windup
	if wind > 0.0:
		await get_tree().create_timer(wind).timeout
		# 그 사이 스윙이 끝났거나(판정됨) 캐릭터가 사라졌으면 접는다
		# (드롭킥은 여기서 접어도 착지·일어나기는 after_physics가 끝까지 마무리한다)
		if not is_instance_valid(fighter) or not _swinging or _resolved:
			return
	hitbox.damage = fighter.compute_damage(combo_damage[step])
	hitbox.knockback = Vector2(combo_knockback[step].x * fighter.facing, combo_knockback[step].y)
	hitbox.pop_override = combo_pop[step]
	hitbox.debris_enabled = (not debris_final_hit_only) or step == combo_damage.size() - 1
	hitbox.source_fighter = fighter
	hitbox.global_position = fighter.global_position + Vector2(range * fighter.facing, 0.0)
	# 이미 겹쳐 있는 상대도 이번 타에 다시 맞도록 잠깐 껐다 켜서 area_entered가 새로 발생하게 한다
	hitbox.monitoring = false
	hitbox.monitorable = false
	hitbox.clear_repeat_state()
	hitbox.monitoring = true
	hitbox.monitorable = true
	_active_left = active_duration

func _reset(cd: float) -> void:
	_step = 0
	_queued = false
	_chain_left = 0.0
	cooldown_left = cd

## --- 드롭킥 마무리 ---
## 뛰어올라 앞으로 나가기 시작한다. 착지 판정·일어나기는 after_physics가 이어서 맡는다
func _start_dropkick(fighter: Fighter) -> void:
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
	return 0.0

## move_and_slide 직후 매 프레임 호출된다 (movement_override로 등록돼 있는 동안만)
func after_physics(fighter: Fighter, delta: float) -> void:
	if not _dk_active:
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
