class_name CatFollower
extends CharacterBody2D

## 고양이 집에서 나온 고양이 — 종류(`kind`)마다 행동이 다르다. **add_child 전에** `kind`를 넣을 것.
## - 검은: 빠름. 상대와 거리를 두고(가까우면 뒤로 물러남) 3초마다 돌진 공격(피해 3)
## - 주황: 보통. 밟은 바닥 끝에서 끝까지 계속 왕복하다가 상대 몸이 닿으면 바로 할퀴기(피해 5)
## - 흰: 느림. 주인(고양이 아주머니)에게 다가가 혀로 핥아 회복(5, 쿨 3초 — 핥기 범위 안일 때만)
## 그림은 `CatSprite`(파츠 조립) 자식.
##
## 충돌은 캐릭터와 같은 방식 — 레이어 1(바닥·벽을 밟음) + 캐릭터·다른 고양이·일진 패거리와는
## 양방향 `add_collision_exception_with`로 몸 충돌만 끈다(`Fighter._ignore_other_fighters`와 같은 꼴).
## **맞으면 체력이 깎인다** — 자식 Hurtbox(`fighter` = 이 고양이, 일진 패거리와 같은 방식)의 판정은 꼬리를 뺀
## 머리(원)·몸통(상자)·발 두 개(상자)로, `CatSprite`의 배치 값에서 계산해 바라보는 쪽에 맞춰 좌우를 뒤집는다.
## 부른 사람(고양이 아주머니)의 공격엔 안 맞는다(`immune_source`). 체력이 다 닳으면 터지며 사라진다

enum Kind { BLACK, ORANGE, WHITE }

const CAT_SPRITE := preload("res://skills/CatSprite.gd")
const HURTBOX_SCRIPT := preload("res://combat/Hurtbox.gd")

## 종류별 털 색 / 이름(머리 위 표시·디버그용)
const FUR_COLORS: Array[Color] = [Color(0.16, 0.16, 0.18), Color(0.95, 0.56, 0.2), Color(0.97, 0.97, 0.95)]
const KIND_NAMES: Array[String] = ["검은 고양이", "주황 고양이", "흰 고양이"]
const OUTLINE_COLOR := Color(0.1, 0.08, 0.08)

@export_group("검은 고양이 (돌진)")
@export var black_speed: float = 300.0
@export var black_damage: int = 3
@export var black_dash_cooldown: float = 3.0
## 돌진 전에 엉덩이를 뒤로 빼고 웅크리는 준비 시간(초)
@export var black_dash_windup: float = 0.5
## 돌진 속도(px/초)와 시간(초)
@export var black_dash_speed: float = 780.0
@export var black_dash_time: float = 0.22
## 돌진 잔상 간격(초)·사라지는 시간(초)
@export var black_trail_interval: float = 0.04
@export var black_trail_fade: float = 0.25
## 상대가 이 거리(px)보다 가까우면 물러나고, 이보다 멀면 다가간다 — 그 사이에선 노려보며 선다
@export var black_retreat_distance: float = 140.0
@export var black_approach_distance: float = 200.0
## 돌진을 시작하는 최대 거리(px)
@export var black_dash_range: float = 320.0
@export_group("주황 고양이 (할퀴기)")
@export var orange_speed: float = 200.0
@export var orange_damage: int = 5
@export var orange_attack_cooldown: float = 1.5
## 상대가 이 가로·세로(px) 안이면 몸이 닿았다고 보고 바로 할퀸다(발끼리 비교 — 캐릭터·고양이 몸 반지름 20씩 + 앞발)
@export var orange_touch_range: Vector2 = Vector2(50.0, 50.0)
## 앞발을 휘두르는 모션 시간(초)
@export var orange_swipe_time: float = 0.25
@export_group("흰 고양이 (핥기 회복)")
@export var white_speed: float = 140.0
@export var white_heal: int = 5
@export var white_lick_cooldown: float = 10.0
## 주인이 이 가로·세로(px) 안이면 핥는다 (발끼리 비교)
@export var white_lick_range: Vector2 = Vector2(50.0, 50.0)
@export_group("공통")
## 벽에 막혔을 때 뛰어넘으려는 점프 속도(px/초)
@export var hop_speed: float = 360.0
## 상대 발이 이만큼(px) 넘게 위에 있고 가로로 jump_reach_x 안이면 뛰어오른다 — 발판 위로 따라간다.
## 점프 힘·중력은 **플레이어와 똑같다**(`Fighter.jump_velocity`/`gravity`/`fall_gravity_multiplier`).
## **점프는 땅을 떠날 때마다 한 번뿐** — 2단 점프 없음, 벽 폴짝 넘기도 그 한 번에 포함
@export var jump_trigger_height: float = 40.0
@export var jump_reach_x: float = 170.0
## 착지 순간 몸이 납작해지는 정도 — 플레이어(1.33, 0.75)보다 약하게. 원점이 발바닥이라 발은 바닥에 붙은 채 눌린다
@export var land_squash: Vector2 = Vector2(1.15, 0.87)
## 찌그러짐이 원래 크기로 돌아오는 속도 (플레이어와 같은 값)
@export var squash_recover_speed: float = 2.5
## 한 번 뛰고/내려오고 다음까지 쉬는 시간(초) — 발판 끝에서 콩콩 반복하지 않게
@export var jump_cooldown: float = 0.4
## 땅에 이만큼(초) 붙어 있어야 다시 뛴다 — 공중에서 발판 끝을 스치는 순간 또 뛰어 2단 점프처럼 되지 않게
@export var jump_ground_time: float = 0.1
## 상대가 이만큼(px) 넘게 아래에 있으면 밟고 선 원웨이 발판을 잠깐 통과해 내려온다
@export var drop_trigger_height: float = 40.0
@export var drop_through_time: float = 0.35
## 처음 나올 때 커지는 시간(초)
@export var pop_time: float = 0.2
@export var max_hp: int = 20
## 넉백 있는 공격에 맞으면 이만큼(초) 따라가기를 멈추고 눈을 감은 채 밀려난다
@export var hurt_stun: float = 0.45
## 밀려나는 동안 가로 속도가 줄어드는 정도(px/초²)
@export var hurt_friction: float = 650.0
## 걷기 가속(px/초²) — 속도를 즉시 꺾지 않아야 움직임이 덜 뚝뚝 끊긴다
@export var walk_accel: float = 1500.0

var kind: int = Kind.BLACK
## 이 고양이를 부른 캐릭터 — 그 상대를 따라간다. 해제 여부는 `_has_owner`로 따로 기억한다
var owner_fighter: Fighter = null:
	set(value):
		owner_fighter = value
		_has_owner = value != null

var _has_owner: bool = false
var _facing: float = 1.0
## 종류별 걷는 속도 — _ready에서 kind로 정해진다
var _speed: float = 200.0
## 공격(돌진·할퀴기)/핥기 쿨 남은 시간
var _attack_cd: float = 0.0
## 검은 고양이 돌진 준비·돌진 남은 시간·방향
var _windup_left: float = 0.0
var _dash_left: float = 0.0
var _dash_dir: float = 1.0
## 주황 고양이 순찰 방향과 할퀴기 모션 남은 시간
var _patrol_dir: float = 1.0
var _swipe_left: float = 0.0
## 검은 고양이 잔상 타이머
var _trail_timer: float = 0.0
var _hitbox: Hitbox = null
var _walk_phase: float = 0.0
var _age: float = 0.0
var _sprite = null
var _jump_cd: float = 0.0
## 땅에 계속 붙어 있은 시간(초) — 떠 있으면 0
var _ground_time: float = 0.0
## 이번에 땅을 떠난 뒤 이미 뛰었는지 — 땅에 닿으면 풀린다. 벽에 닿을 때마다 폴짝 뛰어 벽을 타고 끝없이 올라가던 것을 막는다
var _jumped: bool = false
## 지난 프레임에 땅에 있었는지(착지 순간 감지) / 지금 찌그러진 정도(1,1 = 원래)
var _was_on_floor: bool = true
var _squash: Vector2 = Vector2.ONE
var current_hp: int = 0
## Hurtbox 쪽 방어 판정이 읽는다 — 고양이는 막지 않는다
var is_guarding: bool = false
var _stun_left: float = 0.0
var _flash_left: float = 0.0
var _dead: bool = false
## 잡혀 있는 동안(고양이 옷 3타) — 잡은 쪽이 자리를 직접 옮기므로 스스로는 움직이지도 공격하지도 않는다
var is_grabbed: bool = false
## Hurtbox 판정 모양들과 그 바라보는 쪽(+x) 기준 자리 — 방향이 바뀌면 x만 뒤집는다
var _hurt_shapes: Array[CollisionShape2D] = []
var _hurt_rest: Array[Vector2] = []

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	# 캐릭터·먼저 나온 고양이·일진 패거리·모든 고양이 집 벽과 몸으로 안 부딪치게 — 새로 나온 쪽(자신)이 양방향으로 건다
	for group in ["fighters", "catmom_cats", "iljin_crew", "cat_house_solids"]:
		for body in get_tree().get_nodes_in_group(group):
			if body is PhysicsBody2D and is_instance_valid(body):
				add_collision_exception_with(body)
				body.add_collision_exception_with(self)
	add_to_group("catmom_cats")
	# 소환물 분류: 생물체 — 평타가 캐릭터와 똑같이 들어가고, 고양이 옷 3타에 잡혀 내던져진다(`ComboMeleeAttack.SUMMON_CREATURE_GROUP`)
	add_to_group(&"summon_creature")
	# 캐릭터와 같은 층(z 0) — 소환물은 전부 캐릭터와 같은 층에 그린다(2026-10-04 확정)
	_sprite = CAT_SPRITE.new()
	_sprite.name = "Visual"
	_sprite.kind = kind
	add_child(_sprite)
	_build_body_collision()
	current_hp = max_hp
	_speed = [black_speed, orange_speed, white_speed][kind]
	_patrol_dir = 1.0 if randf() < 0.5 else -1.0
	if kind != Kind.WHITE:
		_hitbox = Hitbox.new()
		_hitbox.monitoring = false
		_hitbox.monitorable = false
		var hit_shape := CollisionShape2D.new()
		var hit_rect := RectangleShape2D.new()
		hit_rect.size = Vector2(34.0, 28.0)
		hit_shape.shape = hit_rect
		_hitbox.add_child(hit_shape)
		add_child(_hitbox)
	_build_hurtbox()
	_update_sprite()

## 공격 판정을 켠다 — 피해는 주인의 공격으로 계산돼 주인 버프를 따라간다. 주인이 사라졌으면 안 때린다
func _start_hit(damage: int, knockback: Vector2) -> void:
	if _hitbox == null or not _has_owner or not is_instance_valid(owner_fighter):
		return
	_hitbox.source_fighter = owner_fighter
	_hitbox.damage = owner_fighter.compute_damage(damage)
	_hitbox.knockback = knockback
	_hitbox.position = Vector2(_facing * 20.0, -16.0)
	_set_hitbox_active(true)

func _set_hitbox_active(on: bool) -> void:
	if _hitbox:
		# 맞는 중(충돌 신호 안)에도 불리므로 set_deferred로 바꾼다
		_hitbox.set_deferred("monitoring", on)
		_hitbox.set_deferred("monitorable", on)

## 몸 충돌 = 몸통 그림 크기(가로는 몸통 폭, 세로는 몸통 꼭대기부터 발바닥까지). 몸통이 가운데라 방향이 바뀌어도 그대로
func _build_body_collision() -> void:
	var k: float = _sprite.size_scale
	var body_box: Rect2 = CAT_SPRITE.bbox_of(kind, "body")
	var body_h: float = _sprite.body_width * body_box.size.y / body_box.size.x
	var top: float = (_sprite.body_center.y - body_h * 0.5) * k
	var rect := RectangleShape2D.new()
	rect.size = Vector2(_sprite.body_width * k, -top)
	var shape := CollisionShape2D.new()
	shape.shape = rect
	shape.position = Vector2(_sprite.body_center.x * k, top * 0.5)
	add_child(shape)

## 꼬리를 뺀 머리·몸통·발에 맞는 판정 — CatSprite의 배치 값(배율 1 기준)에 size_scale을 곱해 만든다
func _build_hurtbox() -> void:
	var hurtbox = HURTBOX_SCRIPT.new()
	hurtbox.name = "Hurtbox"
	var k: float = _sprite.size_scale
	var body_box: Rect2 = CAT_SPRITE.bbox_of(kind, "body")
	var body_size := Vector2(_sprite.body_width, _sprite.body_width * body_box.size.y / body_box.size.x) * k
	_add_hurt_rect(hurtbox, _sprite.body_center * k, body_size)
	var foot_box: Rect2 = CAT_SPRITE.bbox_of(kind, "foot")
	var paw_size := Vector2(_sprite.paw_width, _sprite.paw_width * foot_box.size.y / foot_box.size.x) * k
	_add_hurt_rect(hurtbox, _sprite.front_paw * k, paw_size)
	_add_hurt_rect(hurtbox, _sprite.back_paw * k, paw_size)
	var head_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _sprite.head_width * k * 0.45
	head_shape.shape = circle
	_add_hurt_shape(hurtbox, head_shape, _sprite.head_center * k)
	add_child(hurtbox)
	if _has_owner and is_instance_valid(owner_fighter):
		hurtbox.immune_source = owner_fighter

func _add_hurt_rect(hurtbox: Area2D, center: Vector2, size: Vector2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	_add_hurt_shape(hurtbox, shape, center)

func _add_hurt_shape(hurtbox: Area2D, shape: CollisionShape2D, rest: Vector2) -> void:
	shape.position = rest
	hurtbox.add_child(shape)
	_hurt_shapes.append(shape)
	_hurt_rest.append(rest)

func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, _pop_override: float = -1.0, _ignore_guard: bool = false) -> void:
	if _dead:
		return
	current_hp = maxi(current_hp - amount, 0)
	_flash_left = 0.12
	if knockback != Vector2.ZERO:
		velocity = Vector2(knockback.x, minf(knockback.y, -120.0))
		_stun_left = hurt_stun
		# 돌진(준비 포함) 중에 맞으면 끊긴다
		_dash_left = 0.0
		_windup_left = 0.0
		if _sprite:
			_sprite.pounce = 0.0
		_set_hitbox_active(false)
	if current_hp <= 0:
		_die()

func take_map_damage(amount: int, knockback: Vector2 = Vector2.ZERO, pop_override: float = -1.0) -> void:
	take_damage(amount, knockback, pop_override, true)

## 체력이 다 닳았다 — 바로 무리에서 빼야 집이 다음 고양이를 내보낼 수 있다(4마리 제한)
func _die() -> void:
	_dead = true
	remove_from_group("catmom_cats")
	var parent: Node = get_parent()
	if parent:
		var burst := CrashBurst.new()
		burst.color = FUR_COLORS[kind]
		burst.radius = 30.0
		parent.add_child(burst)
		burst.global_position = global_position + Vector2(0.0, -15.0)
	queue_free()

## 사라질 때 걸어 둔 몸 충돌 예외를 상대 쪽에서도 지운다 — 안 지우면 상대 목록에 사라진 몸이 남아
## `get_collision_exceptions()`(AI 발판 찾기)를 부를 때마다 "body is null" 오류가 난다
func _exit_tree() -> void:
	for group in ["fighters", "catmom_cats", "iljin_crew", "cat_house_solids"]:
		for body in get_tree().get_nodes_in_group(group):
			if body != self and body is PhysicsBody2D and is_instance_valid(body):
				body.remove_collision_exception_with(self)

func _physics_process(delta: float) -> void:
	_age +=minf(delta, 0.05)
	if is_grabbed:
		# 돌진·할퀴기 도중에 잡혔으면 끊는다 — 매달린 채 판정이 남아 있으면 안 된다
		velocity = Vector2.ZERO
		_dash_left = 0.0
		_windup_left = 0.0
		_swipe_left = 0.0
		_set_hitbox_active(false)
		return
	if not is_on_floor():
		# 플레이어와 같은 중력 — 떨어질 때만 fall_gravity_multiplier가 붙는다
		var g: float = Fighter.gravity
		if velocity.y > 0.0:
			g *= Fighter.fall_gravity_multiplier
		velocity.y += g * delta
	else:
		_jumped = false
	_update_squash(delta)
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
	if _stun_left > 0.0:
		# 맞고 밀려나는 중 — 따라가기를 멈추고 미끄러진다
		_stun_left = maxf(_stun_left - delta, 0.0)
		velocity.x = move_toward(velocity.x, 0.0, hurt_friction * delta)
		move_and_slide()
		_ground_time = 0.0
		_update_sprite()
		return
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	var want_x: float = 0.0
	match kind:
		Kind.BLACK:
			want_x = _tick_black(delta)
		Kind.ORANGE:
			want_x = _tick_orange(delta)
		Kind.WHITE:
			want_x = _tick_white()
	# 속도를 가속/감속으로 따라가게 — 방향을 바꿀 때 몸이 잠깐 미끄러져 덜 뚝뚝 끊긴다. 돌진만 즉발
	if _dash_left > 0.0:
		velocity.x = want_x
	else:
		velocity.x = move_toward(velocity.x, want_x, walk_accel * delta)
	_jump_cd = maxf(_jump_cd - delta, 0.0)
	# 점프는 땅에 제대로 서 있을 때 한 번만 — 공중 점프(2단 점프)는 없다
	if is_on_floor() and velocity.y >= 0.0 and _ground_time >= jump_ground_time:
		# 주황은 자기 발판을 안 떠나고, 돌진 중엔 안 뛴다
		var vertical: Fighter = _vertical_target()
		if vertical and _dash_left <= 0.0:
			_follow_vertically(vertical)
	elif not is_on_floor() and _dash_left <= 0.0:
		# 낮은 장애물만 폴짝 넘는다 — 맵 벽처럼 높은 벽 앞에서 콩콩대며 넘어가려 들지 않게. 이미 뛰었으면 안 뛴다
		if not _jumped and kind != Kind.ORANGE and want_x != 0.0 and is_on_wall() and velocity.y >= 0.0 and _can_hop_over():
			velocity.y = -hop_speed
			_jumped = true
	move_and_slide()
	_ground_time = _ground_time + delta if is_on_floor() and velocity.y >= 0.0 else 0.0
	# 공중에선 다리를 멈춘 채로 둔다. 다리 박자는 실제 속도에 비례 — 천천히 돌아설 땐 다리도 천천히
	if is_on_floor():
		_walk_phase = _walk_phase + delta * absf(velocity.x) * 0.07 if absf(velocity.x) > 10.0 else 0.0
	_update_sprite()

## 검은 고양이 — 상대와 거리를 두다가(가까우면 뒤로) 쿨마다 돌진해 들이받는다
func _tick_black(delta: float) -> float:
	# 준비(웅크림) — 제자리에서 엉덩이를 실룩이다가 시간이 다 되면 돌진으로 넘어간다
	if _windup_left > 0.0:
		_windup_left -= delta
		_facing = _dash_dir
		if _sprite:
			_sprite.pounce = minf(_sprite.pounce + delta * 7.0, 1.0)
		if _windup_left <= 0.0:
			if _sprite:
				_sprite.pounce = 0.0
			_dash_left = black_dash_time
			_trail_timer = 0.0
			_start_hit(black_damage, Vector2(_dash_dir * 220.0, -160.0))
		return 0.0
	if _dash_left > 0.0:
		_dash_left -= delta
		if _dash_left <= 0.0:
			_set_hitbox_active(false)
		_facing = _dash_dir
		_trail_timer -= delta
		if _trail_timer <= 0.0:
			_trail_timer = black_trail_interval
			_spawn_dash_ghost()
		return _dash_dir * black_dash_speed
	var foe: Fighter = _target()
	if foe == null:
		return 0.0
	var dx: float = foe.global_position.x - global_position.x
	var dist: float = absf(dx)
	if dist > 4.0:
		_facing = signf(dx)
	var level: bool = absf(foe.global_position.y + 30.0 - global_position.y) < 60.0
	if _attack_cd <= 0.0 and is_on_floor() and level and dist > 60.0 and dist < black_dash_range:
		_attack_cd = black_dash_cooldown
		_windup_left = black_dash_windup
		_dash_dir = signf(dx) if dx != 0.0 else _facing
		_facing = _dash_dir
		return 0.0
	if dist < black_retreat_distance:
		return -signf(dx) * _speed
	if dist > black_approach_distance:
		return signf(dx) * _speed
	return 0.0

## 주황 고양이 — 자기 발판 위를 왔다 갔다 하다가(끝·벽에서 되돌아옴) 상대가 닿을 거리면 할퀸다
func _tick_orange(delta: float) -> float:
	if _swipe_left > 0.0:
		_swipe_left = maxf(_swipe_left - delta, 0.0)
		if _sprite:
			_sprite.paw_reach = sin((1.0 - _swipe_left / maxf(orange_swipe_time, 0.01)) * PI)
	var foe: Fighter = _target()
	if foe and _attack_cd <= 0.0:
		var dx: float = foe.global_position.x - global_position.x
		var dy: float = absf(foe.global_position.y + 30.0 - global_position.y)
		if absf(dx) <= orange_touch_range.x and dy <= orange_touch_range.y:
			# 닿은 쪽(뒤에서 닿아도)으로 홱 돌아 할퀸다 — 걷기는 멈추지 않는다
			if dx != 0.0:
				_facing = signf(dx)
			_attack_cd = orange_attack_cooldown
			_swipe_left = orange_swipe_time
			_start_hit(orange_damage, Vector2(_facing * 180.0, -140.0))
			Timers.after(self, 0.12, func(): _set_hitbox_active(false))
			_spawn_claw_marks()
			return _patrol_dir * _speed
	# 밟은 바닥 끝(또는 벽)에서 끝까지 왔다 갔다 — 할퀴는 동안엔 돌아본 쪽을 그대로 본다
	if is_on_floor() and (is_on_wall() or not _floor_ahead()):
		_patrol_dir = -_patrol_dir
	if _swipe_left <= 0.0:
		_facing = _patrol_dir
	return _patrol_dir * _speed

## 주황 고양이 할퀴기 자국 — 앞발 앞에 비스듬한 세 줄을 그었다가 금방 지운다(맵에 붙임 — 고양이 반전에 안 뒤집히게)
func _spawn_claw_marks() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var marks := Node2D.new()
	parent.add_child(marks)
	marks.global_position = global_position + Vector2(_facing * 34.0, -26.0)
	marks.scale = Vector2(_facing, 1.0)
	for i in 3:
		var line := Line2D.new()
		line.width = 3.0
		line.default_color = Color(1.0, 0.95, 0.85)
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		var off: float = (i - 1) * 8.0
		line.points = PackedVector2Array([Vector2(-8.0 + off, -14.0), Vector2(off, 0.0), Vector2(6.0 + off, 14.0)])
		marks.add_child(line)
	marks.modulate = Color(1, 1, 1, 0.95)
	var tween := marks.create_tween()
	tween.tween_property(marks, "modulate:a", 0.0, 0.25).set_delay(0.08)
	tween.tween_callback(marks.queue_free)

## 검은 고양이 돌진 잔상 — 그림을 통째로 복제해 맵에 남기고 서서히 지운다.
## ⚠️ 복제본은 add_child 전에 **스크립트를 뗄 것** — 안 떼면 _ready가 파츠를 또 만들어 두 겹이 된다
func _spawn_dash_ghost() -> void:
	var parent: Node = get_parent()
	if parent == null or _sprite == null:
		return
	var ghost: Node2D = _sprite.duplicate()
	ghost.set_script(null)
	parent.add_child(ghost)
	ghost.global_position = _sprite.global_position
	ghost.scale = _sprite.scale
	ghost.z_index = -1
	ghost.modulate = Color(0.65, 0.7, 1.0, 0.45)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, black_trail_fade)
	tween.tween_callback(ghost.queue_free)

## 앞의 장애물이 폴짝 뛰어넘을 만큼 낮은지 — 머리 위 높이(-70px)에서 앞으로 쏴 봐서 비어 있으면 낮은 것
func _can_hop_over() -> bool:
	var from: Vector2 = global_position + Vector2(0.0, -70.0)
	return PhysicsQuery.raycast_ignoring_fighters(self, from, from + Vector2(_facing * 44.0, 0.0)).is_empty()

## 주황 고양이 순찰 — 걷는 방향 앞에 바닥이 있는지 (없으면 발판 끝이니 되돌아선다)
func _floor_ahead() -> bool:
	var from: Vector2 = global_position + Vector2(_patrol_dir * 26.0, -10.0)
	var ground_y: float = PhysicsQuery.ground_y_below(self, from, 50.0, 99999.0)
	return ground_y < global_position.y + 40.0

## 흰 고양이 — 주인에게 다가가 범위 안이면 혀로 핥아 회복시킨다
func _tick_white() -> float:
	if not _has_owner or not is_instance_valid(owner_fighter):
		return 0.0
	var dx: float = owner_fighter.global_position.x - global_position.x
	var dy: float = absf(owner_fighter.global_position.y + 30.0 - global_position.y)
	if absf(dx) > 4.0:
		_facing = signf(dx)
	if absf(dx) <= white_lick_range.x and dy <= white_lick_range.y:
		if _attack_cd <= 0.0 and owner_fighter.current_hp < owner_fighter.stats.max_hp:
			_attack_cd = white_lick_cooldown
			owner_fighter.heal(white_heal)
			# 핥아준 순간 주인이 잠깐 초록빛 — HealSkill과 같은 "회복했다" 신호. 고양이는 머리를 까딱인다
			owner_fighter.set_tint("cat_lick", Color(0.72, 1.0, 0.78), 0.35)
			if _sprite:
				_sprite.nod_left = 0.5
		return 0.0
	return signf(dx) * _speed

## 점프·발판 내려가기로 따라갈 대상 — 검은은 상대, 흰은 주인, 주황은 자기 발판을 안 떠난다
func _vertical_target() -> Fighter:
	match kind:
		Kind.BLACK:
			return _target()
		Kind.WHITE:
			return owner_fighter if _has_owner and is_instance_valid(owner_fighter) else null
	return null

## 상대가 위면 뛰어오르고, 아래면 밟고 선 원웨이 발판을 잠깐 통과해 내려온다.
## 높이는 발끼리 비교한다(캐릭터 원점은 몸 가운데라 발 = +30)
func _follow_vertically(target: Fighter) -> void:
	if _jump_cd > 0.0:
		return
	var dx: float = target.global_position.x - global_position.x
	var dy: float = target.global_position.y + 30.0 - global_position.y
	if dy < -jump_trigger_height and absf(dx) < jump_reach_x:
		velocity.y = Fighter.jump_velocity
		_jumped = true
		_jump_cd = jump_cooldown
	elif dy > drop_trigger_height:
		var platform: Node = _one_way_floor()
		if platform is PhysicsBody2D:
			add_collision_exception_with(platform)
			Timers.after(self, drop_through_time, func():
				if is_instance_valid(platform):
					remove_collision_exception_with(platform))
			_jump_cd = jump_cooldown

## 착지 순간 몸을 살짝 납작하게 눌렀다가 천천히 편다(플레이어 BodyRig와 같은 방식, 세기만 약하게)
func _update_squash(delta: float) -> void:
	var on_floor: bool = is_on_floor()
	if on_floor and not _was_on_floor:
		_squash = land_squash
	_was_on_floor = on_floor
	_squash = _squash.move_toward(Vector2.ONE, delta * squash_recover_speed)

## 지금 밟고 선 바닥이 원웨이 발판이면 그 바디, 아니면 null(맨바닥은 뚫고 떨어지면 안 된다)
func _one_way_floor() -> Node:
	for i in get_slide_collision_count():
		var col: KinematicCollision2D = get_slide_collision(i)
		if col.get_normal().y > -0.7:
			continue
		var shape_owner = col.get_collider_shape()
		if shape_owner is CollisionShape2D and shape_owner.one_way_collision:
			return col.get_collider()
		if shape_owner is CollisionPolygon2D and shape_owner.one_way_collision:
			return col.get_collider()
	return null

## 방향·처음 커지기·걷기 박자를 그림에 넘긴다
func _update_sprite() -> void:
	if _sprite == null:
		return
	var pop: float = clampf(_age / maxf(pop_time, 0.01), 0.0, 1.0)
	var s: float = 0.6 + 0.4 * pop
	_sprite.scale = Vector2(_facing * s * _squash.x, s * _squash.y)
	_sprite.walk_phase = _walk_phase
	_sprite.modulate = Color(1.0, 0.4, 0.4) if _flash_left > 0.0 else Color(1, 1, 1)
	# 맞고 밀려나는 동안 눈을 감는다
	_sprite.eyes_closed = _stun_left > 0.0
	for i in _hurt_shapes.size():
		_hurt_shapes[i].position = Vector2(_hurt_rest[i].x * _facing, _hurt_rest[i].y)

func _target() -> Fighter:
	if not _has_owner or not is_instance_valid(owner_fighter):
		return null
	var foe: Fighter = owner_fighter.find_opponent()
	return foe if is_instance_valid(foe) else null

## 고양이 얼굴(머리 그림) — 머리 위 선택 표시·집 간판이 같은 그림을 쓴다. center가 얼굴 가운데, r은 예전 원형 머리 반지름 기준(귀 포함 가로 = r x 2.6)
static func draw_face(ci: CanvasItem, cat_kind: int, center: Vector2, r: float) -> void:
	CAT_SPRITE.draw_head(ci, cat_kind, center, r * 2.6)

