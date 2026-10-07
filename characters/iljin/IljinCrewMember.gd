class_name IljinCrewMember
extends CharacterBody2D

## 일진 궁극기로 불려 나온 패거리 한 명 (친구 / 여자친구).
##
## **몸이 캐릭터와 똑같이 논다(2026-09-15)** — 중력을 받아 떨어지고, 맞으면 넉백에 밀리고,
## 바닥·벽·발판에 막힌다. 몸으로 길도 막아서 일진도 상대도 통과하지 못한다.
## 맞으면 HP가 깎이고, 다 깎이면 스르륵 사라진다.
##
## **처음엔 StaticBody2D였다** — 그 자리에 붙박인 "HP 있는 벽"이라 중력도 넉백도 안 받았다.
## 사용자 요청으로 `CharacterBody2D`로 바꾸면서 중력·마찰·`move_and_slide()`를 직접 돌린다.
##
## **그래도 Fighter로 만들지는 않는다.** Fighter의 `_ready()`는 자신을 "fighters" 그룹에 넣어서
## 카메라가 따라가고 AI가 상대로 착각하게 만들고, 그 위에 `_ignore_other_fighters()`가
## **캐릭터끼리의 몸 충돌을 꺼버려서 오히려 통과해 버린다**.
## 그룹 밖에 있으므로 상대 Fighter는 예외를 안 걸고 그대로 부딪힌다.

## 이만큼 맞으면 사라진다
@export var max_hp: int = 30
## 쓰러질 때 사라지는 데 걸리는 시간(초)
@export var fade_out: float = 0.35
## 맞았을 때 빨갛게 물드는 시간(초)
@export var flash_time: float = 0.12
## 넉백이 마찰로 잦아드는 빠르기(px/초²). 캐릭터 경직 마찰(`Fighter.HITSTUN_FRICTION`)과 같은 값이다 —
## 패거리는 조작 입력이 없으니 캐릭터처럼 "경직이 풀리면 멈추는" 대신 계속 마찰만 받는다
@export var knockback_friction: float = 900.0

## --- 침 뱉기 (친구 전용) ---
## **`spit_scene`이 비어 있으면 아무것도 안 한다** — 여자친구는 비워둬서 그냥 서 있기만 한다.
## 순서: 하늘색 파선으로 경고(`spit_warn_time`) -> 침이 일직선으로 날아감 -> `spit_interval` 뒤 반복
@export var spit_scene: PackedScene
## 경고로 띄울 하늘색 파선 (`skills/SpitWarning.gd`)
@export var warning_script: Script
## 침을 뱉는 간격(초)과 나타난 뒤 첫 침까지의 시간(초)
@export var spit_interval: float = 6.0
@export var spit_first_delay: float = 1.0
## 파선이 보이는 시간(초). 이게 지나면 바로 침이 나가고 **파선은 그 순간 사라진다**
@export var spit_warn_time: float = 0.5
## 침 데미지 / 속도(px/초) / 날아가는 거리(px) — 파선 길이도 이 거리에 맞춘다.
## **속도는 히트스캔급이다**(420px를 약 0.12초에 지난다). 빠른 만큼 한 프레임에 상대를 건너뛰지 않도록
## `Spit`이 발사할 때 판정을 진행 방향으로 길게 늘여준다
@export var spit_damage: int = 5
@export var spit_speed: float = 3600.0
@export var spit_range: float = 420.0
## 침이 나가는 자리 (몸 원점 기준, x는 바라보는 쪽으로 자동 반전).
## **머리 그림에서 실제로 입술이 있는 자리다**(2026-09-16 사용자 요청 "침 뱉는 게 입에서 나왔으면").
## 얼굴 그림 세 장(기본·모으는·뱉는)의 입술 끝을 다 재보니 전부 로컬 (20~21, -21)로 일치해서 그 값을 썼다 —
## 얼굴이 바뀌어도 입 자리는 안 움직인다는 뜻이라 얼굴별로 따로 둘 필요가 없다.
##
## **예전 값 (34, -26)은 입이 아니라 얼굴 바깥 허공이었다.** "몸 반지름(20) + 침 반지름(9)보다 커야
## 자기 몸에 안 닿는다"는 이유로 잡아 둔 값이었는데, 지금은 `Spit`이 "iljin_crew" 그룹 몸을 통과하고
## (`Spit._on_body_entered`) 피격 판정에 닿아도 안 사라지므로(관통) **그 제약이 이제 없다**
@export var mouth_offset: Vector2 = Vector2(21.0, -21.0)
## 침을 모으는 동안 / 뱉는 순간의 얼굴. 배율이 (0,0)이면 기본 머리 배율을 그대로 쓴다
@export var gather_face: Texture2D
@export var gather_face_scale: Vector2 = Vector2.ZERO
@export var spit_face: Texture2D
@export var spit_face_scale: Vector2 = Vector2.ZERO
## 뱉는 얼굴이 유지되는 시간(초)
@export var spit_face_time: float = 0.35

## --- 상대에게 걸어가기 (여자친구) ---
## 켜면 **좀비처럼 상대 쪽으로 계속 걸어간다.** 대시·방어·점프는 안 한다(사용자 지정)
@export var walk_to_opponent: bool = false
## 걷는 속도(px/초)
@export var walk_speed: float = 150.0
## 상대와 이 거리(px) 안이면 멈춘다 — 발차기 사거리보다 조금 짧게 잡아 붙어서 차게 한다
@export var walk_stop_distance: float = 38.0
## 넉백을 맞은 뒤 다시 걷기까지 굳어 있는 시간(초).
## **0으로 두면 안 된다** — 맞자마자 걸어가서 넉백이 없던 일이 된다(그네 튕김과 같은 함정)
@export var knockback_stun: float = 0.35

## --- 발차기 (여자친구) ---
## 켜면 상대가 사거리 안에 들어왔을 때 발로 찬다. 자세는 리그의 발차기 모션(`attack_kick_hit`)을 쓴다
@export var kick_enabled: bool = false
@export var kick_damage: int = 6
## 발이 닿는 거리(px)와 세로로 인정하는 범위(px)
@export var kick_range: float = 46.0
@export var kick_height: float = 48.0
## 다음 발차기까지 쉬는 시간(초)
@export var kick_interval: float = 1.6
## 예비동작 / 판정이 켜진 시간 / 뒤끝(초). **이 동안은 걷지 않는다**.
## `kick_windup`은 리그 `attack_duration`의 40%와 맞춰야 발이 다 뻗은 순간에 판정이 나간다(0.5 x 0.4 = 0.2)
@export var kick_windup: float = 0.2
@export var kick_active: float = 0.12
@export var kick_recover: float = 0.2
@export var kick_knockback: Vector2 = Vector2(260.0, -150.0)

## --- 상대 조준 (침 뱉는 쪽만 켠다) ---
## 켜면 **매 프레임** 상대를 향해 몸을 돌리고 머리로 겨눈다. 침·경고 파선도 그 방향으로 나간다
@export var face_opponent: bool = false
## 머리가 위아래로 꺾이는 최대 각도(도). 넘으면 고개가 꺾여 보여서 이 각도로 자른다
@export var head_aim_max_deg: float = 35.0
## 이 거리(px) 안에서는 좌우를 안 바꾼다 — 딱 겹쳤을 때 몸이 덜덜 뒤집히는 걸 막는다
@export var face_deadzone: float = 8.0

var current_hp: int = 0
## 패거리는 방어를 못 한다. `Hitbox._is_blocked_by_guard()`가 이 프로퍼티를 읽어 가므로 반드시 있어야 한다
var is_guarding: bool = false

## 이미 쓰러지는 중인지 (사라지는 동안 또 맞아도 두 번 처리되지 않게)
var _dying: bool = false
## 잡혀 있는 동안(고양이 옷 3타) — 잡은 쪽이 자리를 직접 옮기므로 스스로는 움직이지도 뱉지도 차지도 않는다
var is_grabbed: bool = false
## 몸 충돌을 이미 꺼 둔 캐릭터들 {instance_id: true} — 같은 상대에게 두 번 걸지 않으려고 적어 둔다
var _ignored: Dictionary = {}

@onready var _visual: Node2D = get_node_or_null("Visual")
@onready var _body_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var _hurtbox: Area2D = get_node_or_null("Hurtbox")

## 부른 사람 — 침의 주인으로 넘겨서 "누구 공격인지"가 방어 판정까지 이어지게 한다
var _owner_fighter: Fighter = null
## 부른 사람이 "있었는지" 기억해둔다. **해제된 객체는 `== null`이 true**라서 이것 없이는
## "원래 주인이 없었다"와 "주인이 사라졌다"를 구분할 수 없다(GDScript 공통 함정)
var _had_owner: bool = false
## 다음 침까지 남은 시간 / 경고 파선이 남은 시간 / 뱉는 얼굴이 남은 시간
var _spit_left: float = 0.0
var _warn_left: float = 0.0
var _face_left: float = 0.0
## 지금 떠 있는 경고 파선 (침이 나가는 순간 직접 지운다)
var _warning: Node2D = null
## 지금 겨누고 있는 방향(단위 벡터). 머리·파선·침이 전부 이 값을 따라간다
var _aim: Vector2 = Vector2.RIGHT
## 넉백을 맞고 굳어 있는 남은 시간 / 발차기 동작 남은 시간 / 판정이 켜진 남은 시간 / 다음 발차기까지 쿨
var _stun_left: float = 0.0
var _kick_left: float = 0.0
var _kick_active_left: float = 0.0
var _kick_cd: float = 0.0
var _kick_fired: bool = false
@onready var _kick_hitbox: Hitbox = get_node_or_null("Hitbox")

func _ready() -> void:
	current_hp = max_hp
	# 자기가 뱉은 침이 앞에 선 동료 몸에 막히지 않게 — `Spit`이 이 그룹을 보고 통과시킨다
	add_to_group("iljin_crew")
	# 소환물 분류: 생물체 — 평타가 캐릭터와 똑같이 들어가고, 고양이 옷 3타에 잡혀 내던져진다(`ComboMeleeAttack.SUMMON_CREATURE_GROUP`)
	add_to_group(&"summon_creature")
	_spit_left = spit_first_delay
	_ignore_fighter_bodies()

## **캐릭터와의 몸 충돌을 끈다**(2026-09-16 사용자 요청 "머리 위로 올라가는 거 막아줘").
## 물리 충돌을 켜 두면 캐릭터가 패거리 **머리 위에 올라서서 발판처럼 밟고 다닌다.**
## 지붕처럼 뾰족한 도형으로 바꿔도 못 막았다 — 꼭짓점에 정확히 떨어지면 법선이 위를 향해
## 바닥으로 판정돼 그대로 올라선다(실측: 캡슐 꼭대기 높이에 그대로 안착).
## 그래서 **캐릭터끼리 이미 쓰고 있는 방식**을 그대로 가져왔다(`Fighter._ignore_other_fighters`
## + `_separate_from_others`): 세로 충돌은 아예 끄고 **가로로만 코드로 밀어낸다**(`_block_fighters`).
## 양쪽에 다 걸어야 한다 — 한쪽만 걸면 상대 쪽 `move_and_slide`가 여전히 막힌다.
##
## **`_ready()`에서 한 번만 걸면 안 된다.** 그때 아직 없던 캐릭터는 그냥 빠져서 그 캐릭터만
## 머리 위에 올라설 수 있다(실측으로 겪음). 그래서 매 물리 프레임에 다시 훑되,
## 이미 건 상대는 `_ignored`에 적어 두고 건너뛴다 — 보통 캐릭터가 둘뿐이라 비용이 없다시피 하다
func _ignore_fighter_bodies() -> void:
	for f in get_tree().get_nodes_in_group("fighters"):
		if not (f is PhysicsBody2D) or not is_instance_valid(f):
			continue
		var id: int = f.get_instance_id()
		if _ignored.has(id):
			continue
		_ignored[id] = true
		add_collision_exception_with(f)
		f.add_collision_exception_with(self)

## 부른 사람을 알려준다 — **그 사람의 공격은 안 맞는다.** 패거리가 일진 바로 옆에 서 있어서
## 상대를 때리려다 자기 편을 때려 죽이는 일이 생긴다
func set_owner_fighter(fighter: Node) -> void:
	_owner_fighter = fighter as Fighter
	_had_owner = _owner_fighter != null
	if _hurtbox == null:
		_hurtbox = get_node_or_null("Hurtbox")
	if _hurtbox:
		_hurtbox.immune_source = fighter
	# **부른 사람이 쓰러지면 패거리도 같이 사라진다** — 일진이 KO된 자리에 패거리만 남아 있으면
	# 누가 이겼는지 헷갈린다. 라운드가 바뀔 땐 씬이 통째로 다시 만들어져서 저절로 정리된다
	if _owner_fighter and not _owner_fighter.died.is_connected(_on_owner_died):
		_owner_fighter.died.connect(_on_owner_died)

func _on_owner_died() -> void:
	if _dying:
		return
	_fall()

func _process(delta: float) -> void:
	if _dying or is_grabbed:
		return
	# 부른 사람이 시그널도 없이 사라졌으면(훈련장에서 캐릭터 교체 등) 남아 있을 이유가 없다
	if _had_owner and not is_instance_valid(_owner_fighter):
		_fall()
		return
	# **매 프레임 상대를 따라본다** — 상대가 반대편으로 돌아가도 등을 보인 채 엉뚱한 데 뱉지 않는다
	if face_opponent:
		_track_opponent()
	if kick_enabled:
		_update_kick(delta)
	if spit_scene == null:
		return
	# 뱉는 얼굴은 잠깐만 — 시간이 지나면 기본 얼굴로 돌아간다
	if _face_left > 0.0:
		_face_left = maxf(_face_left - delta, 0.0)
		if _face_left <= 0.0:
			_clear_face()
	# 경고(파선)가 도는 중이면 그게 끝나는 순간 바로 침이 나간다
	if _warn_left > 0.0:
		_warn_left = maxf(_warn_left - delta, 0.0)
		# 머리가 계속 조준하므로 파선도 같이 따라간다 — 셋(머리·파선·침)이 어긋나면 "조준"으로 안 보인다
		if is_instance_valid(_warning):
			_warning.position = _mouth_offset()
			_warning.rotation = _aim.angle()
		if _warn_left <= 0.0:
			_fire_spit()
		return
	_spit_left = maxf(_spit_left - delta, 0.0)
	if _spit_left <= 0.0:
		_begin_warning()

## 침을 모으기 시작한다 — 얼굴이 바뀌고 날아갈 자리에 하늘색 파선이 깔린다
func _begin_warning() -> void:
	_warn_left = spit_warn_time
	_set_face(gather_face, gather_face_scale)
	if warning_script == null:
		return
	var warn := warning_script.new() as Node2D
	if warn == null:
		return
	# **자기 자식으로 붙인다** — 쓰러져 사라질 때 경고선도 같이 정리된다
	add_child(warn)
	warn.position = _mouth_offset()
	warn.setup(_facing(), spit_range, spit_warn_time)
	_warning = warn

## 파선이 가리키던 그 자리로 침을 쏜다
func _fire_spit() -> void:
	# **침이 날아가는 동안 파선이 남아 있으면 안 된다.** 파선도 제 시간에 스스로 사라지지만
	# queue_free()는 이번 프레임 끝에 처리돼서 한 프레임 같이 보일 수 있다 — 여기서 먼저 숨기고 지운다
	if is_instance_valid(_warning):
		_warning.hide()
		_warning.queue_free()
	_warning = null
	_spit_left = spit_interval
	_set_face(spit_face, spit_face_scale)
	_face_left = spit_face_time
	var map: Node = get_parent()
	if map == null or spit_scene == null:
		return
	var spit := spit_scene.instantiate() as Node2D
	if spit == null:
		return
	# **수명은 setup() 전에 넣어야 한다** — Projectile이 setup()에서 타이머를 만들기 때문이다
	if "lifetime" in spit and spit_speed > 0.0:
		spit.lifetime = spit_range / spit_speed
	map.add_child(spit)
	spit.global_position = global_position + _mouth_offset()
	if spit.has_method("setup"):
		# 주인을 일진으로 넘겨야 "캐릭터의 공격"이 돼서 방어로 막히고 일진 자신은 안 맞는다.
		# 일진이 이미 사라졌으면 주인 없는 판정(맵 피해)이 된다
		var shooter: Fighter = _owner_fighter if is_instance_valid(_owner_fighter) else null
		spit.setup(_facing(), spit_speed, spit_damage, shooter)
		# 카운터 반격이 일진이 아니라 침을 뱉은 이 패거리에게 오도록 실제로 쏜 몸을 적어 둔다
		if "attacker_body" in spit:
			spit.attacker_body = self
	# **setup 다음에 부를 것** — setup이 rotation을 수평으로 덮어쓴다
	if spit.has_method("aim"):
		spit.aim(_aim)

## 발차기 — 사거리 안에 상대가 있으면 예비동작 뒤에 판정을 잠깐 켠다.
## 자세는 리그의 발차기 모션이 맡는다(`attack_kick_hit`을 0으로 두고 `play_attack_swing(0)`)
func _update_kick(delta: float) -> void:
	_kick_cd = maxf(_kick_cd - delta, 0.0)
	# 판정 창이 지나면 히트박스를 끈다
	if _kick_active_left > 0.0:
		_kick_active_left = maxf(_kick_active_left - delta, 0.0)
		if _kick_active_left <= 0.0:
			_set_kick_hitbox(false)
	# 동작이 도는 중 — 예비동작이 끝나는 순간에 딱 한 번 판정을 켠다
	if _kick_left > 0.0:
		_kick_left = maxf(_kick_left - delta, 0.0)
		if not _kick_fired and _kick_left <= kick_active + kick_recover:
			_kick_fired = true
			_fire_kick()
		return
	if _kick_cd > 0.0 or _stun_left > 0.0:
		return
	var foe: Fighter = _find_opponent()
	if foe == null:
		return
	if absf(foe.global_position.x - global_position.x) > kick_range:
		return
	if absf(foe.global_position.y - global_position.y) > kick_height:
		return
	_kick_left = kick_windup + kick_active + kick_recover
	_kick_fired = false
	if _visual and _visual.has_method("play_attack_swing"):
		_visual.play_attack_swing(0)

## 발이 다 뻗은 순간 — 앞쪽에 판정을 켠다
func _fire_kick() -> void:
	if _kick_hitbox == null:
		return
	_kick_hitbox.damage = kick_damage
	_kick_hitbox.knockback = Vector2(kick_knockback.x * _facing(), kick_knockback.y)
	# **주인을 일진으로 넘긴다** — 그래야 "캐릭터의 공격"이 돼서 방어로 막히고,
	# 일진 자신과 다른 패거리(immune_source가 일진)는 안 맞는다
	_kick_hitbox.source_fighter = _owner_fighter if is_instance_valid(_owner_fighter) else null
	_kick_hitbox.global_position = global_position + Vector2(kick_range * _facing(), 0.0)
	_kick_hitbox.clear_repeat_state()
	_set_kick_hitbox(true)
	_kick_active_left = kick_active
	_kick_cd = kick_interval

## 물리 연산 중에 켜고 끄면 Godot이 막으므로 deferred로 미룬다
func _set_kick_hitbox(on: bool) -> void:
	if _kick_hitbox == null:
		return
	_kick_hitbox.set_deferred("monitoring", on)
	_kick_hitbox.set_deferred("monitorable", on)

## 상대를 향해 몸을 돌리고(좌우) 머리로 겨눈다(위아래). 매 프레임 부른다
func _track_opponent() -> void:
	var foe: Fighter = _find_opponent()
	if foe == null or _visual == null:
		_set_head_aim(0.0)
		return
	# **몸 기준 오른쪽에 있으면 오른쪽으로 몸을 튼다.** 좌우 반전은 리그의 scale.x 부호가 맡는다
	var dx: float = foe.global_position.x - global_position.x
	if absf(dx) >= face_deadzone:
		_visual.scale.x = absf(_visual.scale.x) * signf(dx)
	_aim = _compute_aim(foe)
	# 리그에는 "바라보는 쪽을 0으로 본 위아래 각"을 넘긴다 (좌우 반전은 리그가 알아서 맞춘다)
	_set_head_aim(atan2(_aim.y, _aim.x * _facing()))

## 상대를 찾는다 — 부른 사람(일진)은 뺀다. 패거리는 "fighters" 그룹에 없으므로 서로를 겨누지 않는다
func _find_opponent() -> Fighter:
	for f in get_tree().get_nodes_in_group("fighters"):
		if f == _owner_fighter or not (f is Fighter) or not is_instance_valid(f):
			continue
		return f
	return null

## 입에서 상대 몸 중심으로 향하는 단위 벡터. 위아래 각도는 head_aim_max_deg로 자른다
func _compute_aim(foe: Fighter) -> Vector2:
	var forward := Vector2(_facing(), 0.0)
	if foe == null:
		return forward
	var from: Vector2 = global_position + _mouth_offset()
	var to_foe: Vector2 = foe.global_position - from
	if to_foe.length() < 1.0:
		return forward
	to_foe = to_foe.normalized()
	# 너무 가파르면 고개가 꺾여 보인다 — 각도를 자르고 그 각도로 방향을 다시 만든다
	var limit: float = deg_to_rad(head_aim_max_deg)
	var elev: float = clampf(atan2(to_foe.y, to_foe.x * _facing()), -limit, limit)
	return Vector2(cos(elev) * _facing(), sin(elev))

func _set_head_aim(radians: float) -> void:
	if _visual and _visual.has_method("set_head_aim"):
		_visual.set_head_aim(radians)

## 지금 바라보는 쪽(+1 오른쪽 / -1 왼쪽). 리그의 좌우 반전 부호가 곧 방향이다
func _facing() -> float:
	if _visual and _visual.scale.x < 0.0:
		return -1.0
	return 1.0

## 바라보는 쪽으로 뒤집은 입 위치 (몸 원점 기준).
##
## **머리가 위아래로 겨누면(`set_head_aim`) 입도 같이 돈다** — 머리 회전축(리그의 `Head` 노드 자리)을
## 중심으로 같은 각도만큼 돌린다. 이게 없으면 최대 각도(35도)로 겨눌 때 그려진 입과 침이 나가는 자리가
## 15px쯤 어긋나서, 위를 쏠 때 턱 밑에서 침이 나오는 것처럼 보인다.
## **회전축은 리그에서 그때그때 읽는다** — 에디터에서 머리 위치를 옮겨도 저절로 따라온다.
## 좌우 반전(`_facing()`)은 **다 돌린 뒤 맨 마지막에** 곱한다 — 리그도 `scale.x` 부호로 뒤집으므로
## 계산은 전부 "오른쪽을 본 상태"에서 하고 마지막에 한 번만 뒤집어야 맞는다
func _mouth_offset() -> Vector2:
	var m: Vector2 = mouth_offset
	var head: Node2D = _head_node()
	if head != null and not is_zero_approx(head.rotation):
		m = head.position + (m - head.position).rotated(head.rotation)
	return Vector2(m.x * _facing(), m.y)

## 리그의 머리 스프라이트 (없으면 null)
func _head_node() -> Node2D:
	if _visual == null:
		return null
	return _visual.get_node_or_null("Head") as Node2D

## 리그의 액션 표정 슬롯을 그때그때 갈아끼운다 (일진의 담배·돌진 스킬과 같은 방식)
func _set_face(tex: Texture2D, tex_scale: Vector2) -> void:
	if tex == null or _visual == null or not _visual.has_method("set_action_face"):
		return
	_visual.action_head_texture = tex
	_visual.action_head_scale = tex_scale
	_visual.set_action_face(true)

func _clear_face() -> void:
	if _visual and _visual.has_method("set_action_face"):
		_visual.set_action_face(false)

## 중력·마찰·이동. **캐릭터와 같은 중력(`Fighter.gravity`)을 쓴다** — 훈련장에서 중력을 바꾸면 같이 따라간다.
## 쓰러지는 중에는 건드리지 않는다(판정·충돌을 이미 껐으므로 그대로 두면 바닥을 뚫고 내려간다)
func _physics_process(delta: float) -> void:
	if _dying:
		return
	if is_grabbed:
		velocity = Vector2.ZERO
		return
	if not is_on_floor():
		velocity.y += Fighter.gravity * delta
	if _stun_left > 0.0:
		_stun_left = maxf(_stun_left - delta, 0.0)
	# 좀비처럼 상대 쪽으로 계속 걸어간다 — 맞고 굳은 동안과 발차기 중에는 멈춘다
	if walk_to_opponent and _stun_left <= 0.0 and _kick_left <= 0.0:
		_walk_toward_opponent(delta)
	else:
		# 조작 입력이 없으니 넉백은 마찰로만 잦아든다
		velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
	move_and_slide()
	_ignore_fighter_bodies()
	_block_fighters()
	_update_walk_pose()

## 몸이 가로로 겹친 캐릭터를 옆으로 밀어낸다 — **이게 "몸으로 길을 막는다"의 실체다**
## (세로 충돌은 `_ignore_fighter_bodies`에서 꺼 놨으므로 머리 위에는 못 선다).
## 간격·높이 기준은 캐릭터끼리 쓰는 값(`Fighter.BODY_PUSH_*`)을 그대로 빌려 쓴다 —
## 한쪽만 다른 값을 쓰면 "캐릭터는 못 지나가는데 패거리는 지나가진다" 같은 어긋남이 생긴다.
##
## **패거리는 안 밀린다** — 그 자리에 버티고 선 벽이라 같이 밀리면 막는 의미가 없다.
## 그래서 캐릭터끼리처럼 절반씩 나누지 않고 **상대를 겹친 만큼 통째로** 밀어낸다.
## **부른 사람(일진)은 안 민다** — 내 편이 앞을 막으면 조작이 답답해진다
func _block_fighters() -> void:
	for f in get_tree().get_nodes_in_group("fighters"):
		if not (f is Fighter) or not is_instance_valid(f) or f == _owner_fighter:
			continue
		if absf(global_position.y - f.global_position.y) > Fighter.BODY_PUSH_HEIGHT:
			continue
		var dx: float = f.global_position.x - global_position.x
		var dist: float = absf(dx)
		if dist >= Fighter.BODY_PUSH_WIDTH:
			continue
		var dir: float = signf(dx)
		if dir == 0.0:
			# 완전히 겹쳤으면 한쪽으로 갈라 내보낸다(그 자리에 갇히지 않게)
			dir = 1.0 if f.get_instance_id() > get_instance_id() else -1.0
		# move_and_collide라 벽은 안 뚫는다 — 벽과 패거리 사이에 몰리면 거기서 멈춘다
		f.move_and_collide(Vector2(dir * (Fighter.BODY_PUSH_WIDTH - dist), 0.0))

## 상대 쪽으로 걸어간다. 붙었으면 멈춘다(계속 밀면 상대를 밀고 다니는 꼴이 된다)
func _walk_toward_opponent(delta: float) -> void:
	var foe: Fighter = _find_opponent()
	if foe == null:
		velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
		return
	var dx: float = foe.global_position.x - global_position.x
	velocity.x = signf(dx) * walk_speed if absf(dx) > walk_stop_distance else 0.0

## 리그에 "지금 얼마나 빨리 걷는지"를 알려줘야 걷기 동작이 나온다.
## 리그는 원래 부모 Fighter의 속도를 보는데 패거리는 Fighter가 아니라서, 컷인이 쓰는
## `manual_speed_ratio` 통로로 직접 넣어준다(Fighter가 있으면 무시되므로 캐릭터엔 영향 없다)
func _update_walk_pose() -> void:
	if not walk_to_opponent or _visual == null or not ("manual_speed_ratio" in _visual):
		return
	_visual.manual_speed_ratio = clampf(absf(velocity.x) / maxf(walk_speed, 1.0), 0.0, 1.0)

## 맞은 순간 캐릭터와 **같은 식**으로 넉백을 받는다(`Fighter.take_damage`의 계산을 그대로 옮긴 것).
## 수평은 `KNOCKBACK_MULTIPLIER`만큼 키워 더하고, 위로는 데미지 비례 팝업만큼 띄운다
func _apply_knockback(knockback: Vector2, amount: int, pop_override: float) -> void:
	if knockback == Vector2.ZERO:
		return
	# 맞은 뒤 잠깐 굳는다 — 안 굳으면 다음 프레임에 걷기가 velocity.x를 덮어써서 넉백이 사라진다
	_stun_left = maxf(_stun_left, knockback_stun)
	velocity.x += knockback.x * Fighter.KNOCKBACK_MULTIPLIER
	velocity.y += knockback.y
	var pop: float = pop_override
	if pop < 0.0:
		pop = clampf(Fighter.HIT_POP_BASE + amount * Fighter.HIT_POP_PER_DAMAGE, 0.0, Fighter.HIT_POP_MAX)
	if pop > 0.0:
		velocity.y = minf(velocity.y, -pop)

## Hurtbox가 넘겨주는 피해. **넉백도 캐릭터와 똑같이 받는다**(2026-09-15) —
## 예전엔 그 자리에 버티는 벽이라 넉백을 무시했다
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, pop_override: float = -1.0, _ignore_guard: bool = false) -> void:
	if _dying:
		return
	current_hp = maxi(current_hp - amount, 0)
	_apply_knockback(knockback, amount, pop_override)
	_flash()
	_play_hurt_face()
	if current_hp <= 0:
		_fall()

## 맞은 순간 잠깐 아파하는 얼굴로 (캐릭터의 `Fighter._play_hurt_face()`와 같은 방식).
## 그 표정 그림이 없는 몸(여자친구)은 리그가 알아서 그냥 넘어간다
func _play_hurt_face() -> void:
	if _visual and _visual.has_method("play_hurt_face"):
		_visual.play_hurt_face()

## 맵 기믹(지나가는 열차 등)이 주는 피해. 패거리에겐 구분할 게 없어 똑같이 받는다
func take_map_damage(amount: int, knockback: Vector2 = Vector2.ZERO, pop_override: float = -1.0) -> void:
	take_damage(amount, knockback, pop_override, true)

## 맞은 순간 잠깐 빨갛게 (캐릭터의 `Fighter._flash_hit()`과 같은 연출).
## **루트가 아니라 Visual에 건다** — 루트의 modulate는 등장/퇴장 페이드가 쓰고 있어서 서로 덮어쓴다
func _flash() -> void:
	if _visual == null:
		return
	var tween := create_tween()
	tween.tween_property(_visual, "modulate", Color(1.0, 0.35, 0.35), flash_time * 0.35)
	tween.tween_property(_visual, "modulate", Color(1.0, 1.0, 1.0), flash_time)

## HP가 0이 됐다 — 판정과 길막을 먼저 끄고 서서히 사라진다
func _fall() -> void:
	_dying = true
	# 사라지는 걸 기다렸다 지나가야 하면 답답하다. 물리 연산 중에 끄면 Godot이 막으므로 deferred로 미룬다
	if _body_shape:
		_body_shape.set_deferred("disabled", true)
	if _hurtbox:
		_hurtbox.set_deferred("monitorable", false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_out)
	tween.tween_callback(queue_free)
