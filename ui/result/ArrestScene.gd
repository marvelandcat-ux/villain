extends CanvasLayer

## 대전 최종 결과 3단계 — **연행 장면**(승리 화면 → 패배 화면 → 연행 → 결과 버튼).
## 『개그만화 보기 좋은 날』 "명탐정 우사미짱"의 쿠마키치 연행 장면 패러디다:
## 앞 왼쪽에 크게 잘린 경찰차, 가운데 밧줄을 쥔 경찰, 그 뒤로 수갑 찬 두 사람(이 판의 패자·승자)이
## 비스듬히 물러나며 작아지고, 오른쪽 뒤에 이 판에 안 나온 로스터가 작게 줄지어 무표정으로 구경한다.
##
## **원근은 카메라 하나로 계산한다** — 지평선·소실점·카메라 높이·초점 거리로 바닥 선·경찰차·인물 크기·그림자를 전부 투영한다.
## 그래서 발 위치만 옮기면 크기·그림자·밧줄 굵기가 저절로 맞고, 밀고 들어가기(dolly)도 가까운 것일수록 더 커진다.
## 단위는 **캐릭터 키 = 1**.
##
## 사용: add_child 후 `play(info)`. 약 3초 뒤 `finished`. 끝나도 장면은 그대로 남는다(위에 결과 버튼이 뜬다).
## info 키: winner_rig / loser_rig(리그 경로), winner_name / loser_name, winner_p2_color / loser_p2_color, is_draw

signal finished

const ResultSfx = preload("res://ui/result/ResultSfx.gd")
const RopeScript = preload("res://ui/result/ArrestRope.gd")
const POLICE_RIG := "res://characters/police/PoliceRig.tscn"
const DEFAULT_BACKDROP := "res://ui/result/backdrops/PoliceStation.tres"
const BACKDROP_DIR := "res://ui/result/backdrops/"
const MobScript = preload("res://ui/result/MobCrowd.gd")
const GuideScript = preload("res://ui/result/PerspectiveGuide.gd")
const BASE_SIZE := Vector2(1280, 720)

# --- 박자(실제 초, play() 기준) ---
# 처음엔 6초였는데 "너무 길어서 게임 템포가 느려졌다"(2026-10-08 사용자) -> 같은 순서를 3초로 줄였다
const FADE_IN := 0.2
const WALK_1 := Vector2(0.1, 1.05)
const WALK_2 := Vector2(1.8, 2.75)
## 첫 구간에서 걸어갈 몫(나머지는 두 번째 구간)
const WALK_SPLIT := 0.45
## 경찰이 멈춰 서서 뒤를 돌아보는 때 / 승자가 "어? 나도?" 하고 풀 죽는 때 / 경찰이 밧줄을 홱 당기는 때
const LOOKBACK_AT := 1.1
const BEAT_AT := 1.3
const TUG_AT := 1.65
const FINISH_AT := 3.0

@export_group("카메라(원근)")
## 지평선 높이(1280x720 기준 화면 px). 카메라가 사람 가슴 높이라 경찰 얼굴보다 아래에 온다
@export var horizon_y: float = 470.0
## 소실점 x — 연석·타일 세로선이 여기로 모인다
@export var vanish_x: float = 760.0
## 카메라 높이(캐릭터 키 = 1). 낮을수록 앞사람이 뒷사람보다 우뚝 솟아 보인다(원작처럼 올려다보는 맛)
@export var camera_height: float = 0.62
## 초점 거리(px) — 클수록 망원(원근이 약해짐)
@export var focal: float = 1500.0
## 연출 동안(FINISH_AT까지) 카메라가 앞으로 밀고 들어가는 거리(월드). 0이면 고정 화면
@export var dolly_distance: float = 0.16

@export_group("인물(시작할 때 발 위치)")
@export var police_feet: Vector2 = Vector2(535, 638)
@export var first_feet: Vector2 = Vector2(738, 622)
@export var second_feet: Vector2 = Vector2(918, 607)
## 구경꾼 자리 — 앞(아래)에 있는 것일수록 크게 나온다. 개수가 곧 최대 인원
@export var crowd_feet: Array[Vector2] = [Vector2(1035, 575), Vector2(1102, 566), Vector2(1170, 578), Vector2(1238, 569)]
## 경찰만 조금 더 크게(어른) — 1이면 다른 사람과 같은 키
@export var police_height_scale: float = 1.05
## 행렬이 왼쪽(경찰차 쪽)으로 걸어가는 거리(월드)
@export var walk_distance: float = 0.18
## 걷는 동안 리그에 넣는 걸음 세기(0~1)
@export var walk_speed_ratio: float = 0.46
## 끌려가는 걸음이라 보폭을 줄인다(리그 기본 11)
@export var walk_foot_stride: float = 7.0

@export_group("건물 배경")
## 인물들이 **이 건물 문에서 막 끌려 나온** 것처럼 보이게, 그림 속 문을 기준점으로 원근에 맞춰 놓는다(ArrestBackdropConfig.gd).
## **맵마다 그 맵 건물이 선다**: 대전에서 고른 맵 씬 이름과 같은 `ui/result/backdrops/<맵 이름>.tres`(예: Gym.tres)를 쓴다.
## 그 파일이 없거나 그림(texture)이 비어 있으면 이 기본 건물 — 비우면 경찰서(DEFAULT_BACKDROP)
@export var default_backdrop: Resource
## 건물이 땅에 닿는 화면 높이(밀고 들어가기 전). 지평선(horizon_y)에 가까울수록 건물이 멀어져 작아진다
@export var facade_base_y: float = 548.0
## 출입문 가운데가 올 화면 x — 행렬 바로 뒤라 "문에서 막 나온" 것처럼 보인다
@export var door_screen_x: float = 820.0

@export_group("원근 가이드")
## 켜면 지평선·소실점·문 자리·캐릭터 키를 겹쳐 그린다 — 배경 그림을 맞출 때 쓴다(건물은 반투명이 된다)
@export var show_perspective_guide: bool = false

@export_group("구경꾼 무리")
## 얼굴 없는 구경꾼(MobCrowd) 발 위치(화면, 밀고 들어가기 전). back = 로스터 구경꾼(crowd_feet)보다 먼 줄, front = 가까운 줄
@export var mob_back_feet: Array[Vector2] = [
	Vector2(575, 553), Vector2(630, 556), Vector2(685, 552), Vector2(930, 551), Vector2(975, 553), Vector2(1020, 552), Vector2(1065, 554), Vector2(1110, 551),
	Vector2(1155, 553), Vector2(1200, 552), Vector2(1245, 554), Vector2(1290, 551), Vector2(1335, 553), Vector2(1380, 552), Vector2(1425, 554), Vector2(1470, 551),
	Vector2(952, 557), Vector2(997, 559), Vector2(1042, 558), Vector2(1087, 560), Vector2(1132, 557), Vector2(1177, 559), Vector2(1222, 558), Vector2(1267, 560),
	Vector2(1312, 557), Vector2(1357, 559), Vector2(1402, 558), Vector2(1447, 560), Vector2(1492, 557),
]
@export var mob_front_feet: Array[Vector2] = [Vector2(1300, 588), Vector2(1368, 594), Vector2(1436, 589), Vector2(1504, 595)]
## 얼굴 없는 구경꾼 밝기(1 = 하얀 바탕 그대로). 너무 튄다고 해서 낮췄다(2026-10-10 사용자: "너무 밝아")
@export_range(0.3, 1.0, 0.01) var mob_shade: float = 0.78

@export_group("밧줄")
## 밧줄 굵기(월드) / 처짐(두 점 거리 대비)
@export var rope_thickness: float = 0.02
@export var rope_sag: float = 0.17

@onready var _stage: Node2D = $Stage
@onready var _backdrop: Node2D = $Stage/Backdrop
@onready var _building: Sprite2D = $Stage/Building
@onready var _crowd_layer: Node2D = $Stage/Crowd
@onready var _line_layer: Node2D = $Stage/Procession
@onready var _car: Node2D = $Stage/Car
@onready var _fade: ColorRect = $Fade

## 리그 경로 -> [보이는 영역(리그 좌표), 머리 영역] — 같은 리그를 다시 잴 일이 없게
static var _bounds_cache: Dictionary = {}
## 그림 경로 -> 불투명 영역
static var _opaque_cache: Dictionary = {}
## `warm_up()`이 스레드로 미리 읽기 시작한 경로들 — `release_warm()`이 손을 놓는다
static var _warm_paths: Array[String] = []

var _info: Dictionary = {}
var _playing: bool = false
var _sent_finished: bool = false
## play() 이후 흐른 실제 시간 / 장면이 뜬 뒤 흐른 실제 시간(경광등·구름은 play 전에도 돈다)
var _time: float = 0.0
var _clock: float = 0.0
var _last_usec: int = 0
## 이번 프레임 실제 시간 간격
var _frame_dt: float = 0.0
var _dolly: float = 0.0
var _actors: Array = []
var _police: Dictionary = {}
var _first: Dictionary = {}
var _second: Dictionary = {}
var _crowd: Array = []
var _rope_a: Node2D = null
var _rope_b: Node2D = null
var _siren: AudioStreamPlayer = null
## [시각, Callable] — 시간 순서대로 한 번씩 부른다
var _events: Array = []
var _next_event: int = 0
var _building_world: Vector3 = Vector3.ZERO
var _building_height: float = 956.0
var _building_scale: float = 0.4
## 그림 가장자리를 하늘로 녹이는 재질(씬에 붙어 있던 것) — 끄는 그림이면 떼었다가 다시 붙인다
var _edge_material: Material = null
var _mob_back: Node2D = null
var _mob_front: Node2D = null
var _guide: Node2D = null
## 경광등 박자 시계 — 사이렌이 울리면 소리가 들리는 지점에 맞추고, 없거나 꺼지면 이어서 센다
var _siren_clock: float = 0.0

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 리그들이 이번 프레임 자세를 다 잡은 **뒤에** 손·고개를 덮어써야 해서 맨 마지막에 돈다
	process_priority = 100
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0, 0, 0, 1)
	_last_usec = Time.get_ticks_usec()
	_edge_material = _building.material
	_apply_backdrop(default_backdrop if default_backdrop != null else load(DEFAULT_BACKDROP))
	_build_mobs()
	if show_perspective_guide:
		_guide = Node2D.new()
		_guide.set_script(GuideScript)
		_stage.add_child(_guide)
	get_viewport().size_changed.connect(_fit_to_screen)
	_fit_to_screen()
	_update_scene()

## 이 장면에 나올 수 있는 리그(경찰 + 구경꾼 후보 전원 + extra)를 **뒤에서 미리 읽기 시작한다**.
## play()가 리그 일곱 개를 한꺼번에 읽느라 검은 화면에서 1~2초 멈췄다(실측) — 승리·패배 화면이 도는 동안 불러 둘 것.
## 다 읽힌 리그는 손을 놓기(`release_warm`) 전까지 캐시에 남아 있어서 play()의 load()가 곧바로 받아 간다
static func warm_up(extra: Array = []) -> void:
	# 헤드리스(가짜 렌더러)에선 스레드로 그림을 만들면 "Parameter "t" is null"(texture_2d_initialize) 에러가 쏟아진다(실측).
	# 실제 창에선 안 나고, 헤드리스 검사에서 가짜 경보가 되므로 끈다
	if DisplayServer.get_name() == "headless":
		return
	var paths: Array = [POLICE_RIG]
	for character_name in GameState.CHARACTERS.keys():
		if GameState.CHARACTER_RIGS.has(character_name):
			paths.append(GameState.CHARACTER_RIGS[character_name])
	paths.append_array(extra)
	for path in paths:
		var p: String = str(path)
		if p == "" or _warm_paths.has(p) or not ResourceLoader.exists(p):
			continue
		if ResourceLoader.load_threaded_request(p) == OK:
			_warm_paths.append(p)

## 미리 읽기에서 손을 놓는다 — 장면에 쓰인 리그는 장면이 붙들고 있고, 안 쓰인 것은 메모리에서 풀린다
static func release_warm() -> void:
	for p in _warm_paths:
		ResourceLoader.load_threaded_get(p)
	_warm_paths.clear()

func _exit_tree() -> void:
	# 끝나기 전에 지워져도 미리 읽기가 붙든 리그가 메모리에 남지 않게
	release_warm()

## 연출을 시작한다. add_child 다음에 부를 것
func play(info: Dictionary) -> void:
	if _playing:
		return
	_info = info
	_playing = true
	_time = 0.0
	# 싸운 맵의 건물 그림이 있으면 그걸로 — 그 건물 문에서 끌려 나온 셈이다(그림이 비어 있으면 기본 건물 그대로)
	var map_path: String = str(info.get("map_path", ""))
	var map_config: String = BACKDROP_DIR + map_path.get_file().get_basename() + ".tres"
	if map_path != "" and ResourceLoader.exists(map_config):
		_apply_backdrop(load(map_config))
	_build_cast()
	_events = [
		[LOOKBACK_AT, _police_look_back],
		[BEAT_AT, _winner_deflates],
		[TUG_AT + 0.05, _tug_squash],
		[0.55, _crowd_blink.bind(0)],
		[1.5, _crowd_blink.bind(2)],
		[2.2, _crowd_blink.bind(1)],
		[2.65, _crowd_blink.bind(3)],
		[FINISH_AT, _finish],
	]
	_events.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_next_event = 0
	_siren = ResultSfx.play(self, ResultSfx.SIREN, -12.0, 1.0, true)
	_update_scene()

func _process(_delta: float) -> void:
	# 실제 시간으로 잰다 — KO 슬로처럼 Engine.time_scale이 바뀌어 있어도 박자가 안 흔들린다
	var now: int = Time.get_ticks_usec()
	var dt: float = minf(float(now - _last_usec) / 1000000.0, 0.05)
	_last_usec = now
	_frame_dt = dt
	_clock += dt
	# 경광등은 사이렌에 맞춘다 — 지금 **들리는** 지점(출력 지연까지 뺀 값)을 잰다. 소리가 없거나 꺼지면 같은 박자로 이어서 센다
	if is_instance_valid(_siren) and _siren.playing:
		_siren_clock = _siren.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	else:
		_siren_clock += dt
	if _playing:
		_time += dt
		while _next_event < _events.size() and _time >= float(_events[_next_event][0]):
			var cb: Callable = _events[_next_event][1]
			_next_event += 1
			cb.call()
	_update_scene()

# ---------------------------------------------------------------- 배치

## 넓은 화면이면 좌우(또는 위아래)로 더 보인다 — 구도는 가운데에 두고 배경만 끝까지 채운다
func _fit_to_screen() -> void:
	var rect: Rect2 = get_viewport().get_visible_rect()
	_stage.position = rect.position + (rect.size - BASE_SIZE) * 0.5
	_backdrop.set("view_rect", Rect2(rect.position - _stage.position, rect.size))
	_update_guide()

func _build_cast() -> void:
	var is_draw: bool = bool(_info.get("is_draw", false))
	var winner_rig: String = str(_info.get("winner_rig", ""))
	var loser_rig: String = str(_info.get("loser_rig", ""))
	# 구경꾼 — 먼(위쪽) 자리부터 붙여야 앞사람이 뒷사람을 가린다
	var names: Array = []
	for character_name in GameState.CHARACTERS.keys():
		if character_name == str(_info.get("winner_name", "")) or character_name == str(_info.get("loser_name", "")):
			continue
		if GameState.CHARACTER_RIGS.has(character_name):
			names.append(character_name)
	names.shuffle()
	var slots: Array = crowd_feet.duplicate()
	slots = slots.slice(0, mini(slots.size(), names.size()))
	var order: Array = range(slots.size())
	order.sort_custom(func(a: int, b: int) -> bool: return slots[a].y < slots[b].y)
	_crowd.resize(slots.size())
	for i in order:
		var actor: Dictionary = _make_actor(str(GameState.CHARACTER_RIGS[names[i]]), slots[i], _crowd_layer, &"crowd", false)
		_crowd[i] = actor
		if not actor.is_empty():
			_actors.append(actor)
	# 행렬 — 뒤(둘째) → 둘째 밧줄 → 첫째 → 첫째 밧줄 → 경찰 순으로 쌓는다.
	# 밧줄은 묶인 사람의 손(앞) 위, 그 앞사람 몸 뒤로 지나가야 자연스럽다
	_second = _make_actor(winner_rig, second_feet, _line_layer, &"second", bool(_info.get("winner_p2_color", false)))
	_rope_b = _make_rope()
	_first = _make_actor(loser_rig, first_feet, _line_layer, &"first", bool(_info.get("loser_p2_color", false)))
	_rope_a = _make_rope()
	_police = _make_actor(POLICE_RIG, police_feet, _line_layer, &"police", false)
	for actor in [_second, _first, _police]:
		if not actor.is_empty():
			_actors.append(actor)
	# 표정 — 패자는 처음부터 찡그리고 고개를 푹, 승자는 아직 이긴 기분(액션 얼굴 + 턱 들기)이다가 BEAT에 풀이 죽는다.
	# 무승부면 둘 다 무표정(우사미짱식 멍한 얼굴)으로 시작해 BEAT에 같이 식은땀
	if not is_draw:
		if not _second.is_empty():
			(_second["rig"] as BodyRig).set_action_face(true)
			_second["tilt_from"] = -6.0
		if not _first.is_empty():
			_first["hurt"] = true
	else:
		for actor in [_first, _second]:
			if not actor.is_empty():
				actor["tilt_from"] = 3.0
	for actor in [_first, _second]:
		if not actor.is_empty():
			_add_cuffs(actor)

func _make_rope() -> Node2D:
	var rope := Node2D.new()
	rope.set_script(RopeScript)
	_line_layer.add_child(rope)
	return rope

## 리그 하나를 [발 기준 노드 > 그림자 + 기울기 > 크기·방향 > 리그]로 감싸 붙인다.
## 리그 루트의 scale은 리그가 스쿼시에 쓰므로 직접 안 건드린다(⚠️ BodyRig 규칙) — 크기·좌우는 holder가 맡는다
func _make_actor(path: String, feet: Vector2, layer_node: Node2D, role: StringName, p2_color: bool) -> Dictionary:
	if path == "" or not ResourceLoader.exists(path):
		return {}
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		return {}
	var rig: BodyRig = scene.instantiate() as BodyRig
	if rig == null:
		return {}
	var node := Node2D.new()
	node.name = String(role)
	var shadow := ShadowBlob.new()
	node.add_child(shadow)
	var lean := Node2D.new()
	node.add_child(lean)
	var holder := Node2D.new()
	lean.add_child(holder)
	# add_child가 _ready를 바로 부르므로 리그 값은 그 전에 넣는다
	rig.idle_gestures = role == &"police"   # 경찰은 뒤돌아보기(play_lookback)가 가만히 서 있을 때만 이어져서 켜 둔다
	rig.idle_motion_delay = 9999.0          # 대신 저절로 나오는 몸짓(머리 긁기 등)은 막는다
	if role != &"crowd":
		rig.foot_stride = walk_foot_stride
		rig.body_bob = 3.0
	layer_node.add_child(node)
	holder.add_child(rig)
	if p2_color:
		rig.set_player_two(true)
	# 키는 소품을 뺀 몸으로 잰다(키보드·가방 크기에 키가 휘둘리지 않게)
	_hide_props(rig)
	var measured: Array = _measure(rig, path)
	var bounds: Rect2 = measured[0]
	if role == &"crowd":
		_show_props(rig)
	var actor: Dictionary = {
		"role": role, "node": node, "lean": lean, "holder": holder, "rig": rig, "shadow": shadow,
		"world": _ground_to_world(feet),
		"mul": police_height_scale if role == &"police" else 1.0,
		"bottom": bounds.end.y, "rig_h": maxf(bounds.size.y, 1.0), "head_rect": measured[1],
		"hand_l": rig.get_node_or_null("HandL"), "hand_r": rig.get_node_or_null("HandR"),
		"head": rig.get_node_or_null("Head"), "body": rig.get_node_or_null("Body"),
		"tilt_from": 9.0, "tilt_to": 9.0,
		"hurt": false, "hurt_left": 0.0, "sweat": null, "cuffs": null,
	}
	for part_name in ["hand_l", "hand_r", "head", "body"]:
		var part: Node2D = actor[part_name]
		actor[part_name + "_rest"] = part.position if part != null else Vector2.ZERO
	return actor

## 구경꾼은 자기 소품을 그대로 든다(무엇을 숨길지는 그 뒤로 리그가 매 프레임 정한다)
static func _show_props(rig: Node2D) -> void:
	for hold_name in ["HandRHold", "HandLHold"]:
		var hold: CanvasItem = rig.get_node_or_null(hold_name) as CanvasItem
		if hold != null:
			hold.visible = true
	for hand_name in ["HandL", "HandR"]:
		var hand: Node = rig.get_node_or_null(hand_name)
		if hand == null:
			continue
		for child in hand.get_children():
			if child is CanvasItem:
				(child as CanvasItem).visible = true

## 손에 든 무기·소품은 압수 — 수갑 찬 손에 키보드·소주병이 붙어 있으면 이상하다.
## 리그가 매 프레임 다시 켜는 것도 있어서(악플러 키보드 등) 매 프레임 부른다
static func _hide_props(rig: Node2D) -> void:
	for hold_name in ["HandRHold", "HandLHold"]:
		var hold: CanvasItem = rig.get_node_or_null(hold_name) as CanvasItem
		if hold != null and hold.visible:
			hold.visible = false
	for hand_name in ["HandL", "HandR"]:
		var hand: Node = rig.get_node_or_null(hand_name)
		if hand == null:
			continue
		for child in hand.get_children():
			if child is CanvasItem and (child as CanvasItem).visible:
				(child as CanvasItem).visible = false

func _add_cuffs(actor: Dictionary) -> void:
	var rig: BodyRig = actor["rig"]
	var hand_l: Sprite2D = actor["hand_l"] as Sprite2D
	var hand_r: Sprite2D = actor["hand_r"] as Sprite2D
	if hand_l == null or hand_r == null:
		return
	var cuffs := Cuffs.new()
	cuffs.hand_l = hand_l
	cuffs.hand_r = hand_r
	var hand_size: Vector2 = hand_r.texture.get_size() * hand_r.scale.abs() if hand_r.texture != null else Vector2(18, 16)
	cuffs.back = hand_size.x * 0.3
	cuffs.ring_size = Vector2(hand_size.x * 0.12, hand_size.y * 0.34)
	rig.add_child(cuffs)
	actor["cuffs"] = cuffs

# ---------------------------------------------------------------- 매 프레임

func _update_scene() -> void:
	if _playing:
		var k: float = clampf(_time / FINISH_AT, 0.0, 1.0)
		_dolly = dolly_distance * (1.0 - pow(1.0 - k, 2.2))
		_fade.color.a = 1.0 - smoothstep(0.0, FADE_IN, _time)
	var walking: bool = _playing and ((_time > WALK_1.x and _time < WALK_1.y) or (_time > WALK_2.x and _time < WALK_2.y))
	var walked: float = -walk_distance * _walk_progress(_time) if _playing else 0.0
	var tug_s: float = _time - TUG_AT
	for actor in _actors:
		_update_actor(actor, walking, walked, tug_s)
	_update_ropes(tug_s)
	_update_building()
	_backdrop.set("vanish_x", vanish_x)
	_backdrop.set("horizon_y", horizon_y)
	_backdrop.set("camera_height", camera_height)
	_backdrop.set("focal", focal)
	_backdrop.set("dolly", _dolly)
	_backdrop.set("time", _clock)
	var b_left: float = _project(_building_world).x
	_backdrop.set("building_span", Vector2(b_left, b_left + _building.region_rect.size.x * _building.scale.x))
	_car.set("vanish_x", vanish_x)
	_car.set("horizon_y", horizon_y)
	_car.set("camera_height", camera_height)
	_car.set("focal", focal)
	_car.set("dolly", _dolly)
	_car.set("time", _clock)
	var tone: Vector2 = ResultSfx.siren_tone_at(maxf(_siren_clock, 0.0))
	_car.set("siren_tone", int(tone.x))
	_car.set("tone_time", tone.y)
	for mob in [_mob_back, _mob_front]:
		if mob == null:
			continue
		mob.set("vanish_x", vanish_x)
		mob.set("horizon_y", horizon_y)
		mob.set("camera_height", camera_height)
		mob.set("focal", focal)
		mob.set("dolly", _dolly)
		mob.set("time", _clock)

func _update_actor(actor: Dictionary, walking: bool, walked: float, tug_s: float) -> void:
	var role: StringName = actor["role"]
	var rig: BodyRig = actor["rig"]
	var offset: float = 0.0
	var lean: float = 0.0
	if role != &"crowd":
		offset = walked
		rig.manual_speed_ratio = walk_speed_ratio if walking else 0.0
		if role == &"police":
			lean = 0.05 * _pulse(tug_s, 0.08, 7.0)   # 당기면서 몸이 뒤로 살짝 젖혀진다
		else:
			# 홱 당겨지면 앞으로 휘청 — 둘째는 줄이 팽팽해지는 만큼 조금 늦게
			var delay: float = 0.05 if role == &"first" else 0.14
			var lurch: float = _pulse(tug_s - delay, 0.1, 5.0) * (1.0 if role == &"first" else 0.85)
			offset -= 0.045 * lurch
			lean = -0.085 * lurch
	var base_world: Vector3 = actor["world"]
	var world: Vector3 = base_world + Vector3(offset, 0.0, 0.0)
	var node: Node2D = actor["node"]
	node.position = _project(world)
	(actor["lean"] as Node2D).rotation = lean
	var px: float = _px_per_unit(world.z) * float(actor["mul"])
	var k: float = px / float(actor["rig_h"])
	var holder: Node2D = actor["holder"]
	# 전원 왼쪽(경찰차 쪽)을 본다 — 좌우는 holder의 scale.x 부호로만
	holder.scale = Vector2(-k, k)
	holder.position = Vector2(0.0, -float(actor["bottom"]) * k)
	var shadow: ShadowBlob = actor["shadow"]
	var rx: float = px * 0.3
	shadow.set_radius(Vector2(rx, rx * camera_height / maxf(world.z - _dolly, 0.05) * 1.25))
	if role != &"crowd":
		_hide_props(rig)
	_pose_hands(actor, tug_s)

## 리그가 이번 프레임 잡은 자세 위에 손·고개를 덮어쓴다(이 노드가 리그들보다 늦게 돈다)
func _pose_hands(actor: Dictionary, tug_s: float) -> void:
	var role: StringName = actor["role"]
	if role == &"crowd":
		return
	var rig: BodyRig = actor["rig"]
	var body: Node2D = actor["body"]
	var body_rest: Vector2 = actor["body_rest"]
	var bob: Vector2 = body.position - body_rest if body != null else Vector2.ZERO
	var hand_l: Node2D = actor["hand_l"]
	var hand_r: Node2D = actor["hand_r"]
	if role == &"police":
		# 밧줄 쥔 손(뒤쪽 손)은 허리 뒤에 — 당길 때 앞으로 홱
		if hand_l != null:
			var pull: float = _pulse(tug_s, 0.08, 7.0)
			var rest_l: Vector2 = actor["hand_l_rest"]
			hand_l.position = rest_l + Vector2(5.0 + 10.0 * pull, 6.0) + bob
			hand_l.rotation = 0.0
		return
	# 묶인 두 사람 — 두 손을 배 앞에 모은다(수갑)
	if hand_r != null and hand_l != null:
		var rest_r: Vector2 = actor["hand_r_rest"]
		var cuff_r := Vector2(rest_r.x * 0.6, rest_r.y + 7.0)
		hand_r.position = cuff_r + bob
		hand_l.position = cuff_r + Vector2(-6.5, 2.0) + bob
		hand_r.rotation = 0.0
		hand_l.rotation = 0.0
	# 고개 — BEAT에 tilt_from에서 tilt_to로 떨군다(양수 = 숙임, 리그 좌표라 좌우 부호는 안 곱한다)
	var head: Node2D = actor["head"]
	if head != null:
		var drop: float = smoothstep(BEAT_AT, BEAT_AT + 0.3, _time)
		head.rotation = deg_to_rad(lerpf(float(actor["tilt_from"]), float(actor["tilt_to"]), drop))
	# 찡그린 얼굴은 리그가 잠깐(0.45초)만 띄우므로 꺼지기 전에 다시 건다
	if bool(actor["hurt"]):
		actor["hurt_left"] = float(actor["hurt_left"]) - _frame_dt
		if float(actor["hurt_left"]) <= 0.0:
			rig.play_hurt_face()
			actor["hurt_left"] = 0.25
	# 땀방울은 스스로 사라진다 — 지워진 노드를 타입 변수에 넣으면 에러라 먼저 확인한다
	var sweat_ref: Variant = actor["sweat"]
	if sweat_ref != null:
		if not is_instance_valid(sweat_ref):
			actor["sweat"] = null
		elif head != null:
			var sweat: Node2D = sweat_ref
			var base: Vector2 = sweat.get_meta("base")
			var head_rest: Vector2 = actor["head_rest"]
			sweat.position = base + (head.position - head_rest)

func _update_ropes(tug_s: float) -> void:
	var taut: float = _pulse(tug_s, 0.08, 4.5)
	var sway: float = sin(_clock * 2.3) * 1.5
	if _rope_a != null:
		_rope_a.visible = not _police.is_empty() and not _first.is_empty()
		if _rope_a.visible:
			var a: Vector2 = _line_layer.to_local((_police["hand_l"] as Node2D).global_position)
			var b: Vector2 = _cuff_point(_first)
			var police_world: Vector3 = _police["world"]
			var thick: float = rope_thickness * _px_per_unit(police_world.z)
			_rope_a.set("tail_length", thick * 5.0)
			_rope_a.call("set_rope", a, b, a.distance_to(b) * rope_sag * (1.0 - 0.85 * taut) + sway, thick)
	if _rope_b != null:
		_rope_b.visible = not _first.is_empty() and not _second.is_empty()
		if _rope_b.visible:
			var a2: Vector2 = _cuff_point(_first)
			var b2: Vector2 = _cuff_point(_second)
			var second_world: Vector3 = _second["world"]
			var thick2: float = rope_thickness * _px_per_unit(second_world.z)
			var taut2: float = _pulse(tug_s - 0.08, 0.08, 4.5)
			_rope_b.call("set_rope", a2, b2, a2.distance_to(b2) * rope_sag * (1.0 - 0.85 * taut2) - sway * 0.6, thick2)

## 수갑 찬 두 손목의 가운데(밧줄이 감기는 곳)
func _cuff_point(actor: Dictionary) -> Vector2:
	var cuffs: Node2D = actor["cuffs"]
	var rig: BodyRig = actor["rig"]
	if cuffs != null and is_instance_valid(cuffs):
		var local: Vector2 = cuffs.call("center")
		return _line_layer.to_local(rig.to_global(local))
	return _line_layer.to_local(rig.global_position)

func _update_building() -> void:
	var z: float = _building_world.z
	var k: float = _building_scale * z / maxf(z - _dolly, 0.05)
	_building.scale = Vector2(k, k)
	_building.position = _project(_building_world) - Vector2(0.0, _building_height * k)

# ---------------------------------------------------------------- 사건

func _police_look_back() -> void:
	if not _police.is_empty():
		(_police["rig"] as BodyRig).play_lookback()

## 승자가 "어? 나도 잡혀가?" — 이긴 얼굴이 풀리고 식은땀 한 방울. 무승부면 둘 다
func _winner_deflates() -> void:
	var targets: Array = [_second]
	if bool(_info.get("is_draw", false)):
		targets.append(_first)
	for actor in targets:
		if actor.is_empty():
			continue
		var rig: BodyRig = actor["rig"]
		rig.set_action_face(false)
		rig.play_squash(Vector2(0.9, 1.1))
		_add_sweat(actor)

func _add_sweat(actor: Dictionary) -> void:
	var head_rect: Rect2 = actor["head_rect"]
	if head_rect.size == Vector2.ZERO:
		return
	var sweat := SweatMark.new()
	sweat.size = head_rect.size.y * 0.085
	var base := Vector2(head_rect.position.x + head_rect.size.x * 0.2, head_rect.position.y + head_rect.size.y * 0.3)
	sweat.set_meta("base", base)
	sweat.position = base
	(actor["rig"] as Node2D).add_child(sweat)
	actor["sweat"] = sweat

func _tug_squash() -> void:
	for actor in [_first, _second]:
		if not actor.is_empty():
			(actor["rig"] as BodyRig).play_squash(Vector2(1.06, 0.94))

func _crowd_blink(index: int) -> void:
	if index >= _crowd.size():
		return
	var entry: Dictionary = _crowd[index]
	if not entry.is_empty():
		(entry["rig"] as BodyRig).play_blink()

func _finish() -> void:
	if _sent_finished:
		return
	_sent_finished = true
	ResultSfx.fade_out(_siren, 0.8)
	_siren = null
	# 장면이 다 떴으니 미리 읽어 둔 리그에서 손을 놓는다(승리·패배 화면 7초 + 이 장면 3초 뒤라 읽기는 다 끝나 있다 — 기다리지 않는다)
	release_warm()
	finished.emit()

# ---------------------------------------------------------------- 건물 배경 · 구경꾼 무리 · 가이드

## 건물 그림을 고르고 **문을 기준으로** 원근에 맞춰 놓는다(ArrestBackdropConfig.gd 참고).
## 그림 밑변(땅선)이 화면 facade_base_y에, 문 가운데가 door_screen_x에 오고, 그 깊이에서 문 높이가 캐릭터 키 x door_height가 되게 배율을 정한다.
## 문 자리를 안 적은 그림은 "원근 가이드 위에 화면 그대로 그린 그림"으로 보고 1280x720 화면에 1:1로 깐다
func _apply_backdrop(config: Resource) -> void:
	if config == null or config.get("texture") == null:
		return
	var tex: Texture2D = config.get("texture")
	var size: Vector2 = tex.get_size()
	var door: Rect2 = config.get("door_rect")
	var ground: float = float(config.get("ground_px"))
	if ground <= 0.0:
		# 문 자리 없이 원근 가이드 위에 그린 그림이면 땅선도 가이드의 초록 선(facade_base_y)이다
		ground = facade_base_y * size.x / BASE_SIZE.x if door.size.y <= 0.0 else size.y
	_building.texture = tex
	_building.region_enabled = true
	_building.region_rect = Rect2(0.0, 0.0, size.x, ground)
	_building_height = ground
	var base_y: float = facade_base_y
	var left_x: float = 0.0
	if door.size.y > 0.0:
		var z: float = _depth_of(base_y)
		_building_scale = float(config.get("door_height")) * focal / z / door.size.y
		left_x = door_screen_x - (door.position.x + door.size.x * 0.5) * _building_scale
		var horizon_px: float = float(config.get("horizon_px"))
		if horizon_px >= 0.0:
			var drawn_horizon: float = base_y - (ground - horizon_px) * _building_scale
			if absf(drawn_horizon - horizon_y) > 25.0:
				push_warning("ArrestScene: 배경 그림 눈높이가 장면 지평선과 %dpx 어긋난다 — 원근가이드.png에 맞춰 그림을 고칠 것" % int(drawn_horizon - horizon_y))
	else:
		_building_scale = BASE_SIZE.x / size.x
		base_y = ground * _building_scale
	var base_z: float = _depth_of(base_y)
	_building_world = Vector3((left_x - vanish_x) * base_z / focal, 0.0, base_z)
	_building.material = _edge_material if bool(config.get("edge_fade")) else null
	for flag in _building.get_children():
		if flag is CanvasItem:
			(flag as CanvasItem).visible = bool(config.get("show_flags"))
	_building.self_modulate.a = 0.45 if show_perspective_guide else 1.0
	_update_building()

## 얼굴 없는 구경꾼 무리 — 로스터 구경꾼보다 먼 줄은 그 뒤에, 가까운 줄은 그 앞에 그려지게 두 겹으로 나눈다
func _build_mobs() -> void:
	_mob_back = _make_mob_layer(mob_back_feet, 11)
	_stage.move_child(_mob_back, _crowd_layer.get_index())
	_mob_front = _make_mob_layer(mob_front_feet, 23)
	_stage.move_child(_mob_front, _line_layer.get_index())

func _make_mob_layer(feet_list: Array[Vector2], seed_value: int) -> Node2D:
	var layer_node := Node2D.new()
	layer_node.set_script(MobScript)
	_stage.add_child(layer_node)
	var worlds: Array = []
	for feet in feet_list:
		worlds.append(_ground_to_world(feet))
	layer_node.set("shade", mob_shade)
	layer_node.call("setup", worlds, seed_value)
	return layer_node

## 가이드에 지금 카메라·문 자리·키 막대 자리를 넣는다
func _update_guide() -> void:
	if _guide == null:
		return
	_guide.set("vanish_x", vanish_x)
	_guide.set("horizon_y", horizon_y)
	_guide.set("camera_height", camera_height)
	_guide.set("focal", focal)
	_guide.set("facade_base_y", facade_base_y)
	_guide.set("door_screen_x", door_screen_x)
	var config: Resource = default_backdrop if default_backdrop != null else load(DEFAULT_BACKDROP)
	_guide.set("door_height", float(config.get("door_height")) if config != null else 1.35)
	var rect: Rect2 = get_viewport().get_visible_rect()
	_guide.set("view_rect", Rect2(rect.position - _stage.position, rect.size))
	var markers: Array = [["경찰", police_feet], ["패자", first_feet], ["승자", second_feet]]
	if not crowd_feet.is_empty():
		markers.append(["구경꾼", crowd_feet[0]])
	if not mob_back_feet.is_empty():
		markers.append(["먼 구경꾼", mob_back_feet[mob_back_feet.size() - 1]])
	_guide.set("markers", markers)
	_guide.queue_redraw()

# ---------------------------------------------------------------- 원근 계산

## 바닥 높이(화면 y)에 있는 점의 깊이
func _depth_of(screen_y: float) -> float:
	return focal * camera_height / maxf(screen_y - horizon_y, 1.0)

## 밀고 들어가기 전 화면의 발 위치 -> 월드(X, 0, Z)
func _ground_to_world(feet: Vector2) -> Vector3:
	var z: float = _depth_of(feet.y)
	return Vector3((feet.x - vanish_x) * z / focal, 0.0, z)

## 월드 -> 화면(Stage 좌표). Y는 위가 +
func _project(p: Vector3) -> Vector2:
	var z: float = maxf(p.z - _dolly, 0.05)
	return Vector2(vanish_x + focal * p.x / z, horizon_y + focal * (camera_height - p.y) / z)

## 깊이 z에서 키 1이 화면에서 몇 px인지
func _px_per_unit(z: float) -> float:
	return focal / maxf(z - _dolly, 0.05)

## 걸음 진행도(0~1) — 두 구간에 나눠 걷고, 구간마다 천천히 출발해 천천히 선다
func _walk_progress(t: float) -> float:
	if t <= WALK_1.x:
		return 0.0
	if t < WALK_1.y:
		return WALK_SPLIT * _ease_walk((t - WALK_1.x) / (WALK_1.y - WALK_1.x))
	if t <= WALK_2.x:
		return WALK_SPLIT
	if t < WALK_2.y:
		return WALK_SPLIT + (1.0 - WALK_SPLIT) * _ease_walk((t - WALK_2.x) / (WALK_2.y - WALK_2.x))
	return 1.0

## 사다리꼴 속도(앞뒤 18%만 가속·감속) — 대부분 같은 빠르기라 발걸음과 잘 맞는다
static func _ease_walk(u: float) -> float:
	var a: float = 0.18
	u = clampf(u, 0.0, 1.0)
	var norm: float = 1.0 - a
	if u < a:
		return u * u / (2.0 * a * norm)
	if u < 1.0 - a:
		return (u - a * 0.5) / norm
	return 1.0 - (1.0 - u) * (1.0 - u) / (2.0 * a * norm)

## 확 올라갔다 서서히 잦아드는 한 번의 출렁임(s < 0이면 0)
static func _pulse(s: float, rise: float, decay: float) -> float:
	if s < 0.0:
		return 0.0
	if s < rise:
		return sin(s / rise * PI * 0.5)
	return exp(-(s - rise) * decay)

# ---------------------------------------------------------------- 리그 크기 재기

## [보이는 영역, 머리 영역](리그 좌표) — **실제로 칠해진 부분**만 잰다(그림 여백은 캐릭터마다 달라서)
func _measure(rig: Node2D, path: String) -> Array:
	if _bounds_cache.has(path):
		return _bounds_cache[path]
	var to_rig: Transform2D = rig.get_global_transform().affine_inverse()
	var bounds := Rect2()
	var started: bool = false
	var head_rect := Rect2()
	for sprite in _sprites_of(rig):
		if sprite.texture == null or not sprite.is_visible_in_tree():
			continue
		var r: Rect2 = _rect_in(to_rig * sprite.get_global_transform(), _opaque_local(sprite))
		if not started:
			bounds = r
			started = true
		else:
			bounds = bounds.merge(r)
		if sprite.name == &"Head" and sprite.get_parent() == rig:
			head_rect = r
	var out: Array = [bounds, head_rect]
	_bounds_cache[path] = out
	return out

static func _rect_in(xf: Transform2D, r: Rect2) -> Rect2:
	var out := Rect2(xf * r.position, Vector2.ZERO)
	for corner in [Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		out = out.expand(xf * corner)
	return out

static func _sprites_of(node: Node) -> Array[Sprite2D]:
	var found: Array[Sprite2D] = []
	if node is Sprite2D:
		found.append(node as Sprite2D)
	for child in node.get_children():
		found.append_array(_sprites_of(child))
	return found

## 스프라이트 자기 좌표에서 칠해진 영역
static func _opaque_local(sprite: Sprite2D) -> Rect2:
	var full: Rect2 = sprite.get_rect()
	if sprite.region_enabled or sprite.hframes > 1 or sprite.vframes > 1:
		return full
	var o: Rect2 = _opaque_rect(sprite.texture)
	var x: float = full.size.x - o.position.x - o.size.x if sprite.flip_h else o.position.x
	var y: float = full.size.y - o.position.y - o.size.y if sprite.flip_v else o.position.y
	return Rect2(full.position + Vector2(x, y), o.size)

## 그림에서 반쯤 이상 불투명한 영역. 작게 줄여서 잰다(큰 그림을 한 점씩 보면 첫 프레임이 끊긴다)
static func _opaque_rect(tex: Texture2D) -> Rect2:
	var key: String = tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id())
	if _opaque_cache.has(key):
		return _opaque_cache[key]
	var size: Vector2 = tex.get_size()
	var rect := Rect2(Vector2.ZERO, size)
	var img: Image = tex.get_image()
	if img != null and size.x > 0.0 and size.y > 0.0:
		if img.is_compressed():
			img.decompress()
		var shrink: float = minf(1.0, 128.0 / maxf(size.x, size.y))
		var w: int = maxi(int(round(size.x * shrink)), 1)
		var h: int = maxi(int(round(size.y * shrink)), 1)
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
		var min_p := Vector2i(w, h)
		var max_p := Vector2i(-1, -1)
		for yy in h:
			for xx in w:
				if img.get_pixel(xx, yy).a >= 0.5:
					min_p = Vector2i(mini(min_p.x, xx), mini(min_p.y, yy))
					max_p = Vector2i(maxi(max_p.x, xx), maxi(max_p.y, yy))
		if max_p.x >= 0:
			var sx: float = size.x / w
			var sy: float = size.y / h
			rect = Rect2(min_p.x * sx, min_p.y * sy, (max_p.x - min_p.x + 1) * sx, (max_p.y - min_p.y + 1) * sy)
	_opaque_cache[key] = rect
	return rect

# ---------------------------------------------------------------- 작은 그림들

## 발밑 그림자 — 멀수록 납작해진다(바닥 원을 비스듬히 본 모양)
class ShadowBlob extends Node2D:
	var radius: Vector2 = Vector2.ZERO
	var color: Color = Color(0.16, 0.11, 0.09, 0.27)

	## 반지름이 바뀌었을 때만 다시 그린다
	func set_radius(r: Vector2) -> void:
		if r.is_equal_approx(radius):
			return
		radius = r
		queue_redraw()

	func _draw() -> void:
		if radius.x < 0.5 or radius.y < 0.3:
			return
		var pts := PackedVector2Array()
		for i in 28:
			var t: float = TAU * i / 28.0
			pts.append(Vector2(radius.x * 0.08 + cos(t) * radius.x, sin(t) * radius.y))
		draw_colored_polygon(pts, color)

## 수갑 — 두 손목에 쇠고리 + 가운데 짧은 사슬. 리그의 자식이라 리그 좌표로 그린다
class Cuffs extends Node2D:
	var hand_l: Node2D = null
	var hand_r: Node2D = null
	## 손 그림 가운데에서 손목(몸 쪽)까지
	var back: float = 5.5
	var ring_size: Vector2 = Vector2(2.2, 5.4)
	var steel: Color = Color(0.8, 0.83, 0.88)
	var shine: Color = Color(1, 1, 1, 0.9)
	var line: Color = Color(0.07, 0.07, 0.09)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _wrist(hand: Node2D) -> Vector2:
		return hand.position + Vector2(-back, 1.2)

	## 두 손목의 가운데 — 밧줄이 여기 감긴다
	func center() -> Vector2:
		if hand_l == null or hand_r == null:
			return position
		return (_wrist(hand_l) + _wrist(hand_r)) * 0.5

	func _draw() -> void:
		if hand_l == null or hand_r == null:
			return
		var a: Vector2 = _wrist(hand_l)
		var b: Vector2 = _wrist(hand_r)
		for i in range(1, 3):
			var p: Vector2 = a.lerp(b, i / 3.0) + Vector2(0.0, ring_size.y * 0.3)
			draw_circle(p, ring_size.x * 0.75, line)
			draw_circle(p, ring_size.x * 0.42, steel)
		_ring(a)
		_ring(b)

	func _ring(c: Vector2) -> void:
		var pts := PackedVector2Array()
		for i in 21:
			var t: float = TAU * i / 20.0
			pts.append(c + Vector2(cos(t) * ring_size.x, sin(t) * ring_size.y))
		draw_polyline(pts, line, ring_size.x * 0.95, true)
		draw_polyline(pts, steel, ring_size.x * 0.45, true)
		draw_polyline(pts.slice(12, 16), shine, ring_size.x * 0.22, true)

## 식은땀 한 방울(만화 기호) — 나타나서 조금 흘러내리다 사라진다. 리그 좌표로 그린다
class SweatMark extends Node2D:
	var size: float = 4.0
	var life: float = 2.4
	var _age: float = 0.0

	func _process(delta: float) -> void:
		_age += minf(delta, 0.05)
		queue_redraw()
		if _age >= life:
			queue_free()

	func _draw() -> void:
		var pop: float = clampf(_age / 0.12, 0.0, 1.0)
		var fade: float = 1.0 - clampf((_age - (life - 0.5)) / 0.5, 0.0, 1.0)
		var s: float = size * (0.55 + 0.45 * pop)
		var drop := Vector2(0.0, size * 0.9 * clampf(_age / life, 0.0, 1.0))
		var pts := PackedVector2Array([drop + Vector2(0.0, -s * 2.2)])
		for i in 15:
			var deg: float = lerpf(-35.0, 215.0, i / 14.0)
			pts.append(drop + Vector2(cos(deg_to_rad(deg)), sin(deg_to_rad(deg))) * s)
		draw_colored_polygon(pts, Color(0.62, 0.86, 1.0, fade))
		var closed: PackedVector2Array = pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, Color(0.08, 0.13, 0.24, fade), maxf(s * 0.22, 0.6), true)
		draw_circle(drop + Vector2(-s * 0.35, -s * 0.15), s * 0.26, Color(1, 1, 1, 0.9 * fade))
