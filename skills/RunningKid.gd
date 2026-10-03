class_name RunningKid
extends Hitbox

## 내려놓은 **아이**. 층간소음 빌런 2번 스킬(`KidRushSkill`)이 바닥에 놓으면
## 앞으로 **쿵쿵 뛰어갔다가** 돌아와 엄마 품으로 들어간다.
##
## 흐름은 세 토막이다.
##  1. `OUT`    — 앞으로 달려간다. 한 걸음씩 폴짝 뛰며 **발이 땅에 닿을 때마다 쿵** 한다(화면이 울린다).
##  2. `TURN`   — 갈 거리를 다 가면 잠깐 멈춰 돌아선다.
##  3. `BACK`   — 엄마에게 돌아온다. 품에 닿으면 사라지고 엄마가 다시 안는다.
##
## **Hitbox를 물려받는다** — 달리는 동안 닿는 상대를 밀어낸다. 발이 땅에 닿는 순간에만 때리는 게 아니라
## 몸에 닿으면 바로다(네 살짜리가 들이받는 그림).
## 벽에 막히면 그 자리에서 돌아선다 — 맵 밖으로 나가 영영 안 돌아오는 걸 막는다

## 달려 나가는 속도(px/s)와 거리(px)
@export var run_speed: float = 420.0
@export var run_distance: float = 260.0
## 돌아오는 속도(px/s). 나갈 때보다 빨라야 기다리는 맛이 덜 늘어진다
@export var return_speed: float = 520.0
## 끝까지 가서 돌아서기 전에 멈칫하는 시간(초)
@export var turn_pause: float = 0.18
## **처음 서 있던 자리**에 이만큼 가까워지면 "돌아왔다"로 치고 사라진다(px)
@export var catch_radius: float = 30.0
## 아무 일이 없어도 이 시간이 지나면 무조건 돌아선다(초) — 벽에 끼는 걸 막는 안전장치
@export var out_timeout: float = 2.0

@export_group("자세 씬")
## **달릴 때 자세를 씬 파일로 잡는다.** 세 장이다 —
##  `ready_pose`  : 내려놓은 직후 **준비** 자세(달리기 시작 전)
##  `peak_pose`   : 폴짝 떠서 **가장 높이** 올라갔을 때
##  `land_pose`   : 발이 **땅에 닿은** 순간
## 달리는 동안 땅 → 꼭대기 → 땅을 오가며 두 장 사이를 이어 간다.
## 비워 두면 씬에 저장된 자세 그대로 뻣뻣하게 간다
@export var ready_pose: PackedScene = null
@export var peak_pose: PackedScene = null
@export var land_pose: PackedScene = null
## 내려놓고 **준비 자세로 서 있는 시간**(초). 이 시간이 지나면 달리기 시작한다
@export var ready_time: float = 0.22

@export_group("박수 시작")
## 엄마가 박수를 치기 시작하는 지점 — 아이가 **엄마를 이만큼 지나쳤을 때**(px).
## 0이면 엄마 몸 한가운데를 지나는 순간, 음수면 지나기 전에 미리, 양수면 좀 더 간 뒤에 친다
@export var clap_pass_offset: float = 0.0

@export_group("착지 충격파")
## 발이 땅에 닿을 때마다 **발밑 주변으로 퍼지는 충격파**가 때린다. 띄울 장면(`StompWave.tscn`)
@export var wave_scene: PackedScene
## 때리는 범위(px). 충격파 그림의 `max_radius`와 같게 맞춰 준다 — 보이는 대로 맞아야 억울하지 않다
@export var wave_radius: float = 110.0
## 충격파 피해와 밀어내는 힘. x는 **아이에게서 멀어지는 쪽**으로 자동으로 갈린다.
## ⚠️ **y는 0에 가깝게 둔다.** 위로 띄우면 상대가 충격파 범위 밖으로 날아가서
## 다음 걸음부터 안 맞는다 — "쿵쿵쿵 → 데미지데미지데미지"가 안 된다(실측)
@export var wave_damage: int = 5
@export var wave_knockback: Vector2 = Vector2(85, 0)
## 켜면 충격파에 맞아도 **땅에서 안 뜬다**(기본). 끄면 데미지에 비례해 붕 뜬다 —
## 뜨면 범위를 벗어나므로 연타가 끊긴다
@export var wave_keeps_grounded: bool = true
## 같은 상대를 다시 때리기까지 기다리는 시간(초). **0이면 디딜 때마다 매번 들어간다**(기본).
## 0보다 키우면 그 시간 안에는 한 번만 맞는다 — 너무 많이 들어간다 싶으면 올리면 된다
@export var wave_cooldown: float = 0.0
## 충격파가 생기는 높이를 **발바닥에서** 더 내리거나 올리는 값(px, 양수면 아래로).
## 자리는 아이 발 조각에서 자동으로 찾는다 — 이 값은 미세 조정용이다
@export var wave_foot_offset: float = 2.0

@export_group("쿵쿵 걸음")
## 한 걸음(폴짝 뛰었다 착지)에 걸리는 시간(초). 짧을수록 다다다 뛴다
@export var step_time: float = 0.22
## 뛰어오르는 높이(px)
@export var hop_height: float = 16.0
## 발이 닿을 때마다 화면이 울리는 세기(0이면 안 울린다)
@export var stomp_shake: float = 0.16
## 발이 닿을 때마다 좌우로 몸이 기우는 각도(도)
@export var waddle_deg: float = 7.0

## 지금 어느 토막인지
enum Phase { OUT, TURN, BACK, DONE }

var _phase: int = Phase.OUT
## 내려놓은 엄마. 돌아올 목표이자, 품에 다시 안기게 할 대상
var _mom: Fighter = null
## 나갈 때 방향(+1 오른쪽 / -1 왼쪽)과 남은 거리
var _dir: float = 1.0
var _left: float = 0.0
## **처음 서 있던 자리**를 엄마 기준으로 적어 둔 것(x는 보던 방향 기준).
## 엄마가 돌아서도 아이는 여전히 자기 자리(뒤쪽이면 뒤쪽)로 돌아온다
var _home_local: Vector2 = Vector2.ZERO
## 걸음 위상(0~1이 한 걸음)과 지금까지 디딘 걸음 수
var _step_phase: float = 0.0
var _steps: int = 0
## 땅 높이 — 폴짝 뛰어도 이 높이로 돌아온다
var _ground_y: float = 0.0
## 토막별로 흐른 시간
var _time: float = 0.0
## 엄마가 박수를 치기 시작했는지 — 한 번만 켜려고 들고 있는다
var _clap_started: bool = false
## 충격파로 마지막에 때린 시각 {Fighter: 초} — 같은 상대를 연속으로 못 때리게 막는다
var _wave_last: Dictionary = {}

func _ready() -> void:
	super()
	add_to_group("projectiles")
	monitoring = false
	monitorable = false

## 바닥에 내려놓는다. dir 쪽으로 달려갔다가 mom에게 돌아온다
func drop(mom: Fighter, at: Vector2, dir: float, damage_value: int, knock: Vector2) -> void:
	_mom = mom
	_dir = signf(dir) if not is_zero_approx(dir) else 1.0
	_left = run_distance
	_phase = Phase.OUT
	_time = 0.0
	_step_phase = 0.0
	_steps = 0
	global_position = at
	_ground_y = at.y
	# 떠난 자리를 엄마 기준으로 적어 둔다 — 돌아올 목표다
	var face: float = signf(mom.facing) if not is_zero_approx(mom.facing) else 1.0
	_home_local = Vector2((at.x - mom.global_position.x) * face, at.y - mom.global_position.y)
	source_fighter = mom
	damage = damage_value
	knockback = knock
	scale.x = absf(scale.x) * _dir   # 가는 쪽을 보게 뒤집는다
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)

## 아직 밖에 나가 있는지(= 엄마 품에 없다)
func is_out() -> bool:
	return _phase != Phase.DONE

## 지금 당장 엄마 품으로 들여보낸다 — 라운드가 끝나는 등으로 정리가 필요할 때
func catch_now() -> void:
	if _phase == Phase.DONE:
		return
	_finish()

func _physics_process(delta: float) -> void:
	_time += delta
	_apply_kid_pose()
	match _phase:
		Phase.OUT:
			# 내려놓고 잠깐은 준비 자세로 서 있는다
			if _time < ready_time:
				global_position.y = _ground_y
				return
			_walk(delta, _dir, run_speed)
			_check_clap_start()
			_left -= run_speed * delta
			if _left <= 0.0 or _time >= out_timeout or _blocked():
				_phase = Phase.TURN
				_time = 0.0
		Phase.TURN:
			global_position.y = _ground_y
			rotation = 0.0
			if _time >= turn_pause:
				_phase = Phase.BACK
				_time = 0.0
				_dir = -_dir
				scale.x = absf(scale.x) * _dir
				# 돌아오는 길에도 다시 부딪힐 수 있게 지난 기록을 지운다
				clear_repeat_state()
		Phase.BACK:
			if not is_instance_valid(_mom):
				_finish()
				return
			var to: Vector2 = _home_world() - global_position
			if to.length() <= catch_radius:
				_finish()
				return
			_walk(delta, signf(to.x), return_speed)
		Phase.DONE:
			pass

## 지금 토막·걸음 위상에 맞는 자세를 입힌다.
## 준비 시간 동안은 `ready_pose` 그대로, 그 뒤로는 **땅(land) ↔ 꼭대기(peak)** 를 오간다 —
## 한 걸음(0~1)에서 가운데(0.5)가 가장 높이 뜬 지점이다
func _apply_kid_pose() -> void:
	if _phase == Phase.DONE:
		return
	if _phase == Phase.OUT and _time < ready_time and ready_pose != null:
		_put_pose(ready_pose, 1.0)
		return
	if land_pose == null and peak_pose == null:
		return
	var high: float = sin(PI * clampf(_step_phase, 0.0, 1.0))
	if land_pose != null:
		_put_pose(land_pose, 1.0)
		if peak_pose != null:
			_put_pose(peak_pose, high)
	else:
		_put_pose(peak_pose, high)

## 자세 씬 하나를 weight만큼 섞는다. 1이면 그 자세 그대로, 0이면 안 건드린다.
## 조각은 **이름으로** 찾는다(KidHead / KidBody / KidFootL / KidFootR / KidHandL / KidHandR)
func _put_pose(scene: PackedScene, weight: float) -> void:
	if scene == null or weight <= 0.0:
		return
	var pose: Dictionary = BodyRig.read_pose(scene)
	for part_name in pose:
		var part := find_child(part_name, true, false) as Node2D
		if part == null:
			continue
		var data: Array = pose[part_name]
		part.position = part.position.lerp(data[0] as Vector2, weight)
		part.rotation = lerp_angle(part.rotation, data[1] as float, weight)

## 처음 서 있던 자리를 지금 월드 좌표로 바꿔 준다 — 엄마가 움직이고 돌아서도 따라온다
func _home_world() -> Vector2:
	if not is_instance_valid(_mom):
		return global_position
	var face: float = signf(_mom.facing) if not is_zero_approx(_mom.facing) else 1.0
	return _mom.global_position + Vector2(_home_local.x * face, _home_local.y)

## **아이가 엄마 몸을 지나가는 순간** 박수를 시작한다.
## 첫 착지보다 조금 이르다 — 아이가 엄마 앞을 스쳐 나가는 그 박자가 자연스럽다(2026-10-04 사용자 요청)
func _check_clap_start() -> void:
	if _clap_started or not is_instance_valid(_mom):
		return
	if (global_position.x - _mom.global_position.x) * _dir >= clap_pass_offset:
		_start_clap()

func _start_clap() -> void:
	_clap_started = true
	_set_mom_clapping(true)

## 엄마에게 박수를 치라고(또는 그만 치라고) 알린다. 그 기능이 없는 몸이면 조용히 넘어간다
func _set_mom_clapping(on: bool) -> void:
	if not is_instance_valid(_mom):
		return
	var visual: Node = _mom.get_node_or_null("Visual")
	if visual and visual.has_method("set_clapping"):
		visual.set_clapping(on)

## 벽에 막혔는지 — 맵 밖으로 나가지 않게 한 칸 앞을 두드려 본다.
##
## ⚠️ **캐릭터들은 빼고 본다.** 안 빼면 엄마 몸과 상대 몸이 바로 앞에 있어서 내려놓자마자
## "막혔다"가 되어 한 발짝도 못 가고 돌아선다(실측: 피해 0). 막는 건 벽·바닥뿐이다
func _blocked() -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position, global_position + Vector2(_dir * 26.0, 0.0))
	query.collide_with_areas = false
	var skip: Array[RID] = []
	for f in get_tree().get_nodes_in_group("fighters"):
		if f is CollisionObject2D:
			skip.append((f as CollisionObject2D).get_rid())
	query.exclude = skip
	var hit: Dictionary = space.intersect_ray(query)
	return not hit.is_empty()

## 한 걸음 — 폴짝 떴다가 착지하고, 착지하는 순간 쿵 한다
func _walk(delta: float, dir: float, speed: float) -> void:
	global_position.x += dir * speed * delta
	_step_phase += delta / maxf(step_time, 0.01)
	if _step_phase >= 1.0:
		_step_phase -= 1.0
		_steps += 1
		_stomp()
	# 0 → 1 → 0으로 떴다 내려온다
	var hop: float = sin(PI * _step_phase)
	global_position.y = _ground_y - hop_height * hop
	# 한 걸음마다 좌우로 뒤뚱거린다
	var side: float = 1.0 if _steps % 2 == 0 else -1.0
	rotation = deg_to_rad(waddle_deg) * side * hop

## 발이 땅에 닿는 순간 — 화면을 울리고 **충격파가 퍼지며 주변을 때린다**
func _stomp() -> void:
	# 혹시 엄마를 지나치지 못한 채 두 걸음을 걸었으면(앞쪽에서 출발한 경우 등) 여기서라도 시작한다
	if not _clap_started and _steps >= 2:
		_start_clap()
	if stomp_shake > 0.0:
		var camera: Camera2D = get_viewport().get_camera_2d() if is_inside_tree() else null
		if camera and camera.has_method("add_trauma"):
			camera.add_trauma(stomp_shake)
	# 영역전개(궁극기) 안에서는 **바닥을 타고 퍼지는 고리 대신 아래층으로 내려꽂는 부채꼴**이 된다 —
	# 윗집에서 쿵쿵거리는 소리가 아랫집으로 내려가는 게 이 궁의 전부라서다(2026-10-04 사용자 설계)
	var domain: Node = _domain()
	if domain:
		domain.kid_stomp(Vector2(global_position.x, _foot_y()))
		return
	_spawn_wave()
	_wave_hit()

## 엄마가 지금 영역전개 중이면 그 궁극기 노드를 돌려준다(아니면 null)
func _domain() -> Node:
	if not is_instance_valid(_mom):
		return null
	var ult: Node = _mom.get_node_or_null("SkillUltimate")
	if ult and ult.has_method("kid_stomp") and ult.has_method("is_active") and ult.is_active():
		return ult
	return null

## 발밑에 충격파 그림을 띄운다. 발 높이(_ground_y)에 놓아야 바닥을 타고 퍼지는 것처럼 보인다
func _spawn_wave() -> void:
	if wave_scene == null:
		return
	var parent: Node = get_parent()
	if parent == null:
		return
	var wave := wave_scene.instantiate() as Node2D
	if wave == null:
		return
	parent.add_child(wave)
	wave.global_position = Vector2(global_position.x, _foot_y())
	# 그려지는 고리를 때리는 범위에 맞춘다
	if "max_radius" in wave:
		wave.max_radius = wave_radius

## **발바닥 높이**를 월드 좌표로 돌려준다. 충격파는 몸통이 아니라 여기서 퍼져야 바닥을 친 것처럼 보인다.
## 아이 발 조각을 찾아 그 아래쪽을 쓰고, 못 찾으면 뿌리 높이(`_ground_y`)로 돌아간다
func _foot_y() -> float:
	var lowest: float = -INF
	for foot_name in ["KidFootL", "KidFootR"]:
		var foot := find_child(foot_name, true, false) as Sprite2D
		if foot == null:
			continue
		# 발 그림의 아래쪽 끝 — 조각 자리에서 그림 높이의 절반만큼 더 내려간다
		var half: float = 0.0
		if foot.texture:
			half = float(foot.texture.get_height()) * 0.5 * absf(foot.global_scale.y)
		lowest = maxf(lowest, foot.global_position.y + half)
	if lowest == -INF:
		return _ground_y + wave_foot_offset
	return lowest + wave_foot_offset

## 충격파 범위 안의 상대를 때린다. **엄마는 안 때린다**(자기 아이니까).
## 같은 상대는 wave_cooldown 동안 다시 안 맞는다 — 걸음마다 쌓여서 순식간에 녹는 걸 막는다
func _wave_hit() -> void:
	if wave_damage <= 0 or not is_inside_tree():
		return
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	for other in get_tree().get_nodes_in_group("fighters"):
		if other == _mom or not (other is Fighter) or not is_instance_valid(other):
			continue
		var target: Fighter = other
		if absf(target.global_position.x - global_position.x) > wave_radius:
			continue
		if absf(target.global_position.y - _foot_y()) > wave_radius:
			continue
		if _wave_last.get(target, -99.0) + wave_cooldown > now:
			continue
		_wave_last[target] = now
		var dir: float = signf(target.global_position.x - global_position.x)
		if is_zero_approx(dir):
			dir = 1.0
		var damage_value: int = wave_damage
		if is_instance_valid(_mom):
			damage_value = _mom.compute_damage(wave_damage)
		# 세 번째 값이 **띄우는 힘**이다. 0이면 지상 유지, -1이면 데미지 비례로 붕 뜬다
		var pop: float = 0.0 if wave_keeps_grounded else -1.0
		target.take_damage(damage_value, Vector2(wave_knockback.x * dir, wave_knockback.y), pop)

## 엄마 품으로 돌아갔다 — 품에 다시 안기게 하고 사라진다
func _finish() -> void:
	_phase = Phase.DONE
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	_restore_carry()
	queue_free()

func _restore_carry() -> void:
	if not is_instance_valid(_mom):
		return
	var visual: Node = _mom.get_node_or_null("Visual")
	if visual and "carrying" in visual:
		visual.carrying = true
	# 아이가 돌아왔으니 박수도 그만 — 웃는 얼굴도 같이 원래대로 돌아간다
	_set_mom_clapping(false)

## 라운드가 끝나는 등으로 그냥 사라질 때도 엄마가 다시 안은 걸로 되돌린다
func _exit_tree() -> void:
	if _phase != Phase.DONE:
		_restore_carry()
