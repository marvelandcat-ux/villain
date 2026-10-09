class_name MapSelect
extends Control

## 맵 선택 — 우주에 떠 있는 대한민국 지구본(임시 그림), 지도 위 핀(`MapPin`)을 눌러 맵을 고른다.
## 땅·바다가 같이 천천히 돈다. 핀에 마우스를 올리면 멈추고, 지구본을 좌클릭으로 끌면 좌우로 돌릴 수 있다(놓으면 살짝 미끄러짐).
## 고르면 그 핀 쪽으로 돌아 → 평평한 지도로 펼쳐지고 → 핀 쪽으로 확대된 뒤 → 그 맵으로 들어간다.
## 지구본 그림은 `KoreaGlobe.gdshader`(그림 좌표 계산은 아래 `_screen_of()`와 짝), 표면 그림은 `tools/make_korea_globe.py`가 만든다.
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
const PX_PER_DEG := 66.0
const TEX_SIZE := Vector2(2048, 1024)

## 지구본 중심·반지름(px), 기울기(라디안), 저절로 도는 속도(초당 그림 가로 몇 바퀴)
const GLOBE_CENTER := Vector2(640, 345)
const GLOBE_RADIUS := 920.0
const GLOBE_TILT := -0.3
const SPIN_SPEED := 1.0 / 160.0
## 펼친 지도의 반 크기(px)와 그 가로가 보여 주는 그림 폭(u) — 한반도가 세로로 꽉 차게
const FLAT_HALF := Vector2(660, 380)
const FLAT_SPAN_U := 0.70
## 끌다 놓았을 때 미끄러지는 힘이 줄어드는 빠르기(1초에 남는 비율이 아니라 감속 계수)와 최대 속도(초당 바퀴)
const FLING_DAMP := 3.0
const FLING_MAX := 1.5
## 고른 뒤 연출 시간(초): 핀 쪽으로 돌기 / 펼치기 / 확대
const TURN_TIME := 0.5
const UNFOLD_TIME := 0.9
const ZOOM_TIME := 1.1
const ZOOM_TO := 3.5
## 검게 빨려 들어간 뒤 새 맵이 서서히 드러나는 시간(초)
const MAP_FADE_IN := 1.0
## 핀에 마우스를 올리면 뜨는 썸네일 크기(px)와 핀 머리 위로 띄우는 틈(px)
const THUMB_SIZE := Vector2(256, 144)
const THUMB_GAP := 34.0
## 핀 이름표끼리 띄울 여유(px) — 딱 붙지 않을 만큼만
const LABEL_PAD := 4.0

@onready var _globe: ColorRect = $Globe
@onready var _pins: Control = $Pins
@onready var _random_button: Button = $RandomButton
@onready var _status_label: Label = $StatusLabel
@onready var _p1_standee: Node2D = $P1Standee
@onready var _p2_standee: Node2D = $P2Standee

var _pin_nodes: Dictionary = {}  # {map_name: MapPin}
var _thumbs: Dictionary = {}     # {map_name: 썸네일 카드} — 맵 씬을 훑는 게 무거워서 처음에 한 번씩만 만든다
var _spin: float = 0.0           # 그림을 가로로 민 양(u) — 0이면 한반도가 정면
## 좌클릭으로 끄는 중인지 / 놓은 뒤 남은 미끄러지는 속도(초당 u)
var _dragging: bool = false
var _fling: float = 0.0
var _flatten: float = 1.0   # 평면 지도 모드(2026-10-08) — 처음부터 펼쳐진 채로 시작
var _zoom: float = 1.0
var _zoom_uv: Vector2 = Vector2(0.5, 0.5)
## 고르는 연출 중(핀·버튼 잠금, 자동 회전 멈춤)
var _busy: bool = false
var _picked: String = ""
## 평면 지도(2026-10-08): 바다 질감만 흐르는 밀림(그림 좌표 u·v)과 그 속도(초당). 땅은 고정
const OCEAN_FLOW := Vector2(0.012, 0.005)
var _ocean_scroll: Vector2 = Vector2.ZERO
## 빨려 들어갈 때 화면을 덮어 가는 검은 막(코드로 만든다)
var _dark: ColorRect = null

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
	# 빨려 들어갈 때 화면을 덮어 가는 검은 막 — 맨 위에, 마우스는 안 막는다
	_dark = ColorRect.new()
	_dark.name = "Dark"
	_dark.color = Color(0, 0, 0, 0)
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dark)
	_apply_globe()

func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)
	# 평면 지도: 땅은 고정, 바다 질감만 천천히 비스듬히 흐른다
	_ocean_scroll += OCEAN_FLOW * dt
	_ocean_scroll = Vector2(fposmod(_ocean_scroll.x, 1.0), fposmod(_ocean_scroll.y, 1.0))
	_apply_globe()

## 평면 지도 모드에선 끌기 없음(땅이 고정이라 끌 것이 없다). 함수는 남겨 둠 — 지구본으로 되돌릴 때를 위해
func _gui_input(_event: InputEvent) -> void:
	return

## (지구본 모드에서 쓰던 끌기 — 지금은 안 불린다)
func _gui_input_globe(event: InputEvent) -> void:
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
		mat.set_shader_parameter("ocean_scroll", _ocean_scroll)
	for map_name in _pin_nodes:
		var pin = _pin_nodes[map_name]
		var spot: Dictionary = _screen_of(_pin_uv(map_name) - Vector2(_spin, 0.0))
		pin.visible = spot.visible and (_picked == "" or map_name == _picked)
		if pin.visible:
			pin.place_tip(spot.pos)
	_layout_labels()
	_update_thumbs()

## 핀 이름표는 **항상 핀 아래**에 단다(2026-10-08 사용자: 자리를 찾아 이리저리 움직이는 게 거슬림).
## 겹침은 지구본을 키워서(`GLOBE_RADIUS`) 핀 사이를 벌리는 것으로 푼다
func _layout_labels() -> void:
	for pin in _pin_nodes.values():
		if pin.label_side != PIN_SCRIPT.LabelSide.BELOW:
			pin.set_label_side(PIN_SCRIPT.LabelSide.BELOW)

func _overlap_area(rect: Rect2, others: Array[Rect2]) -> float:
	var total: float = 0.0
	for o in others:
		total += rect.intersection(o).get_area()
	return total

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
	vbox.add_child(_make_thumb_art(map_name))
	var label := Label.new()
	label.text = map_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(label)
	return card

## 썸네일 그림 — `tools/MapThumbGen.tscn`이 실제 게임 화면을 찍어 둔 `ui/map_thumbs/<맵 파일 이름>.png`.
## 찍어 둔 게 없는 맵(새 맵)만 예전처럼 MapPreview 스케치로 그린다(스케치는 맵마다 깨져 보여서 2026-10-09 사진으로 바꿈)
func _make_thumb_art(map_name: String) -> Control:
	var map_path: String = GameState.MAPS[map_name]
	var shot: Texture2D = MapPreview.snapshot_texture(map_path)
	if shot:
		var art := TextureRect.new()
		art.texture = shot
		art.custom_minimum_size = THUMB_SIZE
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return art
	var preview := MapPreview.new()
	preview.custom_minimum_size = THUMB_SIZE
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.set_map(map_path)
	return preview

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

## 돌리기 전 그림 좌표 uv(= 핀 uv - spin)가 화면 어디에 보이는지 {pos, visible}
## ⚠️ KoreaGlobe.gdshader의 surface_uv()를 거꾸로 한 계산 — 한쪽을 고치면 같이 고칠 것
func _screen_of(uv: Vector2) -> Dictionary:
	var target := Vector2(0.5 + wrapf(uv.x - 0.5, -0.5, 0.5), uv.y)
	# 확대는 그림 좌표를 zoom_uv 쪽으로 당긴 것이라 거꾸로 편다
	var s: Vector2 = _zoom_uv + (target - _zoom_uv) * _zoom
	# 공의 휘는 정도(1 = 지구본, 0 = 평평)와 가운데 배율(1라디안이 몇 px)
	var c: float = 1.0 - _flatten
	var k: float = lerpf(GLOBE_RADIUS, FLAT_HALF.x / (PI * FLAT_SPAN_U), _flatten)
	var q: Vector2
	var on_front: bool = true
	if c < 0.001:
		q = Vector2((s.x - 0.5) * TAU * k, (s.y - 0.5) * PI * k)
	else:
		var lon: float = (s.x - 0.5) * TAU * c
		var lat: float = (0.5 - s.y) * PI * c
		q = Vector2(cos(lat) * sin(lon), -sin(lat)) * k / c
		on_front = cos(lat) * cos(lon) > 0.15
	return {"pos": GLOBE_CENTER + q.rotated(GLOBE_TILT * c), "visible": on_front}

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
	# 평면 지도(2026-10-08 사용자 설계): 핀 자리로 **점점 빠르게 확대되며 빨려 들어가고**, 동시에 화면이 점점 어두워진다.
	# 완전히 검어지면 씬을 바꾸고, 새 맵이 자리잡으면 검은 막이 서서히 걷힌다(SceneTransition.go_to_scene_from_black) — 로딩 화면 대신
	_zoom_uv = _pin_uv(map_name)
	var tween := create_tween().set_parallel(true)
	tween.tween_method(_set_zoom, 1.0, ZOOM_TO, ZOOM_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_dark, "color:a", 1.0, ZOOM_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 글자·핀·캐릭터는 먼저 사라진다 — 빨려 들어가는 건 지도만
	for node in [_status_label, _pins, _p1_standee, _p2_standee, _random_button]:
		tween.tween_property(node, "modulate:a", 0.0, ZOOM_TIME * 0.4)
	await tween.finished
	GameState.selected_map_path = GameState.MAPS[map_name]
	SceneTransition.go_to_scene_from_black(GameState.selected_map_path, MAP_FADE_IN)

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
	# 평면 지도라 돌릴 게 없다 — 핀을 잠깐 비춘 뒤 바로 빨려 들어간다
	_pin_nodes[pick].grab_focus()
	await get_tree().create_timer(0.45).timeout
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
		get_viewport().set_input_as_handled()
		_on_back_pressed()
