@tool
class_name WindNewspaper
extends Node2D

## 선로 바닥이나 의자 위에 떨어져 있는 신문지 한 장 — 열차가 지나가면 바람에 휘말려 날아올랐다가
## 팔랑거리며 다시 떨어진다 (지하철 승강장 장식, 승패와 무관 — 충돌·판정 없음).
## 스프라이트를 받기 전까지 도형으로 그린다. 그림으로 바꿀 땐 _draw()만 바꾸면 된다.
##
## 열차는 "subway_train" 그룹으로 찾고, 달리는 중인지·방향·몸통 위치는 SubwayTrain의 공개 함수로 묻는다.
## 바람은 **열차보다 먼저 온다** — 앞머리 gust_reach 앞에서 가장 세게 불어 종이를 띄우고,
## 차체 옆에서는 약하게, 꼬리 뒤에서는 잠깐 빨려 들어가다 잦아든다.
## 벽에 부딪히면 튕겨 나오므로 맵 밖으로 사라지지 않고, 다음 열차는 반대 방향이라 도로 날려 보낸다.
## @tool이라 에디터에서도 보여서 위치를 눈으로 잡을 수 있다 — 움직임은 게임에서만 돈다

## --- 모양 ---
## 펼쳤을 때 종이 크기(px)
@export var paper_size: Vector2 = Vector2(26.0, 18.0)
## 종이 색 — 맵의 CanvasModulate(0.55, 0.58, 0.7)가 곱해져 푸르스름하게 어두워지므로 조금 밝게 잡았다.
## 전단지는 노랑·분홍으로 바꿔 쓴다
@export var paper_color: Color = Color(0.97, 0.95, 0.88)
## 바닥에 누워 있을 때 세로로 눌리는 비율 — 옆에서 보면 누운 종이는 얇다
@export_range(0.1, 1.0, 0.05) var lie_flat: float = 0.4

## --- 바닥·벽·천장 (월드 좌표) ---
## 날아간 뒤 떨어지는 바닥 — 선로 윗면(300)보다 살짝 위
@export var ground_y: float = 299.0
## 좌우 벽 안쪽 면 — 벽이 ±560(두께 40)이라 ±540
@export var wall_x: float = 540.0
## 이보다 높이 떠오르지 않는다 — 역 이름판까지 날아가면 산만하다
@export var ceiling_y: float = 110.0
## 벽에 부딪혔을 때 튕겨 나오는 비율
@export_range(0.0, 1.0, 0.05) var wall_bounce: float = 0.3

## --- 바람 ---
## 이보다 높이 있는 종이엔 바람이 안 닿는다 — 열차 지붕 위 조금까지(의자 윗면 155는 들어간다)
@export var wind_top_y: float = 120.0
## 열차 앞머리보다 이만큼 앞에서부터 돌풍이 분다(px)
@export var gust_reach: float = 160.0
## 열차 꼬리 뒤로 바람이 남는 거리(px)
@export var wake_reach: float = 120.0
## 바람에 끌려가는 최고 속도(px/초) — 열차(950)보다 느려야 열차에 처지면서 흩날린다
@export var wind_speed: float = 480.0
## 차체 옆 / 꼬리 뒤 바람 세기 (앞머리 돌풍 = 1)
@export_range(0.0, 1.0, 0.05) var body_wind: float = 0.4
@export_range(0.0, 1.0, 0.05) var wake_wind: float = 0.55
## 바람 속도에 얼마나 빨리 붙는지(1/초)
@export var wind_grip: float = 3.5
## 돌풍을 처음 맞을 때 위로 튀는 속도(px/초) 범위
@export var lift_min: float = 120.0
@export var lift_max: float = 230.0
## 이미 한 번 날린 뒤 바닥에 떨어졌을 때, 남은 바람에 톡톡 튀는 속도(px/초) 범위
@export var hop_min: float = 40.0
@export var hop_max: float = 100.0

## --- 떨어지기 ---
## 중력(px/초²) — 종이라 캐릭터보다 훨씬 약하다. `gravity`라는 이름은 피한다(Crown.gd와 같은 관례)
@export var fall_gravity: float = 420.0
## 바람 속에선 중력이 이만큼만 걸린다 — 바람이 받쳐줘서 뜬 채로 흩날린다
@export_range(0.0, 1.0, 0.05) var wind_gravity_scale: float = 0.45
## 떨어지는 속도 상한(px/초) — 공기에 받쳐 천천히 떨어진다
@export var max_fall_speed: float = 130.0
## 바람이 없을 때 가로 속도가 줄어드는 정도(1/초)
@export var air_drag: float = 1.6
## 떨어질 때 좌우로 팔랑거리는 속도 폭(px/초)과 빠르기
@export var sway: float = 60.0
@export var sway_speed: float = 5.0
## 날아오를 때 도는 속도(rad/초) 범위와, 바람이 그친 뒤 잦아드는 정도(1/초)
@export var spin_min: float = 4.0
@export var spin_max: float = 10.0
@export var spin_damp: float = 1.2
## 공중에서 앞뒤로 뒤집히는 속도(rad/초) 범위
@export var flip_min: float = 5.0
@export var flip_max: float = 12.0
## 바닥에서 미끄러질 때 마찰(px/초²)
@export var ground_friction: float = 650.0

## --- 열차가 오기 직전 ---
## 경고등이 켜진 동안 바닥의 종이가 들썩이는 각도(rad)와 빠르기 — 바람이 열차보다 먼저 온다
@export var tremble: float = 0.06
@export var tremble_speed: float = 34.0

## 그릴 때 쓰는 가로·세로 배율 — x는 앞뒤로 뒤집히는 정도(음수면 뒷면), y는 누운 정도.
## 노드의 scale을 안 쓰는 이유: @tool이라 에디터에서 scale을 건드리면 씬 파일에 저장돼 버린다
var _look: Vector2 = Vector2.ONE
var _airborne: bool = false
var _vel: Vector2 = Vector2.ZERO
var _spin: float = 0.0
var _flip: float = 0.0
var _flip_speed: float = 0.0
## 팔랑거림 위상 — 종이마다 다르게 시작해서 같이 흔들리지 않게 한다
var _sway_phase: float = 0.0
var _time: float = 0.0
## 지금 이 종이가 누워 있는 면(월드 y) — 처음엔 놓인 자리(의자 위일 수도 있다), 한 번 날아가면 선로 바닥
var _rest_y: float = 0.0
## 이번 열차에서 이미 크게 한 번 떴는지 — 지나가는 내내 크게 튀면 트램펄린처럼 보인다
var _gusted: bool = false
var _train: SubwayTrain

func _ready() -> void:
	_look = Vector2(1.0, lie_flat)
	if Engine.is_editor_hint():
		return
	# 놓인 자리 바로 밑이 이 종이가 누워 있는 면이다
	_rest_y = global_position.y + _half_height()
	_sway_phase = randf() * TAU

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		# 에디터에서는 움직이지 않고, 인스펙터에서 바꾼 모양이 바로 보이게 다시 그리기만 한다
		_look = Vector2(1.0, lie_flat)
		queue_redraw()
		return
	_time += delta
	var wind: float = 0.0
	var dir: float = 0.0
	var warning: bool = false
	var train: SubwayTrain = _find_train()
	if train:
		if train.is_running():
			dir = float(train.get_direction())
			wind = _wind_strength(train, dir)
		else:
			_gusted = false   # 다음 열차 때 다시 크게 뜰 수 있게
			warning = train.is_dangerous()
	if wind > 0.0:
		_catch_wind(wind, dir, delta)
	if _airborne:
		_fly(wind, delta)
	else:
		_rest(warning, delta)
	queue_redraw()

## "subway_train" 그룹의 열차를 찾아 기억해둔다 (열차가 없는 맵이면 null — 그냥 누워 있기만 한다)
func _find_train() -> SubwayTrain:
	if not is_instance_valid(_train):
		_train = get_tree().get_first_node_in_group("subway_train") as SubwayTrain
	return _train

## 지금 이 종이 자리에 부는 바람 세기(0~1). 열차 꼬리를 0, 앞머리를 차체 길이로 놓은 축 위에서 잰다
func _wind_strength(train: SubwayTrain, dir: float) -> float:
	if global_position.y < wind_top_y:
		return 0.0
	var half: float = train.get_half_width()
	var s: float = (global_position.x - (train.get_body_x() - dir * half)) * dir
	var length: float = half * 2.0
	if s > length + gust_reach or s < -wake_reach:
		return 0.0
	if s > length:
		return 1.0                                  # 앞머리가 밀어내는 돌풍 — 가장 세다
	if s >= 0.0:
		return body_wind                            # 차체 옆 — 흐트러진 바람
	return wake_wind * (1.0 + s / wake_reach)       # 꼬리 뒤 — 빨려 들어가다 잦아든다

## 바람을 맞는다 — 가로로는 바람 속도로 끌려가고, 처음 맞는 돌풍엔 크게 떠오른다
func _catch_wind(wind: float, dir: float, delta: float) -> void:
	_vel.x += (dir * wind_speed * wind - _vel.x) * minf(wind_grip * delta, 1.0)
	if not _gusted:
		_gusted = true
		_take_off(randf_range(lift_min, lift_max), dir)
	elif not _airborne:
		# 이미 한 번 날린 뒤 바닥에 떨어졌으면 남은 바람에 톡톡 튀며 끌려간다
		_take_off(randf_range(hop_min, hop_max) * wind, dir)

## 떠오른다. 한 번 날아가면 떨어지는 곳은 선로 바닥이다 (의자 위에서 날려도)
func _take_off(lift: float, dir: float) -> void:
	_airborne = true
	_rest_y = ground_y
	_vel.y = minf(_vel.y, -lift)
	# 대부분은 바람 방향으로 굴러가듯 돌고, 가끔 반대로 돈다
	var turn: float = dir if randf() < 0.75 else -dir
	if turn == 0.0:
		turn = 1.0
	_spin = randf_range(spin_min, spin_max) * turn
	_flip_speed = randf_range(flip_min, flip_max)

## 공중 — 약한 중력으로 떨어지면서 돌고, 뒤집히고, 좌우로 팔랑거린다
func _fly(wind: float, delta: float) -> void:
	var g: float = fall_gravity * (wind_gravity_scale if wind > 0.0 else 1.0)
	_vel.y = minf(_vel.y + g * delta, max_fall_speed)
	if wind <= 0.0:
		_vel.x *= exp(-air_drag * delta)
		_spin *= exp(-spin_damp * delta)
		_flip_speed *= exp(-spin_damp * delta)
	# 팔랑거림은 속도에 쌓지 않고 그 순간만 더한다 — 쌓으면 한쪽으로 흘러가 버린다
	_sway_phase += delta * sway_speed
	var sway_v: float = sin(_sway_phase) * sway * (1.0 - wind)
	global_position += Vector2(_vel.x + sway_v, _vel.y) * delta
	# 도는 게 거의 멈추면 낙엽처럼 좌우로 기울며 떨어진다
	if absf(_spin) > 1.5 or wind > 0.0:
		rotation += _spin * delta
	else:
		rotation = lerp_angle(rotation, sin(_sway_phase) * 0.45, minf(delta * 3.0, 1.0))
	# 앞뒤로 뒤집히기 — 빨리 돌 땐 cos로 얇아졌다 넓어졌다, 느려지면 가까운 면으로 펴진다
	_flip += _flip_speed * delta
	var c: float = cos(_flip)
	var side: float = 1.0 if c >= 0.0 else -1.0
	if _flip_speed > 2.0:
		_look.x = maxf(absf(c), 0.15) * side
	else:
		_look.x = move_toward(_look.x, side, delta * 3.0)
	_look.y = move_toward(_look.y, 1.0, delta * 4.0)
	_keep_inside()
	if _vel.y > 0.0 and global_position.y + _half_height() >= _rest_y:
		_land()

## 누워 있다 — 남은 속도만큼 미끄러지고, 옆에서 본 누운 종이처럼 얇게 눌린다.
## 열차가 오기 직전(경고등)엔 바람이 먼저 와서 들썩거린다
func _rest(warning: bool, delta: float) -> void:
	_vel.x = move_toward(_vel.x, 0.0, ground_friction * delta)
	global_position.x += _vel.x * delta
	_keep_inside()
	var side: float = 1.0 if _look.x >= 0.0 else -1.0
	_look.x = move_toward(_look.x, side, delta * 6.0)
	_look.y = move_toward(_look.y, lie_flat, delta * 6.0)
	var tilt: float = sin(_time * tremble_speed + _sway_phase) * tremble if warning else 0.0
	# 뒤집혀 떨어졌으면 뒤집힌 채로 눕는다 — 0도로만 되돌리면 바닥에서 한 바퀴 빙 돈다
	var flat: float = roundf(rotation / PI) * PI
	rotation = lerp_angle(rotation, flat + tilt, minf(delta * 8.0, 1.0))
	global_position.y = _rest_y - _half_height()

## 떨어져서 면에 닿았다 — 가로 속도는 남겨서 조금 미끄러지게 한다
func _land() -> void:
	_airborne = false
	_vel.y = 0.0
	global_position.y = _rest_y - _half_height()

## 벽을 넘어가거나 너무 높이 뜨지 않게 막는다
func _keep_inside() -> void:
	var limit: float = wall_x - paper_size.x * 0.5
	if absf(global_position.x) > limit:
		global_position.x = signf(global_position.x) * limit
		if signf(_vel.x) == signf(global_position.x):
			_vel.x = -_vel.x * wall_bounce
			_spin = -_spin * 0.6
	if global_position.y < ceiling_y:
		global_position.y = ceiling_y
		_vel.y = maxf(_vel.y, 0.0)

## 지금 모양에서 가운데부터 아래 끝까지의 높이 (회전은 무시한 근사)
func _half_height() -> float:
	return paper_size.y * absf(_look.y) * 0.5

## 임시 도형: 접힌 신문 한 장. 누워 있거나 옆으로 뒤집혀 얇아졌을 땐 글자 줄을 안 그린다 — 뭉개져 보인다.
## 좌표에 _look을 직접 곱해서 그린다 — scale로 누르면 외곽선 두께까지 같이 얇아진다
func _draw() -> void:
	var w: float = paper_size.x * 0.5
	var h: float = paper_size.y * 0.5
	var corners: PackedVector2Array = _quad(Rect2(-w, -h, w * 2.0, h * 2.0))
	draw_colored_polygon(corners, paper_color)
	# 가운데 접힌 자국
	draw_line(Vector2(0.0, -h) * _look, Vector2(0.0, h) * _look, paper_color.darkened(0.2), 1.0)
	if absf(_look.x * _look.y) > 0.55:
		var ink := Color(0.32, 0.32, 0.36)
		# 왼쪽 면: 굵은 제목 한 칸 + 짧은 줄 셋 / 오른쪽 면: 기사 줄 다섯
		draw_colored_polygon(_quad(Rect2(-w * 0.88, -h * 0.72, w * 0.7, h * 0.4)), ink)
		for i in 3:
			var y: float = -h * 0.1 + i * h * 0.28
			draw_line(Vector2(-w * 0.88, y) * _look, Vector2(-w * 0.16, y) * _look, ink, 1.0)
		for i in 5:
			var y: float = -h * 0.72 + i * h * 0.32
			draw_line(Vector2(w * 0.16, y) * _look, Vector2(w * 0.88, y) * _look, ink, 1.0)
	var outline: PackedVector2Array = corners.duplicate()
	outline.append(corners[0])
	draw_polyline(outline, Color.BLACK, 1.5)

## 사각형 네 모서리에 지금 배율(_look)을 곱한 다각형
func _quad(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		r.position * _look, Vector2(r.end.x, r.position.y) * _look,
		r.end * _look, Vector2(r.position.x, r.end.y) * _look])
