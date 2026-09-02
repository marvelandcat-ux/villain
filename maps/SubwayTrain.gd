class_name SubwayTrain
extends Node2D

## 승강장 아래 선로를 일정 주기로 가로지르는 열차.
## 화면 밖 → 반대편 화면 밖까지 실제로 미끄러져 지나가며, 지나가는 동안에만 판정이 켜진다.
## 승강장 위에 서 있으면 절대 안 맞고, 선로로 떨어졌을 때만 맞는 "떨어지면 죽는다" 연출용 기믹.
##
## 시간 조절은 전부 인스펙터(@export)에서 한다:
##  - interval: 열차 한 대가 지나가고 다음 열차가 올 때까지의 간격(초)
##  - first_delay: 라운드 시작 후 첫 열차까지 기다리는 시간(초)
##  - warning_duration: 열차가 오기 전 경고등이 깜빡이는 시간(초)
##  - speed: 열차가 달리는 속도(px/초) — 화면을 가로지르는 데 걸리는 시간이 이걸로 정해진다

## 열차 사이 간격(초)
@export var interval: float = 8.0
## 라운드 시작 후 첫 열차까지의 대기(초)
@export var first_delay: float = 4.0
## 열차가 오기 전 경고등이 깜빡이는 시간(초)
@export var warning_duration: float = 1.5
## 열차 속도(px/초)
@export var speed: float = 950.0
## 열차에 치였을 때 데미지
@export var damage: int = 30
## 출발/도착 지점의 x 거리 (이 값만큼 화면 바깥에서 출발해 반대쪽 같은 거리까지 간다)
@export var travel_x: float = 1400.0
## true면 열차가 올 때마다 진행 방향이 좌↔우로 번갈아 바뀐다
@export var alternate_direction: bool = true
## 경고등이 1초에 깜빡이는 횟수
@export var warning_blink_speed: float = 6.0

## 진행 중인 상태
enum State { WAITING, WARNING, RUNNING }

@onready var body: Node2D = $Body
@onready var hitbox: Hitbox = $Body/Hitbox
@onready var warning_light: Node2D = $WarningLight

var _state: int = State.WAITING
var _timer: float = 0.0
## 1이면 왼쪽 → 오른쪽, -1이면 오른쪽 → 왼쪽
var _direction: int = 1

func _ready() -> void:
	_timer = first_delay
	_set_hitbox_active(false)
	_park_body()
	warning_light.visible = false
	hitbox.damage = damage

func _process(delta: float) -> void:
	match _state:
		State.WAITING:
			_tick_waiting(delta)
		State.WARNING:
			_tick_warning(delta)
		State.RUNNING:
			_tick_running(delta)

## 다음 열차를 기다리는 중 — warning_duration만큼 남으면 경고등을 켠다
func _tick_waiting(delta: float) -> void:
	_timer -= delta
	if _timer <= warning_duration:
		_state = State.WARNING
		_timer = warning_duration
		warning_light.visible = true

## 경고등이 깜빡이는 중
func _tick_warning(delta: float) -> void:
	_timer -= delta
	# sin 값의 부호로 켜짐/꺼짐을 만든다 (별도 타이머 없이 깜빡이게)
	warning_light.visible = sin(_timer * TAU * warning_blink_speed) > 0.0
	if _timer <= 0.0:
		_start_run()

## 열차가 실제로 지나가는 중
func _tick_running(delta: float) -> void:
	body.position.x += speed * _direction * delta
	if absf(body.position.x) >= travel_x:
		_finish_run()

func _start_run() -> void:
	warning_light.visible = false
	_state = State.RUNNING
	body.position.x = -travel_x * _direction
	# 열차 그림은 앞뒤가 같은 모양이라 방향에 따라 좌우만 뒤집는다 (판정 사각형은 대칭이라 영향 없음)
	body.scale.x = _direction
	_set_hitbox_active(true)

func _finish_run() -> void:
	_set_hitbox_active(false)
	_park_body()
	if alternate_direction:
		_direction = -_direction
	_state = State.WAITING
	_timer = interval

## 대기 중에는 열차를 화면 밖에 세워둔다
func _park_body() -> void:
	body.position.x = -travel_x * _direction
	body.scale.x = _direction

func _set_hitbox_active(active: bool) -> void:
	hitbox.monitoring = active
	hitbox.monitorable = active
	body.visible = active
