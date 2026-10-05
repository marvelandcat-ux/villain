@tool
class_name GymBackdropSettings
extends Resource

## **헬스장 배경 레이어 설정** — 창밖 도시, 창틀 줄의 자리와 크기를 적어 둔다.
##
## 맵 씬(`maps/Gym.tscn`)에 직접 적지 않고 리소스로 뺀 이유는, 눈으로 보고 맞추는
## 조정 씬(`maps/GymBackdropStudio.tscn`)이 **이 파일 하나만 덮어쓰면 되기 때문**이다.
## 맵 씬을 통째로 다시 저장하면 다른 노드까지 휩쓸린다

@export_group("하늘")
## **창밖 하늘.** 그림 없이 색으로만 깐다 — 창틀 사이로 조각조각 보이는 자리라
## 구름 하나까지 그릴 이유가 없다. 위에서 아래로 두 색을 섞는다
@export var sky_top: Color = Color(0.05, 0.07, 0.18, 1.0)
@export var sky_bottom: Color = Color(0.13, 0.17, 0.34, 1.0)
## 하늘이 덮는 네모 — 창이 뚫린 자리를 넉넉히 감싸야 한다
@export var sky_rect: Rect2 = Rect2(-1400.0, -620.0, 2800.0, 760.0)
## 별 개수(0이면 안 뿌린다)와 크기
@export var star_count: int = 70
@export var star_size: float = 2.2
@export var star_color: Color = Color(1.0, 0.98, 0.85, 0.85)

@export_group("창밖 도시")
## 도시 그림의 한가운데 자리
@export var city_center: Vector2 = Vector2(0.0, -170.0)
## 가로로 몇 px을 덮을지 — 그림이 모자라면 좌우로 반복된다
@export var city_width: float = 2600.0
## 그림 크기 배수
@export var city_scale: Vector2 = Vector2(1.0, 1.0)

@export_group("벽")
## **창이 뚫려 있는 안쪽 벽.** 통짜로 깔면 창밖이 다 가려지므로,
## 창과 창 **사이**·창 **위아래**만 조각으로 메운다
@export var wall_rect: Rect2 = Rect2(-1400.0, -620.0, 2800.0, 790.0)
## 밤이라 흰 벽도 그대로 두면 너무 튄다 — 한 겹 죽인다
@export var wall_tint: Color = Color(0.68, 0.70, 0.76, 1.0)
## 벽 조각과 창틀이 만나는 자리를 이만큼 겹친다(px) — 0이면 1px짜리 틈이 비친다
@export var wall_overlap: float = 4.0
## 벽 그림에서 **테두리를 뺀 안쪽**만 쓴다(px). 테두리까지 쓰면 조각마다 줄이 생긴다
@export var wall_inset: float = 0.0
## 벽 무늬 한 장을 게임에서 얼마나 크게 보일지. 조각을 늘려 쓰면 무늬가 찌그러지므로
## **크기는 이 값으로 정하고, 모자란 만큼은 반복**시킨다
@export var wall_tile_scale: float = 0.17

@export_group("창틀")
## 창틀 줄의 한가운데 자리
@export var window_center: Vector2 = Vector2(0.0, -170.0)
## 몇 칸을 늘어놓을지
@export var window_count: int = 8
## 칸과 칸의 **중심 사이** 거리(px)
@export var window_spacing: float = 330.0
## 창틀 한 칸의 크기 배수
@export var window_scale: Vector2 = Vector2(0.28, 0.28)
