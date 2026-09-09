class_name FocusLines
extends Sprite2D

## 만화 집중선 — 캐릭터 뒤에 깔려서 "쾅!" 하고 강조해주는 판.
##
## 두 가지가 겹쳐 돈다:
##  1. **등장 순간 한 번 확 조여든다** — 크게 시작해서 제 크기로 빨려들며 나타난다(burst_*).
##     메인 메뉴가 이 일러스트로 넘어올 때 restart()를 불러주므로 나올 때마다 다시 터진다
##  2. **계속 부글거린다** — 손으로 그린 만화처럼 한 컷씩 미세하게 어긋난다(jitter_*).
##     매끄럽게 흔들면 "돌아가는 바퀴"로 보이므로, **초당 jitter_hz번만 끊어서** 바꾼다.
##     좌우 뒤집기까지 번갈아 하면 선 무늬가 매번 달라져서 진짜로 다시 그린 것처럼 보인다
##
## 흔들림은 난수를 쓰되 **시간에서 계산하는 결정적 난수**라, 같은 순간엔 항상 같은 모양이다
## (`randf()`를 쓰면 프레임마다 값이 달라져 60fps로 떨리는 노이즈가 된다).
##
## 배치: 메인 메뉴에서 **배경 다음, Scrim 앞**에 둔다. Scrim·LeftFade가 위를 덮으므로
## 흰 선이 눈 아플 만큼 튀지 않고, 왼쪽 메뉴 위로는 자연스럽게 어두워진다.
## 이름을 `Fx<일러스트 이름>`으로 지으면 `MainMenu`가 그 일러스트와 짝지어 같이 켜고 끈다.

@export_group("등장")
## 등장할 때 조여드는 시간(초)
@export var burst_time: float = 0.42
## 조여들기 시작할 때의 크기 배수 (1보다 크면 밖에서 빨려든다)
@export var burst_scale: float = 1.28
## 조여드는 동안 회전하는 각도(도). 살짝 돌면서 들어오면 더 세게 들이친다
@export var burst_spin_deg: float = 6.0

@export_group("평소")
## 등장이 끝난 뒤의 불투명도
@export_range(0.0, 1.0, 0.05) var idle_alpha: float = 0.55
## 도는 속도(초당 각도).
## **선 간격이 좁아서 10도/초를 넘기면 바람개비처럼 보인다** — 스포크가 눈에 띄게 휙휙 지나간다.
## 5도면 한 바퀴에 72초라, 10초 노출 동안 72도쯤 돌아서 "천천히 흐르는" 정도로 읽힌다
@export var spin_deg_per_sec: float = 5.0
## 숨쉬듯 커졌다 작아지는 비율
@export_range(0.0, 0.2, 0.005) var pulse: float = 0.02
## 그 주기(초)
@export var pulse_period: float = 3.4

@export_group("부글거림")
## 1초에 몇 번 새로 그린 것처럼 바꿀지.
## **처음에 11로 뒀다가 너무 정신없다는 피드백을 받아 4로 낮췄다** — 만화 집중선은
## 원래 컷마다 한 번 바뀌는 것이라 초당 3~5번이 자연스럽다. 10을 넘기면 지직거리는 노이즈가 된다
@export var jitter_hz: float = 4.0
## 한 컷마다 틀어지는 최대 각도(도)
@export var jitter_deg: float = 0.6
## 한 컷마다 달라지는 크기 비율
@export_range(0.0, 0.1, 0.005) var jitter_scale: float = 0.01
## 한 컷마다 흔들리는 불투명도 폭
@export_range(0.0, 0.5, 0.01) var jitter_alpha: float = 0.05
## true면 한 컷 걸러 좌우를 뒤집어 무늬가 매번 달라 보이게 한다.
## **기본은 끔.** 선 무늬가 통째로 바뀌어서 이게 제일 정신없다 — 확 튀는 연출이 필요할 때만 켤 것
@export var jitter_flip: bool = false

## 씬에 저장된 제자리 값 — 에디터에서 옮기거나 키워두면 그 값을 기준으로 움직인다
var _rest_scale: Vector2 = Vector2.ONE
var _rest_rot: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	_rest_scale = scale
	_rest_rot = rotation
	if texture == null:
		push_warning("FocusLines: 그림이 비었다 (임포트 전이거나 경로가 바뀜)")
	restart()

## 이 효과가 화면에 나타난 순간 메인 메뉴가 부른다 — 등장 연출을 처음부터 다시 돌린다
func restart() -> void:
	_time = 0.0

func _process(delta: float) -> void:
	_time += delta

	# 등장: 크게 시작해서 제 크기로 빨려든다. 뒤로 갈수록 느려지도록 세제곱 감속
	var u: float = clampf(_time / maxf(burst_time, 0.001), 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - u, 3.0)
	var enter_scale: float = lerpf(burst_scale, 1.0, eased)
	var enter_spin: float = deg_to_rad(burst_spin_deg) * (1.0 - eased)
	var enter_alpha: float = idle_alpha * eased

	# 평소: 아주 천천히 돌면서 숨쉰다
	var breath: float = 1.0 + pulse * sin(_time * TAU / maxf(pulse_period, 0.01))
	var spin: float = deg_to_rad(spin_deg_per_sec) * _time

	# 부글거림: 초당 jitter_hz번만 끊어서 바꾼다 (매 프레임 바꾸면 지직거리는 노이즈가 된다)
	var step: int = int(_time * maxf(jitter_hz, 0.01))
	var r1: float = _noise(step, 1)
	var r2: float = _noise(step, 2)
	var r3: float = _noise(step, 3)

	scale = _rest_scale * enter_scale * breath * (1.0 + jitter_scale * r1)
	rotation = _rest_rot + spin + enter_spin + deg_to_rad(jitter_deg) * r2
	# **modulate가 아니라 self_modulate에 건다** — 메인 메뉴가 일러스트를 바꿀 때
	# 이 노드의 modulate로 크로스페이드를 걸기 때문에, 같은 곳에 쓰면 서로 덮어써서 깜빡인다.
	# 둘은 곱해지므로 페이드와 부글거림이 자연스럽게 겹친다
	self_modulate.a = clampf(enter_alpha * (1.0 + jitter_alpha * r3), 0.0, 1.0)
	if jitter_flip:
		flip_h = (step % 2) == 0

## -1~1 사이의 결정적 의사난수. 같은 (step, salt)면 항상 같은 값이라 프레임률과 무관하게 같은 모양이 나온다
func _noise(step: int, salt: int) -> float:
	var n: int = (step * 73856093) ^ (salt * 19349663)
	n = (n ^ (n >> 13)) * 1274126177
	return float((n >> 8) & 1023) / 511.5 - 1.0
