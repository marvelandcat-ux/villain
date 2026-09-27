class_name MouseGrabSkill
extends Skill

## 유선 마우스 그랩 — 마우스를 앞으로 던져 맞은 상대를 악플러 쪽으로 끌어온다 (악플러 스킬1).
## 이 노드는 던지는 팔 동작만 시키고, 실제 동작(날아가기·잡기·끌어오기)과 그림은 MouseGrab이 처리한다.
## 던진 마우스가 날아가는 속도(px/초). 2026-09-27 사용자 요청으로 500 -> 800(1.6배).
## **바꾸면 throw_gravity도 속도 배수의 제곱만큼 같이 바꿔야 사거리가 그대로다**(떨어지는 동안 가로로 가는 거리가 속도에 비례)
@export var throw_speed: float = 800.0
## 마우스가 날아가는 최대 거리(px). 이 안에 상대가 없으면 빗나가 사라진다
@export var max_range: float = 680.0
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
## 날아가는 마우스가 아래로 처지기 시작하는 지점 — 사거리의 몇 %를 지났을 때인지.
## 0.5면 "절반 지점부터" 중력을 받는다. 1이면 끝까지 곧게 날아간다(예전 동작)
@export_range(0.0, 1.0, 0.05) var throw_drop_after: float = 0.62
## 처지기 시작한 뒤 받는 중력(px/초²). 클수록 무겁게 뚝 떨어진다.
## **손 높이가 지면에서 27px뿐이라 이 값이 곧 실효 사거리를 정한다** — 처지기 시작한 뒤
## 27px 떨어지는 데 걸리는 시간만큼만 더 날아가고 거기서 끝나기 때문이다(속도 800·중력 2304면 약 0.15초 = 122px).
## 사거리를 늘리려면 이 값을 낮추거나 throw_drop_after를 올릴 것.
## 속도 1.6배 때 사거리를 유지하려고 900 x 1.6² = 2304(처지는 곡선 모양도 예전과 같다)
@export var throw_gravity: float = 2304.0
## 떨어지다 지면·발판에 닿으면 거기서 사라질지. 끄면 사거리를 다 채울 때까지 땅속으로 들어간다.
## 켜두면 평지 실효 사거리가 약 544px이 되고(max_range 680은 점프해서 던졌을 때의 상한),
## 점프해서 던지면 손이 높아진 만큼 더 멀리 간다
@export var throw_stop_on_ground: bool = true
## 빗나간 뒤 유선에 딸려 손으로 되감기는 속도(px/초). 0에 가까우면 하염없이 끌려온다
@export var throw_return_speed: float = 1280.0
## 마우스가 상대 중심에서 이만큼 안에 들어오면 "잡았다"고 본다(px).
## 상대 몸(캡슐 20x60)보다 좁으니 너무 줄이면 스치기만 하고 안 잡힌다
@export var catch_radius: float = 30.0

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
	grab.drop_after = throw_drop_after
	grab.gravity = throw_gravity
	grab.stop_on_ground = throw_stop_on_ground
	grab.return_speed = throw_return_speed
	grab.catch_radius = catch_radius
	fighter.get_parent().add_child(grab)
	grab.setup(fighter, throw_speed, max_range, reel_speed, damage)
