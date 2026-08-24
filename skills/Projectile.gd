class_name Projectile
extends Hitbox

## 직선으로 날아가는 투사체 공용 컴포넌트 (BB탄, 토하기 등). Hitbox를 상속해서 맞으면 실제 데미지를 준다
@export var lifetime: float = 1.5

var _velocity_x: float = 0.0

func _ready() -> void:
	super._ready()
	body_entered.connect(_on_body_entered)
	var timer := Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()

## 발사 방향(1 또는 -1), 속도, 최종 데미지, 발사자를 지정한다
func setup(direction: float, speed: float, projectile_damage: int, shooter: Fighter) -> void:
	_velocity_x = direction * speed
	damage = projectile_damage
	source_fighter = shooter
	knockback = Vector2(direction * 100.0, -20.0)
	rotation = 0.0 if direction >= 0.0 else PI

func _physics_process(delta: float) -> void:
	position.x += _velocity_x * delta

func _on_area_entered(area: Area2D) -> void:
	super._on_area_entered(area)
	if area is Hurtbox:
		queue_free()

func _on_body_entered(_body: Node2D) -> void:
	# 벽 등 물리 바디에 부딪히면 데미지 없이 사라진다
	queue_free()
