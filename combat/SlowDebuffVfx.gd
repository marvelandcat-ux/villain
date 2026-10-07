class_name SlowDebuffVfx
extends Node2D

## 슬로우(이동속도 감소)가 걸린 동안 캐릭터에 붙어 있는 파란 이펙트 (순수 장식 — 판정이 없다).
## 걸리는 순간: 큰 회오리가 빠르게 돌며 퍼지고 달팽이가 톡 튀어나온다.
## 걸려 있는 동안: 머리 위 달팽이가 꿈틀거리며 둥실대고, 물방울이 가끔 떨어진다.
##
## `Fighter.apply_temp_multiplier()`가 이동속도를 낮출 때 **맵에** 붙이고 `setup(fighter, 시간)`을 부른다
## (캐릭터 자식이면 좌우 반전에 뒤집힘) — 그래서 어느 캐릭터가 거는 슬로우든 자동으로 나온다. 위치는 매 프레임 캐릭터를 따라간다.
## 회오리(뒤쪽 층)는 맵에서 캐릭터 바로 앞 순서로 끼워 넣어 캐릭터 그림 뒤에 그린다(HealBurst와 같은 방식).
## 같은 캐릭터에 다시 걸리면 예전 것을 지우고 새로 시작한다 — 남은 시간은 둘 중 더 긴 쪽(짧은 슬로우가 긴 슬로우의 이펙트를 일찍 끄지 않게)

const SNAIL_TEX := preload("res://sprite/VFX/슬로우.png")
const SWIRL_TEX := preload("res://sprite/VFX/슬로우 훠오리.png")
const DROP_TEX := preload("res://sprite/VFX/슬로우 물방울.png")

## 그림마다 실제로 보이는 영역(px, 알파 64 이상) — 캔버스가 1254x1254로 넓고 그림이 한쪽에 치우쳐 있어서
## 크기는 이 영역으로 맞추고, 가운데도 이 영역의 중심으로 옮긴다(**그림을 바꾸면 다시 잴 것**)
const SNAIL_RECT := Rect2(177, 350, 926, 605)
const SWIRL_RECT := Rect2(234, 215, 862, 816)
const DROP_RECT := Rect2(374, 298, 498, 698)

const GROUP := "slow_debuff_vfx"

## 머리 위 달팽이 가로 크기(px)와 높이(원점 기준, 위가 -)
@export var snail_width: float = 34.0
@export var snail_y: float = -74.0
## 걸리는 순간 퍼지는 큰 회오리 지름(px)
@export var burst_swirl_size: float = 100.0
## 물방울 키(px)와 떨어지는 간격(초) 최소~최대
@export var drop_height: float = 11.0
@export var drop_interval: Vector2 = Vector2(0.45, 0.85)
## 끝날 때 사라지는 시간(초)
@export var fade_time: float = 0.3

var _target: Node2D = null
var _has_target: bool = false
var _back: Node2D = null
var _snail: Sprite2D = null
## 달팽이가 보는 쪽(1 오른쪽 / -1 왼쪽)과 튀어나오는 크기(0 → 1, 살짝 넘쳤다 돌아온다)
var _snail_dir: float = 1.0
var _snail_grow: float = 0.0
var _time: float = 0.0
var _drop_wait: float = 0.3
## 이펙트가 사라지기까지 남은 시간(초)
var _left: float = 0.0
var _ending: bool = false

func _process(delta: float) -> void:
	# 남은 시간은 실제 delta로 잰다(슬로우 해제 타이머와 어긋나지 않게) — 움직임만 첫 프레임 튐을 막는다
	if not _ending:
		_left -= delta
		if _left <= fade_time:
			_fade_out()
	delta = minf(delta, 0.05)
	_time += delta
	if _has_target and is_instance_valid(_target):
		global_position = _target.global_position
		# 달팽이는 캐릭터가 보는 쪽을 향한다(그림은 오른쪽을 본다)
		var face = _target.get("facing")
		if face is float and face != 0.0:
			_snail_dir = signf(face)
	if _back != null and is_instance_valid(_back):
		_back.global_position = global_position
	if _snail != null:
		# 둥실 + 기어가듯 꿈틀(가로로 늘었다 세로로 눌렸다)
		_snail.position.y = snail_y + sin(_time * TAU / 1.6) * 3.0
		var inch: float = sin(_time * TAU / 0.9)
		var base: float = snail_width / SNAIL_RECT.size.x * _snail_grow
		_snail.scale = Vector2(_snail_dir * base * (1.0 + inch * 0.06), base * (1.0 - inch * 0.05))
	if not _ending:
		_drop_wait -= delta
		if _drop_wait <= 0.0:
			_drop_wait = randf_range(drop_interval.x, drop_interval.y)
			_spawn_drop()

func _exit_tree() -> void:
	if _back != null and is_instance_valid(_back):
		_back.queue_free()

## fighter: 따라갈 캐릭터 / duration: 슬로우 시간(초) — 끝나면 스스로 사라진다.
## **맵에 add_child 한 뒤** 부를 것(뒤쪽 층을 같은 부모에 끼워 넣는다)
func setup(fighter: Node2D, duration: float) -> void:
	_target = fighter
	_has_target = fighter != null
	_left = duration
	# 같은 캐릭터에 이미 붙어 있던 슬로우 이펙트는 지운다(겹쳐 두 마리가 되지 않게) — 남은 시간은 더 긴 쪽을 잇는다
	for other in get_tree().get_nodes_in_group(GROUP):
		if other != self and other.get("_target") == fighter and not other.is_queued_for_deletion():
			if not other.get("_ending"):
				_left = maxf(_left, float(other.get("_left")))
			other.queue_free()
	add_to_group(GROUP)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if _has_target:
		global_position = fighter.global_position
	_build_back_layer(fighter)
	_spawn_snail()

## 캐릭터 뒤에 그릴 것 — 걸리는 순간의 큰 회오리
func _build_back_layer(fighter: Node2D) -> void:
	var parent := get_parent()
	if parent == null:
		return
	_back = Node2D.new()
	_back.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(_back)
	_back.global_position = global_position
	if fighter != null and fighter.get_parent() == parent:
		parent.move_child(_back, fighter.get_index())
	# 걸리는 순간: 몸 가운데에서 큰 회오리가 빠르게 감기며 퍼졌다 사라진다
	var burst := _sprite(SWIRL_TEX, SWIRL_RECT, _back)
	burst.position = Vector2(0.0, -6.0)
	var burst_full: float = burst_swirl_size / SWIRL_RECT.size.x
	burst.scale = Vector2.ONE * burst_full * 0.3
	var btw := burst.create_tween().set_parallel()
	btw.tween_property(burst, "scale", Vector2.ONE * burst_full, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	btw.tween_property(burst, "rotation_degrees", -540.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	btw.tween_property(burst, "modulate:a", 0.0, 0.35).set_delay(0.25)
	btw.chain().tween_callback(burst.queue_free)

## 머리 위 달팽이 — 크기·자리는 _process가 매 프레임 정하므로 여기선 튀어나오는 정도(_snail_grow)만 트윈한다
func _spawn_snail() -> void:
	_snail = _sprite(SNAIL_TEX, SNAIL_RECT, self)
	_snail.position = Vector2(0.0, snail_y)
	_snail.scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(self, "_snail_grow", 1.0, 0.3).set_delay(0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 달팽이 아래나 몸 옆에서 물방울이 하나 떨어진다
func _spawn_drop() -> void:
	var s := _sprite(DROP_TEX, DROP_RECT, self)
	var from_snail: bool = randf() < 0.5
	if from_snail:
		s.position = Vector2(randf_range(-10.0, 10.0), snail_y + 6.0)
	else:
		s.position = Vector2(randf_range(-26.0, 26.0), randf_range(-30.0, 10.0))
	var full: float = drop_height / DROP_RECT.size.y * randf_range(0.8, 1.15)
	s.scale = Vector2(full * 0.6, full * 0.3)
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector2.ONE * full, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_parallel()
	tw.chain().tween_property(s, "position:y", s.position.y + randf_range(22.0, 32.0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(s, "modulate:a", 0.0, 0.2).set_delay(0.3)
	tw.chain().tween_callback(s.queue_free)

## 슬로우가 끝나면 전부 흐려지며 사라진다
func _fade_out() -> void:
	if _ending:
		return
	_ending = true
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 0.0, fade_time)
	if _back != null and is_instance_valid(_back):
		tw.tween_property(_back, "modulate:a", 0.0, fade_time)
	tw.chain().tween_callback(queue_free)

## 그림 한 장 — 보이는 영역의 중심이 노드 원점에 오게 offset을 준다(돌릴 때 흔들리지 않게)
func _sprite(tex: Texture2D, visible_rect: Rect2, parent: Node) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.offset = tex.get_size() * 0.5 - visible_rect.get_center()
	parent.add_child(s)
	return s
