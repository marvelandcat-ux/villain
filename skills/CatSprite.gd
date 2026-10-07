extends Node2D

## 고양이 그림 조립 — `sprite/고양이 아줌마/고양이들/`의 머리·몸·발·꼬리를 코드로 붙인다(검은·주황·흰 공용).
## 그림은 전부 **오른쪽(+x)을 본다**. 원점 = 발바닥(땅), +x = 고양이가 보는 쪽. 반대로 보게 하려면 이 노드의 scale.x를 음수로.
## 자세는 사용자 참고 그림(2026-10-04) — 몸통이 낮게 엎드리고, 큰 머리가 몸 앞 위에 얹히고, 발은 엎드린 그대로 바닥에(앞발 = 가슴 밑, 뒷발 = 엉덩이 밑).
## 걸을 때 발은 앞뒤로 번갈아 살짝 들리며 미끄러진다. 꼬리 그림은 직선이라 `Line2D`에 늘려 붙여 **곡선으로 휘고 물결친다**.
## 파츠마다 `PARTS`의 BBOX(그림 속 실제 영역)만 잘라 쓰고 목표 크기(px)로 배율을 역산한다 — **그림을 바꾸면 BBOX를 다시 잴 것**

const DIR := "res://sprite/고양이 아줌마/고양이들/"
## 종류(0 검은 / 1 주황 / 2 흰)별 [파일, BBOX(x, y, w, h)]
const PARTS: Array = [
	{
		"head": ["검은 고양이 머리.png", Rect2(162, 88, 996, 994)],
		"body": ["검은 고양이 몸.png", Rect2(0, 198, 1428, 726)],
		"foot": ["검은 고양이 발.png", Rect2(227, 333, 898, 433)],
		"tail": ["검은 고양이.png", Rect2(257, 221, 1665, 281)],
	},
	{
		"head": ["주황색 고양이머리.png", Rect2(69, 81, 1089, 1129)],
		"body": ["주황색 고양이몸.png", Rect2(146, 199, 1277, 643)],
		"foot": ["주황색 고양이 발.png", Rect2(41, 52, 1167, 775)],
		"tail": ["주황색 고양이 꼬리.png", Rect2(277, 195, 1565, 321)],
	},
	{
		"head": ["하양 고양이 머리.png", Rect2(113, 21, 1087, 1154)],
		"body": ["하양고양이 몸.png", Rect2(0, 199, 1430, 725)],
		"foot": ["하양 고야이 발.png", Rect2(41, 54, 1096, 773)],
		"tail": ["하양 고양이 꼬리.png", Rect2(240, 210, 1683, 305)],
	},
]
## 종류별 눈(머리 그림 픽셀, 테두리 포함 + 여유) [가운데, 크기, 털색] — 머리 그림을 바꾸면 다시 잴 것
const EYES: Array = [
	[Vector2(913, 620), Vector2(225, 160), Color8(42, 40, 40)],
	[Vector2(857, 654), Vector2(265, 170), Color8(249, 156, 60)],
	[Vector2(876, 719), Vector2(235, 190), Color8(252, 252, 252)],
]
const EYE_BLINK_SCRIPT := preload("res://characters/EyeBlink.gd")

## 고양이 전체 크기 배율 — 아래 px 값은 전부 배율 1 기준이다
@export var size_scale: float = 1.5
## 몸통 가로 길이(px)와 가운데
@export var body_width: float = 32.0
@export var body_center: Vector2 = Vector2(0.0, -10.0)
## 머리 가로 크기(px, 귀 포함)와 가운데 — 몸 앞 위에 얹힌다
@export var head_width: float = 24.0
@export var head_center: Vector2 = Vector2(16.0, -19.0)
## 발 가로 길이(px)와 가운데(앞발·뒷발) — 바닥에 엎드린 그대로
@export var paw_width: float = 12.0
@export var front_paw: Vector2 = Vector2(11.0, -3.0)
@export var back_paw: Vector2 = Vector2(-6.0, -3.0)
## 화면 안쪽(먼) 발이 가까운 발에서 비켜난 거리와 어둡기
@export var far_paw_shift: float = -3.0
@export var far_paw_tint: Color = Color(0.7, 0.7, 0.7)
## 걸을 때 발이 앞뒤로 미끄러지는 거리, 들리는 높이(px)
@export var paw_stride: float = 3.5
@export var paw_lift: float = 2.0
## 꼬리 — 길이(px), 뿌리 자리, 뻗는 기본 방향(도, 180 = 정뒤), 위로 휘는 정도(px), 물결 크기(px)·빠르기
@export var tail_length: float = 26.0
@export var tail_root: Vector2 = Vector2(-13.0, -11.0)
@export var tail_deg: float = 195.0
@export var tail_curl: float = 7.0
@export var tail_wave: float = 3.0
@export var tail_wave_speed: float = 4.0
## 꼬리를 이루는 점 개수 — 많을수록 매끈하게 휜다
@export var tail_points: int = 12

var kind: int = 0
## 걷기 박자(라디안) — 0이면 네 발이 제자리에 엎드린다
var walk_phase: float = 0.0
## 0~1 — 가까운 앞발을 앞 위로 뻗는 정도(흰 고양이 할퀴기)
var paw_reach: float = 0.0
## 0~1 — 돌진 준비 웅크림(검은 고양이): 엉덩이를 뒤로 빼고 낮추며 실룩거린다
var pounce: float = 0.0
## 남은 시간(초) — 0보다 크면 머리를 까딱까딱(흰 고양이 핥기)
var nod_left: float = 0.0
## 눈 감기(피격) — 머리 그림의 눈을 털색 눈꺼풀(EyeBlink)로 덮으며 감는다
var eyes_closed: bool = false

static var _textures: Dictionary = {}
static var _cropped: Dictionary = {}

var _head: Sprite2D
var _body: Sprite2D
var _tail: Line2D
## [먼 앞, 먼 뒤, 가까운 앞, 가까운 뒤]
var _paws: Array[Sprite2D] = []
var _paw_rest: Array[Vector2] = []
var _age: float = 0.0
## 파츠를 담는 그릇 — size_scale만큼 키운다
var _root: Node2D
## 눈꺼풀(EyeBlink) — 머리 스프라이트의 자식이라 머리를 따라다닌다
var _eye_lid: Node2D

## kind(0 검은 / 1 주황 / 2 흰)의 파츠 그림
static func texture_of(cat_kind: int, part: String) -> Texture2D:
	var key: String = "%d_%s" % [cat_kind, part]
	if not _textures.has(key):
		_textures[key] = load(DIR + PARTS[cat_kind][part][0])
	return _textures[key]

static func bbox_of(cat_kind: int, part: String) -> Rect2:
	return PARTS[cat_kind][part][1]

## BBOX만 잘라낸 그림 — Line2D는 region을 못 쓰므로 꼬리는 이걸 늘려 붙인다
static func cropped_of(cat_kind: int, part: String) -> Texture2D:
	var key: String = "%d_%s" % [cat_kind, part]
	if not _cropped.has(key):
		var image: Image = texture_of(cat_kind, part).get_image()
		if image.is_compressed():
			image.decompress()
		_cropped[key] = ImageTexture.create_from_image(image.get_region(Rect2i(bbox_of(cat_kind, part))))
	return _cropped[key]

## 머리 그림 하나를 center에 가로 width px로 그린다(_draw 안에서) — 선택 표시·집 간판용
static func draw_head(ci: CanvasItem, cat_kind: int, center: Vector2, width: float) -> void:
	var src: Rect2 = bbox_of(cat_kind, "head")
	var size := Vector2(width, width * src.size.y / src.size.x)
	ci.draw_texture_rect_region(texture_of(cat_kind, "head"), Rect2(center - size * 0.5, size), src)

func _ready() -> void:
	_build()

## 몸통 가운데의 실제 자리(배율 반영) — 들고 있는 쪽이 몸통 가운데를 손에 맞출 때 쓴다
func body_center_scaled() -> Vector2:
	return body_center * size_scale

## 종류를 바꿔 다시 조립한다
func set_kind(cat_kind: int) -> void:
	kind = cat_kind
	if is_inside_tree():
		_build()

func _build() -> void:
	for child in get_children():
		child.queue_free()
	_paws.clear()
	_paw_rest.clear()
	_root = Node2D.new()
	_root.scale = Vector2(size_scale, size_scale)
	add_child(_root)
	_tail = Line2D.new()
	_tail.texture = cropped_of(kind, "tail")
	_tail.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	var tail_box: Rect2 = bbox_of(kind, "tail")
	_tail.width = tail_length * tail_box.size.y / maxf(tail_box.size.x, 1.0)
	_tail.joint_mode = Line2D.LINE_JOINT_ROUND
	_root.add_child(_tail)
	var far_front := _paw(front_paw + Vector2(far_paw_shift, 0.0), true)
	var far_back := _paw(back_paw + Vector2(far_paw_shift, 0.0), true)
	_body = _sprite("body", body_width)
	_body.position = body_center
	var near_back := _paw(back_paw, false)
	var near_front := _paw(front_paw, false)
	_head = _sprite("head", head_width)
	_head.position = head_center
	# 저절로 깜빡이진 않고(간격 9999) 맞았을 때만 감는다. 좌표는 머리 그림 픽셀, region 가운데가 원점
	var eye: Array = EYES[kind]
	_eye_lid = EYE_BLINK_SCRIPT.new()
	_eye_lid.needs_rig = false
	_eye_lid.position = eye[0] - bbox_of(kind, "head").get_center()
	_eye_lid.eye_size = eye[1]
	_eye_lid.skin_color = eye[2]
	_eye_lid.line_width = 45.0
	_eye_lid.close_time = 0.06
	_eye_lid.open_time = 0.12
	_eye_lid.interval_min = 9999.0
	_eye_lid.interval_max = 9999.0
	_head.add_child(_eye_lid)
	_paws = [far_front, far_back, near_front, near_back]
	_paw_rest = [far_front.position, far_back.position, near_front.position, near_back.position]
	_apply_pose()

func _sprite(part: String, target: float) -> Sprite2D:
	var rect: Rect2 = bbox_of(kind, part)
	var s := Sprite2D.new()
	s.texture = texture_of(kind, part)
	s.region_enabled = true
	s.region_rect = rect
	var k: float = target / maxf(rect.size.x, 1.0)
	s.scale = Vector2(k, k)
	_root.add_child(s)
	return s

func _paw(pos: Vector2, far: bool) -> Sprite2D:
	var s := _sprite("foot", paw_width)
	s.position = pos
	if far:
		s.modulate = far_paw_tint
	return s

func _process(delta: float) -> void:
	_age += minf(delta, 0.05)
	if nod_left > 0.0:
		nod_left = maxf(nod_left - delta, 0.0)
	_apply_pose()

func _apply_pose() -> void:
	if _tail == null:
		return
	_update_tail()
	# 대각선 발끼리 같이 움직인다(먼 앞 + 가까운 뒤 / 먼 뒤 + 가까운 앞). 앞으로 나갈 때만 살짝 들린다
	var walking: bool = walk_phase != 0.0
	var phases: Array[float] = [walk_phase, walk_phase + PI, walk_phase + PI, walk_phase]
	for i in _paws.size():
		var off := Vector2.ZERO
		if walking:
			off.x = sin(phases[i]) * paw_stride
			off.y = -maxf(cos(phases[i]), 0.0) * paw_lift
		_paws[i].position = _paw_rest[i] + off
		_paws[i].rotation = 0.0
	# 가까운 앞발은 할퀼 때 앞 위로 뻗는다
	var r: float = clampf(paw_reach, 0.0, 1.0)
	if r > 0.0:
		_paws[2].position += Vector2(8.0, -7.0) * r
		_paws[2].rotation = deg_to_rad(-35.0) * r
	_body.position = body_center + Vector2(0.0, -absf(sin(walk_phase)) * 0.8 if walking else 0.0)
	_head.position = head_center + Vector2(0.0, -absf(sin(walk_phase)) * 1.2 if walking else 0.0)
	_head.rotation = 0.0
	# 가만히 있을 땐 천천히 숨쉬기 — 몸이 미세하게 들썩인다
	if not walking:
		var breath: float = sin(_age * 3.0)
		_body.position.y += breath * 0.7
		_head.position.y += sin(_age * 3.0 + 0.5) * 0.9
	# 돌진 준비 웅크림 — 몸·머리를 뒤로 빼고 낮추며, 엉덩이가 실룩거린다
	if pounce > 0.001:
		var wiggle: float = sin(_age * 22.0) * 1.1 * pounce
		_body.position += Vector2(-4.0 * pounce + wiggle * 0.5, 1.6 * pounce)
		_body.rotation = -0.06 * pounce
		_head.position += Vector2(-2.5 * pounce, 2.6 * pounce + wiggle * 0.3)
	else:
		_body.rotation = 0.0
	# 핥기 — 머리가 앞으로 나가며 까딱까딱
	if nod_left > 0.0:
		var nod: float = sin(nod_left * 28.0)
		_head.position += Vector2(1.5, nod * 2.0)
		_head.rotation = nod * 0.14
	if _eye_lid:
		_eye_lid.held_closed = eyes_closed

## 꼬리 — 뿌리에서 tail_deg 쪽으로 뻗으며 끝으로 갈수록 위로 휘고, 물결이 뿌리에서 끝으로 흐른다.
## Line2D는 첫 점이 그림 왼쪽 끝이다 — 그림 왼쪽이 꼬리 끝이라 **끝 → 뿌리** 순서로 점을 넣는다
func _update_tail() -> void:
	var n: int = maxi(tail_points, 2)
	var dir := Vector2.RIGHT.rotated(deg_to_rad(tail_deg))
	# 뻗는 방향에 수직인 두 쪽 중 화면 위(-y)쪽
	var up := Vector2(-dir.y, dir.x)
	if up.y > 0.0:
		up = -up
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		var t: float = 1.0 - float(i) / float(n - 1)
		var bend: float = tail_curl * t * t * (1.0 + pounce * 1.2) + sin(_age * tail_wave_speed - t * 3.0) * tail_wave * t
		pts[i] = tail_root + dir * (tail_length * t) + up * bend
	_tail.points = pts
