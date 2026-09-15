class_name IljinCrewMember
extends StaticBody2D

## 일진 궁극기로 불려 나온 패거리 한 명 (친구 / 여자친구).
##
## **StaticBody2D라 몸으로 길을 막는다** — 일진도 상대도 통과하지 못한다.
## 맞으면 HP가 깎이고, 다 깎이면 스르륵 사라진다.
##
## **Fighter로 만들지 않은 이유:** Fighter의 `_ready()`는 자신을 "fighters" 그룹에 넣어서
## 카메라가 따라가고 AI가 상대로 착각하게 만들고, 그 위에 `_ignore_other_fighters()`가
## **캐릭터끼리의 몸 충돌을 꺼버려서 오히려 통과해 버린다**. 여기서 필요한 건 HP 있는 벽이라
## 별개 노드로 두는 쪽이 짧고 안전하다.

## 이만큼 맞으면 사라진다
@export var max_hp: int = 30
## 쓰러질 때 사라지는 데 걸리는 시간(초)
@export var fade_out: float = 0.35
## 맞았을 때 빨갛게 물드는 시간(초)
@export var flash_time: float = 0.12

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
## **x는 몸 반지름(20) + 침 반지름(9)보다 커야 한다** — 안쪽에서 나가면 자기 몸에 닿아 바로 사라진다
@export var mouth_offset: Vector2 = Vector2(34.0, -26.0)
## 침을 모으는 동안 / 뱉는 순간의 얼굴. 배율이 (0,0)이면 기본 머리 배율을 그대로 쓴다
@export var gather_face: Texture2D
@export var gather_face_scale: Vector2 = Vector2.ZERO
@export var spit_face: Texture2D
@export var spit_face_scale: Vector2 = Vector2.ZERO
## 뱉는 얼굴이 유지되는 시간(초)
@export var spit_face_time: float = 0.35

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

func _ready() -> void:
	current_hp = max_hp
	# 자기가 뱉은 침이 앞에 선 동료 몸에 막히지 않게 — `Spit`이 이 그룹을 보고 통과시킨다
	add_to_group("iljin_crew")
	_spit_left = spit_first_delay

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
	if _dying:
		return
	# 부른 사람이 시그널도 없이 사라졌으면(훈련장에서 캐릭터 교체 등) 남아 있을 이유가 없다
	if _had_owner and not is_instance_valid(_owner_fighter):
		_fall()
		return
	# **매 프레임 상대를 따라본다** — 상대가 반대편으로 돌아가도 등을 보인 채 엉뚱한 데 뱉지 않는다
	if face_opponent:
		_track_opponent()
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
	# **setup 다음에 부를 것** — setup이 rotation을 수평으로 덮어쓴다
	if spit.has_method("aim"):
		spit.aim(_aim)

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

## 바라보는 쪽으로 뒤집은 입 위치 (몸 원점 기준)
func _mouth_offset() -> Vector2:
	return Vector2(mouth_offset.x * _facing(), mouth_offset.y)

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

## Hurtbox가 넘겨주는 피해. **넉백은 안 받는다** — 그 자리에 버티고 선 몸이라 밀려나면 길막이 풀린다
func take_damage(amount: int, _knockback: Vector2 = Vector2.ZERO, _pop_override: float = -1.0, _ignore_guard: bool = false) -> void:
	if _dying:
		return
	current_hp = maxi(current_hp - amount, 0)
	_flash()
	_play_hurt_face()
	_update_hp_face()
	if current_hp <= 0:
		_fall()

## 맞은 순간 잠깐 아파하는 얼굴로 (캐릭터의 `Fighter._play_hurt_face()`와 같은 방식).
## 그 표정 그림이 없는 몸(여자친구)은 리그가 알아서 그냥 넘어간다
func _play_hurt_face() -> void:
	if _visual and _visual.has_method("play_hurt_face"):
		_visual.play_hurt_face()

## 남은 HP 비율을 몸에 알려준다 — 얼마 안 남으면 지친 얼굴로 바뀐다(`BodyRig.weary_hp_ratio` 0.3 이하).
## HP 30이면 9 이하에서 바뀐다. 회복이 없으므로 맞을 때만 갱신하면 된다
func _update_hp_face() -> void:
	if _visual and _visual.has_method("update_hp_ratio"):
		_visual.update_hp_ratio(float(current_hp) / float(maxi(max_hp, 1)))

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
