class_name XSlashFinisher
extends Node

## **X자 마무리 연출** — 지하철 아저씨 쌍 악기 3타. `BasicAttack`(ComboMeleeAttack)의 자식으로 단다.
##
## 한 타를 **느림 → 빠름 → 느림** 세 토막으로 끊어 연출한다(2026-10-02 사용자 요청).
##  1. **손을 위로 쭉 드는 동안** — 시간이 느려지고 카메라가 아저씨에게 바짝 다가간다.
##  2. **내리치는 순간** — 평소 속도로 돌아온다. 느린 채로 내리치면 내리꽂는 맛이 안 난다.
##  3. **맞아서 날아가는 동안** — 다시 느려지고, **맞은 쪽에 X자 자취**가 그어진다.
##
## 판정 자체는 건드리지 않는다 — 때리는 건 평소대로 몸이 한다.
## **궁(쌍 악기)을 쓴 동안만 나온다** — 평소 3타는 그냥 단소로 친다

## 연출이 붙는 타 번호(0부터). 기본 2 = 3타
@export var trigger_step: int = 2
## 켜 두면 **왼손에도 악기를 든 동안**(= 궁 중)에만 나온다
@export var require_dual: bool = true
## 띄울 X자 자취 장면
@export var trail_scene: PackedScene
## **맞은 쪽** 몸 중심에서 X가 뜨는 자리(x는 때린 쪽이 보는 방향으로 자동 반전)
@export var trail_offset: Vector2 = Vector2(0, -10)
## 켜면 X가 **맞은 쪽 몸에 붙어 같이 날아간다**(기본). 끄면 맞은 자리에 그대로 남고 상대만 날아간다
@export var follow_victim: bool = true
## X자 크기 배율
@export var trail_scale: float = 1.0

@export_group("슬로우모션")
## **손을 드는 동안**(예비동작)의 시간 배속. 1이면 안 느려진다
@export var windup_scale: float = 0.4
## 그 느려짐이 아무리 길어도 이 **실제 시간**(초)이 지나면 저절로 풀린다 — 타가 끊겨도 안 멈춰 있게 하는 안전장치
@export var windup_slow_max: float = 1.2
## **내리치는 순간**의 배속. 1이면 평소 속도로 돌아온다(기본)
@export var strike_scale: float = 1.0
## **맞고 날아가는 동안**의 배속과 그 **실제 시간**(초)
@export var impact_scale: float = 0.3
@export var impact_time: float = 0.45

@export_group("카메라")
## 평소 배율의 몇 배까지 다가갈지
@export var zoom_mul: float = 1.55
## 다가가 있는 **실제 시간**(초)과 들어가고 나오는 데 걸리는 시간(초)
@export var zoom_time: float = 1.1
@export var zoom_blend: float = 0.12

## 내가 시간을 건드린 마지막 순번. 되돌리는 타이머는 이 번호가 그대로일 때만 되돌린다 —
## 그 사이 다른 연출(또는 이 연출의 다음 토막)이 시간을 잡았으면 덮어쓰면 안 된다
var _slow_token: int = 0

## --- 콤보가 불러 주는 세 지점 ---

## 그 타가 **시작될 때**(예비동작 시작). 손을 드는 동안을 느리게 만들고 카메라를 당긴다
func on_combo_swing(fighter: Fighter, step: int) -> void:
	if not _applies(fighter, step):
		return
	_zoom_in(fighter)
	_set_time(fighter, windup_scale, windup_slow_max)

## 그 타의 **판정이 켜지는 순간**(내리치는 순간). 평소 속도로 돌려 내리꽂는 맛을 살린다.
## 판정은 평소대로 몸이 하므로 **항상 false**를 돌려준다
func on_combo_strike(fighter: Fighter, step: int, _src: Hitbox) -> bool:
	if _applies(fighter, step):
		_set_time(fighter, strike_scale, 0.0)
	return false

## 그 타가 **맞았을 때**. 다시 느려지고 맞은 쪽에 X자가 그어진다
func on_combo_hit(fighter: Fighter, step: int, victim: Node) -> void:
	if not _applies(fighter, step):
		return
	_spawn_trail(fighter, victim)
	_set_time(fighter, impact_scale, impact_time)

## 이 연출을 낼 타·상태인지
func _applies(fighter: Fighter, step: int) -> bool:
	if step != trigger_step or not is_instance_valid(fighter):
		return false
	return not require_dual or _is_dual(fighter)

## 왼손에도 악기를 들고 있는지(= 궁 중인지) 몸에게 물어본다
func _is_dual(fighter: Fighter) -> bool:
	var visual: Node = fighter.get_node_or_null("Visual")
	return visual != null and "held_item_l_armed" in visual and bool(visual.held_item_l_armed)

## X자를 **맞은 쪽 몸에** 띄운다. 맞은 게 없으면(헛침) 아무것도 안 띄운다.
##
## 기본은 맞은 쪽의 **자식으로 붙인다** — 그래야 상대가 날아가는 내내 X가 몸에 새겨진 채 같이 간다.
## 맵에 붙이면 맞은 자리에 남고 상대만 빠져나가 버린다
func _spawn_trail(fighter: Fighter, victim: Node) -> void:
	if trail_scene == null:
		return
	var target := victim as Node2D
	if target == null or not is_instance_valid(target):
		return
	var trail := trail_scene.instantiate() as Node2D
	if trail == null:
		return
	var offset := Vector2(trail_offset.x * fighter.facing, trail_offset.y)
	if follow_victim:
		target.add_child(trail)
		# 자식이라 **부모의 크기·뒤집힘을 물려받는다** — 몸이 피격으로 기울거나 뒤집혀도
		# X는 그대로여야 하므로 위치만 쓰고 크기는 아래에서 다시 정한다
		trail.position = offset
	else:
		var parent: Node = fighter.get_parent()
		if parent == null:
			trail.queue_free()
			return
		parent.add_child(trail)
		trail.global_position = target.global_position + offset
	trail.scale = Vector2(trail_scale * signf(fighter.facing), trail_scale)

func _zoom_in(fighter: Fighter) -> void:
	var camera: Camera2D = fighter.get_viewport().get_camera_2d()
	if camera and camera.has_method("focus_on"):
		camera.focus_on(fighter, zoom_mul, zoom_time, zoom_blend)

## 시간 배속을 바꾼다. `hold`가 0보다 크면 그 **실제 시간** 뒤에 1로 되돌린다.
##
## ⚠️ 되돌리는 타이머는 `ignore_time_scale`로 돌려야 한다 — 배속을 낮춰 놨으므로 보통 타이머는
##    그만큼 늦게 끝난다(히트스톱이 쓰는 방법과 같다).
## ⚠️ 되돌릴 때 **내가 마지막으로 건드린 게 맞고, 값도 그대로일 때만** 1로 올린다 —
##    그 사이 다음 토막이나 KO 연출이 시간을 잡았으면 그걸 덮어쓰면 안 된다
func _set_time(fighter: Fighter, value: float, hold: float) -> void:
	_slow_token += 1
	var token: int = _slow_token
	Engine.time_scale = maxf(value, 0.02)
	if hold <= 0.0:
		return
	var applied: float = Engine.time_scale
	var timer: SceneTreeTimer = fighter.get_tree().create_timer(hold, true, false, true)
	timer.timeout.connect(func():
		if _slow_token == token and absf(Engine.time_scale - applied) < 0.001:
			Engine.time_scale = 1.0)
