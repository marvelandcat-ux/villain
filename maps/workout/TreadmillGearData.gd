@tool
extends Resource

## **런닝머신 단계별 발 장비 자리표** — 런닝머신 스택이 오르면 발이 바뀐다(2026-10-06 사용자 지정).
##
## | 스택 | 발 |
## |---|---|
## | 1~3 | 그대로(속도만 오른다) |
## | 4~6 | 자전거 바퀴 — 움직이면 굴러간다 |
## | 7~9 | 스포츠카 바퀴 — 움직이면 굴러간다 |
## | 10 | 로켓 부스터(캐릭터마다 그림) + 뒤로 제트 불꽃, **공중에 떠서** 다닌다 |
##
## **장비는 하나다**(GearL) — 두 발을 대신하는 외바퀴·부스터 하나(2026-10-06 사용자 디자인).
## 캐릭터·단계마다 **머리·몸·손 자리, 장비의 자리·각도·크기, 불꽃 자리**를 적어 둔다.
## 고치는 곳은 `maps/workout/Treadmill*Studio.tscn`(단계마다 한 장)이다 — 캐릭터를 바꿔 가며 끌어 맞추면 여기에 바로 저장된다.
## 적힌 게 없는 캐릭터는 리그의 원래 자리 + 발 크기로 잡은 기본 장비를 쓴다(`default_entry`)

const STAGE_NONE := ""
const STAGE_BIKE := "bike"
const STAGE_CAR := "car"
const STAGE_ROCKET := "rocket"

## 자리를 적는 조각들 — 머리·몸·손은 **자리만**, 장비·불꽃은 자리·각도·크기를 쓴다
const BODY_PARTS: Array[String] = ["Head", "Body", "HandL", "HandR"]
const GEAR_PARTS: Array[String] = ["GearL", "GearR"]
const FLAME_PARTS: Array[String] = ["FlameL", "FlameR"]

## 각 단계가 시작되는 스택
@export var bike_from: int = 4
@export var car_from: int = 7
@export var rocket_from: int = 10
## 바퀴 그림
@export var bike_texture: Texture2D
@export var car_texture: Texture2D
## 캐릭터별 로켓 신발 그림 {캐릭터 이름: Texture2D}. 없는 캐릭터는 원래 발 그림에 불꽃만 붙는다
@export var rocket_shoes: Dictionary = {}
## 고쳐 둔 자리들 {"캐릭터|단계": {조각 이름: [위치, 각도, 크기]}} — 편집 씬이 채운다
@export var entries: Dictionary = {}

@export_group("로켓 단계 뜨기")
## 10스택이면 **공중에 떠서** 다닌다 — 편집 씬에서 맞춘 자리보다 이만큼(리그 px) 위로 띄운다.
## 그림만 뜬다(판정·발판은 땅 그대로). 편집 씬의 회색 땅선이 이만큼 아래에 그려진다
@export var rocket_hover_height: float = 16.0
## 떠 있는 동안 위아래로 둥실거리는 폭(px)과 빠르기(초당 왕복 수)
@export var rocket_hover_bob: float = 2.5
@export var rocket_hover_speed: float = 1.6

@export_group("기본 자리")
## 자리를 안 잡아 둔 캐릭터의 장비 크기 — 발 그림 가로 길이의 몇 배로 잡을지
## (금쪽이를 맞춘 크기에서 거꾸로 잡았다: 바퀴 1.4, 부스터 1.7)
@export var default_wheel_ratio: float = 1.4
@export var default_shoe_ratio: float = 1.7

## 불투명 영역 캐시 {그림 경로: Rect2}
static var _rect_cache: Dictionary = {}

## 스택 수 -> 단계 이름
func stage_of(stack: int) -> String:
	if stack >= rocket_from:
		return STAGE_ROCKET
	if stack >= car_from:
		return STAGE_CAR
	if stack >= bike_from:
		return STAGE_BIKE
	return STAGE_NONE

## 그 단계의 장비 그림. 로켓인데 그 캐릭터 신발 그림이 없으면 null(원래 발을 그대로 쓴다)
func gear_texture(character: String, stage: String) -> Texture2D:
	match stage:
		STAGE_BIKE:
			return bike_texture
		STAGE_CAR:
			return car_texture
		STAGE_ROCKET:
			return rocket_shoes.get(character, null) as Texture2D
	return null

## **장비 그림을 갈아 끼운다**(편집 씬에서 GearL에 그림을 끌어다 놓으면 여기로 들어온다).
##
## ⚠️ **자전거·스포츠카 바퀴는 전 캐릭터가 같은 그림 한 장을 쓴다** — 한 캐릭터 편집 씬에서 바꾸면
## 모두가 같이 바뀐다. 로켓 신발만 캐릭터마다 다르다(자기 신발에 번개를 그린 것이라서)
func set_gear_texture(character: String, stage: String, tex: Texture2D) -> void:
	match stage:
		STAGE_BIKE:
			bike_texture = tex
		STAGE_CAR:
			car_texture = tex
		STAGE_ROCKET:
			rocket_shoes[character] = tex
	emit_changed()

## 바퀴처럼 굴러가는 단계인지
func rolls(stage: String) -> bool:
	return stage == STAGE_BIKE or stage == STAGE_CAR

func entry(character: String, stage: String) -> Dictionary:
	return entries.get(character + "|" + stage, {})

func set_entry(character: String, stage: String, value: Dictionary) -> void:
	entries[character + "|" + stage] = value
	emit_changed()

## **적어 둔 게 없을 때 쓰는 기본 자리.** rest는 리그 조각들의 제자리
## {조각 이름: {"position", "scale", "texture", "offset", "centered"}}(FootL·FootR·Head·Body·HandL·HandR).
## 장비 하나(GearL)를 **두 발 사이 가운데**에, 아랫변을 발바닥에 맞춰 세운다
func default_entry(rest: Dictionary, gear_tex: Texture2D, stage: String) -> Dictionary:
	var out: Dictionary = {}
	for part in BODY_PARTS:
		if rest.has(part):
			out[part] = [rest[part]["position"], 0.0, Vector2.ONE]
	# 두 발이 차지하는 네모를 합쳐 그 가운데에 세운다
	var feet := Rect2()
	var foot_tex: Texture2D = null
	var foot_scale: float = 1.0
	for side in ["L", "R"]:
		var foot: Dictionary = rest.get("Foot" + side, {})
		if foot.is_empty():
			continue
		var box: Rect2 = visible_box(foot)
		feet = box if foot_tex == null else feet.merge(box)
		if foot_tex == null:
			foot_tex = foot.get("texture") as Texture2D
			foot_scale = absf((foot["scale"] as Vector2).x)
	var tex: Texture2D = gear_tex if gear_tex != null else foot_tex
	if tex == null:
		return out
	var opaque: Rect2 = opaque_rect(tex)
	var ratio: float = default_shoe_ratio if stage == STAGE_ROCKET else default_wheel_ratio
	# 크기는 발 한 짝 가로 길이 기준(두 발을 합친 폭으로 재면 발 간격에 따라 들쭉날쭉해진다)
	var one_foot: float = visible_box(rest.get("FootL", rest.get("FootR", {}))).size.x
	var k: float = one_foot * ratio / maxf(opaque.size.x, 1.0)
	if gear_tex == null:
		k = foot_scale   # 부스터 그림이 없으면 원래 발 크기 그대로
	var height: float = opaque.size.y * k
	var center := Vector2(feet.get_center().x, feet.end.y - height * 0.5)
	# 그림의 불투명한 가운데가 그림 한가운데와 어긋난 만큼 되돌린다(장비는 가운데 기준으로 그린다)
	center -= (opaque.get_center() - tex.get_size() * 0.5) * k
	out["GearL"] = [center, 0.0, Vector2(k, k)]
	if stage == STAGE_ROCKET:
		# 불꽃은 부스터 그림 안 좌표(그림 픽셀) — 뒤쪽(왼쪽 끝)에서 뒤로 뿜는다
		var heel := Vector2(opaque.position.x + opaque.size.x * 0.08, opaque.get_center().y + opaque.size.y * 0.1)
		out["FlameL"] = [heel - tex.get_size() * 0.5, 0.0, Vector2.ONE]
	return out

## 그 단계에서 공중에 뜨는 높이·둥실거림 [높이, 폭, 빠르기] — 로켓만 뜬다
func hover_of(stage: String) -> Array:
	if stage == STAGE_ROCKET:
		return [rocket_hover_height, rocket_hover_bob, rocket_hover_speed]
	return [0.0, 0.0, 0.0]

## 발 그림이 리그 안에서 차지하는 네모(리그 좌표, 각도는 무시)
static func visible_box(part: Dictionary) -> Rect2:
	var tex: Texture2D = part.get("texture") as Texture2D
	var pos: Vector2 = part.get("position", Vector2.ZERO)
	var scale: Vector2 = (part.get("scale", Vector2.ONE) as Vector2).abs()
	if tex == null:
		return Rect2(pos - Vector2(8, 4), Vector2(16, 8))
	var opaque: Rect2 = opaque_rect(tex)
	var origin: Vector2 = part.get("offset", Vector2.ZERO)
	if part.get("centered", true):
		origin -= tex.get_size() * 0.5
	return Rect2(pos + (opaque.position + origin) * scale, opaque.size * scale)

## 그림에서 알파가 절반 이상인 영역(그림 픽셀). 4칸씩 건너뛰며 잰다
static func opaque_rect(tex: Texture2D) -> Rect2:
	var key: String = tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id())
	if _rect_cache.has(key):
		return _rect_cache[key]
	var rect := Rect2(Vector2.ZERO, tex.get_size())
	var img: Image = tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		const STEP := 4
		var min_p := Vector2i(img.get_width(), img.get_height())
		var max_p := Vector2i(-1, -1)
		for y in range(0, img.get_height(), STEP):
			for x in range(0, img.get_width(), STEP):
				if img.get_pixel(x, y).a >= 0.5:
					min_p = Vector2i(mini(min_p.x, x), mini(min_p.y, y))
					max_p = Vector2i(maxi(max_p.x, x), maxi(max_p.y, y))
		if max_p.x >= 0:
			rect = Rect2(Vector2(min_p), Vector2(max_p - min_p) + Vector2(STEP, STEP))
	_rect_cache[key] = rect
	return rect
