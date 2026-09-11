class_name SkillClashPopup
extends CanvasLayer

## 스킬 클래시(두 캐릭터가 같은 슬롯을 동시에 썼을 때) 연타 미니게임.
##
## 연출은 이렇다 — 시작하면 노란(P1)/파란(P2) 덩어리가 화면 밖에서 미끄러져 들어와 **쾅 하고 맞물리고**,
## 그 사선 경계가 그대로 밀당 게이지가 된다. 방금 부딪힌 슬롯의 키를 더 많이 연타한 쪽이 이긴다.
## 밀리는 쪽은 얼굴이 화면 끝으로 밀려나며 **고개가 뒤로 젖혀지고**, 이기는 쪽은 **고개를 앞으로 꺾는다**.
## 경계선에서는 스파크가 지직거린다.
## 게임 화면에서는 두 캐릭터가 손을 맞대고 대치한다(`BodyRig.set_clash`).
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
## 연타할 키의 슬롯 이름. **부딪힌 스킬이 뭐든 항상 이 키를 연타한다**(2026-09-10 기획) —
## 부딪힌 슬롯 키를 그대로 쓰면 스킬1로 부딪혔는지 궁극기로 부딪혔는지에 따라 눌러야 할 키가 매번 달라져서,
## 갑자기 화면이 멈춘 0.2초 안에 "이번엔 무슨 키더라"를 판단해야 한다. 항상 같은 키로 통일한다.
## 빈 문자열로 두면 예전처럼 부딪힌 슬롯의 키를 쓴다
@export var mash_action_id: String = "basic_attack"

## 얼굴 그림의 높이 (띠 높이 대비 비율)
@export var face_height_ratio: float = 0.92
## 밀당 상황에 따라 얼굴이 꺾이는 최대 각도(도). 이기는 쪽은 앞으로, 밀리는 쪽은 뒤로
@export var face_tilt_deg: float = 26.0
## 얼굴이 목표 각도를 따라가는 빠르기 (클수록 즉각적)
@export var face_follow_speed: float = 12.0

## 맞댄 손이 앞뒤로 밀고 밀리는 폭(px). 0이면 손이 붙은 채 가만히 있는다
@export var shove_amplitude: float = 8.0
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

enum Phase { IDLE, SLAM, MASH, ZOOM_OUT }

@onready var _band: ClashBand = $Band
@onready var _face_a: Sprite2D = $FaceA
@onready var _face_b: Sprite2D = $FaceB
@onready var _flash: ColorRect = $Flash

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
	# 서로 마주 보게 세운다 — 왼쪽(A)이 오른쪽을, 오른쪽(B)이 왼쪽을 본다
	_face_b.scale.x *= -1.0

	# 게임 화면의 두 캐릭터는 손을 맞대고 대치한다
	_set_clash_pose(true)

	_elapsed = 0.0
	_balance = 0.5
	_decided_early = false
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
	var target_h: float = _band.band_height() * face_height_ratio
	var s: float = target_h / maxf(float(tex.get_height()), 1.0)
	face.scale = Vector2(s, s)

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
					_a_won = (randf() < 0.5) if is_equal_approx(_balance, 0.5) else (_balance > 0.5)
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
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		_flash.color.a = flash_strength * (_flash_left / maxf(flash_fade_time, 0.001))
	if _shake_left > 0.0:
		_shake_left = maxf(_shake_left - delta, 0.0)

## 얼굴 위치·각도를 게이지에 맞춘다.
## 밀리는 쪽은 화면 끝으로 밀려나며 고개가 뒤로 젖혀지고, 이기는 쪽은 고개를 앞으로 꺾는다
func _update_faces(delta: float) -> void:
	# push_a: +1이면 A가 완전히 밀어붙이는 중, -1이면 완전히 밀리는 중
	var push_a: float = (_balance - 0.5) * 2.0
	_tilt_a = lerpf(_tilt_a, push_a, clampf(delta * face_follow_speed, 0.0, 1.0))
	var tilt: float = deg_to_rad(face_tilt_deg) * _tilt_a
	if _face_a.visible:
		_face_a.position = _band.face_anchor(true)
		# A는 오른쪽(상대)을 보고 있으므로 시계 방향(+)이 곧 "앞으로 꺾기"다
		_face_a.rotation = tilt
	if _face_b.visible:
		_face_b.position = _band.face_anchor(false)
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
	_set_clash_pose(false)
	finished.emit(_a_won)

## t가 0이면 원래 카메라, 1이면 두 캐릭터 중간을 확대해서 잡은 상태
func _apply_camera(t: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	var shake := Vector2.ZERO
	if _shake_left > 0.0:
		var k: float = _shake_left / maxf(shake_time, 0.001)
		shake = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength * k * k
	_camera.global_position = _camera_from_position.lerp(_camera_target_position, t) + shake
	_camera.zoom = _camera_from_zoom.lerp(_camera_from_zoom * zoom_amount, t)
