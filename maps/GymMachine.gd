@tool
class_name GymMachine
extends Sprite2D

## **헬스장 운동 기구** — 맵 전용 키로 운동하면 그 기구가 맡은 능력이 올라간다(기획서 21쪽).
##
## | 기구 | 올려주는 것 | `Fighter` 배수 |
## |---|---|---|
## | 바벨 컬 | 기본공격력 | `basic_attack_damage_multiplier` |
## | 스쿼트 | 점프력 | `jump_multiplier` |
## | 런닝머신 | 이동속도 | `move_speed_multiplier` |
##
## 기구는 **자리와 모양과 수치만 들고 있다** — 실제로 운동을 굴리는 건 맵 전용 스킬
## `skills/WorkoutSkill.gd`다(캐릭터마다 하나씩 붙는다). 그래야 두 선수가 같은 기구를
## 각자 쓸 수 있고, 맞아서 끊기는 처리도 맞은 쪽 스킬이 혼자 맡는다.
##
## **`Sprite2D`를 물려받는다**(2026-10-06). 그래야 에디터에서 네모 핸들을 끌어 크기를 잡고,
## 인스펙터에서 그림을 바로 갈아 끼울 수 있다. 예전에는 `_draw()`로 그려서 핸들이 안 잡혔다.
## 그림이 없으면 예전처럼 도형으로 그린다.
##
## 노드의 **원점이 바닥에 닿는 지점**이다 — 그림을 꽂으면 `offset`을 자동으로 맞춰
## 밑변 가운데가 원점에 오게 한다. `GymLayout`은 그래서 x만 섞으면 된다

enum Kind {
	CURL,      ## 바벨 컬 — 공격력
	SQUAT,     ## 스쿼트 랙 — 점프력
	TREADMILL, ## 런닝머신 — 이동속도
}

@export var kind: Kind = Kind.CURL:
	set(value):
		kind = value
		queue_redraw()
## 좌우 반전(`GymLayout`이 섞을 때 뒤집기도 한다)
@export var flip: bool = false:
	set(value):
		flip = value
		queue_redraw()
## 전체 크기 배율
@export var size_scale: float = 1.0:
	set(value):
		size_scale = value
		_fit_texture()
		queue_redraw()
## 그림 크기 배수. **이제는 노드 `scale`을 쓰는 게 낫다** — 에디터에서 핸들로 잡히기 때문이다.
## 예전 맵이 이 값을 들고 있어서 남겨 뒀고, 꽂아 둔 그림에만 곱해진다

@export_group("운동")
## 1초 운동하면 쌓이는 스펙.
## **바벨 컬은 두 번 왔다 갔다 하면 1씩 오른다**(한 번이 1.6초라 3.2초에 1 = 0.3125, 2026-10-05 사용자 지정)
@export var spec_per_second: float = 0.3125
## **이 기구 하나로 쌓을 수 있는 스펙 최대치.** 다 채우면 더 해도 안 오른다
@export var spec_max: float = 6.0
## 스펙 1당 배수가 얼마나 오르는지 — 기본값이면 꽉 채워서 x1.36
@export var gain_per_spec: float = 0.06
## **바닥보다 이만큼 더 내려놓는다(px).** 런닝머신은 사람이 벨트 위에 서야 해서,
## 벨트 윗면이 바닥 높이에 오도록 기구를 그만큼 묻는다(2026-10-05 사용자 지정).
## `GymLayout`이 자리를 잡을 때 이 값을 더한다
@export var ground_sink: float = 0.0
## **운동할 때 바라볼 방향**(-1 왼쪽 / +1 오른쪽). 0이면 예전처럼 기구 쪽을 본다.
## 런닝머신은 조작판이 왼쪽 끝에 있어서 **-1**이어야 조작판을 보고 달리는 모양이 된다
@export var face_dir: float = 0.0
## 운동하러 설 수 있는 범위(기구 중심에서 좌우·위아래 px).
## 위아래를 좁게 둬야 **2층 기구를 1층에서 쓰는** 일이 안 생긴다
@export var use_range_x: float = 80.0
@export var use_range_y: float = 70.0

@export_group("레일")
## **런닝머신 벨트 윗면**(기구 원점 기준 사각형). 여기에 줄무늬를 깔아 흐르게 한다.
## 기구 그림을 바꿨으면 이 네모를 그림의 벨트 자리에 맞춰 다시 잡을 것
@export var belt_rect: Rect2 = Rect2(-74.9, -37, 162.5, 6.2):
	set(value):
		belt_rect = value
		queue_redraw()
## 줄무늬 간격(px)과 굵기(px). 간격이 좁을수록 촘촘히 흐른다
@export var belt_gap: float = 13.0
@export var belt_width: float = 2.0
## 줄무늬 색
@export var belt_color: Color = Color(0.45, 0.47, 0.52, 0.9)
## 흐르는 빠르기(px/초). **음수면 오른쪽으로 흐른다** — 왼쪽을 보고 달리니 벨트는 뒤(오른쪽)로 간다
@export var belt_speed: float = -95.0
## 아무도 안 쓸 때도 돌릴지. 꺼 두면 **운동하는 사람이 있을 때만** 돈다
@export var belt_always: bool = false
## 줄무늬를 비스듬히 눕히는 정도(0이면 곧은 세로줄)
@export_range(0.0, 1.0, 0.05) var belt_slant: float = 0.35

@export_group("색")
## 기구 속을 채우는 색
@export var body_color: Color = Color(0.13, 0.13, 0.15, 1.0)
## **윤곽선은 밝게.** 배경이 어두워서 검은 선으로 그리면 녹아 버린다
@export var line_color: Color = Color(0.78, 0.8, 0.86, 1.0)
@export var line_width: float = 3.0
## 쇠붙이(봉·화면)에 쓰는 밝은 색
@export var metal_color: Color = Color(0.62, 0.65, 0.72, 1.0)
## 기구마다 다른 상징색 — 게이지와 포인트에 쓴다(한눈에 구분되라고)
@export var accent_curl: Color = Color(1.0, 0.45, 0.35, 1.0)
@export var accent_squat: Color = Color(0.45, 0.85, 1.0, 1.0)
@export var accent_treadmill: Color = Color(0.55, 1.0, 0.55, 1.0)
## 발밑 그림자 진하기(0이면 안 그린다)
@export var shadow_alpha: float = 0.22

## 지금 누가 이 기구에서 운동하는 중이면 채운 비율(0~1), 아니면 -1.
## `WorkoutSkill`이 매 프레임 넣어 준다 — 기구는 받아서 게이지만 그린다
var _gauge: float = -1.0

## 레일이 흘러간 거리 — 간격 하나만큼 가면 처음으로 되돌려 끝없이 돈다
var _belt_offset: float = 0.0

## 그림의 **밑변 가운데**가 노드 원점에 오게 맞춘다. 기구는 바닥에 서는 물건이라
## 원점이 발밑이어야 자리를 섞을 때 x만 바꾸면 된다
func _fit_texture() -> void:
	if texture == null:
		return
	centered = false
	var size: Vector2 = texture.get_size() * size_scale
	offset = Vector2(-size.x * 0.5, -size.y) / maxf(size_scale, 0.0001)
	# 그림 자체의 배수는 scale에 곱해 넣는다 — 핸들로 잡은 크기와 같이 먹는다
	queue_redraw()

func _ready() -> void:
	_fit_texture()
	if Engine.is_editor_hint():
		return
	# 운동 스킬이 이 그룹으로 기구를 찾는다(기구마다 Area2D를 두는 것보다 가볍다)
	add_to_group(WorkoutSkill.MACHINE_GROUP)

## 레일을 흘린다 — 런닝머신이 아니면 아무 일도 안 한다
func _process(delta: float) -> void:
	if kind != Kind.TREADMILL or belt_speed == 0.0 or belt_rect.size.x <= 0.0:
		return
	if not belt_always and _gauge < 0.0 and not Engine.is_editor_hint():
		return
	_belt_offset = fposmod(_belt_offset + belt_speed * delta, maxf(belt_gap, 1.0))
	queue_redraw()

## 이 기구가 올려주는 `Fighter`의 배수 이름
func stat_property() -> String:
	match kind:
		Kind.SQUAT:
			return "jump_multiplier"
		Kind.TREADMILL:
			return "move_speed_multiplier"
		_:
			# **기본공격 전용 배수다**(2026-10-02 사용자 확인) — `attack_debuff_multiplier`를 쓰면
			# `compute_damage`를 지나는 스킬 피해까지 같이 세진다
			return "basic_attack_damage_multiplier"

## 쌓인 스펙을 적어 두는 이름표(`Fighter.custom_data["gym_spec"]`의 열쇠).
## 같은 종류의 기구가 맵에 둘 있어도 **스펙은 한 칸에 합쳐 쌓인다**
func spec_key() -> String:
	match kind:
		Kind.SQUAT:
			return "squat"
		Kind.TREADMILL:
			return "treadmill"
		_:
			return "curl"

## 운동할 때 커지는 몸 부위 — `BodyRig`에 알려 주면 그 부위가 부푼다(기획서 "한눈에 보임")
func muscle_part() -> String:
	return "arm" if kind == Kind.CURL else "leg"

## 이 기구를 쓸 수 있는 자리에 있는지
func in_range(point: Vector2) -> bool:
	var d: Vector2 = point - global_position
	# **바닥에 묻어 둔 만큼은 빼고 잰다** — 기구를 내렸다고 운동할 수 있는 자리까지
	# 같이 내려가면, 런닝머신 앞에 서 있어도 범위 밖이 되어 버린다
	d.y += ground_sink
	# ⚠️ 예전엔 `use_range_x * size_scale`로 쟀는데, 그건 **도형으로 그리던 시절**(size_scale 1.0)에
	# 맞춰 둔 식이다. 그림을 꽂으면서 size_scale이 0.15쯤으로 내려가자 범위까지 1/7로 줄어
	# 기구 바로 앞에 서도 운동이 안 됐다(2026-10-05). 이제 **노드 크기**만 반영한다
	return absf(d.x) <= use_range_x * absf(scale.x) and absf(d.y) <= use_range_y * absf(scale.y)

## 게이지를 갱신한다(-1이면 아무도 안 쓰는 중)
func set_gauge(ratio: float) -> void:
	if is_equal_approx(_gauge, ratio):
		return
	_gauge = ratio
	queue_redraw()

func accent() -> Color:
	match kind:
		Kind.SQUAT:
			return accent_squat
		Kind.TREADMILL:
			return accent_treadmill
		_:
			return accent_curl

## 좌우로 차지하는 폭 — 자리를 섞을 때 서로 안 겹치게 재는 값.
## **그림을 쓰면 그림 폭을 그대로 쓴다** — 도형 시절 숫자를 그대로 두면 그림과 따로 놀아
## 기구끼리 겹치거나 쓸데없이 멀어진다(2026-10-06)
func width() -> float:
	if texture != null:
		return texture.get_size().x * size_scale
	match kind:
		Kind.SQUAT:
			return 190.0 * size_scale
		Kind.TREADMILL:
			return 210.0 * size_scale
		_:
			return 180.0 * size_scale

## 꼭대기 높이(원점 기준, 음수) — 게이지를 그 위에 띄운다.
## 그림은 바닥(원점)에서 위로 그려지므로 그림 높이가 곧 꼭대기다
func top_offset() -> float:
	if texture != null:
		return -texture.get_size().y * size_scale
	match kind:
		Kind.SQUAT:
			return -150.0 * size_scale
		Kind.TREADMILL:
			return -112.0 * size_scale
		_:
			return -70.0 * size_scale

func _draw() -> void:
	if shadow_alpha > 0.0:
		# 바닥에 닿은 자리에 납작한 그림자 — 없으면 떠 보인다
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.22))
		draw_circle(Vector2(0.0, -9.0), width() * 0.4, Color(0, 0, 0, shadow_alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if texture == null:
		# 그림이 없을 때만 도형으로 그린다. 그림이 있으면 Sprite2D가 알아서 그린다
		match kind:
			Kind.CURL:
				_draw_curl()
			Kind.SQUAT:
				_draw_squat()
			Kind.TREADMILL:
				_draw_treadmill()
	if kind == Kind.TREADMILL:
		_draw_belt()
	_draw_gauge()

## **바벨 컬** — 낮은 거치대에 바벨이 얹혀 있다. 들어 올려 팔을 키우는 기구
func _draw_curl() -> void:
	var s: float = size_scale
	var d: float = -1.0 if flip else 1.0
	# 거치대 — 벌어진 다리 둘
	_bar(Vector2(-34 * s * d, 0), Vector2(-16 * s * d, -50 * s), 9.0 * s, body_color)
	_bar(Vector2(34 * s * d, 0), Vector2(16 * s * d, -50 * s), 9.0 * s, body_color)
	_bar(Vector2(-22 * s * d, -26 * s), Vector2(22 * s * d, -26 * s), 7.0 * s, body_color)
	# 거치대에 얹힌 바벨
	_plate_bar(-62.0 * s, 62.0 * s, -58.0 * s, 18.0 * s, 5.0 * s)

## **스쿼트 랙** — 기둥 둘 사이에 봉이 높이 걸려 있다. 메고 앉았다 서며 다리를 키우는 기구
func _draw_squat() -> void:
	var s: float = size_scale
	# 기둥 둘 + 받침
	for x in [-52.0, 52.0]:
		_bar(Vector2(x * s, 0), Vector2(x * s, -148 * s), 12.0 * s, body_color)
		_bar(Vector2((x - 20.0) * s, -4 * s), Vector2((x + 20.0) * s, -4 * s), 10.0 * s, body_color)
		# 봉을 받치는 갈고리
		_bar(Vector2(x * s, -120 * s), Vector2((x + (14.0 if x > 0.0 else -14.0)) * s, -128 * s), 7.0 * s, metal_color)
	# 어깨에 메는 봉
	_plate_bar(-86.0 * s, 86.0 * s, -124.0 * s, 22.0 * s, 6.0 * s)

## **런닝머신** — 비스듬한 발판과 손잡이·화면. 달려서 발을 빠르게 만드는 기구
func _draw_treadmill() -> void:
	var s: float = size_scale
	var d: float = -1.0 if flip else 1.0
	# 달리는 판 — 앞이 살짝 들려 있다
	var belt_back := Vector2(-78 * s * d, -26 * s)
	var belt_front := Vector2(70 * s * d, -40 * s)
	_bar(belt_back, belt_front, 16.0 * s, body_color)
	draw_line(belt_back, belt_front, metal_color, 4.0 * s, true)
	# 받침 다리
	_bar(Vector2(-62 * s * d, -22 * s), Vector2(-62 * s * d, 0), 9.0 * s, body_color)
	_bar(Vector2(58 * s * d, -36 * s), Vector2(58 * s * d, 0), 9.0 * s, body_color)
	# 손잡이 기둥과 화면
	var post_top := Vector2(74 * s * d, -104 * s)
	_bar(Vector2(66 * s * d, -38 * s), post_top, 10.0 * s, body_color)
	var screen := Rect2(post_top + Vector2(-26 * s * d if d > 0.0 else 2 * s, -18 * s), Vector2(26 * s, 20 * s))
	draw_rect(screen, body_color)
	draw_rect(screen, line_color, false, line_width)
	draw_rect(screen.grow(-5.0 * s), accent_treadmill)
	# 손잡이 — 달릴 때 잡는 가로 막대
	_bar(post_top, post_top + Vector2(-34 * s * d, 6 * s), 7.0 * s, metal_color)

## **흐르는 레일** — 벨트 네모 안에 줄무늬를 일정 간격으로 긋고, 그 간격만큼 흘렀으면
## 처음으로 되돌려 끝없이 도는 것처럼 보이게 한다. 네모 밖으로는 안 그린다
func _draw_belt() -> void:
	var rect: Rect2 = belt_rect
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var gap: float = maxf(belt_gap, 1.0)
	var slant: float = rect.size.y * belt_slant
	var x: float = rect.position.x - _belt_offset
	while x <= rect.end.x:
		# 줄무늬 한 줄 — 위가 앞서고 아래가 뒤처지게 눕혀서 돌아가는 맛을 낸다
		var top := Vector2(x + slant, rect.position.y)
		var bottom := Vector2(x, rect.end.y)
		# 네모 밖으로 삐져나오는 줄은 건너뛴다(클리핑 대신 가장자리만 거른다)
		if top.x >= rect.position.x and bottom.x <= rect.end.x:
			draw_line(top, bottom, belt_color, belt_width, true)
		x += gap

## 운동 게이지 — 기구 위에 뜨는 가느다란 막대. 아무도 안 쓰면 안 그린다
func _draw_gauge() -> void:
	if _gauge < 0.0:
		return
	var w: float = 76.0 * size_scale
	var h: float = 9.0
	var y: float = top_offset() - 26.0
	var box := Rect2(-w * 0.5, y, w, h)
	draw_rect(box.grow(2.0), Color(0, 0, 0, 0.6))
	draw_rect(box, Color(0.18, 0.18, 0.2, 0.9))
	draw_rect(Rect2(box.position, Vector2(w * clampf(_gauge, 0.0, 1.0), h)), accent())
	draw_rect(box, line_color, false, 2.0)

## 원판 둘 달린 봉 하나 (바벨·스쿼트 봉이 같은 모양이라 한 곳에 모았다)
func _plate_bar(x0: float, x1: float, y: float, plate_r: float, bar_w: float) -> void:
	draw_line(Vector2(x0, y), Vector2(x1, y), metal_color, bar_w, true)
	for x in [x0 + plate_r * 0.6, x1 - plate_r * 0.6]:
		draw_circle(Vector2(x, y), plate_r, body_color)
		draw_arc(Vector2(x, y), plate_r, 0.0, TAU, 22, line_color, line_width, true)

## 윤곽선이 있는 굵은 막대 하나. 기구는 전부 막대와 원의 조합이라 이것만 있으면 된다
func _bar(from: Vector2, to: Vector2, thickness: float, color: Color) -> void:
	draw_line(from, to, line_color, thickness + line_width * 2.0, true)
	draw_line(from, to, color, thickness, true)
