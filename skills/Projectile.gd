class_name Projectile
extends Hitbox

## 직선으로 날아가는 투사체 공용 컴포넌트 (BB탄, 토하기 등). Hitbox를 상속해서 맞으면 실제 데미지를 준다
@export var lifetime: float = 1.5

var _velocity_x: float = 0.0

func _ready() -> void:
	super._ready()
	body_entered.connect(_on_body_entered)

## 발사 방향(1 또는 -1), 속도, 최종 데미지, 발사자를 지정한다
func setup(direction: float, speed: float, projectile_damage: int, shooter: Fighter) -> void:
	_velocity_x = direction * speed
	damage = projectile_damage
	source_fighter = shooter
	knockback = Vector2(direction * 100.0, -20.0)
	rotation = 0.0 if direction >= 0.0 else PI
	_start_lifetime_timer()

## 수명 타이머는 _ready()가 아니라 setup()에서 만든다 — _ready()는 add_child 하는 순간 바로 실행돼서,
## 호출자가 그 다음 줄에서 lifetime을 바꿔도 이미 기본값(1.5)으로 타이머가 만들어진 뒤였다.
## 이것 때문에 토하기의 스택별 사거리(lifetime_per_stack)가 한동안 전혀 안 먹고 있었음.
## 투사체 자신의 자식 Timer라서 투사체가 먼저 사라지면 타이머도 같이 정리된다
func _start_lifetime_timer() -> void:
	var timer := Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()

func _physics_process(delta: float) -> void:
	position.x += _velocity_x * delta

func _on_area_entered(area: Area2D) -> void:
	super._on_area_entered(area)
	# 쏜 사람 본인의 Hurtbox는 무시한다. 총구가 캐릭터 안쪽에서 시작하거나 투사체 판정이 크면
	# 발사하자마자 자기 몸에 닿아서 그대로 사라져버린다(토사물 그림을 넣으면서 실제로 겪음)
	if area is Hurtbox and area.fighter != source_fighter:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	# 벽 등 물리 바디에 부딪히면 데미지 없이 사라진다.
	# 쏜 사람 본인의 몸(CharacterBody2D)은 무시 — 안 그러면 느린 투사체가 몸을 빠져나가기 전에
	# 자기 몸에 부딪혀 그대로 사라진다(0스택 토하기처럼 느린 경우 실제로 발생)
	if body == source_fighter:
		return
	queue_free()
