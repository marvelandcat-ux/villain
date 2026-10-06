extends Node

## **평타 마무리 = 아이 드롭킥.** 층간소음 빌런 기본공격(`BasicAttack`)의 **자식**으로 달아 두면,
## 콤보가 그 타를 휘두를 때 알려 주고 여기서 아이를 날린다.
##
## 아이는 앞으로 쭉 날아가 발길질하고 **왔던 길 그대로** 돌아온다 —
## 실제 움직임은 몸(`BodyRig.play_kid_dropkick`)이 그린다. 판정은 평소 콤보 히트박스를 그대로 쓴다.
##
## 2번 스킬로 아이를 내려놓은 동안에는 품에 아이가 없어서 아무 일도 안 일어난다(엄마 발차기만 나간다)

## 몇 번째 타에서 날릴지 — 0이 1타다(기본 3타 콤보라 2 = 마무리)
@export var kick_step: int = 2
## 아이가 나갔다 돌아오는 시간(초). 0이면 몸에 적어 둔 `kid_kick_time`을 쓴다
@export var duration: float = 0.0

@export_group("느리게")
## **뛰어올라 최고점에 닿을 때까지는 평소 속도**로 두고, 그 뒤 앞으로 날아가는 구간만 느려진다.
## 차기 시작하고 몇 초 뒤부터 느려질지(게임 시간) — 리그의 `Kid Kick Rise`와 같이 보고 맞춘다
@export var slow_delay: float = 0.13
## 느려지는 정도(1이면 안 느려짐)와 그 길이(초, **실제 시간**이라 느려져도 그대로 흐른다)
@export var slow_scale: float = 0.55
@export var slow_time: float = 0.28

@export_group("카메라")
## **차는 동안 아이 쪽으로 화면을 살짝 당긴다.** 1이면 안 당긴다
@export var camera_zoom: float = 1.25
## 당겼다 돌아오는 데 걸리는 시간(초)
@export var camera_time: float = 0.55

## 느려짐을 건 횟수 — 겹쳐 걸렸을 때 **마지막 것만** 배속을 되돌리게 하는 표식
var _slow_token: int = 0

func on_combo_swing(fighter: Fighter, step: int) -> void:
	if step != kick_step or not is_instance_valid(fighter):
		return
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual == null or not visual.has_method("play_kid_dropkick"):
		return
	visual.play_kid_dropkick(duration)
	if slow_scale >= 0.999 or slow_time <= 0.0:
		_zoom_to_kid(fighter, visual)
		return
	# 솟아오르는 동안은 그대로 두고, 앞으로 뻗는 순간부터 느려지며 화면이 당겨진다
	# 스킬 자식 Timer로 기다린다 — 그 사이 라운드가 끝나 캐릭터가 지워져도 타이머째 사라져 에러가 안 난다
	Timers.after(self, maxf(slow_delay, 0.01), func(): _start_slow(fighter, visual))

## 느리게 + 클로즈업을 같이 건다
func _start_slow(fighter: Fighter, visual: Node) -> void:
	if not is_instance_valid(fighter) or not is_instance_valid(visual):
		return
	_zoom_to_kid(fighter, visual)
	_slow_token += 1
	var token: int = _slow_token
	Engine.time_scale = slow_scale
	# ⚠️ 되돌리는 타이머는 **배속을 무시**해야 한다 — 느려진 시간으로 재면 복구도 같이 느려져 안 돌아온다
	var back: SceneTreeTimer = fighter.get_tree().create_timer(slow_time, true, false, true)
	back.timeout.connect(func():
		if token == _slow_token:
			Engine.time_scale = 1.0)

## 라운드가 끝나거나 캐릭터가 사라져도 배속은 반드시 되돌린다
func _exit_tree() -> void:
	_slow_token += 1
	if not is_equal_approx(Engine.time_scale, 1.0):
		Engine.time_scale = 1.0

## 아이 머리를 따라가며 화면을 조금 당긴다 — 훈련장처럼 그 기능이 없는 카메라면 그냥 넘어간다
func _zoom_to_kid(fighter: Fighter, visual: Node) -> void:
	if camera_zoom <= 1.001 or camera_time <= 0.0:
		return
	var cam: Camera2D = fighter.get_viewport().get_camera_2d()
	if cam == null or not cam.has_method("focus_on"):
		return
	var at: Node2D = fighter
	if visual.has_method("kid_head_node"):
		var kid: Node2D = visual.kid_head_node()
		if kid != null:
			at = kid
	cam.focus_on(at, camera_zoom, camera_time)
