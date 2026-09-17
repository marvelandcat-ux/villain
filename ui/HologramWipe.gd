class_name HologramWipe
extends Control

## 화면을 "홀로그램 타일"로 뒤덮었다가 걷어내는 전환 연출.
## 화면을 격자로 나눠 칸마다 같은 타일 그림(sprite/대전모드/홀로그램타일.png)을 깔고,
## 왼쪽 위 -> 오른쪽 아래로 대각선 순서에 따라 하나씩 튀어나오게 해서 홀로그램이 번져
## 화면을 뒤덮는 것처럼 보이게 한다(covered). 다 덮인 뒤 start_uncover()를 부르면
## 같은 순서로 타일이 사라지며 뒤에 있는 화면을 다시 드러낸다(uncovered).
##
## 씬을 바꾸는 동안 화면을 가려두는 용도로 쓴다 — SceneTransition(오토로드) 참고.
## 코드로만 만드는 노드다(HologramWipe.new()로 바로 인스턴스해서 add_child) — 씬 파일이 없다

## 화면이 다 덮이면 보낸다
signal covered
## start_uncover() 이후 타일이 다 사라지면 보낸다
signal uncovered

## 타일 그림 (정사각형, 이어붙였을 때 격자로 보이는 그림)
@export var tile_texture: Texture2D = preload("res://sprite/대전모드/홀로그램타일.png")
## 타일 한 칸의 화면 크기(px)
@export var cell_size: Vector2 = Vector2(80, 80)
## 타일 하나가 나타나거나 사라지는 데 걸리는 시간(초)
@export var appear_duration: float = 0.16
## 첫 타일부터 마지막 타일까지 스윕이 퍼지는 전체 시간(초) — 대각선 순서로 이 시간에 걸쳐 번진다
@export var sweep_duration: float = 0.5
## 화면이 다 덮인 뒤 covered를 보내기까지 잠깐 멈추는 시간(초)
@export var hold_time: float = 0.15

## 다 덮인 뒤 가운데에 표시할 글자(맵 이름 등). add_child 하기 전에 정해둘 것 — 비워두면 안 띄운다
var label_text: String = ""

## 지금 덮는 중인지(false면 걷어내는 중) — start_uncover()가 호출되기 전까지는 true
var _covering: bool = true
var _tiles: Array = []  # [{node: TextureRect, delay: float}]
var _elapsed: float = 0.0
var _finished: bool = false  # 지금 단계(덮기/걷기)가 끝나서 더 이상 _process에서 갱신할 게 없는지
var _label: Label = null

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_grid()
	if label_text != "":
		_label = Label.new()
		_label.text = label_text
		_label.anchor_right = 1.0
		_label.anchor_bottom = 1.0
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.add_theme_font_size_override("font_size", 36)
		_label.add_theme_color_override("font_color", Color(1, 1, 1))
		_label.add_theme_constant_override("outline_size", 8)
		_label.add_theme_color_override("font_outline_color", Color(0.05, 0.2, 0.5))
		_label.modulate.a = 0.0
		add_child(_label)

## 화면 크기를 cell_size로 나눠 칸마다 타일 하나씩 깐다. 대각선 순서(col+row)로 나타나는 시점을
## 정해서 왼쪽 위부터 오른쪽 아래로 번지는 스윕을 만든다 — 걷어낼 때도 같은 순서를 그대로 쓴다
func _build_grid() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var cols: int = ceili(vp.x / cell_size.x)
	var rows: int = ceili(vp.y / cell_size.y)
	var max_index: int = maxi(cols + rows - 2, 1)
	for row in range(rows):
		for col in range(cols):
			var tile := TextureRect.new()
			tile.texture = tile_texture
			tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tile.stretch_mode = TextureRect.STRETCH_SCALE
			tile.position = Vector2(col, row) * cell_size
			tile.size = cell_size
			tile.pivot_offset = cell_size * 0.5
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.modulate.a = 0.0
			tile.scale = Vector2(0.25, 0.25)
			add_child(tile)
			var delay: float = (float(col + row) / float(max_index)) * sweep_duration
			_tiles.append({"node": tile, "delay": delay})

## 다 덮인 채로 멈춰 있던 타일을 걷어내기 시작한다 — covered가 나온 뒤에만 부를 것
func start_uncover() -> void:
	_covering = false
	_finished = false
	_elapsed = 0.0
	if _label:
		_label.modulate.a = 0.0  # 이름표는 새 화면이 드러나기 전에 바로 숨긴다

func _process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta
	var all_done := true
	for t in _tiles:
		var local_t: float = clampf((_elapsed - t["delay"]) / appear_duration, 0.0, 1.0)
		if local_t < 1.0:
			all_done = false
		var node: TextureRect = t["node"]
		# 뒤로 갈수록 느려지게(감속) — 톡 튀어나왔다가/사뿐히 꺼지는 느낌
		var eased: float = 1.0 - pow(1.0 - local_t, 3.0)
		var shown: float = eased if _covering else (1.0 - eased)
		node.modulate.a = local_t if _covering else (1.0 - local_t)
		node.scale = Vector2.ONE * lerpf(0.25, 1.0, shown)
	if _covering and _label:
		var sweep_end: float = sweep_duration + appear_duration
		_label.modulate.a = clampf((_elapsed - sweep_end * 0.6) / 0.3, 0.0, 1.0)
	if not all_done:
		return
	_finished = true
	if _covering:
		await get_tree().create_timer(hold_time).timeout
		covered.emit()
	else:
		uncovered.emit()
