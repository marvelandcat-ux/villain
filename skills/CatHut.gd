class_name CatHut
extends Area2D

## 고양이를 주기적으로 소환하는 오두막 구조물 — 자체 HP가 있어서 공격으로 부술 수 있고, 시간이 지나도 사라진다 (캣맘 궁극기).
## Fighter가 아니라서 combat/Hurtbox.gd(Fighter 전용)를 못 쓰고, 여기서 직접 Hitbox를 감지한다
@export var max_hp: int = 40
@export var spawn_interval: float = 3.0
@export var lifetime: float = 15.0
@export var cat_damage: int = 5
@export var cat_lifetime: float = 5.0
@export var cat_scene: PackedScene

var current_hp: int = 0
var owner_fighter: Fighter

func _ready() -> void:
	current_hp = max_hp
	area_entered.connect(_on_area_entered)

	var lifetime_timer := Timer.new()
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(queue_free)
	add_child(lifetime_timer)
	lifetime_timer.start()

	var spawn_timer := Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_spawn_cat)
	add_child(spawn_timer)
	spawn_timer.start()

func _on_area_entered(area: Area2D) -> void:
	if area is Hitbox and area.source_fighter != owner_fighter:
		take_damage(area.damage)

func take_damage(amount: int) -> void:
	current_hp -= amount
	if current_hp <= 0:
		queue_free()

func _spawn_cat() -> void:
	if cat_scene == null or owner_fighter == null or not is_instance_valid(owner_fighter):
		return
	var cat: CatPet = cat_scene.instantiate()
	get_parent().add_child(cat)
	cat.global_position = global_position
	cat.owner_fighter = owner_fighter
	cat.lifetime = cat_lifetime
	cat.damage = cat_damage
