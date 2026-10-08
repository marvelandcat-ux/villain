extends Node2D

## 번화가 택시(2026-10-08). `min_interval`~`max_interval`초마다 도로 한쪽 화면 밖에서 나와
## 반대편 밖으로 달려 나간다(방향 랜덤). 닿은 캐릭터는 **피해 없이 높이 튀어 오른다**
## (스프링 `SpringJumpPad`와 같은 식 — 사용자 결정).
##
## 그림: 자식 `Art`(왼쪽으로 갈 땐 scale.x만 뒤집는다) 밑에 바퀴 둘 → 본체 순서(바퀴가 아치 뒤로 들어간다).
## 원점 = 택시 아래 가운데(바퀴가 도로에 닿는 자리). 그림 실측(1254 캔버스, 2026-10-08):
## 본체 보이는 영역 x 3~1254 / y 379(표시등 꼭대기)~871, 바퀴 아치 가운데 x 256 / 1036,
## 바퀴 지름 190(본체 픽셀) · 중심 y 828 · 바닥 923. **그림을 바꾸면 다시 잴 것**

@export var min_interval: float = 8.0
@export var max_interval: float = 15.0
## 달리는 속도(px/s)
@export var speed: float = 560.0
## 달리는 길의 양 끝(x) — 벽(±926) 바깥에서 나오고 들어간다
@export var start_x: float = 1150.0
## 튀어 오르는 속도(px/s). 중력 기준 약 1000이면 400px 넘게 뜬다
@export var bounce_velocity: float = 1000.0
## 택시 진행 방향으로 함께 미는 속도(px/s). 0이면 위로만 뜬다
@export var push_x: float = 0.0
## 같은 사람을 다시 튕기기까지 쉬는 시간(초) — 지붕에 다시 떨어지면 또 튕긴다
@export var rebounce_delay: float = 0.35
## 캐릭터 원점 ~ 발끝 거리(몸 캡슐 높이 60의 절반)
@export var fighter_foot: float = 30.0
## 판정 크기(월드 px) — 본체 길이와 표시등 꼭대기까지 높이. 그림 배율을 바꾸면 같이
@export var body_length: float = 269.0
@export var roof_height: float = 117.0

@export_group("눌림")
## 사람을 튕길 때 차체가 스프링처럼 눌렸다 되돌아온다(2026-10-08 사용자 요청). 바닥(바퀴)을 축으로 세로는 눌리고 가로는 반만큼 퍼진다
@export var squash_enabled: bool = true
## 튕길 때 주는 충격(눌림 속도). 3.4면 실측 약 11% 눌린다(2.6 → 8%)
@export var squash_kick: float = 3.4
## 스프링 세기 — 클수록 빨리 되돌아온다
@export var squash_stiffness: float = 380.0
## 잦아드는 빠르기 — 작을수록 여러 번 출렁인다
@export var squash_damping: float = 10.0
## 가장 깊이 눌릴 수 있는 비율
@export var squash_max: float = 0.3
@export_group("")

@export_group("달리는 느낌")
## 달리는 동안 차체 뒤로 하얀 스피드 라인(`combat/SpeedLines.gd`)을 끌고 간다(2026-10-08 사용자 요청 "자동차가 가고 있다는 느낌")
@export var speed_lines: bool = true
## 줄이 생기는 높이 범위(원점 = 바퀴 바닥 기준, 위가 음수). 차체 높이 117 안쪽
@export var speed_line_spread: Vector2 = Vector2(-105.0, -22.0)
@export var speed_line_count: int = 5
@export var speed_line_length: float = 170.0
## 뒷바퀴 밑에서 먼지(`combat/LandDust.gd`)를 이 간격(초)마다 피운다. 0이면 안 피움
@export var dust_interval: float = 0.09
## 먼지 세기(착지 먼지 기준 1 = 큰 뭉치)와 색 — 도로 먼지라 누르스름하게
@export var dust_power: float = 0.5
@export var dust_color: Color = Color(0.86, 0.8, 0.68, 0.75)
## 지나갈 때 화면이 미세하게 떨린다(카메라 `set_rumble`). 가까울수록 세고 0이면 안 떨림
@export var rumble_strength: float = 0.08
## 이 거리(px) 밖이면 안 떨린다
@export var rumble_range: float = 900.0
@export_group("")

const SPEED_LINES_SCRIPT := preload("res://combat/SpeedLines.gd")
const LAND_DUST_SCRIPT := preload("res://combat/LandDust.gd")

var _driving: bool = false
var _dir: float = 1.0
var _wait: float = 0.0
## {Fighter: 다시 튕길 수 있을 때까지 남은 시간}
var _cooldowns: Dictionary = {}
## 눌린 비율(+ = 납작)과 그 속도, 그림 원래 배율
var _squash: float = 0.0
var _squash_vel: float = 0.0
var _art_base_scale: Vector2 = Vector2.ONE
## 달리는 동안 끌고 가는 스피드 라인(없으면 null) / 다음 먼지까지 남은 시간
var _lines: Node2D = null
var _dust_left: float = 0.0

@onready var _art: Node2D = $Art
@onready var _wheels: Array[Node2D] = [$Art/WheelBack, $Art/WheelFront]

func _ready() -> void:
	visible = false
	_art_base_scale = _art.scale.abs()
	_wait = randf_range(min_interval, max_interval)

func _physics_process(delta: float) -> void:
	delta = minf(delta, 0.05)
	for f in _cooldowns.keys():
		_cooldowns[f] -= delta
		if _cooldowns[f] <= 0.0:
			_cooldowns.erase(f)
	if not _driving:
		_wait -= delta
		if _wait <= 0.0:
			_start()
		return
	position.x += _dir * speed * delta
	_spin_wheels(delta)
	_bounce_fighters()
	_update_squash(delta)
	_update_dust(delta)
	_update_rumble()
	if position.x * _dir > start_x:
		_driving = false
		visible = false
		_stop_speed_lines()
		_wait = randf_range(min_interval, max_interval)

func _start() -> void:
	_dir = -1.0 if randf() < 0.5 else 1.0
	position.x = -start_x * _dir
	# 그림은 오른쪽을 보고 있다 — 왼쪽으로 갈 땐 뒤집는다
	_squash = 0.0
	_squash_vel = 0.0
	_apply_squash()
	_driving = true
	visible = true
	_start_speed_lines()
	_dust_left = 0.0

## 굴러간 거리 / 바퀴 반지름만큼 돈다. Art가 뒤집혀 있으면 화면에선 반대로 돌아 진행 방향과 맞는다
func _spin_wheels(delta: float) -> void:
	for wheel in _wheels:
		var tex_radius: float = 494.0 # 바퀴.png 지름 988의 절반
		var radius: float = maxf(tex_radius * absf(wheel.global_scale.y), 1.0)
		wheel.rotation += speed * delta / radius

func _bounce_fighters() -> void:
	var half: float = body_length * 0.5
	for node in get_tree().get_nodes_in_group("fighters"):
		var fighter := node as Fighter
		if fighter == null or not is_instance_valid(fighter) or fighter.is_grabbed:
			continue
		if _cooldowns.has(fighter):
			continue
		# 몸 반지름(20)만큼 넉넉히 — 범퍼에 스치기만 해도 걸린다
		if absf(fighter.global_position.x - global_position.x) > half + 20.0:
			continue
		var feet: float = fighter.global_position.y + fighter_foot
		if feet < global_position.y - roof_height - 4.0 or fighter.global_position.y > global_position.y + 10.0:
			continue
		fighter.velocity = Vector2(fighter.velocity.x + push_x * _dir, -bounce_velocity)
		fighter.cancel_landing_lag()
		_cooldowns[fighter] = rebounce_delay
		if squash_enabled:
			_squash_vel += squash_kick

## 감쇠 스프링 — 눌림이 0으로 되돌아오며 몇 번 출렁인다
func _update_squash(delta: float) -> void:
	if not squash_enabled:
		return
	if absf(_squash) < 0.0005 and absf(_squash_vel) < 0.005:
		if _squash != 0.0:
			_squash = 0.0
			_apply_squash()
		return
	_squash_vel += (-squash_stiffness * _squash - squash_damping * _squash_vel) * delta
	_squash += _squash_vel * delta
	_squash = clampf(_squash, -squash_max, squash_max)
	_apply_squash()

## 원점이 바퀴 바닥이라 Art 배율만 바꾸면 바닥에 붙은 채 눌린다. 좌우 뒤집기(_dir)는 여기서 같이 건다
func _apply_squash() -> void:
	_art.scale = Vector2(_art_base_scale.x * (1.0 + _squash * 0.5) * _dir, _art_base_scale.y * (1.0 - _squash))

## --- 달리는 느낌 ---
## 차체 뒤로 끌리는 하얀 줄. 택시를 따라다니다(`setup`의 caster) 떠나면 `stop()`으로 꼬리부터 지워진다
func _start_speed_lines() -> void:
	_stop_speed_lines()
	if not speed_lines:
		return
	var parent: Node = get_parent()
	if parent == null:
		return
	_lines = SPEED_LINES_SCRIPT.new()
	_lines.line_count = speed_line_count
	_lines.spread_y = speed_line_spread
	_lines.follow_length = speed_line_length
	_lines.z_index = -11   # 택시(-10) 바로 뒤
	_lines.z_as_relative = false
	parent.add_child(_lines)
	# 길이는 넉넉히 — 화면을 다 건너는 데 약 4초, 떠날 때 stop()으로 끊는다
	_lines.setup(self, _dir, 30.0)

func _stop_speed_lines() -> void:
	if _lines != null and is_instance_valid(_lines):
		_lines.stop()
	_lines = null

## 뒷바퀴가 도로를 구르는 자리에서 먼지가 피어오른다 — 착지 먼지를 작게·누르스름하게 돌려쓴다
func _update_dust(delta: float) -> void:
	if dust_interval <= 0.0:
		return
	_dust_left -= delta
	if _dust_left > 0.0:
		return
	_dust_left = dust_interval
	var parent: Node = get_parent()
	if parent == null:
		return
	var dust := LAND_DUST_SCRIPT.new()
	dust.color = dust_color
	dust.outline_color = Color(dust_color.r * 0.5, dust_color.g * 0.45, dust_color.b * 0.4, 0.4)
	parent.add_child(dust)
	# 뒷바퀴 = 진행 방향 반대쪽 바퀴. 바퀴 자리는 Art 기준 ±80이라 뒤집힘(_dir)만 곱한다
	var back_wheel_x: float = -79.8 * _dir
	dust.global_position = global_position + Vector2(back_wheel_x, 0.0)
	dust.setup(dust_power)

## 가까이 지나갈수록 화면이 미세하게 떨린다 — 땅이 울리는 느낌
func _update_rumble() -> void:
	if rumble_strength <= 0.0:
		return
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null or not cam.has_method("set_rumble"):
		return
	var dist: float = absf(cam.get_screen_center_position().x - global_position.x)
	var closeness: float = clampf(1.0 - dist / maxf(rumble_range, 1.0), 0.0, 1.0)
	if closeness > 0.0:
		cam.set_rumble(rumble_strength * closeness)
