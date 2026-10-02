class_name ThrownRecorder
extends Hitbox

## 던진 검은 리코더 — 지하철 아저씨 쌍 악기 평타의 1타(던지기)와 3타(돌아오며 베기)를 맡는다.
##
## 흐름은 네 토막이다.
##  1. `OUT`   — 1타에 손을 떠나 **빙글빙글 돌며 앞으로 날아간다**. 여기 닿으면 1타 명중이다.
##  2. `HOVER` — 날아갈 거리를 다 가면 **곧바로 되돌아선다**(`hover_timeout` 0 = 쉬지 않음).
##  3. `BACK`  — 주인에게 돌아온다. **돌아오는 길도 때린다** — 1타에 맞고 굳어 있는 상대가
##     거의 확정으로 한 번 더 맞는 추가타다. 이건 콤보 단계가 아니라 **따로 들어가는 피해**다.
##  4. 주인 품에 닿으면 사라지고 손의 리코더가 다시 보인다 — **2타를 치기도 전에 두 악기가 다 손에 있다.**
##
## **Hitbox를 물려받는다** — damage/knockback/connected 신호를 그대로 쓰려고. 때릴지 말지는
## `monitoring`으로만 가른다(날아가는 중·돌아오는 중에만 켠다).
## 기다리는 동안 아무 일이 없으면 `hover_timeout` 뒤에 알아서 돌아온다 — 콤보가 끊겨도 영영 안 남는다

## 던질 때 앞으로 나가는 속도(px/s)와 거리(px). 거리를 다 가면 그 자리에서 기다린다
@export var throw_speed: float = 1800.0
@export var throw_distance: float = 150.0
## 돌아올 때 속도(px/s). 나갈 때보다 빨라야 3타 타이밍에 맞춰 도착한다
@export var return_speed: float = 2600.0
## 주인 몸에 이만큼 가까워지면 "받았다"로 치고 사라진다(px)
@export var catch_radius: float = 26.0
## 도는 속도(도/초). 빙글빙글 도는 맛을 내는 값이라 크게 잡는다
@export var spin_speed: float = 1080.0
## 끝까지 날아간 뒤 되돌아서기 전에 멈칫하는 시간(초). **0이면 곧바로 돌아온다**(기본).
## 2타를 치기 전에 손에 돌아와 있어야 해서 0으로 둔다 — 늘리면 그만큼 늦게 돌아온다
@export var hover_timeout: float = 0.0
## **돌아오며 때리는 피해**를 나갈 때 피해의 몇 배로 할지. 1.0이면 1타와 같은 피해가 한 번 더 들어간다.
## 넉백·띄우기는 나갈 때와 똑같다(사용자 요청: "넉백은 뭐 동일하게")
@export var return_damage_ratio: float = 1.0
## 날아가는 동안 위아래로 살짝 흔들리는 폭(px)과 빠르기 — 수평으로만 가면 자로 그은 것처럼 보인다
@export var wobble: float = 5.0
@export var wobble_speed: float = 13.0

## 지금 어느 토막인지
enum Phase { OUT, HOVER, BACK, DONE }

var _phase: int = Phase.OUT
## 던진 주인. 돌아올 목표이자, 몸 그림(리코더 다시 보이기)을 되돌릴 대상
var _owner_fighter: Fighter = null
## 이번 타를 보고하는 콤보(`ComboMeleeAttack`). 맞으면 그쪽 콤보가 이어진다
var _combo: Node = null
## 나갈 때 방향(+1 오른쪽 / -1 왼쪽)과 아직 남은 거리
var _dir: float = 1.0
var _left: float = 0.0
## 기다린 시간 — hover_timeout을 재는 데 쓴다
var _waited: float = 0.0
## 위아래 흔들림 위상
var _phase_t: float = 0.0
## 던져진 높이(y) — 흔들림은 이 높이를 기준으로 오르내린다
var _base_y: float = 0.0
## 나갈 때의 피해 — 돌아올 때 배수를 걸 기준값
var _out_damage: int = 0

func _ready() -> void:
	super()
	add_to_group("projectiles")
	connected.connect(_on_connected)
	monitoring = false
	monitorable = false

## 던진다. 던진 자리에서 dir 쪽으로 날아가며, 맞으면 combo에게 "이번 타 명중"이라고 알린다
func launch(from: Fighter, at: Vector2, dir: float, combo: Node, src: Hitbox) -> void:
	_owner_fighter = from
	_combo = combo
	_dir = signf(dir) if not is_zero_approx(dir) else 1.0
	_left = throw_distance
	_phase = Phase.OUT
	global_position = at
	_base_y = at.y
	source_fighter = from
	_copy_hit_values(src)
	_out_damage = damage
	_arm(true)

## 돌아오라고 부른다(3타). 돌아오는 동안 다시 때릴 수 있게 판정을 새로 켠다
func recall(src: Hitbox = null) -> void:
	if _phase == Phase.DONE:
		return
	_phase = Phase.BACK
	_copy_hit_values(src)
	# 돌아오는 길은 추가타다 — 나갈 때 피해에 배수를 건다(넉백·띄우기는 그대로)
	damage = maxi(int(round(float(_out_damage) * return_damage_ratio)), 1)
	# 나갈 때 맞은 상대도 돌아올 때 다시 맞아야 한다 — 지난 기록을 지운다
	clear_repeat_state()
	_arm(true)

## 지금 돌아오는 중이거나 기다리는 중인지(= 아직 손에 없다)
func is_out() -> bool:
	return _phase != Phase.DONE

## **지금 당장 손에 넣는다.** "3타를 치기 전에는 무조건 두 악기가 손에 있어야 한다"를 보장하는 장치 —
## 속도를 넉넉히 잡아 둬서 평소엔 알아서 돌아와 있고, 뭔가 늦어졌을 때만 여기로 들어온다
func catch_now() -> void:
	if _phase == Phase.DONE:
		return
	_finish()

## 그 타의 피해·넉백·띄우기를 콤보 판정 상자에서 그대로 베껴 온다.
## ⚠️ **띄우기(pop_override)까지 꼭 가져와야 한다** — 기본값(-1)은 "데미지 비례로 띄움"이라,
## 안 베끼면 1타 던지기에 맞은 상대가 공중으로 떠서 2·3·4타가 전부 허공을 친다(실측)
func _copy_hit_values(src: Hitbox) -> void:
	if src == null:
		return
	damage = src.damage
	knockback = src.knockback
	pop_override = src.pop_override

func _arm(on: bool) -> void:
	set_deferred("monitoring", on)
	set_deferred("monitorable", on)

func _physics_process(delta: float) -> void:
	_phase_t += delta
	rotation += deg_to_rad(spin_speed) * delta * _dir
	match _phase:
		Phase.OUT:
			var step: float = throw_speed * delta
			global_position.x += step * _dir
			global_position.y = _base_y + sin(_phase_t * wobble_speed) * wobble
			_left -= step
			if _left <= 0.0:
				_phase = Phase.HOVER
				_waited = 0.0
				_arm(false)
		Phase.HOVER:
			global_position.y = _base_y + sin(_phase_t * wobble_speed) * wobble
			_waited += delta
			# 멈칫하는 시간이 끝나면(기본 0 = 다음 프레임에 바로) 돌아선다
			if _waited >= hover_timeout or not is_instance_valid(_owner_fighter):
				recall()
		Phase.BACK:
			if not is_instance_valid(_owner_fighter):
				_finish()
				return
			var target: Vector2 = _owner_fighter.global_position
			var to: Vector2 = target - global_position
			if to.length() <= catch_radius:
				_finish()
				return
			global_position += to.normalized() * return_speed * delta
		Phase.DONE:
			pass

## 맞은 걸 콤보에게 알린다 — 몸 판정이 맞은 것과 똑같이 그 타가 "명중"으로 처리된다.
## 한 번 때리면 그 구간에서는 더 안 때린다(나갈 때 한 번, 돌아올 때 한 번)
func _on_connected(victim: Node) -> void:
	_arm(false)
	# **나갈 때 맞은 것만 "1타 명중"으로 보고한다.** 돌아오며 때리는 건 콤보 단계가 아니라
	# 그냥 한 대 더 들어가는 추가타라, 보고하면 2타가 두 번 열려 콤보가 꼬인다
	if _phase != Phase.OUT:
		return
	if _combo != null and is_instance_valid(_combo) and _combo.has_method("report_external_hit"):
		_combo.report_external_hit(victim)

## 주인 품에 돌아왔다 — 손에 든 리코더를 다시 보이게 하고 사라진다
func _finish() -> void:
	_phase = Phase.DONE
	_arm(false)
	_restore_hand()
	queue_free()

func _restore_hand() -> void:
	if not is_instance_valid(_owner_fighter):
		return
	var visual: Node = _owner_fighter.get_node_or_null("Visual")
	if visual and "held_item_l_thrown" in visual:
		visual.held_item_l_thrown = false

## 라운드가 끝나는 등으로 그냥 사라질 때도 손에 리코더를 돌려준다
func _exit_tree() -> void:
	if _phase != Phase.DONE:
		_restore_hand()
