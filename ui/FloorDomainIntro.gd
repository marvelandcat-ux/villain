extends CanvasLayer

## **영역전개 연출 1장 — 현관문 두드리기.** 층간소음 빌런 궁극기를 쓰면 제일 먼저 나온다.
##
## 복도 벽지 앞 현관문이 뜨고, 오른쪽 아래에서 **손이 날아와 문을 두드린다** —
## 닿는 순간 손이 눌렸다가(작아졌다) 튕기고(커졌다) 화면이 울린다. `knock_count`번 반복한다.
##
## 자리는 전부 **씬에서 끌어 맞춘다**: `Door`(문), `HandStart`(손이 출발하는 자리),
## `HandKnock`(두드리는 자리). 화면 가운데가 (0,0)이라 창 크기가 달라도 가운데가 안 틀어진다.
##
## 씬만 따로 열어도(F6) 바로 재생된다 — 맞춰 놓고 눈으로 확인하라고 넣어 뒀다

signal finished

## 손이 출발해서 문에 닿기까지(초)
@export var travel_time: float = 0.3
## 몇 번 두드릴지
@export var knock_count: int = 2
## 두드릴 때 손이 **눌리는 크기**와 **튕기는 크기**(1이 원래 크기)
@export var knock_press_scale: float = 0.76
@export var knock_pop_scale: float = 1.18
## 눌리는 시간 / 튕기는 시간 / 다음 두드리기까지 쉬는 시간(초)
@export var knock_press_time: float = 0.06
@export var knock_pop_time: float = 0.1
@export var knock_gap: float = 0.09
## 다 두드리고 다음 장면으로 넘어가기 전에 머무는 시간(초)
@export var hold_after: float = 0.3
## 두드릴 때 화면이 흔들리는 폭(px)과 가라앉는 시간(초)
@export var shake: float = 7.0
@export var shake_time: float = 0.16
## 두드릴 때 **문도 같이 흔들린다** — 폭(px). 2장(문 열고 말할 때)보다 약하게 둔다.
## 0이면 문은 가만히 있고 화면만 흔들린다
@export var door_shake: float = 4.0
## 벽지를 화면에 꽉 채울지(끄면 씬에 잡아 둔 크기 그대로)
@export var cover_screen: bool = true
## 화면을 덮은 벽지를 **이만큼 더 키운다**(1이면 딱 맞게만). 세 장면 모두 같은 값을 쓴다
@export var wall_zoom: float = 1.2
## 씬에 잡아 둔 자리·크기가 **이 화면 높이**를 기준으로 그려졌다고 친다.
## 실제 창이 더 크면 그만큼 통째로 확대한다 — 그래야 울트라와이드에서도 문 크기가 같다
@export var design_height: float = 720.0
## 이 장면만 따로 띄웠을 때(F6) 바로 재생할지
@export var autoplay_when_alone: bool = true

@onready var _hand: Node2D = $Root/Hand
@onready var _start: Node2D = $Root/HandStart
@onready var _knock: Node2D = $Root/HandKnock
@onready var _wall: Sprite2D = $Root/Wallpaper
@onready var _root: Node2D = $Root
@onready var _door: Node2D = get_node_or_null("Root/Door")

## 손의 원래 크기(씬에 잡아 둔 값)
var _hand_scale: Vector2 = Vector2.ONE
## 문 제자리(흔든 뒤 돌아올 자리)
var _door_home: Vector2
var _playing: bool = false

func _ready() -> void:
	_hand_scale = _hand.scale if _hand else Vector2.ONE
	_door_home = _door.position if _door else Vector2.ZERO
	_fit_screen()
	get_viewport().size_changed.connect(_fit_screen)
	if _hand:
		_hand.visible = false
	if autoplay_when_alone and get_parent() == get_tree().root:
		play()

## 화면 가운데에 맞추고 벽지를 화면에 꽉 채운다 — 창 비율이 달라도 가운데가 안 틀어진다
func _fit_screen() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	# 기준 높이보다 큰 창이면 통째로 키운다 — 씬에서 잡은 자리는 그대로 두고 배율만 바뀐다
	var zoom: float = maxf(view.y / maxf(design_height, 1.0), 0.01)
	if _root:
		_root.position = view * 0.5
		_root.scale = Vector2(zoom, zoom)
	if cover_screen and _wall and _wall.texture:
		var tex: Vector2 = _wall.texture.get_size()
		# 통째로 커진 만큼 나눠 준다 — 벽지는 화면을 딱 덮기만 하면 된다
		var k: float = maxf(view.x / tex.x, view.y / tex.y) / zoom * maxf(wall_zoom, 0.1)
		_wall.scale = Vector2(k, k)

## 연출을 재생한다. 다 끝나면 `finished`가 난다
func play() -> void:
	if _playing or _hand == null:
		return
	_playing = true
	_hand.visible = true
	_hand.position = _start.position if _start else Vector2.ZERO
	_hand.scale = _hand_scale
	var aim: Vector2 = _knock.position if _knock else Vector2.ZERO
	var tw := create_tween()
	# 손이 날아온다 — 끝에서 느려지며 문 앞에 선다
	tw.tween_property(_hand, "position", aim, maxf(travel_time, 0.01)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in range(maxi(knock_count, 1)):
		# 두드리는 순간 — 눌렸다가(작게) 튕긴다(크게)
		tw.tween_callback(_knock_hit)
		tw.tween_property(_hand, "scale", _hand_scale * knock_press_scale, maxf(knock_press_time, 0.01)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_hand, "scale", _hand_scale * knock_pop_scale, maxf(knock_pop_time, 0.01)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_hand, "scale", _hand_scale, maxf(knock_pop_time, 0.01))
		if i < knock_count - 1:
			tw.tween_interval(maxf(knock_gap, 0.0))
	tw.tween_interval(maxf(hold_after, 0.0))
	tw.tween_callback(_done)

## 두드린 순간 화면을 흔든다 — 카메라가 아니라 이 층(CanvasLayer)만 흔들어서
## 맵이 뒤에서 뭘 하든 상관없이 똑같이 울린다
func _knock_hit() -> void:
	_shake_door()
	if shake <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var tw := create_tween()
	var steps: int = 4
	for i in range(steps):
		var amount: float = shake * (1.0 - float(i) / float(steps))
		var to := Vector2(rng.randf_range(-amount, amount), rng.randf_range(-amount, amount))
		tw.tween_property(self, "offset", to, maxf(shake_time / float(steps), 0.01))
	tw.tween_property(self, "offset", Vector2.ZERO, maxf(shake_time * 0.3, 0.01))

## 두드린 문이 제자리에서 잠깐 덜컹인다
func _shake_door() -> void:
	if _door == null or door_shake <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var tw := create_tween()
	for i in range(3):
		var amount: float = door_shake * (1.0 - float(i) / 3.0)
		tw.tween_property(_door, "position",
			_door_home + Vector2(rng.randf_range(-amount, amount), rng.randf_range(-amount * 0.5, amount * 0.5)),
			maxf(shake_time / 3.0, 0.01))
	tw.tween_property(_door, "position", _door_home, 0.05)

func _done() -> void:
	_playing = false
	finished.emit()
