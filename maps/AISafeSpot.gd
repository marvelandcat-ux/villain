class_name AISafeSpot
extends Marker2D

## 맵 기믹(지나가는 열차 등)이 위험한 동안 AI가 피신할 수 있는 지점 표시자.
## Marker2D를 원하는 위치(지하철 승강장의 의자 발판 위 등)에 놓고 이 스크립트만 붙이면 된다 —
## AIController가 "ai_safe_spot" 그룹으로 찾아서 가장 가까운 곳으로 걸어가 뛰어오른다

func _ready() -> void:
	add_to_group("ai_safe_spot")
