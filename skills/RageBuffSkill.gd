class_name RageBuffSkill
extends Skill

## 열등감 느끼기 — 사용하면 duration 동안 기본공격(콤보 매 타) 데미지가 bonus_damage만큼 오른다. (악플러 스킬2)
## 기획 문서에 발동 조건이 미정이었던 오픈 이슈를 액티브 사용식으로 임의 확정한 것
##
## 예전에는 기본공격 쿨타임을 0.3초로 고정하는 버프였는데, 악플러 원래 쿨이 이미 0.3초라
## 헛칠 때 말고는 체감이 없어서 2026-10-01 사용자 요청으로 평타 데미지 +2로 바꿨다
## 버프가 도는 동안엔 분노한 표정(action_head_texture) + 붉은 색조. 맞아도 색조는 유지된다(Fighter._flash_hit).
## 시간이 다 되면 되돌리는데, **씬이 통째로 사라져도 콜백이 남지 않도록 자식 Timer 노드를 쓴다**
## (get_tree().create_timer는 SceneTree에 속해서 이 노드보다 오래 살아남아 "Lambda capture was freed" 에러가 난다)
@export var duration: float = 6.0
## 버프 동안 기본공격 한 타마다 더해지는 데미지 (캐릭터 공격 배율·왕관 버프는 그 뒤에 곱해진다)
@export var bonus_damage: int = 2
## 발동하는 순간 머리를 부들부들 떠는 시간(초). 0이면 안 떤다.
## **버프가 도는 내내 떨게 하려면 여기에 `duration`(6초)과 같은 값을 넣으면 된다** —
## 지금은 "쓰는 순간 열받아서 부르르"만 보여주는 짧은 연출이다.
## 떨리는 세기·빠르기는 리그 쪽(`BodyRig`의 `head_shake_*`)에서 조절한다
@export var head_shake_time: float = 0.7

## 버프를 되돌릴 타이머 — 이 노드의 자식이라 캐릭터가 사라지면 같이 사라진다
var _timer: Timer

func _execute(fighter: Fighter) -> void:
	if fighter.basic_attack and "bonus_damage" in fighter.basic_attack:
		fighter.basic_attack.bonus_damage = bonus_damage
	# 열받아서 씩씩거리는 동안 붉으락푸르락한 오라 + 분노한 표정
	fighter.set_tint("rage", Color(1.0, 0.55, 0.35), duration)
	# 공격력이 오른 동안 빨간 칼 아이콘이 몸 근처에서 떠오른다(끄는 건 _end_rage)
	fighter.show_status_vfx(&"attack_up")
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("set_action_face"):
		visual.set_action_face(true)
	# 열받아서 머리가 부들부들 (그 기능이 없는 비주얼이면 그냥 넘어간다)
	if visual and visual.has_method("play_head_shake"):
		visual.play_head_shake(head_shake_time)
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

## 데미지 보너스와 분노 표정을 원래대로 돌린다 (색조는 set_tint의 duration이 알아서 걷는다)
func _end_rage() -> void:
	var fighter := get_parent() as Fighter
	if fighter == null:
		return
	if fighter.basic_attack and "bonus_damage" in fighter.basic_attack:
		fighter.basic_attack.bonus_damage = 0
	fighter.hide_status_vfx(&"attack_up")
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("set_action_face"):
		visual.set_action_face(false)
