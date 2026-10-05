class_name WorkoutSkill
extends Skill

## **헬스장 맵 전용 스킬 — 운동하기**(기획서 21쪽, 2026-10-02).
##
## 기구 앞에서 **맵 키(P1 `E` / P2 `[`)** 를 누르면 운동을 시작하고, 다시 누르면 그만둔다.
## 운동하는 동안 그 기구가 맡은 능력(`GymMachine.stat_property`)이 조금씩 오른다.
##
## **"운동할지 방해할지 고르게 만드는 맵"이라 운동 중엔 발이 묶인다** — 그게 이 맵이 거는 판돈이다.
## 기획서대로 **맞으면 멈추지만 그때까지 쌓인 스펙은 남는다**(스펙은 쌓는 족족 배수로 반영하므로
## 따로 "확정" 단계가 없다 — 끊겨도 이미 올라 있다).
##
## `Stage.map_skill_scene`에 이 씬을 꽂으면 두 선수 모두에게 자동으로 붙는다 —
## 캐릭터 씬은 전혀 안 건드린다(공사현장 내리찍기와 같은 구조).

## 쌓인 스펙을 적어 두는 곳 — `Fighter.custom_data[SPEC_BAG]`에 {기구이름: 스펙} 으로 쌓인다.
## **라운드가 끝나면 맵이 통째로 다시 열리므로 스펙도 라운드마다 초기화된다**
const SPEC_BAG := "gym_spec"
## 배수를 걸 때 쓰는 이름표 앞머리. 기구 종류마다 따로 걸려서 서로 안 지운다
const MODIFIER_PREFIX := "gym_"

## 기구가 모여 있는 그룹 이름(`GymMachine`이 스스로 들어간다)
const MACHINE_GROUP := "gym_machine"

## 운동을 시작·중단할 때의 쿨타임(초). 너무 짧으면 키 한 번에 켜졌다 꺼진다
@export var toggle_cooldown: float = 0.25
## 몸이 제일 많이 부풀 때의 배율(1.0이면 안 변한다). 기획서 "강화된 부위가 변해 한눈에 보임"
@export var muscle_gain: float = 0.45
## 몸이 꽉 부푸는 기준 스펙 — 기구의 `spec_max`와 맞춰 두면 다 채웠을 때 최대가 된다
@export var muscle_full_spec: float = 6.0
## 운동하는 동안 몸이 위아래로 들썩이는 폭(px)과 빠르기 — 가만히 서 있으면 운동으로 안 보인다
@export var bob_amount: float = 5.0
@export var bob_speed: float = 7.0

@export_group("AI")
## 상대가 이만큼 떨어져 있을 때만 AI가 운동한다 — 코앞에서 운동하면 그냥 맞는다
@export var ai_safe_distance: float = 420.0

## 지금 쓰고 있는 기구(없으면 운동 중이 아니다)
var _machine: GymMachine = null
## 운동 중인 캐릭터
var _fighter: Fighter = null
## 들썩임에 쓰는 시계
var _bob: float = 0.0
## 몸 그림의 원래 y — 들썩이게 흔들었다가 되돌릴 때 쓴다
var _visual_home_y: float = 0.0

func _process(delta: float) -> void:
	super._process(delta)
	if _machine == null:
		return
	if not is_instance_valid(_fighter) or not is_instance_valid(_machine):
		_stop()
		return
	# 발이 땅에서 떨어졌거나(점프), 맞아서 굳었거나, 기구에서 멀어지면 운동이 끊긴다
	if not _fighter.is_on_floor() or _fighter.is_in_hitstun() or not _machine.in_range(_fighter.global_position):
		_stop()
		return
	# **아무 키나 누르면 그 자리에서 끊긴다**(2026-10-05 사용자 규칙).
	# ⚠️ `move_input`을 보면 안 된다 — 운동 중엔 `movement_override` 때문에 컨트롤러가
	# 이동·점프 입력을 **아예 안 읽어서** 그 값이 그대로 멈춰 있다. 그래서 키를 직접 본다
	if _wants_break():
		_stop()
		return
	var key: String = _machine.spec_key()
	var spec: float = minf(_get_spec(key) + _machine.spec_per_second * delta, _machine.spec_max)
	_set_spec(key, spec)
	_apply_spec(_machine, spec)
	_machine.set_gauge(spec / maxf(_machine.spec_max, 0.001))
	# 바벨 컬은 자세가 직접 움직이므로 들썩임을 겹치면 두 번 흔들린다
	if not _is_curl() and not _is_squat() and not _is_run():
		_bob += delta * bob_speed
		_apply_bob(sin(_bob) * bob_amount)
	# 다 채웠으면 알아서 손을 턴다 — 더 해도 안 오르는데 발만 묶여 있으면 손해다
	if spec >= _machine.spec_max:
		_stop()

## 맵 키를 누를 때마다 불린다 — 운동 중이면 그만두고, 아니면 가까운 기구에서 시작한다
func _execute(fighter: Fighter) -> void:
	if _machine != null:
		_stop()
		return
	var machine: GymMachine = _find_machine(fighter)
	if machine == null:
		# 기구가 없는데 눌렀을 뿐이다 — 쿨타임까지 날리면 억울하다
		cooldown_left = 0.0
		return
	if fighter.movement_override != null:
		cooldown_left = 0.0
		return
	_fighter = fighter
	_machine = machine
	_bob = 0.0
	# 기구를 보고 선다(등지고 운동하면 이상하다). 정확히 겹쳐 있으면 보던 쪽 그대로.
	# **기구가 방향을 정해 뒀으면 그쪽이 이긴다** — 런닝머신은 조작판을 보고 달려야 한다
	if not is_zero_approx(machine.face_dir):
		fighter.facing = signf(machine.face_dir)
	else:
		var dx: float = machine.global_position.x - fighter.global_position.x
		if absf(dx) > 4.0:
			fighter.facing = signf(dx)
	# **발을 묶는다** — 이게 이 맵의 판돈이다
	fighter.movement_override = self
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual:
		_visual_home_y = visual.position.y
	if not fighter.damaged.is_connected(_on_interrupted):
		fighter.damaged.connect(_on_interrupted)
	# 때리기 시작하면 운동은 그만둔 것으로 친다(운동과 공격 중 하나를 고르는 맵이다)
	if not fighter.basic_attack_used.is_connected(_on_attacked):
		fighter.basic_attack_used.connect(_on_attacked)
	machine.set_gauge(_get_spec(machine.spec_key()) / maxf(machine.spec_max, 0.001))
	_set_curl_pose(true)
	_set_squat_pose(true)
	_set_run_pose(true)
	_set_workout_flag(true)

func effective_cooldown() -> float:
	return toggle_cooldown

## 운동을 끝낸다(스스로 그만두든, 맞아서 끊기든 거쳐 가는 한 곳)
func _stop() -> void:
	_set_curl_pose(false)
	_set_squat_pose(false)
	_set_run_pose(false)
	_set_workout_flag(false)
	if _machine != null and is_instance_valid(_machine):
		_machine.set_gauge(-1.0)
	_machine = null
	if is_instance_valid(_fighter):
		if _fighter.movement_override == self:
			_fighter.movement_override = null
		if _fighter.damaged.is_connected(_on_interrupted):
			_fighter.damaged.disconnect(_on_interrupted)
		if _fighter.basic_attack_used.is_connected(_on_attacked):
			_fighter.basic_attack_used.disconnect(_on_attacked)
		_apply_bob(0.0)
	_fighter = null

func _on_interrupted(_amount: int, _knockback: Vector2) -> void:
	_stop()

func _on_attacked() -> void:
	_stop()

## **운동 중이라고 리그에 알려 준다** — 기구 종류와 상관없이 켠다.
## 리그는 이걸 보고 idle 몸짓(뒤돌아보기·머리 긁기)을 쉰다
func _set_workout_flag(on: bool) -> void:
	if not is_instance_valid(_fighter):
		return
	var visual: Node = _fighter.get_node_or_null("Visual")
	if visual and visual.has_method("set_workout"):
		visual.set_workout(on)

## 지금 쓰는 기구가 **런닝머신**인지
func _is_run() -> bool:
	return _machine != null and is_instance_valid(_machine) and _machine.kind == GymMachine.Kind.TREADMILL

## 달리기 자세를 켜고 끈다. 리그에 그 손잡이가 없으면 조용히 넘어간다
func _set_run_pose(on: bool) -> void:
	if on and not _is_run():
		return
	if not is_instance_valid(_fighter):
		return
	var visual: Node = _fighter.get_node_or_null("Visual")
	if visual and visual.has_method("set_run"):
		visual.set_run(on)

## 지금 쓰는 기구가 **스쿼트 랙**인지
func _is_squat() -> bool:
	return _machine != null and is_instance_valid(_machine) and _machine.kind == GymMachine.Kind.SQUAT

## 스쿼트 자세를 켜고 끈다. 리그에 그 손잡이가 없으면 조용히 넘어간다
func _set_squat_pose(on: bool) -> void:
	if on and not _is_squat():
		return
	if not is_instance_valid(_fighter):
		return
	var visual: Node = _fighter.get_node_or_null("Visual")
	if visual and visual.has_method("set_squat"):
		visual.set_squat(on)

## 지금 쓰는 기구가 **바벨 컬**인지 — 컬만 전용 자세가 있다
func _is_curl() -> bool:
	return _machine != null and is_instance_valid(_machine) and _machine.kind == GymMachine.Kind.CURL

## 바벨 컬 자세를 켜고 끈다. 리그에 그 손잡이가 없으면 조용히 넘어간다(다른 캐릭터 리그에 안전하게)
func _set_curl_pose(on: bool) -> void:
	if on and not _is_curl():
		return
	if not is_instance_valid(_fighter):
		return
	var visual: Node = _fighter.get_node_or_null("Visual")
	if visual and visual.has_method("set_curl"):
		visual.set_curl(on)

## 이 중 하나라도 눌려 있으면 운동을 그만둔다 — 맵 전용 키는 빼 둔다(그건 _execute가 토글로 받는다)
const BREAK_ACTIONS: Array[String] = ["left", "right", "jump", "down",
	"basic_attack", "skill_1", "skill_2", "ultimate"]

## 이 캐릭터를 조작하는 사람이 몇 번인지(1/2). 컴퓨터가 잡고 있으면 0
func _player_index() -> int:
	if not is_instance_valid(_fighter):
		return 0
	for child in _fighter.get_children():
		if "player_index" in child:
			return int(child.player_index)
	return 0

## 지금 조작 키가 눌려 있는지 — 컴퓨터가 쓰는 중이면 늘 false다
func _wants_break() -> bool:
	var index: int = _player_index()
	if index <= 0:
		return false
	for name in BREAK_ACTIONS:
		var action: String = "p%d_%s" % [index, name]
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			return true
	return false

## 지금 운동 중인지 — 다른 연출이 물어볼 수 있게 열어 둔다
func is_working_out() -> bool:
	return _machine != null

## 쓸 수 있는 기구 중 **제일 가까운 것**. 없으면 null
func _find_machine(fighter: Fighter) -> GymMachine:
	var best: GymMachine = null
	var best_d: float = INF
	for node in get_tree().get_nodes_in_group(MACHINE_GROUP):
		var machine := node as GymMachine
		if machine == null or not machine.in_range(fighter.global_position):
			continue
		var d: float = fighter.global_position.distance_squared_to(machine.global_position)
		if d < best_d:
			best_d = d
			best = machine
	return best

## --- 스펙 ---

func _get_spec(key: String) -> float:
	if not is_instance_valid(_fighter):
		return 0.0
	return float(_fighter.custom_data.get(SPEC_BAG, {}).get(key, 0.0))

func _set_spec(key: String, value: float) -> void:
	if not is_instance_valid(_fighter):
		return
	var bag: Dictionary = _fighter.custom_data.get(SPEC_BAG, {})
	bag[key] = value
	_fighter.custom_data[SPEC_BAG] = bag

## 쌓인 스펙을 실제 능력치 배수로 건다. **쌓는 즉시 거는 게 핵심이다** —
## 그래야 운동이 끊겨도 "그때까지 쌓인 건 남는다"가 저절로 성립한다
func _apply_spec(machine: GymMachine, spec: float) -> void:
	_fighter.set_modifier(machine.stat_property(), MODIFIER_PREFIX + machine.spec_key(),
		1.0 + spec * machine.gain_per_spec)
	_apply_muscle()

## 쌓인 스펙만큼 몸을 부풀린다 — 팔은 바벨 컬, 다리는 스쿼트·런닝머신이 키운다.
## 리그에 그 손잡이가 없으면 조용히 넘어간다(다른 캐릭터 리그에도 안전하게)
func _apply_muscle() -> void:
	var visual: Node = _fighter.get_node_or_null("Visual")
	if visual == null:
		return
	var full: float = maxf(muscle_full_spec, 0.001)
	if "muscle_arm" in visual:
		visual.muscle_arm = 1.0 + clampf(_get_spec("curl") / full, 0.0, 1.0) * muscle_gain
	if "muscle_leg" in visual:
		var leg: float = (_get_spec("squat") + _get_spec("treadmill")) / (full * 2.0)
		visual.muscle_leg = 1.0 + clampf(leg, 0.0, 1.0) * muscle_gain

## 운동하는 들썩임 — 몸 그림만 위아래로 흔든다(판정은 그대로다)
func _apply_bob(offset: float) -> void:
	if not is_instance_valid(_fighter):
		return
	var visual: Node2D = _fighter.get_node_or_null("Visual")
	if visual:
		visual.position.y = _visual_home_y + offset

## --- 이동 가로채기(`Fighter.movement_override` 인터페이스) ---

## 운동하는 동안은 제자리다
func get_move_velocity_x() -> float:
	return 0.0

func after_physics(_fighter: Fighter, _delta: float) -> void:
	pass

## --- AI ---

## `AIController`가 물어본다 — 지금 운동할 만한지.
## ⚠️ AI는 **기구를 찾아가지는 않는다**. 마침 기구 옆에 서 있을 때만 운동한다
func ai_wants_use(fighter: Fighter, target: Node) -> bool:
	if _machine != null or not fighter.is_on_floor():
		return false
	if is_instance_valid(target) and target is Node2D:
		if fighter.global_position.distance_to((target as Node2D).global_position) < ai_safe_distance:
			return false
	var machine: GymMachine = _find_machine(fighter)
	if machine == null:
		return false
	return _get_spec(machine.spec_key()) < machine.spec_max

func _exit_tree() -> void:
	_stop()
