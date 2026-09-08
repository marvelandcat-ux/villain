class_name MouseGrab
extends Node2D

## 유선 마우스를 던져 상대를 잡아 끌어오는 그랩 (악플러 스킬1, 임시 도형 버전).
## 마우스(회색 도형)가 앞으로 날아가다 상대에 닿으면 "잡고", 유선(Line2D)으로 이어진 채
## 상대를 악플러 쪽으로 수평으로 끌어당긴다. 다 끌어오거나 빗나가면 사라진다.
## 상대를 끌어올 때는 상대의 movement_override를 잡아 수평 이동을 가로챈다(DashSkill과 같은 덕타이핑).

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
## 0 = 던지는 중, 1 = 끌어오는 중
var _state: int = 0
var _wire: Line2D
var _mouse: Polygon2D

func setup(source: Fighter, throw_speed: float, max_range: float, reel_speed: float, damage: int) -> void:
	_source = source
	_dir = source.facing
	_throw_speed = throw_speed
	_max_range = max_range
	_reel_speed = reel_speed
	_damage = damage
	_opponent = source.find_opponent()
	_mouse_pos = _hand_world()
	_build_shapes()

func _hand_world() -> Vector2:
	return _source.global_position + Vector2(_hand_offset.x * _dir, _hand_offset.y)

## 도형으로 마우스 몸통 + 유선을 만든다 (임시 — 나중에 그림으로 교체)
func _build_shapes() -> void:
	z_index = 20
	_wire = Line2D.new()
	_wire.width = 2.0
	_wire.default_color = Color(0.25, 0.25, 0.28)
	add_child(_wire)
	_mouse = Polygon2D.new()
	_mouse.color = Color(0.82, 0.82, 0.88)
	# 둥근 사각형 흉내낸 8각형 마우스 몸통
	_mouse.polygon = PackedVector2Array([
		Vector2(-7, -11), Vector2(7, -11), Vector2(9, -3), Vector2(9, 9),
		Vector2(5, 13), Vector2(-5, 13), Vector2(-9, 9), Vector2(-9, -3)])
	add_child(_mouse)
	# 버튼 분할선 느낌의 어두운 세로 막대
	var button := Polygon2D.new()
	button.color = Color(0.45, 0.45, 0.5)
	button.polygon = PackedVector2Array([Vector2(-1, -11), Vector2(1, -11), Vector2(1, -3), Vector2(-1, -3)])
	_mouse.add_child(button)

func _physics_process(delta: float) -> void:
	if not (_source and is_instance_valid(_source)):
		_release()
		return
	var hand: Vector2 = _hand_world()

	if _state == 0:
		# 앞으로 날아간다
		_mouse_pos.x += _dir * _throw_speed * delta
		if _opponent and is_instance_valid(_opponent) and _mouse_pos.distance_to(_opponent.global_position) < _catch_radius:
			_grab()
		elif absf(_mouse_pos.x - hand.x) >= _max_range:
			_release()  # 빗나감 → 사라진다
			return
	elif _state == 1:
		# 잡은 상대를 끌어온다 (마우스는 상대 몸에 붙어있다)
		if not (_opponent and is_instance_valid(_opponent)):
			_release()
			return
		_mouse_pos = _opponent.global_position
		if absf(_opponent.global_position.x - _source.global_position.x) <= _release_dist:
			_release()  # 다 끌어옴 → 놓아준다
			return

	# 유선·마우스 위치 갱신 (월드좌표를 로컬로 변환)
	_wire.points = PackedVector2Array([to_local(hand), to_local(_mouse_pos)])
	_mouse.position = to_local(_mouse_pos)
	_mouse.scale.x = _dir

## 잡는 순간 — 데미지를 조금 주고, 상대 수평 이동을 잡아채 끌어오기 시작한다
func _grab() -> void:
	_state = 1
	if _damage > 0:
		_opponent.take_damage(_damage)
	if _opponent.movement_override == null:
		_opponent.movement_override = self

## movement_override 인터페이스 — 상대를 악플러 쪽으로 수평으로 끌어당긴다 (Fighter.apply_physics가 부른다)
func get_move_velocity_x() -> float:
	if not (_opponent and _source and is_instance_valid(_opponent) and is_instance_valid(_source)):
		return 0.0
	return signf(_source.global_position.x - _opponent.global_position.x) * _reel_speed

func after_physics(_fighter: Fighter, _delta: float) -> void:
	pass

## 끝날 때 상대에게 걸어둔 movement_override를 반드시 해제한다 — 안 그러면 해제된 self를 참조하다 에러난다
func _release() -> void:
	if _opponent and is_instance_valid(_opponent) and _opponent.movement_override == self:
		_opponent.movement_override = null
	queue_free()

## 어떤 경로로 트리에서 빠지든(라운드 리로드 등) 상대 override를 반드시 풀어준다
func _exit_tree() -> void:
	if _opponent and is_instance_valid(_opponent) and _opponent.movement_override == self:
		_opponent.movement_override = null
