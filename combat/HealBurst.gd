class_name HealBurst
extends Node2D

## 회복할 때 몸 주위에 터지는 연두색 이펙트 (순수 장식 — 판정이 없다).
## 뒤쪽(캐릭터 뒤): 원형 빛 + 솟는 빛기둥 / 앞쪽(캐릭터 앞): 떠오르는 십자가 + 반짝이.
##
## `Fighter._spawn_heal_burst()`가 **맵에** 붙이고 `setup(fighter, 세기)`를 부른다(캐릭터 자식이면 좌우 반전에 뒤집힘).
## 위치는 매 프레임 캐릭터를 따라간다 — 회복하면서 움직여도 이펙트가 몸에 붙어 있다.
## 뒤쪽 층은 맵에서 캐릭터 바로 앞 순서로 끼워 넣어 캐릭터 그림 뒤에 그려지게 한다(음수 z는 맵 그림 뒤로 숨어서 안 씀)

const CROSS_TEX := preload("res://sprite/VFX/heal_effect_fixed_1.png")
const GLOW_TEX := preload("res://sprite/VFX/heal_clean_2_orb_final.png")
const SPARKLE_TEX := preload("res://sprite/VFX/heal_clean_3_sparkle.png")
const BEAM_TEX := preload("res://sprite/VFX/heal_clean_5_beam.png")

## 캐릭터 원점(몸 가운데)에서 발바닥까지(px) — 캡슐 반지름 20 + 절반 30
const FEET_Y: float = 30.0
## 이펙트가 다 사라지기까지(초)
const LIFE: float = 1.6

## 십자가 크기(px, 화면 기준) 최소~최대
@export var cross_size: Vector2 = Vector2(22.0, 30.0)
## 십자가가 떠오르는 높이(px) 최소~최대
@export var cross_rise: Vector2 = Vector2(55.0, 80.0)
## 원형 빛 지름(px, 세기 1일 때)
@export var glow_size: float = 135.0
## 빛기둥 높이(px, 세기 1일 때)
@export var beam_height: float = 130.0

var _target: Node2D = null
var _has_target: bool = false
var _back: Node2D = null

func _process(_delta: float) -> void:
	if _has_target and is_instance_valid(_target):
		global_position = _target.global_position
	if _back != null and is_instance_valid(_back):
		_back.global_position = global_position

func _exit_tree() -> void:
	if _back != null and is_instance_valid(_back):
		_back.queue_free()

## fighter: 따라갈 캐릭터 / power: 0~1 세기(회복량이 클수록 큼 — 작은 회복은 십자가 몇 개만)
## **맵에 add_child 한 뒤** 부를 것(뒤쪽 층을 같은 부모에 끼워 넣는다)
func setup(fighter: Node2D, power: float) -> void:
	_target = fighter
	_has_target = fighter != null
	power = clampf(power, 0.0, 1.0)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if _has_target:
		global_position = fighter.global_position
	_build_back_layer(fighter, power)
	var crosses: int = 2 + roundi(3.0 * power)
	for i in crosses:
		_spawn_cross(i, crosses)
	for i in 3 + roundi(4.0 * power):
		_spawn_sparkle()
	Timers.self_destruct(self, LIFE)

## 캐릭터 뒤에 그릴 것들 — 세기가 약하면(고양이 핥기 같은 작은 회복) 생략한다
func _build_back_layer(fighter: Node2D, power: float) -> void:
	if power < 0.3:
		return
	var parent := get_parent()
	if parent == null:
		return
	_back = Node2D.new()
	_back.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(_back)
	_back.global_position = global_position
	if fighter != null and fighter.get_parent() == parent:
		parent.move_child(_back, fighter.get_index())
	var size_k: float = lerpf(0.6, 1.0, power)
	_spawn_glow(glow_size * size_k)
	_spawn_beam(beam_height * size_k)

## 몸 가운데에서 부풀었다 사라지는 원형 빛
func _spawn_glow(diameter: float) -> void:
	var s := _sprite(GLOW_TEX, _back)
	var full: float = diameter / GLOW_TEX.get_width()
	s.position = Vector2(0.0, -8.0)
	s.scale = Vector2.ONE * full * 0.35
	s.modulate.a = 0.0
	var tw := s.create_tween().set_parallel()
	tw.tween_property(s, "scale", Vector2.ONE * full, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.8, 0.1)
	tw.chain().tween_property(s, "modulate:a", 0.0, 0.55).set_delay(0.15)

## 발밑에서 위로 솟았다가 가늘어지며 사라지는 빛기둥 — 아래 가운데가 원점
func _spawn_beam(height: float) -> void:
	var s := _sprite(BEAM_TEX, _back)
	s.centered = false
	s.offset = Vector2(-BEAM_TEX.get_width() * 0.5, -BEAM_TEX.get_height())
	var full: float = height / BEAM_TEX.get_height()
	s.position = Vector2(0.0, FEET_Y)
	s.scale = Vector2(full * 0.85, 0.0)
	s.modulate.a = 0.85
	var tw := s.create_tween()
	tw.tween_property(s, "scale:y", full, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_parallel()
	tw.chain().tween_property(s, "scale:x", 0.0, 0.4).set_delay(0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(s, "modulate:a", 0.0, 0.4).set_delay(0.12)

## 몸 주위에서 톡 튀어나와 위로 떠오르며 사라지는 십자가. 순서대로 조금씩 늦게 나와서 "뿅뿅뿅"
func _spawn_cross(index: int, count: int) -> void:
	var s := _sprite(CROSS_TEX, self)
	# 좌우로 고르게 나누고 조금씩 흔든다 — 랜덤만 쓰면 한쪽에 몰린다
	var lane: float = (float(index) + 0.5) / float(count) * 2.0 - 1.0
	s.position = Vector2(lane * 34.0 + randf_range(-6.0, 6.0), randf_range(-36.0, 18.0))
	var full: float = randf_range(cross_size.x, cross_size.y) / CROSS_TEX.get_width()
	s.scale = Vector2.ZERO
	s.rotation_degrees = randf_range(-12.0, 12.0)
	var delay: float = index * 0.07 + randf_range(0.0, 0.04)
	var rise: float = randf_range(cross_rise.x, cross_rise.y)
	var life: float = randf_range(0.75, 0.9)
	var tw := s.create_tween()
	tw.tween_interval(delay)
	# 팝: 살짝 크게 튀었다 제 크기로
	tw.tween_property(s, "scale", Vector2.ONE * full * 1.3, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "scale", Vector2.ONE * full, 0.08)
	tw.set_parallel()
	tw.chain().tween_property(s, "position:y", s.position.y - rise, life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "rotation_degrees", 0.0, life * 0.6)
	tw.tween_property(s, "modulate:a", 0.0, life * 0.4).set_delay(life * 0.6)

## 몸 둘레에서 반짝 돌며 커졌다 꺼지는 작은 별
func _spawn_sparkle() -> void:
	var s := _sprite(SPARKLE_TEX, self)
	var angle: float = randf() * TAU
	var radius: float = randf_range(22.0, 48.0)
	s.position = Vector2(cos(angle) * radius, sin(angle) * radius * 0.9 - 10.0)
	var full: float = randf_range(11.0, 17.0) / SPARKLE_TEX.get_height()
	s.scale = Vector2.ZERO
	s.rotation_degrees = randf_range(-30.0, 30.0)
	var delay: float = randf_range(0.05, 0.45)
	var tw := s.create_tween()
	tw.tween_interval(delay)
	tw.set_parallel()
	tw.chain().tween_property(s, "scale", Vector2.ONE * full, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "rotation_degrees", s.rotation_degrees + 90.0, 0.4)
	tw.tween_property(s, "position:y", s.position.y - 16.0, 0.4)
	tw.chain().tween_property(s, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _sprite(tex: Texture2D, parent: Node) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	parent.add_child(s)
	return s
