class_name CatHouse
extends Node2D

## 고양이 집 — 고양이 아주머니 스킬1(`CatHouseSkill`)이 망치질로 짓는다. **원점 = 바닥 가운데**.
## 다 지으면(`finish_build`) 고양이 한 마리가 바로 나오고 그 뒤 `spawn_interval`마다 한 마리씩 나온다.
## 나오는 고양이는 **집을 설치할 당시** 고른 종류로 고정이다(`CatHouseSkill`이 짓기 시작할 때 `cat_kind`를 넣어 준다) —
## 나중에 스킬2로 다른 고양이를 골라도 이 집은 안 바뀐다.
## 맵 전체에 주인의 고양이가 `max_cats`마리면 그 차례는 건너뛴다.
##
## 상대가 때리면 부서진다 — Fighter가 아니지만 자식 Hurtbox(`fighter` = 이 집)로 맞는다(일진 패거리와 같은 방식).
## 그래서 `take_damage()`/`take_map_damage()`/`is_guarding`을 갖춘다. 다 짓기 전엔 판정이 없다.
## 다 지으면 몸통 크기의 StaticBody2D(기본 레이어 1 = 맵 벽·바닥과 같음)가 붙어 **상대를 벽처럼 막고**, 지붕 위엔 올라설 수 있다.
## 지은 사람과 **모든 고양이**는 그 몸을 통과한다(고양이는 집 안에서 태어나고 집 사이를 오가다 끼기 쉽다 — 벽은 `cat_house_solids` 그룹).
## 그림은 `고양이집.png`(종이 박스)를 `_draw()`로 그린다 — 짓는 중엔 아래부터 잘라 보이고, 다 지으면 오른쪽 큰 면 가운데에 고양이 얼굴 간판

const CAT_FOLLOWER := preload("res://skills/CatFollower.gd")
const HURTBOX_SCRIPT := preload("res://combat/Hurtbox.gd")
const BOX_TEXTURE := preload("res://sprite/고양이 아줌마/고양이집.png")
## 박스 그림에서 잰 자리(그림 픽셀) — **그림을 바꾸면 다시 잴 것**
## 보이는 영역(지붕 처마 포함, 알파 1/4 이상)
const BOX_OPAQUE := Rect2(188, 79, 1186, 832)
## 막는 몸·피격 판정 — 벽 왼쪽 끝 ~ 오른쪽 끝, 지붕 꼭대기 ~ 바닥(처마는 뺀다)
const BOX_WALLS := Rect2(250, 85, 1080, 826)
## 오른쪽 큰 면(손잡이 구멍 있는 면)의 가운데 — 고양이 간판 자리
const BOX_FRONT_CENTER := Vector2(838, 615)

@export var max_hp: int = 40
@export var spawn_interval: float = 7.0
## 주인의 고양이가 맵에 이만큼 있으면 더 안 내보낸다
@export var max_cats: int = 4
## 박스 그림 전체 가로(px, 처마 포함) — 세로·판정은 그림 비율로 따라간다
@export var house_width: float = 70.0
## 고양이 얼굴 간판 반지름(px)
@export var icon_radius: float = 9.0
## 부서질 때 파편 색(종이 박스)
@export var wall_color: Color = Color(0.91, 0.72, 0.47)

## 이 집이 내보내는 고양이 종류(CatFollower.Kind) — 설치 당시 선택으로 고정, 지붕 간판도 이 종류
var cat_kind: int = 0
## 지은 사람 — 이 사람의 공격엔 안 맞는다. 해제 여부는 `_has_owner`로 따로 기억한다
var owner_fighter: Fighter = null:
	set(value):
		owner_fighter = value
		_has_owner = value != null
var current_hp: int = 0
## Hurtbox 쪽 방어 판정이 읽는다 — 집은 막지 않는다
var is_guarding: bool = false

var _has_owner: bool = false
## 0 = 터만 잡음, 1 = 다 지음
var _progress: float = 0.0
var _built: bool = false
var _flash: float = 0.0
var _solid: StaticBody2D = null

func _ready() -> void:
	current_hp = max_hp
	# AI가 부수러 오는 목표(cat_houses), 길을 막으면 뛰어넘는 방해물(ai_jump_over)
	add_to_group("cat_houses")
	# 소환물 분류: 건물 — 평타가 1타만 반복된다(`ComboMeleeAttack.SUMMON_BUILDING_GROUP`)
	add_to_group(&"summon_building")
	add_to_group("ai_jump_over")

## 짓는 정도(0~1)를 정한다 — 아래부터 차오른다
func set_progress(t: float) -> void:
	_progress = clampf(t, 0.0, 1.0)
	queue_redraw()

## 다 지었다 — 판정을 붙이고 고양이를 하나 바로 내보낸 뒤 주기 생성을 시작한다
func finish_build() -> void:
	if _built:
		return
	_built = true
	set_progress(1.0)
	_add_hurtbox()
	_add_solid()
	_spawn_cat()
	var timer := Timer.new()
	timer.wait_time = maxf(spawn_interval, 0.1)
	timer.timeout.connect(_spawn_cat)
	add_child(timer)
	timer.start()

func _add_hurtbox() -> void:
	var hurtbox = HURTBOX_SCRIPT.new()
	hurtbox.name = "Hurtbox"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var walls: Rect2 = _walls_local()
	rect.size = walls.size
	shape.shape = rect
	shape.position = walls.get_center()
	hurtbox.add_child(shape)
	add_child(hurtbox)
	if _has_owner and is_instance_valid(owner_fighter):
		hurtbox.immune_source = owner_fighter

## 벽처럼 막는 몸 — 판정 상자와 같은 크기(지붕 처마는 뺀다)
func _add_solid() -> void:
	_solid = StaticBody2D.new()
	_solid.name = "Solid"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var walls: Rect2 = _walls_local()
	rect.size = walls.size
	shape.shape = rect
	shape.position = walls.get_center()
	_solid.add_child(shape)
	# 고양이가 집 벽 그룹을 보고 예외를 걸 수 있게 — add_child 전에 넣어야 고양이 _ready가 못 놓친다
	_solid.add_to_group("cat_house_solids")
	add_child(_solid)
	# 지은 사람(고양이 아주머니)은 자기 집을 그냥 통과한다 — 예외는 양쪽에 다 건다
	if _has_owner and is_instance_valid(owner_fighter):
		owner_fighter.add_collision_exception_with(_solid)
		_solid.add_collision_exception_with(owner_fighter)
	# 고양이는 **어느 집에도** 안 막힌다 — 집 사이·새로 지은 집에 끼지 않게(먼저 나와 있던 고양이들에게 지금 건다.
	# 나중에 나오는 고양이는 자기 _ready에서 cat_house_solids 그룹을 보고 건다)
	for cat in get_tree().get_nodes_in_group("catmom_cats"):
		if cat is PhysicsBody2D and is_instance_valid(cat):
			cat.add_collision_exception_with(_solid)
			_solid.add_collision_exception_with(cat)

## 집이 사라지면 벽(_solid)도 같이 사라진다 — 걸어 둔 예외를 상대 쪽에서 지운다(안 지우면 AI 발판 찾기가 오류를 낸다)
func _exit_tree() -> void:
	if _solid == null or not is_instance_valid(_solid):
		return
	for group in ["fighters", "catmom_cats", "iljin_crew"]:
		for body in get_tree().get_nodes_in_group(group):
			if body is PhysicsBody2D and is_instance_valid(body):
				body.remove_collision_exception_with(_solid)

## 다 지어서 맞을 수 있는(부술 수 있는) 상태인지 — AI가 본다
func is_built() -> bool:
	return _built and current_hp > 0

## AI가 뛰어넘을 자리(바닥 가운데 조금 위) — 다 짓기 전엔 안 막으니 ai_blocks가 false
func ai_obstacle_position() -> Vector2:
	return global_position + Vector2(0.0, -10.0)

## 이 집이 f를 막는지 — 다 지은 집만, 지은 사람은 통과한다
func ai_blocks(f: Node) -> bool:
	return _built and not (_has_owner and f == owner_fighter)

func take_damage(amount: int, _knockback: Vector2 = Vector2.ZERO, _pop_override: float = -1.0, _ignore_guard: bool = false) -> void:
	if not _built or current_hp <= 0:
		return
	current_hp = maxi(current_hp - amount, 0)
	_flash = 0.12
	if current_hp <= 0:
		_break()

func take_map_damage(amount: int, knockback: Vector2 = Vector2.ZERO, pop_override: float = -1.0) -> void:
	take_damage(amount, knockback, pop_override, true)

## 짓다 만 집을 치운다(스킬이 끊겼을 때)
func cancel_build() -> void:
	if not _built:
		queue_free()

func _break() -> void:
	var parent: Node = get_parent()
	if parent:
		var burst := CrashBurst.new()
		burst.color = wall_color
		parent.add_child(burst)
		burst.global_position = global_position + _walls_local().get_center()
	queue_free()

func _spawn_cat() -> void:
	if not _has_owner or not is_instance_valid(owner_fighter) or _count_owner_cats() >= max_cats:
		return
	var parent: Node = get_parent()
	if parent == null:
		return
	var cat = CAT_FOLLOWER.new()
	cat.kind = cat_kind
	cat.owner_fighter = owner_fighter
	# 집 벽 예외는 고양이 _ready가 cat_house_solids 그룹으로 전부 건다
	parent.add_child(cat)
	cat.global_position = global_position + Vector2(0.0, -2.0)

func _count_owner_cats() -> int:
	var n: int = 0
	for cat in get_tree().get_nodes_in_group("catmom_cats"):
		if is_instance_valid(cat) and not cat.is_queued_for_deletion() and cat.get("owner_fighter") == owner_fighter:
			n += 1
	return n

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		queue_redraw()

## 그림 픽셀 좌표를 집 로컬 좌표로 — 보이는 영역의 가로 가운데·맨 아래가 원점(바닥 가운데)
func _box_to_local(p: Vector2) -> Vector2:
	var k: float = house_width / BOX_OPAQUE.size.x
	return Vector2((p.x - BOX_OPAQUE.get_center().x) * k, (p.y - BOX_OPAQUE.end.y) * k)

## 막는 몸·판정 상자(집 로컬)
func _walls_local() -> Rect2:
	var top_left: Vector2 = _box_to_local(BOX_WALLS.position)
	return Rect2(top_left, _box_to_local(BOX_WALLS.end) - top_left)

func _draw() -> void:
	# 짓는 중엔 아래부터 progress만큼만 보이고 반투명하다
	var shown_px: float = BOX_OPAQUE.size.y * _progress
	if shown_px <= 1.0:
		return
	var alpha: float = 1.0 if _built else 0.75
	var tint := Color(1, 1, 1, alpha)
	if _flash > 0.0:
		tint = Color(1.0, 0.45, 0.45, alpha)
	var src := Rect2(BOX_OPAQUE.position.x, BOX_OPAQUE.end.y - shown_px, BOX_OPAQUE.size.x, shown_px)
	var top_left: Vector2 = _box_to_local(src.position)
	draw_texture_rect_region(BOX_TEXTURE, Rect2(top_left, _box_to_local(src.end) - top_left), src, tint)
	# 다 지었으면 오른쪽 큰 면 가운데에 고양이 얼굴 간판
	if _built:
		CAT_FOLLOWER.draw_face(self, cat_kind, _box_to_local(BOX_FRONT_CENTER), icon_radius)
