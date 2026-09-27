class_name LandDust
extends Node2D

## 착지할 때 발 양옆으로 밀려나가는 먼지 뭉치 (순수 장식 — 판정이 없다).
## **양쪽에 몽글몽글한 구름 뭉치가 하나씩** 생겨 바닥을 따라 바깥으로 미끄러지며 부풀었다 사라진다(2026-09-26 사용자 레퍼런스).
## 흰색 + 옅은 어두운 테두리 — 점프 바람 줄기(JumpWind)와 같은 톤이라 뛰고 내려앉는 연출이 짝이 된다.
## 그림 없이 `_draw()`로 그리므로 먼지 스프라이트를 받으면 여기만 바꾸면 된다.
##
## `Fighter._spawn_land_dust()`가 착지 순간 맵에 붙이고 `setup(세기)`로 얼마나 높이서 떨어졌는지 넘긴다

## 뭉치 기본 반지름(px) — 세기 1(기준 높이에서 떨어짐)일 때
@export var clump_radius: float = 7.0
## 바깥으로 밀려나가는 첫 속도(px/초)와 줄어드는 정도(px/초²)
@export var slide_speed: float = 150.0
@export var slide_drag: float = 420.0
## 살짝 떠오르는 속도(px/초)
@export var rise_speed: float = 14.0
## 사라지기까지(초)
@export var life: float = 0.38
## 처음·마지막 크기 배수 — 나오면서 부푼다
@export var grow_from: float = 0.55
@export var grow_to: float = 1.15
## 색과 테두리
@export var color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var outline_color: Color = Color(0.12, 0.14, 0.2, 0.55)
@export var outline_px: float = 2.0

## 구름 한 뭉치를 이루는 동그라미들 — (가로, 세로, 반지름) 뭉치 반지름 대비. 가운데가 크고 둘레에 작은 게 붙는다
const CLOUD: Array[Vector3] = [
	Vector3(0.0, 0.0, 1.0), Vector3(-0.85, 0.25, 0.72), Vector3(0.8, 0.2, 0.68),
	Vector3(-0.3, -0.62, 0.72), Vector3(0.42, -0.5, 0.6),
]

## 먼지 한 뭉치
class Clump:
	var side: float = 1.0
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var size: float = 1.0
	var jitter: PackedVector2Array = PackedVector2Array()

var _clumps: Array[Clump] = []
var _age: float = 0.0

## power는 "얼마나 높이서 떨어졌나"(1.0 = 기준 높이). 작으면 작게, 크면 크고 멀리 퍼진다
func setup(power: float) -> void:
	z_index = -1   # 캐릭터 발밑에 깔린다
	var size: float = clampf(0.45 + 0.55 * power, 0.45, 1.6)
	for side in [-1.0, 1.0]:
		var c := Clump.new()
		c.side = side
		c.size = size * randf_range(0.9, 1.1)
		# 발 바로 옆에서 시작한다 — 너무 안쪽이면 작은 먼지가 발 그림에 가려 안 보인다
		c.pos = Vector2((10.0 + 6.0 * size) * side, -clump_radius * c.size * 0.55)
		c.vel = Vector2(slide_speed * sqrt(size) * randf_range(0.85, 1.15) * side, -rise_speed)
		# 동그라미마다 조금씩 흔들어 두 뭉치가 똑같이 생기지 않게 한다
		for i in CLOUD.size():
			c.jitter.append(Vector2(randf_range(-0.12, 0.12), randf_range(-0.12, 0.12)))
		_clumps.append(c)
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	for c in _clumps:
		c.vel.x = move_toward(c.vel.x, 0.0, slide_drag * delta)
		c.pos += c.vel * delta
	queue_redraw()

func _draw() -> void:
	var t: float = _age / life
	var grow: float = lerpf(grow_from, grow_to, 1.0 - (1.0 - t) * (1.0 - t))
	# 앞 40%는 또렷하다가 뒤로 갈수록 흐려진다
	var fade: float = 1.0 - clampf((t - 0.4) / 0.6, 0.0, 1.0)
	# 테두리를 먼저 전부 깔고 흰 몸통을 위에 칠한다 — 동그라미끼리 겹친 자리에 테두리 선이 안 생기게
	if outline_px > 0.0 and outline_color.a > 0.0:
		var oc: Color = outline_color
		oc.a *= fade
		for c in _clumps:
			_draw_clump(c, grow, outline_px, oc)
	var col: Color = color
	col.a *= fade
	for c in _clumps:
		_draw_clump(c, grow, 0.0, col)

func _draw_clump(c: Clump, grow: float, extra: float, col: Color) -> void:
	var r: float = clump_radius * c.size * grow
	for i in CLOUD.size():
		var d: Vector3 = CLOUD[i]
		# 바깥쪽(진행 방향)으로 동그라미 배치를 뒤집어 두 뭉치가 서로 마주 보게 한다
		var off := Vector2((d.x + c.jitter[i].x) * c.side, d.y + c.jitter[i].y) * r
		draw_circle(c.pos + off, d.z * r + extra, col)
