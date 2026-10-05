extends Node2D

## **헬스장 기구 배치 조정 씬** — 9가지(또는 그 이상) 배치를 눈으로 보고 맞춘다.
## F6으로 이 씬을 열면 바로 뜬다.
##
## 맵 전체를 띄우지 않고 **바닥·2층·벽만 똑같이 그려 놓는다** — 실제 대전 씬을 띄우면
## HUD·카메라·AI가 다 따라와서 기구를 끌기 어렵다. 치수는 `maps/Gym.tscn`에서 그대로 옮겨 왔으니
## 저 씬의 바닥 높이나 2층 폭을 고치면 **여기 export도 같이 고쳐야 한다**.
##
## 조작
##   1~6      : 배치 번호 고르기
##   [ ]      : 배치 번호를 앞뒤로
##   마우스 끌기: 기구 옮기기 — 누른 자리에서 제일 가까운 기구를 잡는다
##   방향키    : 잡은(마지막으로 만진) 기구를 1px씩. Shift를 누르면 10px씩
##   F        : 그 기구 좌우 뒤집기
##   G        : 바닥에 딱 붙이기(그 기구의 `ground_sink`까지 반영)
##   C        : 지금 배치를 **다음 번호로 복사** — 비슷한 배치를 만들 때 쓴다
##   S        : 저장
##
## 저장은 `maps/GymPlacements.tres` 하나만 건드린다. 맵 씬은 안 건드리므로 안전하다

## 고칠 배치표. 비어 있으면 아래 경로에서 불러오고, 그것도 없으면 새로 만든다
@export var placements: GymPlacement
## 저장할 곳
@export var save_path: String = "res://maps/GymPlacements.tres"
## 몇 가지를 만들지. **기구 3개를 자리 3곳에 놓는 경우의 수가 3! = 6가지**라 기본이 6이다 —
## 자리를 더 늘리면 그만큼 올려도 된다
@export var slot_count: int = 6

@export_group("맵 치수 (Gym.tscn과 맞출 것)")
## 1층 바닥 윗면 y
@export var ground_y: float = 280.0
## 2층 슬래브 윗면 y
@export var upper_y: float = 100.0
## 2층 슬래브가 걸쳐 있는 좌우 끝
@export var upper_half_width: float = 640.0
## 벽 안쪽 좌우 끝
@export var wall_half_width: float = 1228.0

@export_group("보기")
## 캐릭터가 얼마나 큰지 견줄 실루엣을 놓을 자리들
@export var dummy_spots: PackedVector2Array = PackedVector2Array([
	Vector2(-1050.0, 280.0), Vector2(1050.0, 280.0)])
## 실루엣 크기(px) — 실제 캐릭터가 대략 이만하다
@export var dummy_size: Vector2 = Vector2(52.0, 125.0)
## 맵 폭 2496이 한 화면에 들어오는 배율
@export var zoom: float = 0.7
## 카메라가 보는 한가운데 높이 — 바닥과 2층이 같이 보이는 자리
@export var camera_y: float = 55.0

## 기구 셋 — 맵에 있는 것과 같은 설정으로 만든다
var _machines: Array[GymMachine] = []
## 지금 고른 배치 번호
var _index: int = 0
## 마우스로 잡고 있는 기구
var _grabbed: GymMachine = null
## 잡은 순간의 마우스와 기구 자리 차이 — 이걸 더해야 기구가 튀지 않는다
var _grab_offset: Vector2 = Vector2.ZERO
## 방향키·F·G가 건드릴 기구(마지막으로 만진 것)
var _active: GymMachine = null
var _label: Label = null
var _saved_left: float = 0.0

func _ready() -> void:
	if placements == null:
		placements = load(save_path) as GymPlacement if ResourceLoader.exists(save_path) else GymPlacement.new()
	_build_stage()
	_build_machines()
	_build_ui()
	var cam := Camera2D.new()
	cam.zoom = Vector2(zoom, zoom)
	cam.position = Vector2(0.0, camera_y)
	add_child(cam)
	cam.make_current()
	_load_slot(0)

# --------------------------------- 배경 ---------------------------------

## 바닥·2층·벽을 맵과 같은 자리에 그린다. 충돌은 필요 없으니 그림만 둔다
func _build_stage() -> void:
	_fill(PackedVector2Array([
		Vector2(-3000, -2400), Vector2(3000, -2400), Vector2(3000, ground_y), Vector2(-3000, ground_y)]),
		Color(0.1451, 0.1569, 0.1765))
	_fill(PackedVector2Array([
		Vector2(-3000, ground_y), Vector2(3000, ground_y), Vector2(3000, 2400), Vector2(-3000, 2400)]),
		Color(0.0941, 0.0941, 0.0941))
	_fill(PackedVector2Array([
		Vector2(-upper_half_width, upper_y), Vector2(upper_half_width, upper_y),
		Vector2(upper_half_width, upper_y + 22.0), Vector2(-upper_half_width, upper_y + 22.0)]),
		Color(0.2196, 0.2235, 0.2588))
	# 벽과 바닥선 — 어디까지 놓을 수 있는지 눈으로 보이게
	for x in [-wall_half_width, wall_half_width]:
		_line(Vector2(x, ground_y), Vector2(x, ground_y - 900.0), Color(0.5, 0.52, 0.6, 0.7), 4.0)
	_line(Vector2(-upper_half_width, upper_y), Vector2(upper_half_width, upper_y),
		Color(0.6, 0.63, 0.71), 4.0)

func _fill(points: PackedVector2Array, color: Color) -> void:
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = color
	add_child(poly)

func _line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.default_color = color
	line.width = width
	add_child(line)

# --------------------------------- 기구 ---------------------------------

## 맵 씬에서 기구 셋만 떠다가 놓는다 — 크기·그림을 따로 적어 두면 맵과 어긋난다
func _build_machines() -> void:
	var packed: PackedScene = load("res://maps/Gym.tscn")
	var map: Node = packed.instantiate()
	var equipment: Node = map.get_node_or_null("Equipment")
	if equipment == null:
		map.queue_free()
		return
	for child in equipment.get_children():
		if not (child is GymMachine):
			continue
		child.owner = null   # 떼기 전에 풀어 둬야 "주인이 안 맞는다"는 경고가 안 뜬다
		equipment.remove_child(child)
		add_child(child)
		_machines.append(child)
	map.queue_free()
	for spot in dummy_spots:
		_build_dummy(spot)

## 캐릭터 크기 견주개 — 발이 바닥에 닿는 네모 하나면 충분하다
func _build_dummy(at: Vector2) -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-dummy_size.x * 0.5, -dummy_size.y), Vector2(dummy_size.x * 0.5, -dummy_size.y),
		Vector2(dummy_size.x * 0.5, 0.0), Vector2(-dummy_size.x * 0.5, 0.0)])
	poly.color = Color(0.95, 0.75, 0.25, 0.35)
	poly.position = at
	add_child(poly)

# --------------------------------- 안내문 ---------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(18, 14)
	_label.add_theme_font_size_override("font_size", 19)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_label)

func _refresh_label() -> void:
	if _label == null:
		return
	var lines: Array[String] = []
	lines.append("배치 %d / %d   (숫자키로 고르기, [ ]로 앞뒤)" % [_index + 1, slot_count])
	for machine in _machines:
		var mark: String = "▶ " if machine == _active else "   "
		lines.append("%s%s  x=%d  y=%d%s" % [mark, _korean_name(machine),
			roundi(machine.position.x), roundi(machine.position.y),
			"  (뒤집음)" if machine.flip else ""])
	lines.append("")
	lines.append("끌기=옮기기 · 방향키=1px(Shift 10px) · F=뒤집기 · G=바닥에 붙이기")
	lines.append("C=다음 번호로 복사 · S=저장")
	if _saved_left > 0.0:
		lines.append("")
		lines.append("저장했다 → %s" % save_path)
	_label.text = "\n".join(lines)

func _korean_name(machine: GymMachine) -> String:
	match machine.kind:
		GymMachine.Kind.SQUAT:
			return "스쿼트 랙"
		GymMachine.Kind.TREADMILL:
			return "런닝머신"
		_:
			return "바벨 거치대"

# --------------------------------- 배치 읽고 쓰기 ---------------------------------

## 그 번호의 배치를 화면에 올린다. 적어 둔 게 없으면 **기본 자리**를 깔아 준다
func _load_slot(index: int) -> void:
	_index = clampi(index, 0, maxi(slot_count - 1, 0))
	for machine in _machines:
		var fallback: Vector2 = _default_spot(machine, _index)
		machine.position = placements.spot(machine.kind, _index, fallback)
		machine.flip = placements.flipped(machine.kind, _index)
		machine.queue_redraw()
	_active = _machines[0] if not _machines.is_empty() else null
	_refresh_label()

## 아직 안 적은 번호에 깔아 줄 **시작 자리**. 어차피 끌어서 고칠 거라
## "서로 안 겹치고 아홉 가지가 눈에 띄게 다르면" 충분하다.
## 자리 후보 다섯 군데를 두고, 배치 번호마다 기구 셋에게 다르게 나눠 준다
const SEAT_SETS: Array = [
	[0, 1, 2], [1, 2, 0], [2, 0, 1],   # 1층 양 끝과 2층 가운데를 돌려쓰기
	[0, 2, 1], [1, 0, 2], [2, 1, 0],   # 그 나머지 순열
	[3, 1, 2], [0, 4, 2], [3, 4, 2],   # 1층 안쪽 자리를 섞은 변형
]

func _default_spot(machine: GymMachine, index: int) -> Vector2:
	var seats: Array[Vector2] = [
		Vector2(-900.0, ground_y),   # 0 1층 왼쪽 끝
		Vector2(900.0, ground_y),    # 1 1층 오른쪽 끝
		Vector2(0.0, upper_y),       # 2 2층 한가운데
		Vector2(-380.0, ground_y),   # 3 1층 왼쪽 안쪽
		Vector2(380.0, ground_y),    # 4 1층 오른쪽 안쪽
	]
	var set_at: Array = SEAT_SETS[index % SEAT_SETS.size()]
	var seat: Vector2 = seats[set_at[int(machine.kind) % set_at.size()]]
	return seat + Vector2(0.0, machine.ground_sink)

## 지금 화면의 자리를 그 번호에 적어 둔다
func _store_slot() -> void:
	for machine in _machines:
		placements.set_spot(machine.kind, _index, machine.position, machine.flip)

func _save() -> void:
	_store_slot()
	var err: int = ResourceSaver.save(placements, save_path)
	print("[저장] ", save_path, " 결과=", err, " / 적어 둔 배치 ", placements.count(), "개")
	_saved_left = 2.0
	_refresh_label()

## 지금 배치를 다음 번호에도 똑같이 적어 두고 그리로 넘어간다
func _copy_to_next() -> void:
	_store_slot()
	var next: int = (_index + 1) % maxi(slot_count, 1)
	for machine in _machines:
		placements.set_spot(machine.kind, next, machine.position, machine.flip)
	_load_slot(next)

# --------------------------------- 조작 ---------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_grab_at(get_global_mouse_position())
		else:
			if _grabbed != null:
				_store_slot()
			_grabbed = null
		return
	if event is InputEventMouseMotion and _grabbed != null:
		_grabbed.position = get_global_mouse_position() + _grab_offset
		_refresh_label()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	_key(event as InputEventKey)

## 누른 자리에서 **제일 가까운 기구**를 잡는다. 그림이 투명한 데가 많아 정확히 찍기 어렵다
func _grab_at(at: Vector2) -> void:
	var best: GymMachine = null
	var best_d: float = INF
	for machine in _machines:
		# 기구는 바닥에 서 있으므로, 몸통 한가운데를 기준으로 거리를 잰다
		var center: Vector2 = machine.position + Vector2(0.0, machine.top_offset() * 0.5)
		var d: float = center.distance_to(at)
		if d < best_d:
			best_d = d
			best = machine
	if best == null:
		return
	_grabbed = best
	_active = best
	_grab_offset = best.position - at
	_refresh_label()

func _key(key: InputEventKey) -> void:
	match key.keycode:
		KEY_S:
			_save()
			return
		KEY_C:
			_copy_to_next()
			return
		KEY_F:
			if _active:
				_active.flip = not _active.flip
				_active.queue_redraw()
				_store_slot()
				_refresh_label()
			return
		KEY_G:
			if _active:
				var floor_y: float = upper_y if _active.position.y < (ground_y + upper_y) * 0.5 else ground_y
				_active.position.y = floor_y + _active.ground_sink
				_store_slot()
				_refresh_label()
			return
		KEY_BRACKETLEFT:
			_store_slot()
			_load_slot(posmod(_index - 1, maxi(slot_count, 1)))
			return
		KEY_BRACKETRIGHT:
			_store_slot()
			_load_slot(posmod(_index + 1, maxi(slot_count, 1)))
			return
		KEY_TAB:
			# 다음 기구로 건너뛴다 — 겹쳐 있어서 마우스로 집기 어려울 때 쓴다
			if not _machines.is_empty():
				var at: int = _machines.find(_active)
				_active = _machines[posmod(at + 1, _machines.size())]
				_refresh_label()
			return
	# 숫자 키로 배치 번호 — 0은 10번째다
	if key.keycode >= KEY_1 and key.keycode <= KEY_9:
		_store_slot()
		_load_slot(key.keycode - KEY_1)
		return
	if key.keycode == KEY_0:
		_store_slot()
		_load_slot(9)
		return
	var step: float = 10.0 if key.shift_pressed else 1.0
	var move: Vector2 = Vector2.ZERO
	match key.keycode:
		KEY_LEFT:
			move.x = -step
		KEY_RIGHT:
			move.x = step
		KEY_UP:
			move.y = -step
		KEY_DOWN:
			move.y = step
	if move != Vector2.ZERO and _active:
		_active.position += move
		_store_slot()
		_refresh_label()

func _process(delta: float) -> void:
	if _saved_left > 0.0:
		_saved_left = maxf(_saved_left - delta, 0.0)
		if is_zero_approx(_saved_left):
			_refresh_label()
