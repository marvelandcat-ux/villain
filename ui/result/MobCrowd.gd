extends Node2D

## 연행 장면 구경꾼 무리 — **얼굴 없는 몸 테두리**(2026-10-08 사용자: "사람이 많이 있다는 효과").
## 게임 캐릭터와 같은 체형(큰 동그란 머리 + 사다리꼴 몸 + 작은 발)을 흰 바탕 + 검은 테두리로만 그리고 얼굴은 비운다.
## 로스터 캐릭터 구경꾼(리그) 사이사이와 뒤에 깔려 무리를 이룬다.
##  - 원근은 ArrestScene과 같은 카메라로 투영한다(장면이 매 프레임 값을 넣는다) — 멀수록 작고, 흐리고, 테두리가 얇다
##  - 리미티드 애니: 숨쉬듯 들썩임 + 가끔 수군거리듯 폴짝, 머리가 연행 쪽(왼쪽)으로 살짝 쏠린다
##  - 수십 명을 **그리기 한 번**(LineMesh)으로 그린다 — draw_* 를 사람마다 부르면 프레임이 떨어진다
## class_name을 일부러 안 단다 — 장면이 set_script로 붙인다

const LineMesh = preload("res://ui/result/LineMesh.gd")

var vanish_x: float = 760.0
var horizon_y: float = 470.0
var camera_height: float = 0.62
var focal: float = 1500.0
var dolly: float = 0.0
## 실제 시간(초)
var time: float = 0.0

## 가까운 사람의 바탕색들(사람마다 하나씩 고른다)
var fills: Array[Color] = [Color(0.98, 0.98, 0.99), Color(0.92, 0.93, 0.95), Color(0.95, 0.93, 0.9), Color(0.89, 0.91, 0.94)]
## 머리카락(일부만)
var hair_color: Color = Color(0.5, 0.52, 0.58)
var line_near: Color = Color(0.08, 0.08, 0.1)
## 멀어질수록 바탕·테두리가 이 색으로 녹는다(공기 원근)
var haze: Color = Color(0.85, 0.89, 0.95)
## 이 깊이(캐릭터 키 단위)부터 흐려지기 시작해 haze_far에서 haze_amount만큼
var haze_near: float = 9.0
var haze_far: float = 22.0
var haze_amount: float = 0.45
## 바탕·머리카락·공기색을 통째로 이만큼 어둡게(1 = 그대로) — 장면이 setup 전에 넣는다(ArrestScene.mob_shade)
var shade: float = 1.0

## 사람마다 {x, z, h, fill, hair, lean, phase, hop_at, hop_every}
var _people: Array = []

## 무리를 새로 깐다. worlds는 사람마다 발 위치(월드 X, 0, Z — 장면이 화면 발 위치를 깊이로 바꿔 넘긴다).
## 같은 seed면 늘 같은 무리가 선다
func setup(worlds: Array, seed_value: int = 7) -> void:
	_people.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for w in worlds:
		var p: Vector3 = w
		var hair_roll: float = rng.randf()
		_people.append({
			"x": p.x, "z": p.z,
			"h": rng.randf_range(0.86, 1.03),
			"wide": rng.randf_range(0.92, 1.12),
			"fill": fills[rng.randi() % fills.size()],
			# 0 = 민머리, 1 = 머리카락 덮개, 2 = 모자 챙
			"hair": 1 if hair_roll < 0.45 else (2 if hair_roll < 0.6 else 0),
			"look": rng.randf_range(-0.05, -0.015) if rng.randf() < 0.8 else rng.randf_range(0.01, 0.03),
			"phase": rng.randf() * TAU,
			"breath": rng.randf_range(2.1, 3.2),
			"hop_every": rng.randf_range(2.2, 4.5),
			"hop_off": rng.randf() * 4.0,
		})
	# 먼 사람부터 그려야 앞사람이 뒷사람을 가린다
	_people.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["z"] > b["z"])
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if _people.is_empty():
		return
	var mesh = LineMesh.new()
	for p in _people:
		_add_person(mesh, p)
	mesh.draw_on(self)

func _add_person(mesh, p: Dictionary) -> void:
	var z: float = maxf(float(p["z"]) - dolly, 0.05)
	var unit: float = focal / z
	var feet := Vector2(vanish_x + focal * float(p["x"]) / z, horizon_y + focal * camera_height / z)
	var h: float = float(p["h"]) * unit
	var haze_k: float = clampf((float(p["z"]) - haze_near) / maxf(haze_far - haze_near, 0.01), 0.0, 1.0) * haze_amount
	var air: Color = _shaded(haze)
	var fill: Color = _shaded(p["fill"]).lerp(air, haze_k)
	var line: Color = line_near.lerp(air, haze_k * 1.25)
	var width: float = clampf(unit * 0.012, 1.3, 3.2)
	# 숨쉬기(아주 조금) + 가끔 수군거리듯 두 번 폴짝
	var t: float = time + float(p["hop_off"])
	var breath: float = sin(t * TAU / float(p["breath"]) + float(p["phase"])) * 0.006
	var hop_t: float = fposmod(t, float(p["hop_every"]))
	var hop: float = 0.0
	if hop_t < 0.36:
		hop = absf(sin(hop_t / 0.18 * PI)) * 0.035
	var lift: float = (breath + hop) * h
	var wide: float = float(p["wide"])
	var look: float = float(p["look"]) * h
	var base := feet - Vector2(0.0, lift)
	# 발 — 가까운 사람만(멀면 안 보일 만큼 작다)
	if unit > 70.0:
		for side in [-1.0, 1.0]:
			var fc := feet + Vector2(side * 0.12 * h * wide, -0.03 * h)
			_add_ellipse(mesh, fc, Vector2(0.085 * h, 0.042 * h), fill, line, width)
	# 몸(사다리꼴)
	var bottom: float = 0.05 * h
	var top: float = 0.6 * h
	var body := PackedVector2Array([
		base + Vector2(-0.25 * h * wide, -bottom), base + Vector2(0.25 * h * wide, -bottom),
		base + Vector2(0.18 * h * wide + look * 0.4, -top), base + Vector2(-0.18 * h * wide + look * 0.4, -top),
	])
	mesh.add_fill(body, fill)
	mesh.add_line(body, PackedColorArray([line]), width, true)
	# 머리 — 얼굴은 없다. 연행 쪽으로 살짝 쏠린다
	var r: float = 0.235 * h
	var head_c := base + Vector2(look, -(h - r))
	_add_ellipse(mesh, head_c, Vector2(r, r), fill, line, width)
	match int(p["hair"]):
		1:
			_add_cap(mesh, head_c, r, _shaded(hair_color).lerp(air, haze_k), line, width)
		2:
			var brim_y: float = head_c.y - r * 0.35
			mesh.add_line(PackedVector2Array([Vector2(head_c.x - r * 1.05, brim_y), Vector2(head_c.x + r * (0.4 if look < 0.0 else 1.05), brim_y)]),
				PackedColorArray([line]), width * 1.3)

func _shaded(c: Color) -> Color:
	return Color(c.r * shade, c.g * shade, c.b * shade, c.a)

static func _ellipse_points(c: Vector2, radius: Vector2, sides: int = 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides:
		var a: float = TAU * i / sides
		pts.append(c + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return pts

static func _add_ellipse(mesh, c: Vector2, radius: Vector2, fill: Color, line: Color, width: float) -> void:
	var pts := _ellipse_points(c, radius)
	mesh.add_fill(pts, fill)
	mesh.add_line(pts, PackedColorArray([line]), width, true)

## 머리 윗부분을 덮는 머리카락 — 원을 현으로 자른 조각이라 늘 볼록하다(부채꼴 채우기가 안 삐져나온다)
static func _add_cap(mesh, c: Vector2, r: float, color: Color, line: Color, width: float) -> void:
	var pts := PackedVector2Array()
	var steps: int = 12
	var from: float = PI + 0.25
	var to: float = TAU - 0.25
	for i in steps + 1:
		var a: float = lerpf(from, to, float(i) / steps)   # 왼쪽 → 위 → 오른쪽
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	mesh.add_fill(pts, color)
	mesh.add_line(pts, PackedColorArray([line]), width * 0.8, true)
