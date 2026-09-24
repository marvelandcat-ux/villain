class_name StunStars
extends Node2D

## 기절한 캐릭터 머리 위에서 별이 빙글빙글 도는 연출.
## `기절효과1.png`/`기절효과2.png` 두 장을 번갈아 보여주는 2프레임 플립북이다 —
## 두 그림이 같은 캔버스(1882x836)에 그려져 있고 타원 고리 위치도 거의 같아서,
## 같은 region으로 잘라 놓으면 별만 반대편으로 튀어 "돌고 있다"로 읽힌다.
##
## 캐릭터의 자식으로 붙이지 않고 **맵에 붙여서 매 프레임 머리 위치를 따라간다**(`Crown`과 같은 방식).
## 자식으로 붙이면 캐릭터가 좌우를 볼 때 `scale.x = -1`로 뒤집히면서 같이 뒤집히고,
## 캐릭터가 사라질 때 연출도 같이 잘려나간다

const SCENE_PATH := "res://combat/StunStars.tscn"

## 두 그림에서 실제로 그려진 부분(알파 bbox)의 **합집합**. 1번은 x 272~1690 / y 58~616,
## 2번은 x 234~1648 / y 112~637이라 각자 잘라내면 프레임마다 그림이 좌우로 튄다 —
## 합집합으로 똑같이 잘라야 타원 고리가 제자리에 머물고 **별만** 반대편으로 넘어간다
const REGION := Rect2(234, 58, 1457, 580)

## 캐릭터 원점(발밑)에서 별 고리까지의 거리. 왕관이 -70이라 그보다 조금 더 위에 둔다
@export var head_offset: Vector2 = Vector2(0.0, -76.0)
## 두 프레임을 바꾸는 간격(초). 짧을수록 빨리 도는 것처럼 보인다
@export var frame_interval: float = 0.11
## 고리가 위아래로 살짝 흔들리는 폭(px). 0이면 안 흔들린다
@export var bob_amplitude: float = 2.5
## 흔들리는 속도(초당 사이클)
@export var bob_speed: float = 3.0
## 사라지기 직전 이만큼(초) 동안 서서히 투명해진다
@export var fade_out_time: float = 0.15

## 따라다닐 대상. `spawn()`이 채워준다
var target: Fighter

## 남은 표시 시간. 0 이하가 되면 스스로 사라진다
var _life: float = 0.0
var _frame_timer: float = 0.0
var _frame: int = 0
var _elapsed: float = 0.0

@onready var _stars: Sprite2D = $Stars
## 0번 프레임은 씬에 붙어 있고, 1번 프레임만 여기서 불러와 번갈아 끼운다
@onready var _frame_a: Texture2D = _stars.texture
@onready var _frame_b: Texture2D = load("res://sprite/맵/놀이터/기절효과2.png")

func _ready() -> void:
	# 자르는 영역은 이 스크립트가 기준이다 — 씨에도 같은 값이 박혀 있지만,
	# 둘이 어긋나면 별이 프레임마다 좌우로 튀므로 여기서 한 번 더 맞춰둔다
	_stars.region_rect = REGION

## 기절한 캐릭터 머리 위에 별을 띄운다. 이미 떠 있으면 시간만 늘려준다 —
## 연타로 맞을 때마다 새로 생기면 같은 자리에 여러 장이 겹쳐서 진하게 보인다
static func spawn(fighter: Fighter, duration: float) -> StunStars:
	if fighter == null or not is_instance_valid(fighter) or duration <= 0.0:
		return null
	# 슈퍼아머 중이면 경직이 안 걸리므로 별도 띄우지 않는다 — 멀쩡히 움직이는데 머리 위에 별이 돌면 헷갈린다
	if fighter.has_super_armor():
		return null
	var parent: Node = fighter.get_parent()
	if parent == null:
		return null
	for node in parent.get_children():
		if node is StunStars and node.target == fighter:
			node.extend(duration)
			return node
	var stars: StunStars = load(SCENE_PATH).instantiate()
	stars.target = fighter
	stars._life = duration
	parent.add_child(stars)
	# add_child()가 _ready()를 그 자리에서 돌리므로, 첫 프레임에 (0,0)에 한 번 번쩍이지 않도록
	# 여기서 미리 머리 위로 옮겨둔다
	stars.global_position = fighter.global_position + stars.head_offset
	return stars

## 이미 떠 있는 별의 시간을 늘린다(남은 시간보다 짧으면 무시)
func extend(duration: float) -> void:
	_life = maxf(_life, duration)
	modulate.a = 1.0

func _process(delta: float) -> void:
	# 대상이 사라졌으면(라운드 리셋·링아웃) 연출도 같이 정리한다
	if not is_instance_valid(target):
		queue_free()
		return

	_life -= delta
	if _life <= 0.0:
		queue_free()
		return

	_elapsed += delta
	global_position = target.global_position + head_offset + Vector2(0.0, sin(_elapsed * bob_speed * TAU) * bob_amplitude)

	_frame_timer += delta
	if _frame_timer >= frame_interval:
		_frame_timer -= frame_interval
		_frame = 1 - _frame
		_stars.texture = _frame_b if _frame == 1 else _frame_a

	if fade_out_time > 0.0 and _life < fade_out_time:
		modulate.a = _life / fade_out_time
