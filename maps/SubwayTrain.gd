class_name SubwayTrain
extends Node2D

## 선로를 일정 주기로 가로지르는 열차 (지하철 승강장 맵의 핵심 기믹).
## 플레이어는 선로 바닥에서 싸우기 때문에 열차가 오면 반드시 피해야 한다 —
## 부딪히면 데미지를 입고 열차가 가는 쪽으로 계속 밀리며(hit_interval마다 반복 타격),
## 지붕 위에 올라타도 판정이 열차 전체를 덮고 있어서 그냥 튕겨 나간다.
## 피하는 방법은 넉백으로 거리가 벌어졌을 때 이단 점프로 의자 발판 위에 올라가는 것.
##
## 시간 조절은 전부 인스펙터(@export)에서 한다:
##  - interval: 열차가 도착해서 다음 열차가 도착할 때까지의 주기(초). 통과에 걸리는 시간까지 포함한 값이라
##    30이면 정확히 30초마다 한 대씩 온다
##  - first_delay: 라운드 시작 후 첫 열차가 도착할 때까지(초)
##  - warning_duration: 열차가 도착하기 몇 초 전부터 도착 음악과 경고등이 나오는지
@export var interval: float = 30.0
## 라운드 시작 후 첫 열차 도착까지(초). warning_duration보다 커야 음악이 잘린 채 시작하지 않는다
@export var first_delay: float = 12.0
## 도착 몇 초 전부터 음악·경고등이 나오는지
@export var warning_duration: float = 5.0
## 열차 속도(px/초)
@export var speed: float = 950.0
## 한 번 부딪힐 때 데미지 (hit_interval마다 반복해서 들어간다)
@export var damage: int = 12
## 부딪혀 있는 동안 다시 맞기까지의 간격(초)
@export var hit_interval: float = 0.35
## 넉백 — 열차가 가는 쪽으로 미는 힘
@export var knockback_push: float = 420.0
## 넉백 — 위로 튕겨 올리는 힘 (지붕에 올라탔을 때 그냥 떨어져 나가게 하는 몫)
@export var knockback_lift: float = 260.0
## 출발/도착 지점의 x 거리. 열차 그림 반폭(441) + 화면 반폭(640)보다 넉넉해야 화면 안에서 툭 나타나지 않는다
@export var travel_x: float = 1200.0
## true면 열차가 올 때마다 진행 방향이 좌↔우로 번갈아 바뀐다
@export var alternate_direction: bool = true
## 경고등이 1초에 깜빡이는 횟수
@export var warning_blink_speed: float = 4.0
## 열차 도착 음악(옛날 지하철 도착 음악). 비워두면 소리 없이 경고등만 깜빡인다
@export var arrival_music: AudioStream

## --- 객실 창문 불빛 ---
## 창문 불빛·벽에 비치는 빛기둥을 켤지 — **2026-09-26 사용자 요청("어색하다")으로 꺼 뒀다.** 켜면 아래 값대로 다시 나온다
@export var window_lights: bool = false
## 창문 빛의 세기 (0이면 안 켜진다). 그림에 이미 세게 구워져 있으니 여기서 줄여 쓰면 된다
@export var window_glow: float = 1.0
## 형광등이 미세하게 떨리는 폭 (0이면 일정하게 켜져 있다)
@export var window_flicker: float = 0.09
## 떨리는 빠르기
@export var window_flicker_speed: float = 16.0

## --- 창문에서 쏟아지는 빛 (맵에 비치는 네모난 빛무리) ---
## 창문 위로 뻗는 빛기둥의 길이(px). 벽에 창문 모양대로 빛이 훑고 지나간다
@export var beam_up_length: float = 230.0
## 창문 아래로 뻗는 빛의 길이(px). **기본값 0 — 이 맵에서는 열차가 선로 바닥에 딱 붙어 있어서
## 아래로 가는 빛이 차체에 통째로 가려 안 보인다.** 열차가 공중에 뜬 맵을 만들면 그때 켜면 된다
@export var beam_down_length: float = 0.0
## 빛기둥이 멀어지면서 좌우로 벌어지는 정도 (길이 대비 비율, 한쪽 기준).
## **크게 주면 안 된다** — 0.5로 했더니 옆 창문 빛과 X자로 겹쳐서 창문 모양이 뭉개지고 하얗게 떴다
@export var beam_spread: float = 0.1
## 창문 바로 앞에서의 빛 세기. 멀어질수록 0으로 사라진다
@export var beam_alpha: float = 0.68
## 빛기둥 길이가 창문마다 얼마나 들쭉날쭉한지 (0이면 전부 같은 길이, 0.35면 기준 길이의 65~135%).
## **열차가 지나갈 때마다 다시 뽑으므로 매번 다른 모양이 된다**
@export var beam_length_variance: float = 0.35
## 빛기둥이 열차 바깥쪽으로 기우는 정도 (길이 대비 비율).
## 열차 한가운데 창문은 곧게 서고, 앞뒤 끝으로 갈수록 바깥으로 눕는다 —
## 빛이 열차에서 퍼져나가는 것처럼 보이게 하는 값. 0이면 전부 곧게 선다
@export var beam_tilt: float = 0.35
## 빛기둥 색 — 맵의 CanvasModulate(0.55, 0.58, 0.7)가 더하기 빛에도 곱해져서
## 통과하고 나면 (0.55, 0.45, 0.25) 호박색이 더해진다. 맵 조명을 바꾸면 "원하는 최종색 / 맵 조명"으로 다시 잡을 것
## (2026-09-11~26엔 맵을 밝혀 두느라 (0.625, 0.496, 0.263)으로 나눠 뒀다가, 맵을 다시 어둡게 하며 원래 값으로 되돌렸다)
@export var beam_color: Color = Color(1.0, 0.769, 0.361)

## --- 화면 진동 (2026-09-12) ---
## 경고등이 켜져 있는 동안 바닥이 낮게 울리는 세기(0~1). 화면 최대 흔들림 12px에 곱해진다
@export var warning_shake: float = 0.12
## 열차가 실제로 지나가는 동안 흔들리는 세기(0~1)
@export var pass_shake: float = 0.5
## 열차가 화면 한가운데(스테이지 중앙)에 가까울수록 더 흔들리는 정도 (0이면 지나가는 내내 같은 세기)
@export var pass_shake_focus: float = 0.6

## 진행 중인 상태
enum State { WAITING, WARNING, RUNNING }

@onready var body: Node2D = $Body
@onready var hitbox: Hitbox = $Body/Hitbox
@onready var _warning_light: Node2D = $WarningLight
@onready var _music: AudioStreamPlayer = $Music
## 창문만 밝게 구워둔 그림을 가산 블렌드로 열차 위에 얹은 스프라이트 (Body의 자식이라 열차와 같이 움직이고 같이 숨는다)
@onready var _window_light: Sprite2D = $Body/WindowGlow
## 창문에서 뻗어나가는 빛기둥들을 담는 노드. _ready에서 WINDOW_RECTS를 보고 코드로 만들어 넣는다
var _window_beams: Node2D
## 만들어둔 빛기둥들 — 길이를 다시 뽑을 때 각자 어느 창문/어느 방향이었는지 알아야 해서 같이 들고 있는다
var _beams: Array[Dictionary] = []

var _state: int = State.WAITING
## 다음 열차가 도착하기까지 남은 시간. 열차가 출발하는 순간 interval로 다시 채워지므로
## "도착에서 다음 도착까지"가 정확히 interval초가 된다 (지나가는 시간도 이 안에 포함)
var _timer: float = 0.0
## 1이면 왼쪽 → 오른쪽, -1이면 오른쪽 → 왼쪽
var _direction: int = 1
## 창문 불빛이 떨리는 위상 — 계속 커지며 sin()으로 미세한 흔들림을 만든다
var _glow_phase: float = 0.0

## 열차 그림(Metro!.png)에서 뽑아낸 창문 13개의 자리 — Body 로컬 좌표(=월드 px)로 미리 계산해뒀다.
## 그림을 다시 그리면 이 표도 다시 뽑아야 한다 (region_rect 안에서 무채색 중간 밝기 덩어리를 골라 재는 방식)
## 열차 그림의 화면상 반폭(px) — 창문이 앞/뒤 어느 쪽 끝에 가까운지 재는 기준 (2101 x 0.42 / 2)
const TRAIN_HALF_WIDTH: float = 441.2

const WINDOW_RECTS: Array[Rect2] = [
	Rect2(-426.5, -32.8, 64.3, 40.3),   # 운전실 앞유리
	Rect2(-332.0, -29.0, 60.5, 25.6),
	Rect2(-234.6, -31.9, 12.6, 30.7),   # 출입문 창
	Rect2(-201.0, -31.5, 13.0, 30.7),
	Rect2(-142.2, -31.1, 68.0, 29.0),
	Rect2(-33.0, -29.8, 13.0, 30.7),
	Rect2(-0.2, -29.4, 12.6, 30.7),
	Rect2(52.3, -28.1, 65.9, 29.0),
	Rect2(158.1, -28.1, 12.6, 31.1),
	Rect2(190.9, -27.3, 12.2, 30.7),
	Rect2(242.1, -26.0, 65.9, 29.0),
	Rect2(345.4, -26.5, 36.1, 30.2),
	Rect2(391.2, -35.7, 32.3, 39.9),
]

func _ready() -> void:
	# AIController가 "ai_danger_zone" 그룹으로 찾아서 is_dangerous()를 물어보고 피신 여부를 판단한다
	add_to_group("ai_danger_zone")
	# 신문지 날림(WindNewspaper) 같은 장식 연출이 "subway_train" 그룹으로 찾아서 바람 위치를 묻는다
	add_to_group("subway_train")
	_timer = first_delay
	hitbox.damage = damage
	hitbox.repeat_interval = hit_interval
	_music.stream = arrival_music
	_set_hitbox_active(false)
	if window_lights:
		_build_window_beams()
	_park_body()
	_warning_light.visible = false
	if _window_light:
		_window_light.visible = window_lights
		_window_light.modulate.a = window_glow

## 경고등이 켜졌거나(곧 도착) 실제로 지나가는 중이면 위험하다고 알린다 — AIController가 이걸 보고 피신을 시작한다
func is_dangerous() -> bool:
	return _state != State.WAITING

## 지금 선로를 달리고 있는지 — 신문지 날림 같은 장식 연출이 바람을 일으킬지 볼 때 쓴다(WindNewspaper)
func is_running() -> bool:
	return _state == State.RUNNING

## 진행 방향 (1 = 오른쪽으로, -1 = 왼쪽으로)
func get_direction() -> int:
	return _direction

## 열차 몸통 한가운데의 월드 x 좌표
func get_body_x() -> float:
	return body.global_position.x

## 열차 몸통 길이의 절반(px)
func get_half_width() -> float:
	return TRAIN_HALF_WIDTH

func _process(delta: float) -> void:
	_timer -= delta
	_shake_screen(delta)
	match _state:
		State.WAITING:
			if _timer <= warning_duration:
				_begin_warning()
		State.WARNING:
			# sin 값의 부호로 켜짐/꺼짐을 만든다 (별도 타이머 없이 깜빡이게)
			_warning_light.visible = sin(_timer * TAU * warning_blink_speed) > 0.0
			if _timer <= 0.0:
				_begin_run()
		State.RUNNING:
			body.position.x += speed * _direction * delta
			_update_window_light(delta)
			if absf(body.position.x) >= travel_x:
				_finish_run()

## 도착 warning_duration초 전 — 음악과 경고등이 시작된다
func _begin_warning() -> void:
	_state = State.WARNING
	_warning_light.visible = true
	if _music.stream != null:
		_music.play()

func _begin_run() -> void:
	_warning_light.visible = false
	_state = State.RUNNING
	_timer = interval
	body.position.x = -travel_x * _direction
	_apply_direction()
	# 열차가 가는 쪽으로 밀리면서 위로 튕긴다 — 옆에서 부딪히면 밀려나고, 지붕에 있으면 떨어져 나간다
	hitbox.knockback = Vector2(knockback_push * _direction, -knockback_lift)
	# 이번에 지나가는 열차의 빛기둥 높이를 새로 뽑는다 — 매번 같은 모양이면 눈에 익어버린다
	_randomize_beam_heights()
	_set_hitbox_active(true)

func _finish_run() -> void:
	_set_hitbox_active(false)
	_music.stop()
	_park_body()
	if alternate_direction:
		_direction = -_direction
	_state = State.WAITING

## 창문마다 위아래로 빛기둥을 하나씩 만들어 Body에 붙인다.
## Car(열차 그림)보다 **앞 순서**로 옮겨서 빛이 열차 뒤(벽 쪽)로 깔리게 한다 —
## 열차 위에 얹히면 차체를 덮어버려서 빛이 아니라 반투명 판때기로 보인다
func _build_window_beams() -> void:
	if beam_alpha <= 0.0:
		return
	_window_beams = Node2D.new()
	_window_beams.name = "WindowBeams"
	# 더하기 블렌드는 컨테이너에 걸고, 자식 폴리곤은 use_parent_material로 물려받는다
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_window_beams.material = mat
	for rect in WINDOW_RECTS:
		_add_beam(rect, true)
		if beam_down_length > 0.0:
			_add_beam(rect, false)
	body.add_child(_window_beams)
	body.move_child(_window_beams, 0)
	_randomize_beam_heights()

## 창문 하나에 빛기둥을 하나 만들어 붙인다. 실제 모양은 _shape_beam이 잡는다.
## up이 true면 위로(벽 쪽), false면 아래로(선로 바닥 쪽)
func _add_beam(rect: Rect2, up: bool) -> void:
	var beam := Polygon2D.new()
	beam.use_parent_material = true
	# 창문 쪽 두 점만 밝고 끝쪽 두 점은 투명 — 멀어질수록 자연스럽게 사라진다
	var near_color := Color(beam_color.r, beam_color.g, beam_color.b, beam_alpha)
	var far_color := Color(beam_color.r, beam_color.g, beam_color.b, 0.0)
	beam.vertex_colors = PackedColorArray([near_color, near_color, far_color, far_color])
	_window_beams.add_child(beam)
	_beams.append({"node": beam, "rect": rect, "up": up})

## 빛기둥 길이를 창문마다 새로 뽑는다 — 높이가 들쭉날쭉해서 훨씬 자연스럽다.
## 열차가 출발할 때마다 부르므로 지나갈 때마다 모양이 달라진다
func _randomize_beam_heights() -> void:
	for beam in _beams:
		var base: float = beam_up_length if beam["up"] else beam_down_length
		_shape_beam(beam["node"], beam["rect"], beam["up"], base * (1.0 + randf_range(-beam_length_variance, beam_length_variance)))

## 창문 변에서 시작해 멀어질수록 벌어지고 바깥으로 눕는 사다리꼴을 만든다.
## 벌어짐(spread)·눕는 정도(tilt)가 길이에 비례하므로, 길이를 랜덤으로 줘도 모양이 자연스럽게 같이 변한다
func _shape_beam(beam: Polygon2D, rect: Rect2, up: bool, length: float) -> void:
	var spread: float = length * beam_spread
	var near_y: float = rect.position.y if up else rect.position.y + rect.size.y
	var far_y: float = near_y - length if up else near_y + length
	var x1: float = rect.position.x
	var x2: float = rect.position.x + rect.size.x
	# 열차 중심에서 얼마나 떨어진 창문인지(-1=앞 끝, 0=한가운데, +1=뒤 끝)에 비례해 바깥으로 눕힌다
	var side: float = clampf((rect.position.x + rect.size.x * 0.5) / TRAIN_HALF_WIDTH, -1.0, 1.0)
	var lean: float = beam_tilt * length * side
	beam.polygon = PackedVector2Array([
		Vector2(x1, near_y), Vector2(x2, near_y),
		Vector2(x2 + spread + lean, far_y), Vector2(x1 - spread + lean, far_y)])

## 객실 창문 불빛 — 형광등처럼 아주 미세하게 떨린다.
## 어디가 창문인지는 그림(열차창문빛.png)에 이미 구워져 있고 가산 블렌드로 얹히므로, 여기서는 세기만 조절한다.
## 주기가 다른 두 sin을 곱해서 규칙적인 깜빡임으로 안 보이게 한다
func _update_window_light(delta: float) -> void:
	if _window_light == null or not window_lights:
		return
	_glow_phase += delta * window_flicker_speed
	var wobble: float = sin(_glow_phase) * sin(_glow_phase * 0.37 + 1.3)
	var level: float = maxf(1.0 - window_flicker * (0.5 + 0.5 * wobble), 0.0)
	_window_light.modulate.a = window_glow * level
	# 창문에서 쏟아지는 빛도 같은 박자로 떨려야 같은 조명으로 보인다
	if _window_beams:
		_window_beams.modulate.a = level

## 대기 중에는 열차를 화면 밖에 세워둔다
func _park_body() -> void:
	body.position.x = -travel_x * _direction
	_apply_direction()

## 진행 방향에 맞춰 열차 그림을 좌우로 뒤집는다.
## Metro! 그림은 운전실(둥근 앞머리)이 **왼쪽**에 있어서, 오른쪽으로 갈 때(_direction=1) 뒤집어야 앞이 진행 방향을 본다.
## 판정 사각형은 좌우 대칭이라 음수 스케일의 영향을 받지 않는다
func _apply_direction() -> void:
	body.scale.x = -_direction

func _set_hitbox_active(active: bool) -> void:
	hitbox.monitoring = active
	hitbox.monitorable = active
	body.visible = active
	if not active:
		hitbox.clear_repeat_state()

## 열차가 다가오고 지나가는 동안 화면을 흔든다.
## **`add_trauma`가 아니라 `CameraRig.set_rumble()`을 쓴다** — add_trauma는 한 방 맞는 순간 충격이라
## 매 프레임 부어도 감쇠(초당 3)에 밀려 하나도 안 쌓인다. 지속 진동은 바닥값을 까는 방식이라야 한다
func _shake_screen(_delta: float) -> void:
	var amount: float = 0.0
	match _state:
		State.WARNING:
			amount = warning_shake
		State.RUNNING:
			# 열차가 스테이지 한가운데에 가까울수록 세게 — 멀리 있을 때부터 최대로 흔들면
			# 지나가는 순간이 안 살아난다
			var near: float = 1.0 - clampf(absf(body.position.x) / maxf(travel_x, 1.0), 0.0, 1.0)
			amount = pass_shake * (1.0 - pass_shake_focus + pass_shake_focus * near)
	if amount <= 0.0:
		return
	var cam: Node = get_tree().get_first_node_in_group("game_camera")
	if cam and cam.has_method("set_rumble"):
		cam.set_rumble(amount)
