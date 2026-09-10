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
## 명중 시 카메라를 흔드는 세기 = damage × 이 값 (0이면 안 흔든다). 데미지가 클수록 크게·오래 흔들린다
@export var shake_per_damage: float = 0.04
## 맞은 상대를 위로 띄우는 힘(px/s). 음수(기본)면 데미지 비례 기본 팝업, 0이면 안 띄운다(지상 유지).
## 콤보 앞 타격이 상대를 공중에 날려버려 다음 타가 헛치는 걸 막을 때 0으로 둔다
@export var pop_override: float = -1.0

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
## repeat_interval을 쓸 때, 겹쳐 있는 Hurtbox마다 다음 타격까지 남은 시간 {Hurtbox: float}
var _repeat_cooldowns: Dictionary = {}

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
## HazardPlatform과 같은 방식(대상별 쿨타임)이라 매 프레임 연속으로 맞지는 않는다
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
	var kb: Vector2 = _compute_knockback(area)
	# 이 한 방이 방어에 막히는지 먼저 판정해서 팝업·무기 깜빡임에 같이 쓴다
	var blocked: bool = _is_blocked_by_guard(area)
	if not area.take_hit(damage, kb, source_fighter, pop_override):
		return false
	if blocked:
		_notify_blocked_by_guard()
	_spawn_spark(area.global_position, kb)
	if debris_scene != null:
		_spawn_debris(area.global_position)
	_shake_camera()
	var victim: Node = area.fighter
	if blocked:
		# 막았으면 HP가 하나도 안 깎였으므로 숫자 대신 "BLOCK"을 띄운다
		_spawn_block_popup(area.global_position)
	else:
		# 피격 지점에 데미지 숫자(+콤보) 팝업
		var combo: int = 0
		if victim and victim.has_method("get_combo_count"):
			combo = victim.get_combo_count()
		_spawn_damage_number(area.global_position, damage, combo)
	connected.emit(victim)
	return true

## 이 한 방이 상대 방어에 막히는지. **주인 없는 히트박스(맵 기믹)는 방어를 뚫으므로 false다** —
## Hurtbox.take_hit이 source_fighter가 null이면 ignore_guard로 넘기는 것과 같은 규칙이라야
## "BLOCK이 떴는데 HP가 깎였다" 같은 어긋남이 안 생긴다
func _is_blocked_by_guard(hurtbox: Hurtbox) -> bool:
	if not _has_source:
		return false
	var victim: Fighter = hurtbox.fighter
	return victim != null and victim.is_guarding

## 막혔을 때 때린 쪽에게 알린다 — 때린 손과 거기 든 무기가 잠깐 빨갛게 깜빡이고
## 그 동안 기본공격이 안 나간다. **기본공격이 막혔을 때만이라** 이 히트박스가
## 공격자의 basic_attack 소속인지 확인한다 (스킬 히트박스는 그냥 넘어간다)
func _notify_blocked_by_guard() -> void:
	if not is_instance_valid(_source_fighter):
		return
	if _source_fighter.basic_attack == null or get_parent() != _source_fighter.basic_attack:
		return
	_source_fighter.play_weapon_blocked()

## 막은 지점에 "BLOCK" 팝업을 띄운다 (데미지 숫자와 같은 장면을 다른 모드로 쓴다)
func _spawn_block_popup(pos: Vector2) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var popup: Node2D = load("res://combat/DamagePopup.tscn").instantiate()
	scene_root.add_child(popup)
	popup.global_position = pos
	popup.setup_block()

## 피격 지점에 데미지 숫자 팝업을 띄운다 (콤보 2 이상이면 "N HIT"도 함께)
func _spawn_damage_number(pos: Vector2, dmg: int, combo: int) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var popup: Node2D = load("res://combat/DamagePopup.tscn").instantiate()
	scene_root.add_child(popup)
	popup.global_position = pos
	popup.setup(dmg, combo)

## 명중 시 카메라를 데미지에 비례해 흔든다 (game_camera 그룹의 카메라를 찾아 trauma를 더한다)
func _shake_camera() -> void:
	if shake_per_damage <= 0.0:
		return
	var cam: Node = get_tree().get_first_node_in_group("game_camera")
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(float(damage) * shake_per_damage)

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

func _spawn_spark(pos: Vector2, launch_dir: Vector2 = Vector2.ZERO) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var spark: Node2D = load("res://combat/HitSpark.tscn").instantiate()
	scene_root.add_child(spark)
	spark.global_position = pos
	# 넉백 방향이 주어지면 스파크가 그쪽으로 튀어나가게 한다
	if launch_dir != Vector2.ZERO and spark.has_method("launch"):
		spark.launch(launch_dir)

## 명중 지점에 debris_scene을 스폰한다 (유리 파편 등). 파편이 바닥까지 떨어지는 처리는 스폰된 노드가 맡는다
func _spawn_debris(pos: Vector2) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var debris: Node = debris_scene.instantiate()
	scene_root.add_child(debris)
	if debris.has_method("setup"):
		debris.setup(pos)
	elif debris is Node2D:
		debris.global_position = pos
