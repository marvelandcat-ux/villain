class_name CutInSmoke
extends Node2D

## 컷인용 담배 연기 — 스프라이트 없이 `_draw()`로 동그란 덩어리를 겹쳐 그려 "뭉게뭉게" 피어오르게 한다.
## (일진 스킬1의 `CigaretteSmoke`와 같은 방식이다. 거기는 판정이 붙은 Area2D라 컷인엔 못 쓰고,
##  여기는 순수 연출용이라 판정이 없다)
##
## 이 노드의 원점이 **담배 불붙은 끝**이다. 거기서 덩어리가 하나씩 태어나 위로 떠오르며
## 좌우로 흔들리고, 점점 커지면서 옅어진다. 씬에서 이 노드를 담배 끝으로 끌어다 놓으면 된다.
##
## 컷인은 게임이 멈춘(paused) 동안 돌아가므로 `_process`의 delta를 그대로 쓴다 —
## 부모(UltimateCutIn이 띄운 컷인 루트)가 PROCESS_MODE_ALWAYS라 자식인 여기도 같이 돈다.

## 덩어리 하나를 얼마마다 뿜는지(초)
@export var puff_interval: float = 0.13
## 덩어리 하나가 사라지기까지 걸리는 시간(초)
@export var puff_life: float = 1.6
## 위로 떠오르는 속도(px/초, 음수가 위)
@export var rise_speed: float = -95.0
## 좌우로 흔들리는 폭(px)과 빠르기(초당 왕복 수) — 이게 있어야 곧게 안 올라가고 뭉게뭉게 굽이친다
@export var sway: float = 22.0
@export var sway_rate: float = 0.7
## 태어날 때와 사라질 때의 반지름(px)
@export var radius_start: float = 5.0
@export var radius_end: float = 34.0
## 연기 색 (알파는 가장 진할 때의 값)
@export var color: Color = Color(0.82, 0.83, 0.85, 0.55)
## 덩어리 하나를 원 몇 개로 그릴지 — 여러 개를 살짝 어긋나게 겹쳐야 매끈한 원이 아니라 뭉친 덩어리로 보인다
@export var lobes: int = 3
## 흩어짐이 매번 같지 않게 하는 씨앗
@export var seed_value: int = 20260914

## 연기 덩어리 하나 — 태어난 시각과 흔들림 위상만 들고 있고, 위치는 나이로 계산한다
class Puff:
	var age: float = 0.0
	var phase: float = 0.0
	var wobble: Vector2 = Vector2.ZERO
	var lobe_offsets: PackedVector2Array = PackedVector2Array()

var _puffs: Array[Puff] = []
var _spawn_timer: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = seed_value

func _process(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer += puff_interval
		_spawn()
	var alive: Array[Puff] = []
	for puff in _puffs:
		puff.age += delta
		if puff.age < puff_life:
			alive.append(puff)
	_puffs = alive
	queue_redraw()

func _spawn() -> void:
	var puff := Puff.new()
	puff.phase = _rng.randf() * TAU
	puff.wobble = Vector2(_rng.randf_range(-4.0, 4.0), 0.0)
	for i in range(maxi(lobes, 1)):
		# 덩어리 안에서 원들이 조금씩 어긋난 자리 (반지름 대비 비율로 저장해 커질 때 같이 벌어지게 한다)
		puff.lobe_offsets.append(Vector2(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.4, 0.4)))
	_puffs.append(puff)

func _draw() -> void:
	for puff in _puffs:
		var t: float = clampf(puff.age / maxf(puff_life, 0.01), 0.0, 1.0)
		var radius: float = lerpf(radius_start, radius_end, t)
		# 태어날 때 훅 진해졌다가 뒤로 갈수록 옅어진다
		var fade: float = clampf(t / 0.15, 0.0, 1.0) * (1.0 - t)
		var puff_color := Color(color.r, color.g, color.b, color.a * fade)
		var center := Vector2(
			sin(puff.phase + t * TAU * sway_rate) * sway * t,
			rise_speed * puff.age) + puff.wobble
		for offset in puff.lobe_offsets:
			draw_circle(center + offset * radius, radius, puff_color)
