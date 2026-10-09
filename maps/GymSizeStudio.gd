extends Node2D

## **헬스장 눈대중 조절 씬**(2026-10-07 사용자 요청: "실제 맵에 보이는 씬 만들어주면
## 내가 거기서 캐릭터들 맵 크기 대조하면서 크기 조정 할게").
##
## F6으로 띄우면 **진짜 헬스장 맵이 게임과 똑같은 화면 크기로** 나오고, 그 위에서
## 기구 크기·자리·2층 바닥을 키보드로 움직여 본 뒤 **그대로 파일에 저장**한다.
##
## | 저장되는 곳 | 무엇이 |
## |---|---|
## | `maps/Gym.tscn` | 기구 `scale`, 2층 바닥(`Floor2F/Slab`) 네 변 |
## | `maps/GymPlacements.tres` | 지금 보고 있는 배치 번호의 기구 자리·뒤집기 |
##
## ⚠️ **`Gym.tscn`을 통째로 instantiate 하되 트리에 안 넣는다.** 루트에 `Stage.gd`가 붙어 있어서
## 트리에 넣는 순간 `_ready()`가 돌며 선수를 불러오고 라운드가 시작된다. 노드는 **트리에 들어갈 때**
## `_ready()`가 도니까, 보여줄 가지만 떼어다 이쪽에 붙이면 전투 쪽은 한 줄도 안 돈다
##
## ⚠️ **기구 자리는 씬이 아니라 배치표(`GymPlacements.tres`)에 있다.** 그래서 자리 옮기기는
## `.tres`로, 크기는 `.tscn`으로 따로 저장된다

## 떼어다 쓸 맵 가지 — 전투(Stage·HUD·Wrap·Camera)는 빼고 **보이는 것만** 가져온다
const KEEP: Array[String] = ["DecoFar", "DecoBack", "Floor2F", "Ground", "Equipment"]
const GYM_SCENE := "res://maps/Gym.tscn"
## 캐릭터 리그 목록을 들고 있는 쪽 — `class_name`이 없어서 preload로 끌어 쓴다
const RIG_READER := preload("res://maps/workout/RigReader.gd")
## 캐릭터 원점은 발바닥보다 30px 위다(몸통 캡슐 반지름 20 + 높이 60의 절반)
const FEET_LIFT := 30.0
## 1층 바닥 높이 — 비교용 캐릭터를 세울 자리
const GROUND_Y := 621.0

## 무엇을 고르고 있는지
enum Target { CURL, SQUAT, TREADMILL, SLAB }
## 비교용 캐릭터를 어떻게 보여줄지
enum Cast { OFF, ONE, ALL }

@export_group("화면")
## 카메라가 보는 한가운데 — 게임의 헬스장 카메라와 같은 자리
@export var camera_at: Vector2 = Vector2(860, 360)
## 처음 배율. 1이면 게임에서 보이는 그대로다
@export var camera_zoom: float = 1.0

var _layout: GymLayout = null
var _machines: Dictionary = {}          ## {Target: GymMachine}
var _slab: TextureRect = null
var _camera: Camera2D = null
var _label: Label = null
var _panel: PanelContainer = null
## 고른 것을 감싸는 노란 네모 — 기구가 배경 그림에 섞여 어느 게 내 건지 안 보인다
var _marker: Line2D = null

## 지금 고른 대상과 배치 번호
var _target: int = Target.SQUAT
## **무엇을 고치는 중인지** — Tab으로 돌아간다: 0 기구 / 1 범위 선 / 2 운동할 때 설 자리
var _edit_mode: int = 0
var _arrangement: int = 0
## 비교용 캐릭터
var _cast_mode: int = Cast.ONE
var _cast_index: int = 0
var _cast_names: PackedStringArray = PackedStringArray()
var _cast_nodes: Array[Node2D] = []

## 처음 값(R로 되돌릴 때 쓴다) — {Target: {"scale": Vector2, "pos": Vector2, "flip": bool}}
var _origin: Dictionary = {}
var _slab_origin: Rect2 = Rect2()
## 마지막으로 저장한 결과를 화면에 한 줄 띄운다
var _notice: String = ""
var _notice_left: float = 0.0

func _ready() -> void:
	_steal_gym()
	_build_camera()
	_build_hud()
	_cast_names = RIG_READER.names()
	_apply_arrangement()
	_snapshot()
	_rebuild_cast()
	_refresh()

# ---------------------------------------------------------------- 맵 가져오기

## 맵의 **보이는 가지만** 떼어다 붙인다(위 주석의 ⚠️ 참고)
func _steal_gym() -> void:
	var packed := load(GYM_SCENE) as PackedScene
	if packed == null:
		push_error("헬스장 맵을 못 읽었다: " + GYM_SCENE)
		return
	var gym: Node = packed.instantiate()
	for part in KEEP:
		var node: Node = gym.get_node_or_null(part)
		if node == null:
			continue
		gym.remove_child(node)
		# **주인(owner)을 떼고 붙인다** — 안 떼면 곧 free할 `Gym`이 주인으로 남아 경고가 뜨고
		# 그 뒤로 그 가지의 주인이 삭제된 노드를 가리키게 된다
		_disown(node)
		add_child(node)
	gym.free()
	_layout = get_node_or_null("Equipment") as GymLayout
	_slab = get_node_or_null("Floor2F/Slab") as TextureRect
	if _layout == null:
		return
	for child in _layout.get_children():
		if child is GymMachine:
			_machines[(child as GymMachine).kind] = child

## 가지 전체의 주인을 떼어 놓는다
func _disown(node: Node) -> void:
	node.owner = null
	for child in node.get_children():
		_disown(child)

func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.name = "StudioCamera"
	_camera.position = camera_at
	_camera.zoom = Vector2(camera_zoom, camera_zoom)
	add_child(_camera)
	_camera.make_current()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	# 글씨가 맵 그림에 묻히지 않게 뒤에 어두운 판을 깐다
	var panel := PanelContainer.new()
	_panel = panel
	panel.position = Vector2(12, 10)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.78)
	style.set_content_margin_all(10.0)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	panel.add_child(_label)
	_marker = Line2D.new()
	_marker.name = "Marker"
	_marker.width = 2.0
	_marker.default_color = Color(1.0, 0.85, 0.25, 0.95)
	# 기구보다 앞에 그려야 테두리가 보인다
	_marker.z_index = 100
	_marker.z_as_relative = false
	add_child(_marker)

# ---------------------------------------------------------------- 키

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var step: float = 10.0 if key.shift_pressed else 1.0
	var grow: float = 0.05 if key.shift_pressed else 0.01
	match key.keycode:
		KEY_TAB, KEY_T: _edit_mode = (_edit_mode + 1) % 3
		KEY_1: _target = Target.CURL
		KEY_2: _target = Target.SQUAT
		KEY_3: _target = Target.TREADMILL
		KEY_4: _target = Target.SLAB
		KEY_LEFT: _nudge(Vector2(-step, 0.0))
		KEY_RIGHT: _nudge(Vector2(step, 0.0))
		KEY_UP: _nudge(Vector2(0.0, -step))
		KEY_DOWN: _nudge(Vector2(0.0, step))
		KEY_EQUAL, KEY_KP_ADD: _resize(1.0 + grow, step)
		KEY_MINUS, KEY_KP_SUBTRACT: _resize(1.0 / (1.0 + grow), -step)
		KEY_BRACKETLEFT: _thicken(-step)
		KEY_BRACKETRIGHT: _thicken(step)
		KEY_F: _flip()
		KEY_N: _cycle_arrangement()
		KEY_C: _cycle_cast()
		KEY_V: _next_character()
		KEY_R: _restore()
		KEY_0: _reset_view()
		KEY_ENTER, KEY_KP_ENTER, KEY_F5: _save()
		KEY_ESCAPE: get_tree().quit()
		_: return
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if wheel == null or not wheel.pressed or _camera == null:
		return
	# 휠로 가까이 가서 선이 맞는지 들여다볼 수 있게
	if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
		_camera.zoom *= 1.1
	elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_camera.zoom /= 1.1
	else:
		return
	_camera.zoom = _camera.zoom.clampf(0.4, 6.0)
	_refresh()

func _process(delta: float) -> void:
	if _notice_left <= 0.0:
		return
	_notice_left = maxf(_notice_left - delta, 0.0)
	if _notice_left == 0.0:
		_refresh()

# ---------------------------------------------------------------- 움직이기

func _machine() -> GymMachine:
	return _machines.get(_target) as GymMachine

## 고른 것을 옮긴다. 기구는 자리(배치표), 2층 바닥은 네 변이 움직인다
func _nudge(delta: Vector2) -> void:
	if _edit_mode == 2:
		# **운동할 때 설 자리** — 비교 캐릭터가 거기로 따라 선다
		var who: GymMachine = _machine()
		if who:
			who.snap_on_use = true
			who.stand_offset += delta.x
			# **위로 올리는 건 그림만** — 위쪽이 양수라 화살표 방향과 맞추려면 부호를 뒤집는다
			who.stand_lift -= delta.y
			_rebuild_cast()
		return
	if _edit_mode == 1:
		var m: GymMachine = _machine()
		if m:
			m.range_offset += delta
			m.queue_redraw()
		return
	if _target == Target.SLAB:
		if _slab == null:
			return
		_slab.offset_left += delta.x
		_slab.offset_right += delta.x
		_slab.offset_top += delta.y
		_slab.offset_bottom += delta.y
		return
	var machine: GymMachine = _machine()
	if machine:
		machine.position += delta

## 크기 — 기구는 통째로, 2층 바닥은 **가운데를 잡고 가로로만** 늘인다.
## 바닥을 세로로도 같이 늘이면 1층 천장 높이가 따라 바뀌어 버린다
func _resize(by: float, px: float = 0.0) -> void:
	if _edit_mode == 1:
		var m: GymMachine = _machine()
		if m:
			# 배수가 아니라 **px를 더한다** — 범위는 "기구 반폭 + 여유"라 여유를 직접 만지는 게 맞다
			m.range_margin += px
			m.queue_redraw()
		return
	if _target == Target.SLAB:
		if _slab == null:
			return
		var center: float = (_slab.offset_left + _slab.offset_right) * 0.5
		var half: float = (_slab.offset_right - _slab.offset_left) * 0.5 * by
		_slab.offset_left = center - half
		_slab.offset_right = center + half
		return
	var machine: GymMachine = _machine()
	if machine:
		machine.scale *= by

## 2층 바닥 두께(세로)만 바꾼다 — 눌린 정도가 곧 입체 효과라 따로 잡을 수 있어야 한다
func _thicken(by: float) -> void:
	if _edit_mode == 1:
		var m: GymMachine = _machine()
		if m:
			# 세로폭이 좁아야 **2층 기구를 1층에서 쓰는** 일이 안 생긴다
			m.use_range_y = maxf(m.use_range_y + by, 8.0)
			m.queue_redraw()
		return
	if _target != Target.SLAB or _slab == null:
		return
	_slab.offset_bottom = maxf(_slab.offset_bottom, _slab.offset_top + 4.0) + by

func _flip() -> void:
	var machine: GymMachine = _machine()
	if machine:
		machine.flip = not machine.flip

func _restore() -> void:
	if _slab and not _slab_origin.size.is_zero_approx():
		_slab.offset_left = _slab_origin.position.x
		_slab.offset_top = _slab_origin.position.y
		_slab.offset_right = _slab_origin.end.x
		_slab.offset_bottom = _slab_origin.end.y
	for kind in _machines:
		var machine: GymMachine = _machines[kind]
		var saved: Dictionary = _origin.get(kind, {})
		if saved.is_empty():
			continue
		machine.scale = saved["scale"]
		machine.position = saved["pos"]
		machine.flip = saved["flip"]
		machine.range_margin = saved["margin"]
		machine.range_offset = saved["roff"]
		machine.use_range_y = saved["ry"]
		machine.stand_offset = saved["stand"]
		machine.stand_lift = saved["lift"]
	_rebuild_cast()
	_say("처음 값으로 되돌렸다")

func _reset_view() -> void:
	if _camera == null:
		return
	_camera.position = camera_at
	_camera.zoom = Vector2(camera_zoom, camera_zoom)

## 지금 화면의 값을 "처음 값"으로 기억한다
func _snapshot() -> void:
	_origin.clear()
	for kind in _machines:
		var machine: GymMachine = _machines[kind]
		_origin[kind] = {"scale": machine.scale, "pos": machine.position, "flip": machine.flip,
			"margin": machine.range_margin, "roff": machine.range_offset,
			"ry": machine.use_range_y, "stand": machine.stand_offset,
			"lift": machine.stand_lift}
	if _slab:
		_slab_origin = Rect2(_slab.offset_left, _slab.offset_top,
			_slab.offset_right - _slab.offset_left, _slab.offset_bottom - _slab.offset_top)

# ---------------------------------------------------------------- 배치

func _table() -> GymPlacement:
	return _layout.placements if _layout else null

func _cycle_arrangement() -> void:
	var table: GymPlacement = _table()
	if table == null or table.count() == 0:
		return
	_arrangement = (_arrangement + 1) % table.count()
	_apply_arrangement()
	_rebuild_cast()

## 배치표 `_arrangement`번대로 기구를 놓는다.
## `GymLayout`은 게임에서 **무작위로** 고르기 때문에, 여기선 번호를 잡고 직접 놓아야
## 옮긴 자리를 그 번호에 되돌려 적을 수 있다
func _apply_arrangement() -> void:
	var table: GymPlacement = _table()
	if table == null or table.count() == 0:
		return
	_arrangement = clampi(_arrangement, 0, table.count() - 1)
	for kind in _machines:
		var machine: GymMachine = _machines[kind]
		machine.position = table.spot(kind, _arrangement, machine.position)
		machine.flip = table.flipped(kind, _arrangement)

# ---------------------------------------------------------------- 비교용 캐릭터

func _cycle_cast() -> void:
	_cast_mode = (_cast_mode + 1) % 3
	_rebuild_cast()

func _next_character() -> void:
	if _cast_names.is_empty():
		return
	_cast_index = (_cast_index + 1) % _cast_names.size()
	_rebuild_cast()

## 비교용으로 세울 캐릭터를 다시 깐다.
##
## **리그 씬만 띄운다** — 캐릭터 씬을 통째로 띄우면 `Fighter`가 돌아 중력에 떨어지고 입력을 먹는다.
## `BodyRig`는 부모가 `Fighter`가 아니면 가만히 서 있도록 이미 되어 있다
func _rebuild_cast() -> void:
	for node in _cast_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_cast_nodes.clear()
	if _cast_mode == Cast.OFF or _cast_names.is_empty():
		return
	if _cast_mode == Cast.ONE:
		# 고른 기구 옆(또는 **운동할 때 실제로 서는 자리**)에 한 명 세운다
		var machine: GymMachine = _machine()
		var at := Vector2(camera_at.x - 240.0, GROUND_Y)
		var face_left: bool = at.x > camera_at.x
		if machine:
			var ground: float = machine.position.y - machine.sink()
			if machine.snap_on_use:
				# **운동을 켰을 때 가는 그 자리**에 세운다 — 그래야 설 자리를 눈으로 맞출 수 있다
				at = Vector2(machine.stand_spot(Vector2(0.0, ground)).x, ground - machine.stand_lift)
				face_left = at.x > camera_at.x
			else:
				var reach: float = machine.width() * absf(machine.scale.x) * 0.5 + 60.0
				at = Vector2(machine.position.x - reach, ground)
				face_left = at.x > camera_at.x
			if not is_zero_approx(machine.face_dir):
				# 기구가 바라볼 쪽을 정해 뒀으면 그쪽을 따른다(런닝머신은 조작판 쪽)
				face_left = machine.face_dir < 0.0
		_stand(_cast_names[_cast_index], at, face_left)
		return
	# 전부 줄 세우기 — 맵 전체 폭과 사람 크기를 한눈에 견준다
	var span: float = 1560.0
	var count: int = _cast_names.size()
	for i in count:
		var t: float = 0.5 if count == 1 else float(i) / float(count - 1)
		_stand(_cast_names[i], Vector2(100.0 + span * t, GROUND_Y), t > 0.5)

## 리그 하나를 그 발바닥 자리에 세운다
func _stand(who: String, feet: Vector2, face_left: bool) -> void:
	var path: String = RIG_READER.path_of(who)
	if path == "" or not ResourceLoader.exists(path):
		return
	var rig := (load(path) as PackedScene).instantiate() as Node2D
	if rig == null:
		return
	rig.position = feet - Vector2(0.0, FEET_LIFT)
	if face_left:
		rig.scale.x = -absf(rig.scale.x)
	# 기구 앞에 서야 가려지지 않는다 — 기구는 z_index 0이다
	rig.z_index = 5
	add_child(rig)
	_cast_nodes.append(rig)

# ---------------------------------------------------------------- 화면 글씨

func _target_name() -> String:
	match _target:
		Target.CURL: return "바벨 거치대"
		Target.SQUAT: return "스쿼트 랙"
		Target.TREADMILL: return "런닝머신"
		_: return "2층 바닥"

func _cast_name() -> String:
	match _cast_mode:
		Cast.OFF: return "끔"
		Cast.ONE: return _cast_names[_cast_index] if not _cast_names.is_empty() else "없음"
		_: return "전부 줄 세우기"

func _refresh() -> void:
	if _label == null:
		return
	var table: GymPlacement = _table()
	var total: int = table.count() if table else 0
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[헬스장 눈대중 조절]   고른 것: %s%s" % [
		_target_name(), ["", "  ← 범위 선 고치는 중 (Tab)", "  ← 설 자리 고치는 중 (Tab)"][_edit_mode]])
	lines.append("")
	if _target == Target.SLAB and _slab:
		lines.append("  좌 %s   우 %s   폭 %s   두께 %s" % [
			_num(_slab.offset_left), _num(_slab.offset_right),
			_num(_slab.offset_right - _slab.offset_left),
			_num(_slab.offset_bottom - _slab.offset_top)])
		lines.append("  ←→ 좌우로 밀기    ↑↓ 위아래    +/- 가로 늘이기    [ ] 두께")
	else:
		var machine: GymMachine = _machine()
		if machine:
			if _edit_mode == 2:
				lines.append("  운동할 때 설 자리: 가로 %s px   들어올림 %s px   (끌어오기 %s)" % [
					_num(roundf(machine.stand_offset)), _num(roundf(machine.stand_lift)),
					"켬" if machine.snap_on_use else "끔"])
				lines.append("  ←→ 좌우      ↑↓ 그림만 위아래      Tab 다음으로   (Shift 10배)")
				lines.append("  C 를 눌러 캐릭터를 켜 두면 그 자리에 서 보여준다")
			elif _edit_mode == 1:
				lines.append("  범위 가로 ±%s   세로 ±%s   (기구 반폭 %s + 여유 %s)" % [
					_num(roundf(machine.range_x())), _num(roundf(machine.use_range_y)),
					_num(roundf(machine.width() * absf(machine.scale.x) * 0.5)),
					_num(roundf(machine.range_margin))])
				lines.append("  선 자리 (%s, %s)      ←→↑↓ 선 옮기기    +/- 가로폭    [ ] 세로폭" % [
					_num(roundf(machine.range_offset.x)), _num(roundf(machine.range_offset.y))])
				lines.append("  Tab 기구로 돌아가기      (Shift 누르면 10배)")
			else:
				lines.append("  크기 %s   자리 (%s, %s)   뒤집기 %s   범위 ±%s" % [
					_num(machine.scale.x), _num(machine.position.x), _num(machine.position.y),
					"O" if machine.flip else "X", _num(roundf(machine.range_x()))])
				lines.append("  ←→↑↓ 옮기기    +/- 크기    F 뒤집기    Tab 범위/설자리")
	lines.append("")
	lines.append("  1 바벨거치대   2 스쿼트랙   3 런닝머신   4 2층바닥")
	lines.append("  N 다음 배치 (%d/%d)    C 캐릭터 %s    V 다음 캐릭터" % [
		_arrangement + 1, maxi(total, 1), _cast_name()])
	lines.append("  휠 확대/축소    0 화면 원래대로    R 되돌리기    Esc 끄기")
	lines.append("  Tab(또는 T) = 기구 -> 범위 선 -> 설 자리 차례로")
	lines.append("  Enter 저장  →  Gym.tscn(크기) + GymPlacements.tres(자리)")
	if _notice_left > 0.0:
		lines.append("")
		lines.append("  " + _notice)
	_label.text = "\n".join(lines)
	if _panel:
		_panel.reset_size()   # 줄이 길어지면 뒷판도 같이 늘어나야 글씨가 안 삐져나온다
	_mark()

## 고른 것을 노란 네모로 감싼다 — 기구 그림이 배경에 그려진 기구들과 똑같이 생겨서
## 테두리가 없으면 내가 지금 뭘 움직이는지 알 수가 없다
func _mark() -> void:
	if _marker == null:
		return
	var rect: Rect2 = Rect2()
	if _target == Target.SLAB and _slab:
		var base: Vector2 = (_slab.get_parent() as Node2D).global_position
		rect = Rect2(base + Vector2(_slab.offset_left, _slab.offset_top),
			Vector2(_slab.offset_right - _slab.offset_left, _slab.offset_bottom - _slab.offset_top))
	else:
		var machine: GymMachine = _machine()
		if machine == null:
			_marker.clear_points()
			return
		if _edit_mode == 1:
			# 지금 고치는 게 범위라는 걸 보이게 — 범위 네모를 그대로 감싼다
			var c: Vector2 = machine.range_center()
			_marker.points = PackedVector2Array([
				c + Vector2(-machine.range_x(), -machine.use_range_y),
				c + Vector2(machine.range_x(), -machine.use_range_y),
				c + Vector2(machine.range_x(), machine.use_range_y),
				c + Vector2(-machine.range_x(), machine.use_range_y),
				c + Vector2(-machine.range_x(), -machine.use_range_y)])
			return
		# 기구는 **밑변 가운데가 원점**이라 거기서 위로 그림 높이만큼이 몸집이다
		var w: float = machine.width() * absf(machine.scale.x)
		var h: float = absf(machine.top_offset()) * absf(machine.scale.y)
		rect = Rect2(machine.global_position + Vector2(-w * 0.5, -h), Vector2(w, h))
	_marker.points = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y), rect.position])

func _say(text: String) -> void:
	_notice = text
	_notice_left = 4.0
	_refresh()

## 소수점이 지저분하지 않게 — 0.17은 "0.17", 880.0은 "880"으로 보인다
func _num(value: float) -> String:
	var text: String = String.num(value, 4)
	# ⚠️ **소수점이 있을 때만 깎는다** — 그냥 깎으면 1380이 138이 된다(2026-10-07 실측)
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	return text

# ---------------------------------------------------------------- 저장

func _save() -> void:
	var done: PackedStringArray = PackedStringArray()
	if _save_scene():
		done.append("Gym.tscn")
	if _save_table():
		done.append("GymPlacements.tres")
	if done.is_empty():
		_say("저장 실패 — 콘솔을 볼 것")
	else:
		_say("저장했다: %s   (에디터가 켜져 있으면 씬을 다시 열 것)" % ", ".join(done))



## 기구 크기와 2층 바닥을 `Gym.tscn` 글에 되적는다
func _save_scene() -> bool:
	var file := FileAccess.open(GYM_SCENE, FileAccess.READ)
	if file == null:
		push_error("Gym.tscn 을 못 읽었다")
		return false
	var text: String = file.get_as_text()
	file.close()
	for kind in _machines:
		var machine: GymMachine = _machines[kind]
		text = _set_props(text, machine.name, "Equipment", {
			"scale": "Vector2(%s, %s)" % [_dec(machine.scale.x), _dec(machine.scale.y)],
			"range_margin": _dec(machine.range_margin),
			"stand_offset": _dec(machine.stand_offset),
			"stand_lift": _dec(machine.stand_lift),
			"snap_on_use": "true" if machine.snap_on_use else "false",
			"use_range_y": _dec(machine.use_range_y),
			"range_offset": "Vector2(%s, %s)" % [
				_dec(machine.range_offset.x), _dec(machine.range_offset.y)],
		})
	if _slab:
		text = _set_props(text, "Slab", "Floor2F", {
			"offset_left": _dec(_slab.offset_left),
			"offset_top": _dec(_slab.offset_top),
			"offset_right": _dec(_slab.offset_right),
			"offset_bottom": _dec(_slab.offset_bottom),
		})
	var out := FileAccess.open(GYM_SCENE, FileAccess.WRITE)
	if out == null:
		push_error("Gym.tscn 에 못 썼다")
		return false
	out.store_string(text)
	out.close()
	return true

## 지금 보고 있는 배치 번호에 기구 자리를 되적는다
func _save_table() -> bool:
	var table: GymPlacement = _table()
	if table == null or table.count() == 0:
		return false
	for kind in _machines:
		var machine: GymMachine = _machines[kind]
		table.set_spot(kind, _arrangement, machine.position, machine.flip)
	return ResourceSaver.save(table) == OK

## `.tscn` 글에서 그 노드 덩어리를 찾아 속성 줄만 갈아 끼운다.
##
## ⚠️ **이름만 보면 안 된다** — `Slab`이라는 노드가 `Floor2F` 밑에도 `Ground` 밑에도 있다.
## 부모까지 맞아야 엉뚱한 쪽을 고치지 않는다
static func _set_props(text: String, node: String, parent: String, props: Dictionary) -> String:
	var lines: PackedStringArray = text.split("\n")
	var head: int = -1
	for i in lines.size():
		if not lines[i].begins_with("[node name=\"%s\"" % node):
			continue
		if not lines[i].contains("parent=\"%s\"" % parent):
			continue
		head = i
		break
	if head < 0:
		push_error("Gym.tscn 에서 %s (parent=%s) 를 못 찾았다" % [node, parent])
		return text
	# 덩어리 끝 = 다음 대괄호 줄 직전
	var tail: int = lines.size()
	for i in range(head + 1, lines.size()):
		if lines[i].begins_with("["):
			tail = i
			break
	var left: Dictionary = props.duplicate()
	var block: PackedStringArray = PackedStringArray()
	for i in range(head + 1, tail):
		var key: String = lines[i].get_slice(" = ", 0)
		if left.has(key):
			block.append("%s = %s" % [key, left[key]])
			left.erase(key)
		else:
			block.append(lines[i])
	# 아직 안 적혀 있던 속성은 **빈 줄 앞에** 끼워 넣는다(덩어리 사이 빈 줄을 지키려고)
	var blanks: int = 0
	while block.size() > 0 and block[block.size() - 1].strip_edges() == "":
		block.remove_at(block.size() - 1)
		blanks += 1
	for key in left:
		block.append("%s = %s" % [key, left[key]])
	for _i in blanks:
		block.append("")
	var out: PackedStringArray = PackedStringArray()
	for i in head + 1:
		out.append(lines[i])
	out.append_array(block)
	for i in range(tail, lines.size()):
		out.append(lines[i])
	return "\n".join(out)

## `.tscn`은 실수 속성을 `880.0`처럼 적는다 — 소수점이 빠지면 정수로 읽히는 자리가 있어서 꼭 붙인다
func _dec(value: float) -> String:
	var text: String = String.num(value, 5)
	return text if text.contains(".") else text + ".0"
