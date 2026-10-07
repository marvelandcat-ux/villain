class_name StatusIconVfx
extends Node2D

## 버프·디버프가 걸린 동안 몸 근처에서 아이콘이 계속 생겨 위(버프) 또는 아래(디버프)로 흘러가며 흐려지는 이펙트 (순수 장식).
## 슬로우 = 파란 달팽이 / 점프력 감소 = 보라 발에 X(둘 다 내려감) / 공격력 증가 = 빨간 칼이 올라감. 종류별 그림·방향은 아래 `KINDS` 한 곳에서 정한다.
## 아이콘과 함께 같은 방향으로 흐르는 **세로 스피드 라인**(그 버프 색)도 몸 둘레에 긋는다 — 줄은 캐릭터 **뒤**에 그려 몸을 안 가린다.
##
## 직접 만들지 말고 `Fighter.show_status_vfx(종류, 시간)` / `hide_status_vfx(종류)`로 켜고 끈다 —
## Fighter가 종류마다 하나만 들고 있어서 같은 게 또 걸리면 새로 만들지 않고 시간만 늘린다.
## **맵에** 붙는다(캐릭터 자식이면 좌우 반전에 뒤집힘). 위치는 매 프레임 캐릭터를 따라간다

## 종류별 설정. rect = 그림에서 실제로 보이는 영역(px, 알파 64 이상 — **그림을 바꾸면 다시 잴 것**),
## size = 화면에서의 키(px), dir = 1 아래로 / -1 위로, travel = 흘러가는 거리(px), life = 한 개가 사라지기까지(초),
## interval = 다음 아이콘까지(초) 최소~최대, line_color = 스피드 라인 색(버프 색)
const KINDS: Dictionary = {
	&"slow": {
		"texture": preload("res://sprite/VFX/이속 디버프.png"),
		"rect": Rect2(311, 198, 993, 683),
		"size": 18.0, "dir": 1.0, "travel": 30.0, "life": 0.85,
		"interval": Vector2(0.22, 0.38),
		"line_color": Color(0.25, 0.6, 1.0, 0.8),
	},
	&"jump_down": {
		"texture": preload("res://sprite/VFX/점프 디버프.png"),
		"rect": Rect2(264, 93, 1055, 799),
		"size": 18.0, "dir": 1.0, "travel": 30.0, "life": 0.85,
		"interval": Vector2(0.26, 0.42),
		"line_color": Color(0.58, 0.32, 1.0, 0.8),
	},
	&"attack_up": {
		"texture": preload("res://sprite/VFX/칼.png"),
		"rect": Rect2(258, 285, 810, 752),
		"size": 16.0, "dir": -1.0, "travel": 34.0, "life": 0.9,
		"interval": Vector2(0.3, 0.48),
		"line_color": Color(1.0, 0.12, 0.08, 0.8),
	},
}

## 아이콘이 생기는 범위(캐릭터 원점 = 몸 가운데 기준, px) — 가로 ±, 세로 위~아래. 내려가는 종류는 travel만큼 더 위에서 생긴다(_spawn_icon)
const SPAWN_HALF_WIDTH: float = 26.0
const SPAWN_Y: Vector2 = Vector2(-44.0, 14.0)

## 스피드 라인 — 생기는 가로 범위(몸에서 떨어진 거리, 양옆 중 하나), 세로 범위, 길이, 흐르는 속도(px/초), 수명(초), 굵기, 다음 줄까지(초)
const LINE_SIDE_X: Vector2 = Vector2(10.0, 32.0)
const LINE_Y: Vector2 = Vector2(-56.0, 26.0)
const LINE_LENGTH: Vector2 = Vector2(18.0, 34.0)
const LINE_SPEED: float = 150.0
const LINE_LIFE: float = 0.32
const LINE_WIDTH: float = 1.8
const LINE_INTERVAL: Vector2 = Vector2(0.06, 0.12)

## 어떤 종류인지 — **add_child 전에** 넣을 것
var kind: StringName = &"slow"

var _cfg: Dictionary = {}
var _target: Node2D = null
var _has_target: bool = false
## 남은 시간(초). INF면 hide_status_vfx로 끌 때까지 계속
var _left: float = INF
var _stopping: bool = false
var _wait: float = 0.0
var _line_wait: float = 0.0
## 스피드 라인 [x, y(머리 끝), 길이, 나이] — 몸 기준 좌표
var _lines: Array[Vector4] = []
## 스피드 라인을 그리는 판 — 맵에서 캐릭터 바로 앞 순서에 끼워 캐릭터 뒤에 그린다
var _line_layer: Node2D = null

func _ready() -> void:
	_cfg = KINDS.get(kind, KINDS[&"slow"])
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _exit_tree() -> void:
	if _line_layer != null and is_instance_valid(_line_layer):
		_line_layer.queue_free()

func _process(delta: float) -> void:
	if _has_target and is_instance_valid(_target):
		global_position = _target.global_position
	elif not _stopping:
		stop()
	_update_lines(delta)
	if _stopping:
		return
	_line_wait -= delta
	if _line_wait <= 0.0:
		_line_wait = randf_range(LINE_INTERVAL.x, LINE_INTERVAL.y)
		_add_line()
	_left -= delta
	if _left <= 0.0:
		stop()
		return
	_wait -= delta
	if _wait <= 0.0:
		var iv: Vector2 = _cfg["interval"]
		_wait = randf_range(iv.x, iv.y)
		_spawn_icon()

## fighter: 따라갈 캐릭터 / duration: 초(0 이하면 stop()까지 계속). 맵에 add_child 한 뒤 부를 것
func setup(fighter: Node2D, duration: float) -> void:
	_target = fighter
	_has_target = fighter != null
	if _has_target:
		global_position = fighter.global_position
	_left = INF if duration <= 0.0 else duration
	_line_layer = Node2D.new()
	_line_layer.draw.connect(_draw_lines)
	var parent := get_parent()
	if parent != null:
		parent.add_child(_line_layer)
		if _has_target and fighter.get_parent() == parent:
			_line_layer.z_index = fighter.z_index
			_line_layer.z_as_relative = fighter.z_as_relative
			parent.move_child(_line_layer, fighter.get_index())
	_line_layer.global_position = global_position

## 또 걸렸을 때 — 남은 시간은 둘 중 더 긴 쪽(짧은 효과가 긴 효과의 표시를 일찍 끄지 않게). 0 이하면 끝없이
func extend(duration: float) -> void:
	_left = INF if duration <= 0.0 else maxf(_left, duration)

## 더 만들지 않고, 떠 있는 아이콘이 다 사라지면 스스로 지운다
func stop() -> void:
	if _stopping:
		return
	_stopping = true
	# 라운드가 끝나 씬이 내려가는 중(트리 밖)이면 타이머를 못 돌린다 — 그냥 바로 지운다
	if not is_inside_tree():
		queue_free()
		return
	Timers.self_destruct(self, float(_cfg.get("life", 1.0)) + 0.1)

func is_stopping() -> bool:
	return _stopping

## 줄 하나 — 몸 양옆 중 한쪽에 생긴다(몸 한가운데는 어차피 몸에 가려서)
func _add_line() -> void:
	var side: float = -1.0 if randf() < 0.5 else 1.0
	_lines.append(Vector4(side * randf_range(LINE_SIDE_X.x, LINE_SIDE_X.y), randf_range(LINE_Y.x, LINE_Y.y),
		randf_range(LINE_LENGTH.x, LINE_LENGTH.y), 0.0))

## 줄을 dir 쪽으로 흘려보내고 수명이 다한 줄은 지운다
func _update_lines(delta: float) -> void:
	if _line_layer == null or not is_instance_valid(_line_layer):
		return
	_line_layer.global_position = global_position
	var dir: float = _cfg["dir"]
	for i in range(_lines.size() - 1, -1, -1):
		var l: Vector4 = _lines[i]
		l.y += dir * LINE_SPEED * delta
		l.w += delta
		if l.w >= LINE_LIFE:
			_lines.remove_at(i)
		else:
			_lines[i] = l
	_line_layer.queue_redraw()

## 줄 긋기 — 흐르는 쪽 끝(머리)은 진하고 꼬리는 투명. 생길 때·사라질 때 전체가 옅어진다
func _draw_lines() -> void:
	var color: Color = _cfg["line_color"]
	var dir: float = _cfg["dir"]
	for l in _lines:
		var fade: float = sin(clampf(l.w / LINE_LIFE, 0.0, 1.0) * PI)
		var head := Vector2(l.x, l.y)
		var tail := Vector2(l.x, l.y - dir * l.z)
		var mid := tail.lerp(head, 0.7)
		var c_head := Color(color, color.a * fade)
		var c_tail := Color(color, 0.0)
		_line_layer.draw_polyline_colors(PackedVector2Array([tail, mid, head]),
			PackedColorArray([c_tail, c_head, Color(c_head, c_head.a * 0.4)]), LINE_WIDTH, true)

## 몸 근처 아무 데서나 하나 생겨 dir 쪽으로 흘러가며 흐려진다. 톡 나타나도록 처음엔 작게 시작
func _spawn_icon() -> void:
	var tex: Texture2D = _cfg["texture"]
	var rect: Rect2 = _cfg["rect"]
	var s := Sprite2D.new()
	s.texture = tex
	# 보이는 영역의 중심이 노드 원점에 오게(캔버스가 넓고 그림이 한쪽에 치우쳐 있다)
	s.offset = tex.get_size() * 0.5 - rect.get_center()
	add_child(s)
	s.position = Vector2(randf_range(-SPAWN_HALF_WIDTH, SPAWN_HALF_WIDTH), randf_range(SPAWN_Y.x, SPAWN_Y.y))
	# 내려가는 아이콘(디버프)은 흘러갈 거리만큼 위에서 생긴다 — 그래야 올라가는 칼(버프)과
	# **같은 구간(가슴~머리 위)** 을 지나간다. 안 그러면 다리 쪽에만 보인다(2026-10-07 사용자 요청)
	if float(_cfg["dir"]) > 0.0:
		s.position.y -= float(_cfg["travel"])
	var full: float = float(_cfg["size"]) / maxf(rect.size.y, rect.size.x) * randf_range(0.85, 1.15)
	s.scale = Vector2.ONE * full * 0.4
	s.modulate.a = 0.0
	var life: float = _cfg["life"]
	var tw := s.create_tween().set_parallel()
	tw.tween_property(s, "scale", Vector2.ONE * full, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 1.0, 0.1)
	tw.tween_property(s, "position:y", s.position.y + float(_cfg["dir"]) * float(_cfg["travel"]), life) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 흘러가는 쪽으로 갈수록 투명해진다
	tw.tween_property(s, "modulate:a", 0.0, life * 0.75).set_delay(life * 0.25)
	tw.chain().tween_callback(s.queue_free)
