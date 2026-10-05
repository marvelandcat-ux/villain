class_name MomDoorGimmick
extends Node2D

## 악플러의 집 "엄마 등짝" 기믹 — 주기마다 문 하나를 열고 `AkpeulleoMom`을 내보낸다.
## 엄마는 머무는 시간이 끝나면 **다른 문**으로 걸어가고, 도착하면 그 문을 열어 들여보낸 뒤 닫는다.
## 문 그림(Sprite2D)은 경첩 쪽 가장자리를 고정한 채 가로로 좁아지며 열리고, 뒤에 깔아 둔 어두운 문틈이 드러난다.
## 엄마는 이 노드의 자식으로 붙는다(맵 직속으로 붙이면 Stage가 맨 뒤에 둔 Fade 뒤로 들어간다)

@export var mom_scene: PackedScene
## 엄마가 드나드는 문들(2개 이상). 나올 문은 랜덤, 들어갈 문은 그 다음 문
@export var door_paths: Array[NodePath] = []
## 라운드 시작(카운트다운 끝)부터 첫 등장까지 / 엄마가 들어간 뒤 다음 등장까지(초). TODO: 기획 미정 — 임시값
@export var first_delay: float = 15.0
@export var interval: float = 20.0
## 문이 열리고 닫히는 시간(초)과 열렸을 때 남는 문 너비 비율
@export var open_time: float = 0.3
@export_range(0.05, 1.0, 0.01) var open_width: float = 0.2
## 엄마가 나온 뒤 문이 닫히기까지(초)
@export var close_after: float = 0.8
## 열린 문틈 색
@export var doorway_color: Color = Color(0.05, 0.04, 0.07)

var _doors: Array[Sprite2D] = []
## 문마다 닫힌 상태 {scale, position, width, hinge(-1 왼쪽 경첩 / +1 오른쪽)}
var _rest: Dictionary = {}
var _timer: float = 0.0
var _mom: Node = null
var _exit_door: Sprite2D = null

func _ready() -> void:
	_timer = first_delay
	# 부모(맵)가 아직 자식을 세팅하는 중이라 형제(문틈)를 바로 못 붙인다 — 한 박자 미룬다
	_setup_doors.call_deferred()

func _setup_doors() -> void:
	var sum_x: float = 0.0
	for path in door_paths:
		var door := get_node_or_null(path) as Sprite2D
		if door:
			_doors.append(door)
			sum_x += door.global_position.x
	if _doors.is_empty():
		return
	var mid_x: float = sum_x / _doors.size()
	for door in _doors:
		var size: Vector2 = _door_size(door)
		# 경첩은 바깥(벽) 쪽 — 왼쪽 문은 왼쪽 가장자리, 오른쪽 문은 오른쪽 가장자리를 붙잡고 열린다
		var hinge: float = -1.0 if door.global_position.x < mid_x else 1.0
		_rest[door] = {"scale": door.scale, "position": door.position, "width": size.x, "hinge": hinge}
		_add_doorway(door, size)

func _process(delta: float) -> void:
	if _mom != null or _doors.size() < 2 or _stage_paused():
		return
	_timer -= delta
	if _timer <= 0.0:
		_open_and_release()

## 카운트다운 중이거나 라운드가 끝났으면 시간도 안 세고 엄마도 안 내보낸다
func _stage_paused() -> bool:
	var stage: Node = get_parent()
	return stage != null and (stage.get("_countdown_active") == true or stage.get("_round_over") == true)

func _open_and_release() -> void:
	if mom_scene == null:
		return
	var i: int = randi() % _doors.size()
	var entry: Sprite2D = _doors[i]
	_exit_door = _doors[(i + 1) % _doors.size()]
	_set_door_open(entry, true)
	var mom := mom_scene.instantiate()
	# 값은 add_child 전에(_ready가 바로 돈다)
	mom.map = get_parent()
	mom.exit_feet = _door_feet(_exit_door)
	_mom = mom
	Timers.after(self, open_time, func() -> void:
		# 이 노드는 맵 원점에 그대로 있으니 position = 맵 좌표. 자리도 add_child 전에(엄마 _ready가 방향을 정한다)
		mom.position = to_local(_door_feet(entry) - Vector2(0.0, mom.FEET_OFFSET))
		add_child(mom)
		mom.exit_reached.connect(_on_mom_exit_reached)
		mom.vanished.connect(_on_mom_vanished)
		Timers.after(self, close_after, _set_door_open.bind(entry, false)))

func _on_mom_exit_reached() -> void:
	if _exit_door:
		_set_door_open(_exit_door, true)
	var mom := _mom
	Timers.after(self, open_time, func() -> void:
		if is_instance_valid(mom):
			mom.vanish())

func _on_mom_vanished() -> void:
	# 못 가서 그 자리에서 사라졌어도 열린 문이 남지 않게 전부 닫는다
	for door in _doors:
		_set_door_open(door, false)
	_mom = null
	_timer = interval

## 문 열기/닫기 — 경첩 쪽 가장자리를 고정한 채 가로로 좁힌다(열린 문은 살짝 어둡게)
func _set_door_open(door: Sprite2D, open: bool) -> void:
	if not is_instance_valid(door) or not _rest.has(door):
		return
	var rest: Dictionary = _rest[door]
	var k: float = open_width if open else 1.0
	var tween := door.create_tween().set_parallel(true)
	tween.tween_property(door, "scale:x", rest.scale.x * k, open_time)
	tween.tween_property(door, "position:x", rest.position.x + rest.hinge * rest.width * (1.0 - k) * 0.5, open_time)
	tween.tween_property(door, "self_modulate", Color(0.75, 0.75, 0.75) if open else Color.WHITE, open_time)

## 문 뒤에 깔아 둘 어두운 문틈 — 문 바로 앞 순서에 끼워 문에 가려져 있다가 문이 좁아지면 드러난다
func _add_doorway(door: Sprite2D, size: Vector2) -> void:
	var parent: Node = door.get_parent()
	var poly := Polygon2D.new()
	poly.z_index = door.z_index
	poly.color = doorway_color
	var h: Vector2 = size * 0.5
	poly.polygon = PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)])
	poly.position = door.position
	parent.add_child(poly)
	parent.move_child(poly, door.get_index())

## 문 그림의 실제 크기(px). 문은 centered Sprite2D + region
func _door_size(door: Sprite2D) -> Vector2:
	var base: Vector2 = door.region_rect.size if door.region_enabled else door.texture.get_size()
	return base * door.scale.abs()

## 문 앞 발바닥 자리 — 문 아래 끝에서 바닥을 찾는다
func _door_feet(door: Sprite2D) -> Vector2:
	var rest: Dictionary = _rest.get(door, {})
	var center_x: float = door.global_position.x
	var bottom: float = door.global_position.y + _door_size(door).y * 0.5
	if not rest.is_empty():
		# 열리는 중이면 그림이 옮겨져 있으니 닫힌 자리 기준으로
		center_x = door.get_parent().to_global(rest.position).x
		bottom = door.get_parent().to_global(rest.position).y + _door_size(door).y * 0.5
	# 못 찾으면 문 아래 끝보다 조금 위 — 발판 속에서 시작하면 통과 발판이라 그대로 빠져 떨어진다
	var y: float = PhysicsQuery.ground_y_below(self, Vector2(center_x, bottom - 30.0), 120.0, bottom - 8.0)
	return Vector2(center_x, y)
