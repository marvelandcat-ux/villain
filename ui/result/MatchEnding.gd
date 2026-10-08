extends CanvasLayer

## 대전 최종 승부가 난 뒤의 **승리 → 패배 화면** 한 벌(그다음 연행 장면은 다른 씬이 맡는다).
##
## 흐름(전부 실제 시간): 승리(victory_time) → 와이프(wipe_time) → 패배(defeat_time) → 검게 닫힘(end_fade_time) → `finished`
##  - 화면 속 인물은 **그 판에서 실제로 싸운 캐릭터의 게임 속 리그**(`info.winner_rig` / `info.loser_rig`)
##  - 자기 플레이어 쪽에 선다: P1 = 왼쪽(오른쪽을 봄), P2 = 오른쪽(왼쪽을 봄)
##  - 리그는 Holder > Puppet(배율·좌우) > Mount(머리를 제자리에 맞추는 어긋남) > 리그 순으로 담는다.
##    **움직임은 Holder에만** 준다 — 리그 루트 scale은 BodyRig가 squash로 덮어써서 건드리면 안 된다
##  - 크기는 눈대중이 아니라 **머리 그림의 불투명 영역**(`BodyRig._opaque_rect_of`)을 재서 화면 높이에 맞춘다
##  - 시간은 `Time.get_ticks_usec()`로 잰다 → Engine.time_scale(슬로)·트리 일시정지에 안 흔들린다
##  - 손 들기·고개 숙이기는 리그가 그 프레임 자세를 다 잡은 **뒤에** 얹는다(`process_priority`가 리그보다 크다)
##
## 쓰는 법: `add_child(ending)` → `ending.play(info)` → `finished`. 끝나면 스스로 지운다(`free_on_finish`).
## 이 씬만 F6로 띄우면 `preview_*` 리그로 계속 반복 재생된다(승자 쪽이 번갈아 바뀐다)

signal finished

const ResultSfx = preload("res://ui/result/ResultSfx.gd")

enum Phase { IDLE, VICTORY, WIPE, DEFEAT, OUTRO, DONE }

@export_group("시간")
@export var victory_time: float = 3.5
@export var wipe_time: float = 0.28
@export var defeat_time: float = 3.0
## 와이프가 다 덮은 뒤 걷히는 시간(초)
@export var wipe_clear_time: float = 0.16
## 패배 화면 끝에 검게 닫히는 시간(초). 0이면 안 닫고 바로 끝낸다
@export var end_fade_time: float = 0.22
## 끝나면 스스로 지운다
@export var free_on_finish: bool = true

@export_group("승리 화면 인물")
## 머리 높이 / 화면 높이 — 머리가 화면 절반 넘게, 몸 아래는 화면 밖으로 잘린다
@export var victory_head_ratio: float = 0.66
## 머리 꼭대기 y / 화면 높이
@export var victory_head_top: float = 0.1
## 머리 가운데 x — 자기 쪽 화면 끝에서 잰 거리 / 화면 폭
@export var victory_head_x: float = 0.25
## 아래 구석에서 튀어 올라오는 시간(초)
@export var victory_enter_time: float = 0.42
## 통통 뛰는 한 번의 시간(초)과 높이(px)
@export var hop_period: float = 0.44
@export var hop_height: float = 28.0
## 뛸 때마다 좌우로 기우는 각도(도)
@export var hop_sway_deg: float = 2.2
## 앞주먹(든 무기째)을 머리 앞 위로 번쩍 들고 뛸 때마다 흔든다. 끄면 손은 숨쉬기만 한다.
## 뒷주먹은 안 든다 — 팔 없이 떠 있는 손이라 머리 뒤에 들면 귀처럼 보였다(실측)
@export var cheer_hands: bool = true
## 든 물건이 머리 높이의 이 배수보다 크면 주먹을 안 든다 — 키보드·단소처럼 큰 무기는 들면 얼굴을 가린다(실측).
## 사탕·소주병 정도는 든다
@export var cheer_max_item: float = 0.75

@export_group("패배 화면 인물")
@export var defeat_head_ratio: float = 0.6
@export var defeat_head_top: float = 0.13
@export var defeat_head_x: float = 0.27
## 위에서 털썩 떨어지는 시간(초)
@export var defeat_drop_time: float = 0.2
## 차갑고 어둡게 덮는 색(modulate)
@export var defeat_tint: Color = Color(0.68, 0.7, 0.92)
## 한숨 한 번의 시간(초)과 들이쉴 때 올라가는 높이(px)
@export var sigh_period: float = 1.45
@export var sigh_lift: float = 8.0
## 화면 동안 천천히 가라앉는 깊이(px)
@export var sink_depth: float = 34.0
## 고개 숙이는 각도(도)와 앞으로 기우는 각도(도)
@export var head_droop_deg: float = 12.0
@export var defeat_lean_deg: float = 3.0
## 부들부들 떠는 폭(px)
@export var shiver_px: float = 3.0

@export_group("글자")
## 이름표 색 — P1 파랑 / P2 빨강(라운드 띠와 같은 색)
@export var p1_color: Color = Color(0.17, 0.42, 0.92)
@export var p2_color: Color = Color(0.9, 0.18, 0.22)
## 패배 이름표는 이 색 쪽으로 빛을 뺀다
@export var defeat_tag_gray: Color = Color(0.33, 0.32, 0.45)

@export_group("미리보기(F6)")
@export_file("*.tscn") var preview_winner_rig: String = "res://characters/chokbeopsonyeon/ChokbeopsonyeonRig.tscn"
@export_file("*.tscn") var preview_loser_rig: String = "res://characters/subwayvillain/SubwayVillainRig.tscn"

## F6 미리보기에서 승자 쪽을 번갈아 바꾸려고 판마다 뒤집는다
static var _preview_p1_wins: bool = true

@onready var _victory: Control = $Victory
@onready var _v_backdrop: Control = $Victory/Backdrop
@onready var _v_confetti_back: Control = $Victory/BackConfetti
@onready var _v_holder: Node2D = $Victory/Holder
@onready var _v_puppet: Node2D = $Victory/Holder/Puppet
@onready var _v_mount: Node2D = $Victory/Holder/Puppet/Mount
@onready var _v_marks: Node2D = $Victory/Hype
@onready var _v_confetti_front: Control = $Victory/FrontConfetti
@onready var _v_title: Control = $Victory/Title
@onready var _defeat: Control = $Defeat
@onready var _d_backdrop: Control = $Defeat/Backdrop
@onready var _d_rain_back: Control = $Defeat/BackRain
@onready var _d_holder: Node2D = $Defeat/Holder
@onready var _d_puppet: Node2D = $Defeat/Holder/Puppet
@onready var _d_mount: Node2D = $Defeat/Holder/Puppet/Mount
@onready var _d_marks: Node2D = $Defeat/Gloom
@onready var _d_rain_front: Control = $Defeat/FrontRain
@onready var _d_vignette: Control = $Defeat/Vignette
@onready var _d_title: Control = $Defeat/Title
@onready var _wipe: Control = $Wipe
@onready var _fade: ColorRect = $Fade

var _phase: Phase = Phase.IDLE
## 지금 단계가 시작된 뒤 흐른 실제 초
var _t: float = 0.0
## 연출 전체에서 흐른 실제 초(떨림 같은 연속 움직임용)
var _clock: float = 0.0
var _last_us: int = 0
var _vis: Rect2 = Rect2(0, 0, 1280, 720)
var _preview_alone: bool = false
## 인물 한 명의 정보 — rig, head, head_rect(리그 기준 머리 네모), head_offset(머리 노드 → 머리 가운데),
## head_rest_scale, left(화면 왼쪽인지), facing, base(Holder 제자리), radius(화면 px), hands({이름: 제자리})
var _win: Dictionary = {}
var _lose: Dictionary = {}
var _snd_cheer: AudioStreamPlayer
var _snd_applause: AudioStreamPlayer
var _snd_rain: AudioStreamPlayer
var _snd_boo: AudioStreamPlayer
var _impact_done: bool = false
var _last_sigh: int = -1

func _ready() -> void:
	# 리그(우선순위 0)가 그 프레임 자세를 다 잡은 뒤에 손·고개를 얹으려고 늦게 돈다
	process_priority = 10
	_preview_alone = get_tree().current_scene == self
	if _preview_alone:
		_play_preview.call_deferred()

## 연출을 시작한다 — add_child 뒤에 부른다. info 키는 파일 맨 위 설명과 Stage 쪽 약속을 따른다:
## winner_rig / loser_rig(리그 경로), winner_is_p1, winner_name / loser_name, winner_p2_color / loser_p2_color, is_draw
func play(info: Dictionary) -> void:
	if _phase != Phase.IDLE:
		return
	if bool(info.get("is_draw", false)):
		# 무승부는 승리·패배 화면 없이 바로 연행으로 넘어간다
		_phase = Phase.DONE
		_finish.call_deferred()
		return
	var winner_p1: bool = bool(info.get("winner_is_p1", true))
	_win = _make_side(_v_mount, str(info.get("winner_rig", "")), bool(info.get("winner_p2_color", false)))
	_win["left"] = winner_p1
	_lose = _make_side(_d_mount, str(info.get("loser_rig", "")), bool(info.get("loser_p2_color", false)))
	_lose["left"] = not winner_p1
	_prepare_faces()
	_v_title.set("subtitle", "P%d %s" % [1 if winner_p1 else 2, str(info.get("winner_name", ""))])
	_v_title.set("tag_color", p1_color if winner_p1 else p2_color)
	_d_title.set("subtitle", "P%d %s" % [2 if winner_p1 else 1, str(info.get("loser_name", ""))])
	_d_title.set("tag_color", (p2_color if winner_p1 else p1_color).lerp(defeat_tag_gray, 0.35))
	_d_holder.modulate = defeat_tint
	_layout()
	get_viewport().size_changed.connect(_layout)
	_start_victory()

func _process(_delta: float) -> void:
	# 실제 시간 — delta는 Engine.time_scale에 눌리므로 쓰지 않는다
	var now: int = Time.get_ticks_usec()
	var dt: float = 0.0 if _last_us == 0 else minf(float(now - _last_us) / 1000000.0, 0.05)
	_last_us = now
	if _phase == Phase.IDLE or _phase == Phase.DONE:
		return
	_t += dt
	_clock += dt
	match _phase:
		Phase.VICTORY:
			_tick_victory(dt)
			if _t >= victory_time:
				_start_wipe()
		Phase.WIPE:
			_tick_victory(dt)
			_wipe.set("progress", _ease_in_quad(clampf(_t / maxf(wipe_time, 0.01), 0.0, 1.0)))
			if _t >= wipe_time:
				_start_defeat()
		Phase.DEFEAT:
			_tick_defeat(dt)
			if _t >= defeat_time:
				_start_outro()
		Phase.OUTRO:
			_tick_defeat(dt)
			var u: float = clampf(_t / maxf(end_fade_time, 0.01), 0.0, 1.0)
			_fade.color.a = u
			if u >= 1.0:
				_phase = Phase.DONE
				_finish()

# ---------------------------------------------------------------- 인물 준비

func _make_side(mount: Node2D, rig_path: String, p2_color: bool) -> Dictionary:
	var side: Dictionary = {"rig": null, "head": null}
	if rig_path == "" or not ResourceLoader.exists(rig_path):
		push_warning("MatchEnding: 리그 경로를 못 찾았다 — '%s'" % rig_path)
		return side
	var scene := load(rig_path) as PackedScene
	var node: Node = scene.instantiate() if scene != null else null
	var rig := node as BodyRig
	if rig == null:
		push_warning("MatchEnding: BodyRig가 아니다 — '%s'" % rig_path)
		if node != null:
			node.free()
		return side
	# 값은 add_child 전에 — 결과 화면에선 머리 긁기·뒤돌아보기 같은 혼자 노는 몸짓을 끈다
	rig.idle_gestures = false
	rig.swing_trail = false
	mount.add_child(rig)
	# 2P 색 몸통은 _ready가 몸통 그림을 기억한 **뒤에** 갈아 끼워야 남는다
	if p2_color:
		rig.set_player_two(true)
	side["rig"] = rig
	var head := rig.get_node_or_null("Head") as Sprite2D
	side["head"] = head
	var head_local := Rect2(-27, -27, 54, 54)
	var to_rig := Transform2D.IDENTITY
	if head != null and head.texture != null:
		side["head_rest_scale"] = head.scale
		head_local = _opaque_rect_in_sprite(rig, head)
		to_rig = rig.get_global_transform().affine_inverse() * head.get_global_transform()
	else:
		side["head_rest_scale"] = Vector2.ONE
	side["head_rect"] = _transform_rect(to_rig, head_local)
	# 머리 가운데를 "머리 노드 자리에서 얼마나 비켜 있나"로 기억한다 — 표정 그림이 바뀌어 배율이 달라져도 안 어긋난다
	side["head_offset"] = (side["head_rect"] as Rect2).get_center() - (head.position if head != null else Vector2.ZERO)
	var hands: Dictionary = {}
	for part_name in ["HandL", "HandR"]:
		var hand := rig.get_node_or_null(part_name) as Node2D
		if hand != null:
			hands[part_name] = hand.position
	side["hands"] = hands
	side["held_size"] = _held_item_size(rig)
	return side

## 앞손(HandRHold)에 든 보이는 물건의 크기(리그 기준, 가로·세로 중 큰 쪽). 빈손이면 0
func _held_item_size(rig: BodyRig) -> float:
	var hold := rig.get_node_or_null("HandRHold") as Node2D
	if hold == null:
		return 0.0
	var to_rig: Transform2D = rig.get_global_transform().affine_inverse()
	var out := Rect2()
	var found: bool = false
	for child in hold.get_children():
		var sprite := child as Sprite2D
		if sprite == null or not sprite.visible or sprite.texture == null:
			continue
		var r: Rect2 = _transform_rect(to_rig * sprite.get_global_transform(), sprite.get_rect())
		out = r if not found else out.merge(r)
		found = true
	return maxf(out.size.x, out.size.y) if found else 0.0

## 스프라이트 그림의 **확실히 보이는** 영역을 그 스프라이트 기준 좌표로 돌려준다
func _opaque_rect_in_sprite(rig: BodyRig, sprite: Sprite2D) -> Rect2:
	var tex: Texture2D = sprite.texture
	var tex_size: Vector2 = tex.get_size()
	var px: Rect2 = rig._opaque_rect_of(tex)
	if sprite.flip_h:
		px.position.x = tex_size.x - px.end.x
	if sprite.flip_v:
		px.position.y = tex_size.y - px.end.y
	var origin: Vector2 = sprite.offset - (tex_size * 0.5 if sprite.centered else Vector2.ZERO)
	return Rect2(px.position + origin, px.size)

static func _transform_rect(xf: Transform2D, r: Rect2) -> Rect2:
	var out := Rect2(xf * r.position, Vector2.ZERO)
	for corner in [Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		out = out.expand(xf * corner)
	return out

## 승자는 그 캐릭터의 **액션 표정**(신난 얼굴 — 금쪽이 메롱, 악플러 고함, 층간소음 웃음+박수, 일진 담배)으로,
## 없는 캐릭터는 평소 얼굴 그대로 둔다. 패자는 `_defeat_face()`가 고른 얼굴을 액션 표정 칸에 꽂아 유지한다.
## 액션 표정 칸을 빌리는 이유: 그 칸은 시간이 지나도 안 풀려서(피격 얼굴은 0.45초 뒤 풀린다) 화면 내내 유지된다
func _prepare_faces() -> void:
	var win_rig := _win.get("rig") as BodyRig
	if win_rig != null:
		win_rig.set_action_face(true)
		# 박수 자세가 있는 캐릭터(층간소음 빌런)는 주먹 대신 손뼉을 친다 — set_clapping이 액션 표정도 같이 켠다
		if win_rig.clap_open_pose != null and win_rig.clap_close_pose != null:
			win_rig.set_clapping(true)
			_win["claps"] = true
	var lose_rig := _lose.get("rig") as BodyRig
	if lose_rig == null:
		return
	var face: Array = _defeat_face(_lose)
	if face.is_empty():
		return
	lose_rig.action_head_texture = face[0]
	lose_rig.action_head_scale = face[1]
	lose_rig.set_action_face(true)

## 패배 얼굴 고르기 — [그림, 배율] 또는 빈 배열(평소 얼굴 유지).
##  1) **올라잇**(`curl_face_rise`): 이를 악물고 식은땀 흘리는 찡그림 — 레퍼런스 패배(이 악문 지하철 아저씨)와 제일 가깝다.
##     이름은 "올라잇"이지만 실제 그림은 힘주는 찡그림이라 승리엔 안 맞고 분한 얼굴로 딱이다
##  2) **피격**(`hurt_head_texture`): 얻어맞고 일그러진 얼굴
##  3) **힘든**(`curl_face_fall`): 입 벌리고 지친 얼굴
## KO 얼굴(눈 X)은 안 쓴다 — 기절이라 "분하고 우울한" 표정이 아니고, 대전 KO 연출과도 겹친다.
## 배율은 리그가 헬스장에서 그 얼굴을 띄울 때와 똑같이 계산한다(살색 높이를 평소 얼굴에 맞춤)
func _defeat_face(side: Dictionary) -> Array:
	var rig := side.get("rig") as BodyRig
	var rest: Vector2 = side.get("head_rest_scale", Vector2.ONE)
	var curl_base: Vector2 = rig.curl_face_scale if rig.curl_face_scale != Vector2.ZERO else rest
	if rig.curl_face_rise != null:
		return [rig.curl_face_rise, curl_base * rig._curl_face_fit(rig.curl_face_rise)]
	if rig.hurt_head_texture != null:
		return [rig.hurt_head_texture, rig.hurt_head_scale if rig.hurt_head_scale != Vector2.ZERO else rest]
	if rig.curl_face_fall != null:
		return [rig.curl_face_fall, curl_base * rig._curl_face_fit(rig.curl_face_fall)]
	return []

# ---------------------------------------------------------------- 배치

## 화면 크기에 맞춰 인물·글자 자리를 다시 잡는다(넓은 화면이면 좌우가 더 보인다)
func _layout() -> void:
	_vis = get_viewport().get_visible_rect()
	_frame_side(_win, _v_puppet, _v_mount, victory_head_ratio, victory_head_top, victory_head_x)
	_frame_side(_lose, _d_puppet, _d_mount, defeat_head_ratio, defeat_head_top, defeat_head_x)
	var win_left: bool = bool(_win.get("left", true))
	_v_backdrop.set("focus", Vector2(_side_x(win_left, victory_head_x), _vis.position.y + _vis.size.y * (victory_head_top + victory_head_ratio * 0.5)))
	_v_title.set("anchor", Vector2(_side_x(not win_left, 0.3), _vis.position.y + _vis.size.y * 0.4))
	_d_title.set("anchor", Vector2(_side_x(win_left, 0.27), _vis.position.y + _vis.size.y * 0.36))

## 자기 쪽 화면 끝에서 from_edge(화면 폭 비율)만큼 들어온 x
func _side_x(left: bool, from_edge: float) -> float:
	return _vis.position.x + _vis.size.x * from_edge if left else _vis.end.x - _vis.size.x * from_edge

## 머리 높이가 화면의 head_ratio가 되게 키우고, 머리 가운데를 정한 자리에 놓는다.
## Holder 원점 = 머리 바로 아래 화면 맨 밑 — 눌렸다 늘어날 때 발밑(화면 밖)이 아니라 화면 끝을 축으로 삼는다
func _frame_side(side: Dictionary, puppet: Node2D, mount: Node2D, head_ratio: float, head_top: float, head_x: float) -> void:
	if side.get("rig") == null:
		return
	var rect: Rect2 = side["head_rect"]
	var fit: float = head_ratio * _vis.size.y / maxf(rect.size.y, 1.0)
	var left: bool = bool(side.get("left", true))
	var facing: float = 1.0 if left else -1.0
	var cx: float = _side_x(left, head_x)
	var cy: float = _vis.position.y + _vis.size.y * (head_top + head_ratio * 0.5)
	side["facing"] = facing
	side["base"] = Vector2(cx, _vis.end.y)
	side["radius"] = (rect.size.x + rect.size.y) * 0.25 * fit
	puppet.scale = Vector2(fit * facing, fit)
	var c: Vector2 = rect.get_center()
	mount.position = Vector2(-c.x, (cy - _vis.end.y) / fit - c.y)

# ---------------------------------------------------------------- 승리

func _start_victory() -> void:
	_phase = Phase.VICTORY
	_t = 0.0
	_victory.visible = true
	_v_holder.position = Vector2(-10000, 0)
	_v_confetti_back.set("raining", true)
	_v_confetti_front.set("raining", true)
	_v_marks.set("facing", _win.get("facing", 1.0))
	# 양쪽 아래 구석에서 축포 두 방 — 엇갈려서 펑, 펑
	Timers.after(self, 0.06, _fire_popper.bind(true), true)
	Timers.after(self, 0.24, _fire_popper.bind(false), true)
	Timers.after(self, 0.12, func() -> void: _snd_cheer = ResultSfx.play(self, ResultSfx.CHEER, -2.0), true)
	Timers.after(self, 0.3, func() -> void: _snd_applause = ResultSfx.play(self, ResultSfx.APPLAUSE, -6.0), true)
	Timers.after(self, 0.3, Callable(_v_title, "show_title"), true)

func _fire_popper(left_corner: bool) -> void:
	var origin := Vector2(_vis.position.x - 12.0, _vis.end.y + 12.0) if left_corner else Vector2(_vis.end.x + 12.0, _vis.end.y + 12.0)
	var angle: float = -62.0 if left_corner else -118.0
	_v_confetti_back.call("burst", origin, angle, 18.0, 78, 950.0, 2200.0)
	_v_confetti_front.call("burst", origin, angle, 20.0, 16, 950.0, 2000.0)
	ResultSfx.play(self, ResultSfx.POPPER, -1.0, 1.0 if left_corner else 1.12)

func _tick_victory(dt: float) -> void:
	for node in [_v_backdrop, _v_confetti_back, _v_marks, _v_confetti_front, _v_title]:
		node.call("tick", dt)
	if _win.get("rig") == null:
		return
	var t: float = _t if _phase == Phase.VICTORY else victory_time + _t
	var facing: float = _win["facing"]
	# 아래 구석에서 빙그르 튀어 올라와 살짝 넘쳤다 자리 잡는다
	var e: float = _ease_out_back(clampf(t / maxf(victory_enter_time, 0.01), 0.0, 1.0), 1.6)
	var start_off := Vector2(-facing * _vis.size.x * 0.32, _vis.size.y * 0.75)
	var start_rot: float = -facing * 0.32
	# 통통 — 땅에 닿을 때 눌리고 떠오르며 늘어난다
	var ht: float = maxf(t - victory_enter_time, 0.0)
	var hw: float = clampf(ht / 0.15, 0.0, 1.0)
	var p: float = fmod(ht / maxf(hop_period, 0.05), 1.0)
	var height: float = sin(p * PI) * hw
	var contact: float = maxf(0.0, 1.0 - minf(p, 1.0 - p) / 0.14) * hw
	_v_holder.position = (_win["base"] as Vector2) + start_off * (1.0 - e) + Vector2(0.0, -height * hop_height)
	_v_holder.rotation = start_rot * (1.0 - e) + sin(ht * PI / maxf(hop_period, 0.05)) * deg_to_rad(hop_sway_deg) * hw
	_v_holder.scale = Vector2(1.0 + 0.075 * contact - 0.03 * height, 1.0 - 0.09 * contact + 0.05 * height)
	if cheer_hands and not bool(_win.get("claps", false)) 			and float(_win.get("held_size", 0.0)) <= (_win["head_rect"] as Rect2).size.y * cheer_max_item:
		# 손은 늘 머리 앞 위에 들려 있고, 뛰어오를 때마다 끝까지 뻗는다
		var w: float = smoothstep(0.1, 0.4, t)
		_cheer(_win, w * (0.78 + 0.22 * sin(p * PI)))
	_feed_marks(_v_marks, _win, clampf((t - 0.3) / 0.2, 0.0, 1.0))

## 앞주먹을 머리 앞 위쪽으로 들어 올린다(k: 0 = 리그 자세 그대로, 1 = 끝까지 듦).
## 리그가 이번 프레임 손 자리를 매번 새로 잡으므로 그 위에 목표 쪽으로 끌어당기기만 한다(쌓이지 않는다)
func _cheer(side: Dictionary, k: float) -> void:
	var rig := side["rig"] as BodyRig
	var hand := rig.get_node_or_null("HandR") as Node2D
	if hand == null:
		return
	var hr: Rect2 = side["head_rect"]
	var before_pos: Vector2 = hand.position
	var before_rot: float = hand.rotation
	hand.position = before_pos.lerp(Vector2(hr.end.x + hr.size.x * 0.17, hr.position.y + hr.size.y * 0.22), k)
	hand.rotation = lerp_angle(before_rot, -0.55, k)
	_follow_hold(rig, "HandR", before_pos, before_rot, hand)

## 손에 든 물건(HandRHold 등)도 손을 따라간다 — 리그가 방금 손 자리를 그대로 베껴 둔 경우에만 같이 옮긴다
func _follow_hold(rig: BodyRig, hand_name: String, before_pos: Vector2, before_rot: float, hand: Node2D) -> void:
	var hold := rig.get_node_or_null(hand_name + "Hold") as Node2D
	if hold == null:
		return
	if hold.position.is_equal_approx(before_pos) and is_equal_approx(hold.rotation, before_rot):
		hold.position = hand.position
		hold.rotation = hand.rotation

# ---------------------------------------------------------------- 와이프

func _start_wipe() -> void:
	_phase = Phase.WIPE
	_t = 0.0
	_wipe.set("from_right", not bool(_lose.get("left", false)))
	_wipe.set("progress", 0.0)
	_wipe.modulate.a = 1.0
	_wipe.visible = true
	ResultSfx.fade_out(_snd_cheer, 0.35)
	ResultSfx.fade_out(_snd_applause, 0.35)

# ---------------------------------------------------------------- 패배

func _start_defeat() -> void:
	_phase = Phase.DEFEAT
	_t = 0.0
	_victory.visible = false
	_defeat.visible = true
	_wipe.set("progress", 1.0)
	_d_holder.position = Vector2(-10000, 0)
	_d_marks.set("facing", _lose.get("facing", 1.0))
	_d_rain_back.call("start")
	_d_rain_front.call("start")
	var clear := create_tween().set_ignore_time_scale(true)
	clear.tween_property(_wipe, "modulate:a", 0.0, wipe_clear_time).set_delay(0.03)
	clear.tween_callback(_wipe.hide)
	Timers.after(self, 0.05, func() -> void: _snd_rain = ResultSfx.play(self, ResultSfx.RAIN, -15.0, 1.0, true), true)
	Timers.after(self, 0.45, Callable(_d_title, "show_title"), true)

func _tick_defeat(dt: float) -> void:
	for node in [_d_backdrop, _d_rain_back, _d_marks, _d_rain_front, _d_vignette, _d_title]:
		node.call("tick", dt)
	var t: float = _t if _phase == Phase.DEFEAT else defeat_time + _t
	if not _impact_done and t >= defeat_drop_time:
		_impact()
	if _lose.get("rig") == null:
		return
	var facing: float = _lose["facing"]
	# 위에서 털썩 — 떨어지는 동안 길쭉했다가 닿는 순간 찌그러지고 출렁이며 돌아온다
	var drop_u: float = clampf(t / maxf(defeat_drop_time, 0.01), 0.0, 1.0)
	var fall_y: float = -_vis.size.y * 0.9 * (1.0 - drop_u * drop_u)
	var tl: float = t - defeat_drop_time
	var sx: float = 0.94
	var sy: float = 1.08
	if tl >= 0.0:
		var bounce: float = exp(-6.5 * tl) * cos(17.0 * tl)
		sx = 1.0 + 0.11 * bounce
		sy = 1.0 - 0.15 * bounce
	# 한숨 — 천천히 들이쉬고(0 → 1) 길게 내쉰다(1 → 0). 내쉬기 시작할 때 입김이 나간다
	var breath: float = 0.0
	var shiver_env: float = exp(-5.0 * tl) if tl >= 0.0 else 0.0
	var st: float = tl - 0.4
	if st > 0.0:
		var sp: float = fmod(st / maxf(sigh_period, 0.1), 1.0)
		if sp < 0.42:
			breath = sin(sp / 0.42 * PI * 0.5)
		else:
			breath = cos((sp - 0.42) / 0.58 * PI * 0.5)
			shiver_env += exp(-7.0 * (sp - 0.42) * sigh_period) * 0.6
			var cycle: int = int(st / maxf(sigh_period, 0.1))
			if cycle != _last_sigh:
				_last_sigh = cycle
				_d_marks.call("sigh")
	var settle: float = maxf(tl, 0.0)
	sy += 0.022 * breath
	sx -= 0.008 * breath
	var sink: float = sink_depth * _ease_out_cubic(clampf(settle / 2.4, 0.0, 1.0))
	var shiver: float = sin(_clock * 58.0) * shiver_px * shiver_env
	_d_holder.position = (_lose["base"] as Vector2) + Vector2(shiver, fall_y + sink - breath * sigh_lift)
	_d_holder.scale = Vector2(sx, sy)
	_d_holder.rotation = facing * deg_to_rad(defeat_lean_deg) * _ease_out_cubic(clampf(settle / 1.0, 0.0, 1.0))
	_slump(_lose, _ease_out_cubic(clampf(settle / 0.7, 0.0, 1.0)), breath)
	_feed_marks(_d_marks, _lose, clampf((tl - 0.25) / 0.5, 0.0, 1.0))

## 털썩 내려앉는 순간 — 잠깐 아픈 얼굴(없는 캐릭터는 그냥 넘어간다) + 야유
## (슬픈 트롬본은 2026-10-08 사용자 요청으로 뺐다)
func _impact() -> void:
	_impact_done = true
	var rig := _lose.get("rig") as BodyRig
	if rig != null:
		rig.play_hurt_face()
	_snd_boo = ResultSfx.play(self, ResultSfx.BOO, -5.0)

## 고개를 숙이고 손을 축 늘어뜨린다(k: 0 = 리그 자세 그대로, 1 = 끝까지). 들이쉴 때(breath)는 조금 든다
func _slump(side: Dictionary, k: float, breath: float) -> void:
	if k <= 0.0:
		return
	var rig := side["rig"] as BodyRig
	var head := side.get("head") as Node2D
	if head != null:
		var droop: float = deg_to_rad(head_droop_deg) * (1.0 - 0.3 * breath)
		head.rotation = lerp_angle(head.rotation, droop, k)
	var hands: Dictionary = side.get("hands", {})
	for part_name in hands:
		var hand := rig.get_node_or_null(part_name) as Node2D
		if hand == null:
			continue
		var before_pos: Vector2 = hand.position
		var before_rot: float = hand.rotation
		var target: Vector2 = (hands[part_name] as Vector2) + Vector2(-1.5, 5.0 - 2.0 * breath)
		hand.position = before_pos.lerp(target, k)
		# 손목을 아래로 꺾어 든 무기가 축 늘어지게 한다(로컬 좌표라 좌우 반전에 저절로 맞는다)
		hand.rotation = lerp_angle(before_rot, 0.55, k)
		_follow_hold(rig, part_name, before_pos, before_rot, hand)

## 만화 기호에 머리 자리(화면 좌표)·크기를 넣는다 — 머리가 들썩여도 따라간다
func _feed_marks(marks: Node2D, side: Dictionary, strength: float) -> void:
	var head := side.get("head") as Node2D
	if head == null:
		marks.set("strength", 0.0)
		return
	var parent := head.get_parent() as Node2D
	var offset: Vector2 = (side["head_offset"] as Vector2).rotated(head.rotation)
	marks.set("center", parent.get_global_transform() * (head.position + offset))
	marks.set("radius", float(side.get("radius", 100.0)))
	marks.set("strength", strength)

# ---------------------------------------------------------------- 끝

func _start_outro() -> void:
	if end_fade_time <= 0.0:
		_phase = Phase.DONE
		_stop_sounds(0.2)
		_finish()
		return
	_phase = Phase.OUTRO
	_t = 0.0
	_fade.visible = true
	_stop_sounds(end_fade_time + 0.1)

func _stop_sounds(duration: float) -> void:
	for player in [_snd_rain, _snd_boo, _snd_cheer, _snd_applause]:
		if player != null and is_instance_valid(player):
			ResultSfx.fade_out(player, duration)

func _finish() -> void:
	finished.emit()
	if _preview_alone:
		_preview_p1_wins = not _preview_p1_wins
		Timers.after(self, 0.8, get_tree().reload_current_scene, true)
		return
	if free_on_finish:
		queue_free()

func _play_preview() -> void:
	play({
		"winner_rig": preview_winner_rig if _preview_p1_wins else preview_loser_rig,
		"loser_rig": preview_loser_rig if _preview_p1_wins else preview_winner_rig,
		"winner_is_p1": _preview_p1_wins,
		"winner_name": "승자",
		"loser_name": "패자",
		"winner_p2_color": not _preview_p1_wins,
		"loser_p2_color": _preview_p1_wins,
		"is_draw": false,
	})

# ---------------------------------------------------------------- 이징

static func _ease_out_back(u: float, s: float) -> float:
	var v: float = u - 1.0
	return 1.0 + (s + 1.0) * v * v * v + s * v * v

static func _ease_out_cubic(u: float) -> float:
	return 1.0 - pow(1.0 - u, 3.0)

static func _ease_in_quad(u: float) -> float:
	return u * u
