class_name ComboMeleeAttack
extends MeleeAttack

## 히트 확인식 3타 기본 콤보.
## 규칙(단순): 기본공격이 "맞으면" 쿨타임 없이 곧바로 다음 타가 나간다(최대 3타). 헛치면 짧은 쿨타임이 붙는다.
##
## 손맛의 핵심은 두 가지:
##  1) 잠금(lock)을 쓰지 않는다 — 스윙 중에도 다음 입력이 막히지 않는다.
##  2) 입력 버퍼링 — 스윙이 끝나기 전에 눌러도 그 입력을 기억해뒀다가, 그 타가 명중하면 즉시 다음 타를 낸다.
##     (연타로 1→2→3타가 자연스럽게 이어지게 하는 부분)
##
## 부모 MeleeAttack의 range/active_duration/windup/hitbox는 그대로 쓰고, damage/knockback/팝업만
## 타별 배열로 덮어쓴다.

## 타별 데미지 (총 3타). 앞 두 타는 약하게, 마무리를 세게
@export var combo_damage: Array[int] = [3, 4, 7]
## 타별 넉백. 1·2타는 상대를 붙잡아두려고 살짝만, 마무리(3타)는 크게 날린다
@export var combo_knockback: Array[Vector2] = [
	Vector2(130, 0),
	Vector2(150, 0),
	Vector2(400, -180),
]
## 타별로 상대를 위로 띄우는 힘(px/s). 0이면 지상 유지, 음수면 기본 팝업.
## 앞 두 타는 안 띄워야(0) 상대가 콤보 사거리 안에 머문다
@export var combo_pop: Array[float] = [0.0, 0.0, -1.0]
## 한 타가 명중한 뒤, 다음 타를 눌러 이어갈 수 있는 여유 시간(초).
## 이 안에 다시 누르면 쿨 없이 다음 타가 나가고, 안 누르면 콤보가 조용히 끝난다(맞췄으니 쿨타임 없음).
## 사람이 또박또박 누르는 속도(0.5~0.8초)에도 이어지도록 넉넉히 1초를 준다
@export var chain_grace: float = 1.0
## 마지막 3타까지 다 낸 뒤의 짧은 회복 쿨타임(초)
@export var finish_cooldown: float = 0.3
## 헛쳤을 때 붙는 짧은 쿨타임(초) — 잽 난사만 막을 정도로 가볍게
@export var whiff_cooldown: float = 0.35

## 다음에 나갈 타 (0=1타, 1=2타, 2=3타)
var _step: int = 0
## 지금 스윙이 진행 중인지 (windup~active 동안 true). 이 동안 들어온 입력은 버퍼된다
var _swinging: bool = false
## 스윙 중에 다음 타 입력이 들어왔는지 (명중하면 즉시 다음 타로 소모)
var _buffered: bool = false
## 명중 후 다음 입력을 기다리는 여유 시간
var _window_left: float = 0.0
var _fighter: Fighter = null

## 스윙 중이거나(버퍼용) 이어가기 여유가 있거나 쿨이 없으면 입력을 받아준다.
## Fighter.use_basic_attack이 이 값으로 입력을 스킬까지 전달할지 정하므로, 스윙 중에도 true여야 버퍼링이 된다
func can_use() -> bool:
	return _swinging or _window_left > 0.0 or cooldown_left <= 0.0

func use(fighter: Fighter) -> void:
	_fighter = fighter
	# 스윙이 진행 중이면 지금 입력을 기억해뒀다가, 그 타가 맞으면 곧바로 다음 타를 낸다
	if _swinging:
		_buffered = true
		return
	if not can_use():
		return
	# 이어가기 여유가 없었다면(=새 콤보) 1타부터
	if _window_left <= 0.0:
		_step = 0
	_window_left = 0.0
	_start_swing(fighter)

## 스킬 클래시에서 밀렸을 때 — 콤보를 끊고 짧은 쿨만 소모
func cancel_use() -> void:
	_reset(whiff_cooldown)

## 이 스킬이 타별 스윙을 직접 재생하므로 Fighter는 기본 스윙을 덧대지 않는다
func handles_own_visual() -> bool:
	return true

func _process(delta: float) -> void:
	super._process(delta)  # 쿨타임 감소
	if _window_left > 0.0 and not _swinging:
		_window_left = maxf(_window_left - delta, 0.0)
		if _window_left <= 0.0:
			# 이어가기 여유를 놓쳤다 — 맞췄으니 쿨 없이 조용히 콤보만 리셋
			_reset(0.0)

## 현재 _step의 타를 실제로 휘두른다
func _start_swing(fighter: Fighter) -> void:
	_swinging = true
	_buffered = false
	_window_left = 0.0
	_do_combo_hit(fighter, _step)

## 한 타를 휘두르고, 명중 여부에 따라 다음 타로 이을지 결정한다
func _do_combo_hit(fighter: Fighter, step: int) -> void:
	var dmg: int = combo_damage[step]
	var kb: Vector2 = combo_knockback[step]
	# 타별 스윙 모션 (0=내려찍기, 1=후려치기, 2=올려치기)
	var visual := fighter.get_node_or_null("Visual")
	if visual and visual.has_method("play_attack_swing"):
		visual.play_attack_swing(step)
	if windup > 0.0:
		await get_tree().create_timer(windup).timeout
		if not is_instance_valid(fighter):
			_swinging = false
			return
	hitbox.damage = fighter.compute_damage(dmg)
	hitbox.knockback = Vector2(kb.x * fighter.facing, kb.y)
	hitbox.pop_override = combo_pop[step]
	hitbox.source_fighter = fighter
	hitbox.global_position = fighter.global_position + Vector2(range * fighter.facing, 0.0)
	var landed := [false]
	var on_hit := func(_victim): landed[0] = true
	hitbox.connected.connect(on_hit)
	hitbox.monitoring = true
	hitbox.monitorable = true
	await get_tree().create_timer(active_duration).timeout
	hitbox.monitoring = false
	hitbox.monitorable = false
	if hitbox.connected.is_connected(on_hit):
		hitbox.connected.disconnect(on_hit)
	_swinging = false
	_resolve_swing(landed[0], step)

## 스윙이 끝난 뒤: 맞았으면 다음 타로(버퍼돼 있으면 즉시, 아니면 잠깐 기다림), 헛쳤으면 짧은 쿨과 함께 리셋
func _resolve_swing(landed: bool, step: int) -> void:
	if landed:
		if step < combo_damage.size() - 1:
			_step = step + 1
			cooldown_left = 0.0
			if _buffered:
				# 스윙 중에 미리 눌러둔 입력이 있으면 곧바로 다음 타
				_start_swing(_fighter)
			else:
				# 살짝 늦게 눌러도 이어지도록 잠깐 창을 연다
				_window_left = chain_grace
			return
		# 3타까지 다 맞춤 → 짧은 회복 후 리셋
		_reset(finish_cooldown)
	else:
		# 헛침 → 짧은 쿨타임
		_reset(whiff_cooldown)

func _reset(cd: float) -> void:
	_step = 0
	_buffered = false
	_window_left = 0.0
	cooldown_left = cd
