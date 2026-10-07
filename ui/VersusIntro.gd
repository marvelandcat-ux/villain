class_name VersusIntro
extends CanvasLayer

## 스토리 모드에서 대전에 들어가기 전 "주인공 VS 적" 매치업을 보여주는 화면.
## Stage.gd가 _ready() 맨 앞에서(캐릭터를 스폰하기도 전에) 이 씬을 띄우고 finished를 기다린 뒤
## 나머지(스폰 → 3,2,1,FIGHT 카운트다운)를 진행한다. 아직 Fighter가 없는 시점이라
## GameState.p1_character_path/p2_character_path 값만으로 이름·색·초상화를 채운다.
##
## (2026-09-29 개편) 컨셉아트대로 바꿨다 — 화면을 비스듬히 자른 **사다리꼴 두 장**이
## 양옆에서 날아와 가운데서 쾅 부딪히고, 이음새에서 불꽃이 터지고, 캐릭터가 흔들린다.
## 2초 멈췄다가 맵 선택 뒤와 같은 **홀로그램 타일 전환**으로 대전 화면에 넘겨준다.
##
## 순서: 날아옴 → 충돌(불꽃+흔들림+VS 등장) → 2초 유지 → 타일로 덮기 → finished.
## **덮은 채로 넘긴다** — Stage가 그 뒤에서 캐릭터를 스폰하고, 다 되면 SceneTransition.uncover()로 걷어낸다

## 연출이 다 끝났을 때 — Stage.gd가 이걸 기다린 뒤 캐릭터를 스폰한다.
## 이 시점에 화면은 이미 홀로그램 타일로 덮여 있다
signal finished

## 여기 쓰는 캐릭터 그림은 **인게임 몸(BodyRig)을 그대로 띄운 것**이다 —
## 컨셉아트도 게임에 들어간 부품(머리·몸통·손·발)을 맞춰 그린 것이라, 따로 그림을 만들 게 아니라
## 실제 쓰는 리그를 그대로 크게 보여주는 게 맞다. 캐릭터 부품을 고치면 VS 화면도 같이 바뀐다.
##
## 대부분은 GameState.CHARACTER_RIGS에 있고, **주인공(경찰)만 거기 빠져 있어서** 여기서 직접 잡아준다
const EXTRA_RIGS := {
	"주인공": "res://characters/police/PoliceRig.tscn",
	"일진": "res://characters/iljin/IljinRig.tscn",
}
## **VS 화면 전용 포즈 씬.** 여기 적힌 캐릭터는 인게임 리그 대신 이 씬을 띄운다.
## 포즈 씬은 머리·몸·손·발·무기가 전부 그냥 Sprite2D라서, 씬을 열어 **하나씩 집어서 끌면**
## 격돌 화면에서만 자리가 바뀐다(인게임 캐릭터는 그대로다).
## 여기 없는 캐릭터는 인게임 리그를 그대로 쓰고, 머리만 아래 VERSUS_HEADS로 갈아 끼운다
const VERSUS_POSES := {
	"주인공": "res://ui/versus/PoliceVersusPose.tscn",
	"금쪽이": "res://ui/versus/ChokbeopsonyeonVersusPose.tscn",
	"악플러": "res://ui/versus/AkpeulleoVersusPose.tscn",
}
## 포즈 씬을 그린 기준 화면 높이(px). 화면이 이보다 크면 그 비율만큼 통째로 커진다
const POSE_REFERENCE_HEIGHT := 720.0

## 포즈 씬이 없는 캐릭터의 머리만 갈아 끼울 때 쓴다 — **격돌 장면이니 평소 얼굴 대신 화난 얼굴**을 쓴다.
## 인게임 리그(characters/…Rig.tscn)는 안 건드린다. 여기 없는 캐릭터는 리그에 달린 머리 그대로다.
## **원래 머리와 그림 크기가 같아야 한다**(경찰은 둘 다 1330x1182) — 다르면 머리만 커지거나 자리가 밀린다
const VERSUS_HEADS := {
	"주인공": "res://sprite/storymode/경찰서/분노경찰관.png",
}
## **포즈 씬 전용 배율.** 포즈 씬은 자동 맞춤을 안 하고 씬에 그린 크기 그대로 나온다 —
## 부품을 옮겨도 전체 크기가 안 변해서, 에디터에서 보이는 그대로 화면에 뜬다
@export var pose_scale: float = 1.0
## 포즈 씬의 원점(머리 한가운데)이 화면 세로 어디에 놓일지 (0~1)
@export_range(0.0, 1.0, 0.01) var pose_anchor_y: float = 0.31

## **포즈 씬이 없는 캐릭터에만** 쓰는 자동 맞춤 배율. 칸을 꽉 채우는 크기 대비 값이다
@export var rig_zoom: float = 0.72
## 발끝이 칸 높이의 몇 %에 오는지. 1이면 칸 맨 아래에 딱 선다
@export_range(0.6, 1.2, 0.01) var rig_bottom: float = 1.0
## 사다리꼴이 화면 밖에서 날아 들어오는 데 걸리는 시간(초)
@export var slam_time: float = 0.28
## 부딪힌 뒤 그대로 멈춰 보여주는 시간(초)
@export var hold_time: float = 2.0
## 충돌 직후 흔들리는 시간(초)
@export var shake_time: float = 0.4
## 화면 전체가 흔들리는 폭(px)
@export var banner_shake: float = 18.0
## 캐릭터 둘이 각자 흔들리는 폭(px) — 서로 반대 방향으로 밀린다
@export var portrait_shake: float = 11.0
## 흔들리는 속도(클수록 파르르 떤다)
@export var shake_speed: float = 58.0

@onready var _root: Control = $Root
@onready var _banner: Control = $Root/Banner
@onready var _p1_half: VersusHalf = $Root/Banner/P1Half
@onready var _p2_half: VersusHalf = $Root/Banner/P2Half
@onready var _p1_box: Control = $Root/Banner/P1Half/P1Box
@onready var _p2_box: Control = $Root/Banner/P2Half/P2Box
@onready var _p1_image: TextureRect = $Root/Banner/P1Half/P1Box/P1Image
@onready var _p2_image: TextureRect = $Root/Banner/P2Half/P2Box/P2Image
@onready var _p1_name_label: Label = $Root/Banner/P1Half/P1NameLabel
@onready var _p2_name_label: Label = $Root/Banner/P2Half/P2NameLabel
@onready var _sparks: VersusSparks = $Root/Banner/Sparks
@onready var _vs_label: Label = $Root/Banner/VsLabel

## 흔들림이 끝나면 제자리로 되돌려야 해서 원래 자리를 기억해 둔다
var _shake_left: float = 0.0
var _banner_home: Vector2 = Vector2.ZERO
var _p1_home: Vector2 = Vector2.ZERO
var _p2_home: Vector2 = Vector2.ZERO

func _ready() -> void:
	set_process(false)
	# 그림을 넣는 것도, 날아올 거리를 재는 것도 **칸 크기가 잡힌 뒤에** 해야 한다
	await get_tree().process_frame
	_fill_side(_p1_box, _p1_image, _p1_name_label, GameState.p1_character_path, 1.0)
	_fill_side(_p2_box, _p2_image, _p2_name_label, GameState.p2_character_path, -1.0)
	_play_intro()

## 칸에 인게임 몸을 세운다. 리그가 없는 캐릭터만 초상화 그림으로 대신한다.
## facing이 -1이면 좌우로 뒤집는다 — **둘이 서로 마주 보게** 하려고 오른쪽 캐릭터만 뒤집는다
func _fill_side(box: Control, image: TextureRect, name_label: Label, character_path: String, facing: float) -> void:
	var character_name: String = _find_character_name(character_path)
	name_label.text = character_name
	var rig: Node2D = _make_rig(character_name)
	if rig != null:
		image.texture = null
		box.add_child(rig)
		_swap_head(rig, character_name)
		if VERSUS_POSES.has(character_name):
			_place_pose(box, rig, facing)
		else:
			_fit_rig(box, rig, facing)
		return
	# 리그가 없으면 도감·HUD에 쓰는 초상화로 대신한다 (지금은 전원 리그가 있어서 여기까지 안 온다)
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture = GameState.portrait_texture(character_name) if GameState.has_portrait(character_name) else null

## VS 화면 전용 머리로 갈아 끼운다. 갈아 끼울 게 없으면 아무것도 안 한다.
## **포즈 씬을 쓰는 캐릭터는 건너뛴다** — 그쪽은 씬에 이미 원하는 머리가 꽂혀 있고,
## 여기서 또 바꾸면 씬에서 고른 머리가 무시돼서 헷갈린다
func _swap_head(rig: Node2D, character_name: String) -> void:
	if VERSUS_POSES.has(character_name):
		return
	var path: String = str(VERSUS_HEADS.get(character_name, ""))
	if path == "":
		return
	var head: Sprite2D = rig.get_node_or_null("Head") as Sprite2D
	if head == null:
		return
	head.texture = load(path)
	# **눈 깜빡임은 끈다** — 평소 얼굴 눈 위치·크기에 맞춰 둔 것이라 화난 얼굴에 그대로 쓰면
	# 눈이 아닌 데서 눈꺼풀이 내려온다. 격돌 화면은 2초 남짓이라 안 깜빡여도 어색하지 않다
	var blink: Node2D = head.get_node_or_null("EyeBlink") as Node2D
	if blink != null:
		blink.visible = false

func _make_rig(character_name: String) -> Node2D:
	# 포즈 씬이 있으면 그걸 먼저 쓴다 — 격돌 화면 전용으로 자리를 잡아 둔 씬이다
	var pose: String = str(VERSUS_POSES.get(character_name, ""))
	if pose != "":
		var node: Node2D = (load(pose) as PackedScene).instantiate() as Node2D
		# 포즈 씬 안의 에디터용 미리보기(배경·상대 캐릭터)는 게임에선 지운다
		for child in node.get_children():
			if child is VersusPosePreview:
				node.remove_child(child)
				child.queue_free()
		return node
	var path: String = str(EXTRA_RIGS.get(character_name, ""))
	var scene: PackedScene = load(path) if path != "" else GameState.character_rig_scene(character_name)
	if scene == null:
		return null
	# Fighter 없이 띄우면 BodyRig는 걷지 않고 가만히 숨쉬는 동작만 돈다 — VS 화면에 딱 맞는다
	return scene.instantiate() as Node2D

## 포즈 씬을 놓는다. **크기를 자동으로 안 맞춘다** — 씬에 그린 그대로 쓰고,
## 화면 높이가 기준(720)과 다를 때만 그 비율로 통째로 키운다.
## 원점(머리 한가운데)이 칸 가운데·화면 세로 pose_anchor_y 자리에 온다
func _place_pose(box: Control, pose: Node2D, facing: float) -> void:
	var k: float = (_banner.size.y / POSE_REFERENCE_HEIGHT) * maxf(pose_scale, 0.01)
	pose.scale = Vector2(k * signf(facing), k)
	pose.position = Vector2(box.size.x * 0.5, _banner.size.y * pose_anchor_y - box.position.y)

## 리그가 실제로 차지하는 크기를 재서 칸에 맞춰 키우고, 발끝을 칸 아래에 맞춘다.
## **부품 위치를 직접 재야 한다** — 캐릭터마다 머리 크기·팔 길이가 제각각이라
## 고정 배율을 주면 누구는 넘치고 누구는 쪼그라든다
func _fit_rig(box: Control, rig: Node2D, facing: float) -> void:
	rig.scale = Vector2.ONE
	rig.position = Vector2.ZERO
	var bounds: Rect2 = _rig_bounds(rig)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var fit: float = minf(box.size.x / bounds.size.x, box.size.y / bounds.size.y) * maxf(rig_zoom, 0.01)
	rig.scale = Vector2(fit * signf(facing), fit)
	var center_x: float = bounds.position.x + bounds.size.x * 0.5
	rig.position = Vector2(
		box.size.x * 0.5 - fit * signf(facing) * center_x,
		box.size.y * rig_bottom - fit * bounds.end.y,
	)

## 리그 안의 Sprite2D를 전부 훑어 리그 기준 좌표로 합친 네모를 돌려준다
func _rig_bounds(rig: Node2D) -> Rect2:
	var to_rig: Transform2D = rig.get_global_transform().affine_inverse()
	var out := Rect2()
	var started: bool = false
	for node in _all_sprites(rig):
		if node.texture == null or not node.visible:
			continue
		var r: Rect2 = node.get_rect()
		var t: Transform2D = to_rig * node.get_global_transform()
		for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			var p: Vector2 = t * corner
			if not started:
				out = Rect2(p, Vector2.ZERO)
				started = true
			else:
				out = out.expand(p)
	return out

func _all_sprites(node: Node) -> Array[Sprite2D]:
	var found: Array[Sprite2D] = []
	if node is Sprite2D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_all_sprites(child))
	return found

## 캐릭터 씬 경로로 등록된 표시 이름을 역으로 찾는다.
## **대전 로스터(CHARACTERS)뿐 아니라 훈련장 전용 캐릭터까지 봐야 한다** —
## 스토리 주인공(경찰)이 `TRAINING_ONLY_CHARACTERS`에 있어서, 예전엔 여기서 못 찾고
## 이름이 "?"로 떴다(2026-09-14 발견)
func _find_character_name(path: String) -> String:
	var roster: Dictionary = GameState.training_characters()
	for character_name in roster.keys():
		if roster[character_name] == path:
			return character_name
	return "?"

## 양옆에서 날아와 부딪히고, 불꽃이 터지고, 2초 멈췄다가 타일로 덮인다
func _play_intro() -> void:
	# 사다리꼴의 제일 튀어나온 꼭짓점(가운데에서 lean만큼)까지 화면 밖으로 빼야 완전히 안 보인다
	var away: float = _banner.size.x * 0.5 + _p1_half.lean + 60.0
	_p1_half.position.x = -away
	_p2_half.position.x = away
	_vs_label.scale = Vector2.ZERO
	_vs_label.modulate.a = 0.0

	# **가속하면서 부딪혀야** 쾅 하는 느낌이 난다 — EASE_IN으로 끝에서 제일 빠르다
	var slam := create_tween()
	slam.set_parallel(true)
	slam.tween_property(_p1_half, "position:x", 0.0, slam_time).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	slam.tween_property(_p2_half, "position:x", 0.0, slam_time).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	await slam.finished

	# 쾅 — 이음새 한가운데에서 불꽃이 터지고 화면과 캐릭터가 흔들린다
	_sparks.burst(_banner.size * 0.5)
	_start_shake()
	var pop := create_tween()
	pop.set_parallel(true)
	pop.tween_property(_vs_label, "modulate:a", 1.0, 0.08)
	pop.tween_property(_vs_label, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(hold_time).timeout

	# 맵 선택 뒤와 같은 홀로그램 타일 전환. **덮기만 하고 넘긴다** —
	# 걷어내는 건 Stage가 캐릭터를 다 세운 뒤에 한다
	await SceneTransition.cover()
	finished.emit()
	queue_free()

func _start_shake() -> void:
	_banner_home = _banner.position
	_p1_home = _p1_box.position
	_p2_home = _p2_box.position
	_shake_left = shake_time
	set_process(true)

## 충돌 직후 흔들림. 처음이 제일 세고 빠르게 잦아든다(decay = k²).
## **두 캐릭터는 서로 반대로 밀린다** — 같이 흔들리면 부딪힌 게 아니라 화면만 떤 것처럼 보인다
func _process(delta: float) -> void:
	if _shake_left <= 0.0:
		set_process(false)
		_banner.position = _banner_home
		_p1_box.position = _p1_home
		_p2_box.position = _p2_home
		return
	_shake_left -= delta
	var k: float = clampf(_shake_left / maxf(shake_time, 0.001), 0.0, 1.0)
	var decay: float = k * k
	var phase: float = (shake_time - _shake_left) * shake_speed
	_banner.position = _banner_home + Vector2(sin(phase), cos(phase * 1.7) * 0.5) * banner_shake * decay
	var jolt: float = sin(phase * 1.25) * portrait_shake * decay
	_p1_box.position = _p1_home + Vector2(-jolt, sin(phase * 2.1) * portrait_shake * 0.4 * decay)
	_p2_box.position = _p2_home + Vector2(jolt, cos(phase * 2.1) * portrait_shake * 0.4 * decay)
