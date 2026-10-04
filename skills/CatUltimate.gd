class_name CatUltimate
extends Skill

## 고양이 아주머니 궁극기(R) — 스킬2로 **지금 고른 고양이**(`custom_data["cat_kind"]`)에 따라 갈린다.
## - 검은 고양이: 고양이를 겨드랑이에 끼고 엉덩이를 앞으로 — 기본공격이 `black_shots`발짜리 똥 유탄(`CatPoopShell`, 범위 피해)이 된다. 다 쏘면 끝
## - 주황 고양이: 고양이 옷을 입는다(`orange_duration`초) — 스킬1·2는 못 쓰고, 기본공격 피해·받는 피해·
##   기본공격/방어/대시 쿨이 좋아지고 입는 순간 체력 회복. 스킬 봉인은 `custom_data["cat_suit"]`를 두 스킬이 본다
## - 흰 고양이(임시): 흰 고양이를 가슴 앞에 들고 `white_duration`초 동안 기본공격이 빠른 할퀴기가 된다
## 검은·흰은 기본공격 자리를 `CatPoopShot`(발사 콜백만 있는 대체 평타)으로 잠깐 바꿔 끼우고 끝나면 되돌린다

const SHOT_SCRIPT := preload("res://skills/CatPoopShot.gd")
const SHELL_SCRIPT := preload("res://skills/CatPoopShell.gd")
const HELD_CAT_SCRIPT := preload("res://skills/CatHeldVisual.gd")
const HELD_WHITE_SCRIPT := preload("res://skills/CatHeldWhite.gd")
const HOOD_SCRIPT := preload("res://skills/CatSuitHood.gd")
const KIND_BLACK := 0
const KIND_ORANGE := 1
const KIND_WHITE := 2
const MODIFIER_ID := "cat_suit"

@export_group("검은 고양이 (똥 유탄)")
@export var black_shots: int = 5
## 발사 간격(초) — 기본공격 쿨로 쓴다
@export var black_shot_interval: float = 0.5
@export var poop_damage: int = 12
## 폭발 반지름(px)
@export var poop_radius: float = 140.0
## 평지에서 날아가는 거리(px)와 뜨는 속도(px/초) — 가로 속도는 둘로 역산한다
@export var poop_range: float = 350.0
@export var poop_lift: float = 420.0
## 맞은 쪽을 미는 힘(x는 날아가는 쪽으로)
@export var poop_knockback: Vector2 = Vector2(180.0, -160.0)
## 유탄이 나오는 자리(캐릭터 원점 기준, x는 바라보는 쪽) — 낀 고양이 엉덩이
@export var muzzle_offset: Vector2 = Vector2(36.0, 4.0)
## 낀 고양이 그림 자리(리그 로컬, +x = 바라보는 쪽)
@export var held_cat_offset: Vector2 = Vector2(12.0, 4.0)

@export_group("주황 고양이 (고양이 옷)")
@export var orange_duration: float = 10.0
## 기본공격 피해 배수
@export var orange_damage_mult: float = 1.5
## 입는 순간 회복량
@export var orange_heal: int = 30
## 받는 피해 배수(0.6 = 40% 덜 받음)
@export var orange_damage_taken: float = 0.6
## 기본공격·방어·대시 쿨 배수(0.5 = 절반)
@export var orange_cooldown_mult: float = 0.5
@export var orange_tint: Color = Color(1.0, 0.75, 0.35)

@export_group("흰 고양이 (할퀴기, 임시)")
@export var white_duration: float = 10.0
## 할퀴기 간격(초) — 기본공격 쿨로 쓴다
@export var scratch_interval: float = 0.25
@export var scratch_damage: int = 7
## 판정 상자 가운데가 캐릭터에서 앞으로 떨어진 거리(px)와 크기
@export var scratch_reach: float = 45.0
@export var scratch_size: Vector2 = Vector2(50.0, 44.0)
## 맞은 쪽을 미는 힘(x는 바라보는 쪽으로)
@export var scratch_knockback: Vector2 = Vector2(140.0, -60.0)
## 판정이 켜져 있는 시간(초)
@export var scratch_hit_time: float = 0.1
## 든 고양이 그림 자리(리그 로컬, +x = 바라보는 쪽)
@export var held_white_offset: Vector2 = Vector2(20.0, -2.0)

enum Mode { NONE, BLACK, ORANGE, WHITE }

var _mode: Mode = Mode.NONE
var _fighter: Fighter = null
var _has_fighter: bool = false
var _shots_left: int = 0
var _time_left: float = 0.0
var _saved_basic: Skill = null
var _shot = null
var _held = null
var _hood = null

func can_use() -> bool:
	return super() and _mode == Mode.NONE

func _kind_of(fighter: Fighter) -> int:
	return int(fighter.custom_data.get("cat_kind", 0))

func _execute(fighter: Fighter) -> void:
	_fighter = fighter
	_has_fighter = true
	match _kind_of(fighter):
		KIND_BLACK:
			_start_black(fighter)
		KIND_ORANGE:
			_start_orange(fighter)
		KIND_WHITE:
			_start_white(fighter)

func _process(delta: float) -> void:
	super._process(delta)
	if _mode == Mode.ORANGE or _mode == Mode.WHITE:
		_time_left -= delta
		if _time_left <= 0.0:
			_end_mode()

# --- 기본공격 바꿔 끼우기 (검은·흰 공용) ---

## 기본공격 자리에 interval 간격으로 on_fire를 부르는 대체 평타를 끼우고, 리그에 든 고양이 그림(held)을 붙인다
func _swap_basic(fighter: Fighter, interval: float, reach: float, on_fire: Callable, held: Node2D, held_offset: Vector2) -> void:
	_shot = SHOT_SCRIPT.new()
	_shot.name = "CatBasicOverride"
	_shot.cooldown = interval
	_shot.range = reach
	_shot.on_fire = on_fire
	add_child(_shot)
	_saved_basic = fighter.basic_attack
	fighter.basic_attack = _shot
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual:
		_held = held
		_held.position = held_offset
		visual.add_child(_held)
	else:
		held.free()

func _restore_basic() -> void:
	if _has_fighter and is_instance_valid(_fighter) and _fighter.basic_attack == _shot and _saved_basic != null:
		_fighter.basic_attack = _saved_basic
	_saved_basic = null
	if is_instance_valid(_shot):
		_shot.queue_free()
	_shot = null
	if is_instance_valid(_held):
		_held.queue_free()
	_held = null

# --- 검은 고양이 ---

func _start_black(fighter: Fighter) -> void:
	_mode = Mode.BLACK
	_shots_left = black_shots
	var held = HELD_CAT_SCRIPT.new()
	held.name = "HeldBlackCat"
	held.max_shots = black_shots
	_swap_basic(fighter, black_shot_interval, poop_range * 0.85, _fire_poop, held, held_cat_offset)
	if is_instance_valid(_held):
		_held.shots_left = black_shots

func _fire_poop(fighter: Fighter) -> void:
	if _mode != Mode.BLACK or _shots_left <= 0:
		return
	var map: Node = fighter.get_parent()
	if map:
		var dir: float = _dir_of(fighter)
		var g: float = 1200.0
		var shell = SHELL_SCRIPT.new()
		shell.gravity_force = g
		map.add_child(shell)
		shell.global_position = fighter.global_position + Vector2(muzzle_offset.x * dir, muzzle_offset.y)
		var air: float = 2.0 * poop_lift / g
		var vx: float = poop_range / maxf(air, 0.01)
		shell.setup(fighter, Vector2(vx * dir, -poop_lift), fighter.compute_damage(poop_damage), poop_radius, poop_knockback)
	_shots_left -= 1
	if is_instance_valid(_held):
		_held.shots_left = _shots_left
		_held.kick()
	_squash(fighter)
	if _shots_left <= 0:
		# 기본공격 처리(_fire_basic_attack)가 끝난 뒤에 원래 평타로 돌려놓는다
		call_deferred("_end_mode")

# --- 흰 고양이 (임시) ---

func _start_white(fighter: Fighter) -> void:
	_mode = Mode.WHITE
	_time_left = white_duration
	var held = HELD_WHITE_SCRIPT.new()
	held.name = "HeldWhiteCat"
	_swap_basic(fighter, scratch_interval, scratch_reach + scratch_size.x * 0.4, _scratch, held, held_white_offset)

## 앞쪽 상자에 잠깐 판정을 켠다(맵에 붙여서 그 자리에 남는다 — 캐릭터 자식이면 반전에 뒤집힌다)
func _scratch(fighter: Fighter) -> void:
	if _mode != Mode.WHITE:
		return
	var map: Node = fighter.get_parent()
	if map:
		var dir: float = _dir_of(fighter)
		var hitbox := Hitbox.new()
		hitbox.damage = fighter.compute_basic_damage(scratch_damage)
		hitbox.knockback = Vector2(scratch_knockback.x * dir, scratch_knockback.y)
		hitbox.pop_override = 0.0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = scratch_size
		shape.shape = rect
		hitbox.add_child(shape)
		hitbox.source_fighter = fighter
		map.add_child(hitbox)
		hitbox.global_position = fighter.global_position + Vector2(scratch_reach * dir, -5.0)
		Timers.self_destruct(hitbox, scratch_hit_time)
	if is_instance_valid(_held):
		_held.swipe()
	_squash(fighter)

# --- 주황 고양이 ---

func _start_orange(fighter: Fighter) -> void:
	_mode = Mode.ORANGE
	_time_left = orange_duration
	fighter.custom_data["cat_suit"] = true
	fighter.set_modifier("basic_attack_damage_multiplier", MODIFIER_ID, orange_damage_mult)
	fighter.set_modifier("damage_taken_multiplier", MODIFIER_ID, orange_damage_taken)
	fighter.set_modifier("guard_dash_cooldown_multiplier", MODIFIER_ID, orange_cooldown_mult)
	# 기본공격 쿨은 attack_speed_multiplier만큼 빨리 돈다 — 쿨 x0.5 = 속도 x2
	fighter.set_modifier("attack_speed_multiplier", MODIFIER_ID, 1.0 / maxf(orange_cooldown_mult, 0.05))
	fighter.heal(orange_heal)
	fighter.set_tint(MODIFIER_ID, orange_tint)
	var visual: Node = fighter.get_node_or_null("Visual")
	var head: Node2D = visual.get_node_or_null("Head") if visual else null
	if head:
		_hood = HOOD_SCRIPT.new()
		_hood.name = "CatSuitHood"
		_hood.scale = Vector2(1.0 / maxf(absf(head.scale.x), 0.0001), 1.0 / maxf(absf(head.scale.y), 0.0001))
		head.add_child(_hood)

func _end_orange_effects() -> void:
	if is_instance_valid(_hood):
		_hood.queue_free()
	_hood = null
	if not _has_fighter or not is_instance_valid(_fighter):
		return
	_fighter.custom_data.erase("cat_suit")
	for property in ["basic_attack_damage_multiplier", "damage_taken_multiplier", "guard_dash_cooldown_multiplier", "attack_speed_multiplier"]:
		_fighter.clear_modifier(property, MODIFIER_ID)
	_fighter.clear_tint(MODIFIER_ID)

# --- 공용 ---

## 지금 모드를 끝내고 모든 걸 되돌린다
func _end_mode() -> void:
	match _mode:
		Mode.BLACK, Mode.WHITE:
			_restore_basic()
		Mode.ORANGE:
			_end_orange_effects()
	_mode = Mode.NONE
	_time_left = 0.0

func _dir_of(fighter: Fighter) -> float:
	return signf(fighter.facing) if not is_zero_approx(fighter.facing) else 1.0

func _squash(fighter: Fighter) -> void:
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("play_squash"):
		visual.play_squash(Vector2(1.06, 0.94))

## 쓰는 중이면 남은 비율(검은 = 남은 탄, 주황·흰 = 남은 시간) — 쿨 파이가 금색으로 그린다
func active_ratio() -> float:
	match _mode:
		Mode.BLACK:
			return float(_shots_left) / maxf(float(black_shots), 1.0)
		Mode.ORANGE:
			return clampf(_time_left / maxf(orange_duration, 0.001), 0.0, 1.0)
		Mode.WHITE:
			return clampf(_time_left / maxf(white_duration, 0.001), 0.0, 1.0)
	return -1.0

func _exit_tree() -> void:
	_end_mode()
