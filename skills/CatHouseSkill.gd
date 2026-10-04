class_name CatHouseSkill
extends Skill

## 고양이 집 짓기 — 고양이 아주머니 스킬1(G). 바라보는 쪽 앞에 무릎을 꿇고 망치질로 `build_time`초 동안 집을 짓는다
## (슈퍼아머 — 맞아도 HP만 닳고 끝까지 짓는다, 망치가 땅을 칠 때마다 먼지). 다 지으면 그 순간 스킬2로 고른 고양이가
## 하나 나오고 그 뒤 `spawn_interval`마다 하나씩(`CatHouse`). 집은 몇 채든 지을 수 있고 상대가 때려 부술 수 있다.
## 지상에서만 쓴다. 짓는 동안 이동·점프·다른 행동 전부 막힌다(`movement_override`)

const CAT_HOUSE := preload("res://skills/CatHouse.gd")
const LAND_DUST := preload("res://combat/LandDust.gd")

## 짓는 시간(초)
@export var build_time: float = 2.0
## 집 가운데가 캐릭터에서 앞으로 떨어진 거리(px)
@export var place_distance: float = 62.0
@export var house_hp: int = 40
@export var spawn_interval: float = 7.0
## 맵에 이 캐릭터의 고양이가 이만큼 있으면 집이 더 안 내보낸다
@export var max_cats: int = 4
## 망치질 먼지 색(착지 먼지 그림을 흙빛으로)
@export var dust_color: Color = Color(0.82, 0.74, 0.6, 0.9)
## 망치질 먼지 크기(착지 먼지 세기)
@export var dust_power: float = 0.6

var _fighter: Fighter = null
var _has_fighter: bool = false
var _house = null
var _building: bool = false
var _armored: bool = false
var _dir: float = 1.0
var _time: float = 0.0
var _next_hit: float = 0.0
var _hammer_period: float = 0.4

func can_use() -> bool:
	if not super():
		return false
	var fighter := get_parent() as Fighter
	# 궁극기 주황 고양이 옷을 입은 동안은 못 쓴다(CatUltimate)
	return fighter != null and fighter.is_on_floor() and not _building and not fighter.custom_data.get("cat_suit", false)

func _execute(fighter: Fighter) -> void:
	_fighter = fighter
	_has_fighter = true
	_dir = signf(fighter.facing) if not is_zero_approx(fighter.facing) else 1.0
	_time = 0.0
	_building = true
	fighter.velocity.x = 0.0
	fighter.movement_override = self
	fighter.start_busy(build_time + 0.1)
	fighter.add_super_armor()
	_armored = true
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual:
		if visual.has_method("set_kneeling"):
			visual.set_kneeling(true)
		if visual.has_method("set_hammering"):
			visual.set_hammering(true)
		var period = visual.get("hammer_period")
		if period != null:
			_hammer_period = maxf(float(period), 0.05)
	_next_hit = _hammer_period
	_place_house(fighter)

## 집 터를 잡는다 — 앞이 벽이면 벽 앞까지 당기고, 그 아래 바닥 위에 놓는다
func _place_house(fighter: Fighter) -> void:
	var map: Node = fighter.get_parent()
	if map == null:
		return
	var feet_y: float = fighter.global_position.y + 30.0
	var from := Vector2(fighter.global_position.x, feet_y - 20.0)
	var x: float = fighter.global_position.x + _dir * place_distance
	var wall: Dictionary = PhysicsQuery.raycast_ignoring_fighters(fighter, from, Vector2(x + _dir * 35.0, from.y))
	if not wall.is_empty():
		x = wall.position.x - _dir * 35.0
	var ground_y: float = PhysicsQuery.ground_y_below(fighter, Vector2(x, feet_y - 20.0), 120.0, feet_y)
	_house = CAT_HOUSE.new()
	_house.max_hp = house_hp
	_house.spawn_interval = spawn_interval
	_house.max_cats = max_cats
	_house.owner_fighter = fighter
	map.add_child(_house)
	_house.global_position = Vector2(x, ground_y)
	_house.set_progress(0.0)

## 짓는 동안은 점프도 못 한다
func blocks_jump() -> bool:
	return _building

## Fighter.apply_physics가 이동 속도를 물어볼 때 — 짓는 동안은 제자리
func get_move_velocity_x() -> float:
	return 0.0

func after_physics(fighter: Fighter, delta: float) -> void:
	# Fighter.move()는 못 움직일 때도 facing을 바꾸므로 매 프레임 되돌린다
	fighter.facing = _dir
	if not _building:
		return
	_time += delta
	if is_instance_valid(_house):
		_house.set_progress(_time / maxf(build_time, 0.01))
	while _time >= _next_hit and _next_hit <= build_time + 0.001:
		_spawn_dust()
		_next_hit += _hammer_period
	if _time >= build_time:
		_complete()

## 망치가 땅을 친 순간 — 집 터에 흙먼지
func _spawn_dust() -> void:
	if not is_instance_valid(_house):
		return
	var map: Node = _house.get_parent()
	if map == null:
		return
	var dust = LAND_DUST.new()
	dust.color = dust_color
	map.add_child(dust)
	dust.global_position = _house.global_position + Vector2(-_dir * 18.0, 0.0)
	dust.setup(dust_power)

## 다 지었다 — 집을 열고 캐릭터를 풀어준다
func _complete() -> void:
	if is_instance_valid(_house):
		_house.finish_build()
	_house = null
	_finish()

## 끝내고(다 지었든 끊겼든) 이동 권한·행동 잠금·자세·슈퍼아머를 되돌린다
func _finish() -> void:
	_building = false
	if is_instance_valid(_house):
		_house.cancel_build()
	_house = null
	_release_armor()
	if not _has_fighter or not is_instance_valid(_fighter):
		return
	if _fighter.movement_override == self:
		_fighter.movement_override = null
	_fighter.end_busy()
	var visual: Node = _fighter.get_node_or_null("Visual")
	if visual:
		if visual.has_method("set_hammering"):
			visual.set_hammering(false)
		if visual.has_method("set_kneeling"):
			visual.set_kneeling(false)

## 슈퍼아머는 개수로 세므로 add/remove를 꼭 한 번씩 짝 맞춘다
func _release_armor() -> void:
	if not _armored:
		return
	_armored = false
	if _has_fighter and is_instance_valid(_fighter):
		_fighter.remove_super_armor()

func _physics_process(_delta: float) -> void:
	# 다른 스킬이 이동 권한을 가져갔으면(after_physics가 더는 안 불림) 짓다 만 집을 치우고 정리한다
	if _building and (not is_instance_valid(_fighter) or _fighter.movement_override != self):
		_finish()

func _exit_tree() -> void:
	_release_armor()
