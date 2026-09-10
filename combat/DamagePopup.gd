class_name DamagePopup
extends Node2D

## 피격 지점에 데미지 숫자를 통통 튀며 위로 띄웠다 사라지게 하는 팝업. 콤보 2 이상이면 "N HIT"도 같이 표시한다.
## Hitbox가 명중 지점에서 스폰하고 setup(데미지, 콤보)로 값을 넘긴다.

## 이 데미지 이상이면 숫자가 가장 크고 빨갛게 표시된다 (그 미만은 데미지에 비례해 작고 흰색 쪽)
@export var big_hit_damage: float = 25.0
## 방어로 막았을 때 뜨는 "BLOCK" 글자 크기·색 (데미지 숫자와 달리 세기에 안 비례한다)
@export var block_font_size: int = 28
@export var block_color: Color = Color(0.55, 0.8, 1.0)
## 떠오르는 높이(px)와 전체 지속시간(초)
@export var rise_height: float = 34.0
@export var duration: float = 0.6

@onready var _damage: Label = $Damage
@onready var _combo: Label = $Combo

## 데미지 숫자와(콤보 2 이상이면) 콤보 수를 설정하고 애니메이션을 시작한다
func setup(damage: int, combo: int = 0) -> void:
	z_index = 100   # 캐릭터·이펙트 위에 그린다
	for lbl in [_damage, _combo]:
		lbl.add_theme_constant_override("outline_size", 6)
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))

	_damage.text = str(damage)
	# 약타=작고 흰색, 강타=크고 빨갛게
	var t: float = clampf(float(damage) / big_hit_damage, 0.0, 1.0)
	_damage.add_theme_font_size_override("font_size", int(round(lerp(20.0, 46.0, t))))
	_damage.add_theme_color_override("font_color", Color(1, 1, 1).lerp(Color(1.0, 0.25, 0.2), t))

	if combo >= 2:
		_combo.visible = true
		_combo.text = "%d HIT" % combo
		_combo.add_theme_font_size_override("font_size", 20)
		_combo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		_combo.visible = false

	_animate()

## 방어로 막혔을 때 — 숫자 대신 "BLOCK"을 띄운다. 실제로 깎인 HP가 0이라 숫자를 띄우면
## 막았는데도 데미지가 들어간 것처럼 보인다. 크기·색은 데미지와 무관하게 고정이다
func setup_block() -> void:
	z_index = 100
	for lbl in [_damage, _combo]:
		lbl.add_theme_constant_override("outline_size", 6)
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_damage.text = "BLOCK"
	_damage.add_theme_font_size_override("font_size", block_font_size)
	_damage.add_theme_color_override("font_color", block_color)
	_combo.visible = false
	_animate()

func _animate() -> void:
	# 살짝 작게 시작해 통통 튀어오르며 커진다
	scale = Vector2(0.5, 0.5)
	var pop := create_tween()
	pop.tween_property(self, "scale", Vector2(1.2, 1.2), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)
	# 위로 떠오른다
	var up := create_tween()
	up.tween_property(self, "position:y", position.y - rise_height, duration).set_ease(Tween.EASE_OUT)
	# 뒷부분에 서서히 사라지고 정리
	var fade := create_tween()
	fade.tween_interval(duration * 0.55)
	fade.tween_property(self, "modulate:a", 0.0, duration * 0.45)
	fade.tween_callback(queue_free)
