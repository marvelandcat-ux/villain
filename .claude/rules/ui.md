---
paths:
  - "ui/**"
  - "GameState.gd"
  - "maps/Stage.gd"
  - "tools/make_title_logo.py"
---

# 화면 흐름 / UI

- `ui/Disclaimer.tscn` → `TitleScreen` → `MainMenu`(스토리/대전/훈련장/가이드/설정). 대전: `RoomSettings` → `CharacterSelect` → `MapSelect` → 맵
- `GameState.gd`(오토로드)가 화면 사이 값을 들고 다님. ESC = 한 단계 뒤로, 대전·스토리 중엔 `PauseMenu`(`process_mode = ALWAYS`)
- 폰트 주아체 — 기호 글리프 없음(코드로 그릴 것). 대화창은 나눔고딕
- **타이틀 구경 모드**(`game_mode == "attract"`): 랜덤 맵·AI 둘, HUD·컷인 없음. 떠날 때 `game_mode` "pvp" + 배율 복구. 로고는 `tools/make_title_logo.py`(**로고를 바꾸면 다시 돌릴 것**)
- 메인 메뉴: `<이름>Item`(판정 고정) > `Slide`(보이는 것만 이동). `Illust*`와 `Background*`는 index로 짝. 일러스트 파츠는 원본 캔버스 그대로 + `centered = false`, **큰 동작은 자세 그림 교체**
- 설정 > 조작 `ui/KeyboardMap.gd`: ⚠️ `_input`에서 `get_local_mouse_position()` 금지 → `_local_of(event)`. ⚠️ **`refresh()`는 마지막에 `queue_redraw()`**. 저장 `GameState.rebind_action()` → `user://settings.cfg`. 마우스 확인은 사용자가
- 해상도 기준 1280x720 + `canvas_items`
- 확인 창 `ConfirmPopup`: `_ask(문구, Callable)`, 두 갈래 `open_choice()`
- 방 설정 `RoomSettings`: 버튼 연결은 `_ready()` 코드로
- 도감 `CharacterDex`(⚠️ TODO: 놀이터 설명이 옛 기믹). `FanTile.gd`(@tool) 네 점 모양 버튼
- 초상화: 크기·위치는 `ui/PortraitFrames.tscn`, 전부 `GameState.frame_portrait()` 경유. 스킬 로고 `Skill.icon`(투명 여백 잘라 넣기)
- 맵 선택 `MapSelect`(**2026-10-08 평면 지도로 개편** — 사용자: "구는 비율이 이상하다, 평면에 바다만 흐르고 한반도 보여주기"): `KoreaGlobe.gdshader`를 **`flatten` 1로 고정**해 평면으로 쓴다(지구본 코드는 남아 있어 `_flatten` 0으로 돌리면 공으로 복귀). 그림은 `korea_ocean.png` + `korea_land.png`(`tools/make_korea_globe.py`, 땅 자리는 셰이더 `land_rect`). **땅은 고정, 바다만 흐른다**(셰이더 `ocean_scroll` ← `OCEAN_FLOW` (0.012, 0.005)/초; `spin`은 0). 끌기·자전 없음(`_gui_input`은 빈 함수, 옛 끌기는 `_gui_input_globe`에 보관). 배율: `FLAT_HALF` (660, 380)·`FLAT_SPAN_U` 0.70 → 1라디안 300px, 위도 1도 ≈ 60px, 지도 중심 `GLOBE_CENTER` (640, 345) = 경위도 (127.5, 38). 핀(`MapPin`, `MAP_PINS` 경위도)은 이름표 **항상 아래 고정**. **고르면**: 핀 자리로 `ZOOM_TO` 3.5배까지 `ZOOM_TIME` 1.1초 동안 CUBIC EASE_IN(점점 빠르게 빨려 들어감) + 검은 막 `_dark` 알파 0→1(글자·핀·캐릭터는 0.44초에 먼저 사라짐) → `SceneTransition.go_to_scene_from_black(맵, MAP_FADE_IN 1.0)` = 검은 막으로 덮은 채 씬 바꾸고 새 맵이 **서서히 밝아진다**(로딩 화면 대신). 랜덤 버튼은 핀을 0.45초 비춘 뒤 같은 길. ⚠️ 셰이더 `surface_uv()` ↔ `_screen_of()`, 파이썬 `CENTER_*`/`PX_PER_DEG` ↔ 스크립트 상수는 짝
- 맵 선택 썸네일(2026-10-09): 실제 게임 화면 사진 `ui/map_thumbs/<맵파일>.png`(`tools/MapThumbGen.tscn` F6로 찍음, 구경 모드로 띄우고 캐릭터는 숨김). **맵 그림을 바꾸거나 새 맵을 넣으면 다시 돌릴 것** — 맵 선택·도감·맵 상세 셋 다 `MapPreview.snapshot_texture()`로 이 사진을 먼저 쓰고, 없으면 옛 스케치로 떨어진다. 1280x720
- 숨겨진 캐릭터: 선택창에서 **aaddssww** → `_toggle_hidden_mode`. 경로 `GameState.character_path()`. 타이틀 구경·도감엔 안 나옴

## 대전 진행

- `Stage._process()`가 양쪽 HP를 **한 번에** 판정(동시 KO = 무승부), 시간 초과는 HP 높은 쪽. 링아웃 `ring_out_y`
- 선수 판 위치: 기본 아래, `Stage.hud_panels_top`이면 위. ⚠️ `panels_top_margin.x`를 76보다 작게 하면 일시정지 버튼에 깔림
- 카운트다운 중엔 컨트롤러 `is_active` false + `move(0)`(`set_physics_process(false)`는 미끄러짐)
- KO 연출 `Stage._play_knockout`: 마지막 넉백대로 물리로 밀려남(`apply_hitstun`으로 `move(0)`를 막음) + 실제 시간 슬로 + 눈 X, 멈추면 `_lay_down_when_settled()`가 Visual만 90도 눕힘. 화면 흔들림 없음

## 대전 최종 승부 연출 `ui/result/` (2026-10-08)

대전(pvp, 컴퓨터 상대 포함) 최종 승부 → KO 슬로 → **승리(3.5초) → 패배(3초) → 연행(3초)** → 결과 띠(`MatchResult.dock_bottom()`). 스토리·attract는 안 탄다. 방 설정 "승패 연출" 끄면 통째로 건너뜀. 무승부는 연행만.

- `MatchEnding.tscn`(승리·패배) / `ArrestScene.tscn`(우사미짱 패러디 연행, 원근은 카메라 하나로 투영 — 발 위치만 옮기면 크기·그림자·밧줄이 따라옴). 둘 다 CanvasLayer 25, `process_mode` ALWAYS, **실제 시간**(Time.get_ticks_usec), `signal finished` + `play(info)`. 결과 띠는 layer 30
- info 키: `winner_rig`/`loser_rig`(= 선수 `Visual.scene_file_path`), `winner_is_p1`, `winner_name`/`loser_name`, `winner_p2_color`/`loser_p2_color`(같은 캐릭터끼리일 때 P2 쪽만), `is_draw`
- 인물 = **그 판에서 싸운 캐릭터의 리그**, 자기 쪽(P1 왼쪽/P2 오른쪽). 리그 루트 scale은 건드리지 말 것(`play_squash`가 덮어써서 좌우 부호가 날아간다) → Holder > Puppet > Mount > 리그
- 효과음은 `ResultSfx.gd`(class_name 없음, preload) — `Sound/result/<이름>.ogg|wav|mp3`만 맞추면 됨, 없으면 무음. ⚠️ **슬픈 트롬본은 사용자가 싫다고 해서 뺐다**(다시 넣지 말 것). 빗소리(rain)는 아직 파일 없음
- ⚠️ **템포**: 연행은 6초 → 3초로 줄였다("게임 템포가 느려졌다", 사용자). 늘리지 말 것. 박자는 `ArrestScene.gd` 상단 상수
- 멈춤 방지: 최종 KO 때 `Stage._preload_match_ending()`이 승리 화면·두 리그를, 승리 화면 동안 `ArrestScene.warm_up()`이 경찰·구경꾼 리그를 스레드로 미리 읽는다(헤드리스에선 끔 — 가짜 렌더러 에러)
- 연출 중엔 일시정지 막음(`_ending_active`/`_knockout_playing`), 영역 궁은 연출 시작 때 `break_domain()`
- **연행 배경 = 싸운 곳 건물 정면 + 출입문**(인물들이 그 문에서 끌려 나온 셈, 2026-10-08 사용자 레퍼런스). 그림 한 장 = `ArrestBackdropConfig.gd` .tres(그림 + **그림 속 문 사각형** `door_rect` + 땅선 `ground_px`). 장면이 문을 크기 기준점으로 놓는다: 땅선 → `facade_base_y`, 문 가운데 → `door_screen_x`, 문 높이 = 캐릭터 키 x `door_height`(1.35). **맵마다 한 장** — 맵 씬 이름과 같은 `ui/result/backdrops/<맵>.tres`(헬스장 = Gym.tres, Stage가 info `map_path`로 넘김). 맵 5개 자리는 그림 없이 만들어 둠 → 그림을 끌어다 놓고 `door_rect`만 적으면 끝. 그림이 비면 `PoliceStation.tres`
  - 새 그림은 `ui/result/backdrops/원근가이드.png`(2560x1440 = 화면 1280x720의 2배) 위에 그릴 것 — 지평선(눈높이) y 470·소실점 x 760·땅선·문 자리·깊이별 캐릭터 키가 그려져 있다. 장면에서 `show_perspective_guide`를 켜면 같은 가이드가 겹쳐 보인다. **카메라 값(horizon_y·vanish_x·camera_height·focal)이나 facade_base_y를 바꾸면 가이드를 다시 찍을 것**
  - 맵 5장(2026-10-09, 이미지 생성 — 경찰서 구도에 맞춘 프롬프트): `backdrops/헬스장_건물`·`놀이터_입구`·`지하철역_입구`·`악플러의집_건물`·`번화가_건물.png`. 흰 하늘은 테두리 flood fill + 경계 2px 흰색→알파로 지웠다. **`door_rect` = 문짝만**(위 유리창·간판·문틀 제외 — 경찰서와 같은 기준), `ground_px` = 맨 아래 계단 밑선. 놀이터는 울타리 입구(안쪽 기둥 사이 ~ 아치 간판 밑면). 놀이터·번화가는 2026-10-10에 다시 뽑았다 — 첫 판은 놀이터가 위에서 내려다본 각도, 번화가는 문이 커서(배율 0.93) 왼쪽에 하늘이 비었다. 새로 뽑을 땐 프롬프트에 **"EYE LEVEL, NOT from above"·문 위아래 좌표(y 770~915)·"건물이 캔버스 좌우 끝을 넘어간다"** 를 못 박을 것
  - 구도: 지금은 **B(건물 바로 뒤, 레퍼런스식)** — facade_base_y 548, 로스터 구경꾼 y 566~578. 예전 A(건물 멀리, 하늘 보임)로 돌리려면 facade_base_y 508 + crowd_feet y 547~558 + mob_back_feet y 522~540
- **경광등은 사이렌에 맞춘다**: 높은음 = 빨강, 낮은음 = 파랑, 음이 바뀔 때 두 번 번쩍(`PoliceCarSide.siren_tone`/`tone_time`). 박자는 실제 파형에서 잰 표 `ResultSfx.SIREN_HIGH_STARTS`(녹음이라 1.05~1.1초로 흔들려 고정 주기 X). ⚠️ **siren 파일을 바꾸면 다시 잴 것** — Godot `--write-movie x.png`로 WAV를 뽑아 음높이(약 1312/732Hz)를 추적했다. 소리가 꺼진 뒤엔 같은 박자로 이어 센다
- **얼굴 없는 구경꾼** `MobCrowd.gd`(흰 바탕 + 검은 테두리, 게임 체형, 얼굴 없음, 수십 명을 LineMesh 한 번에): 로스터 구경꾼보다 먼 줄 `mob_back_feet`(Crowd 뒤) / 가까운 줄 `mob_front_feet`(Crowd 앞). 같은 seed라 매번 같은 무리. 멀수록 haze로 흐려짐. 밝기는 `ArrestScene.mob_shade`(기본 0.78 — 하얀 바탕이 너무 튄다고 해서 낮춤, 2026-10-10)
- TODO: 옆모습 경찰차 그림(지금 `PoliceCarSide.gd` 코드 그림), 승리/패배 표정이 없는 리그(주정뱅이·지하철·캣맘·황근출·인베이전·경찰 등)는 `action_head_texture`/`hurt_head_texture`를 꽂으면 바로 쓰임. 클로즈업(8~9배)에선 손 그림이 털뭉치 고리로 보임

## 궁극기 컷인 `ui/UltimateCutIn.tscn`

- 기획 확정: 1.5초(장면 `cutin_duration` 우선), **연출 중 시간 정지**, 스킵 없음, 확정타 아님. `use_ultimate()` → 연출 → `fire_ultimate_now()`
- 장면은 `CharacterStats.ultimate_cutin_scene`, 파츠 흔들기 `ui/cutin/CutInAnimation.gd`. **캐릭터를 움직여 넣을 땐 리그(`<캐릭터>Rig.tscn`)를 쓸 것**
- 지하철 컷인: ⚠️ `Metro!.png` 무늬가 기울어 칸마다 `rotation = -0.0158` + `skew = 0.0158`(그림 바꾸면 재측정), 이동은 x만. 칸 수·틈을 바꾸면 `train_from_x`/`train_to_x`도. 선글라스 반짝은 `LensGlint.always_show`

## 스토리 모드

- 난이도: `StoryFadeScene`의 `battle_enemy_hp_scale`/`battle_enemy_damage_scale`/`battle_ai_skill` → `Stage._apply_story_handicap()`(⚠️ `stats`는 공유 Resource라 **`duplicate()` 후, `add_child` 전에**) / `_tune_story_ai()`
- 에피소드 `GameState.STORY_EPISODES`, 클리어 기록은 `clears_story` 켠 장면의 `_ready()`
- 장면 `ui/story/StoryScene1~11.tscn`, 전부 `StoryFadeScene.gd`. `Fade`는 맨 마지막 자식·알파 0, 장면 루트·대화창 `mouse_filter = 2`
  - **스토리→대전:** `_setup_battle()`(**GameState에 담는 코드는 여기에** — S 건너뛰기가 `_open_next()`를 우회). (임시) `S` 건너뛰기는 방어키와 겹침 → 방어 테스트 땐 `debug_story_skip_key` 끔
- 대화창 `ui/story/DialogueBox.tscn`: `이름|대사`, 명령 줄 `@show/@hide/@enter/@exit/@close/@waitkey/@pause/@stamp`
- **3번·11번 장면은 도장만 다른 같은 구조 — 새 사건은 복사해 문구·도장만 교체**. PSD를 고치면 PNG로도. 게임 글자는 "비비탄"으로 통일
