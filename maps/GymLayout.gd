@tool
class_name GymLayout
extends Node2D

## **헬스장 기구 배치** — 자식으로 달린 `GymMachine`들을 **라운드마다 다른 자리에** 늘어놓고,
## 두 선수의 시작 자리를 1층 기구들의 **바깥 좌·우**로 옮긴다(2026-10-02 사용자 요청).
##
## 자리는 **층마다 칸을 미리 깔아 두고 그중 몇 개를 뽑는** 방식이다. 칸을 기구 수보다 넉넉히 깔아야
## "이번 판은 런닝머신이 2층에 있네" 같은 변화가 생긴다 — 칸 수와 기구 수가 같으면 **누가 어디 가는지만**
## 바뀌고 층 구성은 매 판 똑같다.
##
## ⚠️ **라운드가 바뀔 때마다 맵이 통째로 다시 열린다**(`Stage._end_round` → `reload_current_scene`).
## 그래서 "라운드마다 랜덤"은 따로 신호를 받을 것 없이 **`_ready()`에서 한 번 섞으면 된다.**
##
## ⚠️ **자식의 `_ready()`는 부모보다 먼저 돈다** — 이 노드가 `Stage`(맵 루트)의 자식이라
## 여기서 `PlayerSpawn1/2`를 옮겨 두면 `Stage._ready()`가 **옮겨진 자리**를 읽어 캐릭터를 세운다.
## 이 순서가 깨지면 선수들이 기구 속에 박힌 채 시작한다

## **미리 짜 둔 배치표**(`maps/GymPlacements.tres`). 꽂혀 있고 배치가 하나라도 적혀 있으면
## 아래의 "칸 깔고 섞기"를 **안 쓰고** 이 표에서 한 가지를 골라 그대로 놓는다.
## 자리는 지금 `.tres`를 인스펙터에서 직접 고친다 — 끌어서 맞추던 편집 씬(`GymPlacementStudio`)은
## 2026-10-06 '개혁'에서 스크립트가 빠지며 죽어서 지웠다(되살리려면 `git show b94dda2^:maps/GymPlacementStudio.gd`)
@export var placements: GymPlacement
## 표를 꽂아 두고도 잠깐 옛 방식으로 돌려 보고 싶을 때 끈다
@export var use_placements: bool = true

## 층마다 바닥 높이(y). **0번이 1층**이고, 선수는 늘 1층에서 시작한다
@export var level_y: PackedFloat32Array = PackedFloat32Array([280.0, 100.0])
## 층마다 기구가 설 수 있는 좌우 한계
@export var level_min_x: PackedFloat32Array = PackedFloat32Array([-340.0, -250.0])
@export var level_max_x: PackedFloat32Array = PackedFloat32Array([340.0, 250.0])
## 층마다 깔아 둘 칸 수. **기구 수보다 많아야** 층 구성이 판마다 달라진다
@export var level_slots: PackedInt32Array = PackedInt32Array([3, 2])
## 칸 가운데에서 좌우로 흔드는 폭(px). 0이면 늘 똑같은 자리에 선다
@export var jitter: float = 55.0
## 같은 층의 기구끼리 최소로 띄우는 거리 — 서로의 폭 절반 합에 이만큼을 더한다
@export var min_gap: float = 40.0
## 기구를 좌우로 뒤집기도 할지
@export var random_flip: bool = true

@export_group("선수 자리")
## 선수 자리를 1층 기구에 맞춰 옮길지. 끄면 씬에 적어둔 자리를 그대로 쓴다
@export var move_spawns: bool = true
## **제일 바깥 1층 기구에서** 선수까지 띄우는 거리(px)
@export var spawn_margin: float = 150.0
## 선수가 설 수 있는 가장 바깥 x(벽 안쪽). 좌우 대칭이다
@export var spawn_limit_x: float = 540.0
## 두 선수 사이를 적어도 이만큼은 띄운다
@export var spawn_min_distance: float = 560.0
## 선수 자리의 높이 — 1층 바닥에서 이만큼 **위**다(캐릭터 원점이 발보다 30px 위라 그만큼 띄운다)
@export var spawn_lift: float = 40.0

@export_group("에디터 미리보기")
## 에디터에서 기구를 **배치표 몇 번(0부터)으로 놓아 보일지**. 게임에선 안 쓴다 — 라운드마다 무작위다.
## 에디터에서 기구를 끌어 옮기면 그 자리가 배치표에 바로 저장되고, **같은 자리를 쓰는 다른 배치도 같이 옮겨진다**
## (가로는 그 자리 전체, 세로는 그 기구만 — 런닝머신처럼 기구마다 묻는 깊이가 달라서)
@export var editor_preview: int = 0:
	set(value):
		editor_preview = maxi(value, 0)
		if Engine.is_editor_hint() and is_inside_tree():
			_show_preview()
## 크기 비교용으로 **에디터에만** 세워 둘 캐릭터 씬 경로. 씬에 저장되지 않고 게임에도 안 나온다.
## 경로로 받는 이유: 씬을 직접 물려 두면 게임에서 맵을 열 때도 그 캐릭터들을 다 불러온다
@export var editor_characters: PackedStringArray = PackedStringArray():
	set(value):
		editor_characters = value
		if Engine.is_editor_hint() and is_inside_tree():
			_show_characters()
## 위 캐릭터들이 설 **발바닥 자리**(같은 번호끼리 짝). 맵 가운데보다 오른쪽이면 왼쪽을 본다
@export var editor_character_feet: PackedVector2Array = PackedVector2Array():
	set(value):
		editor_character_feet = value
		if Engine.is_editor_hint() and is_inside_tree():
			_show_characters()

## 이번 판에 1층에 놓인 기구들의 x(왼쪽부터) — 선수 자리를 잡을 때 쓰고, 밖에서도 읽을 수 있게 남긴다
var ground_x: Array[float] = []

## 에디터: {기구: 미리보기로 놓아 준 자리 / 뒤집기} — 끌어 옮긴 걸 알아채는 데 쓴다
var _shown: Dictionary = {}
var _shown_flip: Dictionary = {}
## 에디터: 끄는 중엔 저장을 미루고, 손을 뗀 다음 프레임에 한 번만 배치표를 저장한다
var _save_pending: bool = false
## 에디터: 세워 둔 비교용 캐릭터들(주인 없이 붙여서 씬에 저장되지 않는다)
var _preview_nodes: Array[Node] = []

func _ready() -> void:
	if Engine.is_editor_hint():
		_show_preview()
		_show_characters()
		return
	set_process(false)
	var items: Array[GymMachine] = _machines()
	if items.is_empty():
		return
	if use_placements and placements != null and placements.count() > 0:
		_place_from_table(items)
	else:
		_scatter(items)
	if move_spawns:
		_place_spawns()

## **직전 판에 쓴 배치 번호.** 씬이 통째로 다시 열려도 스크립트에 남아 있어서,
## 연달아 같은 배치가 나오는 걸 막는 데 쓴다
static var _last_index: int = -1

## 배치표에서 한 가지를 골라 기구를 그 자리에 그대로 놓는다
func _place_from_table(items: Array[GymMachine]) -> void:
	var total: int = placements.count()
	var pick: int = 0
	if total > 1:
		# 직전과 다른 번호를 고른다 — 남은 것 중에서 뽑고, 직전 번호 이상이면 한 칸 밀어 건너뛴다
		pick = randi() % (total - 1) if _last_index >= 0 else randi() % total
		if _last_index >= 0 and pick >= _last_index:
			pick += 1
	_last_index = pick
	ground_x.clear()
	# 1층과 2층을 가르는 높이 — 이 아래면 1층으로 본다(선수 자리를 1층 기구에 맞추기 때문)
	var split: float = level_y[0]
	if level_y.size() > 1:
		split = (level_y[0] + level_y[1]) * 0.5
	for machine in items:
		machine.position = placements.spot(machine.kind, pick, machine.position)
		machine.flip = placements.flipped(machine.kind, pick)
		if machine.position.y >= split:
			ground_x.append(machine.position.x)
	ground_x.sort()

## 칸을 깔고 섞어서 기구를 하나씩 앉힌다
func _scatter(items: Array[GymMachine]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# 1) 층마다 칸을 깔아 하나의 목록으로 만든다 — [층 번호, x]
	var slots: Array = []
	for level in level_y.size():
		var count: int = level_slots[level] if level < level_slots.size() else 1
		var lo: float = level_min_x[level] if level < level_min_x.size() else -300.0
		var hi: float = level_max_x[level] if level < level_max_x.size() else 300.0
		# **칸 가운데는 흔드는 폭만큼 안쪽에서 잡는다** — 구간 끝에서 잡고 나중에 자르면
		# 바깥 칸이 매번 끝에 딱 붙어 서서 랜덤이 안 보인다(실측: 두 판 다 ±300)
		var inner_lo: float = lo + jitter
		var inner_hi: float = hi - jitter
		var span: float = maxf(inner_hi - inner_lo, 0.0)
		for i in count:
			var t: float = 0.5 if count == 1 else float(i) / float(count - 1)
			slots.append([level, inner_lo + span * t + rng.randf_range(-jitter, jitter)])
	# 2) 칸을 섞어서 기구 수만큼 나눠 준다
	slots.shuffle()
	items.shuffle()
	var taken: Dictionary = {}   # {층: [[x, 기구], ...]}
	for i in items.size():
		if i >= slots.size():
			break   # 칸보다 기구가 많다 — 남은 기구는 씬에 적힌 자리에 그대로 둔다
		var level: int = slots[i][0]
		var list: Array = taken.get(level, [])
		list.append([slots[i][1], items[i]])
		taken[level] = list
	# 3) 층마다 왼쪽부터 훑으며 겹침을 푼다
	ground_x.clear()
	for level in taken.keys():
		var list: Array = taken[level]
		list.sort_custom(func(a, b): return a[0] < b[0])
		for i in range(1, list.size()):
			# 노드 scale까지 곱해야 **화면에 보이는** 폭이 된다 — 런닝머신처럼 가로를 따로 줄인 기구가 있다
			var need: float = (list[i - 1][1].width() * absf(list[i - 1][1].scale.x)
				+ list[i][1].width() * absf(list[i][1].scale.x)) * 0.5 + min_gap
			if list[i][0] - list[i - 1][0] < need:
				list[i][0] = list[i - 1][0] + need
		# 오른쪽으로 밀린 만큼 전체를 되돌려 구간 안에 다시 넣는다
		var hi: float = level_max_x[level] if level < level_max_x.size() else 300.0
		var overflow: float = list[list.size() - 1][0] - hi
		if overflow > 0.0:
			for row in list:
				row[0] -= overflow
		var y: float = level_y[level] if level < level_y.size() else 280.0
		for row in list:
			var machine: GymMachine = row[1]
			# 기구마다 바닥보다 더 내려놓을 수 있다(런닝머신은 벨트가 바닥 높이에 와야 한다)
			machine.position = Vector2(row[0], y + machine.ground_sink)
			if random_flip:
				machine.flip = rng.randf() < 0.5
			if level == 0:
				ground_x.append(row[0])
	ground_x.sort()

## 선수 자리를 **1층 기구 바깥 좌·우**로 옮긴다. 서로 마주보게 하는 건 `Stage`가 맡는다.
## 1층에 기구가 하나도 없으면 씬에 적힌 자리를 그대로 둔다
func _place_spawns() -> void:
	if ground_x.is_empty():
		return
	var left: float = clampf(ground_x[0] - spawn_margin, -spawn_limit_x, 0.0)
	var right: float = clampf(ground_x[ground_x.size() - 1] + spawn_margin, 0.0, spawn_limit_x)
	# 기구가 한쪽으로 몰리면 둘이 너무 붙는다 — 모자란 만큼 양쪽으로 똑같이 더 벌린다
	var short: float = spawn_min_distance - (right - left)
	if short > 0.0:
		left = maxf(left - short * 0.5, -spawn_limit_x)
		right = minf(right + short * 0.5, spawn_limit_x)
	_move_spawn("PlayerSpawn1", left)
	_move_spawn("PlayerSpawn2", right)

func _move_spawn(spawn_name: String, x: float) -> void:
	# 맵 루트(부모)에 달린 마커다 — 이 노드의 자식이 아니다
	var marker: Marker2D = get_parent().get_node_or_null(spawn_name)
	if marker == null:
		return
	var ground: float = level_y[0] if level_y.size() > 0 else 280.0
	marker.global_position = Vector2(x, ground - spawn_lift)

## 자식 기구들
func _machines() -> Array[GymMachine]:
	var items: Array[GymMachine] = []
	for child in get_children():
		if child is GymMachine:
			items.append(child)
	return items

# ---------------------------------------------------------------- 에디터 미리보기

## 에디터: 배치표 editor_preview번대로 기구를 놓아 보인다
func _show_preview() -> void:
	_shown.clear()
	_shown_flip.clear()
	if placements == null or placements.count() == 0:
		return
	var index: int = mini(editor_preview, placements.count() - 1)
	for machine in _machines():
		machine.position = placements.spot(machine.kind, index, machine.position)
		machine.flip = placements.flipped(machine.kind, index)
		_shown[machine] = machine.position
		_shown_flip[machine] = machine.flip

## 에디터: 기구를 끌어 옮기거나 뒤집었으면 배치표에 옮겨 적는다
func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() or placements == null:
		return
	var changed: bool = false
	for machine in _machines():
		if not _shown.has(machine):
			continue
		var old: Vector2 = _shown[machine]
		if not machine.position.is_equal_approx(old):
			_move_spot(machine.kind, old, machine.position)
			_shown[machine] = machine.position
			changed = true
		if machine.flip != _shown_flip.get(machine, machine.flip):
			_flip_at_spot(machine.kind, machine.position, machine.flip)
			_shown_flip[machine] = machine.flip
			changed = true
	if changed:
		_save_pending = true
	elif _save_pending:
		_save_pending = false
		ResourceSaver.save(placements)

## 배치표에서 old 자리를 쓰는 칸을 전부 옮긴다 — 가로는 그 자리의 모든 기구, 세로는 그 기구만
func _move_spot(kind: int, old: Vector2, now: Vector2) -> void:
	var delta: Vector2 = now - old
	for k in [GymPlacement.Kind.CURL, GymPlacement.Kind.SQUAT, GymPlacement.Kind.TREADMILL]:
		for i in placements.count():
			var at: Vector2 = placements.spot(k, i)
			if not _same_spot(at, old):
				continue
			at.x += delta.x
			if k == kind:
				at.y += delta.y
			placements.set_spot(k, i, at, placements.flipped(k, i))

## 배치표에서 그 기구가 이 자리에 설 때의 뒤집기를 전부 바꾼다
func _flip_at_spot(kind: int, at: Vector2, flipped: bool) -> void:
	for i in placements.count():
		var spot: Vector2 = placements.spot(kind, i)
		if _same_spot(spot, at):
			placements.set_spot(kind, i, spot, flipped)

## 같은 자리인지 — x가 같고 같은 층(런닝머신은 묻는 깊이만큼 y가 다르다)
func _same_spot(a: Vector2, b: Vector2) -> bool:
	return absf(a.x - b.x) < 0.5 and absf(a.y - b.y) < 60.0

## 에디터: 크기 비교용 캐릭터를 세운다. 주인(owner)을 안 정해서 씬에 저장되지 않는다
func _show_characters() -> void:
	for node in _preview_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_preview_nodes.clear()
	if editor_characters.is_empty() or editor_character_feet.is_empty():
		return
	var center_x: float = 0.0
	for feet in editor_character_feet:
		center_x += feet.x
	center_x /= editor_character_feet.size()
	for i in mini(editor_characters.size(), editor_character_feet.size()):
		var scene := load(editor_characters[i]) as PackedScene
		if scene == null:
			continue
		var body := scene.instantiate() as Node2D
		if body == null:
			continue
		# 캐릭터 원점은 발바닥보다 30px 위다
		body.position = editor_character_feet[i] - Vector2(0.0, 30.0) - position
		var visual := body.get_node_or_null("Visual") as Node2D
		if visual and editor_character_feet[i].x > center_x:
			visual.scale.x = -absf(visual.scale.x)
		add_child(body)
		_preview_nodes.append(body)
