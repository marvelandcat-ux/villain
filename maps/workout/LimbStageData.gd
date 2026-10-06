@tool
extends Resource

## **바벨 컬(손)·스쿼트(발) 단계별 변화 자리표** — 두 운동은 부위만 다르고 똑같다(2026-10-06 사용자 지정).
##
## | 스택 | 변화 |
## |---|---|
## | 1~3 | 그대로(능력치만 오른다) |
## | 4~6 | 조금 커지고 핏줄(💢) 하나가 울끈불끈 |
## | 7~9 | 1.5배, 핏줄 셋 |
## | 10 | 금빛 + 주위에 다이아몬드 반짝이. 다 채우는 순간 빵빠레 |
##
## 캐릭터·단계마다 **손(발) 자리·크기, 핏줄·반짝이 자리**를 적어 둔다.
## 고치는 곳: `maps/workout/Curl*Studio.tscn`(바벨 컬) / `Squat*Studio.tscn`(스쿼트) — 단계마다 한 장.
## 적힌 게 없는 캐릭터는 리그 제자리 + 아래 기본 크기 + 기본 핏줄 자리를 쓴다(`default_entry`)

const GEAR := preload("res://maps/workout/TreadmillGearData.gd")
const STAGE_NONE := ""
const STAGE_VEIN1 := "vein1"
const STAGE_VEIN3 := "vein3"
const STAGE_GOLD := "gold"

## 어느 부위인지 — hands(바벨 컬) / feet(스쿼트)
@export_enum("hands", "feet") var limb: String = "hands"
## 각 단계가 시작되는 스택
@export var vein1_from: int = 4
@export var vein3_from: int = 7
@export var gold_from: int = 10
## 단계별 기본 크기(원래 크기의 몇 배) — 편집 씬에서 손(발)을 키우면 그 캐릭터 값이 따로 적힌다
@export var size_vein1: float = 1.25
@export var size_vein3: float = 1.5
@export var size_gold: float = 1.5
## 핏줄(💢) 그림들 — 여러 장이면 핏줄마다 돌려 가며 쓴다
@export var vein_textures: Array[Texture2D] = []
## 금빛 단계 반짝이(다이아몬드) 그림
@export var sparkle_texture: Texture2D
## 금빛 단계에 **바꿔 낄 그림**(바벨 컬은 금빛 주먹). 비우면 원래 그림에 금빛 셰이더를 입힌다(스쿼트 발)
@export var gold_texture: Texture2D
## 고쳐 둔 자리들 {"캐릭터|단계": {"HandL": [위치, 각도, 크기], "size": 배수, "HandR/Vein1": [위치, 각도, 크기, 그림 경로], ...}}
@export var entries: Dictionary = {}

## 이 운동이 바꾸는 조각 이름 [뒤, 앞]
func part_names() -> Array:
	return ["HandL", "HandR"] if limb == "hands" else ["FootL", "FootR"]

func stage_of(stack: int) -> String:
	if stack >= gold_from:
		return STAGE_GOLD
	if stack >= vein3_from:
		return STAGE_VEIN3
	if stack >= vein1_from:
		return STAGE_VEIN1
	return STAGE_NONE

func default_size(stage: String) -> float:
	match stage:
		STAGE_VEIN1:
			return size_vein1
		STAGE_VEIN3:
			return size_vein3
		STAGE_GOLD:
			return size_gold
	return 1.0

## 그 단계에 바꿔 낄 그림(없으면 null = 원래 그림)
func stage_texture(stage: String) -> Texture2D:
	return gold_texture if stage == STAGE_GOLD else null

## 그 단계에 금빛 셰이더를 입히는지(바꿔 낄 금빛 그림이 없을 때)
func uses_gold_shader(stage: String) -> bool:
	return stage == STAGE_GOLD and gold_texture == null

## 바꿔 낀 그림이 **원래 손(발)과 같은 크기로 보이게** 곱할 배율(불투명한 가로 길이로 맞춘다)
func texture_fit(rest: Dictionary, tex: Texture2D) -> float:
	if tex == null:
		return 1.0
	var orig: Texture2D = rest.get(part_names()[0], {}).get("texture") as Texture2D
	if orig == null:
		return 1.0
	return GEAR.opaque_rect(orig).size.x / maxf(GEAR.opaque_rect(tex).size.x, 1.0)

func entry(character: String, stage: String) -> Dictionary:
	return entries.get(character + "|" + stage, {})

func set_entry(character: String, stage: String, value: Dictionary) -> void:
	entries[character + "|" + stage] = value
	emit_changed()

## **적어 둔 게 없을 때 쓰는 기본 자리.** rest는 리그 제자리(`BodyRig.stage_rest_info()`·`RigReader.read()` 꼴).
## 핏줄은 앞쪽 손(발) 위쪽에(셋이면 앞에 둘·뒤에 하나), 반짝이는 두 손(발) 둘레에 셋씩
func default_entry(rest: Dictionary, stage: String) -> Dictionary:
	var out: Dictionary = {"size": default_size(stage)}
	var names: Array = part_names()
	for part_name in names:
		if rest.has(part_name):
			out[part_name] = [rest[part_name]["position"], 0.0, Vector2.ONE]
	var back: String = names[0]
	var front: String = names[1]
	if not rest.has(front):
		return out
	var tex: Texture2D = stage_texture(stage)
	if tex == null:
		tex = rest[front].get("texture") as Texture2D
	if tex == null:
		return out
	var box: Rect2 = GEAR.opaque_rect(tex)
	# 조각 그림 안 좌표(그림 한가운데가 원점)로 본 불투명 영역 가운데
	var center: Vector2 = box.get_center() - tex.get_size() * 0.5
	var veins: Array = []
	match stage:
		STAGE_VEIN1:
			veins = [[front, Vector2(0.12, -0.2)]]
		STAGE_VEIN3:
			veins = [[front, Vector2(0.12, -0.2)], [front, Vector2(-0.18, 0.12)], [back, Vector2(0.05, -0.18)]]
	for i in veins.size():
		if vein_textures.is_empty():
			break
		var vein_tex: Texture2D = vein_textures[i % vein_textures.size()]
		var vein_box: Rect2 = GEAR.opaque_rect(vein_tex)
		var k: float = box.size.x * 0.55 / maxf(vein_box.size.x, 1.0)
		var target: Vector2 = center + box.size * (veins[i][1] as Vector2)
		# 핏줄 그림은 한가운데 기준으로 그려지니 불투명한 가운데가 target에 오게 되돌린다
		var pos: Vector2 = target - (vein_box.get_center() - vein_tex.get_size() * 0.5) * k
		out["%s/Vein%d" % [veins[i][0], i + 1]] = [pos, 0.0, Vector2(k, k), vein_tex.resource_path]
	if stage == STAGE_GOLD and sparkle_texture != null:
		var spark_box: Rect2 = GEAR.opaque_rect(sparkle_texture)
		var k: float = box.size.x * 0.32 / maxf(spark_box.size.x, 1.0)
		var angles: Array = [-55.0, 35.0, 165.0]
		for part_name in names:
			for j in angles.size():
				var dir := Vector2.from_angle(deg_to_rad(angles[j]))
				var target: Vector2 = center + dir * box.size.x * 0.62
				var pos: Vector2 = target - (spark_box.get_center() - sparkle_texture.get_size() * 0.5) * k
				out["%s/Spark%d" % [part_name, j + 1]] = [pos, 0.0, Vector2(k, k), sparkle_texture.resource_path]
	return out
