class_name JjajangEatSkill
extends Skill

## 짜장면 먹기 (황근출 해병 스킬2, 2026-10-01) — 주머니에서 짜장면 그릇을 꺼내 먹는다.
## 다 먹으면 **잃은 체력의 heal_ratio**만큼 회복하고, 대신 대시 쿨타임이 dash_cooldown_per_eat초 늘어난다.
## 늘어난 쿨은 **먹을 때마다 더해지고 라운드 끝까지 남는다**(2026-10-01 사용자 요청: 이동속도 둔화 -> 대시 쿨 증가).
## 먹는 도중 피해를 받으면 그릇을 넣고 끊긴다 — 회복도 쿨 증가도 없고 스킬 쿨은 그대로 돈다

## 먹는 시간(초). 이동은 되고 다른 스킬·기본공격은 막힌다
@export var eat_duration: float = 1.0
## 잃은 체력 중 회복하는 비율
@export_range(0.0, 1.0, 0.05) var heal_ratio: float = 0.1
## 한 번 먹을 때마다 대시 쿨타임에 더하는 초
@export var dash_cooldown_per_eat: float = 2.0

var _fighter_ref: Fighter
## 남은 먹는 시간(0이면 안 먹는 중)
var _eat_left: float = 0.0

func _process(delta: float) -> void:
	super._process(delta)
	if _eat_left <= 0.0:
		return
	_eat_left -= delta
	if _eat_left <= 0.0:
		_finish_eating()

func can_use() -> bool:
	return super.can_use() and _eat_left <= 0.0

func _execute(fighter: Fighter) -> void:
	_fighter_ref = fighter
	_eat_left = maxf(eat_duration, 0.05)
	fighter.start_busy(_eat_left)
	if not fighter.damaged.is_connected(_on_damaged):
		fighter.damaged.connect(_on_damaged)
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("play_eat_motion"):
		visual.play_eat_motion(_eat_left)

func _finish_eating() -> void:
	_eat_left = 0.0
	_disconnect()
	if _fighter_ref == null or not is_instance_valid(_fighter_ref) or _fighter_ref.stats == null:
		return
	var lost: int = _fighter_ref.stats.max_hp - _fighter_ref.current_hp
	if lost > 0:
		_fighter_ref.heal(roundi(lost * heal_ratio))
	var eats: int = int(_fighter_ref.custom_data.get("jjajang_eats", 0)) + 1
	_fighter_ref.custom_data["jjajang_eats"] = eats
	_fighter_ref.dash_cooldown_bonus = eats * dash_cooldown_per_eat

## 먹다가 맞으면 끊긴다
func _on_damaged(_amount: int, _knockback: Vector2) -> void:
	if _eat_left <= 0.0:
		return
	_eat_left = 0.0
	_disconnect()
	if _fighter_ref and is_instance_valid(_fighter_ref):
		_fighter_ref.end_busy()
		var visual: Node2D = _fighter_ref.get_node_or_null("Visual")
		if visual and visual.has_method("stop_eat_motion"):
			visual.stop_eat_motion()

func _disconnect() -> void:
	if _fighter_ref and is_instance_valid(_fighter_ref) and _fighter_ref.damaged.is_connected(_on_damaged):
		_fighter_ref.damaged.disconnect(_on_damaged)
