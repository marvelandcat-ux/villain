---
paths:
  - "maps/**"
  - "sprite/맵/**"
  - "skills/GroundPoundSkill.gd"
  - "skills/WorkoutSkill.gd"
---

# 맵

- `CameraRig`: `add_trauma()` 순간 충격, `set_rumble()` 지속 진동. `_apply_wall_limits()`가 벽 폭으로 최소 줌 강제. `view_scale`/`zoom_boost`는 타이틀용 static
- `maps/ParallaxFollow.gd`(`factor` < 1 먼 층, > 1 앞 층). 앞 층 흐림 `foreground_blur.gdshader`, 먼 층 `far_blur.gdshader`
- 맵 스킬: `GroundPoundSkill`(지상이면 쿨 환불, 발판 `break_platform()`), `WorkoutSkill`

## 놀이터 `maps/Playground.tscn` — 왕관 훔쳐서 달아나기

- ⚠️ **빌더 `tools/build_playground.py`는 돌리면 안 된다**(씬을 손으로 고침). 돌린다면 백업 + 손수정 값을 `PLATFORM_OVERRIDES`·`CROWN_POS`로 옮긴 뒤
- 바닥 y=280, 벽 ±960, 스프링 좌석 y=226, 지붕 y=-82, 중간 구름 y≈-228, 꼭대기 y=-418, 왕관(25, -472). 카메라 `min_y` -300(구름을 올리면 같이). **모든 발판은 원웨이**
- ⚠️ TODO: 점프력 변경 뒤 재실측 안 됨 — 중간→꼭대기 여유 ~3px
- 미끄럼틀 `PavilionLeft/Right`: **왼쪽만 판정**, 바디 넷(한 바디에 몰지 말 것)
- 그네 `Swing.gd`: 튕김 + `apply_hitstun` 필수. 스프링 `SpringJumpPad.gd`: 직전 낙하 속도로 튕김 + `cancel_landing_lag()`
- 왕관 `Crown.gd`: 닿으면 왕(`Crown.is_king()`), 넉백 피해에 떨어뜨림. **승리 조건은 안 건드림**, `pickup_delay` 0 금지. 그림 `진짜왕관.png`는 맵과 `CrownCutIn.tscn` 두 곳
- 모래 `SandPit.gd`: 발치 높이에만 둔화. `모래사장.png`(괄호 없음)는 쓰지 말 것

## 지하철 승강장 `maps/SubwayPlatform.tscn`

- 선로 바닥 y=300, 벽 ±560, 의자 발판 y=155(원웨이, z 0). **의자 위 = 열차 피난처**(의자 높이·열차 크기는 같이 계산), 의자는 트리에서 열차보다 먼저
- 열차 `SubwayTrain.gd`: 1~5칸, 그림을 잘라 조립(`SEAM_FRONT`/`SEAM_BACK`/`MIDDLE_DRIFT` — **그림을 바꾸면 재측정**)
- 조명 `CanvasModulate` + 형광등. 빛나는 물체는 unshaded. **가산 색은 CanvasModulate가 곱해지므로 조명을 바꾸면 다시 잡을 것**
- 먼 층 `DecoBackground`(CanvasGroup + `far_blur`), 앞 기둥 `ForegroundPillars.gd`. 역 이름판을 옮기면 `SignBand`·`SignBandOutline`도

## 헬스장 `maps/Gym.tscn`

- 2층 발판 + 기구 셋(바벨 컬 = 기본공격력 / 스쿼트 랙 = 점프력 / 런닝머신 = 이동속도). `WorkoutSkill`: 운동 중 발 묶임, 맞음·때림·멀어짐이면 끊김, 스펙은 배수(`custom_data["gym_spec"]`)
- 공격력은 기본공격에만(`compute_basic_damage()`). `GymLayout.gd`는 자식 `_ready()`가 부모보다 먼저라는 것에 기대 스폰을 옮김. `muscle_arm`/`muscle_leg`
- 땅 y=280, 2층 y=100(이단 점프 한계 180px), 벽 ±604. TODO: 운동 모션·기구 그림·배경

## 공사현장 `maps/CollapsingApartment.tscn`

- 부서지는 발판 4층(간격 170 = 이단 점프로만). **점프력이 바뀌면 다시 계산**

## 튜토리얼 `maps/Tutorial.tscn`(뼈대)

- 배경 `sprite/맵/튜토리얼/`(구름 `RandomCloudSpawner.gd`, 국기 `FlagFlutter.gdshader`). 땅 ⚠️ `texture_repeat`는 위아래로도 반복 → `region_rect`를 투명한 윗부분 아래부터. 바닥 y=280, 벽 ±1200
- 훈련 더미를 P1이 조작. **교관 = 황근출(옷 입은 리그만, Fighter 아님)** `Instructor`(scale.x -1)
- **처음 켠 사람만** 타이틀 → 튜토리얼(`GameState.tutorial_seen`)
- 말풍선 `maps/SpeechBubble.gd`(@tool, 전부 `_draw()`): **원점 = 꼬리 끝 = 가리키는 곳**. 교관 자식이면 글자가 뒤집혀 맵 직속. `say(text, hint)`(BBCode), `finish_typing()`, `close()`. 폰트 강한육군 Bold — **모든 `*_font_size` 슬롯 지정**(빼면 `[b]`가 16px). ⚠️ "썌"는 글리프 없음 → "쌔"
- 대사 `Tutorial.gd`: 교관 500px 안에 들면 시작, **스페이스로 한 줄씩**, 강조 `_em()`. 대사 중엔 카메라를 교관 ±450px로 clamp. TODO: 이동·점프 다음 조작 설명

## 훈련장 `maps/TrainingGround.tscn`

- 물리값·게임 속도 슬라이더(static var — 영구 반영은 `DEFAULT_*`), 모든 스킬 쿨 0. `Engine.time_scale`은 `_exit_tree`에서 복구. 충돌 보기 `CollisionDebugView.gd`, 바닥 눈금자 `FloorRuler.gd`
- 디버그 격자: 대전 중 **G + '**(`maps/DebugGrid.gd`)
