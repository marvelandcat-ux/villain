class_name RockThrow
extends Sprite2D

## 돌 던지는 연출 (2026-09-13) — **준비 자세로 있다가 던진 자세로 바뀌고, 그 순간 손에 있던 돌이 날아간다.**
##
## 그림 두 장(`돌던지기직전` / `돌던진직후`)이 **같은 캔버스에 같은 기준으로** 그려져 있어서,
## 텍스처만 갈아 끼우면 자세가 바뀐다 — 잼민이 페달과 같은 방식이라 노드를 늘릴 필요가 없다.
##
## 돌은 별도 Sprite2D로 두고 **손에 돌이 있는 자리**에 놓아둔다. 던지는 순간 거기서 출발하므로,
## 자세 그림을 바꾸거나 위치를 옮기면 돌도 같이 옮겨 놓아야 한다.
##
## **씬에는 준비 자세 텍스처를 직접 지정해 둘 것** — 안 그러면 에디터에서 안 보여 배치를 못 한다.

## 던지기 직전(준비) 자세
@export var wind_up_texture: Texture2D
## 던진 직후 자세
@export var release_texture: Texture2D
## 장면이 시작하고 몇 초 뒤에 던지는지
@export var throw_delay: float = 1.8

## 던진 직후 몸이 앞으로 따라 나가는 거리(px). **0이면 제자리에서 그림만 바뀐다** —
## 그림 두 장이 같은 캔버스라 자세만 바뀌고 몸이 안 움직여서 "던진 것 같지 않다"는 인상이 된다(사용자 지적).
## 던지는 방향(+x)으로 살짝 밀어 주면 따라 나간 느낌(follow-through)이 난다
@export var release_shift: Vector2 = Vector2(34.0, 0.0)
## 앞으로 나가는 데 걸리는 시간(초). 짧아야 "휙" 하고 던진 것으로 읽힌다
@export var release_shift_time: float = 0.1
## 앞으로 나갔다가 되돌아오는 비율(0~1). 0이면 나간 자리에 그대로 선다.
## 사람이 던지면 앞으로 쏠렸다가 살짝 중심을 되찾으므로 조금 남겨 두는 게 자연스럽다
@export_range(0.0, 1.0, 0.05) var release_settle_ratio: float = 0.25
## 되돌아오는 데 걸리는 시간(초)
@export var release_settle_time: float = 0.3

@export_group("돌")
## 날아갈 돌 (Sprite2D). 씬에서 **손에 돌이 있는 자리**에 놓아둘 것
@export var rock: NodePath
## 돌이 날아가는 거리(px). 화면 밖까지 나가도록 넉넉히
@export var rock_travel: Vector2 = Vector2(1180.0, 120.0)
## 가운데쯤에서 위로 부풀어 오르는 높이(px). **0이면 한 번에 등속으로 곧게 날아간다**
@export var rock_arc: float = 50.0
## 날아가는 데 걸리는 시간(초)
@export var rock_time: float = 0.5
## 날아가는 동안 몇 바퀴 도는지
@export var rock_spin_turns: float = 2.5
## 다 날아가면 숨길지
@export var hide_rock_after: bool = true

@export_group("돌 잔상")
## 돌 뒤에 남길 잔상 장수. 0이면 잔상 없음. **빠를수록 잔상이 있어야 "쉬익" 하고 지나간 것처럼 보인다** —
## 없으면 순간이동한 것처럼 툭 사라진다
@export var trail_count: int = 8
## 잔상 사이 간격(px). 0이면 **한 프레임에 움직이는 거리**(거리 / 시간 / 60)로 자동.
## 자동값(여기서는 59px)은 돌 폭과 비슷해서 잔상이 뚝뚝 끊겨 보인다 — 절반쯤으로 좁혀 겹치게 하면 한 줄기로 이어진다
@export var trail_spacing: float = 28.0
## 돌 바로 뒤 잔상의 투명도(0~1). 뒤로 갈수록 옅어진다
@export_range(0.0, 1.0, 0.01) var trail_alpha: float = 0.5
## 잔상 색 보정. **1보다 크면 밝아진다** — 검은 배경에서는 원본 회색 그대로면 잔상이 어둡게 묻혀서
## 1.5쯤 올려야 "쉬익" 하고 지나간 흰 줄기로 읽힌다
@export var trail_tint: Color = Color(1.6, 1.6, 1.6, 1.0)
## 잔상을 **더하기 합성**으로 그릴지. 검은 배경에서는 보통 합성이면 옅은 잔상이 그대로 검게 묻히는데,
## 더하기로 그리면 빛줄기처럼 배경 위에 얹힌다. **다만 배경이 완전한 검정이면 보통 합성과 결과가 같다**
## (검정 위에 얹는 건 곱하든 더하든 같은 값이라서) — 지금은 꺼 두고, 밝은 배경으로 바꿀 때 켜 보면 된다
@export var trail_additive: bool = false

var _rock: Sprite2D = null
var _rock_start: Vector2 = Vector2.ZERO
## 던지기 전 서 있던 자리 — 따라 나가는 연출의 기준
var _base_pos: Vector2 = Vector2.ZERO
## 미리 만들어 두고 따라다니게만 하는 잔상들 (RidingBy와 같은 방식)
var _ghosts: Array[Sprite2D] = []
var _flying: bool = false

func _ready() -> void:
	if wind_up_texture:
		texture = wind_up_texture
	_base_pos = position
	_rock = get_node_or_null(rock) as Sprite2D
	if _rock:
		_rock_start = _rock.position
		_rock.visible = false
		_build_ghosts()
	var tween: Tween = create_tween()
	tween.tween_interval(throw_delay)
	tween.tween_callback(_release)

## 잔상 — 돌과 같은 그림을 뒤로 물려 옅게 겹친다. 돌보다 트리에서 앞에 넣어 뒤에 그려지게 한다
func _build_ghosts() -> void:
	if trail_count <= 0 or _rock == null:
		return
	var parent: Node = _rock.get_parent()
	if parent == null:
		return
	var mat: CanvasItemMaterial = null
	if trail_additive:
		mat = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in range(trail_count):
		var ghost := Sprite2D.new()
		ghost.material = mat          # 하나를 같이 쓴다 (장마다 만들 필요 없다)
		ghost.texture = _rock.texture
		ghost.centered = _rock.centered
		ghost.scale = _rock.scale
		ghost.z_index = _rock.z_index
		ghost.visible = false
		parent.add_child(ghost)
		parent.move_child(ghost, _rock.get_index())
		_ghosts.append(ghost)

func _process(_delta: float) -> void:
	if _ghosts.is_empty() or _rock == null:
		return
	var spacing: float = trail_spacing
	if spacing <= 0.0:
		spacing = rock_travel.length() / maxf(rock_time, 0.001) / 60.0
	var back: Vector2 = -rock_travel.normalized() * spacing
	for i in range(_ghosts.size()):
		var ghost: Sprite2D = _ghosts[i]
		ghost.visible = _flying
		if not _flying:
			continue
		# 트리 앞쪽(i가 작을수록)이 가장 멀고 가장 옅다
		ghost.position = _rock.position + back * float(_ghosts.size() - i)
		ghost.rotation = _rock.rotation
		ghost.modulate = Color(trail_tint.r, trail_tint.g, trail_tint.b,
			trail_alpha * float(i + 1) / float(_ghosts.size()))

func _release() -> void:
	if release_texture:
		texture = release_texture
	_lunge()
	if _rock == null:
		return
	_rock.position = _rock_start
	_rock.rotation = 0.0
	_rock.visible = true
	_flying = true
	# 회전과 이동은 따로 돌린다 (포물선으로 던질 땐 이동이 두 구간이라 하나로 묶기 번거롭다)
	var spin: Tween = _rock.create_tween()
	spin.tween_property(_rock, "rotation", TAU * rock_spin_turns, rock_time).set_trans(Tween.TRANS_LINEAR)
	var goal: Vector2 = _rock_start + rock_travel
	var path: Tween = _rock.create_tween()
	if is_zero_approx(rock_arc):
		# **곧게 날아갈 땐 한 번에 등속으로 간다.** 예전엔 arc가 0이어도 두 구간으로 쪼개서
		# 앞은 감속(EASE_OUT) 뒤는 가속(EASE_IN)으로 굴렸는데, 가운데서 한 번 느려져 끊겨 보였다(사용자 지적)
		path.tween_property(_rock, "position", goal, rock_time).set_trans(Tween.TRANS_LINEAR)
	else:
		# 포물선으로 던질 때만 두 구간 — 올라갈 때 느려지고 내려올 때 빨라지는 게 맞다
		var mid: Vector2 = _rock_start + rock_travel * 0.5 - Vector2(0.0, rock_arc)
		path.tween_property(_rock, "position", mid, rock_time * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		path.tween_property(_rock, "position", goal, rock_time * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if hide_rock_after:
		path.tween_callback(_hide_rock)

func _hide_rock() -> void:
	_flying = false
	if _rock:
		_rock.visible = false

## 던진 직후 몸을 앞으로 밀어냈다가 조금 되돌린다
func _lunge() -> void:
	if release_shift == Vector2.ZERO:
		return
	var forward: Vector2 = _base_pos + release_shift
	var lunge: Tween = create_tween()
	lunge.tween_property(self, "position", forward, release_shift_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if release_settle_ratio > 0.0:
		var settle: Vector2 = forward - release_shift * release_settle_ratio
		lunge.tween_property(self, "position", settle, release_settle_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
