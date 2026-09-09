class_name CrownCutIn
extends CanvasLayer

## "놀이터의 왕" 연출 — 왕관에 먼저 닿은 쪽의 얼굴이 뜨고, 머리 위 왕관이 천천히 내려와 안착한다.
##
## 화면 전체를 덮는다. 궁극기 컷인(ui/UltimateCutIn.gd)과 같은 방식으로 연출 동안 게임을 멈추고
## (get_tree().paused) 이 노드만 PROCESS_MODE_ALWAYS로 계속 돈다. 연출이 끝나면 다시 풀린다.
##
## 왕관이 내려앉는 자리는 씬에 놓아둔 Crown 노드의 위치 그대로다 —
## 착지 지점을 바꾸려면 ui/CrownCutIn.tscn에서 Crown을 원하는 곳으로 끌어다 놓으면 된다.
##
## 얼굴 그림은 캐릭터마다 다르므로 GameState.PORTRAITS에서 가져온다 —
## 등록된 그림이 없는 캐릭터면 얼굴 없이 왕관만 내려오고, 연출 자체는 그대로 돈다.
##
## maps/Crown.gd이 "crown_cutin" 그룹으로 이 노드를 찾아 play(왕)를 부른다.

## 연출이 다 끝났을 때 (게임이 다시 움직이기 시작하는 시점)
signal finished

@export_group("길이(초)")
## 화면이 나타나는 시간
@export var open_time: float = 0.22
## 왕관이 머리로 내려오는 시간
@export var drop_time: float = 0.85
## 안착한 뒤 머무는 시간
@export var hold_time: float = 0.45
## 화면이 사라지는 시간
@export var close_time: float = 0.25

@export_group("왕관")
## 왕관이 출발하는 높이 (착지 자리에서 얼마나 위에서 내려오는지, px)
@export var drop_height: float = 300.0
## 안착 순간 눌렸다 펴지는 정도 (0이면 없음)
@export var land_squash: float = 0.18

## 얼굴 그림을 이 높이(px)에 맞춘다 — 캐릭터마다 그림 크기가 달라서 배율을 자동 계산한다
@export var face_height: float = 430.0

@export_group("박수치는 구경꾼")
## 왕이 된 캐릭터를 뺀 나머지가 순서대로 이 자리들에 선다 (Holder 기준). 자리가 모자라면 남는 캐릭터는 안 나온다
@export var spectator_spots: Array[Vector2] = [
	Vector2(-280, 250), Vector2(280, 250),
	Vector2(-432, 250), Vector2(432, 250),
	Vector2(-584, 250), Vector2(584, 250),
]
## 구경꾼 얼굴 높이(px)
@export var spectator_height: float = 130.0
## 1초에 몇 번 손뼉을 치는지
@export var clap_speed: float = 3.2
## 두 손이 벌어졌다 모이는 폭(px)
@export var clap_width: float = 20.0
## 손이 얼굴 아래 어디쯤에 오는지(px)
@export var clap_offset_y: float = 84.0
## 구경꾼 손 크기
@export var clap_hand_scale: float = 0.34

enum Phase { IDLE, OPEN, DROP, HOLD, CLOSE }

@onready var _background: CanvasItem = $Background
@onready var _holder: Node2D = $Holder
@onready var _face: Sprite2D = $Holder/Face
@onready var _crown: Sprite2D = $Holder/Crown
@onready var _spectators: Node2D = $Holder/Spectators

var _phase: int = Phase.IDLE
var _elapsed: float = 0.0
var _crown_base_scale: Vector2 = Vector2.ONE
## 왕관이 내려앉을 자리 — 씬에서 Crown 노드를 놓아둔 그 위치를 그대로 쓴다.
## 착지 지점을 바꾸고 싶으면 숫자를 고칠 필요 없이 에디터에서 왕관을 끌어다 놓으면 된다
var _seat: Vector2 = Vector2.ZERO
## 박수 애니메이션에 쓸 구경꾼 손들 [{left, right, base_x, phase}]
var _claps: Array = []
## 연출이 시작된 뒤 흐른 시간 (박수 박자용 — 단계별 _elapsed와 달리 계속 누적된다)
var _clap_time: float = 0.0

func _ready() -> void:
	add_to_group("crown_cutin")
	visible = false
	_crown_base_scale = _crown.scale
	_seat = _crown.position

## 연출을 시작한다. 이미 재생 중이면 무시한다
func play(king: Fighter) -> void:
	if _phase != Phase.IDLE:
		return
	_setup_face(king)
	_setup_spectators(king)
	_clap_time = 0.0
	_holder.position = get_viewport().get_visible_rect().size / 2.0
	_crown.position = _seat - Vector2(0, drop_height)
	_crown.scale = _crown_base_scale
	visible = true
	_phase = Phase.OPEN
	_elapsed = 0.0
	get_tree().paused = true

## 왕이 된 캐릭터의 정면 얼굴을 띄운다. 등록된 그림이 없으면 얼굴 없이 진행한다
func _setup_face(king: Fighter) -> void:
	_face.texture = null
	if king == null or king.stats == null:
		return
	var path: String = GameState.PORTRAITS.get(king.stats.character_name, "")
	if path == "" or not ResourceLoader.exists(path):
		return
	var texture: Texture2D = load(path)
	_face.texture = texture
	var height: float = float(texture.get_height())
	if height > 0.0:
		_face.scale = Vector2.ONE * (face_height / height)

## 왕이 아닌 캐릭터들을 뒤쪽 자리에 세우고, 각자 손 두 개를 붙여준다.
## 초상화가 등록된 캐릭터만 나온다 — 그림이 없으면 그 자리는 그냥 빈다
func _setup_spectators(king: Fighter) -> void:
	for child in _spectators.get_children():
		child.queue_free()
	_claps.clear()

	var king_name: String = king.stats.character_name if (king and king.stats) else ""
	var hand: Texture2D = $Holder/HandR.texture
	var index: int = 0
	for character_name in GameState.PORTRAITS:
		if character_name == king_name or index >= spectator_spots.size():
			continue
		var path: String = GameState.PORTRAITS[character_name]
		if not ResourceLoader.exists(path):
			continue
		var spot: Vector2 = spectator_spots[index]
		index += 1

		var texture: Texture2D = load(path)
		var face := Sprite2D.new()
		face.texture = texture
		face.position = spot
		var height: float = float(texture.get_height())
		if height > 0.0:
			face.scale = Vector2.ONE * (spectator_height / height)
		_spectators.add_child(face)

		var left := Sprite2D.new()
		left.texture = hand
		left.flip_h = true
		left.scale = Vector2.ONE * clap_hand_scale
		_spectators.add_child(left)
		var right := Sprite2D.new()
		right.texture = hand
		right.scale = Vector2.ONE * clap_hand_scale
		_spectators.add_child(right)

		# 캐릭터마다 박수 박자를 어긋나게 해야 다같이 딱딱 맞춰 치는 로봇처럼 안 보인다
		_claps.append({
			"left": left, "right": right,
			"center": spot + Vector2(0.0, clap_offset_y),
			"phase": float(index) * 1.1,
		})

## 두 손이 가운데로 모였다 벌어지길 반복한다
func _animate_claps() -> void:
	for clap in _claps:
		var swing: float = absf(sin(_clap_time * clap_speed * PI + clap["phase"]))
		var gap: float = clap_width * swing
		clap["left"].position = clap["center"] - Vector2(gap, 0.0)
		clap["right"].position = clap["center"] + Vector2(gap, 0.0)

func _process(delta: float) -> void:
	if _phase == Phase.IDLE:
		return
	_elapsed += delta
	_clap_time += delta
	_animate_claps()
	match _phase:
		Phase.OPEN:
			var t: float = _step(open_time)
			_background.modulate.a = t
			_holder.scale = Vector2.ONE * lerpf(0.92, 1.0, t)
			_holder.modulate.a = t
			if t >= 1.0:
				_next(Phase.DROP)
		Phase.DROP:
			var t: float = _step(drop_time)
			# 끝으로 갈수록 느려지게 — 툭 떨어지는 게 아니라 사뿐히 내려앉는 느낌
			var eased: float = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t)
			_crown.position = (_seat - Vector2(0, drop_height)).lerp(_seat, eased)
			if t >= 1.0:
				_next(Phase.HOLD)
		Phase.HOLD:
			var t: float = _step(hold_time)
			# 안착하는 순간 왕관이 살짝 눌렸다 펴진다
			var squash: float = land_squash * maxf(1.0 - t * 4.0, 0.0)
			_crown.scale = Vector2(_crown_base_scale.x * (1.0 + squash), _crown_base_scale.y * (1.0 - squash))
			if t >= 1.0:
				_next(Phase.CLOSE)
		Phase.CLOSE:
			var t: float = _step(close_time)
			_background.modulate.a = 1.0 - t
			_holder.modulate.a = 1.0 - t
			if t >= 1.0:
				_finish()

## 지금 단계의 진행도(0~1)
func _step(duration: float) -> float:
	return clampf(_elapsed / maxf(duration, 0.001), 0.0, 1.0)

func _next(phase: int) -> void:
	_phase = phase
	_elapsed = 0.0

func _finish() -> void:
	_phase = Phase.IDLE
	visible = false
	_holder.modulate.a = 1.0
	_holder.scale = Vector2.ONE
	get_tree().paused = false
	finished.emit()
