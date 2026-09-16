class_name SkillClashPopup
extends CanvasLayer

## 스킬 클래시(두 캐릭터가 같은 슬롯을 동시에 썼을 때) 연타 미니게임.
##
## 연출은 이렇다 — 시작하면 노란(P1)/파란(P2) 덩어리가 화면 밖에서 미끄러져 들어와 **쾅 하고 맞물리고**,
## 그 사선 경계가 그대로 밀당 게이지가 된다. 방금 부딪힌 슬롯의 키를 더 많이 연타한 쪽이 이긴다.
## 밀리는 쪽은 얼굴이 화면 끝으로 밀려나며 **고개가 뒤로 젖혀지고**, 이기는 쪽은 **고개를 앞으로 꺾는다**.
## 경계선에서는 스파크가 지직거린다.
## 게임 화면에서는 두 캐릭터가 **서로 미친 듯이 주먹을 내지른다**(`BodyRig.set_clash` / `clash_punch`) —
## 연타 한 번마다 그 쪽 캐릭터가 주먹을 두 방씩 내질러서, 누르는 속도가 그대로 주먹질 속도로 보인다.
##
## 사람이 조작하는 쪽은 자기 p{1|2}_<slot_id> 키를 연타하고, AI가 조작하는 쪽은 무작위 간격으로 자동 연타한다
## — 승패는 SkillClashManager가 받아서 스킬 발동/취소로 이어붙인다.
## SkillClashManager가 이미 get_tree().paused = true를 걸어두므로 이 노드는 process_mode ALWAYS로
## 계속 돈다(입력 폴링·카메라 갱신 모두 pause와 무관하게 동작한다)

signal finished(a_won: bool)

## 두 덩어리가 화면 밖에서 들어와 맞물리기까지 걸리는 시간(초) — 이 구간에도 연타는 이미 카운트된다
@export var slam_time: float = 0.22
@export var zoom_out_time: float = 0.18
## 밀당이 계속되는 최대 시간(초) — 게이지가 끝까지 안 밀리면 이 시간이 다 됐을 때 우세한 쪽이 이긴다.
## 1.6 -> 2.0 (2026-09-12). 초당 8타로 끝까지 미는 데 평균 1.63초가 걸려서 여유를 줬다
@export var mash_duration: float = 2.0
## 원래 카메라 배율의 몇 배로 확대해서 들어갈지
@export var zoom_amount: float = 2.4
## 한 번 연타할 때마다 게이지(0~1)가 자기 쪽으로 밀리는 양 — 작을수록 오래 밀당해야 한다.
## 가운데(0.5)에서 끝까지 **순수하게 약 6타 앞서면** 이긴다.
## **예전 값 0.035로는 끝까지 미는 게 불가능했다** — 초당 10타로 쳐도, 상대가 아예 안 눌러도 0%였다
## (복귀력이 초당 0.10씩 끌어당겨서 제한시간 동안 게이지의 2/3밖에 못 갔다. 60fps 시뮬레이션으로 확인)
@export var push_per_press: float = 0.09
## 아무도 안 누르면 게이지가 1초에 이만큼 가운데로 되돌아온다. 0이면 눌린 만큼 그대로 남는다.
## **앞선 쪽을 항상 뒤로 끌어당기는 힘이라 크게 주면 아무도 끝까지 못 민다** — 0.10에서 0.03으로 낮췄다
@export var balance_recenter: float = 0.03
## AI가 한 번 연타하는 데 걸리는 시간 범위(초). **이게 곧 AI 난이도다.**
## 0.16~0.24 = 평균 초당 5타. 예전 0.10~0.20(초당 6.7타)은 보통 사람 연타 속도와 비슷해서,
## 미는 양을 아무리 키워도 사람이 초당 9~10타는 쳐야 끝까지 밀 수 있었다
## 지금 값 기준 시뮬레이션: 사람 초당 8타 -> 98%가 약 1.6초에 끝까지 밂 / 7타 -> 16% (나머지는 시간 종료 때 앞서서 승리) /
## 사람이 안 누르면 AI가 1.2초쯤에 끝까지 밀어 이긴다
@export var ai_press_interval_min: float = 0.16
@export var ai_press_interval_max: float = 0.24
## 연타할 키의 슬롯 이름. **빈 문자열이면 방금 부딪힌 스킬의 키를 그대로 연타한다**(2026-09-16 변경).
## 예전(2026-09-10)엔 "무슨 키로 부딪혔는지 0.2초 안에 판단하기 어렵다"는 이유로 항상 basic_attack으로 고정했었다.
## 바꾼 이유: 부딪힌 순간 **손가락이 이미 그 키 위에 올라가 있다** — 방금 누른 키를 계속 두드리는 게 가장 자연스럽다.
## 게다가 이제 얼굴 아래에 눌러야 할 키(ClashKeyHint)가 크게 떠서 판단할 필요 자체가 없다.
## 다시 고정 키로 되돌리려면 여기에 "basic_attack" 같은 슬롯 이름을 넣으면 된다
@export var mash_action_id: String = ""

## 얼굴 그림의 높이 (띠 높이 대비 비율)
@export var face_height_ratio: float = 0.92

@export_group("누를 키 안내")
## 얼굴 아래에 "지금 두드릴 키 + 연타!"를 띄운다. AI 쪽에는 안 띄운다
@export var show_key_hint: bool = true
## 키 안내를 띄울 때는 얼굴을 줄여서 띠 위쪽으로 올린다 — 띠 안에 얼굴·키·글자를 다 넣으려고
@export var hint_face_height_ratio: float = 0.5
## 띠 가운데 기준 얼굴 / 키캡의 세로 위치(px, 음수가 위). 띠를 따라 기울어진다
@export var hint_face_offset: float = -52.0
@export var hint_key_offset: float = 20.0
@export_group("")
## 밀당 상황에 따라 얼굴이 꺾이는 최대 각도(도). 이기는 쪽은 앞으로, 밀리는 쪽은 뒤로
@export var face_tilt_deg: float = 26.0
## 얼굴이 목표 각도를 따라가는 빠르기 (클수록 즉각적)
@export var face_follow_speed: float = 12.0

## 두 캐릭터가 함께 앞뒤로 흔들리는 폭(px). **주먹 러시로 바꾸면서 0으로 껐다** —
## 손을 맞대고 밀던 시절의 흔들림이라, 주먹질과 겹치면 둘이 같이 춤추는 것처럼 보인다.
## 이기는 쪽이 전진하는 쏠림(shove_bias)은 그대로 쓴다
@export var shove_amplitude: float = 0.0
## 손이 앞뒤로 왕복하는 속도(라디안/초)
@export var shove_speed: float = 8.0
## 밀당이 한쪽으로 기울수록 왕복의 중심이 그쪽으로 밀린다 (px, 밀당 최대일 때 기준).
## 이게 없으면 게이지가 완전히 기울어도 두 사람이 제자리에서 손만 떠는 것처럼 보인다
@export var shove_bias: float = 10.0

## 맞물리는 순간 화면이 번쩍이는 세기(0~1)
@export var flash_strength: float = 0.85
@export var flash_fade_time: float = 0.22
## 맞물리는 순간 카메라가 흔들리는 세기(px)와 잦아드는 시간(초)
@export var shake_strength: float = 26.0
@export var shake_time: float = 0.35

@export_group("연타 중 흔들림")
## 한 번 누를 때마다 화면에 더해지는 흔들림(px). 둘이 같이 연타하면 계속 덜덜 떨린다
@export var press_shake: float = 2.5
## 연타 흔들림의 최대치(px)
@export var rumble_max: float = 7.0
## 흔들림이 잦아드는 빠르기(초당, 클수록 금방 멈춘다)
@export var rumble_decay: float = 9.0
## 띠·얼굴(UI)이 게임 화면 흔들림을 몇 배로 따라 흔들릴지. 0이면 게임 화면만 흔들린다
@export_range(0.0, 2.0, 0.05) var ui_shake_ratio: float = 0.6

@export_group("결착 연출")
## 이긴 쪽 색이 상대 쪽으로 차오르는 시간(초) — 물 따르듯 처음엔 머뭇거리다 가운데서 확 쏟아진다.
## 게이지 절반(0.5)만큼 차오를 때 기준이고, 남은 거리에 비례해서 짧아진다 —
## 이미 거의 다 밀어서 이겼으면 남은 조각만 휙 채우고 넘어간다
@export var pour_time: float = 0.45
## 차오르는 동안 물머리(경계선 가운데)가 앞으로 불룩 튀어나오는 폭(px)
@export var pour_bulge: float = 70.0
## 이긴 쪽 색으로 다 찬 뒤 날아가기 전까지 멈춰 있는 시간(초) — 색이 바뀐 걸 읽을 틈
@export var fly_delay: float = 0.15
## 띠가 진행 방향으로 날아가 화면 밖으로 빠지는 시간(초)
@export var fly_time: float = 0.38
## 날아가기 직전에 뒤로 움찔하는 세기 (0이면 움찔 없이 바로 가속한다)
@export_range(0.0, 2.0, 0.05) var fly_windup: float = 0.6
## 색이 다 찬 순간 이긴 쪽 얼굴이 커졌다 돌아오는 비율
@export_range(0.0, 0.5, 0.01) var winner_face_punch: float = 0.18

## MASH가 끝나면 POUR(이긴 쪽 색으로 차오르기) -> HOLD(잠깐 멈춤) -> FLY(띠가 날아감) -> ZOOM_OUT
enum Phase { IDLE, SLAM, MASH, POUR, HOLD, FLY, ZOOM_OUT }

@onready var _band: ClashBand = $Band
@onready var _face_a: Sprite2D = $FaceA
@onready var _face_b: Sprite2D = $FaceB
@onready var _flash: ColorRect = $Flash
@onready var _hint_a: ClashKeyHint = get_node_or_null("KeyHintA")
@onready var _hint_b: ClashKeyHint = get_node_or_null("KeyHintB")

var _phase: int = Phase.IDLE
var _elapsed: float = 0.0
## 밀당 게이지 — 0.5가 중앙(무승부 상태), 1.0이면 A 완승, 0.0이면 B 완승
var _balance: float = 0.5
var _decided_early: bool = false
var _a_won: bool = false

var _action_a: String = ""
var _action_b: String = ""
var _ai_a: bool = false
var _ai_b: bool = false
var _ai_wait_a: float = 0.0
var _ai_wait_b: float = 0.0

var _fighter_a: Fighter
var _fighter_b: Fighter

var _camera: Camera2D
var _camera_from_position: Vector2
var _camera_from_zoom: Vector2
var _camera_target_position: Vector2
var _shake_left: float = 0.0
var _flash_left: float = 0.0
## 얼굴 각도는 게이지를 그대로 따르지 않고 한 박자 늦게 따라간다 — 바로 붙이면 연타할 때마다 덜덜 떨린다
var _tilt_a: float = 0.0
## 맞댄 손이 앞뒤로 왕복하는 위상. 두 캐릭터가 **같은 값**을 받아야 손이 붙어서 함께 움직인다
var _shove_phase: float = 0.0
## 각자 누른 횟수 — 시간이 다 됐을 때 **더 많이 누른 쪽**이 이긴다
var _presses_a: int = 0
var _presses_b: int = 0
## 연타가 쌓아 올리는 흔들림(px). 누를 때마다 커지고 금방 잦아든다
var _rumble: float = 0.0
## 결착 때 게이지가 차오르기 시작한 값과 목표값
var _pour_from: float = 0.5
var _pour_to: float = 0.5
## 이번 차오르기에 걸리는 시간 (남은 거리에 비례)
var _pour_duration: float = 0.45
## 이긴 쪽이 밀던 방향 — 차오르는 방향이자 띠가 날아가는 방향 (+1 오른쪽 = A 승, -1 왼쪽 = B 승)
var _fly_dir: float = 1.0
## 얼굴의 원래 크기 — 이긴 쪽 얼굴을 튀길 때 기준
var _face_a_base: Vector2 = Vector2.ONE
var _face_b_base: Vector2 = Vector2.ONE

## fighter_a/fighter_b: 클래시를 벌이는 두 Fighter. slot_id: 부딪힌 스킬 슬롯("skill_1"/"skill_2"/
## "ultimate"/"basic_attack") — 이 슬롯의 키를 연타해야 한다. finished(a_won)으로 결과를 알린다
func start(fighter_a: Fighter, fighter_b: Fighter, slot_id: String) -> void:
	_fighter_a = fighter_a
	_fighter_b = fighter_b
	var mash_slot: String = mash_action_id if mash_action_id != "" else slot_id
	var control_a := _read_control(fighter_a, mash_slot)
	var control_b := _read_control(fighter_b, mash_slot)
	_action_a = control_a[0]
	_ai_a = control_a[1]
	_action_b = control_b[0]
	_ai_b = control_b[1]

	_camera = get_viewport().get_camera_2d()
	if _camera:
		_camera_from_position = _camera.global_position
		_camera_from_zoom = _camera.zoom
		_camera_target_position = (fighter_a.global_position + fighter_b.global_position) / 2.0

	_setup_face(_face_a, fighter_a)
	_setup_face(_face_b, fighter_b)
	_setup_hint(_hint_a, _action_a, _ai_a)
	_setup_hint(_hint_b, _action_b, _ai_b)
	# 서로 마주 보게 세운다 — 왼쪽(A)이 오른쪽을, 오른쪽(B)이 왼쪽을 본다
	_face_b.scale.x *= -1.0
	_face_a_base = _face_a.scale
	_face_b_base = _face_b.scale

	# 게임 화면의 두 캐릭터는 손을 맞대고 대치한다
	_set_clash_pose(true)

	_elapsed = 0.0
	_balance = 0.5
	_decided_early = false
	_presses_a = 0
	_presses_b = 0
	_rumble = 0.0
	_tilt_a = 0.0
	_shove_phase = 0.0
	_ai_wait_a = randf_range(ai_press_interval_min, ai_press_interval_max)
	_ai_wait_b = randf_range(ai_press_interval_min, ai_press_interval_max)
	_band.balance = _balance
	_band.slide = 0.0
	_flash.color.a = 0.0
	_phase = Phase.SLAM

## 캐릭터의 정면 얼굴 그림을 띠 높이에 맞춰 얹는다
func _setup_face(face: Sprite2D, fighter: Fighter) -> void:
	var path: String = GameState.PORTRAITS.get(fighter.stats.character_name, "")
	if path == "" or not ResourceLoader.exists(path):
		face.visible = false
		return
	var tex: Texture2D = load(path)
	face.texture = tex
	var ratio: float = hint_face_height_ratio if show_key_hint else face_height_ratio
	var target_h: float = _band.band_height() * ratio
	var s: float = target_h / maxf(float(tex.get_height()), 1.0)
	face.scale = Vector2(s, s)

## 키 안내를 켠다. 사람이 조작하는 쪽에만 — AI는 누를 사람이 없다
func _setup_hint(hint: ClashKeyHint, action: String, is_ai: bool) -> void:
	if hint == null:
		return
	hint.visible = show_key_hint and not is_ai and action != ""
	hint.modulate.a = 1.0
	hint.set_action(action)

## 띠를 따라 기울어진 세로 오프셋 — 얼굴·키캡이 띠와 같은 각도로 줄 선다
func _along_band(offset_y: float) -> Vector2:
	if not show_key_hint:
		return Vector2.ZERO
	return _band.band_transform().basis_xform(Vector2(0.0, offset_y))

## 두 캐릭터를 대치 자세로 세우거나(on) 푼다(off).
## **화면이 멈춰 있어도 자세가 움직여야 하므로 리그의 process_mode를 잠깐 ALWAYS로 올린다** —
## 안 그러면 pause 때문에 BodyRig._process가 아예 안 돌아서 대치 자세로 넘어가질 않는다
func _set_clash_pose(on: bool) -> void:
	for pair in [[_fighter_a, _fighter_b], [_fighter_b, _fighter_a]]:
		var f: Fighter = pair[0]
		var other: Fighter = pair[1]
		if not is_instance_valid(f):
			continue
		var rig := _find_rig(f)
		if rig == null:
			continue
		if on:
			# 상대 쪽을 보게 돌려세운다 — 등지고 손을 맞대면 그림이 안 맞는다
			if is_instance_valid(other):
				var dir: float = signf(other.global_position.x - f.global_position.x)
				f.facing = dir if dir != 0.0 else 1.0
			rig.process_mode = Node.PROCESS_MODE_ALWAYS
		else:
			rig.process_mode = Node.PROCESS_MODE_INHERIT
		rig.set_clash(on)

func _find_rig(fighter: Fighter) -> BodyRig:
	for child in fighter.get_children():
		if child is BodyRig:
			return child
	return null

## fighter를 조작하는 컨트롤러를 보고 [연타할 입력 액션, AI인지 여부]를 반환한다.
## 사람(PlayerController)이면 그 플레이어의 slot_id 키(예: p1_skill_1), AI(AIController)면 액션 없이 자동 연타
func _read_control(fighter: Fighter, slot_id: String) -> Array:
	for child in fighter.get_children():
		if child is PlayerController:
			return ["p%d_%s" % [child.player_index, slot_id], false]
		if child is AIController:
			return ["", true]
	return ["", true]

func _process(delta: float) -> void:
	match _phase:
		Phase.SLAM:
			var t: float = clampf(_elapsed / slam_time, 0.0, 1.0)
			# 뒤로 갈수록 빨라지게(가속) — 마지막에 확 부딪히는 느낌
			_band.slide = t * t
			_apply_camera(t)
			_tick_mash(delta)
			_elapsed += delta
			if t >= 1.0:
				_on_slam_impact()
		Phase.MASH:
			_apply_camera(1.0)
			_tick_mash(delta)
			_elapsed += delta
			if _decided_early or _elapsed >= mash_duration:
				if not _decided_early:
					_a_won = _decide_by_presses()
				_begin_result()
		Phase.POUR:
			_apply_camera(1.0)
			_elapsed += delta
			var u: float = clampf(_elapsed / maxf(_pour_duration, 0.001), 0.0, 1.0)
			# 물 따르듯 — 처음엔 머뭇거리다 가운데서 확 쏟아지고, 끝에서 차분히 찬다
			var e: float = 4.0 * u * u * u if u < 0.5 else 1.0 - pow(-2.0 * u + 2.0, 3.0) * 0.5
			_balance = lerpf(_pour_from, _pour_to, e)
			_band.balance = _balance
			# 물머리는 차오르는 한가운데서 가장 불룩하고, 다 차면 평평해진다
			_band.wave = pour_bulge * sin(u * PI) * _fly_dir
			# 진 쪽 얼굴은 화면 끝으로 밀려나며 흐려진다
			var faded: Sprite2D = _face_b if _a_won else _face_a
			faded.modulate.a = minf(faded.modulate.a, 1.0 - u)
			if u >= 1.0:
				_begin_hold()
		Phase.HOLD:
			_apply_camera(1.0)
			_elapsed += delta
			var uh: float = clampf(_elapsed / maxf(fly_delay, 0.001), 0.0, 1.0)
			_result_faces(uh)
			if uh >= 1.0:
				_begin_fly()
		Phase.FLY:
			_apply_camera(1.0)
			_elapsed += delta
			var uf: float = clampf(_elapsed / maxf(fly_time, 0.001), 0.0, 1.0)
			var prev_fly: float = _band.fly
			# 살짝 뒤로 움찔했다가 확 튀어나가는 곡선 — 그냥 미끄러지면 "사라진다"로 보이고 "날아간다"로 안 보인다
			_band.fly = _fly_dir * _band.fly_distance() * _ease_in_back(uf)
			# 이번 프레임에 움직인 만큼 뒤로 잔상이 끌린다 (빠를수록 길게)
			_band.trail = (_band.fly - prev_fly) * 1.4
			if uf >= 1.0:
				_band.trail = 0.0
				_phase = Phase.ZOOM_OUT
				_elapsed = 0.0
		Phase.ZOOM_OUT:
			var t2: float = clampf(_elapsed / zoom_out_time, 0.0, 1.0)
			_apply_camera(1.0 - t2)
			_elapsed += delta
			if t2 >= 1.0:
				_finish()
	_tick_effects(delta)
	_update_faces(delta)

## 두 덩어리가 맞물리는 순간 — 번쩍이고 흔들린다
func _on_slam_impact() -> void:
	_phase = Phase.MASH
	_elapsed = 0.0
	_band.slide = 1.0
	_flash_left = flash_fade_time
	_shake_left = shake_time

func _tick_effects(delta: float) -> void:
	if _rumble > 0.0:
		_rumble *= exp(-rumble_decay * delta)
		if _rumble < 0.05:
			_rumble = 0.0
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		_flash.color.a = flash_strength * (_flash_left / maxf(flash_fade_time, 0.001))
	if _shake_left > 0.0:
		_shake_left = maxf(_shake_left - delta, 0.0)

## 얼굴 위치·각도를 게이지에 맞춘다.
## 밀리는 쪽은 화면 끝으로 밀려나며 고개가 뒤로 젖혀지고, 이기는 쪽은 고개를 앞으로 꺾는다
func _update_faces(delta: float) -> void:
	# push_a: +1이면 A가 완전히 밀어붙이는 중, -1이면 완전히 밀리는 중
	# 결착 때 이긴 쪽 색을 화면 밖까지 채우느라 게이지가 0~1을 넘어가므로 기울기는 -1~1에서 자른다
	var push_a: float = clampf((_balance - 0.5) * 2.0, -1.0, 1.0)
	_tilt_a = lerpf(_tilt_a, push_a, clampf(delta * face_follow_speed, 0.0, 1.0))
	var tilt: float = deg_to_rad(face_tilt_deg) * _tilt_a
	# 키 안내는 얼굴 바로 아래를 따라간다. 연타 구간이 끝나면(결착 연출부터) 흐려져 사라진다
	var hint_alpha: float = 1.0 if (_phase == Phase.SLAM or _phase == Phase.MASH) else 0.0
	for pair in [[_hint_a, true], [_hint_b, false]]:
		var hint: ClashKeyHint = pair[0]
		if hint and hint.visible:
			hint.position = _band.face_anchor(pair[1]) + _along_band(hint_key_offset)
			hint.rotation = _band.band_transform().get_rotation()
			hint.modulate.a = move_toward(hint.modulate.a, hint_alpha, delta * 8.0)
	if _face_a.visible:
		_face_a.position = _band.face_anchor(true) + _along_band(hint_face_offset)
		# A는 오른쪽(상대)을 보고 있으므로 시계 방향(+)이 곧 "앞으로 꺾기"다
		_face_a.rotation = tilt
	if _face_b.visible:
		_face_b.position = _band.face_anchor(false) + _along_band(hint_face_offset)
		# B는 좌우가 뒤집혀 있어(scale.x < 0) 같은 각도가 화면에서는 반대로 보인다.
		# 그래서 같은 tilt를 넣어야 둘이 나란히 기우는 게 아니라 **서로 맞대고 밀치는** 그림이 된다
		_face_b.rotation = tilt
	# 맞댄 손이 앞뒤로 밀고 밀린다. **두 캐릭터에게 같은 값을 넣는다** — 각자 "앞으로"를 쓰면
	# 서로를 파고들어서 손이 어긋난다. 화면 기준 오프셋을 주고 방향 보정은 리그가 알아서 한다
	_shove_phase += delta * shove_speed
	var shove: float = sin(_shove_phase) * shove_amplitude + push_a * shove_bias

	# 게임 화면의 두 캐릭터도 같은 밀당을 몸으로 표현한다
	_push_rig(_fighter_a, push_a, shove)
	_push_rig(_fighter_b, -push_a, shove)

func _push_rig(fighter: Fighter, push: float, shove: float) -> void:
	if not is_instance_valid(fighter):
		return
	var rig := _find_rig(fighter)
	if rig:
		rig.set_clash_push(push)
		rig.set_clash_shove(shove)

## 아직 승부가 안 났으면 이번 프레임의 연타 입력(사람은 실제 키, AI는 시뮬레이션)을 게이지에 반영한다
func _tick_mash(delta: float) -> void:
	if _decided_early:
		return
	if _ai_a:
		_ai_wait_a -= delta
		if _ai_wait_a <= 0.0:
			_push(true)
			_ai_wait_a = randf_range(ai_press_interval_min, ai_press_interval_max)
	elif _action_a != "" and Input.is_action_just_pressed(_action_a):
		_push(true)

	if _ai_b:
		_ai_wait_b -= delta
		if _ai_wait_b <= 0.0:
			_push(false)
			_ai_wait_b = randf_range(ai_press_interval_min, ai_press_interval_max)
	elif _action_b != "" and Input.is_action_just_pressed(_action_b):
		_push(false)

	# 손을 놓으면 조금씩 가운데로 되돌아온다 — 한 번 앞서면 그대로 굳는 걸 막아서 끝까지 연타하게 만든다
	if balance_recenter > 0.0 and not _decided_early:
		_balance = move_toward(_balance, 0.5, balance_recenter * delta)
		_band.balance = _balance

## 한 번의 연타를 게이지에 반영한다. 끝까지 밀리면 그 자리에서 바로 승부가 난다(밀당 도중 조기 종료)
func _push(is_a_side: bool) -> void:
	if is_a_side:
		_presses_a += 1
	else:
		_presses_b += 1
	# 누를 때마다 화면이 툭 떨린다 — 둘이 같이 연타하면 계속 덜덜 흔들린다
	_rumble = minf(_rumble + press_shake, rumble_max)
	# 그 쪽 키캡이 꾹 눌린다 (AI 쪽은 안내 자체가 꺼져 있다)
	var hint: ClashKeyHint = _hint_a if is_a_side else _hint_b
	if hint:
		hint.press()
	# 누른 쪽 캐릭터가 주먹을 내지른다 — 연타 속도가 그대로 주먹질 속도가 된다
	_punch_rig(_fighter_a if is_a_side else _fighter_b)
	_balance = clampf(_balance + (push_per_press if is_a_side else -push_per_press), 0.0, 1.0)
	_band.balance = _balance
	if _balance >= 1.0:
		_a_won = true
		_decided_early = true
	elif _balance <= 0.0:
		_a_won = false
		_decided_early = true

func _finish() -> void:
	_phase = Phase.IDLE
	offset = Vector2.ZERO
	_set_clash_pose(false)
	finished.emit(_a_won)

## t가 0이면 원래 카메라, 1이면 두 캐릭터 중간을 확대해서 잡은 상태
func _apply_camera(t: float) -> void:
	var shake: Vector2 = _shake_vector()
	# 띠·얼굴이 올라간 이 CanvasLayer도 같이 흔든다 — 카메라만 흔들면 게임 화면만 떨리고 UI는 가만히 있어서 따로 논다
	offset = shake * ui_shake_ratio
	if _camera == null or not is_instance_valid(_camera):
		return
	_camera.global_position = _camera_from_position.lerp(_camera_target_position, t) + shake
	_camera.zoom = _camera_from_zoom.lerp(_camera_from_zoom * zoom_amount, t)

## 지금 프레임의 흔들림 — 맞물릴 때/접힐 때의 한 방(_shake_left)과 연타가 쌓은 떨림(_rumble)을 더한다
func _shake_vector() -> Vector2:
	var v := Vector2.ZERO
	if _shake_left > 0.0:
		var k: float = _shake_left / maxf(shake_time, 0.001)
		v += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength * k * k
	if _rumble > 0.0:
		v += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _rumble
	return v

## 시간이 다 됐을 때의 승자 — **더 많이 누른 쪽이 이긴다.**
## 게이지는 복귀력 때문에 가운데로 끌려와 있을 수 있어서, 게이지 위치보다 누른 횟수가
## "많이 친 쪽이 이긴다"와 정확히 맞는다. 횟수까지 같으면 게이지가 기운 쪽(마지막에 몰아친 쪽),
## 그것도 정확히 가운데면 동전 던지기
func _decide_by_presses() -> bool:
	if _presses_a != _presses_b:
		return _presses_a > _presses_b
	if not is_equal_approx(_balance, 0.5):
		return _balance > 0.5
	return randf() < 0.5

## 승부가 난 순간 — 흔들림을 딱 멈추고(정적), 이긴 쪽 색이 상대 쪽으로 화면 밖까지 차오르게 한다.
## 차오르는 시간은 남은 거리에 비례한다 — 이미 끝까지 밀어서 이겼으면 남은 구석만 휙 채운다
func _begin_result() -> void:
	_rumble = 0.0
	_fly_dir = 1.0 if _a_won else -1.0
	_pour_from = _balance
	_pour_to = _band.full_balance(_a_won)
	_pour_duration = clampf(pour_time * absf(_pour_to - _pour_from) / 0.5, 0.12, pour_time * 1.3)
	_phase = Phase.POUR
	_elapsed = 0.0

## 이긴 쪽 색으로 다 찼다 — 띠를 경계 없는 한 덩어리로 바꾸고 잠깐 멈춘다.
## 경계선이 이미 화면 밖이라 한 덩어리로 바꿔도 화면에 보이는 모양은 그대로다
func _begin_hold() -> void:
	_phase = Phase.HOLD
	_elapsed = 0.0
	_band.wave = 0.0
	_band.show_sparks = false
	_band.solid_color = _band.color_a if _a_won else _band.color_b
	_band.solid = true
	# 색이 다 바뀐 순간 가볍게 번쩍 — 맞물릴 때의 절반 세기
	_flash_left = flash_fade_time * 0.5

## 띠를 진행 방향으로 날려 보낸다. 출발할 때 한 번 쿵
func _begin_fly() -> void:
	_phase = Phase.FLY
	_elapsed = 0.0
	_shake_left = shake_time * 0.4

## 멈춘 동안: 진 쪽 얼굴은 사라지고, 이긴 쪽 얼굴은 한 번 커졌다 돌아온다
func _result_faces(u: float) -> void:
	var winner: Sprite2D = _face_a if _a_won else _face_b
	var loser: Sprite2D = _face_b if _a_won else _face_a
	var base: Vector2 = _face_a_base if _a_won else _face_b_base
	winner.scale = base * (1.0 + winner_face_punch * sin(u * PI))
	# 차오르는 동안 이미 흐려졌으면 다시 진해지지 않게 작은 쪽을 쓴다
	loser.modulate.a = minf(loser.modulate.a, 1.0 - u)

## 처음에 살짝 뒤로 갔다가(움찔) 점점 빨라지며 앞으로 튀어나가는 곡선. 0 -> 1
## fly_windup이 클수록 움찔이 커진다 (0.6이면 날아갈 거리의 약 1.3%만큼 뒤로 갔다 나간다)
func _ease_in_back(u: float) -> float:
	var c1: float = fly_windup
	return (c1 + 1.0) * u * u * u - c1 * u * u

## 이 캐릭터의 리그에 주먹 한 번(연타 한 번 분량)을 넣는다
func _punch_rig(fighter: Fighter) -> void:
	if not is_instance_valid(fighter):
		return
	var rig := _find_rig(fighter)
	if rig:
		rig.clash_punch()
