extends Resource

## 연행 장면 뒤에 서는 **건물 정면 그림 한 장 + 그 그림을 원근에 맞추는 표시**.
## 인물들이 이 건물 문에서 막 나온 것처럼 보이게, 장면이 **문**을 크기 기준점으로 삼아 그림을 놓는다:
## 문 아랫변이 장면의 "건물이 땅에 닿는 선"(ArrestScene.facade_base_y)에 오고, 문 높이가 캐릭터 키의 door_height배가 된다.
## 그래서 그림을 갈아 끼울 땐 **그림 속 문 자리(door_rect)만 재서 적으면** 크기·자리·밀고 들어가기가 저절로 맞는다.
## 새 그림을 그릴 땐 `ui/result/backdrops/원근가이드.png` 위에 그리면 지평선·소실점까지 맞는다.
## **맵마다 한 장**: 파일 이름이 맵 씬 이름과 같으면(헬스장 = maps/Gym.tscn → backdrops/Gym.tres) 그 맵에서 싸웠을 때 저절로 쓰인다.
## 그림(texture)을 비워 두면 기본 건물(경찰서)이 선다
## class_name을 일부러 안 단다(새 class_name을 바로 타입으로 쓰면 파싱 에러) — .tres가 스크립트 경로로 물고 있다

## 건물 정면 그림(투명 배경 PNG — 하늘·앞길은 장면이 그린다)
@export var texture: Texture2D
## 그림 속 출입문 사각형(px). 크기가 0이면 "원근 가이드 위에 화면 그대로 그린 그림"으로 보고 화면에 1:1로 깐다
@export var door_rect: Rect2 = Rect2()
## 그림 속 건물이 땅(길)에 닿는 높이(px) — 이 아래는 잘라 낸다(앞길은 장면이 그린다). 0이면 그림 맨 아래,
## 문 자리 없이 가이드 위에 그린 그림이면 가이드의 초록 선
@export var ground_px: float = 0.0
## 문 높이 = 캐릭터 키의 몇 배인지(어린이 체형 캐릭터라 실제 비율보다 조금 크다)
@export var door_height: float = 1.35
## 그림이 그려진 눈높이(지평선, px). -1이면 모름 — 알면 장면 지평선과 어긋날 때 경고한다
@export var horizon_px: float = -1.0
## 경찰서 그림 전용 펄럭이는 깃발을 켤지(다른 건물이면 끈다)
@export var show_flags: bool = false
## 그림 가장자리를 하늘로 살짝 녹일지(잘린 건물 그림용)
@export var edge_fade: bool = true
