class_name TrashBagThrowSkill
extends Skill

## 번화가 맵 스킬(2026-10-08) — 주운 쓰레기 스택을 **전부** 봉투에 담아 포물선으로 던진다.
## 스택이 많을수록 봉투가 커지고 피해·넉백도 커진다. 스택이 0이면 못 던진다(쿨도 안 돈다).
## 스택은 `fighter.custom_data["trash_stack"]`에 있고, 쓰레기 조각(`maps/TrashPickup.gd`)이 `add_trash()`로 더한다.
## 머리 위에 지금 스택을 띄운다 — **지금은 임시로 숫자**(사용자: 나중에 아이콘으로 바꿀 것)

const STACK_KEY := "trash_stack"
const BAG_SCENE := preload("res://skills/ThrownTrashBag.tscn")

## 최대 스택 — 꽉 차면 쓰레기를 줍지 않는다
@export var max_stack: int = 10
## 피해 = base_damage + damage_per_stack x 스택
@export var base_damage: int = 3
@export var damage_per_stack: int = 2
## 봉투 크기 = 1 + size_per_stack x (스택 - 1)
@export var size_per_stack: float = 0.15
## 넉백 = knockback_base + knockback_per_stack x 스택 (x는 던진 방향으로 뒤집힌다)
@export var knockback_base: Vector2 = Vector2(120, -60)
@export var knockback_per_stack: Vector2 = Vector2(30, -15)
## 던지는 가로 속도 / 처음 위로 뜨는 속도(px/s) / 봉투에 걸리는 중력(px/s²) — 포물선
@export var throw_speed: float = 760.0
@export var throw_lift: float = 300.0
@export var bag_gravity: float = 1000.0
## 아무것도 안 맞아도 이 시간(초) 뒤 사라진다
@export var bag_lifetime: float = 3.0
## 던지는 동작 길이(초) — 봉투는 `BodyRig.throw_release_ratio` 지점에서 손을 떠난다
@export var motion_duration: float = 0.4
## 던지는 동작이 없는 리그에서 쓸 예비동작 시간(초)
@export var fallback_windup: float = 0.14
## 손에 쥐여줄 봉투 그림·배율
@export var hand_bag_texture: Texture2D = preload("res://sprite/맵/번화가/쓰래기 봉투.png")
@export var hand_bag_scale: float = 0.022
## 봉투가 손을 떠나는 자리(캐릭터 원점 기준, x는 바라보는 쪽으로 뒤집힌다)
@export var hand_offset: Vector2 = Vector2(40, -28)

@export_group("스택 표시")
## 캐릭터 원점 기준 표시 자리(머리 위)
@export var label_offset: Vector2 = Vector2(0, -88)
@export var label_font_size: int = 22
@export var label_color: Color = Color(1.0, 0.86, 0.2)
@export_group("")

var _label: Label

func _ready() -> void:
	super()
	_make_label()

func _process(delta: float) -> void:
	super(delta)
	_place_label()

## 지금 스택
func get_trash_stack() -> int:
	var fighter := get_parent() as Fighter
	if fighter == null:
		return 0
	return int(fighter.custom_data.get(STACK_KEY, 0))

## 쓰레기를 n개 더한다. 꽉 차서 못 더하면 false(쓰레기는 바닥에 남는다)
func add_trash(n: int) -> bool:
	var fighter := get_parent() as Fighter
	if fighter == null:
		return false
	var stack: int = get_trash_stack()
	if stack >= max_stack:
		return false
	fighter.custom_data[STACK_KEY] = mini(stack + n, max_stack)
	_refresh_label()
	return true

func _execute(fighter: Fighter) -> void:
	var stack: int = get_trash_stack()
	if stack <= 0:
		# 담을 쓰레기가 없다 — 쿨만 날리지 않게 돌려준다
		cooldown_left = 0.0
		return
	fighter.custom_data[STACK_KEY] = 0
	_refresh_label()
	var visual: Node2D = fighter.get_node_or_null("Visual")
	var wait: float = fallback_windup
	var item_scale: float = hand_bag_scale * _size_for(stack)
	if visual and visual.has_method("play_throw_motion"):
		visual.play_throw_motion(motion_duration)
		wait = motion_duration * float(visual.throw_release_ratio)
		if visual.has_method("set_throw_item"):
			visual.set_throw_item(hand_bag_texture, item_scale)
	var direction: float = fighter.facing
	Timers.after(self, maxf(wait, 0.01), func() -> void:
		if not is_instance_valid(fighter):
			return
		if visual and is_instance_valid(visual) and visual.has_method("clear_throw_item"):
			visual.clear_throw_item()
		_throw(fighter, direction, stack))

func _throw(fighter: Fighter, direction: float, stack: int) -> void:
	var parent: Node = fighter.get_parent()
	if parent == null:
		return
	var bag = BAG_SCENE.instantiate()
	bag.fall_gravity = bag_gravity
	bag.lifetime = bag_lifetime
	parent.add_child(bag)
	bag.set_bag_size(_size_for(stack))
	bag.global_position = fighter.global_position + Vector2(hand_offset.x * direction, hand_offset.y)
	bag.launch(direction, throw_speed, throw_lift, fighter.compute_damage(base_damage + damage_per_stack * stack), fighter)
	# launch()가 돌 기준 넉백을 넣으므로 스택에 맞춰 덮어쓴다
	var kb: Vector2 = knockback_base + knockback_per_stack * stack
	bag.knockback = Vector2(kb.x * (1.0 if direction >= 0.0 else -1.0), kb.y)

func _size_for(stack: int) -> float:
	return 1.0 + size_per_stack * float(maxi(stack - 1, 0))

## 던지는 동작을 스킬이 직접 재생하므로 Fighter의 기본 스윙은 덧대지 않는다
func handles_own_visual() -> bool:
	return true

## AI: 3개 이상 모였고 상대가 앞쪽 비슷한 높이에 있으면 던진다
func ai_wants_use(fighter: Fighter, target: Node2D) -> bool:
	if get_trash_stack() < 3 or target == null or not is_instance_valid(target):
		return false
	var dx: float = target.global_position.x - fighter.global_position.x
	var dy: float = target.global_position.y - fighter.global_position.y
	return absf(dx) < 520.0 and absf(dy) < 140.0 and dx * fighter.facing > 0.0

# --- 머리 위 스택 표시(임시 숫자) ---

func _make_label() -> void:
	_label = Label.new()
	_label.name = "TrashStackLabel"
	# 회전 타격 때 캐릭터 루트 scale.x가 잠깐 줄어도 글자가 찌그러지지 않게 따로 논다
	_label.top_level = true
	_label.z_index = 20
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(80, 30)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var settings := LabelSettings.new()
	settings.font_size = label_font_size
	settings.font_color = label_color
	settings.outline_size = 6
	settings.outline_color = Color(0.08, 0.08, 0.1)
	_label.label_settings = settings
	_label.visible = false
	add_child(_label)

func _refresh_label() -> void:
	if _label == null:
		return
	var stack: int = get_trash_stack()
	_label.visible = stack > 0
	# 주아체에 × 글리프가 없어서 영문 x를 쓴다
	_label.text = "x%d" % stack
	_place_label()

func _place_label() -> void:
	if _label == null or not _label.visible:
		return
	var fighter := get_parent() as Fighter
	if fighter == null:
		return
	_label.global_position = fighter.global_position + label_offset - _label.size * 0.5
