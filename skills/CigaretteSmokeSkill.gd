class_name CigaretteSmokeSkill
extends Skill

## 담배 연기 뿜기 — 일진 스킬1(G). 담배를 꺼내 물고 앞으로 연기를 길게 뿜는다(화염방사기 느낌).
## 연기 안에 있는 상대는 `tick_interval`마다 조금씩 계속 맞는다.
##
## 순서: 담배를 손에 들고 입으로 올린다 -> `windup` 뒤 입에 문다(손의 담배는 치우고 **담배 문 얼굴**로 바꾼다)
## -> 연기가 `duration` 동안 나온다 -> 얼굴이 원래대로 돌아온다.
## 연기 판정·그림은 `CigaretteSmoke.tscn`이 들고 있다. Skill은 Node라 좌표가 없어서 연기는 맵에 붙인다
## (연기가 매 프레임 시전자의 입을 알아서 따라간다).

@export var smoke_scene: PackedScene
## 연기를 뿜는 시간(초)
@export var duration: float = 5.0
## 한 번 맞을 때 데미지 / 다시 맞기까지 간격(초)
@export var damage: int = 2
@export var tick_interval: float = 0.5
## 캐릭터 원점에서 입까지 — x는 바라보는 방향으로 자동 반전, y는 음수가 위쪽
@export var mouth_offset: Vector2 = Vector2(17.0, -27.0)
## 담배를 입으로 가져가는 데 걸리는 시간(초) — 이 시간이 지나야 연기가 나온다.
## 손이 아직 입에 닿지도 않았는데 연기가 뿜어지면 어색하다
@export var windup: float = 0.45
## 손에 든 담배 그림 (입에 물기 전까지만 보인다). 비어 있으면 그림 없이 연기만 나간다
@export var cigarette_path: NodePath = NodePath("Visual/HandRHold/Cigarette")
## 담배를 문 얼굴. **스킬마다 자기 얼굴을 직접 넣는다** — 리그의 액션 표정 슬롯 하나를
## 여러 스킬이 나눠 쓰기 때문에, 안 넣으면 앞서 쓴 스킬(돌진=신남)의 얼굴이 그대로 나온다
@export var smoke_face: Texture2D
## 그 얼굴의 배율 ((0,0)이면 기본 머리 배율)
@export var smoke_face_scale: Vector2 = Vector2.ZERO
## 0보다 크면 그 간격마다 입으로 가져가는 동작을 반복한다. 0이면 처음에 한 번만 올렸다 내린다
@export var puff_motion_interval: float = 0.0

func _execute(fighter: Fighter) -> void:
	if smoke_scene == null:
		return
	# 피우는 내내 기본공격·다른 스킬을 막는다(이동은 된다 — 연기를 겨눠야 하므로).
	# lock_duration 대신 여기서 거는 이유: windup·duration을 인스펙터에서 바꿔도 잠금이 저절로 따라온다
	fighter.start_busy(windup + duration)
	_set_cigarette(fighter, true)
	_play_puff_motion(fighter)
	# 입에 무는 순간: 손의 담배를 치우고(머리 그림에 담배가 들어 있다) 얼굴을 바꾼 뒤 연기를 뿜는다
	_after(windup, func() -> void:
		_set_cigarette(fighter, false)
		_set_smoke_face(fighter, true)
		_spawn_smoke(fighter))
	# 다 피우면 원래 얼굴로
	_after(windup + duration, func() -> void:
		_set_smoke_face(fighter, false)
		_set_cigarette(fighter, false))
	if puff_motion_interval > 0.0:
		_start_repeat_motion(fighter)

## 입 앞에 연기를 띄운다 — 위치·방향은 연기 쪽이 매 프레임 알아서 따라간다
func _spawn_smoke(fighter: Fighter) -> void:
	if not is_instance_valid(fighter) or smoke_scene == null:
		return
	var smoke: Node = smoke_scene.instantiate()
	fighter.get_parent().add_child(smoke)
	if smoke.has_method("setup"):
		smoke.setup(fighter, mouth_offset, fighter.compute_damage(damage), tick_interval, duration)

## 손에 든 담배를 보이거나 숨긴다
func _set_cigarette(fighter: Fighter, shown: bool) -> void:
	if cigarette_path.is_empty() or not is_instance_valid(fighter):
		return
	var cig: Node = fighter.get_node_or_null(cigarette_path)
	if cig is CanvasItem:
		cig.visible = shown

## 담배를 문 얼굴로 바꾼다 (리그의 `action_head_texture`). 그 그림이 없는 캐릭터면 그냥 넘어간다
func _set_smoke_face(fighter: Fighter, on: bool) -> void:
	if not is_instance_valid(fighter):
		return
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual == null or not visual.has_method("set_action_face"):
		return
	if on and smoke_face != null:
		visual.action_head_texture = smoke_face
		visual.action_head_scale = smoke_face_scale
	visual.set_action_face(on)

## 손을 입으로 가져가는 동작은 주정뱅이 마시기 모션을 그대로 쓴다.
## **반복을 안 할 때는 동작 길이를 windup의 네 배로 맞춘다** — 올리기 구간이 전체의 25%라
## 정확히 windup만큼 올라간 뒤 한 모금 빨고 손이 내려온다(연기는 그 뒤로도 계속 나온다)
func _play_puff_motion(fighter: Fighter) -> void:
	if not is_instance_valid(fighter):
		return
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual == null or not visual.has_method("play_drink_motion"):
		return
	if puff_motion_interval <= 0.0 and "drink_duration" in visual:
		visual.drink_duration = maxf(windup, 0.05) * 4.0
	visual.play_drink_motion()

## puff_motion_interval이 켜져 있을 때만 — 뻐끔거리는 동작을 반복하다 끝나면 멈춘다
func _start_repeat_motion(fighter: Fighter) -> void:
	var puff := Timer.new()
	puff.wait_time = puff_motion_interval
	add_child(puff)
	puff.timeout.connect(func() -> void: _play_puff_motion(fighter))
	puff.start()
	_after(windup + duration, func() -> void:
		puff.stop()
		puff.queue_free())

## 이 스킬 노드의 자식 Timer로 예약한다 (Timers.after 참고). delay가 0 이하면 그 자리에서 바로 부른다
func _after(delay: float, what: Callable) -> void:
	if delay <= 0.0:
		what.call()
		return
	Timers.after(self, delay, what)
