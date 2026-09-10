class_name SkillCooldownIcon
extends Control

## 스킬 쿨타임을 "물이 차오르는" 방식으로 보여주는 HUD 슬롯.
## 쿨타임 중에는 스킬 로고가 어둡게 깔려 있고, 아래에서부터 컬러 로고가 차오른다.
## 다 차면(= 쓸 수 있게 되면) 전체가 컬러로 켜지고 테두리가 밝게 맥동한다.
## 로고를 아직 안 그린 캐릭터는 로고 대신 캐릭터 색 사각형이 똑같은 방식으로 차오른다.
##
## 차오르는 그림은 TextureProgressBar가 직접 그린다 —
## texture_under(어두운 로고) 위에 texture_progress(컬러 로고)를 아래에서 위로 채우는 방식.
## 로고 원본이 1000px대라 슬롯 크기(46px)에 맞춰 줄여야 하는데, 줄이는 방법이 두 가지 있고
## 둘 다 함정이 있어서 _fit_bar()가 세 번째 방법을 쓴다:
##  - Control.clip_contents로 직접 잘라내기 -> 캔버스 그룹 합성 때문에 흰 사각형이 비쳐 보인다
##  - TextureProgressBar.nine_patch_stretch -> 진행 영역이 통째로 흰색/회색으로 칠해진다
## 그래서 막대는 텍스처 원본 크기 그대로 두고, Control 자체의 scale로 축소한다

## 테두리(2px) 안쪽 여백
const PAD := 3.0
## 다 찼을 때 / 쿨타임 중 테두리 색
const READY_BORDER := Color(1.0, 0.85, 0.25)
const COOLDOWN_BORDER := Color(0.35, 0.35, 0.42)
## 쿨타임 중 밑에 깔리는 로고에 곱하는 색 (어둡게)
const DIM := Color(0.26, 0.26, 0.32)
## 다 찬 순간 살짝 커졌다 돌아오는 연출의 크기와 속도
const POP_SCALE := 0.2
const POP_SPEED := 4.0
## 다 찼을 때 테두리가 밝아졌다 어두워지는 속도
const PULSE_SPEED := 6.0

@onready var _frame: Panel = $Frame
@onready var _bar: TextureProgressBar = $Bar
@onready var _water_line: ColorRect = $WaterLine
@onready var _key_label: Label = $KeyLabel

## 로고가 없는 스킬이 쓰는 단색 텍스처 (색은 tint로 입힌다)
static var _blank_texture: ImageTexture

var _skill: Skill
## 다 찬 순간 1이 됐다가 0으로 줄어드는 연출용 값
var _pop: float = 0.0
var _was_ready: bool = true
var _pulse_time: float = 0.0
## 슬롯마다 테두리 색을 따로 주기 위해 복제해 둔 스타일박스
var _style: StyleBoxFlat

func _ready() -> void:
	# 테마 스타일박스는 씬 안에서 공유되므로, 복제하지 않으면 한 슬롯의 테두리 색이 전부에 퍼진다
	_style = (_frame.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	_frame.add_theme_stylebox_override("panel", _style)

## 이 슬롯이 표시할 스킬을 지정한다.
## key_hint가 비어 있지 않으면 우하단에 조작 키를 작게 띄운다 (AI가 쓰는 쪽은 빈 문자열).
## fallback_color는 스킬에 로고가 없을 때 로고 대신 차오를 색
func bind(skill: Skill, key_hint: String, fallback_color: Color) -> void:
	_skill = skill
	visible = skill != null
	if skill == null:
		return
	_key_label.text = key_hint
	_key_label.visible = key_hint != ""
	var texture: Texture2D = skill.icon if skill.icon != null else _get_blank_texture()
	_bar.texture_under = texture
	_bar.texture_progress = texture
	# 로고가 있으면 원래 색 그대로, 없으면 캐릭터 색으로 물들여서 채운다
	_bar.tint_progress = Color.WHITE if skill.icon != null else fallback_color
	_bar.tint_under = DIM if skill.icon != null else fallback_color * DIM
	_fit_bar()
	# 라운드 시작 직후 쓸 수 있는 스킬이 괜히 "방금 찼다"고 튀지 않도록 현재 상태로 맞춰 둔다
	_was_ready = skill.can_use()

func _process(delta: float) -> void:
	if _skill == null:
		return
	# cooldown이 0인 스킬(= 언제나 사용 가능)은 항상 꽉 찬 상태로 둔다.
	# 버프가 쿨타임을 덮어썼으면(cooldown_override) 그 값을 기준으로 채워야 물높이가 맞는다
	var ratio: float = 1.0
	var full: float = _skill.effective_cooldown()
	if full > 0.0:
		ratio = clampf(1.0 - _skill.cooldown_left / full, 0.0, 1.0)
	_fit_bar()
	_bar.value = ratio
	_update_water_line(ratio)

	var is_ready: bool = ratio >= 0.999
	if is_ready and not _was_ready:
		_pop = 1.0
	_was_ready = is_ready

	if is_ready:
		_pulse_time += delta
		var pulse: float = 0.72 + 0.28 * sin(_pulse_time * PULSE_SPEED)
		_style.border_color = Color(READY_BORDER.r * pulse, READY_BORDER.g * pulse, READY_BORDER.b * pulse)
	else:
		_pulse_time = 0.0
		_style.border_color = COOLDOWN_BORDER

	if _pop > 0.0:
		_pop = maxf(_pop - delta * POP_SPEED, 0.0)
	pivot_offset = size * 0.5
	scale = Vector2.ONE * (1.0 + POP_SCALE * _pop)

## 로고 원본 비율을 지킨 채 슬롯 안쪽에 꽉 차도록 막대 크기·배율·위치를 잡는다
func _fit_bar() -> void:
	var texture: Texture2D = _bar.texture_progress
	if texture == null:
		return
	var inner: Vector2 = size - Vector2(PAD, PAD) * 2.0
	var source: Vector2 = texture.get_size()
	if inner.x <= 0.0 or inner.y <= 0.0 or source.x <= 0.0 or source.y <= 0.0:
		return
	var fit: float = minf(inner.x / source.x, inner.y / source.y)
	_bar.size = source
	_bar.scale = Vector2(fit, fit)
	_bar.position = (size - source * fit) * 0.5

## 차오르는 중일 때만 수면 하이라이트를 경계선에 얹는다 (다 찼거나 텅 비었을 땐 거슬린다)
func _update_water_line(ratio: float) -> void:
	_water_line.visible = ratio > 0.005 and ratio < 0.995
	if not _water_line.visible:
		return
	# 막대는 scale로 줄여 놨으므로 화면에서의 실제 크기는 size * scale이다
	var drawn: Vector2 = _bar.size * _bar.scale
	_water_line.position = Vector2(_bar.position.x, _bar.position.y + drawn.y * (1.0 - ratio))
	_water_line.size = Vector2(drawn.x, 2.0)

## 입력 액션에 실제로 묶여 있는 키 이름을 가져온다.
## 설정에서 키를 바꿔도 HUD가 자동으로 따라가도록 InputMap에서 그때그때 읽는다
static func key_hint(action: String) -> String:
	if not InputMap.has_action(action):
		return ""
	for event in InputMap.action_get_events(action):
		var key_event := event as InputEventKey
		if key_event == null:
			continue
		var code: Key = key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
		return OS.get_keycode_string(code)
	return ""

## 로고가 없는 스킬용 단색 텍스처. 슬롯 여러 개가 같이 쓰므로 한 번만 만든다
static func _get_blank_texture() -> ImageTexture:
	if _blank_texture == null:
		var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_blank_texture = ImageTexture.create_from_image(image)
	return _blank_texture
