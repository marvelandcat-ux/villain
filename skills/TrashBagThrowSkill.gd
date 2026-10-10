class_name TrashBagThrowSkill
extends Skill

## 번화가 맵 스킬 — **쓰레기 줍기**(2026-10-09 사용자: "던지는 건 없애고 줍는 스킬로"). 예전엔 봉투 던지기였다(파일명·class_name은 참조 때문에 그대로).
## 누르면 몸 주변 `pickup_radius` 안의 바닥 쓰레기를 **전부** 빨아들인다. 닿기만 해서는 안 주워진다(`auto_pickup` 끔) — 그래야 스킬을 쓸 이유가 생긴다.
## 스택은 `fighter.custom_data["trash_stack"]`에 있고, 쓰레기 모으기 모드에선 이게 곧 점수다(Stage).
## 머리 위에 지금 스택을 뱃지로 띄운다

const STACK_KEY := "trash_stack"

## 최대 스택 — 꽉 차면 쓰레기를 줍지 않는다(쓰레기 모으기 모드는 Stage가 9999로 올린다)
@export var max_stack: int = 10
## 줍는 범위(캐릭터 중심에서 px)
@export var pickup_radius: float = 110.0
## 닿기만 해도 줍는지 — 끄면 이 스킬로만 줍는다(`TrashPickup._check_pickup`이 본다)
@export var auto_pickup: bool = false
## 줍는 동작(대충 — 몸을 한 번 눌렀다 편다) 동안 발이 묶이는 시간(초)
@export var pickup_motion_time: float = 0.25

@export_group("스택 표시")
## 캐릭터 원점 기준 표시 자리(머리 위)
@export var label_offset: Vector2 = Vector2(0, -92)
## 스택 1~10 뱃지 그림(`sprite/맵/번화가/쓰래기 아이콘/쓰래기 아이콘 N.png`, 1254 캔버스). 비어 있으면 예전처럼 숫자로 띄운다
@export var stack_icons: Array[Texture2D] = []
## **숫자 없는 뱃지**(`쓰래기 아이콘 픨.png`) — 넣으면 `stack_icons` 대신 이 그림 위에 **숫자를 코드로 쓴다**(2026-10-09 사용자:
## "그림을 여러 장 그리기 힘들어서"). 쓰레기 모으기 모드는 10개를 넘으므로 이걸 쓴다. 숫자 모양은 1~10 그림처럼 노란 굵은 글씨 + 검은 테두리
@export var blank_icon: Texture2D = null
## 숫자 자리(뱃지 가운데 기준, 뱃지 크기 비율) — 그림 1~10의 숫자가 왼쪽 가운데에 있다(원본 1250 캔버스 기준 숫자 중심 ≈ (460, 650))
@export var number_center: Vector2 = Vector2(-0.14, 0.03)
## 한 자리 숫자 글자 크기(뱃지 크기 비율). 두 자리·세 자리는 줄인다
@export var number_size: float = 0.5
@export var number_color: Color = Color(1.0, 0.96, 0.0)
@export var number_outline_color: Color = Color(0.04, 0.04, 0.04)
## 뱃지가 화면에서 차지할 크기(px, 긴 변)
@export var icon_px: float = 46.0
## 주울 때 뱃지가 **펌핑**(커졌다 되돌아옴)하는 배수와 시간(초)
@export var icon_pump_scale: float = 1.4
@export var icon_pump_time: float = 0.22
## 숫자로 띄울 때(뱃지 그림이 없을 때)
@export var label_font_size: int = 22
@export var label_color: Color = Color(1.0, 0.86, 0.2)
@export_group("")

var _label: Label
## 뱃지 묶음(그림 + 숫자) — 펌핑은 이 묶음의 scale을 1에서 키웠다 되돌린다
var _badge_root: Node2D
var _badge: Sprite2D
var _number: Label
var _pump_tween: Tween

const NUMBER_FONT := preload("res://fonts/Jua-Regular.ttf")

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
	_pump_badge()
	return true

## 쓰레기를 n개 뺀다(쓰레기 모으기 모드에서 죽을 때 떨어뜨리는 몫)
func remove_trash(n: int) -> void:
	var fighter := get_parent() as Fighter
	if fighter == null:
		return
	fighter.custom_data[STACK_KEY] = maxi(get_trash_stack() - n, 0)
	_refresh_label()

func _execute(fighter: Fighter) -> void:
	# 동작은 대충 — 몸을 한 번 눌렀다 펴고, 그동안 잠깐 멈춘다
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("play_squash"):
		visual.play_squash(Vector2(1.15, 0.8))   # 허리 굽혀 줍는 느낌
	fighter.velocity.x = 0.0
	fighter.apply_hitstun(pickup_motion_time)
	for piece in _pieces_in_range(fighter):
		if not piece.collect_by(fighter):
			break   # 꽉 찼다

## 범위 안에서 주울 수 있는 쓰레기 조각들
func _pieces_in_range(fighter: Fighter) -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("trash_pickups"):
		if node.has_method("can_collect") and node.can_collect() \
				and node.global_position.distance_to(fighter.global_position) <= pickup_radius:
			out.append(node)
	return out

## 줍는 동작을 스킬이 직접 보여 주므로 Fighter의 기본 스윙은 덧대지 않는다
func handles_own_visual() -> bool:
	return true

## AI: 범위 안에 쓰레기가 있으면 줍는다
func ai_wants_use(fighter: Fighter, _target: Node2D) -> bool:
	return get_trash_stack() < max_stack and not _pieces_in_range(fighter).is_empty()

# --- 머리 위 스택 표시 ---
## 뱃지 그림(`stack_icons`)이 있으면 스택 N번째 그림을 머리 위에 띄우고, 주울 때마다 펌핑한다(2026-10-08 사용자 요청).
## 그림이 없으면 예전 임시 숫자. 둘 다 `top_level`이라 회전 타격 때 캐릭터 루트 scale.x가 잠깐 줄어도 안 찌그러진다

func _make_label() -> void:
	if blank_icon != null or not stack_icons.is_empty():
		_badge_root = Node2D.new()
		_badge_root.name = "TrashStackBadge"
		_badge_root.top_level = true
		_badge_root.z_index = 20
		_badge_root.visible = false
		add_child(_badge_root)
		_badge = Sprite2D.new()
		_badge_root.add_child(_badge)
		if blank_icon != null:
			_number = Label.new()
			_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_number.size = Vector2(icon_px, icon_px)
			_number.position = number_center * icon_px - _number.size * 0.5
			var settings := LabelSettings.new()
			settings.font = NUMBER_FONT
			settings.font_color = number_color
			settings.outline_color = number_outline_color
			_number.label_settings = settings
			_badge_root.add_child(_number)
		return
	_label = Label.new()
	_label.name = "TrashStackLabel"
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

## 스택이 바뀌었을 때 — 그림을 스택 번호 것으로 갈고(넘치면 마지막 그림), 0이면 숨긴다
func _refresh_label() -> void:
	var stack: int = get_trash_stack()
	if _badge_root != null:
		_badge_root.visible = stack > 0
		if stack > 0:
			var tex: Texture2D = blank_icon if blank_icon != null \
				else stack_icons[clampi(stack, 1, stack_icons.size()) - 1]
			if tex != null and _badge.texture != tex:
				_badge.texture = tex
				var longest: float = maxf(tex.get_size().x, tex.get_size().y)
				_badge.scale = Vector2.ONE * icon_px / maxf(longest, 1.0)
			if _number != null:
				_set_number(stack)
	elif _label != null:
		_label.visible = stack > 0
		# 주아체에 × 글리프가 없어서 영문 x를 쓴다
		_label.text = "x%d" % stack
	_place_label()

## 주운 순간 뱃지가 커졌다 되돌아온다(펌핑). 연달아 주우면 처음부터 다시
func _pump_badge() -> void:
	if _badge_root == null or not _badge_root.visible:
		return
	if _pump_tween and _pump_tween.is_valid():
		_pump_tween.kill()
	_badge_root.scale = Vector2.ONE * icon_pump_scale
	_pump_tween = create_tween()
	_pump_tween.tween_property(_badge_root, "scale", Vector2.ONE, icon_pump_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 숫자 쓰기 — 자릿수가 늘면 글자를 줄여 뱃지 안에 들어가게 한다(두 자리부터는 숫자를 가운데로 조금 당긴다)
func _set_number(value: int) -> void:
	var text: String = str(value)
	_number.text = text
	var shrink: float = [1.0, 1.0, 0.72, 0.55][mini(text.length(), 3)]
	var font_px: int = maxi(int(round(icon_px * number_size * shrink)), 8)
	_number.label_settings.font_size = font_px
	_number.label_settings.outline_size = maxi(int(round(font_px * 0.28)), 2)
	var center: Vector2 = number_center * icon_px
	if text.length() >= 2:
		center.x *= 0.6
	_number.position = center - _number.size * 0.5

func _place_label() -> void:
	var fighter := get_parent() as Fighter
	if fighter == null:
		return
	if _badge_root != null and _badge_root.visible:
		_badge_root.global_position = fighter.global_position + label_offset
	elif _label != null and _label.visible:
		_label.global_position = fighter.global_position + label_offset - _label.size * 0.5
