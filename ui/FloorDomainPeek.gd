extends CanvasLayer

## **영역전개 연출 2장 — 문 열고 빼꼼.** 1장(현관문 두드리기) 바로 뒤에 나온다.
##
## 문이 열린 채로 시작해서 **엄마와 아이가 문 뒤에서 옆으로 밀려 나오고**,
## 말풍선으로 한마디 한다. 말하는 동안 엄마 얼굴이 **입 벌린 그림 ↔ 다문 그림**으로 번갈아 바뀐다.
##
## 쌓는 순서가 중요하다: **문틀 → 엄마·아이 → 문짝**. 그래야 엄마가 문짝 뒤에서 나오는 것처럼 보인다.
##
## 자리는 전부 씬에서 끌어 맞춘다: `DoorFrame`/`DoorPanel`(문틀·문짝), `Mom`, `Kid`, `Bubble`.
## 씬만 따로 열어도(F6) 바로 재생된다

signal finished

## 엄마가 할 말
@export var line: String = "애가 시끄러울 수도 있죠!"
## **숨어 있을 때 어디에 있는지** — 씬에 잡아 둔 자리에서 이만큼 떨어진 곳에서 출발한다.
## 문짝 쪽(왼쪽)으로 밀어 두면 문 뒤에 가려져 있다가 옆으로 나온다
@export var peek_offset: Vector2 = Vector2(-90, 0)
## 빼꼼 나오는 데 걸리는 시간(초)과, 나온 뒤 말하기까지 쉬는 시간(초)
@export var peek_time: float = 0.3
@export var talk_delay: float = 0.18
## **아이가 있을 때만** 쓰는 값 — 말을 시작하고 이만큼 지나서 빼꼼 나온다(초).
## 지금 씬에는 아이를 안 쓰기로 해서 `Kid` 노드가 없다. 노드가 없으면 전부 조용히 건너뛴다
@export var kid_delay: float = 1.0
@export var kid_peek_time: float = 0.3
## 말하는 시간(초) — 이 동안 입이 여닫힌다
@export var talk_time: float = 1.5
## 입을 여닫는 간격(초)
@export var mouth_rate: float = 0.11
## 말 끝나고 다음 장면으로 넘어가기 전에 머무는 시간(초)
@export var hold_after: float = 0.8

@export_group("얼굴")
## 입 벌린 그림과 다문 그림. 둘 다 있어야 입이 움직인다
@export var mouth_open: Texture2D
@export var mouth_shut: Texture2D
## 아이 **평소 얼굴**과 **씩 웃는 얼굴**. 아이는 나오면서 웃는 얼굴로 바뀐다
@export var kid_face: Texture2D
@export var kid_smile: Texture2D
## 아이가 **키득거리며 머리를 위아래로 흔드는** 폭(px)과 빠르기, 흔드는 시간(초).
## 0초면 장면이 끝날 때까지 계속 흔든다
@export var kid_bob: float = 7.0
@export var kid_bob_speed: float = 13.0
@export var kid_bob_time: float = 0.0

@export_group("문 흔들림")
## 말하는 동안 문이 울리는 폭(px)과 간격(초).
## **문이 열린 장면에서는 안 흔드는 게 자연스러워서 0으로 꺼 뒀다**(2026-10-04 사용자 판단).
## 다시 쓰고 싶으면 9 정도를 넣으면 된다
@export var door_shake: float = 0.0
@export var door_shake_rate: float = 0.42
## 한 번 울릴 때 문이 떨리는 시간(초)
@export var door_shake_time: float = 0.22
## 같이 흔들리는 화면 폭(px). 0이면 문만 흔들린다
@export var screen_shake: float = 0.0

@export_group("화면")
## 씬에 잡아 둔 자리·크기가 이 화면 높이 기준이라고 친다 — 창이 더 크면 통째로 확대한다
@export var design_height: float = 720.0
## 벽지를 화면에 꽉 채울지
@export var cover_screen: bool = true
## 화면을 덮은 벽지를 **이만큼 더 키운다**(1이면 딱 맞게만). 세 장면 모두 같은 값을 쓴다
@export var wall_zoom: float = 1.2
## 이 장면만 따로 띄웠을 때(F6) 바로 재생할지
@export var autoplay_when_alone: bool = true

@onready var _root: Node2D = $Root
@onready var _wall: Sprite2D = $Root/Wallpaper
@onready var _mom: Node2D = $Root/Mom
## 아이는 쓸 수도 안 쓸 수도 있다(지금 씬에는 없다)
@onready var _kid: Node2D = get_node_or_null("Root/Kid")
@onready var _head: Sprite2D = $Root/Mom/Head
@onready var _bubble: Node2D = $Root/Bubble
@onready var _kid_head: Sprite2D = get_node_or_null("Root/Kid/Head")
## 흔들 문 두 장(문틀·문짝)
@onready var _door_frame: Node2D = get_node_or_null("Root/DoorFrame")
@onready var _door_panel: Node2D = get_node_or_null("Root/DoorPanel")

## 아이 머리 제자리와, 키득거리는 시계
var _kid_head_home: Vector2
var _kid_bob_left: float = 0.0
var _kid_bob_t: float = 0.0
## 문 제자리와, 다음 쾅까지 남은 시간
var _door_home: Vector2
var _door_left: float = 0.0

## 씬에 잡아 둔 제자리(빼꼼 다 나왔을 때)
var _mom_home: Vector2
var _kid_home: Vector2
## 말하는 동안 입이 여닫히게 하는 시계
var _talk_left: float = 0.0
var _mouth_left: float = 0.0
var _mouth_is_open: bool = false
var _playing: bool = false

func _ready() -> void:
	_mom_home = _mom.position
	_kid_home = _kid.position if _kid else Vector2.ZERO
	_kid_head_home = _kid_head.position if _kid_head else Vector2.ZERO
	_door_home = _door_frame.position if _door_frame else Vector2.ZERO
	_fit_screen()
	get_viewport().size_changed.connect(_fit_screen)
	if _bubble:
		_bubble.visible = false
	# 아이는 나올 때까지 아예 안 보인다 — 문 뒤에 걸쳐서 살짝 비치면 "숨어 있다"가 안 된다
	if _kid:
		_kid.visible = false
	if _kid_head and kid_face:
		_kid_head.texture = kid_face
	_set_mouth(false)
	if autoplay_when_alone and get_parent() == get_tree().root:
		play()

## 화면 가운데에 맞추고, 창이 기준 높이보다 크면 통째로 확대한다
func _fit_screen() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var zoom: float = maxf(view.y / maxf(design_height, 1.0), 0.01)
	if _root:
		_root.position = view * 0.5
		_root.scale = Vector2(zoom, zoom)
	if cover_screen and _wall and _wall.texture:
		var tex: Vector2 = _wall.texture.get_size()
		var k: float = maxf(view.x / tex.x, view.y / tex.y) / zoom * maxf(wall_zoom, 0.1)
		_wall.scale = Vector2(k, k)

func play() -> void:
	if _playing:
		return
	_playing = true
	# 문 뒤에 숨은 자리에서 출발한다
	_mom.position = _mom_home + peek_offset
	if _kid:
		_kid.position = _kid_home + peek_offset
	var tw := create_tween()
	# 엄마가 먼저 나온다 — 아이는 말을 시작한 뒤에 따로 나온다
	tw.tween_property(_mom, "position", _mom_home, maxf(peek_time, 0.01)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(talk_delay, 0.0))
	tw.tween_callback(_start_talk)
	tw.tween_interval(maxf(talk_time, 0.1) + maxf(hold_after, 0.0))
	tw.tween_callback(_done)

## 말풍선을 띄우고 입을 움직이기 시작한다
func _start_talk() -> void:
	if _bubble:
		_bubble.visible = true
		if _bubble.has_method("say"):
			_bubble.say(line)
	_talk_left = maxf(talk_time, 0.1)
	_mouth_left = 0.0
	# 말하는 동안 문이 쾅쾅 울린다
	_door_left = 0.0
	if _kid == null:
		return
	# 말하고 조금 지나서 아이가 고개를 내민다 — 나오는 순간에야 보이기 시작한다
	var kt := create_tween()
	kt.tween_interval(maxf(kid_delay, 0.0))
	# **웃는 얼굴로 나온다** — 보이기 전에 얼굴을 바꿔 두고 켠다
	kt.tween_callback(_kid_grin)
	kt.tween_property(_kid, "position", _kid_home, maxf(kid_peek_time, 0.01)) 		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	_update_kid_bob(delta)
	_update_door(delta)
	if _talk_left <= 0.0:
		return
	_talk_left -= delta
	_mouth_left -= delta
	if _mouth_left <= 0.0:
		_mouth_left = maxf(mouth_rate, 0.02)
		_set_mouth(not _mouth_is_open)
	if _talk_left <= 0.0:
		_set_mouth(false)   # 말이 끝나면 입을 다문다

## 말하는 동안 문을 주기적으로 쾅 울린다 — 한 번 울리면 door_shake_time 동안 떨다가 잦아든다
func _update_door(delta: float) -> void:
	if _talk_left <= 0.0:
		return
	_door_left -= delta
	if _door_left <= 0.0:
		_door_left = maxf(door_shake_rate, 0.05)
		_bang()

## 문 한 번 쾅 — 문 두 장을 같이 떨고 화면도 같이 흔든다
func _bang() -> void:
	if door_shake > 0.0:
		_shake_node(_door_frame, _door_home)
		_shake_node(_door_panel, _door_home)
	if screen_shake > 0.0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var tw := create_tween()
		for i in range(3):
			var amount: float = screen_shake * (1.0 - float(i) / 3.0)
			tw.tween_property(self, "offset",
				Vector2(rng.randf_range(-amount, amount), rng.randf_range(-amount, amount)),
				maxf(door_shake_time / 3.0, 0.01))
		tw.tween_property(self, "offset", Vector2.ZERO, 0.05)

## 노드 하나를 제자리 둘레로 몇 번 떨었다가 되돌린다
func _shake_node(node: Node2D, home: Vector2) -> void:
	if node == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var tw := create_tween()
	for i in range(3):
		var amount: float = door_shake * (1.0 - float(i) / 3.0)
		tw.tween_property(node, "position",
			home + Vector2(rng.randf_range(-amount, amount), rng.randf_range(-amount * 0.5, amount * 0.5)),
			maxf(door_shake_time / 3.0, 0.01))
	tw.tween_property(node, "position", home, 0.05)

## 아이가 웃는 얼굴로 바뀌며 나타나고, 그때부터 머리를 키득키득 흔든다
func _kid_grin() -> void:
	if _kid_head and kid_smile:
		_kid_head.texture = kid_smile
	if _kid:
		_kid.visible = true
	_kid_bob_t = 0.0
	_kid_bob_left = kid_bob_time if kid_bob_time > 0.0 else 9999.0

## 키득거리는 머리 — 위로 톡톡 튀는 모양이라 sin의 절댓값을 쓴다(아래로는 안 내려간다)
func _update_kid_bob(delta: float) -> void:
	if _kid_bob_left <= 0.0 or _kid_head == null:
		return
	_kid_bob_left -= delta
	_kid_bob_t += delta
	if _kid_bob_left <= 0.0:
		_kid_head.position = _kid_head_home
		return
	_kid_head.position.y = _kid_head_home.y - absf(sin(_kid_bob_t * kid_bob_speed)) * kid_bob

## 입 벌린 얼굴 ↔ 다문 얼굴. 그림을 둘 다 안 넣어 두면 아무 일도 안 한다
func _set_mouth(open: bool) -> void:
	_mouth_is_open = open
	if _head == null:
		return
	var tex: Texture2D = mouth_open if open else mouth_shut
	if tex != null:
		_head.texture = tex

func _done() -> void:
	_playing = false
	finished.emit()
