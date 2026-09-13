class_name PopUpLayer
extends Node2D

## 숨어 있다가 제자리로 **"퐁" 하고 튀어 올라오는** 화면 조각 (2026-09-13 사용자 요청).
##
## 씬에는 **다 나온 자리**에 그대로 놓아두면 된다 — 시작할 때 알아서 `hide_offset`만큼 내려간 뒤
## `delay` 초 뒤에 튀어 올라온다. **바꾸는 건 position 하나뿐이다**(크기·투명도는 안 건드린다, 사용자 지정).
##
## (2026-09-14) 머리 그림이 화면 전체 캔버스(TextureRect)에서 잘라낸 그림(Sprite2D)으로 바뀌면서 `Node2D` 기반이 됐다.
## 위치만 옮기는 연출이라 노드 종류가 바뀌어도 코드는 그대로다.
##
## 내려가 있는 동안 안 보이려면 **앞을 가려 줄 조각이 이 노드보다 뒤(트리에서 아래)에 있어야 한다** —
## 경찰 머리는 `sprite/storymode/잼민이 제압 씬/풀숲_앞.png`(머리 그림의 아랫 윤곽을 경계로 잘라낸 풀숲)가 가린다.
##
## 튀어 오르는 맛은 **제자리를 지나 `overshoot`만큼 더 올라갔다가 내려오는** 두 단계로 낸다.
## Tween 하나로 TRANS_BACK을 써도 되지만, 그러면 되튐 세기를 인스펙터에서 못 만진다

## 실제로 튀어 오르기 시작하는 순간. 같이 터뜨릴 연출(LeafBurst 등)이 이 신호를 기다린다 —
## `delay`를 만져도 같이 따라오므로 초를 두 군데 적어 둘 필요가 없다
signal popped

## 숨을 때 제자리에서 얼마나 옮겨 가 있을지(px). 가림막 뒤로 완전히 들어갈 만큼 잡을 것
@export var hide_offset: Vector2 = Vector2(0, 150)
## **앞서 지나가는 연출이 끝나기를 기다릴 노드**(`RidingBy`처럼 `passed` 신호를 내는 노드).
## 비워두면 장면이 시작하고 `delay`초 뒤에 그냥 뜬다. 지정하면 그 노드가 끝난 뒤 `delay`초 뒤에 뜬다 —
## **연출 시간을 초로 적어 두면 앞 연출의 크기·속도를 바꿀 때마다 어긋나므로 이쪽이 안전하다**
@export var after: NodePath
## 몇 초 뒤에 튀어나오는지. `after`가 비어 있으면 장면 시작 기준(검은 화면이 걷히는 시간보다 뒤에 둘 것),
## 지정돼 있으면 그 연출이 끝난 뒤부터 센다
@export var delay: float = 1.6
## 튀어 오르는 데 걸리는 시간(초)
@export var pop_time: float = 0.42
## 제자리를 지나 얼마나 더 올라갔다 내려오는지(px). 0이면 그냥 제자리에서 멈춘다
@export var overshoot: float = 14.0
## 되튐(제자리로 돌아오는) 구간이 전체에서 차지하는 비율
@export_range(0.05, 0.9, 0.01) var settle_ratio: float = 0.38

var _rest: Vector2 = Vector2.ZERO

func _ready() -> void:
	_rest = position
	position = _rest + hide_offset
	var waiter: Node = get_node_or_null(after) if not after.is_empty() else null
	if waiter and waiter.has_signal("passed"):
		waiter.connect("passed", _start_pop)
		return
	_start_pop()

func _start_pop() -> void:
	var tween: Tween = create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func(): popped.emit())
	if overshoot > 0.0:
		tween.tween_property(self, "position", _rest - Vector2(0.0, overshoot), pop_time * (1.0 - settle_ratio)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "position", _rest, pop_time * settle_ratio) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		tween.tween_property(self, "position", _rest, pop_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## 연출을 처음부터 다시 (장면을 껐다 켜지 않고 확인하고 싶을 때)
func replay() -> void:
	position = _rest + hide_offset
	_start_pop()
