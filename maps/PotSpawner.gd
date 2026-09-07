class_name PotSpawner
extends Node2D

## 맵 위에서 화분이 상시로 떨어지게 하는 스포너 (놀이터 맵).
## 무작위 간격·무작위 위치로 FallingPot을 만들어 떨어뜨린다.
## 화분 데미지는 FallingPot.tscn 쪽에서, 떨어지는 빈도·범위는 여기서 조절한다.

## 화분 사이 간격(초) — 이 범위에서 매번 무작위로 뽑는다
@export var interval_min: float = 1.2
@export var interval_max: float = 2.8
## 라운드 시작 후 첫 화분까지의 여유(초). 시작하자마자 맞는 걸 막는다
@export var first_delay: float = 3.0
## 떨어지는 가로 범위 (이 노드 기준 ±값)
@export var spawn_half_width: float = 420.0
## 화분이 생기는 높이 (이 노드 기준). 화면 위 바깥이라 툭 튀어나오지 않는다
@export var spawn_y: float = -60.0
## 한 번에 몇 개까지 겹쳐 떨어질 수 있는지 — 너무 많이 쌓이는 걸 막는다
@export var max_alive: int = 6
@export var pot_scene: PackedScene

var _timer: float = 0.0

func _ready() -> void:
	_timer = first_delay

func _process(delta: float) -> void:
	if pot_scene == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = randf_range(interval_min, interval_max)
	if get_child_count() >= max_alive:
		return
	_spawn()

func _spawn() -> void:
	var pot: Node2D = pot_scene.instantiate()
	add_child(pot)
	pot.position = Vector2(randf_range(-spawn_half_width, spawn_half_width), spawn_y)
