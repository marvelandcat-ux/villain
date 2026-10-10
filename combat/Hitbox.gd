class_name Hitbox
extends Area2D

## 공격 판정 — 겹친 Hurtbox에게 데미지를 주고, 실제로 맞았으면 히트 이펙트를 띄운다

## 실제로 명중한 순간 알린다 — 공격자 쪽 스킬이 "맞았으니 콤보 다음 타로 진행" 같은 히트 확인에 쓴다.
## victim은 맞은 Fighter (없을 수도 있어 Node로 받는다)
signal connected(victim: Node)

@export var damage: int = 10
@export var knockback: Vector2 = Vector2.ZERO
## true면 knockback을 그대로 쓰지 않고, 맞는 순간 "공격자 쪽으로" 방향을 계산해서 끌어당긴다 (청소기 흡입 등)
@export var pull_to_source: bool = false
@export var pull_strength: float = 250.0
## 0보다 크면 겹쳐 있는 동안 이 간격(초)마다 계속 다시 때린다 (지나가는 열차에 계속 밀리는 연출).
## 0이면 예전처럼 처음 겹친 순간에 딱 한 번만 때린다 — 스킬 히트박스는 전부 0을 쓴다
@export var repeat_interval: float = 0.0
## 명중 시 이 장면을 명중 지점에 스폰한다 (주정뱅이 술병 깨진 유리 파편 등). 비어 있으면 아무것도 안 한다.
## 스폰된 노드에 setup(pos) 메서드가 있으면 그걸로 위치를 넘기고, 없으면 global_position만 맞춘다
@export var debris_scene: PackedScene
## 명중 시 타격 스파크(HitSpark)를 띄울지. 꺼도 방어에 막혔을 때의 `GuardImpact`는 그대로 뜬다 —
## 막힌 건 보여야 막았다는 게 읽혀서 그대로 둔다(2026-09-25, 금쪽이 기본공격에서 끔)
@export var hit_spark: bool = true
## 켜면 명중 효과가 **둔기(퍽!)** 로 바뀐다 — 날붙이용 `HitSpark`(가늘게 찢어지는 섬광) 대신
## `combat/BluntImpact.gd`(두꺼운 충격 고리 + 뭉툭한 쐐기 + 먼지)가 뜬다.
## 막혔을 때는 둔기든 아니든 `GuardImpact`가 뜬다 — "막았다"는 신호는 캐릭터마다 같아야 한다
@export var blunt_impact: bool = false
## 명중 시 카메라를 흔드는 세기 = damage × 이 값 (0이면 안 흔든다). 데미지가 클수록 크게·오래 흔들린다
@export var shake_per_damage: float = 0.04
## 켜면 **피해를 하나도 주지 않고 "스쳤다"만 알린다**(`connected` 신호만 뜬다).
## 데미지·넉백·경직·스파크·숫자 팝업이 전부 안 나간다 — 지나가며 **표시만 남기고** 피해는
## 나중에 따로 주는 공격에 쓴다(지하철 궁 돌진이 칼자국만 새기고 지나갈 때).
## ⚠️ `Hurtbox.take_hit`을 안 거치므로 **자기 자신·아군 거르기를 여기서 직접 한다**
@export var sense_only: bool = false
## 맞은 상대를 위로 띄우는 힘(px/s). 음수(기본)면 데미지 비례 기본 팝업, 0이면 안 띄운다(지상 유지).
## 콤보 앞 타격이 상대를 공중에 날려버려 다음 타가 헛치는 걸 막을 때 0으로 둔다
@export var pop_override: float = -1.0
## 명중했을 때 울릴 소리(비면 무음). **방어에 막혔을 땐 안 난다.**
## 기본공격은 `ComboMeleeAttack.punch_sound`가 비어 있는 판정에 채워 넣는다
@export var hit_sound: AudioStream
@export var hit_sound_volume_db: float = 0.0

## --- 히트스톱(타격 정지) ---
## 명중하는 순간 **화면 전체가** 멈추는 시간(초) = 이 값 + 데미지 x `hitstop_per_damage`(최대 `hitstop_max`).
## 맞은 쪽만 굳는 경직(`Fighter._hitstun_time`)과는 **다른 것**이다 — 때린 쪽·이펙트·카메라까지 같이 멈춰서
## 주먹이 상대를 그냥 통과하지 않고 "쿵" 하고 부딪힌 것처럼 보인다. 0으로 두면 그 히트박스는 안 멈춘다
## **2026-09-25 사용자 요청으로 꺼 뒀다(0).** 이 값이 0이면 `_apply_hitstop()`이 바로 빠져나가서
## 데미지 비례분·`AttackData.hitstop_scale`도 같이 무시된다. 다시 켜려면 0.022(예전 값)로 돌리면 된다
@export var hitstop_time: float = 0.0
## 데미지 1당 더 멈추는 시간(초) — 센 공격일수록 길게 멈춘다
@export var hitstop_per_damage: float = 0.002
## 아무리 세도 이 이상은 안 멈춘다(초). 너무 길면 조작이 끊긴 것처럼 느껴진다
@export var hitstop_max: float = 0.06
## 멈춘 동안의 시간 배속. 0에 가까울수록 완전히 정지한다 (정확히 0은 피한다)
const HITSTOP_SCALE: float = 0.0001
## 히트 스파크 세기 1이 되는 데미지 — 기본공격 한 방(약 7)이 "보통" 크기로 튀게 잡은 값
const SPARK_POWER_DAMAGE: float = 7.0
## 효과음 헬퍼(새 class_name이라 이름 대신 preload로 부른다)
const _SFX := preload("res://combat/Sfx.gd")
## 방어에 막힌 이펙트(새 class_name이라 이름 대신 preload로 부른다)
const _GUARD_IMPACT := preload("res://combat/GuardImpact.gd")
## 카운터 히트 연출(멈춤·배경 흐림·"COUNTER" 글자). 씬에 하나만 두고 이름으로 찾아 쓴다
const _COUNTER_HIT_FX := preload("res://combat/CounterHitFx.gd")

## 이 히트박스를 만든 캐릭터. 자기 자신의 Hurtbox는 맞아도 무시된다.
## 맵 기믹(지나가는 열차 등)처럼 주인이 없는 히트박스는 null로 둔다
var source_fighter: Fighter:
	get:
		return _source_fighter
	set(value):
		_source_fighter = value
		_has_source = value != null

var _source_fighter: Fighter = null
## 주인이 "있었는지" 기억해둔다. 해제된 객체는 `== null`이 true라서 이걸로만 null과 구분할 수 있다
var _has_source: bool = false
## 이번 타에 debris_scene을 뿌릴지. 콤보 공격이 매 타 켜고 끈다 —
## 주정뱅이 술방울은 마무리 3타에만 튄다(`ComboMeleeAttack.debris_final_hit_only`)
var debris_enabled: bool = true
## 이번 판정의 히트스톱·화면 흔들림 배수 — 콤보가 타마다 넣어준다(AttackData.hitstop_scale / shake_scale).
## 씬에 저장되지 않는 런타임 값이라 다른 판정에는 영향이 없다(기본 1)
var hitstop_multiplier: float = 1.0
var shake_multiplier: float = 1.0
## 이번 판정의 소리 음높이 — 콤보가 타마다 넣어준다(마무리 타는 낮게 = 묵직하게)
var hit_sound_pitch: float = 1.0
## 실제로 때린 몸 — 소환물이 쏜 투사체처럼 판정이 맵에 붙어 있어 부모로 못 찾을 때 쏜 쪽이 넣어 준다.
## 비워 두면 `get_attacker()`가 부모를 거슬러 올라가 찾는다. 카운터 반격이 누구에게 갈지 정하는 데 쓴다
var attacker_body: Node = null
## repeat_interval을 쓸 때, 겹쳐 있는 Hurtbox마다 다음 타격까지 남은 시간 {Hurtbox: float}
var _repeat_cooldowns: Dictionary = {}
## 지금 처리 중인 한 방이 카운터 히트인지 — 스파크·숫자 팝업을 흐림 판 위로 올릴 때 본다
var _counter_now: bool = false

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _on_area_entered(area: Area2D) -> void:
	if _try_hit(area):
		# 방금 때렸으니 반복 타격은 repeat_interval 뒤부터 (겹친 프레임에 두 번 맞지 않게)
		_repeat_cooldowns[area] = repeat_interval

func _on_area_exited(area: Area2D) -> void:
	_repeat_cooldowns.erase(area)

## repeat_interval이 켜져 있으면, 겹쳐 있는 동안 그 간격마다 계속 다시 때린다.
## SpringJumpPad/SandPit과 같은 방식(대상별 쿨타임)이라 매 프레임 연속으로 맞지는 않는다
func _process(delta: float) -> void:
	if repeat_interval <= 0.0 or not monitoring:
		return
	for area in get_overlapping_areas():
		var left: float = _repeat_cooldowns.get(area, 0.0) - delta
		if left <= 0.0:
			if not _try_hit(area):
				continue
			left = repeat_interval
		_repeat_cooldowns[area] = left

## 실제 타격 한 번. 맞았으면 true
func _try_hit(area: Area2D) -> bool:
	# 공격자가 판정보다 먼저 사라졌으면(훈련장에서 캐릭터를 바꾸면 옛 Fighter만 해제되고, 맵에 붙어있는
	# 기둥·투사체는 남는다) 해제된 객체를 take_hit에 넘기게 되어 타입 에러가 난다 — 그냥 무시한다.
	# 주인이 원래 없는 히트박스(지하철 열차 등)는 계속 정상 동작해야 하므로 _has_source로 구분한다
	if _has_source and not is_instance_valid(_source_fighter):
		return false
	if not (area is Hurtbox):
		return false
	if sense_only:
		# 피해 주는 길(`Hurtbox.take_hit`)을 아예 안 탄다 — 거기서 걸러 주던
		# **자기 자신·아군**을 여기서 직접 거른다. 방어·무적은 신호를 받는 쪽이 보고 판단한다
		if area.fighter == source_fighter:
			return false
		if area.immune_source != null and area.immune_source == source_fighter:
			return false
		connected.emit(area.fighter)
		return true
	var kb: Vector2 = _compute_knockback(area)
	# 이 한 방이 방어에 막히는지 먼저 판정해서 팝업·무기 깜빡임에 같이 쓴다
	var blocked: bool = _is_blocked_by_guard(area)
	# 카운터 히트인지 **맞히기 전에** 본다 — take_hit 안에서 맞은 쪽 공격이 끊기며 카운터 창이 닫힌다
	var counter: bool = not blocked and _is_counter_hit(area)
	if not area.take_hit(damage, kb, source_fighter, pop_override, get_attacker()):
		return false
	_counter_now = counter
	if blocked:
		_notify_blocked_by_guard()
	_apply_hitstop()
	if blocked:
		_spawn_guard_impact(area, kb)
	elif hit_spark:
		_spawn_spark(area.global_position, kb)
	if debris_scene != null and debris_enabled:
		_spawn_debris(area.global_position, kb)
	_shake_camera()
	var victim: Node = area.fighter
	if not blocked:
		# 피격 지점에 데미지 숫자(+콤보) 팝업
		var combo: int = 0
		if victim and victim.has_method("get_combo_count"):
			combo = victim.get_combo_count()
		_spawn_damage_number(area.global_position, damage, combo)
		_play_hit_sound()
	connected.emit(victim)
	# **확정 경직(평타 콤보가 connected에서 거는 것)까지 다 걸린 뒤에** 더한다 — 먼저 더하면 큰 쪽만 남아 사라진다
	if counter:
		_apply_counter_hit(victim)
	_counter_now = false
	return true

## 이 한 방이 카운터 히트인지 — 캐릭터의 공격이 **공격이 나오는 중**인 캐릭터를 때렸을 때만.
## 맵 기믹(주인 없음)·겹쳐 있는 동안 계속 때리는 판정(담배 연기 등)·소환물 몸은 카운터가 안 난다
func _is_counter_hit(hurtbox: Hurtbox) -> bool:
	if not _has_source or repeat_interval > 0.0:
		return false
	var victim = hurtbox.fighter
	return victim is Fighter and (victim as Fighter).is_counter_hittable()

## 카운터 히트 — 경직을 더하고 연출을 띄운다(데미지는 그대로, 2026-10-10 사용자 결정)
func _apply_counter_hit(victim: Node) -> void:
	if not (victim is Fighter) or not is_instance_valid(victim):
		return
	var target: Fighter = victim
	target.add_counter_stun()
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var fx: Node = scene_root.get_node_or_null(_COUNTER_HIT_FX.NODE_NAME)
	if fx == null:
		fx = _COUNTER_HIT_FX.new()
		scene_root.add_child(fx)
	var hitter: Node = get_attacker()
	fx.play(target, hitter as Node2D)

## 이 판정으로 실제로 때린 몸(캐릭터 또는 일진 패거리·고양이 같은 소환물). 순서:
## `attacker_body` → 부모를 거슬러 올라가 처음 만나는 **맞을 수 있는 몸**(take_damage가 있는 Node2D) → `source_fighter`.
## 맵에 붙은 투사체처럼 몸을 못 찾으면 주인 캐릭터가 된다
func get_attacker() -> Node:
	if attacker_body != null and is_instance_valid(attacker_body):
		return attacker_body
	var node: Node = get_parent()
	while node != null:
		if node is Node2D and node.has_method("take_damage"):
			return node
		node = node.get_parent()
	return source_fighter if _has_source and is_instance_valid(_source_fighter) else null

## 이 한 방이 상대 방어에 막히는지. **주인 없는 히트박스(맵 기믹)는 방어를 뚫으므로 false다** —
## Hurtbox.take_hit이 source_fighter가 null이면 ignore_guard로 넘기는 것과 같은 규칙이라야
## "BLOCK이 떴는데 HP가 깎였다" 같은 어긋남이 안 생긴다
func _is_blocked_by_guard(hurtbox: Hurtbox) -> bool:
	if not _has_source:
		return false
	# **타입을 안 붙인다** — Hurtbox의 부모가 Fighter가 아닐 수 있다(일진 패거리처럼 HP만 있는 몸).
	# `Fighter`로 받으면 그 순간 타입 에러가 나므로, 방어 여부는 프로퍼티가 있는지 보고 읽는다
	var victim = hurtbox.fighter
	if victim == null or not ("is_guarding" in victim):
		return false
	return victim.is_guarding

## 막혔을 때 때린 쪽에게 알린다 — 때린 손과 거기 든 무기가 잠깐 빨갛게 깜빡이고
## 그 동안 기본공격이 안 나간다. **기본공격이 막혔을 때만이라** 이 히트박스가
## 공격자의 basic_attack 소속인지 확인한다 (스킬 히트박스는 그냥 넘어간다)
func _notify_blocked_by_guard() -> void:
	if not is_instance_valid(_source_fighter):
		return
	if _source_fighter.basic_attack == null or get_parent() != _source_fighter.basic_attack:
		return
	_source_fighter.play_weapon_blocked()

## 명중 소리. 타이틀 뒤 구경 모드에선 배경음악을 덮지 않게 안 낸다
func _play_hit_sound() -> void:
	if hit_sound == null or GameState.game_mode == "attract":
		return
	_SFX.play(self, hit_sound, hit_sound_volume_db, hit_sound_pitch)

## 방어에 막힌 자리에서 `GuardImpact`(파란 초승달 고리 + 판 + 번개 + 속도선)를 터뜨린다.
## 예전엔 "BLOCK" 글자 + 작은 파란 불꽃이었다(2026-10-10 사용자 레퍼런스로 교체).
## 자리는 허트박스 중심이 아니라 **이 판정에 가장 가까운 허트박스 가장자리** — 막은 부위에서 터져야 한다.
## push_dir은 공격이 밀고 들어가는 방향(가로 부호만 쓴다). 비었으면 때린 쪽 → 맞은 쪽으로 정한다
func _spawn_guard_impact(hurtbox: Area2D, push_dir: Vector2 = Vector2.ZERO) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	if absf(push_dir.x) < 0.01:
		push_dir = Vector2(signf(hurtbox.global_position.x - global_position.x), 0.0)
	var fx: Node2D = _GUARD_IMPACT.new()
	scene_root.add_child(fx)
	fx.global_position = _contact_point(hurtbox)
	fx.setup(push_dir, float(damage) / SPARK_POWER_DAMAGE)

## 막힌 자리: 가로는 허트박스의 **때린 쪽 가장자리**, 세로는 이 판정(모양 중심) 높이를 몸 안으로 자른 값.
## 판정이 몸 안까지 파고들어 있어도 이펙트는 몸 앞면에서 터진다. 모양(네모·캡슐)을 못 읽으면 허트박스 중심
func _contact_point(hurtbox: Area2D) -> Vector2:
	var from: Vector2 = global_position
	for c in get_children():
		if c is CollisionShape2D:
			from = c.global_position
			break
	for c in hurtbox.get_children():
		if not (c is CollisionShape2D):
			continue
		var half := Vector2.ZERO
		if c.shape is RectangleShape2D:
			half = (c.shape as RectangleShape2D).size * 0.5
		elif c.shape is CapsuleShape2D:
			var cap := c.shape as CapsuleShape2D
			half = Vector2(cap.radius, cap.height * 0.5)
		else:
			continue
		half *= c.global_scale.abs()
		var mid: Vector2 = c.global_position
		var edge_x: float = mid.x + half.x * (1.0 if from.x > mid.x else -1.0)
		return Vector2(edge_x, clampf(from.y, mid.y - half.y, mid.y + half.y))
	return hurtbox.global_position

## 피격 지점에 데미지 숫자 팝업을 띄운다 (콤보 2 이상이면 "N HIT"도 함께)
func _spawn_damage_number(pos: Vector2, dmg: int, combo: int) -> void:
	# 타이틀 뒤 구경 모드엔 숫자·HIT·BLOCK 팝업을 안 띄운다(2026-09-28 사용자 요청)
	if GameState.game_mode == "attract":
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var popup: Node2D = load("res://combat/DamagePopup.tscn").instantiate()
	scene_root.add_child(popup)
	popup.global_position = pos
	popup.setup(dmg, combo)
	# 카운터면 흐림 판 위로 — 숫자까지 흐려지면 안 읽힌다
	if _counter_now:
		popup.z_index = _COUNTER_HIT_FX.FOCUS_Z + 1

## 명중 시 카메라를 데미지에 비례해 흔든다 (game_camera 그룹의 카메라를 찾아 trauma를 더한다)
func _shake_camera() -> void:
	if shake_per_damage <= 0.0:
		return
	var cam: Node = get_tree().get_first_node_in_group("game_camera")
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(float(damage) * shake_per_damage * shake_multiplier)

## 맞는 순간 화면 전체를 아주 잠깐 멈춘다(히트스톱). 데미지가 클수록 길게 멈춘다.
##
## **`repeat_interval`이 켜진 판정은 건너뛴다** — 열차·담배 연기처럼 겹쳐 있는 동안 계속 때리는 판정은
## 맞을 때마다 멈추면 화면이 끊기는 것처럼 보인다.
##
## 되돌리는 콜백이 **노드를 하나도 붙잡지 않으므로**(`Engine.time_scale`은 전역이다) 히트박스가 먼저
## 사라져도 "Lambda capture was freed" 함정에 걸리지 않고, 시간이 멈춘 채로 남지도 않는다
func _apply_hitstop() -> void:
	if hitstop_time <= 0.0 or repeat_interval > 0.0:
		return
	# 이미 느려져 있으면(연달아 맞았거나 KO 슬로모션 중) 겹쳐 걸지 않는다 —
	# 겹치면 나중 것이 먼저 풀리면서 KO 연출의 배속까지 1로 되돌려버린다
	if Engine.time_scale < 0.5:
		return
	var hold: float = minf(hitstop_time + float(damage) * hitstop_per_damage, hitstop_max) * hitstop_multiplier
	Engine.time_scale = HITSTOP_SCALE
	# **ignore_time_scale = true가 핵심이다** — 배속을 0에 가깝게 낮춰놔서 보통 타이머는 영영 안 끝난다.
	# process_always = true라 클래시·컷인처럼 트리가 멈춘 동안에도 제때 풀린다
	get_tree().create_timer(hold, true, false, true).timeout.connect(
		func() -> void:
			# **되돌리기 전에 아직 내가 멈춰둔 상태인지 확인한다** — 멈춰 있는 사이에 KO가 나면
			# Stage가 배속을 슬로모션(0.35)으로 바꿔놓는데, 그걸 모르고 1로 되돌리면 처치 연출이 그냥 빨라진다
			if Engine.time_scale <= HITSTOP_SCALE * 2.0:
				Engine.time_scale = 1.0)

## 판정을 껐다 켤 때(열차가 지나가고 다음 열차가 올 때) 반복 타격 쿨타임을 초기화한다
func clear_repeat_state() -> void:
	_repeat_cooldowns.clear()

func _compute_knockback(hurtbox: Hurtbox) -> Vector2:
	if not pull_to_source or source_fighter == null:
		return knockback
	var to_source: Vector2 = source_fighter.global_position - hurtbox.global_position
	if to_source.length() < 1.0:
		return Vector2.ZERO
	return to_source.normalized() * pull_strength

func _spawn_spark(pos: Vector2, launch_dir: Vector2 = Vector2.ZERO, blocked: bool = false) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var spark: Node2D
	if blunt_impact:
		spark = BluntImpact.new()
	else:
		spark = load("res://combat/HitSpark.tscn").instantiate()
	scene_root.add_child(spark)
	spark.global_position = pos
	# 맞은 방향으로 찢어지고, 데미지가 클수록 크게 튄다(데미지 7 = 세기 1)
	if spark.has_method("setup"):
		spark.setup(launch_dir, float(damage) / SPARK_POWER_DAMAGE, blocked)
	# 카운터면 흐림 판 위로(맞은 자리 불꽃까지 흐려지면 밋밋하다)
	if _counter_now:
		spark.z_index = _COUNTER_HIT_FX.FOCUS_Z + 1

## 명중 지점에 debris_scene을 스폰한다 (주정뱅이 술방울 등). 튀고 사라지는 처리는 스폰된 노드가 맡는다.
## 때린 방향과 술 스택은 스폰한 쪽만 아는 값이라, _ready가 도는 add_child **전에** 미리 넣어준다
func _spawn_debris(pos: Vector2, launch_dir: Vector2 = Vector2.ZERO) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var debris: Node = debris_scene.instantiate()
	if "burst_dir" in debris:
		debris.burst_dir = launch_dir
	# 술 스택이 많을수록 크게 튄다 — 스택이 눈에 안 보이는 값이라 연출로 드러내 준다
	if "burst_power" in debris and _has_source and is_instance_valid(_source_fighter):
		debris.burst_power = int(_source_fighter.custom_data.get("drink_stacks", 0))
	scene_root.add_child(debris)
	if debris.has_method("setup"):
		debris.setup(pos)
	elif debris is Node2D:
		debris.global_position = pos
