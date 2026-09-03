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

## 진행 중인 상태
enum State { WAITING, WARNING, RUNNING }

@onready var body: Node2D = $Body
@onready var hitbox: Hitbox = $Body/Hitbox
@onready var warning_light: Node2D = $WarningLight
@onready var music: AudioStreamPlayer = $Music

var _state: int = State.WAITING
## 다음 열차가 도착하기까지 남은 시간. 열차가 출발하는 순간 interval로 다시 채워지므로
## "도착에서 다음 도착까지"가 정확히 interval초가 된다 (지나가는 시간도 이 안에 포함)
var _timer: float = 0.0
## 1이면 왼쪽 → 오른쪽, -1이면 오른쪽 → 왼쪽
var _direction: int = 1

func _ready() -> void:
	_timer = first_delay
	hitbox.damage = damage
	hitbox.repeat_interval = hit_interval
	music.stream = arrival_music
	_set_hitbox_active(false)
	_park_body()
	warning_light.visible = false

func _process(delta: float) -> void:
	_timer -= delta
	match _state:
		State.WAITING:
			if _timer <= warning_duration:
				_begin_warning()
		State.WARNING:
			# sin 값의 부호로 켜짐/꺼짐을 만든다 (별도 타이머 없이 깜빡이게)
			warning_light.visible = sin(_timer * TAU * warning_blink_speed) > 0.0
			if _timer <= 0.0:
				_begin_run()
		State.RUNNING:
			body.position.x += speed * _direction * delta
			if absf(body.position.x) >= travel_x:
				_finish_run()

## 도착 warning_duration초 전 — 음악과 경고등이 시작된다
func _begin_warning() -> void:
	_state = State.WARNING
	warning_light.visible = true
	if music.stream != null:
		music.play()

func _begin_run() -> void:
	warning_light.visible = false
	_state = State.RUNNING
	_timer = interval
	body.position.x = -travel_x * _direction
	_apply_direction()
	# 열차가 가는 쪽으로 밀리면서 위로 튕긴다 — 옆에서 부딪히면 밀려나고, 지붕에 있으면 떨어져 나간다
	hitbox.knockback = Vector2(knockback_push * _direction, -knockback_lift)
	_set_hitbox_active(true)

func _finish_run() -> void:
	_set_hitbox_active(false)
	music.stop()
	_park_body()
	if alternate_direction:
		_direction = -_direction
	_state = State.WAITING

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
