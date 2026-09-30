extends Node2D

## 카운터 반격 연출 — 화면 전체를 검은 막으로 살짝 덮고, 그 위에서 지하철 아저씨 선글라스만 번쩍인다(2026-09-30 사용자 결정).
## `CounterSkill`이 맵에 붙이고 `setup(렌즈 노드)` -> 후려치는 순간 `release()`(막이 걷히고 스스로 사라짐).
## **캐릭터까지 덮어야 해서** z_index를 맵 앞 기둥(50)보다 높게 두고, 번쩍임은 그 위 자식에 더하기 블렌드로 그린다.
## 시간은 슬로우(Engine.time_scale)와 상관없이 실제 초로 흐른다 — 슬로우 중에도 번쩍임이 늘어지지 않게.
## 도형은 원·선만 쓴다(크기가 0이 되는 다각형은 분할 실패 에러를 낸다)

## 검은 막 불투명도(0.24 = 투명도 76%)
@export var dim_alpha: float = 0.24
## 막이 깔리는 / 걷히는 시간(실제 초)
@export var fade_in: float = 0.08
@export var fade_out: float = 0.15
## 막이 깔린 뒤 번쩍임이 시작되는 시각과 길이(실제 초)
@export var flash_at: float = 0.1
@export var flash_length: float = 0.4
## 번쩍임 크기(월드 px) — 둥근 빛 반지름 / 십자 빛줄기 가로 반길이
@export var glow_radius: float = 13.0
@export var ray_length: float = 70.0
@export var glow_color: Color = Color(1.0, 0.97, 0.8)
## release()가 안 불려도 이 시간(실제 초) 뒤엔 스스로 걷힌다(안전장치)
@export var max_life: float = 2.0

## 화면을 다 덮을 만큼 큰 사각형 반폭(월드 px) — 카메라가 어디 있어도 가려지게
const COVER: float = 6000.0

var _lens: Node2D = null
var _t: float = 0.0
var _release_t: float = -1.0
var _glint: Node2D

func _ready() -> void:
	z_index = 95
	z_as_relative = false
	var shade := CanvasItemMaterial.new()
	shade.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = shade
	_glint = Node2D.new()
	_glint.z_index = 1
	var glow := CanvasItemMaterial.new()
	glow.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glint.material = glow
	_glint.draw.connect(_draw_glint)
	add_child(_glint)

## 번쩍일 자리(선글라스 렌즈 노드). 이 노드를 매 프레임 따라간다
func setup(lens: Node2D) -> void:
	_lens = lens
	_follow()

## 후려치는 순간 부른다 — 막을 걷고 사라진다
func release() -> void:
	if _release_t < 0.0:
		_release_t = _t

func _process(delta: float) -> void:
	# 슬로우와 상관없이 실제 시간으로 흐르게 배속을 되돌려 더한다
	_t += delta / maxf(Engine.time_scale, 0.0001)
	if _release_t < 0.0 and _t >= max_life:
		release()
	if _release_t >= 0.0 and _t - _release_t >= fade_out:
		queue_free()
		return
	_follow()
	queue_redraw()
	_glint.queue_redraw()

func _follow() -> void:
	if _lens != null and is_instance_valid(_lens):
		global_position = _lens.global_position

## 막 진하기 0~1
func _dim_amount() -> float:
	var k: float = clampf(_t / maxf(fade_in, 0.001), 0.0, 1.0)
	if _release_t >= 0.0:
		k *= 1.0 - clampf((_t - _release_t) / maxf(fade_out, 0.001), 0.0, 1.0)
	return k

## 번쩍임 세기 0~1 — 빠르게 치솟았다가(앞 25%) 천천히 잦아든다
func _flash_amount() -> float:
	var p: float = (_t - flash_at) / maxf(flash_length, 0.001)
	if p <= 0.0 or p >= 1.0:
		return 0.0
	if p < 0.25:
		return p / 0.25
	return 1.0 - (p - 0.25) / 0.75

func _draw() -> void:
	var a: float = dim_alpha * _dim_amount()
	if a <= 0.001:
		return
	draw_rect(Rect2(-COVER, -COVER, COVER * 2.0, COVER * 2.0), Color(0, 0, 0, a))

func _draw_glint() -> void:
	var f: float = _flash_amount()
	# 번쩍임이 끝나도 막이 있는 동안은 렌즈가 은은하게 빛난다
	var ember: float = 0.35 * _dim_amount() if _t > flash_at else 0.0
	var k: float = maxf(f, ember)
	if k <= 0.01:
		return
	var c := glow_color
	# 둥근 빛 — 바깥일수록 옅게 세 겹
	for i in 3:
		var r: float = glow_radius * (1.0 + i * 0.7) * (0.6 + 0.4 * k)
		_glint.draw_circle(Vector2.ZERO, r, Color(c.r, c.g, c.b, 0.45 * k / (i + 1)))
	if f <= 0.01:
		return
	# 십자 빛줄기 — 가로로 길게, 세로는 짧게, 대각선은 더 짧게
	var w: float = 3.0 * f
	_glint.draw_line(Vector2(-ray_length * f, 0), Vector2(ray_length * f, 0), Color(c.r, c.g, c.b, f), w)
	_glint.draw_line(Vector2(0, -ray_length * 0.45 * f), Vector2(0, ray_length * 0.45 * f), Color(c.r, c.g, c.b, f), w)
	var d: float = ray_length * 0.22 * f
	_glint.draw_line(Vector2(-d, -d), Vector2(d, d), Color(c.r, c.g, c.b, 0.7 * f), w * 0.6)
	_glint.draw_line(Vector2(-d, d), Vector2(d, -d), Color(c.r, c.g, c.b, 0.7 * f), w * 0.6)
	_glint.draw_circle(Vector2.ZERO, glow_radius * 0.5 * f, Color(1, 1, 1, f))
