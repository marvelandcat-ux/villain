class_name LocationCard
extends Control

## 장소가 바뀔 때 띄우는 **장소 카드** — 검은 화면 가운데에 작은 부제("사건현장") + 큰 장소 이름("놀이터").
##
## (2026-09-12 사용자 러프: 검은 화면 가운데 "놀이터". 추리·수사물(역전재판 등)처럼 장소 이름을 타자 치듯
##  한 글자씩 찍는다 — 대사창의 타다닥과 같은 느낌. 사건 현장을 옮길 때마다 이 형식을 쓴다)
## 순서: `start_delay` 뒤 부제가 서서히 나타남 -> 장소 이름이 한 글자씩 찍힘 -> `hold_time` 머묾 -> 끝(is_finished)
## StoryFadeScene의 `dialogue`에 이 노드를 지정하면 카드가 끝나야 다음 장면(새 배경)으로 넘어간다.

## 위에 작게 뜨는 부제
@export var subtitle: String = "사건현장"
## 크게 찍히는 장소 이름
@export var title: String = "놀이터"
## 카드가 시작되기 전 기다리는 시간(초) — 검은 화면에서 한 박자 쉬고 뜬다
@export var start_delay: float = 0.3
## 부제가 나타나는 시간(초)
@export var subtitle_fade: float = 0.35
## 장소 이름이 찍히는 빠르기(글자/초) — 대사보다 느리게 또박또박
@export var chars_per_second: float = 8.0
## 다 찍힌 뒤 머무는 시간(초)
@export var hold_time: float = 1.2

@onready var _sub: Label = $Center/Box/Subtitle
@onready var _title: Label = $Center/Box/Title

var _t: float = 0.0
var _shown: int = 0
var _char_timer: float = 0.0
var _done_at: float = -1.0
var _finished: bool = false

func _ready() -> void:
	_sub.text = subtitle
	_title.text = title
	# 글자가 늘어나도 가운데 정렬 위치가 흔들리지 않게 — 배치는 전체 이름으로 먼저 정하고 글자만 가린다
	_title.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_title.visible_characters = 0
	_sub.modulate.a = 0.0

func is_finished() -> bool:
	return _finished

func _process(delta: float) -> void:
	if _finished:
		return
	_t += delta
	if _t < start_delay:
		return
	_sub.modulate.a = clampf((_t - start_delay) / maxf(subtitle_fade, 0.001), 0.0, 1.0)
	if _t < start_delay + subtitle_fade * 0.6:
		return   # 부제가 어느 정도 뜬 뒤 이름을 찍기 시작
	var total: int = title.length()
	if _shown < total:
		_char_timer -= delta
		while _char_timer <= 0.0 and _shown < total:
			_shown += 1
			_char_timer += 1.0 / maxf(chars_per_second, 0.01)
		_title.visible_characters = -1 if _shown >= total else _shown
		return
	if _done_at < 0.0:
		_done_at = _t
	if _t - _done_at >= hold_time:
		_finished = true
