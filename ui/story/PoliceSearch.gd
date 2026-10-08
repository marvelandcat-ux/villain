@tool
class_name PoliceSearch
extends Node2D

## **쓰레기장을 뒤지는 경찰** — 한 장짜리 일러를 레이어로 쪼개서 숨만 쉬게 만든 컷신 (2026-10-08 사용자 자료).
##
## 레이어는 전부 **같은 1672x941 캔버스로 뽑혀 있다**. 그래서 제자리(0,0)에 겹쳐 놓기만 하면
## 원본 그림이 그대로 복원된다 — 자리를 맞출 필요가 없다.
##
## 배경은 psd 안의 `_0004_Layer-0`이 **아니라** `경찰없는배경.png`를 쓴다(사용자 지시).
##
## 움직임은 셋뿐이다:
##  - **몸통** — 숨쉬기. 허리를 중심으로 아주 조금 커졌다 작아진다
##  - **팔** — 어깨를 중심으로 도는 것이라, 손전등 끝이 **반원을 그리며** 움직인다
##  - **얼굴** — 좌우로 뒤집으며 두리번거린다. 뒤집을 때 가로로 납작해졌다 펴져서 "고개를 돌린다"로 읽힌다
##
## 다리는 안 움직인다(전신을 맞추려고 가져온 레이어다).
##
## ⚠️ **머리·팔은 몸통의 자식이다.** 따로 두면 숨 쉴 때 몸만 올라가고 머리가 제자리에 남아 목이 늘어난다.
##
## 회전 중심(`*_pivot`)은 전부 **원본 그림 좌표(px)**다. 인스펙터에서 끌어 맞추면 에디터에서 바로 보인다.

## 그림 원본 크기(px) — 레이어가 전부 이 캔버스로 뽑혀 있다
const CANVAS := Vector2(1672.0, 941.0)

## 켜면 화면을 **꽉 채우도록** 통째로 키운다(남는 쪽은 잘린다). 끄면 씬에 적힌 scale 그대로
@export var fit_to_screen: bool = true

@export_group("회전 중심")
## 숨쉬기의 중심 — **허리**. 여기를 붙잡고 가슴이 부푼다
@export var body_pivot: Vector2 = Vector2(1075.0, 769.0):
	set(value):
		body_pivot = value
		_apply_pivots()
## 팔이 도는 중심 — **어깨**
@export var arm_pivot: Vector2 = Vector2(812.0, 366.0):
	set(value):
		arm_pivot = value
		_apply_pivots()
## 고개가 도는 중심 — **목**
@export var face_pivot: Vector2 = Vector2(1126.0, 214.0):
	set(value):
		face_pivot = value
		_apply_pivots()

@export_group("숨쉬기")
## 한 번 들이쉬고 내쉬는 데 걸리는 시간(초)
@export var breath_period: float = 3.6
## 몸통이 늘어나는 비율. 0.01이면 1%다 — **이 이상 주면 숨이 아니라 펌프질로 보인다**
@export var breath_amount: float = 0.011
## 숨 쉴 때 몸이 같이 오르내리는 거리(px)
@export var breath_lift: float = 2.5

@export_group("팔")
## 팔이 한 번 갔다 오는 데 걸리는 시간(초)
@export var arm_period: float = 5.2
## 어깨에서 도는 각도(도). 손전등이 그리는 반원의 크기다
@export var arm_swing: float = 2.6
## 숨쉬기와 **박자를 어긋내는 양**(0~1). 둘이 딱 맞으면 기계처럼 보인다
@export_range(0.0, 1.0, 0.05) var arm_offbeat: float = 0.35

@export_group("두리번")
## **고개를 좌우로 돌릴지.** 끄면 처음 보던 쪽 그대로 가만히 있는다
## (2026-10-08 사용자 — 18~19화는 "손전등 들고 뒤지다가 딱! 하고 알아챈다" 한 흐름이라 두리번이 방해였다)
@export var look_around: bool = true:
	set(value):
		look_around = value
		if not value:
			_apply_face(1.0, 1.0)
## 한쪽을 보고 있는 시간(초)
@export var look_hold: float = 2.4
## 고개를 돌리는 데 걸리는 시간(초). **0이면 한 번에 툭 바뀐다**(2026-10-08 사용자 —
## 가로로 눌렸다 펴지는 게 "머리가 빙글 돈다"로 보였다). 0보다 크면 그 시간 동안 눌렸다 펴진다
@export var look_turn: float = 0.0
## 돌아간 쪽에서 고개가 갸웃하는 각도(도)
@export var look_tilt: float = 2.0:
	set(value):
		look_tilt = value
		_apply_face(_face_side, 1.0)
## **고개를 돌렸을 때 얼굴이 옮겨 앉는 자리**(px). 좌우로 뒤집기만 하면 목이 안 맞아서 따로 민다.
## 아래 `preview_turned`를 켜 두고 이 값을 끌면 에디터에서 바로 맞출 수 있다
@export var look_offset: Vector2 = Vector2(6.0, 0.0):
	set(value):
		look_offset = value
		_apply_face(_face_side, 1.0)
## **에디터에서 돌아간 얼굴을 세워 두는 스위치** — 켜 놓고 `look_offset`·`look_tilt`를 맞춘다.
## 게임에는 아무 영향이 없다(돌아가는 건 시간이 정한다)
@export var preview_turned: bool = false:
	set(value):
		preview_turned = value
		_apply_face(-1.0 if value else 1.0, 1.0)
## 돌아가는 중에 얼굴이 가장 납작해지는 정도(0이면 완전히 0폭까지 눌린다).
## **`look_turn`이 0이면 안 쓴다**
@export_range(0.0, 1.0, 0.05) var look_squash: float = 0.0

@export_group("수상한 쓰레기봉지")
## 봉지가 주기적으로 **크게 움찔**한다 — 안에 뭔가 있다는 신호다(2026-10-08 사용자)
@export var bag_twitch: bool = true
## 봉지가 흔들리는 **중심**(원본 좌표 px). 바닥에 닿는 부분을 잡아야 자연스럽다
@export var bag_pivot: Vector2 = Vector2(430.0, 900.0):
	set(value):
		bag_pivot = value
		_apply_pivots()
## 몇 초마다 한 번 움찔하는지
@export var bag_every: float = 2.8
## 한 번 움찔하는 데 걸리는 시간(초)
@export var bag_time: float = 0.45
## 그 사이에 좌우로 몇 번 흔들리는지
@export var bag_shakes: float = 2.5
## 흔들리는 각도(도)
@export var bag_angle: float = 4.0
## 같이 들썩이는 높이(px)
@export var bag_lift: float = 18.0
## 눌렸다 펴지는 정도(0.05면 5%)
@export_range(0.0, 0.3, 0.01) var bag_squash: float = 0.05

@export_group("휙 트레일")
## 고개가 바뀌는 순간 **머리가 지나온 쪽으로 뻗는 속도선**. 툭 바뀌기만 하면 심심해서 넣었다
@export var trail_enabled: bool = true
## 선 개수
@export var trail_count: int = 5
## 한 번 그어진 선이 사라지는 데 걸리는 시간(초)
@export var trail_time: float = 0.26
## 머리 가운데에서 선이 시작하는 거리(px) — 머리에 가리지 않게 머리 반지름보다 크게
@export var trail_radius: float = 92.0
## 선 길이(px)
@export var trail_length: float = 150.0
## 선끼리 위아래로 벌어지는 폭(px)
@export var trail_spread: float = 62.0
## 가장 굵은 선의 굵기(px)
@export var trail_width: float = 9.0
@export var trail_color: Color = Color(1.0, 0.98, 0.9, 0.8)
## **머리 그림의 한가운데**(원본 좌표 px). 선이 이 점을 중심으로 뻗는다
@export var head_center: Vector2 = Vector2(1133.0, 121.0)

@onready var _bag: Node2D = $BagPivot
@onready var _bag_sprite: Sprite2D = $BagPivot/Bag
@onready var _body: Node2D = $BodyPivot
@onready var _body_sprite: Sprite2D = $BodyPivot/Body
@onready var _arm: Node2D = $BodyPivot/ArmPivot
@onready var _arm_sprite: Sprite2D = $BodyPivot/ArmPivot/Arm
@onready var _face: Node2D = $BodyPivot/FacePivot
@onready var _face_sprite: Sprite2D = $BodyPivot/FacePivot/Face

## 고개가 휙 돌 때 긋는 속도선. 씬에 저장할 게 아니라 켤 때 만든다(`owner`를 안 줘서 파일에 안 남는다)
class Swish:
	extends Node2D
	var _from := Vector2.ZERO
	var _to := Vector2.ZERO
	var _age: float = 999.0
	var _life: float = 0.26
	var _count: int = 5
	var _radius: float = 92.0
	var _length: float = 150.0
	var _spread: float = 62.0
	var _width: float = 9.0
	var _color := Color.WHITE

	func flash(from: Vector2, to: Vector2, count: int, life: float, radius: float,
			length: float, spread: float, width: float, color: Color) -> void:
		_from = from
		_to = to
		_count = maxi(count, 1)
		_life = maxf(life, 0.01)
		_radius = radius
		_length = length
		_spread = spread
		_width = width
		_color = color
		_age = 0.0
		queue_redraw()

	func _process(delta: float) -> void:
		if _age >= _life:
			return
		_age += delta
		queue_redraw()

	func _draw() -> void:
		if _age >= _life:
			return
		var fade: float = 1.0 - _age / _life
		# 머리가 간 방향. 거의 가로로만 움직이니 길이가 0에 가까워도 축은 살아 있어야 한다
		var dir: Vector2 = _to - _from
		var n: Vector2 = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
		var perp := Vector2(-n.y, n.x)
		for i in _count:
			# -1 ~ 1 — 가운데 선이 제일 길고 굵다
			var s: float = (float(i) / maxf(_count - 1, 1) - 0.5) * 2.0
			var taper: float = 1.0 - absf(s) * 0.55
			var off: Vector2 = perp * (s * _spread)
			# **온 쪽으로** 뻗는다. 머리에 안 가리게 반지름만큼 떨어뜨려 시작한다
			var head: Vector2 = _from + off - n * _radius
			var tail: Vector2 = head - n * (_length * taper)
			draw_line(tail, head, Color(_color.r, _color.g, _color.b, _color.a * fade * taper),
					maxf(_width * taper * fade, 1.0), true)

var _time: float = 0.0
## 지금 얼굴이 보고 있는 쪽(1 = 원래, -1 = 돌아간 쪽)
var _face_side: float = 1.0
var _trail: Swish = null

func _ready() -> void:
	_trail = Swish.new()
	_trail.name = "Swish"
	_body.add_child(_trail)
	# 얼굴보다 **먼저** 그려야 머리 뒤에 깔린다
	_body.move_child(_trail, _face.get_index())
	_apply_pivots()
	_apply_face(-1.0 if (preview_turned and Engine.is_editor_hint()) else 1.0, 1.0)
	if fit_to_screen:
		_fit()
	if Engine.is_editor_hint():
		set_process(false)

## 회전 중심을 실제 노드 자리로 옮긴다.
## **스프라이트는 반대로 밀어 둔다** — 그래야 중심을 어디로 옮기든 그림은 늘 원본 자리(0,0)에 선다.
## 팔·얼굴 중심은 몸통 중심 기준의 상대 좌표라 한 번 빼 준다
func _apply_pivots() -> void:
	if not is_node_ready():
		return
	_bag.position = bag_pivot
	_bag_sprite.position = -bag_pivot
	_body.position = body_pivot
	_body_sprite.position = -body_pivot
	_arm.position = arm_pivot - body_pivot
	_arm_sprite.position = -arm_pivot
	_face_sprite.position = -face_pivot
	_apply_face(_face_side, absf(_face.scale.x))

## 그림이 화면을 덮도록 키운다. 캔버스가 16:9라 가로·세로 배율이 거의 같다
func _fit() -> void:
	var screen: Vector2 = get_viewport_rect().size
	scale = Vector2.ONE * maxf(screen.x / CANVAS.x, screen.y / CANVAS.y)

func _process(delta: float) -> void:
	_time += delta
	_breathe()
	_twitch_bag()
	_swing_arm()
	if look_around:
		_look_around()

## 허리를 붙잡고 가슴이 부푼다. 가로는 세로보다 덜 늘어난다 — 사람 가슴이 그렇게 움직인다
func _breathe() -> void:
	var s: float = sin(_time * TAU / maxf(breath_period, 0.05))
	_body.scale = Vector2(1.0 + s * breath_amount * 0.4, 1.0 + s * breath_amount)
	_body.position = body_pivot + Vector2(0.0, -s * breath_lift)

## 쓰레기봉지가 **움찔**한다 — `bag_every`마다 `bag_time` 동안 바닥을 축으로 좌우로 떨고,
## 떨면서 들썩이고 눌렸다 펴진다. 흔들림은 뒤로 갈수록 잦아든다(그래야 "한 번 움찔"로 읽힌다)
func _twitch_bag() -> void:
	var t: float = fmod(_time, maxf(bag_every, 0.1))
	if not bag_twitch or bag_time <= 0.0 or t >= bag_time:
		_bag.rotation = 0.0
		_bag.position = bag_pivot
		_bag.scale = Vector2.ONE
		return
	var k: float = t / bag_time
	var damp: float = 1.0 - k
	var wave: float = sin(k * TAU * bag_shakes)
	_bag.rotation = deg_to_rad(bag_angle) * wave * damp
	_bag.position = bag_pivot + Vector2(0.0, -absf(wave) * bag_lift * damp)
	var sq: float = bag_squash * damp * (1.0 - absf(wave))
	_bag.scale = Vector2(1.0 + sq, 1.0 - sq)

## 어깨에서 도니까 손전등 끝이 **반원을 그린다**
func _swing_arm() -> void:
	var t: float = _time * TAU / maxf(arm_period, 0.05) + arm_offbeat * TAU
	_arm.rotation = deg_to_rad(arm_swing) * sin(t)

## 좌우로 뒤집으며 두리번거린다.
## 뒤집는 **순간**에 가로를 납작하게 눌렀다 펴서, 툭 바뀌는 게 아니라 고개가 돌아가는 것처럼 보인다
func _look_around() -> void:
	var cycle: float = maxf(look_hold + look_turn, 0.05) * 2.0
	var t: float = fmod(_time, cycle)
	var half: float = cycle * 0.5
	# 지금 어느 쪽을 보고 있나(1 = 원래 방향, -1 = 뒤집힌 방향)
	var side: float = 1.0 if t < half else -1.0
	var in_half: float = t if t < half else t - half
	var width: float = 1.0
	# `look_turn`이 0이면 이 칸을 아예 건너뛴다 — 눌렸다 펴지는 게 없으니 **툭 바뀐다**
	if look_turn > 0.0 and in_half >= look_hold:
		var k: float = clampf((in_half - look_hold) / look_turn, 0.0, 1.0)
		width = lerpf(1.0, look_squash, 1.0 - absf(k * 2.0 - 1.0))
		# 절반을 넘기는 순간 반대쪽 얼굴로 바뀐다
		if k > 0.5:
			side = -side
	# 방향이 막 바뀐 그 프레임에 속도선을 긋는다
	if not is_equal_approx(side, _face_side):
		_flash_trail(_head_at(_face_side), _head_at(side))
	_apply_face(side, width)

## 그 쪽을 볼 때 **머리 한가운데가 오는 자리**(BodyPivot 안 좌표).
## 뒤집히면 머리 중심이 목 기준으로 반대편에 오므로 가로 어긋남도 같이 뒤집는다
func _head_at(side: float) -> Vector2:
	var turned: float = 1.0 if side < 0.0 else 0.0
	var base: Vector2 = face_pivot - body_pivot + look_offset * turned
	var away: Vector2 = head_center - face_pivot
	return base + Vector2(away.x * side, away.y)

## 속도선을 한 번 긋는다. `from`에서 `to`로 간 것이라, 선은 **온 쪽(from 뒤)**으로 뻗는다
func _flash_trail(from: Vector2, to: Vector2) -> void:
	if not trail_enabled or _trail == null:
		return
	_trail.flash(from, to, trail_count, trail_time, trail_radius, trail_length, trail_spread, trail_width, trail_color)

## 얼굴을 **지금 보는 쪽·지금 눌린 정도**로 세운다.
## 애니메이션도, 인스펙터에서 값을 고쳤을 때도 전부 여기를 지난다 — 두 군데서 따로 계산하면 어긋난다
func _apply_face(side: float, width: float) -> void:
	if not is_node_ready():
		return
	_face_side = side
	# 돌아간 쪽일 때만 밀고 갸웃한다
	var turned: float = 1.0 if side < 0.0 else 0.0
	_face.scale = Vector2(side * width, 1.0)
	_face.rotation = deg_to_rad(look_tilt) * turned
	_face.position = face_pivot - body_pivot + look_offset * turned
