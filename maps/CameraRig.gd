class_name CameraRig
extends Camera2D

## 두 파이터의 중간 지점을 부드럽게 따라가는 카메라.
## 맵에 LeftWall/RightWall이 있으면 그 바깥면을 카메라 한계선으로 잡아, 벽 너머(배경 끝, 빈 공간)가
## 화면에 들어오지 않게 한다
@export var follow_speed: float = 4.0
@export var min_y: float = 100.0
@export var max_y: float = 250.0
## 켜면 화면 아래로 보이는 흙(지면 아래) 두께를 **배율과 상관없이** ground_margin_px로 고정한다.
## 끄면(기본) 예전처럼 min_y/max_y만 본다 — 이 스크립트를 쓰는 다른 맵들은 그대로다.
## 넓은 맵(놀이터)은 캐릭터가 멀어지면 화면을 0.65배까지 물리는데, max_y가 고정값이면
## 물릴수록 화면 반 높이가 월드에서 길어져서 아래 흙이 100px에서 190px까지 두꺼워진다
@export var lock_ground_to_bottom: bool = false
## 지면 윗면 y (lock_ground_to_bottom일 때만 쓴다)
@export var ground_y: float = 280.0
## 지면 아래로 화면에 남겨둘 흙 두께(화면 px, lock_ground_to_bottom일 때만 쓴다)
@export var ground_margin_px: float = 56.0
## 벽 바깥이 안 보이도록 카메라 이동 범위를 제한할지. 벽이 없는 링아웃형 맵에서는 꺼도 된다
@export var clamp_to_walls: bool = true
## 한계선을 벽 바깥면에서 더 안쪽으로 당기고 싶을 때 쓰는 여유 폭(px)
@export var wall_margin: float = 0.0
## 1.0이면 벽 사이가 화면에 딱 맞아서(= 벽 밖이 절대 안 보이는 최소 배율) 카메라가 좌우로 전혀 안 움직인다.
## 1보다 키우면 그만큼 더 확대되는 대신 좌우로 따라다닐 여유가 생긴다 (1.1이면 벽 사이 폭의 약 9%)
@export_range(1.0, 2.0, 0.01) var extra_zoom: float = 1.0
## 두 캐릭터 사이가 벌어지면 화면을 물리고, 붙으면 당길지.
## 단 물러날 수 있는 한계는 "벽 밖이 안 보이는 배율"까지다 (_min_zoom)
@export var dynamic_zoom: bool = true
## 두 캐릭터 바깥으로 남겨둘 여유(px). 캐릭터가 화면 가장자리에 딱 붙지 않게 한다
@export var zoom_margin: Vector2 = Vector2(240.0, 170.0)
## 붙어 있을 때 기본 배율의 몇 배까지 당길지. 1.0(기본)이면 당기지 않고 멀어질 때 물러나기만 한다.
## 벽 사이가 화면보다 좁아서 애초에 물러날 여지가 없는 맵(지하철 승강장)에서만 1보다 크게 줘서
## "붙으면 당겼다가 멀어지면 원위치"로 만든다 — 넓은 맵에서 이 값을 올리면 지면이 화면 밖으로 밀려난다
@export_range(1.0, 3.0, 0.05) var max_close_zoom: float = 1.0
## 배율이 목표값을 따라가는 속도 (클수록 빠르다)
@export var zoom_speed: float = 3.0
## 흔들림이 초당 이만큼 잦아든다 (클수록 빨리 멈춘다)
@export var shake_decay: float = 3.0
## 흔들림이 최대(trauma 1.0)일 때 화면이 흔들리는 폭(px)
@export var shake_max_offset: float = 12.0

## 현재 흔들림 세기 0~1 — 타격이 들어오면 데미지에 비례해 쌓이고, 매 프레임 감쇠한다
var _trauma: float = 0.0
## 씬에 저장돼 있던 원래 배율
var _authored_zoom: float = 1.0
## 가장 많이 물러날 수 있는 배율. 이보다 작아지면(= 더 넓게 보면) 벽 밖이 화면에 들어온다.
## 벽 사이가 화면보다 넓은 맵(놀이터)에서는 1.0보다 작아지고, 좁은 맵에서는 1.0보다 커진다
var _min_zoom: float = 1.0
## 두 캐릭터가 붙어 있을 때 가장 많이 당기는 배율
var _max_zoom: float = 1.0

func _ready() -> void:
	# 타격 판정(Hitbox)이 찾아서 흔들 수 있도록 그룹에 등록한다
	add_to_group("game_camera")
	_authored_zoom = zoom.x
	_min_zoom = _authored_zoom
	_max_zoom = _authored_zoom * max_close_zoom
	if not clamp_to_walls:
		return
	_apply_wall_limits()
	# 창 크기가 바뀌면 보이는 폭도 바뀌므로(stretch aspect가 expand라서) 그때마다 다시 계산한다
	get_viewport().size_changed.connect(_apply_wall_limits)

func _process(delta: float) -> void:
	var fighters := get_tree().get_nodes_in_group("fighters")
	if fighters.size() >= 2:
		var a: Vector2 = fighters[0].global_position
		var b: Vector2 = fighters[1].global_position
		var mid: Vector2 = (a + b) / 2.0
		mid.y = clampf(mid.y, min_y, _lowest_center_y())
		global_position = global_position.lerp(mid, follow_speed * delta)
		_update_zoom(a, b, delta)
	_apply_shake(delta)

## 카메라 중심이 내려갈 수 있는 가장 아래 y.
## lock_ground_to_bottom이면 "지면이 화면 아래에서 ground_margin_px 위에 오는 위치"를 **지금 배율로** 계산한다 —
## 배율이 작을수록(멀리 볼수록) 화면 반 높이가 월드에서 길어지므로 중심을 그만큼 더 올려야 한다.
## max_y는 여전히 넘지 않는다(가까이 당겼을 때 계산값이 max_y보다 아래로 가도 max_y에서 멈춤)
func _lowest_center_y() -> float:
	if not lock_ground_to_bottom:
		return max_y
	var half_h: float = get_viewport_rect().size.y * 0.5
	var y: float = ground_y - (half_h - ground_margin_px) / maxf(zoom.y, 0.01)
	return clampf(y, min_y, max_y)

## 두 캐릭터가 다 들어오는 배율을 구해서 부드럽게 따라간다.
## _min_zoom(벽 밖이 안 보이는 한계 배율)보다 더 물러나지는 않는다 — 더 넓게 보면 벽 너머가 드러난다.
## 벽 사이가 화면보다 좁은 맵은 한계 배율이 1보다 커서 "붙었을 때 당겼다가 원래대로 돌아오는" 모양이 되고,
## 넓은 맵(놀이터)은 한계 배율이 1보다 작아서 실제로 뒤로 물러난다.
## 세로 간격(점프)도 같이 보므로 한쪽이 높이 뛰어도 프레임 밖으로 나가지 않는다
func _update_zoom(a: Vector2, b: Vector2, delta: float) -> void:
	if not dynamic_zoom:
		return
	var view: Vector2 = get_viewport_rect().size
	var needed: Vector2 = (a - b).abs() + zoom_margin * 2.0
	var fit: float = minf(view.x / maxf(needed.x, 1.0), view.y / maxf(needed.y, 1.0))
	var target: float = clampf(fit, _min_zoom, _max_zoom)
	var next: float = lerpf(zoom.x, target, clampf(zoom_speed * delta, 0.0, 1.0))
	zoom = Vector2(next, next)

## 타격 세기(trauma)를 더한다 — Hitbox가 명중 시 데미지에 비례해서 호출한다
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

## 화면(offset)을 랜덤으로 흔들고 trauma를 서서히 줄인다. trauma가 0이면 offset을 원위치로 되돌린다
func _apply_shake(delta: float) -> void:
	if _trauma <= 0.0:
		if offset != Vector2.ZERO:
			offset = Vector2.ZERO
		return
	_trauma = maxf(_trauma - shake_decay * delta, 0.0)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_max_offset * _trauma

## 좌우 벽의 바깥면을 찾아 카메라 한계선(limit_left/right)으로 설정한다.
## 벽 사이 폭이 화면 폭보다 좁으면 한계선만으로는 화면이 벽 밖을 물게 되므로,
## 벽 사이가 화면에 딱 맞을 만큼만 확대(zoom)해서 그 문제를 없앤다
func _apply_wall_limits() -> void:
	var left: float = _wall_edge("LeftWall", -1.0)
	var right: float = _wall_edge("RightWall", 1.0)
	if is_nan(left) or is_nan(right):
		return
	left += wall_margin
	right -= wall_margin
	var span: float = right - left
	if span <= 0.0:
		return
	var view_width: float = get_viewport_rect().size.x
	# 벽 사이가 화면에 꽉 차는 배율 = 벽 밖이 드러나기 직전, 즉 가장 많이 물러날 수 있는 한계
	_min_zoom = view_width / span * extra_zoom
	# 당기는 상한은 씬에 저장된 배율과 한계 배율 중 큰 쪽을 기준으로 잡는다
	_max_zoom = maxf(_authored_zoom, _min_zoom) * max_close_zoom
	var clamped: float = clampf(zoom.x, _min_zoom, _max_zoom)
	zoom = Vector2(clamped, clamped)
	limit_left = int(floorf(left))
	limit_right = int(ceilf(right))

## 벽 StaticBody2D의 바깥쪽 면 x좌표를 돌려준다.
## dir이 -1이면 왼쪽 벽의 왼쪽 면, 1이면 오른쪽 벽의 오른쪽 면. 벽이 없으면 NAN
func _wall_edge(node_name: String, dir: float) -> float:
	var parent := get_parent()
	if parent == null:
		return NAN
	var wall := parent.get_node_or_null(node_name) as Node2D
	if wall == null:
		return NAN
	var half_width: float = 0.0
	for child in wall.get_children():
		var collision := child as CollisionShape2D
		if collision == null:
			continue
		var rect := collision.shape as RectangleShape2D
		if rect == null:
			continue
		half_width = maxf(half_width, rect.size.x * 0.5 * absf(collision.global_scale.x))
	return wall.global_position.x + dir * half_width
