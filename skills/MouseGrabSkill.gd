class_name MouseGrabSkill
extends Skill

## 유선 마우스 그랩 — 마우스를 앞으로 던져 맞은 상대를 악플러 쪽으로 끌어온다 (악플러 스킬1).
## 이 노드는 던지는 팔 동작만 시키고, 실제 동작(날아가기·잡기·끌어오기·되감기)과 그림은 MouseGrab이 처리한다.
@export var throw_speed: float = 700.0
## 마우스가 날아가는 최대 거리(px). 이 안에 상대가 없으면 빗나간 것으로 보고 되감기 시작한다
@export var max_range: float = 400.0
## 잡은 상대를 끌어오는 속도(px/초)
@export var reel_speed: float = 320.0
## 잡는 순간 주는 데미지
@export var damage: int = 4
## 날아가는 마우스 몸통의 화면상 길이(px)
@export var mouse_length: float = 30.0
## 잡힌 상대 몸에 감기는 케이블 뭉치의 화면상 폭(px)
@export var coil_width: float = 50.0
## 마우스를 손에 쥔 채 어깨 뒤로 젖히는 시간(초) — 이 시간이 지나야 마우스가 손을 떠난다
@export var throw_windup: float = 0.14
## 뿌린 손이 제자리로 돌아오는 데 걸리는 시간(초)
@export var throw_recover: float = 0.22

@export_group("포물선 / 되감기")
## 손을 떠날 때 위로 뜨는 초기 속도(px/초). 0으로 두면 예전처럼 수평으로 곧게 날아간다
@export var throw_lift: float = 260.0
## 날아가는 마우스에 걸리는 중력(px/초^2). 이 값 때문에 떴다가 떨어지는 포물선이 된다.
## 기본값 260/900은 최대 사거리(400px)에 닿는 순간 마우스가 던진 높이로 다시 내려오도록 잡은 값이다
@export var throw_gravity: float = 900.0
## 최대 비행 시간(초). 사거리보다 이쪽이 먼저 끝나면 그 자리에서 되감기 시작한다
@export var flight_time: float = 0.75
## 빗나간 마우스가 손으로 되감기는 속도(px/초). 던지는 속도보다 빨라야 질질 끌리지 않는다
@export var return_speed: float = 900.0

func _execute(fighter: Fighter) -> void:
	# 팔 동작과 마우스가 같은 시점에 손을 떠나도록 젖히는 시간을 양쪽에 똑같이 넘긴다
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("play_cast_motion"):
		visual.play_cast_motion(throw_windup, throw_recover)
	var grab := MouseGrab.new()
	# 크기·젖히는 시간은 setup()이 그림을 만들기 전에 대입해야 반영된다
	grab.mouse_length = mouse_length
	grab.coil_width = coil_width
	grab.windup_time = throw_windup
	grab.throw_lift = throw_lift
	grab.throw_gravity = throw_gravity
	grab.flight_time = flight_time
	grab.return_speed = return_speed
	fighter.get_parent().add_child(grab)
	grab.setup(fighter, throw_speed, max_range, reel_speed, damage)
