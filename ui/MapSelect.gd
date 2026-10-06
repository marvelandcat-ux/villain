class_name MapSelect
extends Control

## 맵 선택 — 우주에 떠 있는 대한민국 지구본(임시 그림), 지도 위 핀(`MapPin`)을 눌러 맵을 고른다.
## **바다만 돈다**(2026-10-06 사용자 요청) — 한반도와 핀은 늘 정면에 고정, 바다·구름 그림만 밀려 지나간다.
## 고르면 평평한 지도로 펼쳐지고 → 핀 쪽으로 확대된 뒤 → 그 맵으로 들어간다.
## 지구본 그림은 `KoreaGlobe.gdshader`(그림 좌표 계산은 아래 `_uv_at()`과 짝), 표면 그림은 `tools/make_korea_globe.py`가 만든다.
## 배경 양옆에는 CharacterSelect에서 확정한 P1/P2 캐릭터가 인게임 몸(BodyRig)으로 서 있다

## 서 있는 캐릭터 배율 — 1.0이면 실제 대전 화면에서 보이는 것과 똑같은 크기(인게임 크기)로 서 있다
const STANDEE_SCALE := 1.0
const PIN_SCRIPT := preload("res://ui/MapPin.gd")

## 맵마다 지도 위 자리(경도, 위도) — **임시**(사용자가 나중에 정함). 여기 없는 맵은 DEFAULT_PIN에 선다
const MAP_PINS := {
	"지하철역": Vector2(126.98, 37.57),     # 서울
	"놀이터": Vector2(128.90, 37.75),       # 강릉
	"악플러의 집": Vector2(127.38, 36.35),  # 대전
	"헬스장": Vector2(126.85, 35.16),       # 광주
	"번화가": Vector2(129.08, 35.18),       # 부산
}
const DEFAULT_PIN := Vector2(127.8, 36.8)

## 표면 그림의 경위도 배치 — ⚠️ tools/make_korea_globe.py의 같은 이름 값과 똑같아야 한다
const CENTER_LON := 127.5
const CENTER_LAT := 38.0
const PX_PER_DEG := 60.0
const TEX_SIZE := Vector2(2048, 1024)

## 지구본 중심·반지름(px), 기울기(라디안), 바다가 도는 속도(초당 그림 가로 몇 바퀴)
const GLOBE_CENTER := Vector2(640, 320)
const GLOBE_RADIUS := 220.0
const GLOBE_TILT := -0.3
const SPIN_SPEED := 1.0 / 24.0
## 펼친 지도의 반 크기(px)와 그 가로가 보여 주는 그림 폭(u) — 한반도가 세로로 꽉 차게
const FLAT_HALF := Vector2(540, 260)
const FLAT_SPAN_U := 0.62
## 고른 뒤 연출 시간(초): 펼치기 / 확대
const UNFOLD_TIME := 0.9
const ZOOM_TIME := 0.7
const ZOOM_TO := 4.0

@onready var _globe: ColorRect = $Globe
@onready var _pins: Control = $Pins
@onready var _random_button: Button = $RandomButton
@onready var _p1_standee: Node2D = $P1Standee
@onready var _p2_standee: Node2D = $P2Standee

var _pin_nodes: Dictionary = {}  # {map_name: MapPin}
var _spin: float = 0.0           # 바다 그림을 가로로 민 양(u) — 땅은 안 움직인다
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
	_random_button.pressed.connect(_on_random_pressed)

	# P1(왼쪽)은 오른쪽(가운데)을, P2(오른쪽)은 왼쪽(가운데)을 보게 마주 세운다
	_spawn_standee(_p1_standee, GameState.p1_character_path, 1.0)
	_spawn_standee(_p2_standee, GameState.p2_character_path, -1.0)
	_apply_globe()

func _process(delta: float) -> void:
	if not _busy:
		_spin = fposmod(_spin + SPIN_SPEED * minf(delta, 0.05), 1.0)
	_apply_globe()

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
		var spot: Dictionary = _screen_of(_pin_uv(map_name))
		pin.visible = spot.visible and (_picked == "" or map_name == _picked)
		if pin.visible:
			pin.place_tip(spot.pos)

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

## 땅 그림 좌표 uv가 화면 어디에 보이는지 {pos, visible}. 둥글 땐 바로 계산하고, 펼치는 중이면 거기서 뉴턴법으로 맞춘다
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

## 핀을 누름 → 펼치기 → 핀 쪽으로 확대 → 맵으로
func _on_map_picked(map_name: String) -> void:
	if _picked != "":
		return
	_busy = true
	_picked = map_name
	_set_buttons_disabled(true)
	var uv: Vector2 = _pin_uv(map_name)
	var tween := create_tween()
	tween.tween_method(_set_flatten, 0.0, 1.0, UNFOLD_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func(): _zoom_uv = uv)
	tween.tween_method(_set_zoom, 1.0, ZOOM_TO, ZOOM_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	GameState.selected_map_path = GameState.MAPS[map_name]
	SceneTransition.go_to_scene(GameState.selected_map_path)

## 랜덤 — 바다가 빠르게 돌다 느려지는 동안 핀을 차례로 강조(포커스)하다가 멈춘 핀으로 들어간다.
## 대기는 자식 Timer라 연출 중 뒤로 나가 씬이 정리되면 조용히 끝난다
func _on_random_pressed() -> void:
	if _busy:
		return
	_busy = true
	_set_buttons_disabled(true)
	var keys: Array = GameState.MAPS.keys()
	var start: int = randi() % keys.size()
	var steps: int = keys.size() * 3
	var pick: String = keys[start]
	var tween := create_tween()
	tween.tween_method(_set_spin, _spin, _spin + 1.5, 2.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i in steps:
		pick = keys[(start + i) % keys.size()]
		_pin_nodes[pick].grab_focus()
		await _wait(lerpf(0.0133, 0.22, float(i) / float(steps - 1)))
	_spin = fposmod(_spin, 1.0)
	_on_map_picked(pick)

func _wait(duration: float) -> void:
	var timer := Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	add_child(timer)
	timer.start()
	await timer.timeout
	timer.queue_free()

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
