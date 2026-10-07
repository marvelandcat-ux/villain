class_name CatUltimate
extends Skill

## 고양이 아주머니 궁극기(R) — 스킬2로 **지금 고른 고양이**(`custom_data["cat_kind"]`)에 따라 갈린다.
## - 검은 고양이: 고양이를 겨드랑이에 끼고 엉덩이를 앞으로 — 기본공격이 `black_shots`발짜리 똥 유탄(`CatPoopShell`, 범위 피해)이 된다. 다 쏘면 끝
## - 주황 고양이: 고양이 옷을 입는다(**라운드 끝까지**) — 스킬1·2·궁은 못 쓰고(이동·점프·방어·대시·평타·맵 스킬만),
##   기본공격 피해·공격 속도·대시 쿨이 좋아지고 받는 피해가 줄어든다. 스킬 봉인은 `custom_data["cat_suit"]`를 두 스킬이 본다.
##   평타는 주먹 잽(1타)·반대 손 잽(2타)·머리 잡아 등 뒤로 패대기(3타, `CatSuitCombo`를 평타 자식으로 붙인다).
##   그림은 머리·몸통·손·발을 통째로 `고양이 아줌마 합체/` 그림으로 갈아입는다(리그 `set_head_outfit`/`set_body_outfit`)
## - 흰 고양이: 그 자리에서 최대 체력의 `white_heal_ratio`(30%)만큼 회복
## 검은은 기본공격 자리를 `CatPoopShot`(발사 콜백만 있는 대체 평타)으로 잠깐 바꿔 끼우고 끝나면 되돌린다

const SHOT_SCRIPT := preload("res://skills/CatPoopShot.gd")
const SHELL_SCRIPT := preload("res://skills/CatPoopShell.gd")
const HELD_CAT_SCRIPT := preload("res://skills/CatHeldVisual.gd")
const SUIT_COMBO_SCRIPT := preload("res://skills/CatSuitCombo.gd")
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
## 기본공격 피해 배수
@export var orange_damage_mult: float = 1.5
## 받는 피해 배수(0.9 = 10% 덜 받음)
@export var orange_damage_taken: float = 0.9
## 기본공격·대시 쿨 배수(0.5 = 절반). 방어 쿨은 그대로(2026-10-05 사용자 요청)
@export var orange_cooldown_mult: float = 0.5

@export_group("주황 고양이 옷 그림")
## 머리 옆모습과 머리 돌리기 그림(측면1 -> 정면 순), 그림마다 머리 공 (중심 x, 중심 y, 지름) — 0번이 옆모습. 그림을 바꾸면 다시 잴 것
@export var suit_head_texture: Texture2D = preload("res://sprite/고양이 아줌마/고양이 아줌마 합체/고양이 아줌마 합체.png")
@export var suit_head_turn_textures: Array[Texture2D] = [
	preload("res://sprite/고양이 아줌마/고양이 아줌마 합체/고양이 아줌마 합체 측면 1.png"),
	preload("res://sprite/고양이 아줌마/고양이 아줌마 합체/고양이 아줌마 합체 측면 2.png"),
	preload("res://sprite/고양이 아줌마/고양이 아줌마 합체/고양이 아줌마 합체 측면 3.png")]
@export var suit_head_turn_anchors: Array[Vector3] = [Vector3(624, 669, 1043), Vector3(607, 672, 1021), Vector3(632, 664, 1072), Vector3(629, 654, 1073)]
@export var suit_head_turn_faces_left: Array[bool] = [false, false, false, false]
## 머리 공 지름이 평소 머리의 1.1배(사용자 요청으로 키움), 턱 끝 높이·가로 가운데는 평소와 같게 역산한 배율·자리
@export var suit_head_scale: Vector2 = Vector2(0.04899, 0.04899)
@export var suit_head_position: Vector2 = Vector2(-2.97, -37.04)
## 옷 입은 채 맞았을 때 얼굴 — 평소 옷 머리와 같은 캔버스·크기라 배율은 그대로, 자리만 보정
@export var suit_hurt_head_texture: Texture2D = preload("res://sprite/고양이 아줌마/고양이 아줌마 합체/고양이 아줌마 합 체피격.png")
@export var suit_hurt_head_offset: Vector2 = Vector2(0.8, 0.2)
## 몸통(정면)과 몸 돌리기 그림 — 배율·자리는 보이는 영역이 평소 몸통과 같게 역산
@export var suit_body_texture: Texture2D = preload("res://sprite/고양이 아줌마/고양이 아줌마 합체/고양이 아줌마 합체 몸.png")
@export var suit_body_turn_textures: Array[Texture2D] = [
	preload("res://sprite/고양이 아줌마/고양이 아줌마 합체/고양이 아줌마 몸 측면 2.png"),
	preload("res://sprite/고양이 아줌마/고양이 아줌마 합체/고양이 아줌마 합체 몸 측면 3.png")]
@export var suit_body_scale: Vector2 = Vector2(0.028248, 0.03693)
@export var suit_body_position: Vector2 = Vector2(-0.23, 1.15)
## 손·발 — 평소 손·발과 같은 캔버스라 그림만 바꾼다
@export var suit_hand_texture: Texture2D = preload("res://sprite/고양이 아줌마/고양이 아줌마 합체/고양이 아줌마 합체 손.png")
@export var suit_foot_texture: Texture2D = preload("res://sprite/고양이 아줌마/고양이 아줌마 합체/고양이 아줌맘 합체 발.png")

@export_group("흰 고양이 (회복)")
## 쓰는 순간 최대 체력의 이만큼을 회복한다
@export_range(0.0, 1.0, 0.05) var white_heal_ratio: float = 0.3

enum Mode { NONE, BLACK, ORANGE }

var _mode: Mode = Mode.NONE
var _fighter: Fighter = null
var _has_fighter: bool = false
var _shots_left: int = 0
var _saved_basic: Skill = null
var _shot = null
var _held = null
## 고양이 옷을 입기 전 머리·몸통·손발 그림 — 벗을 때 되돌린다
var _saved_head: Dictionary = {}
var _saved_body: Dictionary = {}
var _saved_limbs: Dictionary = {}
## 고양이 옷 평타 — 붙인 3타 장치와, 입기 전 리그 잽 설정·3타 날아가기 이펙트
var _suit_combo: Node = null
var _saved_unarmed_thrust: bool = false
var _saved_finisher_trail: bool = true

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
	# 주황(고양이 옷)은 라운드 끝까지 간다 — 시간을 세지 않는다

# --- 기본공격 바꿔 끼우기 (검은) ---

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
	_swap_basic(fighter, black_shot_interval, poop_range * 0.85, _fire_poop, held, held_cat_offset)

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
		_held.kick()
	_squash(fighter)
	if _shots_left <= 0:
		# 기본공격 처리(_fire_basic_attack)가 끝난 뒤에 원래 평타로 돌려놓는다
		call_deferred("_end_mode")

# --- 흰 고양이 ---

## 그 자리에서 최대 체력의 white_heal_ratio만큼 회복 — 모드 없이 바로 끝난다(쿨은 바로 돈다)
func _start_white(fighter: Fighter) -> void:
	fighter.heal(int(round(fighter.stats.max_hp * white_heal_ratio)))
	fighter.set_tint("cat_lick", Color(0.72, 1.0, 0.78), 0.5)
	_squash(fighter)

# --- 주황 고양이 ---

func _start_orange(fighter: Fighter) -> void:
	_mode = Mode.ORANGE
	fighter.custom_data["cat_suit"] = true
	fighter.set_modifier("basic_attack_damage_multiplier", MODIFIER_ID, orange_damage_mult)
	fighter.set_modifier("damage_taken_multiplier", MODIFIER_ID, orange_damage_taken)
	fighter.set_modifier("dash_cooldown_multiplier", MODIFIER_ID, orange_cooldown_mult)
	# 기본공격 쿨은 attack_speed_multiplier만큼 빨리 돈다 — 쿨 x0.5 = 속도 x2
	fighter.set_modifier("attack_speed_multiplier", MODIFIER_ID, 1.0 / maxf(orange_cooldown_mult, 0.05))
	_wear_suit(fighter)
	_attach_suit_combo(fighter)

func _end_orange_effects() -> void:
	if not _has_fighter or not is_instance_valid(_fighter):
		return
	_fighter.custom_data.erase("cat_suit")
	for property in ["basic_attack_damage_multiplier", "damage_taken_multiplier", "dash_cooldown_multiplier", "attack_speed_multiplier"]:
		_fighter.clear_modifier(property, MODIFIER_ID)
	_detach_suit_combo(_fighter)
	_take_off_suit(_fighter)

## 고양이 옷 평타로 바꾼다 — 1·2타는 리그 맨손 잽(양손 번갈아), 3타는 평타 자식으로 붙인 `CatSuitCombo`가
## 머리를 잡아 패대기친다. 3타가 날아가기 대신 잡기가 되므로 날아가는 이펙트는 끈다
func _attach_suit_combo(fighter: Fighter) -> void:
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual and "unarmed_thrust" in visual:
		_saved_unarmed_thrust = visual.unarmed_thrust
		visual.unarmed_thrust = true
	var basic: Node = fighter.basic_attack
	if basic == null or not is_instance_valid(basic):
		return
	if "finisher_trail" in basic:
		_saved_finisher_trail = basic.finisher_trail
		basic.finisher_trail = false
	_suit_combo = SUIT_COMBO_SCRIPT.new()
	basic.add_child(_suit_combo)

## 고양이 옷 평타를 원래대로
func _detach_suit_combo(fighter: Fighter) -> void:
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual and "unarmed_thrust" in visual:
		visual.unarmed_thrust = _saved_unarmed_thrust
	var basic: Node = fighter.basic_attack
	if basic != null and is_instance_valid(basic) and "finisher_trail" in basic:
		basic.finisher_trail = _saved_finisher_trail
	if _suit_combo != null and is_instance_valid(_suit_combo):
		_suit_combo.queue_free()
	_suit_combo = null

## 리그의 머리·몸통·손발 그림을 고양이 옷(합체 그림)으로 갈아입힌다
func _wear_suit(fighter: Fighter) -> void:
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual == null or not visual.has_method("set_head_outfit"):
		return
	_saved_head = visual.get_head_outfit()
	_saved_body = visual.get_body_outfit()
	visual.set_head_outfit({"texture": suit_head_texture, "scale": suit_head_scale, "position": suit_head_position,
		"turn": suit_head_turn_textures, "anchors": suit_head_turn_anchors,
		"faces_left": suit_head_turn_faces_left,
		"hurt": suit_hurt_head_texture, "hurt_scale": Vector2.ZERO, "hurt_offset": suit_hurt_head_offset})
	visual.set_body_outfit({"texture": suit_body_texture, "scale": suit_body_scale, "position": suit_body_position, "turn": suit_body_turn_textures})
	_saved_limbs = {}
	for part_name in ["HandL", "HandR", "FootL", "FootR"]:
		var part := visual.get_node_or_null(part_name) as Sprite2D
		if part:
			_saved_limbs[part_name] = part.texture
			part.texture = suit_hand_texture if part_name.begins_with("Hand") else suit_foot_texture

## 고양이 옷을 벗긴다 — 입기 전 그림으로 되돌린다
func _take_off_suit(fighter: Fighter) -> void:
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual == null or not visual.has_method("set_head_outfit"):
		return
	visual.set_head_outfit(_saved_head)
	visual.set_body_outfit(_saved_body)
	for part_name in _saved_limbs:
		var part := visual.get_node_or_null(part_name) as Sprite2D
		if part:
			part.texture = _saved_limbs[part_name]
	_saved_head = {}
	_saved_body = {}
	_saved_limbs = {}

# --- 공용 ---

## 지금 모드를 끝내고 모든 걸 되돌린다
func _end_mode() -> void:
	match _mode:
		Mode.BLACK:
			_restore_basic()
		Mode.ORANGE:
			_end_orange_effects()
	_mode = Mode.NONE

func _dir_of(fighter: Fighter) -> float:
	return signf(fighter.facing) if not is_zero_approx(fighter.facing) else 1.0

func _squash(fighter: Fighter) -> void:
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("play_squash"):
		visual.play_squash(Vector2(1.06, 0.94))

## 쓰는 중이면 남은 비율(검은 = 남은 탄, 주황 = 라운드 끝까지라 늘 가득) — 쿨 파이가 금색으로 그린다
func active_ratio() -> float:
	match _mode:
		Mode.BLACK:
			return float(_shots_left) / maxf(float(black_shots), 1.0)
		Mode.ORANGE:
			return 1.0
	return -1.0

func _exit_tree() -> void:
	_end_mode()
