class_name TitleLogo
extends Control

## 타이틀 로고 "트러블 메이커"(2026-09-28 사용자 요청 — 델타룬 타이틀처럼). 세 겹(같은 캔버스, tools/make_title_logo.py가 만든다):
## Glow(글자 둘레 은은한 빛) -> Fill(글자 안쪽) -> Line(원본 검은 테두리, 그대로 유지 — 사용자 결정).
## 하양으로 머물다 -> 빛이 세지며 빛줄기가 훑고 -> 글자 안에 무지개(왼쪽 -> 오른쪽으로 흐름)가 차오르고 -> 다시 하양, 계속 반복.
## 색 계산은 ui/TitleLogo.gdshader, 여기선 시간에 따라 값만 넣는다

## 하양으로 머무는 시간(초)
@export var white_time: float = 2.5
## 빛나기(빛 세짐 + 빛줄기 훑기) 시간(초)
@export var shine_time: float = 0.9
## 무지개가 차오르는/빠지는 시간(초)
@export var rainbow_fade_time: float = 0.8
## 무지개로 머무는 시간(초)
@export var rainbow_time: float = 3.0
## 무지개가 흐르는 빠르기(초당 몇 바퀴)
@export var flow_speed: float = 0.35
## 평소 빛 세기 / 빛나기 순간 최대 / 무지개일 때
@export var glow_base: float = 0.3
@export var glow_peak: float = 0.9
@export var glow_rainbow: float = 0.55

@onready var _glow: TextureRect = $Glow
@onready var _fill: TextureRect = $Fill

var _t: float = 0.0
var _flow: float = 0.0

func _ready() -> void:
	# Glow·Fill이 셰이더 재질을 나눠 쓰지 않게 각자 복제(한쪽만 is_glow)
	_glow.material = _glow.material.duplicate()
	_fill.material = _fill.material.duplicate()
	_glow.material.set_shader_parameter("is_glow", true)
	_apply(0.0, glow_base, -1.0)

func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	_flow += delta * flow_speed
	var cycle: float = white_time + shine_time + rainbow_fade_time * 2.0 + rainbow_time
	_t = fmod(_t + delta, maxf(cycle, 0.01))
	var t: float = _t
	var rainbow: float = 0.0
	var glow: float = glow_base
	var sweep: float = -1.0
	if t < white_time:
		pass
	elif t < white_time + shine_time:
		var k: float = (t - white_time) / maxf(shine_time, 0.01)
		glow = lerpf(glow_base, glow_peak, sin(k * PI))
		# 빛줄기는 로고 왼쪽 밖에서 오른쪽 밖까지(사선이라 조금 더 멀리)
		sweep = lerpf(-0.25, 1.25, k)
	else:
		t -= white_time + shine_time
		if t < rainbow_fade_time:
			rainbow = t / maxf(rainbow_fade_time, 0.01)
		elif t < rainbow_fade_time + rainbow_time:
			rainbow = 1.0
		else:
			rainbow = 1.0 - (t - rainbow_fade_time - rainbow_time) / maxf(rainbow_fade_time, 0.01)
		rainbow = smoothstep(0.0, 1.0, rainbow)
		glow = lerpf(glow_base, glow_rainbow, rainbow)
	_apply(rainbow, glow, sweep)

func _apply(rainbow: float, glow: float, sweep: float) -> void:
	for mat in [_glow.material, _fill.material]:
		mat.set_shader_parameter("rainbow", rainbow)
		mat.set_shader_parameter("flow", _flow)
		mat.set_shader_parameter("sweep_pos", sweep)
	_glow.material.set_shader_parameter("glow_strength", glow)
