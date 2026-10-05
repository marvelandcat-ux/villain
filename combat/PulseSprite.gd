@tool
extends Sprite2D

## **헬스장 단계 표시 그림 하나** — 손·발에 붙는 핏줄(💢, 울끈불끈)과 금빛 단계의 다이아몬드 반짝이.
## - 울끈불끈: 두 번 쿵쿵 부풀었다가 잠깐 쉰다(심장 뛰듯)
## - 반짝: 0에서 커졌다가 다시 사라지며 살짝 돈다
## 핏줄·반짝이마다 박자를 엇갈려(랜덤 시작점) 다 같이 움직이지 않게 한다.
##
## **에디터에선 가만히 있는다** — 편집 씬에서 끌어 맞출 때 크기가 계속 바뀌면 그 값이 저장돼 버린다.
## 리그를 전혀 모른다(대시 잔상이 복제해도 혼자 움직이다 같이 사라진다)

@export_enum("울끈불끈", "반짝") var mode: int = 0
## 초당 몇 번 뛰는지(울끈불끈)·반짝이는지
@export var speed: float = 1.4
## 울끈불끈 부푸는 정도(0.25 = 25% 커짐)
@export var amount: float = 0.28
## 반짝이 한 번에 도는 각도(도)
@export var twinkle_turn_deg: float = 25.0

var _rest_scale: Vector2 = Vector2.ONE
var _rest_rotation: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	_rest_scale = scale
	_rest_rotation = rotation
	_time = randf() * 10.0

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	var p: float = fposmod(_time * speed, 1.0)
	if mode == 0:
		# 앞 40% 동안 두 번 쿵쿵, 나머지는 쉰다
		var beat: float = 0.0
		if p < 0.4:
			beat = pow(absf(sin(p / 0.4 * TAU)), 2.0)
		scale = _rest_scale * (1.0 + amount * beat)
	else:
		# 앞 60% 동안 0 -> 1 -> 0, 나머지는 안 보인다
		var t: float = clampf(p / 0.6, 0.0, 1.0)
		var s: float = sin(t * PI)
		scale = _rest_scale * s * s
		rotation = _rest_rotation + deg_to_rad(twinkle_turn_deg) * (t - 0.5)
