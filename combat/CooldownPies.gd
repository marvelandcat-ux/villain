extends Node2D

## 방어·대시 쿨타임을 캐릭터 등 뒤(바라보는 방향 반대편)에 작은 원형 파이로 보여준다.
## 기본공격이 방어에 막혀 잠긴 동안은 같은 슬롯에 빨간 X가 뜨고, 풀릴수록 빨간 부분이 위에서 아래로 줄어든다.
## 쿨이 도는 동안만 보이고, 다시 쓸 수 있게 될수록 12시 방향부터 시계 방향으로 차오른다
## (HUD 스킬 아이콘처럼 "차오르면 준비 완료"). 다 차면 살짝 커졌다가 사라진다.
## **슬롯:** 먼저 쿨이 시작된 것이 1번 슬롯(맨 위), 그 사이에 시작된 것은 아래 2번 슬롯에 쌓인다.
## 위의 것이 끝나면 아래 것이 위로 미끄러져 올라간다.
## Fighter의 자식으로 붙는다 — Fighter 루트는 좌우로 안 뒤집히므로(뒤집히는 건 Visual) facing을 보고 직접 반대편에 놓는다.
## 그림 파일 없이 코드로 그린다. 부채꼴은 draw_primitive 삼각형으로 — 다각형 하나로 그리면
## 비율이 0 근처일 때 "triangulation failed"가 쏟아진다(CLAUDE.md 참고)

## 1번 슬롯 원의 중심(캐릭터 원점 기준). x는 등 쪽으로 떨어진 거리라 양수로 둔다 — 바라보는 방향의 반대편에 놓이게
## facing 부호를 곱해 쓴다. y는 가슴 높이
@export var offset: Vector2 = Vector2(42, -22)
## 슬롯 사이 세로 간격(px). 다음 슬롯은 이만큼 아래
@export var slot_spacing: float = 19.0
## 방향을 바꿀 때 반대편으로 옮겨 가는 빠르기(클수록 빠름). 0이면 바로 건너뛴다
@export var side_follow_speed: float = 18.0
## 슬롯이 비어 위로 올라갈 때의 빠르기
@export var slot_follow_speed: float = 14.0
## 반지름(px)
@export var radius: float = 8.0
## 바탕(아직 안 찬 부분) 색
@export var back_color: Color = Color(0.1, 0.12, 0.18, 0.55)
## 방어 파이 색 — 보호막과 같은 하늘색
@export var guard_color: Color = Color(0.55, 0.85, 1.0, 0.95)
## 대시 파이 색 — 라임
@export var dash_color: Color = Color(0.7, 1.0, 0.2, 0.95)
## 기본공격 잠금 X 색 — 막힌 무기가 깜빡이는 빨강
@export var blocked_color: Color = Color(1.0, 0.2, 0.2, 0.95)
## **궁극기를 쓰는 중 남은 시간** 색 — 방어(하늘)·대시(라임)·잠금(빨강) 어느 것과도 안 겹치는 금색.
## 이 칸은 **지속형 궁(지하철 아저씨 쌍 악기, 경찰 경관봉)이 돌아가는 동안에만** 뜬다
@export var ultimate_active_color: Color = Color(1.0, 0.82, 0.25, 0.95)
## 궁극기 **쿨타임**까지 보여줄지. **기본은 끔** — 쿨타임은 HUD 스킬 칸이 이미 차오르며 보여 주므로
## 여기까지 뜨면 라운드 내내 칸 하나가 붙박이로 떠 있게 된다(2026-10-02 사용자 요청)
@export var show_ultimate_cooldown: bool = false
## 쿨타임까지 켰을 때 쓰는 색(보라). 끈 상태면 안 쓰인다
@export var ultimate_color: Color = Color(0.78, 0.36, 1.0, 0.95)
## X 팔 하나의 길이(중심에서 끝까지)·반 굵기(px). 끝까지 높이 = (길이 + 반 굵기) / √2 — 기본값이면 원 반지름과 비슷
@export var x_arm_length: float = 8.5
@export var x_arm_half_width: float = 2.8
## 테두리 색·굵기 (밝은 배경에서도 보이게)
@export var edge_color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var edge_width: float = 1.5
## 다 찼을 때 커졌다 사라지는 시간(초)
@export var ready_pop_time: float = 0.25

## 표시할 쿨타임 하나 — Fighter에서 비율을 읽어 올 메서드 이름과 색
class Pie:
	var method: String
	var color: Color
	var ratio: float = 0.0
	var pop_left: float = 0.0
	var cooling: bool = false
	## 지금 그려지는 슬롯 위치(0 = 1번 슬롯). 목표 슬롯으로 미끄러진다
	var slot_pos: float = 0.0
	## true면 원 대신 X 모양(기본공격 잠금)
	var cross: bool = false

	func _init(m: String, c: Color, is_cross := false) -> void:
		method = m
		color = c
		cross = is_cross

## 모든 파이 / 지금 화면에 떠 있는 파이(쿨이 먼저 시작된 순서 = 슬롯 순서)
var _pies: Array[Pie] = []
var _shown: Array[Pie] = []
## 지금 놓인 쪽(-1 = 왼쪽, 1 = 오른쪽). 방향을 바꾸면 반대편으로 미끄러져 간다
var _side: float = -1.0
## 맵 암전(`Blackout.gd`) 중이면 true — 방어·대시·빨간 X(패링 잠금)·금색(궁 쓰는 중)을 전부 숨긴다
var _blackout_hidden: bool = false

func _ready() -> void:
	z_index = 6   # 보호막(5)보다 앞
	visible = false
	add_to_group("cooldown_pies")
	# 맵 조명(CanvasModulate·PointLight2D)에 안 어두워지게 — 어느 맵에서든 같은 색으로 보이는 UI
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	_pies = [Pie.new("guard_cooldown_ratio", guard_color), Pie.new("dash_cooldown_ratio", dash_color),
		Pie.new("ultimate_timer_ratio", ultimate_color),
		Pie.new("blocked_attack_ratio", blocked_color, true)]

func _process(delta: float) -> void:
	var fighter := get_parent()
	if fighter == null:
		return
	# 타이틀 구경 모드는 HUD를 다 숨기므로 이것도 숨긴다
	if GameState.game_mode == "attract":
		visible = false
		return
	var target_side: float = -signf(fighter.facing) if fighter.facing != 0.0 else _side
	if not visible or side_follow_speed <= 0.0:
		_side = target_side   # 숨어 있다 나타날 땐 처음부터 등 뒤에
	else:
		_side = lerpf(_side, target_side, 1.0 - exp(-side_follow_speed * delta))

	for pie in _pies:
		if not fighter.has_method(pie.method):
			continue
		var ratio: float = fighter.call(pie.method)
		# 궁극기 칸은 **지속형 궁이 돌아가는 동안** 남은 시간이 줄어드는 걸 보여 준다(금색).
		# 쿨타임까지 켜 뒀을 때만 차오르는 보라가 따로 뜬다
		if pie.method == "ultimate_timer_ratio":
			var using: bool = fighter.has_method("ultimate_active_ratio") and fighter.ultimate_active_ratio() >= 0.0
			pie.color = ultimate_active_color if using else ultimate_color
			if not using and not show_ultimate_cooldown:
				ratio = 1.0
		var cooling: bool = ratio < 1.0
		if cooling:
			if not pie.cooling and not _shown.has(pie):
				# 새로 쿨이 시작됨 — 맨 아래 빈 슬롯에 바로 나타난다
				pie.slot_pos = float(_shown.size())
				_shown.append(pie)
			pie.ratio = ratio
			pie.pop_left = 0.0
		elif pie.cooling:
			pie.ratio = 1.0
			pie.pop_left = ready_pop_time
		pie.cooling = cooling
		if pie.pop_left > 0.0:
			pie.pop_left = maxf(pie.pop_left - delta, 0.0)
	# 다 끝난 파이를 빼고, 남은 것들은 위로 미끄러져 슬롯을 채운다
	_shown = _shown.filter(func(p: Pie) -> bool: return p.cooling or p.pop_left > 0.0)
	var drawn := _drawn_pies()
	var k: float = 1.0 - exp(-slot_follow_speed * delta)
	for i in drawn.size():
		drawn[i].slot_pos = lerpf(drawn[i].slot_pos, float(i), k)
	visible = not drawn.is_empty()
	if visible:
		queue_redraw()

func _draw() -> void:
	for pie in _drawn_pies():
		_draw_pie(pie)

## 암전이 시작/끝날 때 `Blackout.gd`가 그룹 호출로 부른다
func set_blackout_hidden(value: bool) -> void:
	_blackout_hidden = value

## 지금 실제로 그릴 파이들 — 암전 중엔 궁 지속시간(금색)까지 전부 숨긴다(2026-10-07 사용자 요청)
func _drawn_pies() -> Array[Pie]:
	if not _blackout_hidden:
		return _shown
	var out: Array[Pie] = []
	return out

func _draw_pie(pie: Pie) -> void:
	var center := Vector2(offset.x * _side, offset.y + pie.slot_pos * slot_spacing)
	var r: float = radius
	var alpha: float = 1.0
	if pie.pop_left > 0.0:
		# 다 찬 순간: 1 -> 1.4배로 커지며 흐려진다
		var t: float = 1.0 - pie.pop_left / maxf(ready_pop_time, 0.001)
		r *= 1.0 + 0.4 * t
		alpha = 1.0 - t
	if pie.cross:
		_draw_cross(pie, center, r / radius, alpha)
		return
	var back := back_color
	back.a *= alpha
	draw_circle(center, r, back)
	if pie.ratio > 0.001:
		var fill := pie.color
		fill.a *= alpha
		_draw_sector(center, r, pie.ratio, fill)
	var edge := edge_color
	edge.a *= alpha
	draw_arc(center, r, 0.0, TAU, 32, edge, edge_width, true)

## 12시 방향부터 시계 방향으로 ratio만큼의 부채꼴을 삼각형 조각으로 칠한다
func _draw_sector(center: Vector2, r: float, ratio: float, color: Color) -> void:
	var steps: int = maxi(2, int(ceil(32.0 * ratio)))
	var start: float = -PI * 0.5
	var sweep: float = TAU * ratio
	var prev := center + Vector2(cos(start), sin(start)) * r
	for i in range(1, steps + 1):
		var a: float = start + sweep * float(i) / float(steps)
		var p := center + Vector2(cos(a), sin(a)) * r
		draw_primitive(PackedVector2Array([center, prev, p]), PackedColorArray([color, color, color]), PackedVector2Array())
		prev = p

## X 표시: 어두운 바탕 X 위에 빨간 X를 그리되, ratio만큼 위쪽을 잘라 낸다(풀릴수록 빨강이 아래로 내려감).
## X 외곽선 12점은 가운데에서 보면 별 모양(어디서 봐도 가려지지 않음)이라 가운데 기준 삼각형 부채로 칠할 수 있다
func _draw_cross(pie: Pie, center: Vector2, scale_k: float, alpha: float) -> void:
	var outline := _cross_outline(center, scale_k)
	var back := back_color
	back.a *= alpha
	var fill := pie.color
	fill.a *= alpha
	var half_h: float = (x_arm_length + x_arm_half_width) * scale_k / sqrt(2.0)
	var cut_y: float = center.y - half_h + 2.0 * half_h * pie.ratio
	for i in outline.size():
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		_draw_poly_fan(PackedVector2Array([center, a, b]), back)
		if pie.ratio < 0.999:
			_draw_poly_fan(_clip_below(PackedVector2Array([center, a, b]), cut_y), fill)
	var edge := edge_color
	edge.a *= alpha
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, edge, edge_width, true)

## X 외곽선 12점 — 팔 넷(대각선 방향)마다 끝 모서리 둘 + 팔 사이 안쪽 꺾인 점 하나
func _cross_outline(center: Vector2, scale_k: float) -> PackedVector2Array:
	var arm: float = x_arm_length * scale_k
	var w: float = x_arm_half_width * scale_k
	var pts := PackedVector2Array()
	for k in 4:
		var theta: float = -PI * 0.25 + PI * 0.5 * float(k)
		var u := Vector2(cos(theta), sin(theta))
		var p := Vector2(-u.y, u.x)
		pts.append(center + u * arm - p * w)
		pts.append(center + u * arm + p * w)
		pts.append(center + Vector2(cos(theta + PI * 0.25), sin(theta + PI * 0.25)) * w * sqrt(2.0))
	return pts

## 볼록 다각형에서 y >= cut_y 부분만 남긴다(가로선 한 줄로 자르기)
func _clip_below(poly: PackedVector2Array, cut_y: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var a_in: bool = a.y >= cut_y
		var b_in: bool = b.y >= cut_y
		if a_in:
			out.append(a)
		if a_in != b_in:
			var t: float = (cut_y - a.y) / (b.y - a.y)
			out.append(a.lerp(b, t))
	return out

## 볼록 다각형을 첫 점 기준 삼각형들로 칠한다(점이 3개 미만이면 안 그림)
func _draw_poly_fan(poly: PackedVector2Array, color: Color) -> void:
	for i in range(1, poly.size() - 1):
		draw_primitive(PackedVector2Array([poly[0], poly[i], poly[i + 1]]), PackedColorArray([color, color, color]), PackedVector2Array())
