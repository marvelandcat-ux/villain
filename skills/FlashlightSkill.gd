class_name FlashlightSkill
extends Skill

## **후레쉬** — 경찰이 앞쪽을 둥글게 비춘다(2026-10-07 에피소드 2 설계).
##
## 악플러의 집은 `Blackout`(CanvasModulate)이 방 전체를 어둡게 깔아 두는 맵이다.
## **`CanvasModulate`는 `Light2D`를 못 덮는다** — 그래서 모니터 불빛처럼 `PointLight2D` 하나만 켜면
## 그 근처만 환하게 뚫린다. 감마를 따로 만질 필요가 없다(모니터 조명이 이미 쓰는 방식이다).
##
## 빛은 **바라보는 쪽 앞으로** 나가고, 몸을 돌리면 같이 돈다.
##
## ⚠️ **시야만 밝힌다 — 판정은 아무것도 안 바뀐다.** 어두워도 맞을 건 맞는다(`Blackout`과 같은 약속).

## 켜 두는 시간(초)
@export var duration: float = 5.0
## 빛이 닿는 거리(px) — 그림 반지름이라 실제로 보이는 건 이 값의 두 배 폭이다
@export var light_radius: float = 220.0
## 빛의 세기. 어두운 방에서 얼굴이 보일 만큼만
@export var light_energy: float = 1.5
## 빛 색 — 손전등이라 살짝 누런 흰색
@export var light_color: Color = Color(1.0, 0.97, 0.86, 1.0)
## **앞으로 얼마나 내밀지 / 눈높이**(px). 캐릭터 원점 기준이고, 바라보는 쪽으로 뒤집힌다
@export var light_offset: Vector2 = Vector2(90.0, -18.0)
## 켜고 끌 때 밝아지고 어두워지는 시간(초). 0이면 뚝 켜진다
@export var ramp_time: float = 0.12
## 가운데가 환하고 가장자리로 갈수록 사라지는 정도 — 1에 가까울수록 테두리가 부드럽다
@export_range(0.0, 1.0, 0.05) var softness: float = 0.75

## 지금 켜 둔 불(없으면 꺼져 있는 것)
var _light: PointLight2D = null
## 남은 시간(초)
var _left: float = 0.0
var _fighter: Fighter = null

## HUD에 남은 시간을 띄운다(지속 시간이 있는 다른 궁들과 같은 방식)
func active_ratio() -> float:
	if _left <= 0.0 or duration <= 0.0:
		return -1.0
	return clampf(_left / duration, 0.0, 1.0)

func _execute(fighter: Fighter) -> void:
	if not is_instance_valid(fighter):
		return
	_fighter = fighter
	_left = duration
	if is_instance_valid(_light):
		return   # 이미 켜져 있으면 시간만 다시 채운다
	_light = PointLight2D.new()
	_light.name = "Flashlight"
	_light.texture = _make_glow()
	_light.color = light_color
	_light.energy = 0.0 if ramp_time > 0.0 else light_energy
	# **캐릭터에 붙인다** — 걸어가면 빛도 같이 간다
	fighter.add_child(_light)
	_aim()

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(_light):
		return
	if not is_instance_valid(_fighter):
		_kill()
		return
	_left = maxf(_left - delta, 0.0)
	_aim()
	# 켤 때는 밝아지고, 끝나갈 때는 어두워진다
	var want: float = light_energy
	if ramp_time > 0.0:
		var on: float = clampf((duration - _left) / ramp_time, 0.0, 1.0)
		var off: float = clampf(_left / ramp_time, 0.0, 1.0)
		want = light_energy * minf(on, off)
	_light.energy = want
	if _left <= 0.0:
		_kill()

## 바라보는 쪽 앞으로 빛을 돌린다
func _aim() -> void:
	if not (is_instance_valid(_light) and is_instance_valid(_fighter)):
		return
	var dir: float = signf(_fighter.facing)
	if dir == 0.0:
		dir = 1.0
	_light.position = Vector2(light_offset.x * dir, light_offset.y)

func _kill() -> void:
	if is_instance_valid(_light):
		_light.queue_free()
	_light = null
	_left = 0.0

## 가운데가 희고 가장자리로 갈수록 투명해지는 **둥근** 빛 그림.
## 그림 파일을 안 쓰는 이유: 반지름·번짐을 인스펙터에서 바로 만지고 싶어서다
func _make_glow() -> GradientTexture2D:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, clampf(1.0 - softness, 0.0, 0.95), 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = ramp
	tex.fill = GradientTexture2D.FILL_RADIAL
	# 가운데에서 바깥으로 퍼지게 — 0.5,0.5가 한가운데다
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var size: int = int(maxf(light_radius, 8.0)) * 2
	tex.width = size
	tex.height = size
	return tex

func _exit_tree() -> void:
	_kill()
