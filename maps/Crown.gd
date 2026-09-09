class_name Crown
extends Area2D

## 놀이터의 핵심 기믹 — **왕관 훔쳐서 달아나기**.
##
## 흐름: 꼭대기에 놓인 왕관을 주우면 "놀이터의 왕"이 되어 버프를 받는다.
## 왕이 한 대라도 맞으면 **왕관이 머리에서 튕겨 나가 바닥에 떨어지고**, 잠깐 뒤부터 다시 아무나 주울 수 있다.
## 그래서 왕은 들고 도망치고, 상대는 쫓아가서 때려 떨어뜨린 뒤 먼저 주워야 한다.
##
## **승리 조건은 건드리지 않는다.** 왕관을 오래 들고 있어도 라운드가 끝나지 않는다 —
## 승패는 `maps/Stage.gd`가 여전히 HP와 링아웃으로만 판정한다.
## 왕관은 어디까지나 강한 버프라서, 이 맵만 다른 게임이 되지 않고 격투 골격이 그대로 유지된다.
##
## 왕이 받는 것:
##  - 이동속도 x `king_speed_multiplier` (도망칠 수 있게)
##  - 공격력 x `king_damage_multiplier`
##  - 모래사장에서 안 느려진다 (`maps/SandPit.gd`가 `is_king()`을 확인한다)
##
## 왕 표시는 `Fighter.custom_data`에 남긴다 — 맵이 캐릭터를 건드리지 않고 상태만 붙이는 방식이라,
## 라운드가 리셋되면 캐릭터가 새로 생기면서 표시도 같이 사라진다.
##
## 획득 연출(`ui/CrownCutIn.tscn`)은 "crown_cutin" 그룹으로 찾아 재생한다 —
## 궁극기 컷인이 "ultimate_cutin" 그룹을 쓰는 것과 같은 방식이라, 맵에 연출 노드가 없으면 그냥 넘어간다.
## **연출이 1.8초짜리라 뺏을 때마다 틀면 경기가 끊긴다.** 그래서 `cutin_once`가 켜져 있으면 그 라운드 첫 획득에만 튼다.

## 누군가 왕관을 차지한 순간 (연출을 붙일 자리)
signal crowned(king: Fighter)
## 왕이 맞아서 왕관을 떨어뜨린 순간
signal dropped(loser: Fighter)

## Fighter.custom_data에 왕 표시를 남길 때 쓰는 키
const KING_KEY := "playground_king"

@export_group("왕 버프")
## 왕의 이동속도 배수. 도망이 성립하려면 1보다 커야 한다
@export_range(1.0, 2.0, 0.05) var king_speed_multiplier: float = 1.25
## 왕의 공격력 배수.
## Fighter 쪽 프로퍼티 이름이 `attack_debuff_multiplier`라 디버프 전용처럼 보이지만,
## `compute_damage()`가 그대로 곱하는 값이라 1보다 크게 주면 버프가 된다
@export_range(1.0, 2.0, 0.05) var king_damage_multiplier: float = 1.3

@export_group("떨어뜨리기")
## 왕이 맞았을 때 왕관이 튕겨 나가는 초기 속도. x는 넉백 방향으로 부호가 붙고, y는 음수가 위쪽.
## **x를 0으로 둔 이유(실측):** 예전엔 (180, -420)이라 왕관이 넉백 방향으로 151px 날아갔는데,
## 정작 맞은 왕은 36px밖에 안 밀린다(넉백 253 / 마찰 900). 그래서 왕관이 **맞은 사람 너머**에 떨어져
## 경직(0.3초)이 풀린 왕이 0.74초에, 때린 쪽이 0.82초에 도착 — **때려도 맞은 쪽이 도로 줍는** 상태였다.
## 지금은 맞은 자리에 그대로 떨어져서, 밀려나지도 경직되지도 않은 때린 쪽이 조금 유리한 진짜 달리기 싸움이 된다.
## y도 -420에서 낮췄다 — 너무 높이 뜨면 내려올 때까지 둘 다 밑에서 기다리느라 달리기가 성립하지 않는다
@export var drop_velocity: Vector2 = Vector2(0.0, -300.0)
## 떨어진 뒤 다시 주울 수 있게 되기까지의 시간(초).
## **0으로 두면 안 된다** — 때린 쪽이 밀착해 있으면 떨어지자마자 그대로 회수해서
## "때리면 뺏김"이 되어 버린다. 잠깐 잠가야 둘 다 달려드는 쟁탈전이 생긴다
@export var pickup_delay: float = 0.35
## 못 줍는 동안 왕관이 깜빡이는 속도(초당 횟수). 0이면 안 깜빡인다
@export var lock_blink_speed: float = 6.0
## **주운 직후 이 시간(초) 동안은 맞아도 안 벗겨진다.**
## 이게 없으면 원거리 캐릭터(BB탄·토하기)가 맵 반대편에서 툭툭 치는 것만으로 왕관을 무한히 봉쇄한다 —
## 접근 리스크를 안 지고 왕을 무력화할 수 있어서 이 맵에서만 원거리가 압도적이 된다.
## "원거리인지"로 거르는 건 지금 수치로 불가능하다(BB탄/토하기 데미지 6·넉백 200 vs 기본공격 6·220으로 사실상 같다).
## 대신 **뺏기는 빈도에 상한**을 둬서 같은 문제를 푼다. 왕이 도망칠 시간을 주는 효과도 같이 난다
@export var drop_grace: float = 1.0
## 이 값 이상의 피해에만 왕관이 벗겨진다. **기본 0 = 끄기.**
## 0보다 크게 두면 원거리 견제를 걸러낼 것 같지만, 기본공격 데미지가 4~8이라
## 문턱을 8로 잡는 순간 **근접 기본공격까지 같이 막혀서** "쫓아가서 때려 떨어뜨린다"는 핵심 루프가 죽는다.
## 나중에 원거리 데미지를 따로 낮추면 그때 켤 것
@export var drop_min_damage: int = 0

@export_group("떨어진 왕관의 물리")
## 낙하 가속도(px/s²).
## **`gravity`라는 이름을 쓰면 안 된다** — Area2D에 같은 이름의 내장 프로퍼티가 이미 있어서
## `The member "gravity" already exists in parent class Area2D` 컴파일 에러가 난다
@export var fall_gravity: float = 1150.0
## 바닥에 닿았다고 볼 y좌표 — 왕관 **중심**이 이 높이에 멈춘다 (놀이터 지면 윗면 280 - 왕관 반높이 17)
@export var ground_y: float = 263.0
## 바닥에 튕길 때 남는 속도 비율. 0이면 안 튄다
@export_range(0.0, 0.8, 0.05) var bounce: float = 0.35
## 바닥에 닿았을 때 가로 속도가 줄어드는 비율(초당). 클수록 빨리 멈춘다
@export var ground_friction: float = 3.0
## 왕관이 나갈 수 없는 좌우 **중심** 한계.
## 놀이터 벽 안쪽 면이 ±700이고 왕관 폭이 56이라, 중심은 ±672까지만 가야 벽에 안 파고든다
@export var bounds_x: float = 672.0

@export_group("들고 있을 때")
## 왕의 원점(발밑)에서 왕관까지의 거리. 캐릭터 키가 60px이라 머리 위가 대략 -70이다
@export var head_offset: Vector2 = Vector2(0.0, -70.0)

@export_group("연출")
## true면 획득 컷인을 그 라운드 **첫 획득에만** 재생한다. false면 뺏을 때마다 재생
@export var cutin_once: bool = true

## 지금 왕관을 쓰고 있는 쪽 (없으면 바닥에 떨어져 있다는 뜻)
var _holder: Fighter
## 바닥에 있을 때의 낙하 속도
var _velocity: Vector2 = Vector2.ZERO
## 아직 못 줍는 남은 시간(초)
var _lock_left: float = 0.0
## 어딘가에 얹혀 가만히 있는 상태인가.
## **시작할 때 true여야 한다** — false로 두면 씬에 놓아둔 꼭대기 발판 자리에서
## 라운드 시작과 동시에 바닥으로 굴러떨어진다(발판을 통과하므로 아무 데도 안 걸린다)
var _grounded: bool = true
## 주운 뒤 안 벗겨지는 남은 시간(초)
var _grace_left: float = 0.0
## 이번 라운드에 컷인을 이미 틀었는지
var _cutin_played: bool = false
## 버프를 걸 때 쓰는 내 고유 번호 — 다른 효과가 건 배수를 안 지우도록 id로 구분한다
var _modifier_id: int = 0

## 이 캐릭터가 놀이터의 왕인가. 모래사장 쪽에서 이걸 보고 판단한다
static func is_king(fighter: Fighter) -> bool:
	if fighter == null or not is_instance_valid(fighter):
		return false
	return fighter.custom_data.get(KING_KEY, false)

func _ready() -> void:
	_modifier_id = get_instance_id()
	# AI가 맵에 왕관이 있는지 찾을 때 쓰는 표식 (controllers/AIController.gd)
	add_to_group("crown")

## 지금 바닥에 떨어져 있어서 주울 수 있는 상태인가
func is_available() -> bool:
	return not is_instance_valid(_holder) and _lock_left <= 0.0

## 지금 왕관을 쓰고 있는 쪽 (없으면 null)
func get_holder() -> Fighter:
	return _holder if is_instance_valid(_holder) else null

## 신호(area_entered) 대신 매 프레임 겹친 목록을 훑는다 — 라운드 리셋이나 순간이동으로
## 신호가 안 오는 경우가 있어서, 이 프로젝트의 다른 판정들(SandPit·SpringJumpPad)도 같은 방식이다
func _physics_process(delta: float) -> void:
	# 들고 있는 동안 흘러야 하는 값이라 아래 early return보다 먼저 깎는다
	if _grace_left > 0.0:
		_grace_left -= delta
	if is_instance_valid(_holder):
		# 들고 있는 동안은 머리 위에 따라다닌다
		global_position = _holder.global_position + head_offset
		return
	# 왕이 사라졌는데(라운드 리셋·링아웃) 표시가 남아 있으면 정리한다
	if _holder != null:
		_holder = null

	if _lock_left > 0.0:
		_lock_left -= delta
		if _lock_left <= 0.0:
			modulate.a = 1.0
	_fall(delta)
	_blink_while_locked()
	if _lock_left <= 0.0:
		_try_pickup()

## 떨어진 왕관을 직접 굴린다. Area2D라 물리 엔진이 안 밀어주므로 손으로 계산한다 —
## 바닥·벽만 신경 쓰면 되는 단순한 포물선이라 RigidBody2D를 붙일 이유가 없다
func _fall(delta: float) -> void:
	# ground_y / bounds_x는 전역 좌표 기준이다. 들고 있을 때 머리 위치도 global_position으로 잡으므로
	# 여기서도 전역으로 통일한다 — 섞어 쓰면 맵 루트가 조금이라도 움직이는 순간 어긋난다
	if _grounded:
		return
	var pos: Vector2 = global_position
	_velocity.y += fall_gravity * delta
	pos += _velocity * delta
	# 좌우 벽에 부딪히면 튕겨 돌아온다
	if absf(pos.x) > bounds_x:
		pos.x = clampf(pos.x, -bounds_x, bounds_x)
		_velocity.x = -_velocity.x * bounce
	if pos.y >= ground_y:
		pos.y = ground_y
		if absf(_velocity.y) > 60.0:
			_velocity.y = -_velocity.y * bounce   # 아직 튈 힘이 남았다
		else:
			# 다 튀었으니 미끄러지다가 멈춘다
			_velocity.y = 0.0
			_velocity.x = move_toward(_velocity.x, 0.0, absf(_velocity.x) * ground_friction * delta)
			if absf(_velocity.x) < 1.0:
				_velocity = Vector2.ZERO
				_grounded = true
	global_position = pos

## 못 줍는 동안 깜빡여서 "아직 안 된다"를 눈으로 알린다
func _blink_while_locked() -> void:
	if _lock_left <= 0.0 or lock_blink_speed <= 0.0:
		return
	modulate.a = 0.45 + 0.55 * absf(sin(_lock_left * lock_blink_speed * PI))

## 겹친 사람 중 **왕관에 가장 가까운 쪽**이 줍는다.
## 목록 순서대로 첫 번째를 집으면 둘이 동시에 달려들었을 때 늘 같은 플레이어가 이겨서
## 쟁탈전이 자리 싸움이 아니라 고정된 결과가 되어 버린다
func _try_pickup() -> void:
	var winner: Fighter = null
	var best: float = INF
	for area in get_overlapping_areas():
		if not (area is Hurtbox):
			continue
		var fighter: Fighter = area.fighter
		if fighter == null or not is_instance_valid(fighter) or fighter.current_hp <= 0:
			continue
		var d: float = global_position.distance_squared_to(fighter.global_position)
		if d < best:
			best = d
			winner = fighter
	if winner:
		_give_crown(winner)

func _give_crown(fighter: Fighter) -> void:
	_holder = fighter
	_grace_left = drop_grace
	_velocity = Vector2.ZERO
	modulate.a = 1.0
	fighter.custom_data[KING_KEY] = true
	fighter.set_modifier("move_speed_multiplier", _modifier_id, king_speed_multiplier)
	fighter.set_modifier("attack_debuff_multiplier", _modifier_id, king_damage_multiplier)
	# 이 왕이 맞으면 바로 떨어뜨린다. 왕이 바뀔 때마다 연결/해제하므로 중복 연결되지 않는다
	if not fighter.damaged.is_connected(_on_holder_damaged):
		fighter.damaged.connect(_on_holder_damaged)
	crowned.emit(fighter)
	_play_cutin(fighter)

## **넉백이 있는 피해(진짜 타격)에만 반응한다.**
## `Fighter.apply_dot()`·`MouseGrab`·`HazardPlatform`은 넉백 없이 `take_damage()`를 부르는데,
## 그것까지 받아주면 독 틱 한 번에 왕관이 벗겨지고(때린 사람도 없는데) 튀는 방향도 엉뚱해진다 —
## 넉백이 0이라 바라보는 방향의 반대로 날아가 버린다
func _on_holder_damaged(amount: int, knockback: Vector2) -> void:
	if knockback == Vector2.ZERO:
		return
	if _grace_left > 0.0:
		return
	if amount < drop_min_damage:
		return
	_drop(knockback)

## 왕관을 머리에서 떼어내 튕겨 보낸다.
## 가로 방향은 넉백을 따라간다 — 맞은 쪽이 날아가는 방향이라, 때린 사람이 자동으로 줍게 되지 않는다.
## (때리자마자 회수되면 사용자가 원한 "떨어진 걸 주워야 한다"가 성립하지 않는다)
func _drop(knockback: Vector2) -> void:
	var loser: Fighter = _holder
	if is_instance_valid(loser):
		global_position = loser.global_position + head_offset
		loser.custom_data.erase(KING_KEY)
		loser.clear_modifier("move_speed_multiplier", _modifier_id)
		loser.clear_modifier("attack_debuff_multiplier", _modifier_id)
		if loser.damaged.is_connected(_on_holder_damaged):
			loser.damaged.disconnect(_on_holder_damaged)
	_holder = null
	# 수직으로만 맞은 타격(넉백 x가 0)이면 맞은 쪽의 뒤쪽으로 흘린다
	var dir: float = signf(knockback.x)
	if dir == 0.0:
		dir = -loser.facing if is_instance_valid(loser) else 1.0
	_velocity = Vector2(drop_velocity.x * dir, drop_velocity.y)
	_grounded = false
	_lock_left = pickup_delay
	dropped.emit(loser)

func _play_cutin(fighter: Fighter) -> void:
	if cutin_once and _cutin_played:
		return
	var cutin: Node = get_tree().get_first_node_in_group("crown_cutin")
	if cutin == null or not cutin.has_method("play"):
		return
	_cutin_played = true
	cutin.play(fighter)
