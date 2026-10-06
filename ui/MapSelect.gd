class_name MapSelect
extends Control

## 맵 선택 — 우주에 떠 있는 대한민국 지구본(임시 그림), 지도 위 핀(`MapPin`)을 눌러 맵을 고른다.
## 땅·바다가 같이 천천히 돈다. 핀에 마우스를 올리면 멈추고, 지구본을 좌클릭으로 끌면 좌우로 돌릴 수 있다(놓으면 살짝 미끄러짐).
## 고르면 그 핀 쪽으로 돌아 → 평평한 지도로 펼쳐지고 → 핀 쪽으로 확대된 뒤 → 그 맵으로 들어간다.
## 지구본 그림은 `KoreaGlobe.gdshader`(그림 좌표 계산은 아래 `_uv_at()`과 짝), 표면 그림은 `tools/make_korea_globe.py`가 만든다.
## 배경 양옆에는 CharacterSelect에서 확정한 P1/P2 캐릭터가 인게임 몸(BodyRig)으로 서 있다

## 서 있는 캐릭터 배율 — 1.0이면 실제 대전 화면에서 보이는 것과 똑같은 크기(인게임 크기)로 서 있다
const STANDEE_SCALE := 1.0
const PIN_SCRIPT := preload("res://ui/MapPin.gd")

## 맵마다 지도 위 자리(경도, 위도) — **임시**(사용자가 나중에 정함). 여기 없는 맵은 DEFAULT_PIN에 선다.
## 실제 도시 자리는 해안에 붙어 핀이 바다로 삐져나와서, **땅 안쪽**으로 들이고 이름이 안 겹치게 위아래로 엇갈려 뒀다
const MAP_PINS := {
	"지하철역": Vector2(127.0, 37.45),      # 서울 쪽
	"놀이터": Vector2(128.45, 36.9),        # 경북 북부 쪽
	"악플러의 집": Vector2(127.3, 36.3),    # 대전 쪽
	"헬스장": Vector2(127.0, 35.3),         # 광주 쪽
	"번화가": Vector2(128.5, 35.55),        # 대구~부산 쪽
}
const DEFAULT_PIN := Vector2(127.8, 36.8)

## 표면 그림의 경위도 배치 — ⚠️ tools/make_korea_globe.py의 같은 이름 값과 똑같아야 한다
const CENTER_LON := 127.5
const CENTER_LAT := 38.0
const PX_PER_DEG := 60.0
const TEX_SIZE := Vector2(2048, 1024)

## 지구본 중심·반지름(px), 기울기(라디안), 저절로 도는 속도(초당 그림 가로 몇 바퀴)
const GLOBE_CENTER := Vector2(640, 320)
const GLOBE_RADIUS := 220.0
const GLOBE_TILT := -0.3
const SPIN_SPEED := 1.0 / 24.0
## 펼친 지도의 반 크기(px)와 그 가로가 보여 주는 그림 폭(u) — 한반도가 세로로 꽉 차게
const FLAT_HALF := Vector2(540, 260)
const FLAT_SPAN_U := 0.62
## 끌다 놓았을 때 미끄러지는 힘이 줄어드는 빠르기(1초에 남는 비율이 아니라 감속 계수)와 최대 속도(초당 바퀴)
const FLING_DAMP := 3.0
const FLING_MAX := 1.5
## 고른 뒤 연출 시간(초): 핀 쪽으로 돌기 / 펼치기 / 확대
const TURN_TIME := 0.5
const UNFOLD_TIME := 0.9
const ZOOM_TIME := 0.7
const ZOOM_TO := 4.0
## 핀에 마우스를 올리면 뜨는 썸네일 크기(px)와 핀 머리 위로 띄우는 틈(px)
const THUMB_SIZE := Vector2(256, 144)
const THUMB_GAP := 34.0

@onready var _globe: ColorRect = $Globe
@onready var _pins: Control = $Pins
@onready var _random_button: Button = $RandomButton
@onready var _p1_standee: Node2D = $P1Standee
@onready var _p2_standee: Node2D = $P2Standee

var _pin_nodes: Dictionary = {}  # {map_name: MapPin}
var _thumbs: Dictionary = {}     # {map_name: 썸네일 카드} — 맵 씬을 훑는 게 무거워서 처음에 한 번씩만 만든다
var _spin: float = 0.0           # 그림을 가로로 민 양(u) — 0이면 한반도가 정면
## 좌클릭으로 끄는 중인지 / 놓은 뒤 남은 미끄러지는 속도(초당 u)
var _dragging: bool = false
var _fling: float = 0.0
var _flatten: float = 0.0
var _zoom: float = 1.0
var _zoom_uv: Vector2 = Vector2(0.5, 0.5)
## 고르는 연출 중(핀·버튼 잠금, 자동 회전 멈춤)
var _busy: bool = false
var _picked: String = ""

func _ready() -> void:
	for map_name in GameState.MAPS.keys():
		var pin = PIN_SCRIPT.new()
		pin.map_name = map_name
		pin.pressed.connect(_on_map_picked.bind(map_name))
		_pins.add_child(pin)
		_pin_nodes[map_name] = pin
		var thumb := _make_thumb(map_name)
		add_child(thumb)
		_thumbs[map_name] = thumb
	_random_button.pressed.connect(_on_random_pressed)

	# P1(왼쪽)은 오른쪽(가운데)을, P2(오른쪽)은 왼쪽(가운데)을 보게 마주 세운다
	_spawn_standee(_p1_standee, GameState.p1_character_path, 1.0)
	_spawn_standee(_p2_standee, GameState.p2_character_path, -1.0)
	_apply_globe()

func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)
	if not _busy and not _dragging:
		# 놓은 뒤 미끄러짐은 점점 줄고, 핀에 마우스를 올리고 있으면 저절로 도는 것만 멈춘다
		_fling = move_toward(_fling, 0.0, absf(_fling) * FLING_DAMP * dt + 0.01 * dt)
		var auto: float = 0.0 if _any_pin_hovered() else SPIN_SPEED
		_spin = fposmod(_spin + (auto + _fling) * dt, 1.0)
	_apply_globe()

## 지구본 위를 좌클릭으로 끌면 끈 만큼 돈다(핀은 버튼이라 핀 위 클릭은 여기로 안 온다)
func _gui_input(event: InputEvent) -> void:
	if _busy:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and (event.position - GLOBE_CENTER).length() <= GLOBE_RADIUS:
			_dragging = true
			_fling = 0.0
			accept_event()
		elif not event.pressed and _dragging:
			_dragging = false
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		# 오른쪽으로 끌면 표면도 오른쪽으로 — 화면 1px = 적도 둘레(2πR)의 1/길이만큼
		var du: float = -event.relative.x / (TAU * GLOBE_RADIUS)
		_spin = fposmod(_spin + du, 1.0)
		var dt: float = maxf(get_process_delta_time(), 0.001)
		_fling = clampf(lerpf(_fling, du / dt, 0.5), -FLING_MAX, FLING_MAX)
		accept_event()

func _any_pin_hovered() -> bool:
	for pin in _pin_nodes.values():
		if pin.visible and pin.is_hovered():
			return true
	return false

## container 자리에 그 캐릭터의 인게임 몸(BodyRig)을 세운다. Fighter가 없으니 걷지 않고
## 가만히 서서 숨쉬는 동작만 돈다 — CharacterSelect의 미리보기 상자와 같은 원리
func _spawn_standee(container: Node2D, character_path: String, facing: float) -> void:
	var character_name: String = GameState.character_name_for_path(character_path)
	if not GameState.has_character_rig(character_name):
		return
	var rig: Node2D = GameState.character_rig_scene(character_name).instantiate()
	container.add_child(rig)
	rig.scale = Vector2(STANDEE_SCALE * facing, STANDEE_SCALE)

## 셰이더 값을 넣고 핀을 지도 위 자리로 옮긴다
func _apply_globe() -> void:
	var mat := _globe.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("rect_size", _globe.size)
		mat.set_shader_parameter("center", GLOBE_CENTER)
		mat.set_shader_parameter("radius", GLOBE_RADIUS)
		mat.set_shader_parameter("tilt", GLOBE_TILT)
		mat.set_shader_parameter("spin", _spin)
		mat.set_shader_parameter("flatten", _flatten)
		mat.set_shader_parameter("flat_half", FLAT_HALF)
		mat.set_shader_parameter("flat_span_u", FLAT_SPAN_U)
		mat.set_shader_parameter("zoom", _zoom)
		mat.set_shader_parameter("zoom_uv", _zoom_uv)
	for map_name in _pin_nodes:
		var pin = _pin_nodes[map_name]
		var spot: Dictionary = _screen_of(_pin_uv(map_name) - Vector2(_spin, 0.0))
		pin.visible = spot.visible and (_picked == "" or map_name == _picked)
		if pin.visible:
			pin.place_tip(spot.pos)
	_update_thumbs()

## 맵 썸네일 카드 — 실제 맵 모양을 축소한 MapPreview + 이름. 마우스를 막지 않는다(밑의 핀을 계속 누를 수 있게)
func _make_thumb(map_name: String) -> Control:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.07, 0.18, 0.95)
	style.set_border_width_all(3)
	style.border_color = Color(1, 1, 1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)
	var preview := MapPreview.new()
	preview.custom_minimum_size = THUMB_SIZE
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.set_map(GameState.MAPS[map_name])
	vbox.add_child(preview)
	var label := Label.new()
	label.text = map_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(label)
	return card

## 마우스를 올린(또는 키보드로 고른) 핀 위에만 그 맵 썸네일을 띄운다. 고른 뒤 펼치는 동안엔 숨긴다
func _update_thumbs() -> void:
	for map_name in _thumbs:
		var card: Control = _thumbs[map_name]
		var pin = _pin_nodes[map_name]
		card.visible = _picked == "" and pin.visible and pin.is_highlighted()
		if not card.visible:
			continue
		var head := Vector2(pin.position.x + pin.size.x * 0.5, pin.position.y)
		var at := Vector2(head.x - card.size.x * 0.5, head.y - THUMB_GAP - card.size.y)
		# 위로 넘치면 핀 아래로
		if at.y < 4.0:
			at.y = pin.position.y + pin.size.y + 8.0
		at.x = clampf(at.x, 4.0, size.x - card.size.x - 4.0)
		card.position = at

# ---------------------------------------------------------------- 지도 좌표

## 맵 핀의 그림 좌표(u, v)
func _pin_uv(map_name: String) -> Vector2:
	var lon_lat: Vector2 = MAP_PINS.get(map_name, DEFAULT_PIN)
	return Vector2(
		0.5 + (lon_lat.x - CENTER_LON) * PX_PER_DEG / TEX_SIZE.x,
		0.5 - (lon_lat.y - CENTER_LAT) * PX_PER_DEG / TEX_SIZE.y)

## 지구본 중심 기준 화면 점 p(px)가 보여 주는 그림 좌표 — ⚠️ KoreaGlobe.gdshader와 똑같은 계산
func _uv_at(p: Vector2) -> Vector2:
	var q: Vector2 = p.rotated(-GLOBE_TILT * (1.0 - _flatten)) / GLOBE_RADIUS
	var z: float = sqrt(maxf(1.0 - q.length_squared(), 0.0))
	var lat: float = asin(clampf(-q.y, -1.0, 1.0))
	var lon: float = atan2(q.x, z)
	var sphere := Vector2(0.5 + lon / TAU, 0.5 - lat / PI)
	var du: float = FLAT_SPAN_U / (2.0 * FLAT_HALF.x)
	var flat := Vector2(0.5 + p.x * du, 0.5 + p.y * du * 2.0)
	flat = _zoom_uv + (flat - _zoom_uv) / _zoom
	return sphere.lerp(flat, _flatten)

## 돌리기 전 그림 좌표 uv(= 핀 uv - spin)가 화면 어디에 보이는지 {pos, visible}. 둥글 땐 바로 계산하고, 펼치는 중이면 거기서 뉴턴법으로 맞춘다
func _screen_of(uv: Vector2) -> Dictionary:
	var target := Vector2(0.5 + wrapf(uv.x - 0.5, -0.5, 0.5), uv.y)
	var lon: float = (target.x - 0.5) * TAU
	var lat: float = (0.5 - target.y) * PI
	var z: float = cos(lat) * cos(lon)
	var q := Vector2(cos(lat) * sin(lon), -sin(lat)) * GLOBE_RADIUS
	var p: Vector2 = q.rotated(GLOBE_TILT * (1.0 - _flatten))
	if _flatten > 0.0 or not is_equal_approx(_zoom, 1.0):
		for i in 8:
			var err: Vector2 = _uv_at(p) - target
			if err.length() < 0.00001:
				break
			var h: float = 0.5
			var jx: Vector2 = (_uv_at(p + Vector2(h, 0)) - _uv_at(p)) / h
			var jy: Vector2 = (_uv_at(p + Vector2(0, h)) - _uv_at(p)) / h
			var det: float = jx.x * jy.y - jy.x * jx.y
			if absf(det) < 1e-12:
				break
			p -= Vector2(jy.y * err.x - jy.x * err.y, -jx.y * err.x + jx.x * err.y) / det
	var on_front: bool = z > 0.15 or _flatten > 0.5
	return {"pos": GLOBE_CENTER + p, "visible": on_front}

# ---------------------------------------------------------------- 고르기

## 핀을 누름 → 그 핀 쪽으로 돌기 → 펼치기 → 핀 쪽으로 확대 → 맵으로
func _on_map_picked(map_name: String) -> void:
	if _picked != "":
		return
	_busy = true
	_dragging = false
	_fling = 0.0
	_picked = map_name
	_set_buttons_disabled(true)
	var pin_uv: Vector2 = _pin_uv(map_name)
	# 핀의 u가 정면(0.5)에 오는 spin 중 지금과 가장 가까운 값
	var goal: float = _spin + wrapf(pin_uv.x - 0.5 - _spin, -0.5, 0.5)
	# 돌고 나면 핀은 화면 기준 그림 좌표 (0.5, v)에 있다 — 거기를 향해 확대
	var uv := Vector2(0.5, pin_uv.y)
	var tween := create_tween()
	tween.tween_method(_set_spin, _spin, goal, TURN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_flatten, 0.0, 1.0, UNFOLD_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func(): _zoom_uv = uv)
	tween.tween_method(_set_zoom, 1.0, ZOOM_TO, ZOOM_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	GameState.selected_map_path = GameState.MAPS[map_name]
	SceneTransition.go_to_scene(GameState.selected_map_path)

## 랜덤 — 지구본이 빠르게 두어 바퀴 돌다 점점 느려지며 고른 핀이 정면에 온 채로 멈추고, 그 맵으로 들어간다
func _on_random_pressed() -> void:
	if _busy:
		return
	_busy = true
	_dragging = false
	_fling = 0.0
	_set_buttons_disabled(true)
	var keys: Array = GameState.MAPS.keys()
	var pick: String = keys[randi() % keys.size()]
	var goal: float = _spin + 2.0 + fposmod(_pin_uv(pick).x - 0.5 - _spin, 1.0)
	var tween := create_tween()
	tween.tween_method(_set_spin, _spin, goal, 2.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	_spin = fposmod(_spin, 1.0)
	_pin_nodes[pick].grab_focus()
	_on_map_picked(pick)

func _set_spin(value: float) -> void:
	_spin = value

func _set_flatten(value: float) -> void:
	_flatten = value

func _set_zoom(value: float) -> void:
	_zoom = value

func _set_buttons_disabled(disabled: bool) -> void:
	for pin in _pin_nodes.values():
		pin.disabled = disabled
	_random_button.disabled = disabled

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/CharacterSelect.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _busy:
		_on_back_pressed()
