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

## 악플러의 집 `maps/TrashRoom.tscn` — 암전 + 엄마 등짝

- 사용자가 에디터에서 배치·크기를 직접 잡음(2026-10-05). 땅 y=280, 벽 안쪽 -614 ~ 1194(**좌우 비대칭**, 두께 60). 발판 윗면: 왼쪽 -66(-614~-234)·가운데 12(-127~314)·오른쪽 -10(614~1194), **모두 원웨이**
- ⚠️ **StaticBody2D(발판)에 scale 걸지 말 것** — 그림 scale·판정 size를 따로 맞춤. 그림을 키우면 판정도 다시
- 양쪽 발판은 바닥에서 이단 점프로 못 닿음 — **계단 → 가운데 발판 → 점프**가 의도된 동선(사용자 확인)
- 계단 `Stair`(`SlopeStair.gd`): 그림 `악플러 집 계단.png` flip_h, 배율 0.2872. 판정은 계단 발판 가운데를 잇는 ~36도 원웨이 사각형(아래 끝은 땅 속), 맨 윗 계단은 가운데 발판 판정을 x=314까지 늘려서 덮음. **계단 그림을 옮기거나 키우면 판정도**. 이 맵에서만 `floor_snap_length`↑·`floor_constant_speed`
- 카메라: 지붕 `Wall5`(90도 돌린 벽, 윗면 y -611) ~ 땅 그림 아래 354만 보임 — `use_ceiling`/`ceiling_y`/`floor_bottom_y`. 멀리 물러나 화면이 그보다 높아지면 **가운데 정렬 + 위아래 검은 띠**(`CameraRig._build_letterbox`, 월드 z 4000 사각형이라 HUD 안 덮음). **지붕을 옮기면 `ceiling_y`도**
- 이 맵 카메라엔 `limit_top`/`limit_bottom`을 쓰지 말 것 — 위아래 한계가 겹치면 한쪽이 이겨서 가운데 정렬이 깨진다
- 스폰 -397 / 1030(벽 사이 비율 0.12 / 0.91)
- 암전 `Blackout.gd`: 어두운 동안 `cooldown_pies` 그룹 호출로 방어·대시·빨간 X(패링)·금색(궁 지속시간)까지 전부 숨김(2026-10-07). `MonitorLight`는 사용자가 꺼 둠(visible=false)
- 엄마 기믹 `MomDoorGimmick`(문 `DoorLeft`/`DoorRight`): 주기마다 랜덤 문을 열고(경첩 쪽 고정 + 가로로 좁힘, 뒤에 어두운 문틈 Polygon2D) `AkpeulleoMom`("악플러집 엄마")을 **자기 자식으로** 내보냄. 카운트다운·라운드 끝엔 안 셈. 등장 주기 `first_delay`/`interval`은 TODO 임시값
- `AkpeulleoMom`: **Fighter 아님**(IljinCrewMember와 같은 이유), Hurtbox 없음 = 안 맞음, 그림은 `maps/AkpeulleoMomRig.tscn`(`sprite/맵/악플러집/엄마 스프라이트/` — 원본이 흰 배경 RGB라 테두리 flood fill로 투명화함, 머리 공·배율은 캣맘 리그 크기에 맞춰 역산, 손은 캣맘 것, 발은 `엄마 발.png`. 눈빛 `MomEyeGlow.gd`(Head 자식, 노란 십자, unshaded+가산 + 주변을 비추는 노란 PointLight2D `light_*`): `Blackout.is_dark`("blackout" 그룹)가 켜지는 순간 나타남, 옆모습 그림일 때만 — 머리 그림 바꾸면 `eye_pixel` 재측정. `엄마  몸 측면 3`은 띄어쓰기 두 칸 그대로). "안 자고 뭐하니!" → 가까운 플레이어 추격(**쫓는 플레이어 스탯 move_speed와 같은 속도**, `speed_ratio` 1.0, **1단 점프만** — 발판 길찾기는 AIController 방식을 1단 기준으로 옮김) → 사거리면 말풍선 "등짝 스매쉬!"(`smash_line`) + 3타처럼(0.223초 뒤) `take_map_damage(20)` + `launch_finisher`(평타 3타 기본값) → 16초 뒤 **다른 문**으로. 1단으로 못 닿는 문 발판이면 문 아래서 포물선 한 번에 뛰어오름(`_leap_to`), 20초(`exit_timeout`) 안에 못 가면 그 자리에서 사라짐. 발판 판정(`_support_under`)은 내 발판을 찾을 때 **몸 반지름(`BODY_RADIUS`)만큼 끝 걸침을 봐줌** — 4px만 보면 끝에 걸친 순간 훨씬 아래 계단으로 잘못 잡혀 맨 위 발판 오른쪽 끝에서 왔다 갔다 떨었다(2026-10-07). 오른쪽 문은 1단 점프로 **맨 위 가운데 발판 → 오른쪽으로 떨어지기**가 유일한 길이라, 땅에서 출발하면 도착까지 ~11~13초 걸림
- 천장 조명 `DecoCeilingLamp1~3`(`CeilingLamp.gd`, 원점 = 천장 아랫면 y -551, x -330/290/900 대략 배치): 형광등 그림 `조명.png`(천장에 붙음, 보이는 영역 `LAMP_OPAQUE` — 그림 바꾸면 재측정), 빛은 내부 자식 ColorRect + `CeilingLight.gdshader`(가산, 원뿔·전등 밑 번짐·약한 지글거림·먼지). **방 전체 밝기 = `Blackout` 색(0.56, 0.56, 0.64 — 은은하게 어두움, `blackout_brightness` 0.1로 암전 절대 밝기는 예전과 같음)**, 등마다 원뿔 모양 PointLight2D(`glow_*`, 코드로 만든 텍스처)가 아래 맵·캐릭터를 실제로 밝힘 — `Blackout.light_level()`을 따라 깜빡이고 암전 때 꺼짐(등 그림도 unshaded + 밝기 직접). **지붕을 옮기면 전등 y도**
- 장식은 전부 `Deco*`(미리보기 크기 기준 제외)
- 입체감(2026-10-06, 지하철 방식): 가장 먼 층 `DecoBackground`(CanvasGroup + `far_blur` 1.0/0.12 + `ParallaxFollow` 0.85, 벽 그림 `Wall` 배율 1.3 — 시차로 밀려도 가장자리 안 보이게 키움) → 창문 층 `DecoWindows`(창문 셋, `far_blur` 0.45/0.05, 0.93) → 싸우는 층. 기준 카메라 중심 `reference` (290, -128) = 방 가운데 — 카메라가 여기 있을 때 에디터 배치 그대로. **창문은 `DecoWindows` 안에 넣을 것**
- ⚠️ **맵 그림·발판은 전부 `z_index = -10`** — 대시 잔상(z -2)·스피드라인·먼지(z -1)가 그 앞에 그려져야 한다. z 0으로 두면 이펙트가 배경 뒤로 숨는다. **새로 넣는 맵 노드도 -10**

## 번화가 `maps/Downtown.tscn` — 쓰레기 봉투 + 택시 (2026-10-08)

- 땅 윗면 y=286, 벽 ±926. 전선 `PowerLine.gd`는 밟는 원웨이 발판(AI는 길로 모름). **끝점은 전봇대 애자**(전봇데.png 애자 윗부분 = 캔버스 (329/650/783, 78) — 전봇대를 옮기면 전선 끝도)
- 전선 출렁임: 처짐 하나(`_sag`)를 감쇠 스프링으로 굴려 **V자(누른 자리 꼭짓점)로 그림·판정 선분을 같이** 움직임. 빨리 올라올 때 탄 사람 띄움(`launch_*`). 쓰레기 조각은 착지 후 안 따라 움직임
- **층 z**: 하늘 -30 / 배경 3장 -29(`ParallaxFollow` 시차 — 배경만) / 건물 -20 / 발판·도로·전선·쓰레기통·택시 -10 / **전봇대 +10(캐릭터 앞)**, `ForegroundFade.gd`로 뒤에 들어가면 반투명(`self_modulate`). **건물·전봇대엔 시차 금지** — 발판·전선이 붙어 있어 어긋난다
- 전봇대 앞 느낌: 흐림(`foreground_blur` 4) + 어둡게(`tint`) + **건물 벽 그림자**(`Building*` 그림의 자식으로 깔고 `clip_children`으로 잘라 하늘엔 안 생김). 배경 흐림 `far_blur` 1.8/1.4/1.1
- 쓰레기 착지 높이는 그림마다 **보이는 영역 + 기울기**로 잰다(`TrashPickup._foot()`). ⚠️ 땅 판정 윗면 286인데 도로 그림 윗면은 약 280 — 캐릭터·쓰레기 모두 6px 들어가 보인다
- 쓰레기: `TrashCans`(`DowntownTrashSpawner`) 10초마다 자식 통 하나 랜덤 → `DowntownTrashCan.burst(3~5)`(뚜껑 `Lid` 튕김) → 조각 `TrashPickup.gd`(물리 바디 아님, 레이캐스트 착지, **안 사라지고 쌓임**)
- 맵 스킬 `TrashBagThrowSkill`: 스택 `custom_data["trash_stack"]`(최대 10), 전부 담아 포물선 투척 `ThrownTrashBag`(원웨이 발판은 통과). 크기·피해·넉백이 스택 비례. 스택 0이면 쿨 환불. 머리 위 표시는 **임시 숫자**(아이콘 예정)
- 택시 `DowntownTaxi.gd`: 그림 `택시 본체.png` + `바퀴.png`(`Taxi/Art` 밑에 바퀴 둘 → 본체 순, 왼쪽 갈 땐 `Art.scale.x`만 뒤집음). 본체 0.215배(길이 269·표시등까지 117 = 판정 `body_length`/`roof_height`, **배율을 바꾸면 같이**). 바퀴 그림 중심이 캔버스에서 (3, 11.5) 비켜 있어 `offset`으로 보정. 8~15초마다 랜덤 방향, 닿으면 **피해 없이** 위로 튕김(스프링 방식 + `cancel_landing_lag`)

## 헬스장 `maps/Gym.tscn`

- 2층 발판 + 기구 셋(바벨 컬 = 기본공격력 / 스쿼트 랙 = 점프력 / 런닝머신 = 이동속도). `WorkoutSkill`: 운동 중 발 묶임, 맞음·때림·멀어짐이면 끊김, 스펙은 배수(`custom_data["gym_spec"]`)
- 공격력은 기본공격에만(`compute_basic_damage()`). `GymLayout.gd`는 자식 `_ready()`가 부모보다 먼저라는 것에 기대 스폰을 옮김. `muscle_arm`/`muscle_leg`
- 땅 y=280, 2층 y=100(이단 점프 한계 180px), 벽 ±604. TODO: 운동 모션·기구 그림·배경

## 공사현장 `maps/CollapsingApartment.tscn`

- 부서지는 발판 4층(간격 170 = 이단 점프로만). **점프력이 바뀌면 다시 계산**

## 튜토리얼 `maps/Tutorial.tscn`(뼈대)

- 배경 `sprite/맵/튜토리얼/`(구름 `RandomCloudSpawner.gd`, 국기 `FlagFlutter.gdshader`). 땅 ⚠️ `texture_repeat`는 위아래로도 반복 → `region_rect`를 투명한 윗부분 아래부터. 바닥 y=280, 벽 ±1200
- P1 = 경찰(3타 콤보 필요). **교관 = 진짜 황근출 Fighter**(HP 10만, `immovable`, 컨트롤러 없이 `_drive_instructor`가 굴림). 실습 구간에만 `_set_instructor_hittable(true)`. 3타로 날아가면 제자리로 걸어 돌아옴 → `_on_instructor_home()`이 실습을 끝냄
- **처음 켠 사람만** 타이틀 → 튜토리얼(`GameState.tutorial_seen`). 메뉴 훈련장 버튼에서도 갈 수 있음
- 말풍선 `maps/SpeechBubble.gd`(@tool, 전부 `_draw()`): **원점 = 꼬리 끝 = 가리키는 곳**. 교관 자식이면 글자가 뒤집혀 맵 직속. `say(text, hint, press_hint_delay)`(BBCode), `icon("guard"/"dash"/"parry")`, `finish_typing()`, `close()`. 폰트 강한육군 Bold — **모든 `*_font_size` 슬롯 지정**(빼면 `[b]`가 16px). ⚠️ "썌"는 글리프 없음 → "쌔"
- 대사 `Tutorial.gd` (2026-10-07 개편): 교관 500px 안에 들면 시작. **대사는 `_build_lines()`의 순서가 곧 진행 순서**(번호 상수 없음) — 한 줄 = `_line(text, {gate|phase, goal})`
  - `gate`(move/jump/parkour/guard/dash) = 그 행동을 해야 넘어감(`_update_gates`), `phase`(hit/parry/skill1/skill2/ult/fight) = 스페이스에 말풍선 닫히고 실습 시작, 끝나면 다음 줄. 둘 다 없으면 스페이스
  - `goal` = 화면 아래 흰 알약(`_show_goal`). 키 이름은 설정에서 읽음(`_key("down")` → "S") — **대사에 키를 글자로 박지 말 것**
  - 스킬 실습: 쿨을 0으로 비우고 헛쏘면 `SKILL_RETRY_COOLDOWN`(1.5초)으로 깎음. 성공 = 스킬을 쏜 뒤 `SKILL_HIT_WINDOW` 안에 교관 `damaged`. 궁은 쓰기만 하면 통과(컷인 노드가 없어 바로 나감)
  - 카메라는 항상 플레이어 고정. 플레이어 HP는 패링 시범 중 35% 밑이면 채움, 싸움에서 지면 둘 다 채우고 재시작

## 훈련장 `maps/TrainingGround.tscn`

- 물리값·게임 속도 슬라이더(static var — 영구 반영은 `DEFAULT_*`), 모든 스킬 쿨 0. `Engine.time_scale`은 `_exit_tree`에서 복구. 충돌 보기 `CollisionDebugView.gd`, 바닥 눈금자 `FloorRuler.gd`
- 디버그 격자: 대전 중 **G + '**(`maps/DebugGrid.gd`)
