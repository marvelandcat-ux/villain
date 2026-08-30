class_name BodyRig
extends Node2D

## 스프라이트 조각(머리/몸/손/발)을 붙여 만든 몸에 걷기 동작을 입히는 스크립트.
## 애니메이션 파일 없이, 부모 Fighter의 속도를 보고 매 프레임 각 조각의 위치/회전을 직접 계산한다.
##  - 발: 왼발 한 걸음, 오른발 한 걸음씩 번갈아 움직인다 (한쪽이 움직이는 동안 다른 쪽은 바닥에 붙어 있다)
##  - 몸/머리/손: 한 걸음마다 위로 살짝 들썩 (bob)
##  - 공중에 뜨면: 두 발이 함께 크게 들렸다가, 착지하면 제자리로 돌아온다
## 각 조각의 "제자리" 값은 씬에 저장된 위치를 _ready에서 그대로 기억해두고 거기서부터 흔든다.
## 그래서 에디터에서 조각 위치를 옮겨도 애니메이션 코드는 손댈 필요가 없다.

## 걸을 때 발끝이 위로 들리는 최대 각도(도)
@export var foot_swing_deg: float = 22.0
## 발이 앞뒤로 움직이는 거리(px) — 회전만으로는 제자리걸음처럼 보여서 아주 살짝 곁들인다
@export var foot_stride: float = 3.0
## 몸이 들썩이는 높이(px)
@export var body_bob: float = 2.0
## 걸음 빠르기 — 캐릭터가 최고 속도로 달릴 때 1초에 이 값(라디안)만큼 걸음 위상이 진행된다
@export var step_speed: float = 9.0
## 걷기 시작/멈출 때 동작이 켜지고 꺼지는 빠르기 (클수록 뚝뚝 끊긴다)
@export var blend_speed: float = 8.0
## 점프해서 공중에 떠 있는 동안 두 발이 아래로 뻗는 각도(도)
@export var jump_foot_deg: float = 60.0
## 점프 자세로 바뀌고 착지해서 풀리는 빠르기
@export var jump_blend_speed: float = 12.0
## 기본공격 시 앞쪽 손이 뻗는 최대 거리(px)
@export var punch_distance: float = 20.0
## 주먹이 뻗어나가는 데 걸리는 시간(초) — 짧을수록 빠르고 강하게 나간다
@export var punch_out_time: float = 0.06
## 주먹이 제자리로 돌아오는 데 걸리는 시간(초)
@export var punch_back_time: float = 0.12

@onready var _foot_l: Sprite2D = get_node_or_null("FootL")
@onready var _foot_r: Sprite2D = get_node_or_null("FootR")
@onready var _body: Sprite2D = get_node_or_null("Body")
@onready var _head: Sprite2D = get_node_or_null("Head")
@onready var _hand_l: Sprite2D = get_node_or_null("HandL")
@onready var _hand_r: Sprite2D = get_node_or_null("HandR")

var _fighter: Fighter
## 걸음 위상 — 계속 커지는 각도. sin()에 넣어서 앞뒤로 왔다갔다 하는 값을 만든다
var _phase: float = 0.0
## 동작 세기 (0=제자리, 1=완전히 걷는 중). 멈출 때 툭 끊기지 않게 서서히 줄인다
var _blend: float = 0.0
## 점프 자세 세기 (0=바닥, 1=완전히 공중 자세). 뜨고 내릴 때 각도가 툭 튀지 않게 서서히 오간다
var _air_blend: float = 0.0
## 씬에 저장돼 있던 각 조각의 제자리 위치 {Sprite2D: Vector2}
var _rest_positions: Dictionary = {}
## 주먹 뻗기 진행도 (0=제자리, 1=최대로 뻗은 상태) — play_punch()의 트윈이 값을 바꾼다
var _punch_amount: float = 0.0

func _ready() -> void:
	# Visual로 붙는 자리가 Fighter의 자식이라 부모가 곧 조종 대상이다.
	# 미리보기 도구처럼 Fighter 없이 띄우면 null이고, 그때는 가만히 서 있는다
	_fighter = get_parent() as Fighter
	for part in [_foot_l, _foot_r, _body, _head, _hand_l, _hand_r]:
		if part:
			_rest_positions[part] = part.position

func _process(delta: float) -> void:
	var speed_ratio: float = 0.0
	# Fighter 없이(미리보기 도구 등) 띄운 경우엔 그냥 바닥에 서 있는 것으로 친다
	var on_floor: bool = true
	if _fighter and is_instance_valid(_fighter):
		on_floor = _fighter.is_on_floor()
		# 지금 속도가 그 캐릭터 최고 속도의 몇 %인지 — 느리게 걸으면 발도 덜 흔들리게 하려고 쓴다
		var max_speed: float = _fighter.stats.move_speed * _fighter.move_speed_multiplier
		if max_speed > 0.0:
			speed_ratio = clampf(absf(_fighter.velocity.x) / max_speed, 0.0, 1.0)

	# 공중이면 점프 자세로, 바닥이면 원래 자세로 서서히 옮겨간다
	var air_target: float = 0.0 if on_floor else 1.0
	_air_blend = move_toward(_air_blend, air_target, delta * jump_blend_speed)

	if on_floor and speed_ratio > 0.05:
		_phase += delta * step_speed * maxf(speed_ratio, 0.3)
		_blend = minf(_blend + delta * blend_speed, 1.0)
	else:
		_blend = maxf(_blend - delta * blend_speed, 0.0)
		if is_zero_approx(_blend):
			# 완전히 멈췄으면 다음 걸음이 항상 같은 자세에서 시작하도록 위상을 초기화
			_phase = 0.0

	_apply_pose(speed_ratio)

func _apply_pose(speed_ratio: float) -> void:
	_face_moving_direction()

	var amount: float = _blend * maxf(speed_ratio, 0.4)

	# 한 바퀴(_phase가 0~2파이)를 반씩 나눠서 앞쪽 절반은 왼발, 뒤쪽 절반은 오른발이 한 걸음씩 움직인다.
	# step은 0 → 1 → 0 으로 올라갔다 내려오는 반쪽 사인 곡선 — 발을 들었다가 다시 내려놓는 한 걸음이다
	var cycle: float = fmod(_phase, TAU)
	var left_stepping: bool = cycle < PI
	var step: float = sin(cycle if left_stepping else cycle - PI) * amount

	# 걷는 쪽 발만 움직이고, 반대쪽 발은 제자리(0)에 붙어 있는다.
	# 공중에서는 걷기(step)가 0으로 잦아들고 대신 두 발이 함께 점프 각도로 들린다
	_pose_foot(_foot_l, step if left_stepping else 0.0)
	_pose_foot(_foot_r, 0.0 if left_stepping else step)

	# 발을 들어올리는 순간 몸도 같이 뜨게 해서 한 걸음마다 한 번씩 들썩인다. 위쪽이 음수라 빼준다
	var bob: float = -step * body_bob
	for part in [_body, _head, _hand_l, _hand_r]:
		if part:
			part.position.y = _rest_positions[part].y + bob

	# 앞쪽 손(HandR)은 scale.x 반전 덕분에 항상 바라보는 방향 쪽에 위치한다 — 그 손만 앞으로 뻗는다
	if _hand_r:
		_hand_r.position.x = _rest_positions[_hand_r].x + punch_distance * _punch_amount

## 발 하나의 자세를 잡는다. step은 0(제자리)~1(한 걸음 최대) 값
func _pose_foot(foot: Sprite2D, step: float) -> void:
	if foot == null:
		return
	# 걷기는 발끝이 위로 들리게(각도 양수 = 시계 방향이라 부호를 뒤집는다),
	# 점프는 반대로 발끝이 아래로 뻗게 해서 서로 반대 방향으로 돈다
	foot.rotation = deg_to_rad(-foot_swing_deg * step + jump_foot_deg * _air_blend)
	foot.position.x = _rest_positions[foot].x + foot_stride * step

## 기본공격 시 Fighter가 호출한다 — 앞쪽 손이 앞으로 뻗었다가 돌아오는 주먹 연출을 재생한다
func play_punch() -> void:
	if _hand_r == null:
		return
	var tween := create_tween()
	tween.tween_property(self, "_punch_amount", 1.0, punch_out_time)
	tween.tween_property(self, "_punch_amount", 0.0, punch_back_time)

## 왼쪽(-x)으로 갈 때는 몸 전체를 좌우로 뒤집는다.
## 궁극기 연출 등에서 Visual의 scale을 잠깐 늘였다 줄이는 경우가 있어서,
## 크기는 건드리지 않고 x의 부호만 바라보는 방향에 맞춘다
func _face_moving_direction() -> void:
	if not (_fighter and is_instance_valid(_fighter)):
		return
	var facing_x: float = absf(scale.x) * signf(_fighter.facing)
	if not is_equal_approx(scale.x, facing_x):
		scale.x = facing_x
