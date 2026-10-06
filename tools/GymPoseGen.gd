@tool
extends Node

## **캐릭터별 헬스장 자세·편집 씬 만들기**(2026-10-06 사용자 요청: "캐릭터별로 다 만들어 줘").
##
## 운동 자세(`characters/gym/Gym*Pose.tscn`)는 원래 **한 벌을 전 캐릭터가 같이 썼다.** 그런데
## `BodyRig`는 그 자세에서 **자리와 각도만** 읽어 쓰므로(`_apply_pose_scene`), 팔 길이·머리 크기가
## 다른 캐릭터에게 같은 자리를 먹이면 바벨이 손을 벗어나거나 머리가 묻힌다.
##
## 그래서 캐릭터마다 **자기 그림으로 된 자세 아홉 장**과 **그걸 보면서 고치는 편집 씬 셋**을 만든다.
##  - 자세: `characters/<폴더>/gym/<이름>CurlDownPose.tscn` ... (컬 3 / 스쿼트 3 / 달리기 3)
##  - 편집 씬: `characters/<폴더>/gym/<이름>CurlStudio.tscn` ... (F6로 열면 그 캐릭터가 운동한다)
##
## 만드는 법은 "같이 쓰던 자세를 복사해 **그림만 그 캐릭터 것으로 갈아 끼우는**" 것이다 —
## 자리·각도는 그대로 두고 시작점으로 삼는다. 거기서부터는 사람이 눈으로 보고 고친다.
##
## ⚠️ **이미 있는 파일은 절대 안 건드린다.** 손으로 고쳐 둔 자세를 덮어쓰면 안 되기 때문에,
## 캐릭터를 새로 추가했을 때 다시 돌려도 **없는 것만** 생긴다

const RIG_READER := preload("res://maps/workout/RigReader.gd")

## 같이 쓰던 자세 한 벌 — [운동, 칸 이름, 원본 경로]
const SOURCE_POSES: Array = [
	["Curl", "Down", "res://characters/gym/GymCurlDownPose.tscn"],
	["Curl", "Mid", "res://characters/gym/GymCurlMidPose.tscn"],
	["Curl", "Up", "res://characters/gym/GymCurlUpPose.tscn"],
	["Squat", "Up", "res://characters/gym/GymSquatUpPose.tscn"],
	["Squat", "Mid", "res://characters/gym/GymSquatMidPose.tscn"],
	["Squat", "Down", "res://characters/gym/GymSquatDownPose.tscn"],
	["Run", "Left", "res://characters/gym/GymRunLeftPose.tscn"],
	["Run", "Mid", "res://characters/gym/GymRunMidPose.tscn"],
	["Run", "Right", "res://characters/gym/GymRunRightPose.tscn"],
]

## **변신 단계 편집 씬 원본** — [꼬리 이름, 원본 경로].
## 이 씬들은 원래 `character`를 바꿔 가며 쓰게 만들어져 있지만(한 씬으로 전 캐릭터),
## **캐릭터마다 한 장씩** 뽑아 두면 그 캐릭터 폴더에서 바로 열 수 있다(2026-10-06 사용자 요청).
## 고친 자리는 어느 쪽으로 열든 같은 `.tres`(`TreadmillGear.tres`)의 **그 캐릭터 칸**에 저장된다
## **장비를 낀 상태의 자세 한 벌**을 따로 만들 캐릭터들. 로켓을 신으면 발이 없어지고 몸이 떠서
## 팔다리 각이 달라야 자연스럽다 — 평소 자세와 **따로 둔다**(리그의 `*_pose_gear` 칸).
## 2026-10-06 사용자가 "악플러로 기준 잡겠다"고 해서 악플러만 먼저 뽑는다.
## 기준이 잡히면 여기 이름을 더해 다른 캐릭터에게도 뽑으면 된다
@export var gear_characters: PackedStringArray = PackedStringArray(["악플러"])
## 그 자세가 어느 장비 단계를 전제로 하는지(편집 씬이 이 장비를 끼고 띄운다)
@export_enum("bike", "car", "rocket") var gear_stage: String = "rocket"

## 장비 상태로 베껴 갈 자세 — [운동, 칸 이름]. 원본은 **그 캐릭터의 평소 자세**다
const GEAR_POSES: Array = [
	["Curl", "Down"], ["Curl", "Mid"], ["Curl", "Up"],
	["Squat", "Up"], ["Squat", "Mid"], ["Squat", "Down"],
]
## 장비 상태 편집 씬 — [운동, 자세 세 장의 칸 이름]
const GEAR_STUDIOS: Array = [
	["Curl", ["Down", "Mid", "Up"]],
	["Squat", ["Up", "Mid", "Down"]],
]

const SOURCE_STAGES: Array = [
	["Bike", "res://maps/workout/TreadmillBikeStudio.tscn"],
	["Car", "res://maps/workout/TreadmillCarStudio.tscn"],
	["Rocket", "res://maps/workout/TreadmillRocketStudio.tscn"],
]

## 편집 씬 원본 — [운동, 원본 경로, 자세 세 장의 칸 이름]
const SOURCE_STUDIOS: Array = [
	["Curl", "res://maps/GymCurlStudio.tscn", ["Down", "Mid", "Up"]],
	["Squat", "res://maps/GymSquatStudio.tscn", ["Up", "Mid", "Down"]],
	["Run", "res://maps/GymRunStudio.tscn", ["Left", "Mid", "Right"]],
]

## 자세 씬의 조각 이름 -> 리그에서 베껴 올 조각.
## `HeadView`는 **보기용 머리**(컬은 머리를 안 움직인다), `HandR2`·`FootL2`는 잔상용 덧그림이다
const PART_SOURCE := {
	"FootL": "FootL", "FootL2": "FootL", "FootR": "FootR", "Body": "Body",
	"HandL": "HandL", "HandR": "HandR", "HandR2": "HandR",
	"Head": "Head", "HeadView": "Head",
}

## 그림과 함께 베껴 오는 값들 — **자리(position)와 각도(rotation)는 일부러 뺐다.**
## 그 둘이 "자세"이고, 나머지는 "그 캐릭터가 원래 어떻게 생겼나"다
const COPY_KEYS: Array[String] = ["texture", "scale", "offset", "centered", "flip_h",
	"region_enabled", "region_rect", "z_index"]

func _ready() -> void:
	var made: int = 0
	var skipped: int = 0
	for who in _all_rigs():
		var rig_path: String = String(_all_rigs()[who])
		if rig_path == "" or not ResourceLoader.exists(rig_path):
			continue
		var dir: String = rig_path.get_base_dir().path_join("gym")
		var prefix: String = rig_path.get_file().trim_suffix("Rig.tscn")
		DirAccess.make_dir_recursive_absolute(dir)
		var parts: Dictionary = RIG_READER.read_path(rig_path)
		if parts.is_empty():
			print("  [건너뜀] %s — 리그를 못 읽었다" % who)
			continue
		for row in SOURCE_POSES:
			var out: String = dir.path_join("%s%s%sPose.tscn" % [prefix, row[0], row[1]])
			if ResourceLoader.exists(out):
				skipped += 1
				continue
			if _make_pose(row[2], out, parts, _studio_path(dir, prefix, row[0])):
				made += 1
		for row in SOURCE_STUDIOS:
			var out: String = _studio_path(dir, prefix, row[0])
			if ResourceLoader.exists(out):
				skipped += 1
				continue
			if _make_studio(row[1], out, rig_path, dir, prefix, row[0], row[2]):
				made += 1
		for row in SOURCE_STAGES:
			var out: String = _studio_path(dir, prefix, row[0])
			if ResourceLoader.exists(out):
				skipped += 1
				continue
			if _make_stage_studio(row[1], out, who, "%s%sStudio" % [prefix, row[0]]):
				made += 1
		if gear_characters.has(who):
			var tag: String = gear_stage.capitalize()
			for row in GEAR_POSES:
				var src: String = dir.path_join("%s%s%sPose.tscn" % [prefix, row[0], row[1]])
				var out: String = dir.path_join("%s%s%s%sPose.tscn" % [prefix, tag, row[0], row[1]])
				if ResourceLoader.exists(out) or not ResourceLoader.exists(src):
					skipped += 1
					continue
				if _copy_pose(src, out, dir.path_join("%s%s%sStudio.tscn" % [prefix, tag, row[0]])):
					made += 1
			for row in GEAR_STUDIOS:
				var out: String = dir.path_join("%s%s%sStudio.tscn" % [prefix, tag, row[0]])
				if ResourceLoader.exists(out):
					skipped += 1
					continue
				if _make_gear_studio(dir, prefix, tag, row[0], row[1], out):
					made += 1
		print("%s -> %s" % [who, dir])
	print("새로 만든 씬 %d개 / 이미 있어 건너뛴 것 %d개" % [made, skipped])
	if not Engine.is_editor_hint():
		get_tree().quit()

## 자세를 만들어 줄 리그 전부 {이름: 씬 경로}. **`RigReader` 목록 하나만 본다** —
## 같은 목록을 두 군데 적어 두면 캐릭터를 늘릴 때 한쪽만 고치게 된다
func _all_rigs() -> Dictionary:
	var out: Dictionary = {}
	for who in RIG_READER.names():
		out[who] = RIG_READER.path_of(who)
	return out

func _studio_path(dir: String, prefix: String, motion: String) -> String:
	return dir.path_join("%s%sStudio.tscn" % [prefix, motion])

## 같이 쓰던 자세 한 장을 그 캐릭터 그림으로 갈아 끼워 저장한다
func _make_pose(src_path: String, out_path: String, parts: Dictionary, studio_path: String) -> bool:
	var scene := load(src_path) as PackedScene
	if scene == null:
		return false
	var root: Node = scene.instantiate()
	if root == null:
		return false
	for child in root.get_children():
		var sprite := child as Sprite2D
		if sprite == null or not PART_SOURCE.has(sprite.name):
			continue   # 바벨·원판처럼 **기구는 그대로 둔다**
		var data: Dictionary = parts.get(PART_SOURCE[sprite.name], {})
		for key in COPY_KEYS:
			if data.has(key):
				sprite.set(key, data[key])
	# F6로 이 자세를 열면 **그 캐릭터의 편집 씬**이 열리게 한다
	if "alone_opens_scene" in root:
		root.alone_opens_scene = studio_path
	return _save(root, out_path)

## 편집 씬 원본을 베껴 리그와 자세 세 장만 그 캐릭터 것으로 바꾼다.
## 런닝머신 기구 자리·배율 같은 나머지 설정은 원본 그대로 물려받는다
func _make_studio(src_path: String, out_path: String, rig_path: String, dir: String,
		prefix: String, motion: String, frames: Array) -> bool:
	var scene := load(src_path) as PackedScene
	if scene == null:
		return false
	var root: Node = scene.instantiate()
	if root == null:
		return false
	root.name = "%s%sStudio" % [prefix, motion]
	if "rig_scene" in root:
		root.rig_scene = load(rig_path)
	var keys: Array[String] = ["pose_a", "pose_b", "pose_c"]
	for i in 3:
		var pose_path: String = dir.path_join("%s%s%sPose.tscn" % [prefix, motion, frames[i]])
		if keys[i] in root and ResourceLoader.exists(pose_path):
			root.set(keys[i], load(pose_path))
	return _save(root, out_path)

## 평소 자세 한 장을 **장비 상태용으로 베껴** 둔다. 값은 그대로 두고 F6 연결만 새 편집 씬으로 바꾼다 —
## 여기서부터는 사람이 눈으로 보고 고친다(발이 없어진 만큼 팔다리를 다시 잡아야 한다)
func _copy_pose(src_path: String, out_path: String, studio_path: String) -> bool:
	var scene := load(src_path) as PackedScene
	if scene == null:
		return false
	var root: Node = scene.instantiate()
	if root == null:
		return false
	if "alone_opens_scene" in root:
		root.alone_opens_scene = studio_path
	return _save(root, out_path)

## 장비 상태 편집 씬 한 장. 그 캐릭터의 평소 편집 씬을 베껴 **장비를 끼우고** 자세 셋만 갈아 끼운다
func _make_gear_studio(dir: String, prefix: String, tag: String, motion: String,
		frames: Array, out_path: String) -> bool:
	var src: String = dir.path_join("%s%sStudio.tscn" % [prefix, motion])
	var scene := load(src) as PackedScene
	if scene == null:
		return false
	var root: Node = scene.instantiate()
	if root == null:
		return false
	root.name = "%s%s%sStudio" % [prefix, tag, motion]
	if "gear_stage" in root:
		root.gear_stage = gear_stage
	var keys: Array[String] = ["pose_a", "pose_b", "pose_c"]
	for i in 3:
		var pose_path: String = dir.path_join("%s%s%s%sPose.tscn" % [prefix, tag, motion, frames[i]])
		if keys[i] in root and ResourceLoader.exists(pose_path):
			root.set(keys[i], load(pose_path))
	return _save(root, out_path)

## 단계 편집 씬(자전거·스포츠카·로켓) 한 장을 그 캐릭터용으로 뽑는다.
##
## 원본을 베껴 **`character`만 그 캐릭터로 박아 둔다.** 조각 그림·자리는 트리에 붙는 순간
## `_ready()` -> `_load_character()`가 리그와 `.tres`를 보고 알아서 채운다 — 여기서 손으로 베낄 필요가 없다.
##
## ⚠️ **프레임을 넘기지 않는다.** 이 씬들은 `_process`에서 "조각이 움직였나" 보고 `.tres`에 바로 저장하는데,
## 한 프레임이라도 돌면 기본값을 그대로 저장해 버린다. add_child -> pack -> free 를 한 호흡에 끝낸다
func _make_stage_studio(src_path: String, out_path: String, who: String, node_name: String) -> bool:
	var scene := load(src_path) as PackedScene
	if scene == null:
		return false
	var root: Node = scene.instantiate()
	if root == null:
		return false
	root.name = node_name
	if "character" in root:
		root.character = who
	# 트리에 넣어야 `_ready()`가 돌아 그 캐릭터 몸으로 바뀐다
	add_child(root)
	root.set_process(false)
	remove_child(root)
	return _save(root, out_path)

## 노드를 씬 파일로 저장한다. **자식마다 owner를 박아야** PackedScene에 담긴다
func _save(root: Node, out_path: String) -> bool:
	for child in root.get_children():
		child.owner = root
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		root.free()
		return false
	var err: int = ResourceSaver.save(packed, out_path)
	root.free()
	if err != OK:
		print("  [실패 %d] %s" % [err, out_path])
		return false
	return true
