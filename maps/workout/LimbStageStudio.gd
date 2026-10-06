@tool
extends Node2D

## **바벨 컬·스쿼트 단계 편집 씬** — 운동마다 단계마다 한 장이다.
## `Curl{Vein1,Vein3,Gold}Studio.tscn`(손) / `Squat{Vein1,Vein3,Gold}Studio.tscn`(발).
##
## ## 쓰는 법
## 1. 에디터에서 씬을 연다(실행할 필요 없다)
## 2. 루트를 골라 인스펙터의 **character**를 바꾸면 그 캐릭터 몸으로 바뀐다
## 3. 손(바벨 컬: HandL·HandR) / 발(스쿼트: FootL·FootR)을 **끌어서 옮기고, 네모 핸들로 키운다**
## 4. 그 밑의 **Vein\***(핏줄)·**Spark\***(반짝이)를 끌어 맞춘다. 더 넣고 싶으면 하나 골라 Ctrl+D로 복제,
##    빼고 싶으면 지운다(이름만 Vein·Spark로 시작하면 된다. 그림도 바꿔 끼울 수 있다)
## 5. 손을 떼면 자리표(`CurlStage.tres` / `SquatStage.tres`)에 **그 캐릭터·그 단계로 바로 저장된다** — Ctrl+S는 안 해도 된다
##
## - 손(발) 크기는 두 짝의 평균으로 저장된다(게임에선 두 짝이 같은 크기)
## - 머리·몸·반대쪽 부위는 보기용이다(옮겨도 저장 안 된다)
## - 핏줄·반짝이는 에디터에선 가만히 있고 게임에서 울끈불끈·반짝인다
## - **reset_to_default**를 켜면 그 캐릭터·단계를 기본 자리로 되돌린다
## - 회색 가로줄 = 땅(발바닥 높이), 작은 십자 = 캐릭터 원점(발바닥보다 30px 위)

const RIG_READER := preload("res://maps/workout/RigReader.gd")
const PULSE_SCRIPT := preload("res://combat/PulseSprite.gd")
const GOLD_SHADER := preload("res://characters/GoldLimb.gdshader")

## 이 씬이 맡은 단계
@export_enum("vein1", "vein3", "gold") var stage: String = "vein1"
## 맞춰 볼 캐릭터. **인스펙터에서 목록으로 고른다**(아래 `_validate_property`가 리그 목록을 넣어 준다) —
## 손으로 적던 때는 한 글자만 틀려도 조용히 빈 화면이 됐다
@export var character: String = "금쪽이":
	set(value):
		character = value
		if Engine.is_editor_hint() and is_inside_tree():
			_load_character()
## 자리표(`maps/workout/CurlStage.tres` 또는 `SquatStage.tres`)
@export var data: Resource
## 켜면 지금 캐릭터·단계를 **기본 자리로 되돌린다**(켜자마자 저절로 다시 꺼진다)
@export var reset_to_default: bool = false:
	set(value):
		reset_to_default = false
		if value and Engine.is_editor_hint() and is_inside_tree():
			_reset_current()

## 지금 화면에 올라 있는 캐릭터 — 저장은 이 이름으로 한다
var _loaded: String = ""
var _last_sign: String = ""
var _save_pending: bool = false
## 손(발)의 원래 크기와 그림 바꿔 낀 보정 — 크기 배수를 거꾸로 셀 때 쓴다
var _rest_scale_x: float = 1.0
var _fit: float = 1.0

func _validate_property(property: Dictionary) -> void:
	if property.name == "character":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(RIG_READER.names())

func _ready() -> void:
	_load_character()

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() or data == null or _loaded == "":
		return
	var now_sign: String = _signature()
	if now_sign != _last_sign:
		_last_sign = now_sign
		data.set_entry(_loaded, stage, _capture())
		_save_pending = true
	elif _save_pending:
		_save_pending = false
		ResourceSaver.save(data)

func _draw() -> void:
	draw_line(Vector2(-90, 30), Vector2(90, 30), Color(0.6, 0.6, 0.6, 0.8), 0.4)
	draw_line(Vector2(-3, 0), Vector2(3, 0), Color(1, 0.3, 0.3, 0.8), 0.3)
	draw_line(Vector2(0, -3), Vector2(0, 3), Color(1, 0.3, 0.3, 0.8), 0.3)

## 이 운동이 바꾸는 조각 이름들
func _limb_names() -> Array:
	return data.part_names() if data else ["HandL", "HandR"]

## 캐릭터 리그를 읽어 몸 전체를 입히고, 적어 둔 자리(없으면 기본 자리)로 손(발)·핏줄·반짝이를 놓는다
func _load_character() -> void:
	if data == null:
		return
	if _save_pending and _loaded != "":
		data.set_entry(_loaded, stage, _capture())
		ResourceSaver.save(data)
		_save_pending = false
	var rest: Dictionary = RIG_READER.read(character)
	if rest.is_empty():
		_loaded = ""
		return
	for part_name in RIG_READER.RIG_PARTS:
		var node := get_node_or_null(part_name) as Sprite2D
		if node and rest.has(part_name):
			RIG_READER.copy_look(node, rest[part_name])
			node.position = rest[part_name]["position"]
			node.material = null
	var tex: Texture2D = data.stage_texture(stage)
	_fit = data.texture_fit(rest, tex)
	var entry: Dictionary = data.entry(character, stage)
	if entry.is_empty():
		entry = data.default_entry(rest, stage)
	var size: float = float(entry.get("size", data.default_size(stage)))
	for part_name in _limb_names():
		var node := get_node_or_null(part_name) as Sprite2D
		if node == null or not rest.has(part_name):
			continue
		_rest_scale_x = absf((rest[part_name]["scale"] as Vector2).x)
		if tex != null:
			node.texture = tex
		elif data.uses_gold_shader(stage):
			var mat := ShaderMaterial.new()
			mat.shader = GOLD_SHADER
			node.material = mat
		node.scale = (rest[part_name]["scale"] as Vector2) * _fit * size
		if entry.has(part_name):
			node.position = entry[part_name][0]
		_rebuild_marks(node, entry)
	_loaded = character
	_last_sign = _signature()
	_save_pending = false
	queue_redraw()

## 그 조각 밑의 핏줄·반짝이를 자리표대로 다시 만든다(편집 씬에 저장되도록 주인을 정해 둔다)
func _rebuild_marks(node: Sprite2D, entry: Dictionary) -> void:
	for child in node.get_children():
		if _is_mark(child):
			node.remove_child(child)
			child.free()
	var prefix: String = String(node.name) + "/"
	for key in entry:
		if not String(key).begins_with(prefix):
			continue
		var value: Array = entry[key]
		var mark: Sprite2D = PULSE_SCRIPT.new()
		mark.name = String(key).get_slice("/", 1)
		if value.size() > 3 and String(value[3]) != "" and ResourceLoader.exists(String(value[3])):
			mark.texture = load(String(value[3]))
		mark.mode = 1 if mark.name.begins_with("Spark") else 0
		# 자리·크기는 **붙이기 전에** — 붙이는 순간 _ready가 지금 크기를 울끈불끈의 기준으로 잡는다
		mark.position = value[0]
		mark.rotation = value[1]
		mark.scale = value[2]
		node.add_child(mark)
		if Engine.is_editor_hint():
			mark.owner = self

func _is_mark(node: Node) -> bool:
	return node is Sprite2D and (String(node.name).begins_with("Vein") or String(node.name).begins_with("Spark"))

## 지금 캐릭터·단계를 기본 자리로
func _reset_current() -> void:
	if data == null:
		return
	data.entries.erase(character + "|" + stage)
	ResourceSaver.save(data)
	_save_pending = false
	_loaded = ""
	_load_character()

## 편집 조각들의 지금 자리를 자리표 한 줄로
func _capture() -> Dictionary:
	var out: Dictionary = {}
	var sizes: Array = []
	for part_name in _limb_names():
		var node := get_node_or_null(part_name) as Sprite2D
		if node == null:
			continue
		out[part_name] = [node.position, node.rotation, node.scale]
		sizes.append(absf(node.scale.x) / maxf(_rest_scale_x * _fit, 0.0001))
		for child in node.get_children():
			if _is_mark(child):
				var mark := child as Sprite2D
				var path: String = mark.texture.resource_path if mark.texture else ""
				out["%s/%s" % [part_name, mark.name]] = [mark.position, mark.rotation, mark.scale, path]
	if not sizes.is_empty():
		var total: float = 0.0
		for v in sizes:
			total += v
		out["size"] = total / sizes.size()
	return out

## 조각·핏줄·반짝이 자리를 한 줄 글자로 — 바뀌었는지 비교용
func _signature() -> String:
	var parts: PackedStringArray = []
	for part_name in _limb_names():
		var node := get_node_or_null(part_name) as Sprite2D
		if node == null:
			continue
		parts.append("%s:%s:%s" % [part_name, node.position, node.scale])
		for child in node.get_children():
			if _is_mark(child):
				var mark := child as Sprite2D
				parts.append("%s:%s:%.4f:%s:%s" % [mark.name, mark.position, mark.rotation, mark.scale,
					mark.texture.resource_path if mark.texture else ""])
	return "|".join(parts)
