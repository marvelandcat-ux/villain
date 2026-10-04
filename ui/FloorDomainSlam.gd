extends CanvasLayer

## **영역전개 연출 3장 — 문 쾅.** 2장(문 열고 빼꼼) 바로 뒤에 나오고, 이게 끝나면 집으로 넘어간다.
##
## 닫힌 문이 **옆에서 확 밀려 들어와 제자리에 꽂히고**, 그 순간 문틈에서 불꽃이 튀며 화면이 크게 흔들린다.
## 문 그림·자리·크기는 1장(두드리기)과 **똑같이** 맞춰 둔다 — 세 장면 내내 같은 문이어야 한다.
##
## 씬만 따로 열어도(F6) 바로 재생된다

signal finished

## 문이 **어디서부터** 밀려 들어오는지(제자리 기준 오프셋, px). 오른쪽에서 닫히는 모양이면 x를 +로
@export var slam_from: Vector2 = Vector2(70, 0)
## 닫히는 데 걸리는 시간(초) — 짧을수록 세게 닫힌다
@export var slam_time: float = 0.12
## 닫힌 뒤 문이 덜컹하고 되튀는 폭(px)과 시간(초)
@export var rebound: float = 7.0
@export var rebound_time: float = 0.09
## 쾅 하는 순간 화면이 흔들리는 폭(px)과 가라앉는 시간(초)
@export var shake: float = 16.0
@export var shake_time: float = 0.26
## 다 끝나고 다음(영역)으로 넘어가기 전에 머무는 시간(초)
@export var hold_after: float = 0.45

@export_group("쾅 효과")
## **문틈에서 터지는 별**(`SlamStar`) 크기(px)와, 가지가 퍼지는 가운데 방향·범위(도).
## 0도가 오른쪽이므로 문 오른쪽에서 터뜨리려면 0 그대로 두면 된다
@export var star_radius: float = 110.0
@export var star_aim_deg: float = 0.0
@export var star_spread_deg: float = 115.0
## 가지 개수와 길이가 들쭉날쭉한 정도
@export var star_spikes: int = 7
@export var star_jitter: float = 0.35
## 별 속·테두리 색
@export var star_fill: Color = Color(1.0, 0.87, 0.05)
@export var star_line: Color = Color(0.87, 0.11, 0.09)

@export_group("화면")
## 씬에 잡아 둔 자리·크기가 이 화면 높이 기준이라고 친다
@export var design_height: float = 720.0
## 벽지를 화면에 꽉 채울지
@export var cover_screen: bool = true
## 화면을 덮은 벽지를 **이만큼 더 키운다**(1이면 딱 맞게만). 세 장면 모두 같은 값을 쓴다
@export var wall_zoom: float = 1.2
## 이 장면만 따로 띄웠을 때(F6) 바로 재생할지
@export var autoplay_when_alone: bool = true

const SLAM_STAR := preload("res://combat/SlamStar.gd")

@onready var _root: Node2D = $Root
@onready var _wall: Sprite2D = $Root/Wallpaper
@onready var _door: Node2D = $Root/Door
@onready var _spark_at: Node2D = $Root/SparkAt

## 문 제자리
var _door_home: Vector2
var _playing: bool = false

func _ready() -> void:
	_door_home = _door.position
	_fit_screen()
	get_viewport().size_changed.connect(_fit_screen)
	if autoplay_when_alone and get_parent() == get_tree().root:
		play()

## 화면 가운데에 맞추고, 창이 기준 높이보다 크면 통째로 확대한다
func _fit_screen() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var zoom: float = maxf(view.y / maxf(design_height, 1.0), 0.01)
	if _root:
		_root.position = view * 0.5
		_root.scale = Vector2(zoom, zoom)
	if cover_screen and _wall and _wall.texture:
		var tex: Vector2 = _wall.texture.get_size()
		var k: float = maxf(view.x / tex.x, view.y / tex.y) / zoom * maxf(wall_zoom, 0.1)
		_wall.scale = Vector2(k, k)

func play() -> void:
	if _playing:
		return
	_playing = true
	_door.position = _door_home + slam_from
	var tw := create_tween()
	# 가속하며 닫힌다 — 끝에서 가장 빠르게 꽂혀야 "쾅"으로 읽힌다
	tw.tween_property(_door, "position", _door_home, maxf(slam_time, 0.01)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_impact)
	# 꽂힌 문이 살짝 되튀었다가 자리를 잡는다
	tw.tween_property(_door, "position", _door_home + Vector2(rebound, 0.0), maxf(rebound_time, 0.01))
	tw.tween_property(_door, "position", _door_home, maxf(rebound_time, 0.01))
	tw.tween_interval(maxf(hold_after, 0.0))
	tw.tween_callback(_done)

## 쾅 하는 순간 — 문틈에서 불꽃이 튀고 화면이 흔들린다
func _impact() -> void:
	_spawn_spark()
	if shake <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var tw := create_tween()
	var steps: int = 5
	for i in range(steps):
		var amount: float = shake * (1.0 - float(i) / float(steps))
		tw.tween_property(self, "offset",
			Vector2(rng.randf_range(-amount, amount), rng.randf_range(-amount, amount)),
			maxf(shake_time / float(steps), 0.01))
	tw.tween_property(self, "offset", Vector2.ZERO, 0.05)

## 문틈에 **별 모양 쾅**을 띄운다 — 전용 그림 없이 `SlamStar`가 직접 그린다.
## 예전에는 타격 불꽃(`HitSpark`)을 키워 썼는데 "쾅" 느낌이 안 나서 바꿨다(2026-10-04 사용자 스케치)
func _spawn_spark() -> void:
	if _spark_at == null:
		return
	var star := SLAM_STAR.new()
	star.radius = star_radius
	star.aim_deg = star_aim_deg
	star.spread_deg = star_spread_deg
	star.spike_count = star_spikes
	star.jitter = star_jitter
	star.fill_color = star_fill
	star.line_color = star_line
	_spark_at.add_child(star)

func _done() -> void:
	_playing = false
	finished.emit()
