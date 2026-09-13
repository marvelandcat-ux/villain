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

func _ready() -> void:
	super()   # start_on_cooldown 처리 (기본공격은 꺼져 있지만 규칙을 깨지 않는다)
	# 명중하는 순간(스윙 진행 중이면) 곧바로 "맞음"으로 판정한다
	hitbox.connected.connect(_on_hitbox_connected)

func _on_hitbox_connected(_victim: Node) -> void:
	_count_hit_for_break()
	if _swinging and not _resolved:
		_resolve(true)

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
## "쿨 0.3초 고정" 버프를 켜고도 한 번 헛치는 순간 1초를 쉬게 돼서 버프가 체감되지 않는다
func _effective_miss_cooldown() -> float:
	if cooldown_override > 0.0:
		return cooldown_override
	return miss_cooldown if miss_cooldown >= 0.0 else cooldown

## 실제로 히트박스를 켜서 때린다 (windup만큼만 판정을 늦춘다)
func _fire(fighter: Fighter, step: int) -> void:
	var visual := fighter.get_node_or_null("Visual")
	if visual and visual.has_method("play_attack_swing"):
		visual.play_attack_swing(step)
	if windup > 0.0:
		await get_tree().create_timer(windup).timeout
		# 그 사이 스윙이 끝났거나(판정됨) 캐릭터가 사라졌으면 접는다
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
