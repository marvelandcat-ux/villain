class_name LiquorSplash
extends Node2D

## 주정뱅이가 술병으로 후려칠 때 사방으로 튀는 술방울 (순수 장식 — 판정 없음).
## 예전 `GlassShard`(초록 유리 파편)를 2026-09-12에 대체했다 — 병 그림은 멀쩡한데 유리만 떨어져서
## "이 유리가 어디서 나왔지?"가 됐고, 콤보 3타 내내 나와서 한 병이 세 번 깨지는 꼴이었다.
## 술은 병이 안 깨져도 튀는 게 자연스럽고, 병에 술이 많을수록 크게 튀어서 술 스택도 눈에 보인다.
##
## `Hitbox`가 명중 지점에 스폰하고 `setup()`으로 위치를 넘긴다. 콤보 마무리 3타에만 나온다
## (`ComboMeleeAttack.debris_final_hit_only`). 바닥에 쌓이지 않고 0.6초 안에 전부 사라진다.

## 방울 하나 — 튀어나가서 떨어지다 바닥에 닿으면 퍼지며 사라진다
class Drop:
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var radius: float = 2.0
	var life: float = 0.5
	var age: float = 0.0
	var landed: bool = false

## 기본으로 튀는 방울 개수
@export var drop_count: int = 6
## 술 스택 1칸마다 더 튀는 방울 개수 (3스택이면 기본 + 6개)
@export var drops_per_power: int = 2
## 튀어나가는 속도 범위(px/초)
@export var speed_min: float = 110.0
@export var speed_max: float = 300.0
## 방울에 걸리는 중력(px/초^2)
@export var fall_gravity: float = 1000.0
## 방울 반지름 범위(px)
@export var radius_min: float = 1.2
@export var radius_max: float = 3.2
## 방울이 사라지기까지의 시간(초) 범위
@export var life_min: float = 0.35
@export var life_max: float = 0.6
## 때린 방향으로 튀는 비율 (나머지는 반대로 조금 튄다 — 전부 앞으로만 가면 부채처럼 보인다)
@export var forward_ratio: float = 0.75
## 방울 색 / 외곽선 색 (이 게임 그림체가 굵은 검은 테두리라 작은 방울에도 한 겹 두른다)
@export var drop_color: Color = Color(0.72, 0.93, 0.66)
@export var outline_color: Color = Color(0.09, 0.16, 0.1)
## 바닥을 찾으려고 아래로 쏘는 레이캐스트 길이(px)
@export var ground_probe: float = 2000.0

## 스폰한 쪽(Hitbox)이 add_child 전에 넣어주는 값 — 넉백 방향과 술 스택 수
var burst_dir: Vector2 = Vector2.ZERO
var burst_power: int = 0

var _drops: Array[Drop] = []
## 바닥 높이(이 노드 기준 로컬 y). 방울이 여기 닿으면 멈추고 곧 사라진다
var _ground_y: float = INF

## 명중 지점에서 술을 튀긴다. Hitbox가 add_child 직후 호출한다
func setup(spawn_pos: Vector2) -> void:
	global_position = spawn_pos
	_ground_y = _find_ground_y(spawn_pos) - spawn_pos.y
	# 때린 방향(넉백 x부호)을 앞으로 삼는다. 방향을 모르면 오른쪽으로 친 것으로 본다
	var face: float = 1.0
	if not is_zero_approx(burst_dir.x):
		face = signf(burst_dir.x)
	var count: int = drop_count + drops_per_power * maxi(burst_power, 0)
	for i in count:
		_drops.append(_make_drop(face))
	queue_redraw()

## 위쪽 반원 안에서 무작위 방향으로 한 방울을 만든다
func _make_drop(face: float) -> Drop:
	var d := Drop.new()
	var angle: float = randf_range(-2.7, -0.45)   # 화면은 y가 아래로 +라 음수가 위쪽이다
	var speed: float = randf_range(speed_min, speed_max)
	d.vel = Vector2(cos(angle), sin(angle)) * speed
	if randf() < forward_ratio:
		d.vel.x = absf(d.vel.x) * face
	else:
		d.vel.x = -absf(d.vel.x) * face * 0.5
	d.radius = randf_range(radius_min, radius_max)
	d.life = randf_range(life_min, life_max)
	return d

func _process(delta: float) -> void:
	var alive: bool = false
	for d in _drops:
		if d.age >= d.life:
			continue
		d.age += delta
		if not d.landed:
			d.vel.y += fall_gravity * delta
			d.pos += d.vel * delta
			if d.pos.y >= _ground_y:
				# 바닥에 닿으면 그 자리에서 퍼지며 금방 사라진다 (쌓이지 않는다)
				d.pos.y = _ground_y
				d.landed = true
				d.life = minf(d.life, d.age + 0.12)
		alive = true
	queue_redraw()
	if not alive:
		queue_free()

func _draw() -> void:
	for d in _drops:
		if d.age >= d.life:
			continue
		var t: float = d.age / d.life
		# 뒤쪽 40% 구간에서만 투명해진다 — 처음부터 흐려지면 튀는 순간이 약해 보인다
		var alpha: float = 1.0 if t < 0.6 else 1.0 - (t - 0.6) / 0.4
		var r: float = d.radius * (1.0 - 0.3 * t)
		if d.landed:
			r *= 1.3
		draw_circle(d.pos, r + 0.8, Color(outline_color, alpha))
		draw_circle(d.pos, r, Color(drop_color, alpha))

## 스폰 지점에서 아래로 레이캐스트해 바닥 윗면 y를 찾는다. 못 찾으면(공중) 한참 아래를 바닥으로 친다
func _find_ground_y(from: Vector2) -> float:
	return PhysicsQuery.ground_y_below(self, from, ground_probe, from.y + 400.0)
