class_name DomainShock
extends Node2D

## **아래층으로 퍼져 내려가는 충격파** — 층간소음 빌런 궁극기(영역전개) 전용.
##
## 위층에서 엄마가 발을 디디거나(걷기), 뛰어 착지하거나, 아이가 쿵쿵거릴 때
## 그 **발 자리에서 아래로** 퍼져 내려가 아래층에 있는 상대를 때린다.
##
## 모양은 **아래로 퍼지는 동심 호 여러 겹**이다(2026-10-04 사용자 스케치).
## 처음엔 부채꼴 한 덩어리였는데 "빛줄기 같다"는 지적을 받아 소리가 퍼지는 물결 모양으로 바꿨다.
##
## 걷기 충격파는 `width_ratio`로 **가로만 눌러** 좁은 물결이 된다 — 각도를 줄이는 것과 달리
## 호의 결은 그대로 남아서 같은 기술로 보인다.
##
## 판정은 **첫 물결이 아래층에 닿는 순간 한 번**만 들어간다

## 아래로 퍼져 내려가는 거리(px) — 궁극기가 두 층 간격을 재서 넣어 준다
@export var depth: float = 230.0
## 호가 좌우로 벌어지는 각도(도, 한쪽). 48이면 아래쪽으로 96도짜리 물결이 된다.
## **보이는 폭이 곧 맞는 폭이다** — 맞는 반폭은 `depth * sin(이 각도)`로 계산한다
@export var spread_deg: float = 48.0
## 물결 개수와, 한 겹이 끝까지 퍼지는 시간(초), 겹 사이 출발 간격(초)
@export var arc_count: int = 4
@export var arc_time: float = 0.26
@export var arc_gap: float = 0.055
## 선 굵기(px) — 퍼질수록 조금 얇아진다
@export var line_width: float = 3.2
## 가장 안쪽 물결이 시작하는 반지름(px). 0이면 발 바로 밑에서 점처럼 시작한다
@export var inner_radius: float = 10.0
@export var color: Color = Color(1.0, 1.0, 1.0, 0.92)

## 가로로 눌리는 비율 — 걷기 충격파는 0.5(절반 폭)
var width_ratio: float = 1.0
## 맞은 쪽이 받는 피해와 밀려나는 힘
var damage: int = 4
var knockback: Vector2 = Vector2.ZERO
## 이 충격파를 낸 사람 — 자기 자신은 안 맞는다
var caster: Fighter = null
## 이 높이보다 **아래**에 있는 상대만 맞는다(같은 층에 있는 사람은 안 맞게)
var hit_below: float = 80.0

var _time: float = 0.0
var _life: float = 0.0
var _hit: bool = false

func _ready() -> void:
	z_as_relative = false
	z_index = 30
	# 가로만 눌러서 좁은 물결로 만든다 — 호의 결은 그대로 남는다
	scale.x = maxf(width_ratio, 0.05)
	_life = arc_gap * float(maxi(arc_count - 1, 0)) + arc_time

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if not _hit and _time >= arc_time:
		_hit = true
		_strike()
	if _time >= _life:
		queue_free()

## 맞는 반폭 — **보이는 물결이 아래층에 닿을 때의 폭** 그대로다
func hit_half_width() -> float:
	return depth * sin(deg_to_rad(clampf(spread_deg, 1.0, 89.0))) * maxf(width_ratio, 0.05)

## 첫 물결이 아래층에 닿은 순간 한 번 때린다 — 아래층에 있고 폭 안에 든 상대만
func _strike() -> void:
	if damage <= 0:
		return
	var half: float = hit_half_width()
	for other in get_tree().get_nodes_in_group("fighters"):
		if other == caster or not (other is Fighter) or not is_instance_valid(other):
			continue
		var target: Fighter = other
		if target.global_position.y < global_position.y + hit_below:
			continue   # 같은 층(또는 위)에 있다
		if absf(target.global_position.x - global_position.x) > half:
			continue
		# pop_override 0 — 띄우면 다음 충격파가 전부 빗나가서 "쿵쿵쿵 → 딜딜딜"이 끊긴다
		target.take_damage(damage, knockback, 0.0)

func _draw() -> void:
	for i in range(maxi(arc_count, 1)):
		_draw_arc_ring(_time - arc_gap * float(i))

## 물결 한 겹. t는 그 겹이 출발하고 흐른 시간
func _draw_arc_ring(t: float) -> void:
	if t <= 0.0 or t >= arc_time:
		return
	var k: float = t / arc_time
	# 처음엔 빠르게, 끝으로 갈수록 느리게 퍼진다
	var eased: float = 1.0 - pow(1.0 - k, 2.0)
	var r: float = inner_radius + (depth - inner_radius) * eased
	if r < 1.0:
		return
	var c: Color = color
	c.a *= 1.0 - pow(k, 2.0)
	if c.a <= 0.0:
		return
	var spread: float = deg_to_rad(clampf(spread_deg, 1.0, 89.0))
	# 0도가 오른쪽, 90도가 아래 — 아래를 가운데로 두고 좌우로 벌린다
	draw_arc(Vector2.ZERO, r, PI * 0.5 - spread, PI * 0.5 + spread, 48,
		c, maxf(line_width * (1.0 - k * 0.35), 1.0), true)
