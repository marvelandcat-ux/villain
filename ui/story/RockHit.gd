class_name RockHit
extends Sprite2D

## 자전거 타던 잼민이가 돌에 맞고 넘어지는 연출 (2026-09-14) —
## **화면 왼쪽 밖에서 돌이 날아와 뒷바퀴에 맞고, 그 순간 그림이 넘어지는 자세로 바뀌며 화면이 흔들린다.**
##
## 배경 그림 두 장(`잼민이자전거공원질주` / `잼민이돌맞고넘어지는장면`)이 **같은 캔버스(1672x941)에
## 같은 구도로** 그려져 있어서, TextureRect의 텍스처만 갈아 끼우면 자세가 바뀐다 —
## 돌 던지는 장면(`RockThrow`)이나 잼민이 페달과 같은 방식이다.
##
## 이 스크립트는 **돌 자신**에 붙인다. 씬에서는 돌을 **맞는 자리(뒷바퀴)** 에 놓아둘 것 —
## 거기가 도착점이고, 출발점은 `start_offset`만큼 떨어진 화면 밖이다.
## (에디터에서 돌이 바퀴 위에 겹쳐 보이는 게 정상이다. 게임에선 화면 밖에서 날아와 그 자리에 도착한다)
##
## 화면 흔들림은 `shake_target`으로 지정한 노드의 position을 흔든다. 스토리 장면엔 카메라가 없어서
## **화면 자체를 옮기는 방식**이다. 그래서 흔들 노드(`Shake`)에 든 배경은 화면보다 조금 크게(사방 여유)
## 잡아 둬야 한다 — 딱 맞으면 흔드는 순간 가장자리에 검은 띠가 보인다.

## 맞는 순간 갈아 끼울 배경 (TextureRect 또는 Sprite2D)
@export var bg: NodePath
## 넘어지는 자세 그림
@export var fall_texture: Texture2D

@export_group("날아오기")
## 장면이 시작하고 몇 초 뒤에 맞는지. **StoryFadeScene의 fade_in_time(기본 1.2초)보다 커야**
## 화면이 밝아진 뒤에 날아온다
@export var hit_delay: float = 2.0
## 출발점 — 도착점(씬에 놓아둔 자리)에서 이만큼 떨어진 곳에서 날아온다. x가 음수면 화면 왼쪽 밖
@export var start_offset: Vector2 = Vector2(-1020.0, -70.0)
## 날아오는 데 걸리는 시간(초). 짧을수록 "쉬익" 하고 날아온다
@export var fly_time: float = 0.26
## 날아오는 동안 몇 바퀴 도는지
@export var spin_turns: float = 1.5

@export_group("맞은 뒤")
## 맞고 튕겨 나가는 거리. 0이면 그 자리에서 사라진다
@export var ricochet: Vector2 = Vector2(-120.0, -90.0)
## 튕겨 나가며 사라지는 시간(초)
@export var ricochet_time: float = 0.45

@export_group("화면 흔들기")
## 흔들 노드(보통 배경과 돌을 담은 `Shake` Control). 비우면 안 흔든다
@export var shake_target: NodePath
## 흔들리는 최대 폭(px)
@export var shake_strength: float = 22.0
## 흔들림이 잦아드는 데 걸리는 시간(초)
@export var shake_time: float = 0.55
## 1초에 몇 번 흔들리는지
@export var shake_freq: float = 26.0

@export_group("돌 잔상")
## 돌 뒤에 남길 잔상 장수. 0이면 잔상 없음 (RockThrow와 같은 방식)
@export var trail_count: int = 8
## 잔상 사이 간격(px). 0이면 한 프레임에 움직이는 거리로 자동
@export var trail_spacing: float = 26.0
## 돌 바로 뒤 잔상의 투명도(0~1)
@export_range(0.0, 1.0, 0.01) var trail_alpha: float = 0.45
## 잔상 색 보정. 여기는 밝은 낮 배경이라 1보다 작게 해서 어둡게 깔아야 눈에 띈다
@export var trail_tint: Color = Color(0.75, 0.75, 0.75, 1.0)

var _goal: Vector2 = Vector2.ZERO
var _ghosts: Array[Sprite2D] = []
var _flying: bool = false
var _shake_node: Control = null
var _shake_base: Vector2 = Vector2.ZERO
var _shake_left: float = 0.0

func _ready() -> void:
	# 씬에 놓아둔 자리가 "맞는 자리"다 — 거기서 start_offset만큼 뒤로 물려서 출발한다
	_goal = position
	position = _goal + start_offset
	visible = false
	_shake_node = get_node_or_null(shake_target) as Control
	if _shake_node:
		_shake_base = _shake_node.position
	_build_ghosts()
	var tween: Tween = create_tween()
	tween.tween_interval(hit_delay)
	tween.tween_callback(_launch)

## 잔상 — 같은 그림을 뒤로 물려 옅게 겹친다. 트리에서 돌보다 앞에 넣어 뒤에 그려지게 한다
func _build_ghosts() -> void:
	if trail_count <= 0:
		return
	var parent: Node = get_parent()
	if parent == null:
		return
	for i in range(trail_count):
		var ghost := Sprite2D.new()
		ghost.texture = texture
		ghost.centered = centered
		ghost.scale = scale
		ghost.z_index = z_index
		ghost.visible = false
		parent.add_child(ghost)
		parent.move_child(ghost, get_index())
		_ghosts.append(ghost)

func _launch() -> void:
	visible = true
	_flying = true
	var spin: Tween = create_tween()
	spin.tween_property(self, "rotation", TAU * spin_turns, fly_time).set_trans(Tween.TRANS_LINEAR)
	# **한 번에 등속으로** 날아온다 — 구간을 쪼개면 가운데서 한 번 느려져 끊겨 보인다
	var path: Tween = create_tween()
	path.tween_property(self, "position", _goal, fly_time).set_trans(Tween.TRANS_LINEAR)
	path.tween_callback(_impact)

## 맞는 순간 — 자세 교체 + 화면 흔들기 + 돌 튕겨내기
func _impact() -> void:
	_flying = false
	for ghost in _ghosts:
		ghost.visible = false
	var target: CanvasItem = get_node_or_null(bg) as CanvasItem
	if target and fall_texture:
		if target is TextureRect:
			(target as TextureRect).texture = fall_texture
		elif target is Sprite2D:
			(target as Sprite2D).texture = fall_texture
	if _shake_node:
		_shake_left = shake_time
	if ricochet == Vector2.ZERO:
		visible = false
		return
	var out: Tween = create_tween()
	out.set_parallel(true)
	out.tween_property(self, "position", _goal + ricochet, ricochet_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	out.tween_property(self, "rotation", rotation + TAU * 0.6, ricochet_time)
	out.tween_property(self, "modulate:a", 0.0, ricochet_time)

func _process(delta: float) -> void:
	_update_shake(delta)
	if _ghosts.is_empty():
		return
	var spacing: float = trail_spacing
	if spacing <= 0.0:
		spacing = start_offset.length() / maxf(fly_time, 0.001) / 60.0
	# 날아오는 방향의 반대쪽(= 출발점 쪽)으로 물린다
	var back: Vector2 = start_offset.normalized() * spacing
	for i in range(_ghosts.size()):
		var ghost: Sprite2D = _ghosts[i]
		ghost.visible = _flying
		if not _flying:
			continue
		# 트리 앞쪽(i가 작을수록)이 가장 멀고 가장 옅다
		ghost.position = position + back * float(_ghosts.size() - i)
		ghost.rotation = rotation
		ghost.modulate = Color(trail_tint.r, trail_tint.g, trail_tint.b,
			trail_alpha * float(i + 1) / float(_ghosts.size()))

## 감쇠 진동 — 처음이 가장 세고 제곱으로 빠르게 잦아든다. 가로를 세로보다 크게 흔들어 "충격"으로 읽히게 한다
func _update_shake(delta: float) -> void:
	if _shake_node == null or _shake_left <= 0.0:
		return
	_shake_left -= delta
	if _shake_left <= 0.0:
		_shake_left = 0.0
		_shake_node.position = _shake_base
		return
	var k: float = _shake_left / maxf(shake_time, 0.001)
	var amp: float = shake_strength * k * k
	var phase: float = (shake_time - _shake_left) * shake_freq * TAU
	_shake_node.position = _shake_base + Vector2(sin(phase) * amp, cos(phase * 1.37) * amp * 0.6)
