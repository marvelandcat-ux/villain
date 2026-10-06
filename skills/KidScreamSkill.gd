class_name KidScreamSkill
extends Skill

## **아이 비명** — 층간소음 빌런 1번 스킬. 품에 안긴 아이가 악을 써서
## **사정거리 안의 상대가 한동안 기본공격을 못 쓰게** 만든다.
##
## 이동도 되고 스킬도 쓸 수 있다 — **기본공격만** 막힌다. 그래서 공포(`apply_fear`)와는 다르다.
## 방어 중인 상대에게는 안 걸린다(다른 디버프와 같은 규칙).
##
## 아이를 **내려놓은 동안**(2번 스킬)에는 품에 아이가 없으므로 비명도 안 나간다 —
## 두 스킬이 서로 물려 있어야 "아이 하나로 둘 다 한다"가 성립한다

## 소리가 닿는 거리(px). 이 안에 있는 상대만 걸린다
@export var radius: float = 300.0
## 상대 기본공격이 잠기는 시간(초).
## ⚠️ `Skill`에 이미 `lock_duration`(내 동작이 묶이는 시간)이 있어서 이름을 달리 썼다 — 서로 다른 값이다
@export var attack_lock_duration: float = 4.0
## 같이 들어가는 피해. 0이면 피해 없이 잠그기만 한다
@export var damage: int = 0
## 비명 음파 연출 장면(`KidScream.tscn`). 비워 두면 소리만 나고 그림은 안 뜬다
@export var scream_scene: PackedScene
## 아이 얼굴에서 비명이 터지는 자리를 **더 미세 조정**하는 값(px).
## 기본 자리는 몸(BodyRig)이 알려 주는 **아이 머리 한가운데**다 — x는 보는 방향으로 자동 반전
@export var scream_offset: Vector2 = Vector2(0, 0)
## 아이가 **우는 얼굴**로 있는 시간(초). 소리가 다 퍼질 때까지 울고 있으면 된다
@export var cry_time: float = 1.0
## 품에 아이가 없으면(2번 스킬로 내려놨을 때) 못 쓰게 할지
@export var needs_kid: bool = true

@export_group("안기는 연출")
## 스킬을 쓰면 옆에서 걷던 아이가 **폴짝 뛰어 품에 안긴다.** 안긴 뒤 소리를 지를 때까지 기다리는 시간(초).
## 리그의 `hug_rise_time`(뛰어오르는 시간)보다 조금 길게 둬야 품에 닿은 다음에 소리가 터진다
@export var hug_time: float = 0.3
## **소리를 지른 뒤 아이가 품에 더 머무는 시간(초).** 이만큼 지나면 바닥으로 내려와 옆에서 걷는다.
## 길면 소리가 끝난 뒤에도 안고만 있어서 늘어진다(2026-10-04 사용자 요청으로 1.1 → 0.55)
@export var hug_hold: float = 0.55
## 소리 지를 때 **아이 쪽으로 화면이 다가가는 배율**과 그 시간(초). 1이면 확대하지 않는다
@export var camera_zoom: float = 1.3
@export var camera_time: float = 0.7
## **안고 있는 동안 내 기본공격도 막을지.** 꺼 두는 게 기본이다 —
## 엄마는 안고 있어도 평타가 나가야 한다(2026-10-04 사용자 결정, 켰다가 도로 끔).
## 켜면 아이를 안고 있는 시간(`hug_time` + `hug_hold`)만큼 내 평타도 같이 막힌다
@export var lock_own_attack: bool = false

## 스킬을 쓰면 **아이가 먼저 품으로 뛰어오르고**, 다 안긴 다음에 소리를 지른다.
## 소리가 다 퍼지면 아이는 다시 바닥으로 내려와 옆에서 걷는다
func _execute(fighter: Fighter) -> void:
	if not is_instance_valid(fighter):
		return
	_hug(fighter, true)
	# 두 손이 아이를 받치고 있는 동안은 나도 평타를 못 쓴다
	if lock_own_attack:
		fighter.lock_basic_attack(hug_time + maxf(hug_hold, 0.05))
	if hug_time <= 0.02:
		_scream(fighter)
		return
	# 품에 안기는 동안 기다렸다가 터뜨린다 — 옆에서 걷다가 소리부터 나면 박자가 안 맞는다.
	# 스킬 자식 Timer라 그 사이 라운드가 끝나 캐릭터가 지워져도 콜백이 안 불린다
	Timers.after(self, hug_time, func(): _scream(fighter))
	Timers.after(self, hug_time + maxf(hug_hold, 0.05), func(): _hug(fighter, false))

## **실제로 소리를 지르는 순간** — 우는 얼굴, 빛줄기, 상대 기본공격 잠금, 화면 확대가 여기서 한꺼번에 일어난다
func _scream(fighter: Fighter) -> void:
	if not is_instance_valid(fighter):
		return
	_spawn_effect(fighter)
	_cry(fighter)
	_zoom_in(fighter)
	var hit_any: bool = false
	for other in fighter.get_tree().get_nodes_in_group("fighters"):
		if other == fighter or not (other is Fighter) or not is_instance_valid(other):
			continue
		var target: Fighter = other
		if fighter.global_position.distance_to(target.global_position) > radius:
			continue
		if target.lock_basic_attack(attack_lock_duration):
			hit_any = true
		if damage > 0 and not target.blocks_debuff():
			target.take_damage(fighter.compute_damage(damage))
	if hit_any:
		# 걸렸으면 화면도 살짝 울린다 — 소리로 거는 기술이라 때린 느낌 대신 이걸 준다
		var camera: Camera2D = fighter.get_viewport().get_camera_2d()
		if camera and camera.has_method("add_trauma"):
			camera.add_trauma(0.22)

## 아이를 품으로 불러올리거나 내려놓는다. 리그가 그 기능을 모르면(다른 캐릭터) 아무 일도 안 한다
func _hug(fighter: Fighter, on: bool) -> void:
	if not is_instance_valid(fighter):
		return
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("set_kid_hug"):
		visual.set_kid_hug(on)

## **아이 쪽으로 화면을 살짝 당긴다.** 아이 머리 조각을 따라가므로 엄마가 걸어도 화면이 아이를 놓치지 않는다
func _zoom_in(fighter: Fighter) -> void:
	if camera_zoom <= 1.001 or camera_time <= 0.0:
		return
	var camera: Camera2D = fighter.get_viewport().get_camera_2d()
	if camera == null or not camera.has_method("focus_on"):
		return
	var at: Node2D = fighter
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("kid_head_node"):
		var kid: Node2D = visual.kid_head_node()
		if kid != null:
			at = kid
	camera.focus_on(at, camera_zoom, camera_time)

## 이 스킬을 지금 쓸 수 있는지 — 품에 아이가 있어야 한다.
## `Skill.use()`가 쿨타임만 보기 때문에, 아이가 없을 때 쿨만 돌고 아무 일도 안 나는 걸 여기서 막는다
func can_use() -> bool:
	if not super.can_use():
		return false
	if not needs_kid:
		return true
	return _has_kid()

## 품에 아이가 있는지 몸(BodyRig)에게 물어본다. 리그에 그 기능이 없으면 "있다"로 친다
func _has_kid() -> bool:
	var fighter := get_parent() as Fighter
	if fighter == null:
		return true
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual == null or not ("carrying" in visual):
		return true
	return bool(visual.carrying)

## 비명이 터지는 자리 — **아이 얼굴**. 아이가 없는 몸이면 캐릭터 중심에서 조금 위
func _scream_at(fighter: Fighter) -> Vector2:
	var base: Vector2 = fighter.global_position + Vector2(0.0, -26.0)
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("kid_head_position"):
		base = visual.kid_head_position()
	return base + Vector2(scream_offset.x * fighter.facing, scream_offset.y)

## 아이 얼굴을 우는 얼굴로 바꿨다가 cry_time 뒤에 되돌린다
func _cry(fighter: Fighter) -> void:
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual == null or not visual.has_method("set_kid_crying"):
		return
	visual.set_kid_crying(true)
	Timers.after(self, maxf(cry_time, 0.05), func():
		if is_instance_valid(visual) and visual.has_method("set_kid_crying"):
			visual.set_kid_crying(false))

func _spawn_effect(fighter: Fighter) -> void:
	if scream_scene == null:
		return
	var parent: Node = fighter.get_parent()
	if parent == null:
		return
	var fx := scream_scene.instantiate() as Node2D
	if fx == null:
		return
	parent.add_child(fx)
	fx.global_position = _scream_at(fighter)
	# 그려지는 고리 크기를 사정거리에 맞춘다 — 보이는 대로 맞아야 억울하지 않다
	if "max_radius" in fx:
		fx.max_radius = radius
