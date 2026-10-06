class_name CigaretteSmoke
extends Hitbox

## 담배 연기 기둥 — 일진 스킬1이 입 앞에 띄우는 연기 판정 + 그림(도형).
## **시전자의 입을 매 프레임 따라다닌다** — 걸어가며 겨눌 수 있고 돌아서면 연기도 같이 돈다.
## 연기 안에 있는 동안 `repeat_interval`마다 계속 조금씩 맞는다(화염방사기와 같은 방식).
## 그림 없이 `_draw()`로 그리므로 연기 스프라이트를 받으면 여기만 바꾸면 된다.

## 입에서 연기가 뻗는 길이(px)와 끝에서의 반폭(px)
@export var reach: float = 190.0
@export var spread: float = 30.0
## 연기 덩어리를 얼마마다 하나씩 뿜는지(초)
@export var puff_interval: float = 0.05
## 덩어리가 앞으로 나가는 속도(px/초)와 위로 뜨는 속도
@export var puff_speed: float = 300.0
@export var puff_rise: float = 26.0
## 덩어리 하나가 사라지기까지(초) — 이 시간에 걸쳐 커지며 옅어진다
@export var puff_life: float = 1.1
## 덩어리 처음·마지막 반지름(px)
@export var puff_radius_start: float = 2.5
@export var puff_radius_end: float = 16.0
## 맞을 때마다 뒤로 밀리는 힘 / 살짝 뜨는 힘 (연기를 맞으면 주춤주춤 밀려난다).
## 너무 세게 주면 상대가 연기 밖으로 밀려나 한 번밖에 못 맞는다
@export var knockback_push: float = 95.0
@export var knockback_lift: float = 35.0
## 연기 색
@export var smoke_color: Color = Color(0.72, 0.73, 0.75, 0.55)

## 연기 덩어리 하나
class Puff:
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var age: float = 0.0
	var life: float = 0.9
	var seed: float = 0.0

var _caster: Fighter = null
var _mouth: Vector2 = Vector2.ZERO
var _left: float = 0.0
var _spawn_left: float = 0.0
var _puffs: Array[Puff] = []
var _shape: CollisionShape2D = null
## 연기가 켜진 뒤 흐른 시간(초)과, 상대(Hurtbox)마다 마지막으로 맞힌 시각 {Hurtbox: float}.
## Hitbox는 판정을 벗어나면 대기시간을 지워 버려서, 좌우로 돌아 판정을 넘겼다 들였다 하면 들어올 때마다 바로 맞았다.
## 그래서 벗어났다 돌아와도 repeat_interval이 지나기 전엔 다시 못 때리게 여기서 따로 센다
var _clock: float = 0.0
var _last_hit_at: Dictionary = {}

## 스킬이 스폰 직후 부른다. 입 위치는 캐릭터 원점 기준 오프셋(x는 바라보는 방향으로 자동 반전)
func setup(caster: Fighter, mouth_offset: Vector2, dmg: int, tick: float, life: float) -> void:
	_caster = caster
	_mouth = mouth_offset
	_left = life
	damage = dmg
	repeat_interval = tick
	source_fighter = caster
	# 데미지 비례 기본 팝업을 얹지 않는다 — 아래 knockback만으로 밀리게 해서 튀는 느낌을 막는다
	pop_override = 0.0
	_shape = get_node_or_null("Collision")
	if _shape != null and _shape.shape is RectangleShape2D:
		(_shape.shape as RectangleShape2D).size = Vector2(reach, spread * 2.0)
	_follow_caster()
	monitoring = true
	monitorable = true

func _process(delta: float) -> void:
	_clock += delta
	super(delta)   # Hitbox가 겹친 상대에게 tick마다 다시 데미지를 준다
	if not is_instance_valid(_caster):
		_left = 0.0
	else:
		_follow_caster()
	if _left > 0.0:
		_left = maxf(_left - delta, 0.0)
		if _left <= 0.0:
			# 다 피웠다 — 판정만 끄고 남은 연기는 흩어질 때까지 그린다
			monitoring = false
			monitorable = false
		_spawn_left -= delta
		while _spawn_left <= 0.0:
			_spawn_left += puff_interval
			_puffs.append(_make_puff())
	_advance_puffs(delta)
	queue_redraw()
	if _left <= 0.0 and _puffs.is_empty():
		queue_free()

## 같은 상대는 판정을 나갔다 들어와도 repeat_interval에 한 번만 맞는다
func _try_hit(area: Area2D) -> bool:
	if _last_hit_at.has(area) and _clock - float(_last_hit_at[area]) < repeat_interval - 0.001:
		return false
	if not super(area):
		return false
	_last_hit_at[area] = _clock
	return true

## 입 위치·방향을 따라간다. 판정 사각형은 입에서 앞으로 reach/2만큼 나간 자리에 둔다
func _follow_caster() -> void:
	var dir: float = signf(_caster.facing)
	if is_zero_approx(dir):
		dir = 1.0
	global_position = _caster.global_position + Vector2(_mouth.x * dir, _mouth.y)
	# 넉백도 바라보는 방향을 따라간다 (돌아서면 밀리는 방향도 바뀐다)
	knockback = Vector2(knockback_push * dir, -knockback_lift)
	if _shape != null:
		_shape.position = Vector2(reach * 0.5 * dir, 0.0)

func _make_puff() -> Puff:
	var p := Puff.new()
	var dir: float = signf(_caster.facing) if is_instance_valid(_caster) else 1.0
	if is_zero_approx(dir):
		dir = 1.0
	# 앞으로 빠르게 나가면서 조금씩 위로 뜬다 — 속도를 조금씩 다르게 줘야 뭉치지 않는다
	p.vel = Vector2(dir * puff_speed * randf_range(0.7, 1.15), -puff_rise * randf_range(0.4, 1.3))
	p.life = puff_life * randf_range(0.8, 1.2)
	p.seed = randf() * TAU
	return p

func _advance_puffs(delta: float) -> void:
	var alive: Array[Puff] = []
	for p in _puffs:
		p.age += delta
		if p.age >= p.life:
			continue
		# 앞으로 갈수록 느려지고(공기 저항) 위아래로 조금 흔들린다
		p.vel.x = move_toward(p.vel.x, 0.0, puff_speed * 0.8 * delta)
		p.pos += p.vel * delta
		p.pos.y += sin(p.age * 6.0 + p.seed) * 6.0 * delta
		alive.append(p)
	_puffs = alive

func _draw() -> void:
	for p in _puffs:
		var t: float = p.age / p.life
		var r: float = lerpf(puff_radius_start, puff_radius_end, t)
		var col: Color = smoke_color
		# 처음엔 진하게 나왔다가 끝으로 갈수록 투명해진다
		col.a *= (1.0 - t) * (1.0 - t * 0.3)
		draw_circle(p.pos, r, col)
