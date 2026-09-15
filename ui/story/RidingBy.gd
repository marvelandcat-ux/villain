class_name RidingBy
extends Sprite2D

## 그림 두 장을 번갈아 보여주며 화면을 가로질러 지나가는 연출 (2026-09-13, 잼민이 자전거).
##
## 페달 밟는 두 장(오른발 위 / 왼발 위)이 **같은 캔버스에 같은 자리로** 그려져 있어서,
## 텍스처만 갈아 끼우면 발만 바뀌고 몸·자전거는 안 흔들린다. 그래서 노드 하나로 끝난다.
##
## **씬에는 "지나갈 높이와 크기"만 맞춰서 화면 안 잘 보이는 자리에 놓으면 된다.**
## 출발·도착 자리는 화면 폭과 그림 폭을 보고 스크립트가 알아서 화면 밖으로 잡는다 —
## 그래서 에디터에서 크기·높이를 눈으로 보며 맞출 수 있다.
## **쓰는 값은 `position.y`(지나갈 높이)와 `scale`(크기)뿐이고, `position.x`는 안 쓴다.**
##
## **씬에 `texture`를 첫 장으로 지정해 둘 것** — 안 그러면 에디터에서 아무것도 안 보여서 크기를 못 맞춘다.
## (`frames[0]`은 게임이 시작될 때 들어가므로 에디터에는 반영되지 않는다. 메인 메뉴 등장 프레임과 같은 이유)

## 화면을 다 지나간 순간. 뒤에 이어질 연출(PopUpLayer.after)이 이 신호를 기다린다 —
## 크기나 속도를 바꾸면 지나가는 시간도 같이 바뀌므로, 초를 적어 두는 것보다 이게 안전하다
signal passed

## 번갈아 보여줄 그림들. 두 장이면 두 장을 왔다갔다 한다.
## **한 장만 넣으면 그림이 안 바뀌고 그대로 지나간다** — 너무 빨리 지나가면 발 바뀌는 게 어차피 안 보여서
## 오히려 지저분해 보이기 때문이다(2026-09-13 사용자 요청으로 잼민이는 한 장으로 바꿨다)
@export var frames: Array[Texture2D] = []
## 한 장이 보이는 시간(초). 작을수록 빨리 밟는다
@export var frame_time: float = 0.09
## 지나가는 속도(px/초). **크기를 바꿔도 속도는 그대로다** — 이동 거리를 속도로 나눠 시간을 정하기 때문
@export var speed: float = 1320.0
## 화면 끝에서 이만큼 더 바깥에서 출발하고, 이만큼 더 바깥까지 간다(px)
@export var edge_margin: float = 40.0
## 오른쪽으로 갈지(true) 왼쪽으로 갈지(false). 그림이 오른쪽을 보고 있으므로
## 왼쪽으로 보내려면 `flip_h`도 같이 켤 것
@export var to_right: bool = true
## 장면이 시작하고 몇 초 뒤에 출발하는지
@export var delay: float = 1.4
## 다 지나가면 숨길지. 끄면 화면 밖 도착 자리에 그대로 남는다
@export var hide_after: bool = true

@export_group("잔상")
## 뒤에 남길 잔상 장수. 0이면 잔상 없음
@export var trail_count: int = 3
## 잔상 사이 간격(px). **0이면 `speed / 60`**(한 프레임에 움직이는 거리)으로 자동 잡는다 —
## 그래야 지난 몇 프레임을 그대로 겹친 꼴이 되어 진짜 모션 블러처럼 이어진다
@export var trail_spacing: float = 0.0
## 본체 바로 뒤 잔상의 투명도(0~1). 뒤로 갈수록 옅어진다
@export_range(0.0, 1.0, 0.01) var trail_alpha: float = 0.35

## 미리 만들어 두고 따라다니게만 하는 잔상들 (매 프레임 새로 만들지 않아 가볍다)
var _ghosts: Array[Sprite2D] = []
var _frame: int = 0
var _frame_timer: float = 0.0
var _running: bool = false

func _ready() -> void:
	if not frames.is_empty():
		texture = frames[0]
	visible = false
	# 그림이 화면 밖으로 완전히 빠지는 x — 텍스처 폭의 절반에 여유를 더한다
	var view_width: float = get_viewport_rect().size.x
	var half_width: float = (texture.get_width() * absf(scale.x) * 0.5) if texture else 0.0
	var out_left: float = -half_width - edge_margin
	var out_right: float = view_width + half_width + edge_margin
	var start: Vector2 = Vector2(out_left if to_right else out_right, position.y)
	var goal: Vector2 = Vector2(out_right if to_right else out_left, position.y)
	position = start
	var travel_time: float = absf(goal.x - start.x) / maxf(speed, 1.0)
	_build_ghosts()
	var tween: Tween = create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(_begin)
	# 자전거는 일정한 속도로 지나간다 — 가감속을 넣으면 미끄러지는 것처럼 보인다
	tween.tween_property(self, "position", goal, travel_time).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(_finish)

func _begin() -> void:
	visible = true
	_running = true
	_frame_timer = 0.0

func _finish() -> void:
	_running = false
	if hide_after:
		visible = false
	passed.emit()

## 잔상 — 같은 그림을 조금씩 뒤로 물려 옅게 겹친다. **본체보다 트리에서 앞에 넣어 뒤에 그려지게** 한다
func _build_ghosts() -> void:
	if trail_count <= 0:
		return
	var parent: Node = get_parent()
	if parent == null:
		return
	for i in range(trail_count):
		var ghost := Sprite2D.new()
		ghost.centered = centered
		ghost.z_index = z_index
		ghost.visible = false
		parent.add_child(ghost)
		parent.move_child(ghost, get_index())   # 본체 바로 앞자리로 = 본체보다 먼저(뒤에) 그려진다
		_ghosts.append(ghost)

func _update_trail() -> void:
	if _ghosts.is_empty():
		return
	var spacing: float = trail_spacing if trail_spacing > 0.0 else speed / 60.0
	var back_dir: float = -1.0 if to_right else 1.0
	for i in range(_ghosts.size()):
		var ghost: Sprite2D = _ghosts[i]
		ghost.visible = _running
		if not _running:
			continue
		# 트리 앞쪽(i가 작을수록)이 가장 멀고 가장 옅다
		ghost.texture = texture
		ghost.scale = scale
		ghost.flip_h = flip_h
		ghost.position = position + Vector2(back_dir * spacing * float(_ghosts.size() - i), 0.0)
		ghost.modulate.a = trail_alpha * float(i + 1) / float(_ghosts.size())

func _process(delta: float) -> void:
	_update_trail()
	if not _running or frames.size() < 2:
		return
	_frame_timer += delta
	if _frame_timer < frame_time:
		return
	_frame_timer -= frame_time
	_frame = (_frame + 1) % frames.size()
	texture = frames[_frame]
