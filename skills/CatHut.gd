class_name CatHut
extends Area2D

## 고양이를 주기적으로 소환하는 오두막 구조물 — 자체 HP가 있어서 공격으로 부술 수 있고, 시간이 지나도 사라진다 (고양이 아주머니 궁극기).
## Fighter가 아니라서 combat/Hurtbox.gd(Fighter 전용)를 못 쓰고, 여기서 직접 Hitbox를 감지한다
## 오두막 자체 체력 — 0이 되면 부서진다
@export var max_hp: int = 40
## 고양이를 몇 초마다 소환할지
@export var spawn_interval: float = 3.0
## 안 부서져도 이 시간(초)이 지나면 스스로 사라진다
@export var lifetime: float = 15.0
## 소환되는 고양이의 데미지
@export var cat_damage: int = 5
## 소환되는 고양이가 유지되는 시간(초)
@export var cat_lifetime: float = 5.0
## 소환할 고양이(CatPet) 씬
@export var cat_scene: PackedScene

## 남은 체력
var current_hp: int = 0
## 이 오두막을 소환한 캐릭터 — 자기 고양이·공격에는 안 맞게 구분하는 데 쓴다
var owner_fighter: Fighter

func _ready() -> void:
	current_hp = max_hp
	area_entered.connect(_on_area_entered)

	Timers.self_destruct(self, lifetime)

	var spawn_timer := Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_spawn_cat)
	add_child(spawn_timer)
	spawn_timer.start()

func _on_area_entered(area: Area2D) -> void:
	if area is Hitbox and area.source_fighter != owner_fighter:
		take_damage(area.damage)

## 피해를 입혀 체력을 깎는다. 0 이하가 되면 그 자리에서 부서진다
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
