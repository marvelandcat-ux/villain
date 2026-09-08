class_name ComboMeleeAttack
extends MeleeAttack

## 3타 기본 콤보.
## - 누르면 곧바로 평타가 나간다(입력→다음 입력 사이 딜레이 없음).
## - 그 타가 "맞으면" 쿨타임 없이 이어치기 창(chain_window) 안에 다음 타로 이어진다(최대 3타).
## - 어느 타에서든 "헛발질(빗맞음)" 하면 그 스윙이 끝나는 순간 기본공격 쿨타임(cooldown)이 붙고
##   콤보가 1타로 리셋된다 (2타에서 못 맞히면 다시 1타부터). → 3타를 다 맞추려면 컨트롤이 필요하다.
## - 3타까지 다 맞추면 마무리 회복 쿨(cooldown)이 붙는다.
##
## 명중 여부는 Hitbox.connected 신호로 감지한다. 훈련장은 cooldown이 0으로 꺼져 있어 허공 연습은 쿨 없이 자유롭다.
##
## 타마다 데미지·넉백·팝업·스윙 모션이 다르다.

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

## 지금 낼 타 (0=1타, 1=2타, 2=3타)
var _step: int = 0
## 다음 타를 이어칠 수 있는 남은 시간
var _chain_left: float = 0.0
## 켜둔 히트박스를 끄기까지 남은 시간
var _active_left: float = 0.0
## 이번 스윙이 실제로 뭔가를 맞혔는지 (Hitbox.connected로 켜진다)
var _hit_registered: bool = false
## 스윙마다 증가하는 번호 — windup 대기 중 다음 타가 나가면 옛 스윙을 접는 데 쓴다
var _swing_id: int = 0

func _ready() -> void:
	# 명중 신호를 받아 이번 스윙이 맞았는지 기록한다
	hitbox.connected.connect(_on_hitbox_connected)

func _on_hitbox_connected(_victim: Node) -> void:
	_hit_registered = true

## 회복/헛발 쿨타임만 아니면 언제든 누를 수 있다
func can_use() -> bool:
	return cooldown_left <= 0.0

func use(fighter: Fighter) -> void:
	if not can_use():
		return
	# 이어치기 창이 지났으면 새 콤보이므로 1타부터
	if _chain_left <= 0.0:
		_step = 0
	var step: int = _step
	_fire(fighter, step)
	# 다음 타 준비 (실제 진행 여부는 이 스윙이 맞았는지에 따라 스윙 종료 시점에 최종 결정된다)
	if step >= combo_damage.size() - 1:
		# 마지막 타를 냈다 — 맞으면 마무리 회복 쿨, 헛발이면 헛발 쿨(스윙 종료 시 판정)
		_step = 0
		_chain_left = 0.0
	else:
		_step = step + 1
		_chain_left = chain_window

## 스킬 클래시에서 밀렸을 때 — 콤보를 끊고 기본공격 쿨만 소모
func cancel_use() -> void:
	_reset(cooldown)

## 이 스킬이 타별 스윙을 직접 재생하므로 Fighter는 기본 스윙을 덧대지 않는다
func handles_own_visual() -> bool:
	return true

func _process(delta: float) -> void:
	super._process(delta)  # 쿨타임 감소
	# 켜둔 히트박스를 active_duration 뒤에 끄고, 그 순간 이번 스윙의 명중/헛발을 판정한다
	if _active_left > 0.0:
		_active_left = maxf(_active_left - delta, 0.0)
		if _active_left <= 0.0:
			hitbox.monitoring = false
			hitbox.monitorable = false
			_resolve_swing()
	# 맞고 나서 다음 타를 안 눌러 창이 지나면 콤보만 조용히 리셋(맞췄으니 쿨 없음)
	if _chain_left > 0.0:
		_chain_left = maxf(_chain_left - delta, 0.0)
		if _chain_left <= 0.0 and _step > 0:
			_reset(0.0)

## 스윙이 끝난 순간: 헛발이면 기본공격 쿨 + 1타로 리셋, 마지막 타를 맞혔으면 마무리 회복 쿨
func _resolve_swing() -> void:
	if not _hit_registered:
		# 헛발질 — 기본공격 쿨타임이 붙고 콤보가 1타로 리셋된다 (다음 타를 이으려면 맞혀야 한다)
		_reset(cooldown)
	elif _step == 0 and _chain_left <= 0.0:
		# 방금 맞힌 게 마지막(3타)이었다 (use에서 _step을 0으로 되돌려둠) — 마무리 회복 쿨
		cooldown_left = cooldown

## 한 타를 즉시 휘두른다 (windup만큼만 판정을 늦춘다)
func _fire(fighter: Fighter, step: int) -> void:
	var visual := fighter.get_node_or_null("Visual")
	if visual and visual.has_method("play_attack_swing"):
		visual.play_attack_swing(step)
	_swing_id += 1
	var my_id: int = _swing_id
	if windup > 0.0:
		await get_tree().create_timer(windup).timeout
		if not is_instance_valid(fighter) or my_id != _swing_id:
			return  # 그 사이 다음 타가 나갔으면 이 스윙은 접는다
	hitbox.damage = fighter.compute_damage(combo_damage[step])
	hitbox.knockback = Vector2(combo_knockback[step].x * fighter.facing, combo_knockback[step].y)
	hitbox.pop_override = combo_pop[step]
	hitbox.source_fighter = fighter
	hitbox.global_position = fighter.global_position + Vector2(range * fighter.facing, 0.0)
	# 이번 스윙의 명중 판정을 새로 시작한다
	_hit_registered = false
	# 이미 겹쳐 있는 상대도 이번 타에 다시 맞도록 잠깐 껐다 켜서 area_entered가 새로 발생하게 한다
	hitbox.monitoring = false
	hitbox.monitorable = false
	hitbox.clear_repeat_state()
	hitbox.monitoring = true
	hitbox.monitorable = true
	_active_left = active_duration

func _reset(cd: float) -> void:
	_step = 0
	_chain_left = 0.0
	cooldown_left = cd
