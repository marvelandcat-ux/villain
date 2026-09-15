class_name RageBuffSkill
extends Skill

## 열등감 느끼기 — 사용하면 duration 동안 기본공격 쿨타임이 basic_attack_cooldown으로 **고정**된다.
## 기획 문서에 발동 조건이 미정이었던 오픈 이슈를 액티브 사용식으로 임의 확정한 것 (악플러 스킬2)
##
## 예전에는 attack_speed_multiplier(쿨타임이 1.5배 빨리 도는 배수) 방식이었는데,
## "쿨 0.3초"처럼 결과값을 딱 정하고 싶어서 절대값 덮어쓰기(Skill.cooldown_override)로 바꿨다.
## 배수도 그대로 남겨뒀지만 기본값이 1.0이라 꺼져 있다 — 둘을 같이 켜면 0.3초보다 더 빨라진다
## 버프가 도는 동안엔 분노한 표정(action_head_texture)으로 얼굴이 바뀐다.
## 시간이 다 되면 되돌리는데, **씬이 통째로 사라져도 콜백이 남지 않도록 자식 Timer 노드를 쓴다**
## (get_tree().create_timer는 SceneTree에 속해서 이 노드보다 오래 살아남아 "Lambda capture was freed" 에러가 난다)
@export var duration: float = 6.0
## 버프가 도는 동안 기본공격 쿨타임을 이 값(초)으로 묶는다. 헛쳤을 때의 miss_cooldown도 같이 이 값이 된다
@export var basic_attack_cooldown: float = 0.3
## 기본공격 쿨타임이 도는 속도 배수. 1.0이면 안 걸린다(지금은 위의 절대값 방식만 쓴다)
@export var attack_speed_multiplier: float = 1.0

## 버프를 되돌릴 타이머 — 이 노드의 자식이라 캐릭터가 사라지면 같이 사라진다
var _timer: Timer

func _execute(fighter: Fighter) -> void:
	if attack_speed_multiplier != 1.0:
		fighter.apply_temp_multiplier("attack_speed_multiplier", attack_speed_multiplier, duration)
	# 기본공격 쿨타임을 고정값으로 덮어쓴다. 이미 돌고 있던 쿨도 그 값으로 줄여줘야
	# 스킬을 누른 직후부터 바로 빨라진 게 느껴진다
	if fighter.basic_attack:
		fighter.basic_attack.cooldown_override = basic_attack_cooldown
		fighter.basic_attack.cooldown_left = minf(fighter.basic_attack.cooldown_left, fighter.basic_attack.effective_cooldown())
	# 열받아서 씩씩거리는 동안 붉으락푸르락한 오라 + 분노한 표정
	fighter.set_tint("rage", Color(1.0, 0.55, 0.35), duration)
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("set_action_face"):
		visual.set_action_face(true)
	# **몸을 부풀렸다 줄이는 연출은 뺐다(2026-09-10).** BodyRig는 좌우 반전을 scale.x 부호로
	# 하는데, 트윈이 scale을 양수 (1.12, 1.12)로 끌고 가면서 왼쪽을 보던 캐릭터가 0을 지나
	# 오른쪽으로 뒤집혔다("열등감 쓰면 자꾸 오른쪽 돌아본다"). 리그가 매 프레임 부호를
	# 되돌리려 해서 서로 싸우기까지 했다. 크기를 건드리려면 트윈 대신 리그 쪽에
	# 부호를 지키는 전용 연출을 만들 것
	_start_timer()

## duration 뒤에 버프를 되돌린다. 다시 쓰면 타이머를 새로 시작해 시간이 연장된다
func _start_timer() -> void:
	if _timer == null:
		_timer = Timer.new()
		_timer.one_shot = true
		add_child(_timer)
		_timer.timeout.connect(_end_rage)
	_timer.start(duration)

## 쿨타임 덮어쓰기와 분노 표정을 원래대로 돌린다
func _end_rage() -> void:
	var fighter := get_parent() as Fighter
	if fighter == null:
		return
	if fighter.basic_attack:
		fighter.basic_attack.cooldown_override = 0.0
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("set_action_face"):
		visual.set_action_face(false)
