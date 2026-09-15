class_name LeafBurst
extends Node2D

## 나뭇잎이 사방으로 흩날리는 연출 (2026-09-13) — 풀숲에서 뭔가 **퐁 하고 튀어나온 순간**에 터뜨린다.
##
## 이 노드 자리가 곧 터지는 지점이다. 잎은 시작할 때 `count`장 만들어 두고 숨겨 놨다가,
## `trigger`가 가리키는 노드의 `popped` 신호(또는 `delay`초)에 맞춰 한꺼번에 날린다 —
## **초를 두 군데 적어 두면 앞 연출을 만질 때마다 어긋나므로 신호로 묶는 쪽이 안전하다.**
##
## 잎 하나하나는 "위로 솟았다가 옆으로 흩어지며 떨어지고, 끝에 스르륵 사라진다".
## 방향·거리·회전은 `seed_value`로 고정한 난수라, 돌려볼 때마다 같은 모양이 나와 조정하기 쉽다.

## 잎 그림
@export var leaf_texture: Texture2D
## 몇 장 날릴지
@export var count: int = 12
## 잎 크기
@export var leaf_scale: float = 0.07

@export_group("날아가는 모양")
## 좌우로 흩어지는 거리(px). 잎마다 이 범위 안에서 정해진다
@export var spread_min: float = 50.0
@export var spread_max: float = 210.0
## 처음에 위로 솟는 높이(px)
@export var rise_min: float = 50.0
@export var rise_max: float = 130.0
## 솟았다가 떨어지는 거리(px)
@export var fall: float = 220.0
## 한 장이 날아가는 데 걸리는 시간(초)
@export var duration: float = 1.5
## 날아가는 동안 도는 바퀴 수(±). 잎마다 부호가 다르다
@export var spin_turns: float = 1.2
## 잎마다 조금씩 늦게 출발하는 최대 간격(초)
@export var stagger: float = 0.12

@export_group("시작 시점")
## `popped` 신호를 내는 노드(PopUpLayer 등). 비워두면 장면 시작 후 `delay`초에 그냥 터진다
@export var trigger: NodePath
## 신호를 받고(또는 장면이 시작하고) 몇 초 뒤에 터질지
@export var delay: float = 0.0
## 난수 씨앗 — 바꾸면 흩어지는 모양이 통째로 바뀐다
@export var seed_value: int = 20260913

var _leaves: Array[Sprite2D] = []

func _ready() -> void:
	if leaf_texture == null:
		return
	for i in range(count):
		var leaf := Sprite2D.new()
		leaf.texture = leaf_texture
		leaf.scale = Vector2(leaf_scale, leaf_scale)
		leaf.visible = false
		add_child(leaf)
		_leaves.append(leaf)
	var waiter: Node = get_node_or_null(trigger) if not trigger.is_empty() else null
	if waiter and waiter.has_signal("popped"):
		waiter.connect("popped", _burst)
	else:
		var tween: Tween = create_tween()
		tween.tween_interval(maxf(delay, 0.001))
		tween.tween_callback(_burst)

## 잎을 한꺼번에 날린다 (신호를 받고 delay초 뒤)
func _burst() -> void:
	if delay > 0.0 and not trigger.is_empty():
		var wait: Tween = create_tween()
		wait.tween_interval(delay)
		wait.tween_callback(_launch)
		return
	_launch()

func _launch() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(_leaves.size()):
		var leaf: Sprite2D = _leaves[i]
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var dx: float = side * rng.randf_range(spread_min, spread_max)
		var up: float = rng.randf_range(rise_min, rise_max)
		var spin: float = TAU * spin_turns * (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(0.6, 1.4)
		var start: Vector2 = Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(-10.0, 10.0))
		var time: float = duration * rng.randf_range(0.8, 1.2)
		var wait: float = rng.randf_range(0.0, stagger)
		leaf.position = start
		leaf.rotation = rng.randf_range(0.0, TAU)
		leaf.modulate.a = 1.0
		leaf.visible = false
		# 위로 솟았다가(40%) 옆으로 흩어지며 떨어진다(60%)
		var path: Tween = leaf.create_tween()
		path.tween_interval(wait)
		path.tween_callback(func(): leaf.visible = true)
		path.tween_property(leaf, "position", start + Vector2(dx * 0.45, -up), time * 0.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		path.tween_property(leaf, "position", start + Vector2(dx, -up + fall), time * 0.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		path.tween_callback(func(): leaf.visible = false)
		var spin_tween: Tween = leaf.create_tween()
		spin_tween.tween_interval(wait)
		spin_tween.tween_property(leaf, "rotation", leaf.rotation + spin, time).set_trans(Tween.TRANS_LINEAR)
		# 끝 40% 동안 스르륵 사라진다
		var fade: Tween = leaf.create_tween()
		fade.tween_interval(wait + time * 0.6)
		fade.tween_property(leaf, "modulate:a", 0.0, time * 0.4)
