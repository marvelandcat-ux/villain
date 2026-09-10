class_name MouseGrab
extends Node2D

## 유선 마우스를 던져 상대를 잡아 끌어오는 그랩 (악플러 스킬1).
## 네 단계로 진행된다 — ① 손에 쥔 채 어깨 뒤로 젖히기 ② 포물선을 그리며 날아가기
## ③ 잡아서 끌어오기 ④ 빈 마우스를 손으로 되감기(판정 없음).
## ②에서 빗나가면 ③을 건너뛰고 바로 ④로 간다 — 예전에는 그 자리에서 그냥 사라졌다.
## 유선의 시작점은 고정 좌표가 아니라 리그의 **실제 오른손 위치**라, 팔을 젖히고 뿌리는 동안
## 줄이 손에 붙어서 같이 움직인다(손으로 잡고 있는 느낌).
## 던지는 동안은 `마우스 선.png`(마우스 몸통 + 뒤로 늘어지는 유선), 잡은 뒤에는
## `묶인거.png`(상대 몸에 감긴 케이블 + 악플러 손까지 이어지는 유선)를 그린다.
## 두 그림 모두 "케이블이 왼쪽으로 뻗고 물체가 오른쪽"이라, 왼쪽을 볼 때는 scale.x 부호를 뒤집는다.
## 상대를 끌어올 때는 상대의 movement_override를 잡아 수평 이동을 가로챈다(DashSkill과 같은 덕타이핑).

## 진행 단계 — 손에 쥐고 젖히는 중 / 날아가는 중 / 끌어오는 중 / 빈손으로 되감는 중
const STATE_WINDUP := 0
const STATE_FLY := 1
const STATE_REEL := 2
## 날아가는 게 끝났는데 아무도 못 잡았을 때(또는 다 끌어온 뒤) 마우스만 손으로 되돌아오는 단계.
## **이 단계에는 판정이 없다** — 되감기는 줄에 스치기만 해도 잡히면 던지는 쪽이 너무 유리해진다
const STATE_RETURN := 3

const MOUSE_TEXTURE_PATH := "res://sprite/악플러/몸/마우스 선.png"
const BOUND_TEXTURE_PATH := "res://sprite/악플러/몸/묶인거.png"

## 그림에서 잘라 쓰는 영역 — 유선과 물체를 따로 떼어야 유선만 늘릴 수 있다(물체까지 늘어나면 찌그러진다)
const MOUSE_CORD_REGION := Rect2(0, 333, 1751, 72)
const MOUSE_BODY_REGION := Rect2(1751, 259, 383, 174)
const BOUND_CORD_REGION := Rect2(0, 474, 722, 134)
const BOUND_COIL_REGION := Rect2(722, 292, 644, 491)
## 각 조각에서 "케이블 중심선"이 영역 위쪽에서 몇 px 아래인지 — 조각끼리 이어 붙이는 기준점
const MOUSE_CORD_AXIS := 35.0
const MOUSE_BODY_AXIS := 109.0
const BOUND_CORD_AXIS := 52.0
const BOUND_COIL_AXIS := 234.0
## 감긴 케이블 그림의 한가운데(이 점을 상대 몸 중심에 맞춘다)
const BOUND_COIL_CENTER := Vector2(322.0, 245.5)

## 마우스 몸통의 화면상 길이(px). 배율은 이 값에서 역산한다
var mouse_length: float = 30.0
## 상대 몸에 감긴 케이블 뭉치의 화면상 폭(px)
var coil_width: float = 50.0
## 마우스를 손에 쥔 채 젖히고 있는 시간(초). 이 시간이 지나야 손을 떠나 날아간다.
## 던지는 팔 동작(BodyRig.play_cast_motion)의 젖히는 구간과 같은 값이라야 손과 맞아떨어진다
var windup_time: float = 0.14
## 손을 떠날 때 위로 뜨는 초기 속도(px/초). 0이면 예전처럼 수평으로 곧게 날아간다
var throw_lift: float = 260.0
## 날아가는 마우스에 걸리는 중력(px/초^2). 이것 때문에 위로 떴다가 떨어지는 포물선이 된다
var throw_gravity: float = 900.0
## 되감을 때 손 쪽으로 당겨지는 속도(px/초)
var return_speed: float = 900.0
## 최대 비행 시간(초). 사거리보다 이쪽이 먼저 끝나면 그때 되감기 시작한다
var flight_time: float = 0.75

var _source: Fighter
var _opponent: Fighter
var _dir: float = 1.0
var _throw_speed: float = 700.0
var _max_range: float = 260.0
var _reel_speed: float = 320.0
var _damage: int = 4
## 마우스가 상대 몸에 이만큼 가까워지면 "잡았다"고 본다
var _catch_radius: float = 24.0
## 상대를 악플러에게서 이 거리까지 끌어오면 놓아준다
var _release_dist: float = 44.0
## 유선이 시작되는 손 위치(악플러 원점 기준). x는 바라보는 방향으로 반전된다
var _hand_offset: Vector2 = Vector2(22, -6)

var _mouse_pos: Vector2
## 날아가는 동안의 속도 — 매 프레임 중력이 더해져서 포물선이 된다
var _mouse_vel: Vector2 = Vector2.ZERO
var _state: int = STATE_WINDUP
## 젖히는 단계에 남은 시간(초)
var _windup_left: float = 0.0
## 날아가는 단계에 남은 시간(초)
var _fly_left: float = 0.0
## 캐릭터의 몸(BodyRig) — 실제 손 위치를 물어보고, 당기는 자세를 켜고 끈다
var _rig: Node2D
## 잡은 순간의 좌우 관계(상대가 악플러의 어느 쪽인지) — 끌어오는 내내 고정
var _bind_dir: float = 1.0
var _throw_cord: Sprite2D
var _mouse: Sprite2D
var _bound_cord: Sprite2D
var _coil: Sprite2D

func setup(source: Fighter, throw_speed: float, max_range: float, reel_speed: float, damage: int) -> void:
	_source = source
	_dir = source.facing
	_throw_speed = throw_speed
	_max_range = max_range
	_reel_speed = reel_speed
	_damage = damage
	_opponent = source.find_opponent()
	_rig = source.get_node_or_null("Visual") as Node2D
	_windup_left = maxf(windup_time, 0.0)
	_mouse_pos = _hand_world()
	if _windup_left > 0.0:
		_state = STATE_WINDUP
	else:
		_start_fly()
	_build_shapes()

## 손을 떠나는 순간 — 앞으로 던지면서 위로 살짝 띄운다. 이후 중력이 붙어 포물선을 그린다
func _start_fly() -> void:
	_state = STATE_FLY
	_fly_left = maxf(flight_time, 0.05)
	_mouse_vel = Vector2(_dir * _throw_speed, -throw_lift)

## 유선이 시작되는 지점 — 리그가 있으면 실제 오른손을 따라가고, 없으면 고정 좌표로 대충 맞춘다
func _hand_world() -> Vector2:
	if _rig and is_instance_valid(_rig) and _rig.has_method("get_hand_position"):
		return _rig.get_hand_position()
	return _source.global_position + Vector2(_hand_offset.x * _dir, _hand_offset.y)

## 그림 두 장을 네 조각(던지는 유선/마우스 몸통, 감긴 유선/케이블 뭉치)으로 잘라 만든다
func _build_shapes() -> void:
	z_index = 20
	var mouse_tex: Texture2D = load(MOUSE_TEXTURE_PATH)
	var bound_tex: Texture2D = load(BOUND_TEXTURE_PATH)
	if mouse_tex == null or bound_tex == null:
		push_warning("MouseGrab: 마우스 그림을 못 찾았다 — %s / %s" % [MOUSE_TEXTURE_PATH, BOUND_TEXTURE_PATH])
		return
	# 유선은 중심선이 시작점에 오도록 offset을 주고 늘린다(_stretch_cord 참고)
	_throw_cord = _make_piece(mouse_tex, MOUSE_CORD_REGION, Vector2(0, -MOUSE_CORD_AXIS))
	_mouse = _make_piece(mouse_tex, MOUSE_BODY_REGION, Vector2.ZERO)
	_bound_cord = _make_piece(bound_tex, BOUND_CORD_REGION, Vector2(0, -BOUND_CORD_AXIS))
	_coil = _make_piece(bound_tex, BOUND_COIL_REGION, Vector2.ZERO)

func _make_piece(tex: Texture2D, region: Rect2, offset: Vector2) -> Sprite2D:
	var piece := Sprite2D.new()
	piece.texture = tex
	piece.region_enabled = true
	piece.region_rect = region
	piece.centered = false
	piece.offset = offset
	piece.visible = false
	add_child(piece)
	return piece

func _physics_process(delta: float) -> void:
	if not (_source and is_instance_valid(_source)):
		_release()
		return
	var hand: Vector2 = _hand_world()

	if _state == STATE_WINDUP:
		# 아직 손에 쥔 채 뒤로 젖히는 중 — 마우스가 손을 따라다닌다
		_windup_left = maxf(_windup_left - delta, 0.0)
		# 마우스 몸통 가운데가 손에 오도록 앞끝을 반 칸 앞에 둔다 —
		# 날아가는 그리기와 같은 식이라 손을 떠나는 순간 유선 길이가 안 튄다
		_mouse_pos = hand + Vector2(_dir * mouse_length * 0.5, 0.0)
		if is_zero_approx(_windup_left):
			_start_fly()
	elif _state == STATE_FLY:
		# 손을 떠나 포물선을 그리며 날아간다 — 매 프레임 중력이 세로 속도에 더해진다
		_mouse_vel.y += throw_gravity * delta
		_mouse_pos += _mouse_vel * delta
		_fly_left = maxf(_fly_left - delta, 0.0)
		if _opponent and is_instance_valid(_opponent) and _mouse_pos.distance_to(_opponent.global_position) < _catch_radius:
			_grab()
		elif is_zero_approx(_fly_left) or absf(_mouse_pos.x - hand.x) >= _max_range:
			_start_return()  # 빗나감 → 그 자리에서 손으로 되감는다
	elif _state == STATE_REEL:
		# 잡은 상대를 끌어온다 (케이블이 상대 몸에 감겨 있다)
		if not (_opponent and is_instance_valid(_opponent)):
			_release()
			return
		if absf(_opponent.global_position.x - _source.global_position.x) <= _release_dist:
			# 다 끌어옴 → 상대를 놓아주고, 마우스는 상대가 있던 자리에서 손으로 되감는다
			_mouse_pos = _opponent.global_position
			_start_return()
	elif _state == STATE_RETURN:
		# 빈 마우스가 손으로 끌려온다. 판정이 없으므로 상대를 만나도 아무 일이 없다
		var to_hand: Vector2 = hand - _mouse_pos
		var step: float = return_speed * delta
		if to_hand.length() <= maxf(step, 1.0):
			_release()  # 손에 다 감겼다
			return
		_mouse_pos += to_hand.normalized() * step

	if _state == STATE_REEL:
		_draw_bound(hand)
	else:
		_draw_throw(hand)

## 손에 쥔 동안 + 날아가는 동안 + 되감는 동안 — 마우스 몸통을 앞끝 자리에 놓고, 손에서 몸통 뒤끝까지 유선을 잇는다.
## 쥐고 있을 때는 앞끝이 손보다 반 칸 앞이라 몸통이 손에 얹히고 유선은 주먹 뒤로 짧게 남는다
func _draw_throw(hand: Vector2) -> void:
	if _mouse == null:
		return
	_bound_cord.visible = false
	_coil.visible = false
	var s: float = mouse_length / MOUSE_BODY_REGION.size.x
	# 유선이 붙는 쪽(몸통의 뒤끝)은 날아가는 방향의 반대편이다
	var tail := Vector2(_mouse_pos.x - _dir * MOUSE_BODY_REGION.size.x * s, _mouse_pos.y)
	_mouse.visible = true
	_mouse.position = Vector2(tail.x, tail.y - MOUSE_BODY_AXIS * s)
	_mouse.scale = Vector2(_dir * s, s)
	_stretch_cord(_throw_cord, hand, tail, MOUSE_CORD_REGION.size.x, s)

## 잡은 뒤 — 상대 몸에 케이블 뭉치를 씌우고, 거기서 악플러 손까지 유선을 잇는다
func _draw_bound(hand: Vector2) -> void:
	if _coil == null:
		return
	_throw_cord.visible = false
	_mouse.visible = false
	var s: float = coil_width / BOUND_COIL_REGION.size.x
	var opponent_pos: Vector2 = _opponent.global_position
	_coil.visible = true
	_coil.position = Vector2(
		opponent_pos.x - _bind_dir * BOUND_COIL_CENTER.x * s,
		opponent_pos.y - BOUND_COIL_CENTER.y * s)
	_coil.scale = Vector2(_bind_dir * s, s)
	# 케이블이 뭉치에서 빠져나오는 지점(그림 왼쪽 변) — 좌우 반전해도 이 x는 그대로다
	var knot := Vector2(_coil.position.x, _coil.position.y + BOUND_COIL_AXIS * s)
	_stretch_cord(_bound_cord, hand, knot, BOUND_CORD_REGION.size.x, s)

## 유선 조각을 두 점 사이에 걸친다 — 굵기는 그대로 두고 길이만 늘린 뒤 두 점을 잇는 각도로 돌린다
func _stretch_cord(cord: Sprite2D, from: Vector2, to: Vector2, texture_length: float, thickness: float) -> void:
	if cord == null:
		return
	var delta: Vector2 = to - from
	var dist: float = delta.length()
	cord.visible = dist > 1.0
	if not cord.visible:
		return
	cord.position = from
	cord.rotation = delta.angle()
	cord.scale = Vector2(dist / texture_length, thickness)

## 잡는 순간 — 데미지를 조금 주고, 상대 수평 이동을 잡아채 끌어오기 시작한다
func _grab() -> void:
	_state = STATE_REEL
	_set_reeling(true)
	_bind_dir = signf(_opponent.global_position.x - _source.global_position.x)
	if _bind_dir == 0.0:
		_bind_dir = _dir
	if _damage > 0:
		_opponent.take_damage(_damage)
	if _opponent.movement_override == null:
		_opponent.movement_override = self

## 되감기 시작 — 상대에게 걸어둔 것을 먼저 풀고(이 단계엔 판정이 없다),
## 줄을 당기는 팔 자세를 켠다. 이 자세는 다른 동작(공격·스킬)이 시작되면 그쪽에 밀리지만,
## 마우스는 자세와 상관없이 손 위치를 따라 계속 끌려온다
func _start_return() -> void:
	_state = STATE_RETURN
	if _opponent and is_instance_valid(_opponent) and _opponent.movement_override == self:
		_opponent.movement_override = null
	_set_reeling(true)

## movement_override 인터페이스 — 상대를 악플러 쪽으로 수평으로 끌어당긴다 (Fighter.apply_physics가 부른다)
func get_move_velocity_x() -> float:
	if not (_opponent and _source and is_instance_valid(_opponent) and is_instance_valid(_source)):
		return 0.0
	return signf(_source.global_position.x - _opponent.global_position.x) * _reel_speed

func after_physics(_fighter: Fighter, _delta: float) -> void:
	pass

## 끝날 때 상대에게 걸어둔 movement_override를 반드시 해제한다 — 안 그러면 해제된 self를 참조하다 에러난다
func _release() -> void:
	_set_reeling(false)
	if _opponent and is_instance_valid(_opponent) and _opponent.movement_override == self:
		_opponent.movement_override = null
	queue_free()

## 줄을 당기는 팔 자세를 켜고 끈다 (리그가 없는 임시 사각형 캐릭터면 그냥 넘어간다)
func _set_reeling(on: bool) -> void:
	if _rig and is_instance_valid(_rig) and _rig.has_method("set_reeling"):
		_rig.set_reeling(on)

## 어떤 경로로 트리에서 빠지든(라운드 리로드 등) 상대 override를 반드시 풀어준다
func _exit_tree() -> void:
	_set_reeling(false)
	if _opponent and is_instance_valid(_opponent) and _opponent.movement_override == self:
		_opponent.movement_override = null
