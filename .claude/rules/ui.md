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
- 맵 선택 썸네일(2026-10-09): 실제 게임 화면 사진 `ui/map_thumbs/<맵파일>.png`(`tools/MapThumbGen.tscn` F6로 찍음, 구경 모드로 띄우고 캐릭터는 숨김). **맵 그림을 바꾸거나 새 맵을 넣으면 다시 돌릴 것** — 사진이 없으면 옛 `MapPreview` 스케치로 떨어진다(도감·맵 상세는 아직 스케치)
- 숨겨진 캐릭터: 선택창에서 **aaddssww** → `_toggle_hidden_mode`. 경로 `GameState.character_path()`. 타이틀 구경·도감엔 안 나옴

## 대전 진행

- `Stage._process()`가 양쪽 HP를 **한 번에** 판정(동시 KO = 무승부), 시간 초과는 HP 높은 쪽. 링아웃 `ring_out_y`
- 선수 판 위치: 기본 아래, `Stage.hud_panels_top`이면 위. ⚠️ `panels_top_margin.x`를 76보다 작게 하면 일시정지 버튼에 깔림
- 카운트다운 중엔 컨트롤러 `is_active` false + `move(0)`(`set_physics_process(false)`는 미끄러짐)
- KO 연출 `Stage._play_knockout`: 마지막 넉백대로 물리로 밀려남(`apply_hitstun`으로 `move(0)`를 막음) + 실제 시간 슬로 + 눈 X, 멈추면 `_lay_down_when_settled()`가 Visual만 90도 눕힘. 화면 흔들림 없음

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
