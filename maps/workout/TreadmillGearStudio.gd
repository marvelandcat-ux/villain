@tool
extends Node2D

## **런닝머신 단계 장비 편집 씬** — 단계마다 한 장이다(`TreadmillBikeStudio` 자전거 바퀴 4~6스택 /
## `TreadmillCarStudio` 스포츠카 바퀴 7~9스택 / `TreadmillRocketStudio` 로켓 신발 10스택).
##
## ## 쓰는 법
## 1. 에디터에서 씬을 연다(실행할 필요 없다)
## 2. 루트를 골라 인스펙터의 **character**를 바꾸면 그 캐릭터 몸으로 바뀐다
## 3. **Head·Body·HandL·HandR·GearL**(로켓은 GearL/Flame도)를 끌어 맞춘다 — 장비는 하나(GearL)가 두 발을 대신한다
## 4. 손을 떼면 `maps/workout/TreadmillGear.tres`에 **그 캐릭터·그 단계 자리로 바로 저장된다** — 씬 저장(Ctrl+S)은 안 해도 된다
##
## - 머리·몸·손은 **자리만** 게임에 들어간다(각도·크기를 바꿔도 안 들어간다)
## - 장비(GearL)는 자리·각도·크기를 다 쓴다 — 크기는 네모 핸들로 잡는다
## - 불꽃은 장비 그림 안 좌표라 장비를 키우면 같이 커진다
## - 로켓 신발 그림이 없는 캐릭터는 GearL에 새 그림을 끌어다 놓으면 그 캐릭터 신발로 저장된다
## - **reset_to_default**를 켜면 그 캐릭터·단계를 기본 자리로 되돌린다
## - 회색 가로줄 = 땅(발바닥 높이), 작은 십자 = 캐릭터 원점(발바닥보다 30px 위).
##   **로켓은 게임에서 공중에 뜬다** — 땅선이 뜨는 높이(`rocket_hover_height`)만큼 아래에 그려지고,
##   원래 발바닥 자리는 옅은 점선이다. 부스터를 옅은 선에 붙여 두면 게임에선 그만큼 떠서 다닌다

const RIG_READER := preload("res://maps/workout/RigReader.gd")
## 편집 씬에서 끌어 맞추는 조각들(장비·불꽃 제외)
const EDIT_PARTS: Array[String] = ["Body", "Head", "HandL", "HandR"]

## 이 씬이 맡은 단계
@export_enum("bike", "car", "rocket") var stage: String = "bike"
## 맞춰 볼 캐릭터. **인스펙터에서 목록으로 고른다**(아래 `_validate_property`가 리그 목록을 넣어 준다) —
## 손으로 적던 때는 한 글자만 틀려도 조용히 빈 화면이 됐다
@export var character: String = "금쪽이":
	set(value):
		character = value
		if Engine.is_editor_hint() and is_inside_tree():
			_load_character()
## 자리표(`maps/workout/TreadmillGear.tres`)
@export var data: Resource
## 켜면 지금 캐릭터·단계를 **기본 자리로 되돌린다**(켜자마자 저절로 다시 꺼진다)
@export var reset_to_default: bool = false:
	set(value):
		reset_to_default = false
		if value and Engine.is_editor_hint() and is_inside_tree():
			_reset_current()

## 지금 화면에 올라 있는 캐릭터 — 저장은 이 이름으로 한다(character를 바꾸는 순간엔 이미 새 이름이라)
var _loaded: String = ""
## 마지막으로 본 조각 자리 — 바뀐 걸 알아채는 데 쓴다
var _last_sign: String = ""
var _save_pending: bool = false
## 장비 그림(신발을 갈아 끼웠는지 보려고)
var _last_gear_texture: Texture2D = null

func _validate_property(property: Dictionary) -> void:
	if property.name == "character":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(RIG_READER.names())

func _ready() -> void:
	_load_character()

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() or data == null or _loaded == "":
		return
	var gear_l := get_node_or_null("GearL") as Sprite2D
	# 신발 그림을 갈아 끼웠으면 그 캐릭터 신발로 적고 반대 발도 같이 바꾼다
	if stage == "rocket" and gear_l and gear_l.texture != _last_gear_texture and gear_l.texture != null:
		_last_gear_texture = gear_l.texture
		data.rocket_shoes[_loaded] = gear_l.texture
		var gear_r := get_node_or_null("GearR") as Sprite2D
		if gear_r:
			gear_r.texture = gear_l.texture
		_save_pending = true
	var now_sign: String = _signature()
	if now_sign != _last_sign:
		_last_sign = now_sign
		data.set_entry(_loaded, stage, _capture())
		_save_pending = true
	elif _save_pending:
		_save_pending = false
		ResourceSaver.save(data)

func _draw() -> void:
	# 땅(발바닥 높이)과 캐릭터 원점. 로켓은 그만큼 떠 있으니 진짜 땅을 그만큼 아래에 그린다
	var hover: float = data.rocket_hover_height if (data and stage == "rocket") else 0.0
	draw_line(Vector2(-90, 30 + hover), Vector2(90, 30 + hover), Color(0.6, 0.6, 0.6, 0.8), 0.4)
	if hover > 0.0:
		draw_dashed_line(Vector2(-90, 30), Vector2(90, 30), Color(0.6, 0.6, 0.6, 0.35), 0.25, 2.0)
	draw_line(Vector2(-3, 0), Vector2(3, 0), Color(1, 0.3, 0.3, 0.8), 0.3)
	draw_line(Vector2(0, -3), Vector2(0, 3), Color(1, 0.3, 0.3, 0.8), 0.3)

## 캐릭터 리그를 읽어 조각 그림·제자리를 입히고, 적어 둔 자리(없으면 기본 자리)로 놓는다
func _load_character() -> void:
	# 바꾸기 전 캐릭터의 고친 자리를 놓치지 않게 먼저 적어 둔다
	if _save_pending and data != null and _loaded != "":
		data.set_entry(_loaded, stage, _capture())
		ResourceSaver.save(data)
		_save_pending = false
	var rest: Dictionary = RIG_READER.read(character)
	if rest.is_empty():
		_loaded = ""
		return
	for part_name in EDIT_PARTS:
		var node := get_node_or_null(part_name) as Sprite2D
		if node and rest.has(part_name):
			RIG_READER.copy_look(node, rest[part_name])
			node.position = rest[part_name]["position"]
	var gear_tex: Texture2D = data.gear_texture(character, stage) if data else null
	for side in ["L", "R"]:
		var gear := get_node_or_null("Gear" + side) as Sprite2D
		if gear == null or not rest.has("Foot" + side):
			continue
		RIG_READER.copy_look(gear, rest["Foot" + side])
		gear.flip_h = false
		gear.offset = Vector2.ZERO
		gear.centered = true
		gear.region_enabled = false
		if gear_tex != null:
			gear.texture = gear_tex
	_last_gear_texture = (get_node_or_null("GearL") as Sprite2D).texture if has_node("GearL") else null
	var entry: Dictionary = data.entry(character, stage) if data else {}
	if entry.is_empty() and data:
		entry = data.default_entry(rest, gear_tex, stage)
	_put(entry)
	_loaded = character
	_last_sign = _signature()
	_save_pending = false
	queue_redraw()

## 지금 캐릭터·단계를 기본 자리로
func _reset_current() -> void:
	if data == null:
		return
	data.entries.erase(character + "|" + stage)
	ResourceSaver.save(data)
	_save_pending = false
	_loaded = ""
	_load_character()

## 자리표 한 줄을 편집 조각들에 놓는다
func _put(entry: Dictionary) -> void:
	for part_name in entry:
		var node: Node2D = _node_for(part_name)
		if node == null:
			continue
		var value: Array = entry[part_name]
		node.position = value[0]
		# 머리·몸·손은 자리만 쓴다 — 각도·크기는 리그 그대로 둔다
		if not part_name in EDIT_PARTS:
			node.rotation = value[1]
			node.scale = value[2]

## 편집 조각들의 지금 자리를 자리표 한 줄로
func _capture() -> Dictionary:
	var out: Dictionary = {}
	for part_name in EDIT_PARTS + ["GearL", "GearR", "FlameL", "FlameR"]:
		var node: Node2D = _node_for(part_name)
		if node:
			out[part_name] = [node.position, node.rotation, node.scale]
	return out

func _node_for(part_name: String) -> Node2D:
	match part_name:
		"FlameL":
			return get_node_or_null("GearL/Flame") as Node2D
		"FlameR":
			return get_node_or_null("GearR/Flame") as Node2D
	return get_node_or_null(part_name) as Node2D

## 조각 자리를 한 줄 글자로 — 바뀌었는지 비교용
func _signature() -> String:
	var parts: PackedStringArray = []
	for part_name in EDIT_PARTS + ["GearL", "GearR", "FlameL", "FlameR"]:
		var node: Node2D = _node_for(part_name)
		if node:
			parts.append("%s:%s:%.4f:%s" % [part_name, node.position, node.rotation, node.scale])
	return "|".join(parts)
