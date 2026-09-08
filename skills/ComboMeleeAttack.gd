class_name ComboMeleeAttack
extends MeleeAttack

## 딜레이 없는 3타 기본 콤보 (입력 기반).
## 누르면 곧바로 평타가 나가고, 짧은 이어치기 창(chain_window) 안에 다시 누르면 쿨타임 없이 2타→3타로 이어진다.
## 맞았는지와 무관하게 이어진다 — 허공을 쳐도(훈련장) 3타까지 나간다.
## 3타를 다 쓰거나, 창이 지나 콤보가 끊기면 그때만 회복 쿨타임(cooldown)이 붙는다.
## 훈련장은 모든 스킬 cooldown을 0으로 만들므로(_disable_cooldowns) 거기선 딜레이가 완전히 사라진다.
##
## 타마다 데미지·넉백·팝업·스윙 모션이 다르다 (1·2타는 붙잡아두고, 3타는 크게 날린다).

## 타별 데미지 (총 3타)
@export var combo_damage: Array[int] = [3, 4, 7]
## 타별 넉백. 1·2타는 살짝만, 마무리(3타)는 크게
@export var combo_knockback: Array[Vector2] = [
	Vector2(220, -90),
	Vector2(220, -90),
	Vector2(220, -90),
]
## 타별로 상대를 위로 띄우는 힘(px/s). 0=지상 유지, 음수=기본 팝업(데미지 비례로 위로 붕 뜬다).
## 전부 -1로 두면 원래 평타처럼 매 타 상대가 튕겨 날아간다
@export var combo_pop: Array[float] = [-1.0, -1.0, -1.0]
## 한 타를 낸 뒤 다음 타를 눌러 이어갈 수 있는 시간(초). 이 안에 다시 누르면 쿨 없이 다음 타.
## 넉넉히 줘서 또박또박 눌러도(0.5~0.9초) 이어지게 한다
@export var chain_window: float = 1.0

## 지금 낼 타 (0=1타, 1=2타, 2=3타)
var _step: int = 0
## 다음 타를 이어칠 수 있는 남은 시간
var _chain_left: float = 0.0
## 켜둔 히트박스를 끄기까지 남은 시간 (await 없이 타이머로 처리해 연타 시 겹침을 피한다)
var _active_left: float = 0.0
## 스윙마다 증가하는 번호 — windup 대기 중 다음 타가 나가면 옛 스윙을 접는 데 쓴다
var _swing_id: int = 0

## 회복 쿨타임만 아니면 언제든 누를 수 있다 (이어치기 자체엔 쿨이 없다)
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
	# 곧바로 다음 타 준비 — 마지막(3타)을 냈으면 콤보를 리셋하고 그때만 회복 쿨을 준다
	if step >= combo_damage.size() - 1:
		_step = 0
		_chain_left = 0.0
		cooldown_left = cooldown   # 훈련장에선 cooldown=0이라 딜레이 없음
	else:
		_step = step + 1
		_chain_left = chain_window

## 스킬 클래시에서 밀렸을 때 — 콤보를 끊고 회복 쿨만 소모
func cancel_use() -> void:
	_reset()

## 이 스킬이 타별 스윙을 직접 재생하므로 Fighter는 기본 스윙을 덧대지 않는다
func handles_own_visual() -> bool:
	return true

func _process(delta: float) -> void:
	super._process(delta)  # 회복 쿨타임 감소
	# 켜둔 히트박스를 active_duration 뒤에 끈다
	if _active_left > 0.0:
		_active_left = maxf(_active_left - delta, 0.0)
		if _active_left <= 0.0:
			hitbox.monitoring = false
			hitbox.monitorable = false
	# 이어치기 창이 지나 콤보가 끊기면 리셋(+회복 쿨). 마지막 타에서 이미 _step=0이면 안 걸린다
	if _chain_left > 0.0:
		_chain_left = maxf(_chain_left - delta, 0.0)
		if _chain_left <= 0.0 and _step > 0:
			_reset()

## 한 타를 즉시 휘두른다 (windup만큼만 판정을 늦춘다 — 입력→다음 입력 사이엔 딜레이 없음)
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
	# 이미 겹쳐 있는 상대도 이번 타에 다시 맞도록 잠깐 껐다 켜서 area_entered가 새로 발생하게 한다
	hitbox.monitoring = false
	hitbox.monitorable = false
	hitbox.clear_repeat_state()
	hitbox.monitoring = true
	hitbox.monitorable = true
	_active_left = active_duration

func _reset() -> void:
	_step = 0
	_chain_left = 0.0
	cooldown_left = cooldown
