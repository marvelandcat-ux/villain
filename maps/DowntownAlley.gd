@tool
extends Node2D

## 번화가 가운데 **소실점 골목**(2026-10-08, 사용자 레퍼런스 = 밤거리 사진). 양쪽 건물 사이 빈 가운데에
## 멀어지는 골목을 세운다 — 앞면(싸우는 층) 틈 `front_left`~`front_right`에서 `vanish`(소실점, 땅 근처)로 모인다.
## 깊이 층 3겹(`LAYERS`): 겹마다 CanvasGroup + `far_blur`(멀수록 흐리고 어둡게) + `ParallaxFollow`(멀수록 덜 움직임).
## 각 겹에는 **기존 건물 그림을 재활용**해 양옆 벽을 세우고(`maps/AlleyRoad.gd` 도로 토막 + 간판 건물엔 네온 재질),
## 가장 먼 겹 끝은 소실점을 가리는 건물로 막는다.
##
## 배치는 코드가 그림의 보이는 영역을 재서 안쪽 가장자리부터 바깥으로 이어 붙인다 — 건물 그림을 바꿔도 다시 맞춰진다.
## ⚠️ 노드는 `_ready()`에서 매번 새로 만든다(씬에 저장 안 함). 에디터에서도 보이게 `@tool`. 값을 바꾸면 `rebuild`를 켠다.
## ⚠️ `Deco*` 이름이라 맵 선택 미리보기에선 빠진다. 전부 z -28~-26(배경 -29와 건물 -20 사이)

const PARALLAX_SCRIPT := preload("res://maps/ParallaxFollow.gd")
const ROAD_SCRIPT := preload("res://maps/AlleyRoad.gd")
const FAR_BLUR := preload("res://maps/far_blur.gdshader")
const NEON_SHADER := preload("res://maps/NeonSign.gdshader")
const PICKUP_SCRIPT := preload("res://maps/TrashPickup.gd")   # `_opaque_rect_of()`(보이는 영역 재기) 재활용

## 재활용하는 건물 그림과 **앞면에서의 배율**(씬에 놓인 값) — 깊이만큼 곱해 줄어든다. 간판 있는 것은 네온을 켠다
const BUILDINGS := {
	"tall": {"path": "res://sprite/맵/번화가/건물 세로.png", "scale": 0.4878, "neon": false},
	"tall_sign": {"path": "res://sprite/맵/번화가/건물 세로 간판 버전.png", "scale": 0.4878, "neon": true},
	"wide": {"path": "res://sprite/맵/번화가/건물 가루.png", "scale": 0.4237, "neon": false},
	"bar2": {"path": "res://sprite/맵/번화가/술집2.png", "scale": 0.3661, "neon": true},
	"pocha": {"path": "res://sprite/맵/번화가/전포다찌.png", "scale": 0.3626, "neon": true},
	"mood": {"path": "res://sprite/맵/번화가/감성 술집.png", "scale": 0.3264, "neon": true},
	"conv": {"path": "res://sprite/맵/번화가/편의점.png", "scale": 0.3625, "neon": true},
	"mart": {"path": "res://sprite/맵/번화가/할인 마트.png", "scale": 0.3302, "neon": false},
}

## 깊이 층 — t(0 앞면 ~ 1 소실점: 도로 끝·바닥 높이가 모이는 정도) / size(건물 배율, 앞면 대비 — **t와 따로**) /
## 시차 / 흐림 / 어둡기 / z / 왼쪽 벽(안쪽→바깥) / 오른쪽 벽(안쪽→바깥)
## size를 t처럼 (1-t)로 두면 뒷줄이 장난감처럼 작아졌다(2026-10-08 사용자: "앞줄 건물보다 300px쯤만 작게") —
## 사진처럼 멀어도 건물은 크게, 길만 모이게 한다. 건물 세로(앞면 749px) 기준 0.85/0.72/0.6 = 637/539/449px
const LAYERS := [
	{"t": 0.3, "size": 0.85, "parallax": 0.9, "blur": 0.7, "dim": 0.08, "z": -26,
		"left": ["mood", "tall"], "right": ["pocha", "wide"]},
	{"t": 0.55, "size": 0.72, "parallax": 0.82, "blur": 1.2, "dim": 0.15, "z": -27,
		"left": ["bar2", "mart"], "right": ["conv", "tall_sign"]},
	{"t": 0.75, "size": 0.6, "parallax": 0.74, "blur": 1.8, "dim": 0.22, "z": -28,
		"left": ["tall_sign", "wide"], "right": ["mood", "tall"]},
]
## 가장 먼 겹 뒤에서 소실점을 막는 건물(가운데 정렬)과 그 깊이·배율
const END_WALL := {"t": 0.9, "size": 0.5, "keys": ["wide", "bar2", "wide"]}

## 소실점(월드). 땅(286)에서 50px 위 — 사진처럼 길이 멀어지는 느낌(2026-10-08 사용자 선택)
@export var vanish: Vector2 = Vector2(11.0, 236.0)
## 앞면 골목 양 끝 x(= 양옆 앞줄 건물의 안쪽 가장자리)와 앞면 땅 y
@export var front_left: float = -366.0
@export var front_right: float = 388.0
@export var front_y: float = 286.0
## 시차 기준 카메라 중심 — 배경(`DecoBackground`)과 같은 값
@export var parallax_reference: Vector2 = Vector2(0.0, -226.0)
## 이어 붙일 때 건물끼리 겹치는 폭(앞면 px) — 틈이 안 보이게
@export var overlap: float = 6.0
## 켜면 다시 만든다(에디터에서 값을 바꾼 뒤)
@export var rebuild: bool = false:
	set(v):
		rebuild = false
		if is_inside_tree():
			_build()

var _neon_material: ShaderMaterial = null

func _ready() -> void:
	_build()

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_neon_material = ShaderMaterial.new()
	_neon_material.shader = NEON_SHADER
	for i in LAYERS.size():
		var layer: Dictionary = LAYERS[i]
		var t_from: float = 0.0 if i == 0 else float(LAYERS[i - 1]["t"])
		var group := _make_group("DecoAlley%d" % (i + 1), layer)
		add_child(group)
		# 도로 토막 — 이 겹이 맡는 깊이 구간
		var road := ROAD_SCRIPT.new()
		road.name = "Road"
		road.vanish = vanish
		road.front_left = front_left
		road.front_right = front_right
		road.front_y = front_y
		road.t_from = t_from
		road.t_to = float(layer["t"]) if i < LAYERS.size() - 1 else 1.0
		group.add_child(road)
		# 양옆 벽
		_place_wall(group, layer["left"], float(layer["t"]), float(layer["size"]), -1.0)
		_place_wall(group, layer["right"], float(layer["t"]), float(layer["size"]), 1.0)
		if i == LAYERS.size() - 1:
			_place_end_wall(group)

## 겹 하나 = CanvasGroup(흐림·어둡기) + 시차
func _make_group(group_name: String, layer: Dictionary) -> CanvasGroup:
	var group := CanvasGroup.new()
	group.name = group_name
	group.z_index = int(layer["z"])
	var mat := ShaderMaterial.new()
	mat.shader = FAR_BLUR
	mat.set_shader_parameter("blur_px", float(layer["blur"]))
	mat.set_shader_parameter("dim", float(layer["dim"]))
	group.material = mat
	group.set_script(PARALLAX_SCRIPT)
	group.set("factor", Vector2.ONE * float(layer["parallax"]))
	group.set("reference", parallax_reference)
	return group

## 골목 한쪽 벽 — 안쪽 가장자리(도로 끝)부터 바깥으로 건물을 이어 붙인다. side -1 = 왼쪽, +1 = 오른쪽
func _place_wall(group: Node, keys: Array, t: float, size: float, side: float) -> void:
	var inner_x: float = _edge(front_left if side < 0.0 else front_right, t).x
	var ground_y: float = _edge(0.0, t).y
	var cursor: float = inner_x
	for key in keys:
		var spr := _make_building(String(key), size)
		if spr == null:
			continue
		var r: Rect2 = _visible_rect(spr)   # 로컬(배율 적용) 보이는 영역
		# 안쪽 가장자리를 cursor에, 바닥을 땅에
		var inner_edge: float = r.end.x if side < 0.0 else r.position.x
		spr.position = Vector2(cursor - inner_edge, ground_y - r.end.y)
		group.add_child(spr)
		# 다음 건물은 바깥쪽으로 — 왼쪽 벽(side -1)은 x가 줄고, 오른쪽 벽은 는다
		cursor += side * (r.size.x - overlap * (1.0 - t))

## 가장 먼 겹 끝 — 소실점을 가리는 건물 몇 채를 가운데 정렬로 나란히
func _place_end_wall(group: Node) -> void:
	var t: float = float(END_WALL["t"])
	var ground_y: float = _edge(0.0, t).y
	var sprites: Array = []
	var total: float = 0.0
	for i in END_WALL["keys"].size():
		var spr := _make_building(String(END_WALL["keys"][i]), float(END_WALL["size"]))
		if spr == null:
			continue
		spr.name = "end_%d_%s" % [i, spr.name]
		sprites.append(spr)
		total += _visible_rect(spr).size.x
	var cursor: float = vanish.x - total * 0.5
	for spr in sprites:
		var r: Rect2 = _visible_rect(spr)
		spr.position = Vector2(cursor - r.position.x, ground_y - r.end.y)
		spr.z_index = -1   # 양옆 벽보다 뒤
		group.add_child(spr)
		cursor += r.size.x

## 건물 스프라이트(배율 = 앞면 배율 x size). 축소된 그림은 밉맵 필터가 없으면 지글거리며 **뒤가 더 또렷해 보인다**(2026-10-08 겪음)
func _make_building(key: String, size: float) -> Sprite2D:
	if not BUILDINGS.has(key):
		return null
	var info: Dictionary = BUILDINGS[key]
	var tex: Texture2D = load(String(info["path"]))
	if tex == null:
		return null
	var spr := Sprite2D.new()
	spr.name = key
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	spr.scale = Vector2.ONE * float(info["scale"]) * size
	if bool(info["neon"]):
		spr.material = _neon_material
	return spr

## 스프라이트의 보이는 영역(로컬, 배율 적용, 가운데 원점 기준)
func _visible_rect(spr: Sprite2D) -> Rect2:
	var r: Rect2 = PICKUP_SCRIPT._opaque_rect_of(spr.texture)
	r.position -= spr.texture.get_size() * 0.5
	return Rect2(r.position * spr.scale, r.size * spr.scale)

## 앞면 점을 깊이 t만큼 소실점 쪽으로
func _edge(x: float, t: float) -> Vector2:
	return Vector2(x, front_y).lerp(vanish, t)
