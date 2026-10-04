class_name CatHouse
extends Node2D

## 고양이 집 — 고양이 아주머니 스킬1(`CatHouseSkill`)이 망치질로 짓는다. **원점 = 바닥 가운데**.
## 다 지으면(`finish_build`) 고양이 한 마리가 바로 나오고 그 뒤 `spawn_interval`마다 한 마리씩 나온다.
## 나오는 고양이는 **그 순간** 주인이 스킬2로 고른 종류(`custom_data["cat_kind"]`) — 지붕 간판도 그걸 따라 바뀐다.
## 맵 전체에 주인의 고양이가 `max_cats`마리면 그 차례는 건너뛴다.
##
## 상대가 때리면 부서진다 — Fighter가 아니지만 자식 Hurtbox(`fighter` = 이 집)로 맞는다(일진 패거리와 같은 방식).
## 그래서 `take_damage()`/`take_map_damage()`/`is_guarding`을 갖춘다. 다 짓기 전엔 판정이 없다.
## 다 지으면 몸통 크기의 StaticBody2D(기본 레이어 1 = 맵 벽·바닥과 같음)가 붙어 **상대를 벽처럼 막고**, 지붕 위엔 올라설 수 있다.
## 지은 사람과 이 집에서 나온 고양이는 그 몸을 통과한다(고양이는 안 그러면 집 안에서 태어나 끼인다).
## 그림은 임시로 `_draw()` — 네모난 몸통 + 네모난 지붕 판 + 문 구멍

const CAT_FOLLOWER := preload("res://skills/CatFollower.gd")
const HURTBOX_SCRIPT := preload("res://combat/Hurtbox.gd")

@export var max_hp: int = 40
@export var spawn_interval: float = 7.0
## 주인의 고양이가 맵에 이만큼 있으면 더 안 내보낸다
@export var max_cats: int = 4
## 집 크기(px) — 몸통 가로·세로, 지붕 판 두께·양옆으로 튀어나온 길이
@export var body_size: Vector2 = Vector2(56.0, 40.0)
@export var roof_thickness: float = 12.0
@export var roof_overhang: float = 7.0
@export var wall_color: Color = Color(0.86, 0.68, 0.45)
@export var roof_color: Color = Color(0.72, 0.25, 0.2)
@export var door_color: Color = Color(0.18, 0.12, 0.1)
@export var outline_color: Color = Color(0.15, 0.1, 0.08)

## 지붕 간판에 그려 둔 고양이 종류(CatFollower.Kind) — 주인이 바꾸면 따라 바꿔 다시 그린다
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
	z_index = -1

## 짓는 정도(0~1)를 정한다 — 아래부터 차오른다
func set_progress(t: float) -> void:
	_progress = clampf(t, 0.0, 1.0)
	queue_redraw()

## 다 지었다 — 판정을 붙이고 고양이를 하나 바로 내보낸 뒤 주기 생성을 시작한다
func finish_build() -> void:
	if _built:
		return
	_built = true
	cat_kind = _selected_kind()
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
	var h: float = body_size.y + roof_thickness
	rect.size = Vector2(body_size.x, h)
	shape.shape = rect
	shape.position = Vector2(0.0, -h * 0.5)
	hurtbox.add_child(shape)
	add_child(hurtbox)
	if _has_owner and is_instance_valid(owner_fighter):
		hurtbox.immune_source = owner_fighter

## 벽처럼 막는 몸 — 판정 상자와 같은 크기(지붕 판의 튀어나온 부분은 뺀다)
func _add_solid() -> void:
	_solid = StaticBody2D.new()
	_solid.name = "Solid"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var h: float = body_size.y + roof_thickness
	rect.size = Vector2(body_size.x, h)
	shape.shape = rect
	shape.position = Vector2(0.0, -h * 0.5)
	_solid.add_child(shape)
	add_child(_solid)
	# 지은 사람(고양이 아주머니)은 자기 집을 그냥 통과한다 — 예외는 양쪽에 다 건다
	if _has_owner and is_instance_valid(owner_fighter):
		owner_fighter.add_collision_exception_with(_solid)
		_solid.add_collision_exception_with(owner_fighter)

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
		burst.global_position = global_position + Vector2(0.0, -body_size.y * 0.5)
	queue_free()

func _spawn_cat() -> void:
	if not _has_owner or not is_instance_valid(owner_fighter) or _count_owner_cats() >= max_cats:
		return
	var parent: Node = get_parent()
	if parent == null:
		return
	cat_kind = _selected_kind()
	queue_redraw()
	var cat = CAT_FOLLOWER.new()
	cat.kind = cat_kind
	cat.owner_fighter = owner_fighter
	parent.add_child(cat)
	if is_instance_valid(_solid):
		cat.add_collision_exception_with(_solid)
	cat.global_position = global_position + Vector2(0.0, -2.0)

func _count_owner_cats() -> int:
	var n: int = 0
	for cat in get_tree().get_nodes_in_group("catmom_cats"):
		if is_instance_valid(cat) and not cat.is_queued_for_deletion() and cat.get("owner_fighter") == owner_fighter:
			n += 1
	return n

## 주인이 지금 고른 고양이 종류(스킬2) — 주인이 없으면 마지막으로 그린 종류
func _selected_kind() -> int:
	if not _has_owner or not is_instance_valid(owner_fighter):
		return cat_kind
	return int(owner_fighter.custom_data.get("cat_kind", 0))

func _process(delta: float) -> void:
	if _built and _selected_kind() != cat_kind:
		cat_kind = _selected_kind()
		queue_redraw()
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		queue_redraw()

func _draw() -> void:
	var w: float = body_size.x
	var h: float = body_size.y
	var total: float = h + roof_thickness
	# 짓는 중엔 아래부터 progress만큼만 보이고 반투명하다
	var shown: float = total * _progress
	if shown <= 0.5:
		return
	var alpha: float = 1.0 if _built else 0.75
	var tint := Color(1, 1, 1, alpha)
	if _flash > 0.0:
		tint = Color(1.0, 0.45, 0.45, alpha)
	var body_h: float = minf(shown, h)
	draw_rect(Rect2(-w * 0.5 - 1.5, -body_h - 1.5, w + 3.0, body_h + 1.5), outline_color * tint)
	draw_rect(Rect2(-w * 0.5, -body_h, w, body_h), wall_color * tint)
	# 판자 줄
	var y: float = -10.0
	while y > -body_h:
		draw_line(Vector2(-w * 0.5, y), Vector2(w * 0.5, y), (wall_color.darkened(0.25)) * tint, 1.0)
		y -= 10.0
	# 문 구멍(아치 대신 네모 + 위 반원)
	var door := Vector2(18.0, 22.0)
	var door_h: float = minf(door.y, body_h)
	draw_rect(Rect2(-door.x * 0.5, -door_h, door.x, door_h), door_color * tint)
	if body_h >= door.y + door.x * 0.5:
		draw_circle(Vector2(0.0, -door.y), door.x * 0.5, door_color * tint)
	# 지붕 판 — 몸통 위에 양옆으로 튀어나온 네모
	if shown > h:
		var roof_h: float = shown - h
		var rx: float = w * 0.5 + roof_overhang
		draw_rect(Rect2(-rx - 1.5, -h - roof_h - 1.5, rx * 2.0 + 3.0, roof_h + 3.0), outline_color * tint)
		draw_rect(Rect2(-rx, -h - roof_h, rx * 2.0, roof_h), roof_color * tint)
		# 다 지었으면 지붕 위에 작은 고양이 얼굴 간판
		if _built:
			CAT_FOLLOWER.draw_face(self, cat_kind, Vector2(0.0, -h - roof_thickness * 0.5), roof_thickness * 0.45)
