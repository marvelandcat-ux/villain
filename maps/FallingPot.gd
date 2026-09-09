class_name FallingPot
extends Hitbox

## 위에서 떨어지는 화분. 맞은 쪽에 데미지를 주고 깨진다.
## Hitbox를 상속해서 데미지·넉백·히트 이펙트는 공용 판정을 그대로 쓴다 —
## 주인이 없는 판정(source_fighter = null)이라 지나가는 열차와 같은 부류다.
## PotSpawner가 만들어서 맵에 붙인다.

## 떨어지기 시작하는 속도(px/초)
@export var initial_speed: float = 120.0
## 낙하 가속도(px/초²)
@export var fall_gravity: float = 900.0
## 이 y보다 아래로 내려가면 바닥에 부딪힌 것으로 보고 사라진다
@export var floor_y: float = 296.0
## 화분이 깨질 때 남길 조각 장면 (술병 유리조각 GlassShard 재사용). 비어 있으면 안 남긴다
@export var shard_scene: PackedScene
## 남길 조각 개수
@export var shard_count: int = 3
## 조각 색조 — 임시로 술병 초록 조각을 갈색으로 물들여 화분 조각처럼 보이게 한다
@export var shard_color: Color = Color(0.6, 0.4, 0.25)

var _speed: float = 0.0
## 이미 깨졌으면 두 번 처리하지 않는다
var _broken: bool = false

func _ready() -> void:
	# Hitbox._ready()가 area_entered를 연결하므로 반드시 먼저 부른다
	super()
	_speed = initial_speed
	area_entered.connect(_on_pot_hit)

func _physics_process(delta: float) -> void:
	if _broken:
		return
	_speed += fall_gravity * delta
	global_position.y += _speed * delta
	if global_position.y >= floor_y:
		_break()

## 놀이터의 왕은 화분을 맞아도 데미지를 안 받는다.
## 데미지만 건너뛰고 _on_pot_hit은 그대로 돌게 둬서, 화분은 왕에게 부딪혀 깨지는 모습은 보여준다
func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox and Crown.is_king(area.fighter):
		return
	super(area)

## 누군가를 맞혔으면 그 자리에서 깨진다 (데미지 자체는 Hitbox가 이미 처리했다).
## "pot_shelter" 그룹(놀이터 미끄럼틀 지붕 등)에 닿아도 깨진다 — 지붕 밑은 안전지대가 된다
func _on_pot_hit(area: Area2D) -> void:
	if area is Hurtbox or area.is_in_group("pot_shelter"):
		_break()

## 판정을 끄고 잠깐 깨지는 모습을 보여준 뒤 사라진다
func _break() -> void:
	if _broken:
		return
	_broken = true
	_spawn_pot_shards()
	# area_entered 콜백 안에서 바로 끄면 Godot이 "Function blocked during in/out signal"로 막는다.
	# 물리 처리가 끝난 뒤에 반영되도록 set_deferred로 미룬다
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var shards: Node2D = get_node_or_null("Shards")
	var body: Node2D = get_node_or_null("Body")
	if body:
		body.visible = false
	if shards:
		shards.visible = true
		# get_tree().create_timer()가 아니라 자식 Timer를 쓴다 —
		# 라운드가 끝나 맵이 먼저 정리되면 이 화분도 같이 사라져 콜백이 아예 안 돈다
		var timer := Timer.new()
		timer.wait_time = 0.25
		timer.one_shot = true
		add_child(timer)
		timer.timeout.connect(queue_free)
		timer.start()
	else:
		queue_free()

## 화분이 깨진 자리에 갈색 조각 몇 개를 남긴다 (술병 유리조각 재사용, 임시로 갈색 물들임).
## 조각은 씬 루트에 붙여서 화분이 사라져도 남고, GlassShard가 10초 뒤 스스로 페이드되어 사라진다
func _spawn_pot_shards() -> void:
	if shard_scene == null:
		return
	var root: Node = get_tree().current_scene
	if root == null:
		return
	for i in range(shard_count):
		var shard: Node2D = shard_scene.instantiate()
		root.add_child(shard)
		shard.modulate = shard_color
		if shard.has_method("setup"):
			shard.setup(global_position)
