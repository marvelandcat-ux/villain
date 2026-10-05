@tool
extends RefCounted

## 헬스장 단계 편집 씬들(`Treadmill*Studio`·`Curl*Studio`·`Squat*Studio`)이 같이 쓰는 **캐릭터 리그 읽기**.
## 리그 씬을 화면에 올리지 않고 조각 그림·제자리만 뽑는다 — 기본 자세 씬(rest_pose)이 있으면 리그가 켜질 때처럼 먼저 입힌다

const GAME_STATE_PATH := "res://GameState.gd"
## 읽어 오는 리그 조각들
const RIG_PARTS: Array[String] = ["FootL", "FootR", "Body", "Head", "HandL", "HandR"]

## 리그가 있는 캐릭터 이름들(`GameState.CHARACTER_RIGS`)
static func names() -> PackedStringArray:
	return PackedStringArray(_rigs().keys())

static func _rigs() -> Dictionary:
	var script := load(GAME_STATE_PATH) as GDScript
	if script == null:
		return {}
	return script.get_script_constant_map().get("CHARACTER_RIGS", {})

## 캐릭터 리그의 조각별 {position, rotation, scale, texture, offset, centered, flip_h, region_enabled, region_rect, z_index}
static func read(who: String) -> Dictionary:
	var path: String = String(_rigs().get(who, ""))
	if path == "" or not ResourceLoader.exists(path):
		return {}
	var rig: Node = (load(path) as PackedScene).instantiate()
	var out: Dictionary = {}
	for part_name in RIG_PARTS:
		var part := rig.get_node_or_null(part_name) as Sprite2D
		if part == null:
			continue
		out[part_name] = {
			"position": part.position, "rotation": part.rotation, "scale": part.scale,
			"texture": part.texture, "offset": part.offset, "centered": part.centered,
			"flip_h": part.flip_h, "region_enabled": part.region_enabled, "region_rect": part.region_rect,
			"z_index": part.z_index,
		}
	var rest_pose = rig.get("rest_pose")
	if rest_pose is PackedScene:
		var pose: Node = (rest_pose as PackedScene).instantiate()
		for part_name in out:
			var p := pose.find_child(part_name, true, false) as Node2D
			if p == null:
				continue
			out[part_name]["position"] = p.position
			out[part_name]["rotation"] = p.rotation
			out[part_name]["scale"] = p.scale
			if p is Sprite2D:
				out[part_name]["flip_h"] = (p as Sprite2D).flip_h
		pose.free()
	rig.free()
	return out

## 리그 조각의 겉모습(그림·크기·각도·순서)을 편집 조각에 입힌다
static func copy_look(node: Sprite2D, part: Dictionary) -> void:
	node.texture = part["texture"]
	node.offset = part["offset"]
	node.centered = part["centered"]
	node.flip_h = part["flip_h"]
	node.region_enabled = part["region_enabled"]
	node.region_rect = part["region_rect"]
	node.z_index = part["z_index"]
	node.rotation = part["rotation"]
	node.scale = part["scale"]
