extends Node2D

## 연행 장면(ArrestScene)의 뒤 배경 — 하늘·뭉게구름·지평선의 먼 건물과 나무·바닥(도로/연석/보도 타일)을 코드로 그린다.
## 바닥은 ArrestScene과 **같은 카메라**로 투영한다: 연석·타일 세로선은 소실점으로 모이고, 가로선은 앞으로 올수록 벌어진다.
## 밀고 들어가기(dolly) 중엔 가로선만 아래로 흘러서 "앞으로 다가간다"로 읽힌다(소실점으로 모이는 선은 원래 안 움직인다).
## 구름은 원작처럼 크고 둥근 뭉게구름 — 게임 그림체에 맞춰 흰 윗면 + 푸른 그늘 + 테두리로 납작하게 칠한다
##
## ⚠️ 구름·먼 나무는 원 수백 개라 `draw_circle`로 그리면 원 하나가 그리기 한 번(draw call)이 되어
## 연행 장면이 30fps까지 떨어졌다(2026-10-08 실측, 배경만 끄면 79fps). 그래서 원은 **삼각형 묶음 하나**(`_fill_circles`)로 칠하고,
## 구름은 한 덩이씩 자식 노드에 한 번만 그려 자리만 옮기며, 먼 나무·건물은 보이는 것이 바뀔 때만 다시 그린다

const LineMesh = preload("res://ui/result/LineMesh.gd")

# --- ArrestScene이 매 프레임 넣는 값 ---
## 화면에 보이는 영역(이 노드 좌표). 넓은 화면이면 1280x720보다 넓다
var view_rect: Rect2 = Rect2(0, 0, 1280, 720)
var vanish_x: float = 760.0
var horizon_y: float = 470.0
var camera_height: float = 0.62
var focal: float = 1500.0
var dolly: float = 0.0
## 실제 시간(초) — 구름이 흐르는 데만 쓴다
var time: float = 0.0
## 경찰서 건물이 가리는 가로 범위(이 노드 좌표) — 그 안쪽엔 먼 나무·건물을 안 그린다
var building_span: Vector2 = Vector2(760, 1374)

@export_group("하늘")
@export var sky_top: Color = Color(0.15, 0.4, 0.84)
@export var sky_mid: Color = Color(0.31, 0.6, 0.93)
@export var sky_horizon: Color = Color(0.74, 0.88, 1.0)

@export_group("구름")
@export var cloud_light: Color = Color(1.0, 1.0, 1.0)
@export var cloud_shade: Color = Color(0.8, 0.88, 0.97)
@export var cloud_line: Color = Color(0.47, 0.64, 0.87)
@export var cloud_line_width: float = 3.0
## 구름이 흐르는 빠르기(px/초, 큰 구름 기준 — 작은 구름은 더 느리다)
@export var cloud_speed: float = 7.0

@export_group("먼 풍경")
@export var tree_light: Color = Color(0.47, 0.75, 0.37)
@export var tree_shade: Color = Color(0.31, 0.59, 0.3)
@export var tree_line: Color = Color(0.16, 0.29, 0.17)
@export var city_color: Color = Color(0.66, 0.76, 0.89)

@export_group("바닥")
## 도로와 보도를 가르는 연석의 월드 X(캐릭터 키 = 1). 이보다 왼쪽이 도로
@export var curb_x: float = -0.95
@export var curb_width: float = 0.08
## 보도 타일 한 칸(월드)
@export var tile_size: float = 0.55
## 도로 가운데 점선의 월드 X
@export var lane_x: float = -2.7
@export var walk_near: Color = Color(0.89, 0.8, 0.64)
@export var walk_far: Color = Color(0.9, 0.87, 0.81)
@export var tile_line: Color = Color(0.68, 0.58, 0.43, 0.75)
@export var road_near: Color = Color(0.33, 0.35, 0.41)
@export var road_far: Color = Color(0.56, 0.6, 0.68)
@export var curb_color: Color = Color(0.95, 0.94, 0.9)
@export var edge_line: Color = Color(0.13, 0.13, 0.16)
@export var lane_color: Color = Color(0.97, 0.97, 0.94, 0.92)
## 아래쪽을 살짝 어둡게(앞이 무겁게) — 0이면 안 함
@export_range(0.0, 0.5, 0.01) var bottom_shade: float = 0.13

## 구름마다 {x, y, size, speed, puffs: [Vector3(x, y, 반지름)]} — 단위 공간(가로 약 4)에서 size배
var _clouds: Array = []
## 먼 나무 덩어리 [Vector3(x, 반지름, 밝은 쪽 비율)] / 먼 건물 [Rect2]
var _trees: Array = []
var _city: Array = []
## 구름 한 덩이씩 그려 둔 자식 노드(_clouds와 같은 순서)
var _cloud_nodes: Array[Node2D] = []
## 먼 나무·건물을 그려 둔 자식 노드와, 마지막으로 그린 때의 [지평선, 보이는 나무 번호, 보이는 건물 번호]
var _far: Node2D = null
var _far_key: Array = []
## 세로 줄눈 삼각형 묶음과 그것을 쌓은 때의 화면 값
var _column_mesh: LineMesh = null
var _column_key: Array = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242   # 판마다 모양이 바뀌면 "다른 장소"처럼 보인다 — 늘 같은 하늘
	# 작은(먼) 구름부터 — 그리는 순서가 곧 앞뒤
	var layout: Array = [
		[1500.0, 300.0, 30.0, 0.55], [430.0, 330.0, 24.0, 0.5], [-140.0, 255.0, 34.0, 0.6],
		[640.0, 92.0, 40.0, 0.75], [1130.0, 148.0, 72.0, 1.0], [215.0, 172.0, 64.0, 0.95],
	]
	for entry in layout:
		_clouds.append({"x": entry[0], "y": entry[1], "size": entry[2], "speed": entry[3], "puffs": _make_cloud(rng)})
	var x: float = -900.0
	while x < 2300.0:
		var r: float = rng.randf_range(10.0, 19.0)
		if rng.randf() < 0.18:
			r = rng.randf_range(21.0, 27.0)   # 가끔 큰 나무가 솟아야 줄이 밋밋하지 않다
		_trees.append(Vector3(x, r, rng.randf_range(0.0, 1.0)))
		x += r * rng.randf_range(1.05, 1.5)
	x = -900.0
	while x < 2300.0:
		var w: float = rng.randf_range(40.0, 95.0)
		var h: float = rng.randf_range(26.0, 74.0)
		_city.append(Rect2(x, -h, w, h))
		x += w + rng.randf_range(-10.0, 30.0)
	# 자식은 부모 그림 위에 그려진다 — 하늘·바닥(부모) → 구름 → 먼 풍경. 구름은 지평선보다 한참 위라 먼 풍경과 안 겹친다
	for c in _clouds:
		var cloud := CloudDrawing.new()
		cloud.backdrop = self
		cloud.puffs = c["puffs"]
		cloud.size = c["size"]
		add_child(cloud)
		_cloud_nodes.append(cloud)
	var far := FarDrawing.new()
	far.backdrop = self
	add_child(far)
	_far = far
	# ArrestScene(process_priority 100)이 이번 프레임 값(시간·dolly·건물 폭)을 넣은 **뒤에** 자리를 맞춘다
	process_priority = 200

## 뭉게구름 한 덩이 — 아래 줄 작은 공 + 위 줄 큰 공 + 꼭대기 하나
func _make_cloud(rng: RandomNumberGenerator) -> Array:
	var puffs: Array = []
	var bottom: int = rng.randi_range(4, 5)
	for i in bottom:
		var t: float = float(i) / float(bottom - 1)
		puffs.append(Vector3(lerpf(-1.65, 1.65, t), rng.randf_range(-0.05, 0.05), rng.randf_range(0.5, 0.66)))
	var top: int = rng.randi_range(2, 3)
	for i in top:
		var t: float = float(i) / float(maxi(top - 1, 1))
		puffs.append(Vector3(lerpf(-0.95, 0.95, t) + rng.randf_range(-0.15, 0.15), rng.randf_range(-0.62, -0.5), rng.randf_range(0.72, 0.9)))
	puffs.append(Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(-1.12, -0.98), rng.randf_range(0.62, 0.78)))
	return puffs

func _process(_delta: float) -> void:
	queue_redraw()
	_place_clouds()
	_refresh_far()

func _draw() -> void:
	var left: float = view_rect.position.x - 4.0
	var right: float = view_rect.end.x + 4.0
	var top: float = view_rect.position.y - 4.0
	var bottom: float = view_rect.end.y + 4.0
	_draw_sky(left, right, top)
	_draw_ground(left, right, bottom)

func _draw_sky(left: float, right: float, top: float) -> void:
	var mid_y: float = lerpf(top, horizon_y, 0.55)
	_grad_quad(left, right, top, mid_y, sky_top, sky_mid)
	_grad_quad(left, right, mid_y, horizon_y + 2.0, sky_mid, sky_horizon)

## 구름은 다시 그리지 않고 자리만 옮긴다(화면 밖으로 나가면 반대편에서 다시 들어온다)
func _place_clouds() -> void:
	var span_left: float = view_rect.position.x - 320.0
	var span: float = view_rect.size.x + 640.0
	for i in _cloud_nodes.size():
		var c: Dictionary = _clouds[i]
		var cx: float = span_left + fposmod(float(c["x"]) - span_left + time * cloud_speed * float(c["speed"]), span)
		_cloud_nodes[i].position = Vector2(cx, c["y"])

## 보이는 먼 나무·건물이 바뀌었을 때만(화면 폭·건물 폭이 달라졌을 때) 다시 그리게 한다
func _refresh_far() -> void:
	var left: float = view_rect.position.x - 4.0
	var right: float = view_rect.end.x + 4.0
	var key: Array = [horizon_y, _visible_trees(left, right), _visible_city(left, right)]
	if key != _far_key:
		_far_key = key
		_far.queue_redraw()

func _visible_city(left: float, right: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in _city.size():
		var rect: Rect2 = _city[i]
		if rect.end.x < left or rect.position.x > right:
			continue
		if rect.position.x > building_span.x + 60.0 and rect.end.x < building_span.y - 60.0:
			continue
		out.append(i)
	return out

func _visible_trees(left: float, right: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in _trees.size():
		var tree: Vector3 = _trees[i]
		if tree.x + tree.y < left or tree.x - tree.y > right:
			continue
		if tree.x > building_span.x + 70.0 and tree.x < building_span.y - 70.0:
			continue
		out.append(i)
	return out

## 구름 한 덩이(구름 가운데가 원점). 테두리 → 그늘 → 밝은 윗면 순으로 겹쳐 칠하면 덩어리 하나로 읽힌다
func _draw_cloud_on(canvas: CanvasItem, puffs: Array, size: float) -> void:
	var circles: Array = []
	for p in puffs:
		circles.append([Vector2(p.x, p.y) * size, p.z * size + cloud_line_width, cloud_line])
	for p in puffs:
		circles.append([Vector2(p.x, p.y) * size, p.z * size, cloud_shade])
	for p in puffs:
		var lift: float = 0.3 if p.y > -0.3 else 0.16
		circles.append([Vector2(p.x - p.z * 0.1, p.y - p.z * lift) * size, p.z * size * 0.78, cloud_light])
	_fill_circles(canvas, circles)

## 먼 건물 → 먼 나무(이 노드 좌표 그대로)
func _draw_far_on(canvas: CanvasItem) -> void:
	if _far_key.size() < 3:
		return
	for i in (_far_key[2] as PackedInt32Array):
		var rect: Rect2 = _city[i]
		canvas.draw_rect(Rect2(rect.position + Vector2(0.0, horizon_y), rect.size + Vector2(0.0, 2.0)), city_color)
	var visible: PackedInt32Array = _far_key[1]
	var circles: Array = []
	for i in visible:
		var tree: Vector3 = _trees[i]
		circles.append([Vector2(tree.x, horizon_y - tree.y * 0.42), tree.y + 2.2, tree_line])
	for i in visible:
		var tree: Vector3 = _trees[i]
		circles.append([Vector2(tree.x, horizon_y - tree.y * 0.42), tree.y, tree_shade])
	for i in visible:
		var tree: Vector3 = _trees[i]
		circles.append([Vector2(tree.x - tree.y * 0.18, horizon_y - tree.y * 0.42 - tree.y * 0.22), tree.y * 0.72, tree_light])
	_fill_circles(canvas, circles)

## 꽉 찬 원 여러 개([가운데, 반지름, 색])를 **삼각형 묶음 하나**로 그린다 — 앞에 넣은 원이 먼저 칠해진다.
## ⚠️ draw_circle은 원 하나가 그리기 한 번(draw call)이라, 나무·구름 수백 개를 그것으로 그리면 프레임이 반토막 났다(실측)
static func _fill_circles(canvas: CanvasItem, circles: Array) -> void:
	var mesh := LineMesh.new()
	for c in circles:
		mesh.add_disc(c[0], c[1], c[2])
	mesh.draw_on(canvas)

func _draw_ground(left: float, right: float, bottom: float) -> void:
	if bottom <= horizon_y:
		return
	# 보도(전체) → 도로(연석 왼쪽) 순으로 깐다. 멀수록 하늘빛이 섞여 흐려진다
	_grad_quad(left, right, horizon_y, bottom, walk_far, walk_near)
	var curb_bottom: float = _x_at(curb_x, bottom)
	draw_primitive(PackedVector2Array([Vector2(left, horizon_y), Vector2(vanish_x, horizon_y), Vector2(curb_bottom, bottom), Vector2(left, bottom)]),
		PackedColorArray([road_far, road_far, road_near, road_near]), PackedVector2Array())
	# 도로 표시 — 연석 옆 흰 실선 + 가운데 점선(땅에 붙은 사각형이라 앞으로 올수록 크다)
	_ground_strip(curb_x - 0.22, curb_x - 0.17, lane_color, bottom)
	_lane_dashes(bottom)
	# 연석 — 윗면(밝은 띠)과 도로 쪽 테두리
	_ground_strip(curb_x, curb_x + curb_width, curb_color, bottom)
	_ground_strip(curb_x - 0.014, curb_x, edge_line, bottom)
	_ground_strip(curb_x + curb_width, curb_x + curb_width + 0.008, tile_line.darkened(0.2), bottom)
	_tile_lines(right, bottom)
	# 지평선 언저리를 하늘빛으로 흐리게 — 바닥과 하늘이 칼같이 갈리지 않게
	_grad_quad(left, right, horizon_y - 1.0, horizon_y + 26.0, Color(sky_horizon, 0.85), Color(sky_horizon, 0.0))
	if bottom_shade > 0.0:
		_grad_quad(left, right, lerpf(horizon_y, bottom, 0.45), bottom, Color(0, 0, 0, 0), Color(0.05, 0.03, 0.08, bottom_shade))

## 소실점으로 모이는 바닥 띠(월드 X 범위 x0~x1, 화면 아래까지)
func _ground_strip(x0: float, x1: float, color: Color, bottom: float) -> void:
	draw_primitive(PackedVector2Array([Vector2(vanish_x, horizon_y), Vector2(_x_at(x0, bottom), bottom), Vector2(_x_at(x1, bottom), bottom)]),
		PackedColorArray([color, color, color]), PackedVector2Array())

func _lane_dashes(bottom: float) -> void:
	var z_near: float = focal * camera_height / maxf(bottom - horizon_y, 1.0) + dolly
	var period: float = 1.7
	var dash: float = 0.85
	var k: int = int(floor((z_near - 1.0) / period))
	while true:
		var z0: float = k * period + 0.4
		var z1: float = z0 + dash
		k += 1
		if z1 - dolly < 0.3:
			continue
		if z0 - dolly > 70.0:
			break
		var a: Vector2 = _ground(lane_x, maxf(z0, dolly + 0.3))
		var b: Vector2 = _ground(lane_x + 0.07, maxf(z0, dolly + 0.3))
		var c: Vector2 = _ground(lane_x + 0.07, z1)
		var d: Vector2 = _ground(lane_x, z1)
		if a.y - d.y < 0.6:
			continue
		draw_primitive(PackedVector2Array([a, b, c, d]), PackedColorArray([lane_color, lane_color, lane_color, lane_color]), PackedVector2Array())

## 보도 타일 줄눈 — 세로(소실점으로 모임)는 지평선 쪽으로 옅어지고, 가로는 간격이 좁아지면 옅어진다.
## ⚠️ 줄눈은 200줄 가까이라 draw_polyline/draw_line으로 그으면 줄 하나가 그리기 한 번(draw call)이 되어 그것만으로
## 프레임이 반토막 났다(실측). 그래서 **삼각형 묶음**(`LineMesh`, 안티에일리어싱 가장자리 포함)으로 쌓아 두 번에 그린다.
## 세로 줄눈은 dolly와 상관없어서 화면 크기가 바뀔 때만 다시 쌓는다
func _tile_lines(right: float, bottom: float) -> void:
	var key: Array = [right, bottom, horizon_y, vanish_x, camera_height]
	if key != _column_key:
		_column_key = key
		_column_mesh = _tile_columns(right, bottom)
	_add_mesh(_column_mesh)
	var rows := LineMesh.new()
	var start_x: float = curb_x + curb_width
	var z_near: float = focal * camera_height / maxf(bottom - horizon_y, 1.0) + dolly
	var k: int = int(floor(z_near / tile_size))
	while k < 400:
		var z: float = k * tile_size
		k += 1
		if z - dolly < 0.3:
			continue
		var y: float = _y_at(z)
		var gap: float = y - _y_at(z + tile_size)
		if gap < 2.5:
			break
		var col := Color(tile_line, tile_line.a * clampf((gap - 2.5) / 16.0, 0.0, 1.0))
		rows.add_line(PackedVector2Array([Vector2(_x_at(start_x, y), y), Vector2(right, y)]), PackedColorArray([col, col]), 1.5)
	_add_mesh(rows)

## 세로 줄눈(소실점으로 모이는 선) — 지평선 쪽 끝은 투명하게
func _tile_columns(right: float, bottom: float) -> LineMesh:
	var mesh := LineMesh.new()
	var start_x: float = curb_x + curb_width
	var faint := Color(tile_line, 0.0)
	var mid_y: float = lerpf(horizon_y, bottom, 0.3)
	var n: int = 1
	while n < 200:
		var wx: float = start_x + n * tile_size
		n += 1
		var bx: float = _x_at(wx, bottom)
		var p_top := Vector2(_x_at(wx, horizon_y + 3.0), horizon_y + 3.0)
		if p_top.x > right:
			break
		mesh.add_line(PackedVector2Array([p_top, Vector2(_x_at(wx, mid_y), mid_y), Vector2(bx, bottom)]),
			PackedColorArray([faint, Color(tile_line, tile_line.a * 0.45), tile_line]), 1.6)
	return mesh

func _add_mesh(mesh: LineMesh) -> void:
	if mesh != null:
		mesh.draw_on(self)

## 위아래로 색이 바뀌는 가로 띠
func _grad_quad(left: float, right: float, y0: float, y1: float, c0: Color, c1: Color) -> void:
	if y1 - y0 < 0.5:
		return
	draw_primitive(PackedVector2Array([Vector2(left, y0), Vector2(right, y0), Vector2(right, y1), Vector2(left, y1)]),
		PackedColorArray([c0, c0, c1, c1]), PackedVector2Array())

## 월드 X가 같은 바닥 선이 화면 높이 y에서 지나는 x(이 선들은 전부 소실점으로 모인다)
func _x_at(world_x: float, y: float) -> float:
	return vanish_x + world_x * (y - horizon_y) / camera_height

## 깊이 z인 바닥의 화면 높이
func _y_at(z: float) -> float:
	return horizon_y + focal * camera_height / maxf(z - dolly, 0.05)

func _ground(world_x: float, z: float) -> Vector2:
	var d: float = maxf(z - dolly, 0.05)
	return Vector2(vanish_x + focal * world_x / d, horizon_y + focal * camera_height / d)

## 구름 한 덩이 — 한 번 그려 두고 자리만 옮긴다
class CloudDrawing extends Node2D:
	## 이 그림을 맡긴 ArrestBackdrop(무타입 — 바깥 스크립트 함수를 부르려고)
	var backdrop = null
	var puffs: Array = []
	var size: float = 1.0

	func _draw() -> void:
		if backdrop != null:
			backdrop._draw_cloud_on(self, puffs, size)

## 먼 나무·건물 — 보이는 것이 바뀔 때만 다시 그린다
class FarDrawing extends Node2D:
	## 이 그림을 맡긴 ArrestBackdrop(무타입 — 바깥 스크립트 함수를 부르려고)
	var backdrop = null

	func _draw() -> void:
		if backdrop != null:
			backdrop._draw_far_on(self)
