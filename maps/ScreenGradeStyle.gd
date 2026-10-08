class_name ScreenGradeStyle
extends Resource

## 화면 색보정(`ScreenGrade`) 한 벌 — 맵마다 `.tres`로 만들어 `Stage.screen_grade`에 꽂는다(2026-10-08).
## 칸 이름은 `ScreenGrade.gdshader`의 uniform 이름과 **같아야 한다**(이름으로 넘긴다). 프리셋은 `maps/grade/`

@export_group("색보정")
## 곱해 주는 색(어두운 데는 어둡게 남는다). tint_strength 0이면 안 곱한다
@export var tint: Color = Color(1.0, 1.0, 1.0)
@export_range(0.0, 1.0) var tint_strength: float = 0.0
@export_range(0.5, 1.5) var contrast: float = 1.0
@export_range(0.0, 2.0) var saturation: float = 1.0
@export_range(-0.3, 0.3) var brightness: float = 0.0
@export_group("비네트")
## 가장자리 어둡게 — 세기
@export_range(0.0, 1.0) var vignette: float = 0.0
## 어두워지기 시작하는 거리(화면 세로 절반 = 1.0, 모서리 ≈ 2.0)
@export_range(0.3, 1.5) var vignette_radius: float = 0.9
@export_range(0.05, 1.5) var vignette_softness: float = 1.0
@export_group("그레인")
## 필름 알갱이 세기
@export_range(0.0, 0.3) var grain: float = 0.0
## 알갱이 한 칸(720p 기준 픽셀)
@export_range(1.0, 4.0) var grain_size: float = 1.5
@export_group("")

## 셰이더에 넘기는 칸 이름들
const PARAMS: PackedStringArray = ["tint", "tint_strength", "contrast", "saturation", "brightness",
	"vignette", "vignette_radius", "vignette_softness", "grain", "grain_size"]
