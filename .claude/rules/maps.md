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
- **맵 전체 색보정 `maps/ScreenGrade.gd` + `ScreenGrade.gdshader`**(2026-10-08, 사용자 결정 "후처리 한 장"): `Stage._add_screen_grade()`가 라운드마다 붙이는 **월드 노드(z 3000, 레터박스 4000 아래)** — 카메라 범위를 매 프레임 덮는 사각형에 화면을 읽어(`hint_screen_texture`, unshaded) 색보정→비네트→그레인. HUD·컷인(CanvasLayer)은 안 물든다. 스타일은 `ScreenGradeStyle` `.tres`(`maps/grade/Default·Downtown·TrashRoom·Gym·Playground·Subway`)를 `Stage.screen_grade`에 꽂는다(비면 Default). **그레인·비네트는 전부 0**(2026-10-08 사용자: 노이즈 싫음, 가장자리 어두운 것 이상함) — 틴트·대비·채도만 쓴다. 끄기 `GameState.screen_effects_enabled`(설정 파일 graphics/screen_effects, **설정 화면 토글은 아직 없음**). ⚠️ 가운데(캐릭터)는 또렷하게 — 흐림·색수차는 넣지 말 것. ⚠️ 셰이더 오류는 **헤드리스로 안 잡힌다**(창 띄워서 확인)
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
- `AkpeulleoMom`: **Fighter 아님**(IljinCrewMember와 같은 이유), Hurtbox 없음 = 안 맞음, 그림은 `maps/AkpeulleoMomRig.tscn`(`sprite/맵/악플러집/엄마 스프라이트/` — 원본이 흰 배경 RGB라 테두리 flood fill로 투명화함, 머리 공·배율은 캣맘 리그 크기에 맞춰 역산, 손은 캣맘 것, 발은 `엄마 발.png`. 눈빛 `MomEyeGlow.gd`(Head 자식, 노란 십자, unshaded+가산, 2026-10-08 약 2.5배로 키움: 줄기 34/18 · 굵기 5 · 번짐 16 — 눈을 덮을 만큼 + 주변을 비추는 노란 PointLight2D `light_*`): `Blackout.is_dark`("blackout" 그룹)가 켜지는 순간 나타남, 옆모습 그림일 때만 — 머리 그림 바꾸면 `eye_pixel` 재측정. `엄마  몸 측면 3`은 띄어쓰기 두 칸 그대로). "안 자고 뭐하니!" → 가까운 플레이어 추격(**쫓는 플레이어 스탯 move_speed와 같은 속도**, `speed_ratio` 1.0, **1단 점프만** — 발판 길찾기는 AIController 방식을 1단 기준으로 옮김) → 사거리면 말풍선 "등짝 스매쉬!"(`smash_line`) + 3타처럼(0.223초 뒤) `take_map_damage(20)` + `launch_finisher`(평타 3타 기본값) → 16초 뒤 **다른 문**으로. 1단으로 못 닿는 문 발판이면 문 아래서 포물선 한 번에 뛰어오름(`_leap_to`), 20초(`exit_timeout`) 안에 못 가면 그 자리에서 사라짐. 발판 판정(`_support_under`)은 내 발판을 찾을 때 **몸 반지름(`BODY_RADIUS`)만큼 끝 걸침을 봐줌** — 4px만 보면 끝에 걸친 순간 훨씬 아래 계단으로 잘못 잡혀 맨 위 발판 오른쪽 끝에서 왔다 갔다 떨었다(2026-10-07). 오른쪽 문은 1단 점프로 **맨 위 가운데 발판 → 오른쪽으로 떨어지기**가 유일한 길이라, 땅에서 출발하면 도착까지 ~11~13초 걸림
- 천장 조명 `DecoCeilingLamp1~3`(`CeilingLamp.gd`, 원점 = 천장 아랫면 y -551, x -330/290/900 대략 배치): 형광등 그림 `조명.png`(천장에 붙음, 보이는 영역 `LAMP_OPAQUE` — 그림 바꾸면 재측정), 빛은 내부 자식 ColorRect + `CeilingLight.gdshader`(가산, 원뿔·전등 밑 번짐·약한 지글거림·먼지). **방 전체 밝기 = `Blackout` 색(0.56, 0.56, 0.64 — 은은하게 어두움, `blackout_brightness` 0.1로 암전 절대 밝기는 예전과 같음)**, 등마다 원뿔 모양 PointLight2D(`glow_*`, 코드로 만든 텍스처)가 아래 맵·캐릭터를 실제로 밝힘 — `Blackout.light_level()`을 따라 깜빡이고 암전 때 꺼짐(등 그림도 unshaded + 밝기 직접). **지붕을 옮기면 전등 y도**
- 장식은 전부 `Deco*`(미리보기 크기 기준 제외)
- 배경 층(2026-10-08 사용자: "입체감 있으니 오히려 멀어 보인다" → **시차 뺌**): `DecoBackground`·`DecoWindows` 둘 다 `ParallaxFollow` factor **(1, 1)** = 안 움직임(스크립트·`reference`(290, -128)는 남겨 둬 다시 켜려면 factor만 낮추면 됨). 흐림은 둘 다 `far_blur` **0.4px / dim 0.05**(사용자 "5% 정도"). 벽 그림 `Wall` 배율 1.3은 그대로. **창문은 `DecoWindows` 안에 넣을 것**
- ⚠️ **맵 그림·발판은 전부 `z_index = -10`** — 대시 잔상(z -2)·스피드라인·먼지(z -1)가 그 앞에 그려져야 한다. z 0으로 두면 이펙트가 배경 뒤로 숨는다. **새로 넣는 맵 노드도 -10**

## 번화가 `maps/Downtown.tscn` — 쓰레기 봉투 + 택시 (2026-10-08)

- 땅 윗면 y=286, 벽 노드 ±926(판정 offset 때문에 **안쪽 면은 -959 / 968**). 전선 `PowerLine.gd`는 밟는 원웨이 발판(AI는 길로 모름). **판정은 모든 토막에** 깐다(2026-10-08 — 가파른 끝을 건너뛰어 구멍이 났었음), `max_walk_angle_deg` 60까지 걸어 오르게 `floor_max_angle`을 이 맵에서만 올림. **끝점은 전봇대 애자**(전봇데.png 애자 윗부분 = 캔버스 (329/650/783, 78) — 전봇대를 옮기면 전선 끝도). 2026-10-08 사용자가 전봇대를 옮긴 뒤 다시 맞춤: PoleLeft(-841,-209) 애자 → WireLow 시작 (-760,-415.3)·WireDiagonal 시작 (-800,-415.3) / PoleRightTop(919,-762) → WireDiagonal 끝 (960.3,-968.3)·WireTop 끝 (864.3,-968.3). 공식: `전봇대 position + (캔버스 - (512,768)) x scale`. WireTop 왼쪽 끝만 `LedgeL3` 발판 오른쪽 끝(x -514) **안쪽** (-532, -752) — 허공에서 시작하면 끊겨 보인다(2026-10-08 사용자 지적). **발판을 옮기면 이 점도**
- **2026-10-08 QA**(사용자가 건물·발판 재배치한 뒤 — **아래 사항은 사용자가 알고 일단 둔 것**, 고치지 말 것): 이단 점프 실측 **216px**. 땅 → 왼쪽 계단(127 → 16) → `LedgeL1/Collision3`(-199)가 **215px**로 한계 턱밑 — 1px 여유라 가끔 안 올라가질 수 있음. 오른쪽은 상자(`StepL2/Collision5` 194) → `StepL2/Collision4`(-32)가 **226px**라 점프로 못 올라가고 위에서 떨어져야만 감. 전선 끝은 애자에 정확히 붙어 있음. 쓰레기통 원점은 **가운데**(밑면이 원점 +71)
- 전선 출렁임: 처짐 하나(`_sag`)를 감쇠 스프링으로 굴려 **V자(누른 자리 꼭짓점)로 그림·판정 선분을 같이** 움직임. 빨리 올라올 때 탄 사람 띄움(`launch_*`). 쓰레기 조각은 착지 후 안 따라 움직임. **탄 사람 판정은 `rider_grace`(0.2초)로 끈적하게** 하고 **줄이 움직인 만큼 탄 사람도 같이 옮긴다**(움직이는 발판처럼) — 안 그러면 탔다/안 탔다가 프레임마다 뒤집혀 위아래로 떨었다(2026-10-08, 실측 잔떨림 2.9px → 0.16px). 감쇠 7. **줄 위에선 착지 경직을 매 프레임 끈다**(`cancel_landing_lag`) — 처짐 때문에 착지 높이가 180px을 넘겨 경직이 걸리고 점프가 씹혔다(실측 22번 중 3번 → 0번)
- **층 z**(2026-10-08 입체감 개편): 하늘 -30 / 배경 `DecoBackground` -29(**`배경.png` 한 장**을 CanvasGroup + `far_blur` 1.4/0.1 + `ParallaxFollow` 0.72, 기준 카메라 (0, -226) = 시작 화면) / 건물 -20 / 발판·도로·전선·쓰레기통·택시 -10 / **전봇대 +10(캐릭터 앞)**, `ForegroundFade.gd`로 뒤에 들어가면 반투명(`self_modulate`)
- **가운데 소실점 골목 `DecoAlley`(`maps/DowntownAlley.gd`, 2026-10-08 사용자 레퍼런스 = 밤거리 사진)**: 양옆 앞줄 건물 사이 틈(앞면 x -366~388)에서 소실점 (11, 236)(땅 286에서 50px 위)으로 모이는 골목. 깊이 3겹(`LAYERS` t 0.34/0.58/0.78, z -26/-27/-28) = CanvasGroup + `far_blur`(0.5/0.9/1.3, dim 0.08/0.15/0.22) + `ParallaxFollow`(0.9/0.82/0.74, 기준 (0,-226)). 겹마다 **기존 건물 그림 재활용**(`BUILDINGS` 앞면 배율 x `size` 0.85/0.72/0.6 — **t와 따로**: (1-t)로 줄이니 장난감처럼 작아져서 사용자가 "앞줄보다 300px쯤만 작게"로 바꿈. 축소 그림은 `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` 필수 — 없으면 뒤가 지글거려 더 또렷해 보인다) — 코드가 보이는 영역을 재서 도로 끝에서 바깥으로 이어 붙이고(`_place_wall`), 간판 건물엔 네온 재질, 끝은 `END_WALL`(t 0.9)로 소실점을 막음. 도로는 겹별 토막 `maps/AlleyRoad.gd`(`_draw` 사다리꼴 + 인도 띠 + 점선, 시차가 달라 층별로 끊어 그림). **노드는 `_ready`에서 매번 생성(씬에 저장 안 함)**, 값을 바꾸면 `rebuild`. ⚠️ 왼쪽 벽은 cursor가 **줄어드는** 쪽으로(side -1) — 부호를 반대로 썼다가 안쪽으로 겹쳤음
- **건물엔 시차 금지** — 발판(`Ledge*`)이 건물 벽에 얹혀 있어 어긋난다. **전봇대는 가로 시차만**(`ForegroundFade.parallax` (1.1, 1.0)): 세로를 주면 전선 끝에 선 사람이 그림보다 떠 보인다
- 전봇대 시차 때문에 전선 끝이 떨어져 보이는 건 `PowerLine.start_anchor`/`end_anchor`(전봇대 NodePath)로 막는다 — **그림 끝만** 전봇대를 따라가고(끝에서 `anchor_blend_px` 260 안쪽까지 섞음) **판정 선분은 그대로**. 전봇대를 새로 놓으면 anchor도 같이. WireTop 왼쪽 끝은 건물에 걸려 있어 anchor 없음
- 전봇대 앞 느낌 나머지: 흐림(`foreground_blur` 4) + 어둡게(`tint`) + **건물 벽 그림자**(`Building*` 그림의 자식으로 깔고 `clip_children`으로 잘라 하늘엔 안 생김). 그림자는 시차를 안 따라간다(멀리 있는 벽에 비친 것이라 티 안 남)
- **2·3층 전봇대는 바닥까지 늘인다**(`ForegroundFade.extend_to_ground`, `PoleRightLow`/`PoleRightTop`): 그림 밑에 `shaft_rect`(전봇데.png 민무늬 기둥 (440,1345,144,170) 실측 — **그림 바꾸면 재측정**) 조각을 `extend_to_y`(286)까지 쌓는다. 흐림은 `use_parent_material`, 반투명·그림자도 조각까지. `PoleLeft`도 늘임(2026-10-08 사용자 요청) — 세 전봇대 모두 켜져 있다
- **색보정 `grade/Downtown.tres`**(2026-10-08, 술집 거리 분위기): 밤 네온 — 틴트 보랏빛 파랑 (0.8, 0.78, 1.0) 세기 0.4, 대비 1.12, **채도 1.18**(분홍 네온 간판이 튀게), 밝기 **0**(어둡게 했다가 "맵이 너무 어둡다"로 되돌림 2026-10-08 — 밤 느낌은 틴트·네온으로만). 그레인·비네트 0
- **간판 네온 `maps/NeonSign.gdshader`**(2026-10-08): **글자만** — "주변(둘레 16방향 평균)보다 `contrast_min`(0.07) 이상 밝고 채도 0.15·밝기 0.72 이상인 가는 획"을 골라 과노출(`boost`) + 둘레 번짐(`glow_px` 6 화면px) + 깜빡임(`flicker`). 간판 바탕(분홍 판·벽돌)은 고른 색이라 안 잡힌다(사용자: 글자 부분에만). ⚠️ canvas_item fragment의 `COLOR`는 **이미 그림 x modulate**라 그림 색을 또 곱하면 건물이 통째로 어두워진다(실제로 겪음) → vertex에서 `v_modulate`만 받아 곱한다. 공용 `NeonSignMaterial` 하나를 간판 있는 다섯 건물(감성 술집·술집2·전포다찌·건물 세로 간판·편의점)에 붙임. 문턱을 낮추면 벽돌·택시도 빛나니 인스펙터에서만 조절
- **쓰레기통 몸**(`DowntownTrashCan.solid`, 2026-10-08): `_ready`가 원웨이 `StaticBody2D`(76x110, 가운데 (0,15) = 뚜껑 윗면 -40, 그림 실측 몸통 x ±38 / y -5~70)를 만든다. **쓰레기가 터질 때 뚜껑 위 사람은 위로 튕겨 나감**(`eject_velocity` 620 → 약 170px, `cancel_landing_lag`, 피해 없음). 그림 바꾸면 크기 재측정
- **캐릭터 조명** `RimLight` 노드: 기본 **평행광, 바로 위(0, -1)** — 윗가장자리 림 0.7/2px(`rim_focus` 0.55 = 정면 가장자리 위주), 아랫가장자리 그늘 0.35/3px, 위아래 명암 0.1. `directional`을 끄면 노드 자리가 광원. 자세한 건 CLAUDE.md BodyRig 항목
- 쓰레기 착지 높이는 그림마다 **보이는 영역 + 기울기**로 잰다(`TrashPickup._foot()`). ⚠️ 땅 판정 윗면 286인데 도로 그림 윗면은 약 280 — 캐릭터·쓰레기 모두 6px 들어가 보인다
- 쓰레기: `TrashCans`(`DowntownTrashSpawner`) 10초마다 자식 통 하나 랜덤 → `DowntownTrashCan.burst(3~5)`(뚜껑 `Lid` 튕김) → 조각 `TrashPickup.gd`(물리 바디 아님, 레이캐스트 착지, **안 사라지고 쌓임**). 조각 크기는 `trash_px`(29, 보이는 긴 변 — 2026-10-08 2배로 했다가 1.7배 줄임)로 그림마다 배율을 역산해 캔버스가 달라도 같은 크기(쓰레기1~3 + **메가 커피·담배 꽁초**, 2026-10-08 추가)
- 맵 스킬 `TrashBagThrowSkill`: 스택 `custom_data["trash_stack"]`(최대 10), 전부 담아 포물선 투척 `ThrownTrashBag`(원웨이 발판은 통과). 크기·피해·넉백이 스택 비례. 스택 0이면 쿨 환불. 머리 위 표시는 **스택 뱃지**(`stack_icons` = `쓰래기 아이콘 1~10.png`, 46px, 주울 때 1.4배 펌핑 → 0.22초 BACK 복귀, 2026-10-08. 그림이 비면 예전 숫자). ⚠️ 아이콘 폴더는 git에 있는데 작업 폴더에서 지워졌던 걸 `git checkout`으로 되살림 — 캐시(.ctex)가 없으면 `godot --headless --import --path .`
- 택시 `DowntownTaxi.gd`: 그림 `택시 본체.png` + `바퀴.png`(`Taxi/Art` 밑에 바퀴 둘 → 본체 순, 왼쪽 갈 땐 `Art.scale.x`만 뒤집음). 본체 0.215배(길이 269·표시등까지 117 = 판정 `body_length`/`roof_height`, **배율을 바꾸면 같이**). 바퀴 그림 중심이 캔버스에서 (3, 11.5) 비켜 있어 `offset`으로 보정. 8~15초마다 랜덤 방향, 닿으면 **피해 없이** 위로 튕김(스프링 방식 + `cancel_landing_lag`, **잔상(`start_air_trail`)은 안 남김** — 2026-10-08 사용자: 렉 느낌). **달리는 느낌**(2026-10-08): 차체 뒤 스피드 라인(`SpeedLines` caster = 택시, z -11, 떠날 때 `stop()`), 뒷바퀴 밑 먼지(`LandDust` 0.09초마다, 누르스름), 가까울수록 화면 미세 진동(`set_rumble` 0.08). 튕길 때 차체(`Art`)가 감쇠 스프링으로 **눌렸다 되돌아온다**(`squash_*`, 바퀴 바닥이 축, 가로는 반만큼 퍼짐, 실측 약 11%) — 좌우 뒤집기도 `_apply_squash()`가 같이 건다
- **비둘기 `DowntownPigeons.gd`**(`DecoPigeons`, z -9 = 전선 앞·캐릭터 뒤, 2026-10-08): 그림은 `sprite/맵/번화가/비둘기/` 다섯 장(앉음·날개위·날개아래·활공·쪼기) — 시트 `비둘기.png`를 **`py -3 tools/cut_pigeons.py`**로 자른 것(테두리 flood fill로 배경 제거, 빈 세로줄로 자세 분리, 부리·발 좌표를 `anchors.json`에 출력). **시트를 바꾸면 도구를 다시 돌리고 스크립트 `FRAMES`의 부리·발 좌표도 옮겨 적을 것.** 정렬: 앉은 자세는 발바닥 가운데 = 원점, 나는 자세는 **부리를 앉은 자세의 부리 자리에** 맞춤. 크기는 `perched_height`(30px) 하나로, 10분의 1로 줄여 그리므로 `.import` `mipmaps/generate=true` + `LINEAR_WITH_MIPMAPS`. 앉아 있을 땐 2.5~7초마다 모이 쪼기. 세 전선 중 **랜덤 한 줄**에 3~4마리 나란히(측면, 양 끝 25%는 피함 — 끝은 시차로 그림이 밀림). **순수 장식**(판정 없음). 앉은 전선에 누가 타거나(`PowerLine.has_riders()`), 캐릭터·투사체(`projectiles`·`thrown_stones` 그룹)가 100px 안에 오면 도망 → **판정 있는 표면 아무 데나**(다른 전선 + 원웨이 `RectangleShape2D` 발판 윗면, 전봇대 꼭대기는 그림뿐이라 제외) 중 40px 이상 위이고 안전한 곳 → 위협이 3~5초 없으면 집으로. 옆 비둘기가 뜨면 70px 안도 따라 뜸. 전선 출렁임을 따라 같이 오르내림(`surface_global_y`). ⚠️ `ThrownStone`은 `projectiles` 그룹이 아니라(평타 가르기 대상) `thrown_stones` 그룹을 따로 달았다
- **투사체는 원웨이뿐인 바디(전선·발판)를 뚫는다** — `Projectile._on_body_entered`가 `PhysicsQuery.is_one_way_only()`로 거른다(2026-10-08, 금쪽이 비비탄이 전선에 막혔음). 쓰레기 봉투도 같은 헬퍼. 경찰 돌(`ThrownStone`)은 그대로 막힌다

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
