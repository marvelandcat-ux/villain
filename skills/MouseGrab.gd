class_name MouseGrab
extends Node2D

## 유선 마우스를 던져 상대를 잡아 끌어오는 그랩 (악플러 스킬1).
## 세 단계로 진행된다 — ① 손에 쥔 채 어깨 뒤로 젖히기 ② 앞으로 날아가기 ③ 잡아서 끌어오기.
## ②는 곧게 날아가다가 사거리의 drop_after 지점(기본 50%)을 지나면 중력을 받아 아래로 처진다 —
## "힘이 빠져 떨어지는" 느낌이라, 끝까지 곧게 가던 예전보다 던진 거리가 눈에 읽힌다.
## 떨어지다 지면·발판에 닿으면 사거리가 남아 있어도 거기서 멈춘다(stop_on_ground).
## 빗나가면 그 자리에서 사라지지 않고 **유선에 딸려 손으로 되감긴 뒤** 사라진다(④ 되감기).
## 유선의 시작점은 고정 좌표가 아니라 리그의 **실제 오른손 위치**라, 팔을 젖히고 뿌리는 동안
## 줄이 손에 붙어서 같이 움직인다(손으로 잡고 있는 느낌).
## 던지는 동안은 `마우스 선.png`(마우스 몸통 + 뒤로 늘어지는 유선), 잡은 뒤에는
## `묶인거.png`(상대 몸에 감긴 케이블 + 악플러 손까지 이어지는 유선)를 그린다.
## 두 그림 모두 "케이블이 왼쪽으로 뻗고 물체가 오른쪽"이라, 왼쪽을 볼 때는 scale.x 부호를 뒤집는다.
## 상대를 끌어올 때는 상대의 movement_override를 잡아 수평 이동을 가로챈다(DashSkill과 같은 덕타이핑).

## 진행 단계 — 손에 쥐고 젖히는 중 / 날아가는 중 / 끌어오는 중
const STATE_WINDUP := 0
const STATE_FLY := 1
const STATE_REEL := 2
## 빗나가고 손으로 되감기는 중
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
## 사거리의 몇 %를 지났을 때부터 아래로 처지기 시작하는지 (0.5 = 절반 지점부터). 1이면 안 처진다
var drop_after: float = 0.5
## 처지기 시작한 뒤 받는 중력(px/초²)
var gravity: float = 5000.0
## 떨어지다 지면·발판에 닿으면 거기서 멈출지. 손 높이가 지면에서 27px뿐이라
## 이게 없으면 마우스가 땅에 박힌 채 미끄러져 간다
var stop_on_ground: bool = true
## 빗나간 뒤 손으로 되감기는 속도(px/초). 던질 때보다 빨라야 "탁 감긴다"는 느낌이 난다
var return_speed: float = 1100.0

var _source: Fighter
var _opponent: Fighter
var _dir: float = 1.0
var _throw_speed: float = 700.0
var _max_range: float = 260.0
var _reel_speed: float = 320.0
var _damage: int = 4
## 마우스가 상대 중심에서 이만큼 안에 들어오면 "잡았다"고 본다.
## 스킬 노드가 setup() 전에 덮어쓴다(상대 몸은 캡슐 20x60이라 이 값이 몸보다 좁다)
var catch_radius: float = 30.0
## 상대를 악플러에게서 이 거리까지 끌어오면 놓아준다
var _release_dist: float = 44.0
## 유선이 시작되는 손 위치(악플러 원점 기준). x는 바라보는 방향으로 반전된다
var _hand_offset: Vector2 = Vector2(22, -6)

var _mouse_pos: Vector2
## 처지기 시작한 뒤 쌓이는 낙하 속도(px/초). 손을 떠날 때 0에서 시작한다
var _fall_speed: float = 0.0
var _state: int = STATE_WINDUP
## 젖히는 단계에 남은 시간(초)
var _windup_left: float = 0.0
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
	_state = STATE_WINDUP if _windup_left > 0.0 else STATE_FLY
	_mouse_pos = _hand_world()
	_build_shapes()

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
			_state = STATE_FLY
	elif _state == STATE_FLY:
		# 손을 떠나 앞으로 날아간다. 수평 속도는 끝까지 그대로고, 사거리의 drop_after를 지난
		# 뒤부터만 아래로 가속이 붙는다 (거리로 재므로 던진 뒤 악플러가 걸어가도 판정이 같다)
		var flown: float = absf(_mouse_pos.x - hand.x)
		var was: Vector2 = _mouse_pos
		if flown >= _max_range * drop_after:
			_fall_speed += gravity * delta
			_mouse_pos.y += _fall_speed * delta
		_mouse_pos.x += _dir * _throw_speed * delta
		# 잡기 판정이 먼저다 — 상대 발밑에 떨어지는 프레임에서 착지가 먼저 걸리면
		# 맞을 만했던 한 발이 그냥 사라진다. 떨어지는 중에도 판정은 계속 살아있다
		if _touches_opponent():
			_grab()
		elif _hit_ground(was, _mouse_pos) or absf(_mouse_pos.x - hand.x) >= _max_range:
			_state = STATE_RETURN   # 땅에 떨어졌거나 사거리 끝 → 줄을 당겨 되감는다
	elif _state == STATE_RETURN:
		# 유선에 딸려 손으로 되감긴다. 마우스 몸통 뒤끝이 손에 닿으면 회수 완료.
		# 속도가 0 이하면 영영 안 돌아와 노드가 남으므로 그 경우는 바로 정리한다
		var to_hand: Vector2 = hand - _mouse_pos
		var gap: float = to_hand.length()
		if gap <= mouse_length or return_speed <= 0.0:
			_release()
			return
		_mouse_pos += to_hand / gap * minf(return_speed * delta, gap - mouse_length)
		# 되감기는 길에도 잡기 판정이 산다 — 돌아오는 마우스에 걸리면 그 자리에서 감아 끌어온다
		if _touches_opponent():
			_grab()
	elif _state == STATE_REEL:
		# 잡은 상대를 끌어온다 (케이블이 상대 몸에 감겨 있다)
		if not (_opponent and is_instance_valid(_opponent)):
			_release()
			return
		if absf(_opponent.global_position.x - _source.global_position.x) <= _release_dist:
			_release()  # 다 끌어옴 → 놓아준다
			return

	if _state == STATE_REEL:
		_draw_bound(hand)
	else:
		_draw_throw(hand)

## 손에 쥔 동안 + 날아가는 동안 — 마우스 몸통을 앞끝 자리에 놓고, 손에서 몸통 뒤끝까지 유선을 잇는다.
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

## 이번 프레임에 지나간 길이 지면·발판을 뚫었는지 — 뚫었으면 거기서 끝난다.
## **윗면(법선이 위를 향하는 면)만 본다** — 벽은 통과시키려는 것이다. 벽까지 막으면
## 벽 있는 맵에서 사거리가 맵 폭에 좌우돼서, 같은 스킬이 맵마다 다르게 느껴진다.
## 캐릭터는 몸으로 막으면 안 되므로 fighters 그룹을 전부 레이캐스트에서 뺀다(VomitBeam과 같은 방식)
func _hit_ground(from: Vector2, to: Vector2) -> bool:
	if not stop_on_ground or to.y <= from.y:
		return false   # 내려가는 중일 때만 검사한다
	var hit: Dictionary = PhysicsQuery.raycast_ignoring_fighters(self, from, to)
	if hit.is_empty():
		return false
	return hit["normal"].y < -0.5

## 잡는 순간 — 데미지를 조금 주고, 상대 수평 이동을 잡아채 끌어오기 시작한다
## 마우스가 상대 몸에 닿았는가 — 날아갈 때와 되감길 때가 같은 기준을 쓴다
func _touches_opponent() -> bool:
	if not is_instance_valid(_opponent):
		return false
	# **방어 중인 상대는 아예 안 잡힌다.** 잡아놓고 데미지만 0으로 막으면 끌려오는 건 그대로라
	# "1초 무적"이 무적이 아니게 된다. 안 잡히면 마우스는 그냥 지나쳐 날아가다 손으로 되감긴다
	# 슈퍼아머 중(경찰 바디 수플렉스 등)에도 안 잡힌다 — 끌려가면 쓰던 기술이 끊긴다
	if not _opponent.can_be_grabbed():
		return false
	return _mouse_pos.distance_to(_opponent.global_position) < catch_radius

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
	# 유선 마우스를 맞힌 순간 다음 기본공격 1번이 "키보드 회전 난무"로 강화된다(악플러)
	if is_instance_valid(_source):
		_source.custom_data["keyboard_spin_charged"] = true

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
