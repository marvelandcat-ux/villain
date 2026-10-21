extends Node2D

## 지하철 아저씨 전투 컷신 — **AnimationPlayer 방식**.
##
## 기존 `SubwayFight.gd`는 실사풍 일러스트 조각을 Tween으로 흔드는 방식이었다.
## 이쪽은 **게임에 쓰는 리그(BodyRig)를 그대로 세워 두고** 타임라인으로 움직인다 —
## 그래서 컷신 인물이 인게임 그림체와 똑같이 나온다.
##
## **반드시 알아야 할 것**: `BodyRig.gd`는 `_process`에서 매 프레임 부품 위치를
## 숨쉬기·idle 모션으로 덮어쓴다. 그대로 두면 AnimationPlayer가 찍어 둔 키프레임이
## 바로 다음 프레임에 지워져서 **아무것도 안 움직이는 것처럼 보인다.**
## 그래서 `_ready`에서 리그의 처리를 꺼 버리고, 타임라인에 전권을 준다.

## 멈춰 세울 리그들 — 여기 적힌 노드의 _process를 끈다
@export var rigs: Array[NodePath] = []
## 화면을 흔들 대상(보통 이 노드 자신이 아니라 바깥 틀)
@export var shake_target: NodePath
## 흰 섬광판
@export var flash_rect: NodePath
## 집중선
@export var speedlines: NodePath

## 흔들림이 남은 시간과 세기
var _shake_time: float = 0.0
var _shake_power: float = 0.0
var _shake_base: Vector2 = Vector2.ZERO
var _shake_node: Node2D = null
var _flash: CanvasItem = null
var _lines: CanvasItem = null

func _ready() -> void:
	# 리그의 자체 갱신을 멈춘다 — 이걸 안 하면 타임라인이 매 프레임 지워진다.
	# _ready가 자식부터 돌기 때문에, 이 시점엔 리그가 이미 기본 자세를 잡은 뒤다
	for path in rigs:
		var rig: Node = get_node_or_null(path)
		if rig:
			rig.set_process(false)
			rig.set_physics_process(false)
			_hands_to_front(rig)
	_shake_node = get_node_or_null(shake_target) as Node2D
	if _shake_node:
		_shake_base = _shake_node.position
	_flash = get_node_or_null(flash_rect) as CanvasItem
	_lines = get_node_or_null(speedlines) as CanvasItem
	if _lines:
		_lines.modulate.a = 0.0

func _process(delta: float) -> void:
	if _shake_time <= 0.0:
		return
	_shake_time -= delta
	if _shake_node == null:
		return
	if _shake_time <= 0.0:
		_shake_node.position = _shake_base
		return
	# 남은 시간에 비례해 잦아든다
	var amount: float = _shake_power * (_shake_time / maxf(_shake_decay, 0.001))
	_shake_node.position = _shake_base + Vector2(randf_range(-amount, amount), randf_range(-amount, amount))

## 흔들림이 0까지 잦아드는 데 걸리는 시간 — _process가 비율을 내는 데 쓴다
var _shake_decay: float = 0.3

## **타격 순간** — 타임라인의 메서드 트랙이 부른다.
## power: 흔들림 세기(px), flash: 섬광 밝기(0~1), hold: 흔들림이 이어지는 시간
func impact(power: float = 18.0, flash: float = 0.6, hold: float = 0.3) -> void:
	_shake_power = power
	_shake_time = hold
	_shake_decay = hold
	if _flash:
		# ColorRect는 투명도를 modulate가 아니라 color.a에 들고 있다
		if _flash is ColorRect:
			(_flash as ColorRect).color.a = flash
			var tw: Tween = create_tween()
			tw.tween_property(_flash, "color:a", 0.0, hold * 1.2).set_ease(Tween.EASE_OUT)
		else:
			_flash.modulate.a = flash
			var tw2: Tween = create_tween()
			tw2.tween_property(_flash, "modulate:a", 0.0, hold * 1.2).set_ease(Tween.EASE_OUT)

## **집중선 번쩍** — 타격에 맞춰 잠깐 깔았다 뺀다
func lines_burst(peak: float = 0.75, hold: float = 0.35) -> void:
	if _lines == null:
		return
	_lines.modulate.a = peak
	_lines.scale = Vector2(1.18, 1.18)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_lines, "modulate:a", 0.0, hold).set_ease(Tween.EASE_OUT)
	tw.tween_property(_lines, "scale", Vector2(1.0, 1.0), hold).set_ease(Tween.EASE_OUT)


## **손을 얼굴 앞으로 끌어올린다.**
##
## 리그의 자식 순서가 `... HandL HandR ... Head`라서 머리가 손보다 **나중에** 그려진다.
## 평소엔 손이 몸 옆에 있어 상관없지만, 컷신에서 손을 머리 위로 치켜들면
## **얼굴 뒤로 숨어 버린다.** 그려지는 순서 대신 z_index를 올려 해결한다.
##
## 무기(단소·경봉)는 `HandLHold`/`HandRHold`의 자식이라 걸이까지 같이 올려야 따라온다.
## 리그 원본은 건드리지 않는다 — 이 컷신에서만 앞으로 나온다
func _hands_to_front(rig: Node) -> void:
	for part_name in ["HandL", "HandLHold", "HandR", "HandRHold"]:
		var part: Node2D = rig.get_node_or_null(part_name) as Node2D
		if part:
			part.z_index = 1
