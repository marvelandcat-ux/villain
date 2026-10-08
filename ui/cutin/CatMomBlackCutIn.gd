class_name CatMomBlackCutIn
extends Node2D

## 고양이 아주머니 궁극기(검은 고양이) 컷인 — **만화책 한 쪽처럼 칸이 하나씩 차오른다**(2026-10-08 사용자 러프).
## 처음엔 세 칸 모두 하얗게 비어 있고, 아래 순서로 칸 안에 그림이 들어온다.
##  1. 오른쪽 아래 칸(`PanelWalk`): 할머니가 걸어오듯 몸을 들썩이며 투명 -> 불투명으로 나타나고,
##     **화면에서 왼쪽 안경알**에 하얀 빛이 한 번 훑고 지나간다(`LensGlint`)
##  2. 위 칸(`PanelCat`): 검은 고양이가 **바로** 나타나 있다가 얼굴이 칸 안에서 커지고, 한쪽 눈으로 윙크한다(`EyeBlink`)
##  3. 왼쪽 칸(`PanelHold`): 할머니가 고양이를 안고 있다. 꼬리가 살랑대다가 **할머니 손이 곡선을 그리며 날아가
##     꼬리 끝을 잡고 뒤로 당긴다** — 총을 장전하듯 철컥(칸이 잠깐 흔들린다)
##
## **자리는 전부 씬에서 잡는다.** 칸 모양은 각 `Panel*`(Polygon2D)의 점, 그림 자리는 그 안의 스프라이트를 끌면 된다.
## 이 스크립트는 "언제 무엇을 얼마나 움직일지"만 정한다. 칸 밖으로 나간 그림은 `clip_children`으로 잘린다.
## 칸 사이 검은 선(`Dividers`)은 칸 모양과 따로 있으니 칸 점을 옮기면 선도 같이 옮길 것.

const CAT_SPRITE := preload("res://skills/CatSprite.gd")

## 이 컷인이 화면에 머무는 시간(초). UltimateCutIn이 이 값을 읽어 간다
@export var cutin_duration: float = 3.8

@export_group("1. 걸어오는 할머니")
## 나타나기 시작하는 시각과, 완전히 불투명해질 때까지 걸리는 시간(초)
@export var walk_start: float = 0.05
@export var walk_time: float = 0.75
## 한 걸음마다 몸이 들썩이는 높이(px)와 1초에 몇 걸음 걷는지
@export var walk_bob: float = 16.0
@export var walk_steps_per_sec: float = 3.2
## 걸으며 좌우로 기우는 각도(도)
@export var walk_sway_deg: float = 2.5
## 처음 크기(1 = 씬에 놓인 크기). 다가오며 1까지 커진다
@export var walk_start_scale: float = 0.88
## 안경알 반짝이 터지는 시각(초)
@export var glint_at: float = 0.85

@export_group("2. 검은 고양이 윙크")
## 칸이 나타나는 시각(초)
@export var cat_panel_at: float = 1.3
## 얼굴이 커지기 시작하는 시각과 걸리는 시간(초), 최종 배율
@export var cat_zoom_at: float = 1.5
@export var cat_zoom_time: float = 0.3
@export var cat_zoom: float = 1.7
## 윙크 시작 시각과 감고 있는 시간(초)
@export var wink_at: float = 1.9
@export var wink_hold: float = 0.28

@export_group("3. 꼬리 잡아 당기기")
## 칸이 나타나는 시각(초)
@export var hold_panel_at: float = 2.3
## 손이 꼬리로 날아가기 시작하는 시각과 걸리는 시간(초)
@export var grab_at: float = 2.9
@export var grab_time: float = 0.25
## 손이 그리는 곡선이 위로 부푸는 높이(px) — 클수록 크게 휘어 날아간다
@export var grab_arc: float = 90.0
## 잡은 뒤 뒤로 당기는 거리(px)와 시간(초)
@export var pull_offset: Vector2 = Vector2(-80.0, 14.0)
@export var pull_time: float = 0.16
## 다 당긴 순간 칸이 흔들리는 폭(px)과 시간(초) — "철컥"
@export var rack_shake: float = 9.0
@export var rack_shake_time: float = 0.18
## 당길 때 고양이 몸이 손 쪽으로 끌려가는 비율(0이면 안 끌려감)
@export var pull_drag: float = 0.18

@export_group("꼬리 모양")
## 꼬리 길이(px), 뻗는 방향(도, 180 = 정왼쪽, 160 = 왼쪽 아래로 늘어짐), 끝이 위로 휘는 정도(px)
@export var tail_length: float = 150.0
@export var tail_deg: float = 160.0
@export var tail_curl: float = 30.0
## 살랑대는 물결 크기(px)와 빠르기
@export var tail_wave: float = 22.0
@export var tail_wave_speed: float = 9.0
@export var tail_points: int = 14

@onready var _walk_content: Node2D = $PanelWalk/Content
@onready var _walker: Node2D = $PanelWalk/Content/Walker
@onready var _glint: Node2D = $PanelWalk/Content/Walker/Head/LensGlint
@onready var _cat_content: Node2D = $PanelCat/Content
@onready var _cat_head: Sprite2D = $PanelCat/Content/CatHead
@onready var _wink: Node2D = $PanelCat/Content/CatHead/Wink
@onready var _hold_panel: Node2D = $PanelHold
@onready var _hold_content: Node2D = $PanelHold/Content
@onready var _tail: Line2D = $PanelHold/Content/Tail
@onready var _tail_root: Node2D = $PanelHold/Content/TailRoot
@onready var _hand: Sprite2D = $PanelHold/Content/HandL
@onready var _cat_body: Sprite2D = $PanelHold/Content/CatBody
@onready var _cat_held_head: Sprite2D = $PanelHold/Content/CatHead

var _time: float = 0.0
var _playing: bool = false
var _glinted: bool = false
var _walker_rest: Vector2
var _walker_scale: Vector2
var _cat_head_scale: Vector2
var _hand_rest: Vector2
var _cat_body_rest: Vector2
var _cat_held_head_rest: Vector2
var _hold_panel_rest: Vector2
## 손이 날아가기 시작한 순간의 꼬리 끝 자리 — 손은 여기로 날아간다
var _grab_target: Vector2
var _grab_target_set: bool = false

func _ready() -> void:
	_walker_rest = _walker.position
	_walker_scale = _walker.scale
	_cat_head_scale = _cat_head.scale
	_hand_rest = _hand.position
	_cat_body_rest = _cat_body.position
	_cat_held_head_rest = _cat_held_head.position
	_hold_panel_rest = _hold_panel.position
	# 꼬리 그림은 게임 속 고양이와 같은 것(투명 여백을 잘라낸 판)을 Line2D에 늘려 붙인다
	_tail.texture = CAT_SPRITE.cropped_of(0, "tail")
	_tail.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	var box: Rect2 = CAT_SPRITE.bbox_of(0, "tail")
	_tail.width = tail_length * box.size.y / maxf(box.size.x, 1.0)
	# 윙크 눈꺼풀은 리그 머리가 아니라 그냥 스프라이트에 붙어 있다
	_wink.needs_rig = false
	_apply(0.0)
	# F6로 이 씬만 띄웠으면 화면 가운데로 옮겨 바로 재생한다 — 자리 맞출 때 확인용. R을 누르면 처음부터 다시
	if get_parent() == get_tree().root:
		position = get_viewport().get_visible_rect().size * 0.5
		play()

## 컷인 재생을 시작한다(UltimateCutIn이 부른다). 에디터 화면에서는 씬에 놓인 그대로(세 칸 다 찬 모습) 보인다
func play() -> void:
	_time = 0.0
	_glinted = false
	_grab_target_set = false
	_playing = true
	_apply(0.0)

func _unhandled_key_input(event: InputEvent) -> void:
	if get_parent() == get_tree().root and event.is_pressed() and (event as InputEventKey).keycode == KEY_R:
		play()

func _process(delta: float) -> void:
	if not _playing:
		return
	_time += minf(delta, 0.05)
	_apply(_time)

func _apply(t: float) -> void:
	_apply_walk(t)
	_apply_cat(t)
	_apply_hold(t)

# --- 1. 걸어오는 할머니 ---

func _apply_walk(t: float) -> void:
	var local: float = t - walk_start
	_walk_content.visible = local >= 0.0
	if local < 0.0:
		return
	var k: float = clampf(local / maxf(walk_time, 0.01), 0.0, 1.0)
	var eased: float = 1.0 - (1.0 - k) * (1.0 - k)
	_walk_content.modulate.a = eased
	# 걸음마다 위로 톡 튄다(|sin|). 다 걸어온 뒤엔 숨쉬듯 아주 작게만
	var phase: float = local * walk_steps_per_sec * PI
	var bob: float = absf(sin(phase)) * walk_bob * (1.0 - k * 0.85)
	_walker.position = _walker_rest + Vector2(0.0, -bob)
	_walker.rotation = deg_to_rad(walk_sway_deg) * sin(phase) * (1.0 - k * 0.7)
	_walker.scale = _walker_scale * lerpf(walk_start_scale, 1.0, eased)
	if not _glinted and t >= glint_at:
		_glinted = true
		if _glint.has_method("blink_now"):
			_glint.blink_now()

# --- 2. 검은 고양이 윙크 ---

func _apply_cat(t: float) -> void:
	_cat_content.visible = t >= cat_panel_at
	if t < cat_panel_at:
		return
	var k: float = clampf((t - cat_zoom_at) / maxf(cat_zoom_time, 0.01), 0.0, 1.0)
	# 살짝 넘쳤다가 돌아오는 커짐(back ease) — "툭" 다가오는 느낌
	var c: float = 1.70158
	var back: float = 1.0 + (c + 1.0) * pow(k - 1.0, 3.0) + c * pow(k - 1.0, 2.0)
	_cat_head.scale = _cat_head_scale * lerpf(1.0, cat_zoom, back)
	_wink.held_closed = t >= wink_at and t < wink_at + wink_hold

# --- 3. 꼬리 잡아 당기기 ---

func _apply_hold(t: float) -> void:
	_hold_content.visible = t >= hold_panel_at
	if t < hold_panel_at:
		return
	var local: float = t - hold_panel_at
	var grab_k: float = clampf((t - grab_at) / maxf(grab_time, 0.01), 0.0, 1.0)
	var pull_k: float = clampf((t - grab_at - grab_time) / maxf(pull_time, 0.01), 0.0, 1.0)
	var pull_eased: float = 1.0 - pow(1.0 - pull_k, 3.0)
	if t >= grab_at and not _grab_target_set:
		_grab_target = _free_tail_tip(local)
		_grab_target_set = true
	# 손: 제자리 -> (위로 부푼 곡선) -> 꼬리 끝 -> 뒤로 당김
	var hand_pos: Vector2 = _hand_rest
	if _grab_target_set:
		var e: float = grab_k * grab_k * (3.0 - 2.0 * grab_k)
		var mid: Vector2 = (_hand_rest + _grab_target) * 0.5 + Vector2(0.0, -grab_arc)
		var a: Vector2 = _hand_rest.lerp(mid, e)
		var b: Vector2 = mid.lerp(_grab_target, e)
		hand_pos = a.lerp(b, e) + pull_offset * pull_eased
	_hand.position = hand_pos
	# 당기면 고양이가 손 쪽으로 살짝 끌려온다
	var drag: Vector2 = pull_offset * pull_eased * pull_drag
	_cat_body.position = _cat_body_rest + drag
	_cat_held_head.position = _cat_held_head_rest + drag
	# 꼬리: 잡히기 전엔 살랑, 손이 닿는 동안 꼬리 끝이 손으로 끌려가 팽팽해진다
	var hold_blend: float = 0.0
	if _grab_target_set:
		hold_blend = smoothstep(0.75, 1.0, grab_k)
	_update_tail(local, hold_blend, hand_pos, drag)
	# 다 당긴 순간 "철컥" — 칸이 짧게 흔들린다
	var since_rack: float = t - (grab_at + grab_time + pull_time)
	if since_rack >= 0.0 and since_rack < rack_shake_time:
		var s: float = rack_shake * (1.0 - since_rack / rack_shake_time)
		_hold_panel.position = _hold_panel_rest + Vector2(sin(since_rack * 90.0), cos(since_rack * 70.0)) * s
	else:
		_hold_panel.position = _hold_panel_rest

## 살랑대는 꼬리의 점 하나(t: 0 뿌리 ~ 1 끝)
func _free_tail_point(local: float, t: float, root: Vector2) -> Vector2:
	var dir := Vector2.RIGHT.rotated(deg_to_rad(tail_deg))
	var up := Vector2(-dir.y, dir.x)
	if up.y > 0.0:
		up = -up
	var bend: float = tail_curl * t * t + sin(local * tail_wave_speed - t * 3.0) * tail_wave * t
	return root + dir * (tail_length * t) + up * bend

func _free_tail_tip(local: float) -> Vector2:
	return _free_tail_point(local, 1.0, _tail_root.position)

## Line2D는 첫 점이 그림 왼쪽 끝(= 꼬리 끝)이라 **끝 -> 뿌리** 순서로 넣는다(CatSprite와 같은 규칙)
func _update_tail(local: float, hold_blend: float, hand_pos: Vector2, drag: Vector2) -> void:
	var n: int = maxi(tail_points, 2)
	var root: Vector2 = _tail_root.position + drag
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		var t: float = 1.0 - float(i) / float(n - 1)
		var free: Vector2 = _free_tail_point(local, t, root)
		# 잡힌 꼬리 = 뿌리에서 손까지 거의 곧게(가운데만 살짝 처짐)
		var held: Vector2 = root.lerp(hand_pos, t) + Vector2(0.0, sin(PI * t) * 10.0)
		pts[i] = free.lerp(held, hold_blend)
	_tail.points = pts
