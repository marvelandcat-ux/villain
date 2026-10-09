# 트러블 메이커 (villain) — Godot 프로젝트 규칙

사이드뷰 대전 격투 **"트러블 메이커"**(폴더 `villain`, 빌드 `build/TroubleMaker/`). 기획: https://claude.ai/code/artifact/661e48af-d8db-49c9-bc68-a9294790becb
전역 규칙(한국어, 초보자 눈높이, 안전) 유지. 코드 스타일은 이 문서 우선 — **Godot 4.7.2 / GDScript**(Unity/C# 규칙 아님).

> 2026-10-04 크게 압축: **규칙·함정·같이 고쳐야 하는 짝만** 남김. 기능 설명·수치는 코드를 볼 것(옛 내용은 git 이력).

## 핵심 아키텍처

- **캐릭터 전용 `.gd` 금지** — 모든 캐릭터 루트는 `characters/Fighter.gd`, 차이는 스탯 `.tres` + 스킬 노드(`BasicAttack`/`Skill1`/`Skill2`/`SkillUltimate`). 빈 `skills/Skill.gd` = 의도된 미구현
- **버프·디버프 직접 대입 금지** → `set_modifier`/`clear_modifier`(id별 곱), 임시 `apply_temp_multiplier`. 색조도 `set_tint`/`clear_tint`. `damage_reduction`은 `set_modifier`로 쓰지 말 것(`damage_taken_multiplier` 사용)
- **VFX는 길목에 붙어 있다 — 스킬에서 따로 띄우지 말 것**: 회복은 `heal()`(→ `combat/HealBurst.gd`, 리셋용 채우기는 `heal(n, false)`), 슬로우·점프력 감소는 `apply_temp_multiplier("move_speed_multiplier"/"jump_multiplier", <1)`(→ 달팽이 / 발). `current_hp` 직접 대입이나 `set_modifier`로 건 슬로우(맵 기믹·자기 패널티)엔 안 나옴. **흘러가는 아이콘(버프·디버프 표시)은 `Fighter.show_status_vfx(종류, 시간)`/`hide_status_vfx(종류)`**(→ `combat/StatusIconVfx.gd`, 종류·그림·방향은 그 파일 `KINDS`, 그림 바꾸면 `rect` 재측정). 공격력 버프(`&"attack_up"`)는 길목이 없어 **켠 스킬이 끌 때 hide 짝 필수**(열등감·경봉·쌍악기·주황 고양이)
- **공용 헬퍼 — 다시 짜지 말 것:** `PhysicsQuery.raycast_ignoring_fighters`/`ground_y_below`, `Timers.after`(`real_time`)/`self_destruct`, `Fighter.find_fighter_in_box`, `CrashBurst.spawn`(설정은 add_child 전)
- 스킬: `Skill` 상속 후 `_execute(fighter)`만. `_ready()` 오버라이드 시 `super()`. **쿨은 전부 `effective_cooldown()` 경유**. 스킬2 교체 `swap_skill_2()`, 궁 봉인 `seal_ultimate(id)`. 궁 쿨은 컷인 뒤 `fire_ultimate_now()`부터
- 라운드마다 `reload_current_scene()`(승수만 `GameState`)
- **⚠️ 스킬에서 `Visual.scale` 트윈 금지 → `BodyRig.play_squash()`**
- Hitbox/Hurtbox: `source_fighter` 유무는 `_has_source`로(주인 없는 열차 판정도 동작해야 함 — `is_instance_valid`만으로 막지 말 것). `take_hit()`을 직접 부르는 새 노드도 `_has_source` 검사. `Hurtbox.fighter`는 `Node` → `as Fighter`. HP 오브젝트는 `take_damage`/`take_map_damage`/`is_guarding`만 있으면 됨
- **허트박스는 머리 꼭대기까지**(`HurtboxCollision`, 발끝 +30) — **머리 그림을 바꾸면 다시 잴 것**
- **맵 피해는 `take_map_damage()` 한 곳으로**. `ignore_guard`를 밖에서 true로 주지 말 것
- ⚠️ `take_damage`는 넉백을 속도에 **더한다** → 정확한 속도는 받은 뒤 `velocity` 덮어쓰기
- 이동 가로채기 `movement_override`(+`get_move_velocity_x`/`after_physics`/`blocks_jump`), 대시 가로채기 `dash_override`
- 잡기: `can_be_grabbed()` → **`cancel_finisher_flight()` 먼저** → `is_grabbed`로 위치 직접 이동
- **슈퍼아머는 개수로 셈 — add/remove 짝 필수**. `blocks_debuff()`에 섞지 말 것
- 캐릭터끼리 몸 충돌 없음(양방향 `add_collision_exception_with`, 레이어는 안 건드림). **소환물·설치물도 z 0 + 같은 방식**(음수 z면 맵 그림 뒤로 숨음)
- **맞는 소환물은 두 분류 중 하나의 그룹에 넣을 것**(2026-10-07): `summon_building`(고양이 집) = 평타가 **몇 타였든 다음도 1타**, 1타 x 3번이면 마무리 쿨, 중간에 적을 치면 그 타부터 다시 1타 / `summon_creature`(고양이·일진 패거리) = 캐릭터와 똑같이 1→2→3타, `is_grabbed`를 갖춰 고양이 옷 3타에 잡혀 내던져진다(잡힌 동안 스스로 안 움직임). 규칙은 `ComboMeleeAttack`(`_resolve_building_hit`)·`CatSuitCombo`

### 함정 (실제로 겪음)

- 람다로 노드 건드리는 `create_timer().timeout.connect` → 노드가 먼저 사라지면 에러. **`Timers.after`(노드 자식 Timer)로**
- `Skill`은 `Node`라 좌표 없음 → 자식 Hitbox는 직접 `global_position` 지정
- **`add_child()`는 `_ready()`를 즉시 실행** → 값은 add_child 전에 넣을 것
- 해제된 객체는 `== null`이 true → 주인 유무는 불리언으로
- **`_draw()`에서 0이 될 수 있는 모양은 `draw_primitive`**(`draw_colored_polygon`은 triangulation 에러)
- 안 보이면 **Output 패널 파싱 에러 → 지워진 파일을 가리키는 `ext_resource`** 순으로
- 새 `class_name`을 바로 타입으로 쓰면 파싱 에러 → 무타입 + `preload`
- Area2D 기믹 변수명 금지: `gravity`·`priority`·`monitoring`·`linear_damp`·`angular_damp`
- `.tscn`: `[connection]`은 맨 뒤, 손으로 끼운 노드는 부모 속성 줄 다음. CollisionShape2D는 바디의 **직계 자식**만
- 첫 프레임 delta 튐 → `minf(delta, 0.05)`
- 전체 화면 Control은 `mouse_filter = 2`. `set_input_as_handled()`는 씬 전환·`queue_free()` **전에**
- `duplicate()`는 신호까지 복사 → 판정 복제는 `DUPLICATE_SCRIPTS | DUPLICATE_GROUPS`. **잔상은 복제 후 스크립트를 뗄 것**
- 명중 콜백 안에서 판정 모양 변경은 `set_deferred`
- 셰이더: **`COLOR` 덮어쓸 땐 원래 `COLOR`를 곱할 것**. CanvasGroup 어둡게는 `self_modulate`. Polygon2D는 `vertex_colors`가 있으면 `color` 무시
- **CanvasGroup(흐림 셰이더) 자식에 `z_index`를 주면 그룹 밖에서 그려져 흐림이 안 먹는다** → 앞뒤는 트리 순서로(번화가 골목 2·3층, 2026-10-09)
- 이펙트(먼지·바람·자국)는 **맵에 붙일 것**(캐릭터 자식이면 반전에 뒤집힘). 피격 움찔은 그림만(물리로 띄우면 확정 콤보 깨짐)
- 무언가 사라지면 `git stash list`부터(GitHub Desktop이 치운 적 있음)
- PowerShell 변수는 대소문자 무시. Bash heredoc 속 python의 `\` 줄끝 주의

## 전투

- **📌 평타는 무조건 금쪽이 기준**(30x30 상자, range 40, 파고들기·푸시백 값 공통) — 캐릭터마다 바꾸지 말 것. **📌 3타 준비시간 0.223초 고정**
- `attack_duration`을 바꾸면 `windup`(= x0.4)도. 회전·발차기 타는 리그 `spin_duration`/`kick_duration`을 `finisher_windup`과 같이
- 확정 콤보: **넉백을 키우면 파고들기(`combo_lunge`)도 같이**
- 회전 타격: 루트 `scale.x` 변경은 다음 프레임 `_apply_pose` 첫머리에서 되돌리기, 최소 0.04
- 3타 날아가기 `launch_finisher()`: `FINISHER_*`는 배율 1 기준, `finisher_distance_scale`은 속도 배수(거리 ≈ 제곱). 벽 튕김 속도는 `move_and_slide()` **전에** 기억. **높이는 잃은 체력으로 보간**(2026-10-08): `FINISHER_PEAK_FULL` 150 → `FINISHER_PEAK_EMPTY` 350px, 솟는 속도 `FINISHER_UP_SCALE` √3은 상한이 항상 걸리게 하는 용도(실측 풀피 156 / 반피 256 / 빈사 347px). 체력 배율(속도)에 높이가 또 곱해지지 않는다. **날아가는 동안 받는 피해 절반**(`FINISHER_FLYING_DAMAGE_SCALE`, `take_damage` 맨 앞 올림)
- 클래시 `SkillClashManager`: 스킬1·2·궁만. 테스트에서 스킬은 클래시 대기창 뒤에 나감
- 점프·중력은 **static var**(영구는 `DEFAULT_*`). **점프·중력을 바꾸면 맵 발판 높이(놀이터·지하철 의자·공사현장·헬스장) 재확인**
- 착지 즉시 튕기는 기믹은 `cancel_landing_lag()` 필수
- 방어: 디버프 차단은 `blocks_debuff(from_ultimate)` 한 곳(궁만 관통). 막힘 판정은 `Hitbox._try_hit()`에서 한 번만. 가드/대시 off는 `can_guard()`/`can_dash()` 맨 앞
- **발판 내려가기**: 레이어 끄지 말고 발판에 collision exception(바디 전체에 걸림 → 한 바디에 막힘 충돌 섞지 말 것). 올라갈 발판은 `one_way_collision`
- 히트스톱은 꺼져 있음. 켜면 복귀 타이머 `ignore_time_scale = true`. `Engine.time_scale` 바꾼 스킬은 `_exit_tree`에서 복구

## 캐릭터

로스터 `GameState.CHARACTERS` + **`CHARACTER_RIGS` 둘 다**. 훈련장 전용 `TRAINING_ONLY_CHARACTERS`(주인공), 숨김 `HIDDEN_CHARACTERS`. 새 캐릭터 크기 기준 = 악플러 머리(상한 55x55). **새 스킬은 `AIController._want_skill()`에 한 줄**(또는 스킬에 `ai_wants_use`).

> **캐릭터별·맵별·UI 자세한 메모는 `.claude/rules/*.md`** — 그 파일들을 건드릴 때 자동으로 읽힌다(`paths:`). 새 캐릭터를 만들면 규칙 파일도 하나 추가하고, 스킬 파일 경로를 `paths:`에 넣을 것.

- 오타 파일명은 **그대로 둘 것**(이름을 고치면 참조가 깨짐)

## 몸(BodyRig) — `characters/BodyRig.tscn`/`.gd`

- 캐릭터 씬의 `Visual`(이름 고정). 왼쪽 = `scale.x` 부호만. 캐릭터별 머리는 씬 상속, 조각 위치는 `BodyRig.tscn`을 직접
- **새 리그 배율 눈대중 금지** — 실제 영역 재서 역산(position = 목표중심 - (bbox중심 - 캔버스중심) x 배율). 영역은 `_opaque_rect_of()`(`get_used_rect()`는 알파 1짜리 점에도 늘어남)
- 손 무기는 `HandRHold` 자식(배율 1). `HandR`·`HandRHold`는 형제라 `modulate` 둘 다. `attack_hold_deg` 각도 고정은 되돌린 것 — 건드리지 말 것
- 자세는 `_xxx_target`/`_xxx_blend` + `set_xxx()` + `_pose_xxx()`. **로컬 좌표 자세엔 facing 부호 곱하지 말 것**. 새 자세는 `_face_turn_blocked()`·대치 조건에도
- 머리 돌리기 앵커 = **머리 공의 중심x·y·지름**(알파 1/4 축소 → 높이 22% 열림 연산 → 무게중심·`2sqrt(넓이/pi)`, 프로펠러·턱 제외)
- ⚠️ 머리/몸통 파일명이 비슷 — **덮어쓰기 전 내용 확인**
- 표정 우선순위: 피격 > 토하기/액션 > 취함 > 지침 > 맨정신. `_update_hp_face()`는 `take_damage`/`heal`/`ring_out` 세 곳
- **캐릭터 조명(위에서 오는 빛)** `set_rim_light(params: Dictionary)`/`clear_rim_light()`(2026-10-08): 맵의 `maps/RimLight.gd` 노드가 매 프레임 uniform 값을 넣어 줌. 셰이더 `characters/RimLight.gdshader` = 윗가장자리 림 + 아랫가장자리 그늘 + 파츠 안 위아래 명암(사용자: "맨 위에서 빛, 지붕 아래 명암, 모든 윤곽선에 두르지 말 것"). 안쪽 테두리, 두께는 화면 px, 방향은 MODEL_MATRIX 역변환. ⚠️ 셰이더 함수 안에서는 `UV`/`TEXTURE`를 못 써서 인자로 넘긴다. **리그 재질 하나를 Sprite2D 파츠가 같이 씀 — material이 비어 있는 파츠에만 붙이고 내 재질일 때만 뗌**(빨간 테두리·황금 손이 material을 바꿨다 null로 되돌리는 것과 공존). 파츠 셰이더를 새로 만들면 같은 규칙으로

### 그림 파일 교체

- **파일은 Godot 파일시스템 창에서 옮길 것**(uid 깨짐). 원본이 `.ctex`에만 있으면 offset 56부터 WebP
- 에디터 밖에서 덮어썼으면 `.import` 삭제 후 `godot --headless --editor --path <프로젝트> --quit`
- 배율은 보이는 영역 x scale이 예전과 같게(`centered`면 position 보정). 경로 바꾸면 낡은 `uid=`도
- 흰 배경 제거는 테두리 flood fill(파츠는 알파 PNG로 요청). 구석 얼룩·가장자리 흰 줄 확인
- 배경이 지글거리면 `.import` `mipmaps/generate=true` + 씬 루트 `texture_filter = 4`

## 조작 / AI

- P1: A/D·W 점프·S 아래·F 평타·G/H 스킬·R 궁·E 맵 스킬 / P2: ←→·↑·↓·L·;·'·]·[. 대시 = 이동키 두 번, 발판 내려가기 = 아래키 한 번(원웨이 발판 위에서만, 2026-10-08), **방어 = 평타+스킬1 동시**(`GUARD_CHORD_WINDOW` 0.06초 동안 짝을 기다려서 혼자 누른 평타·스킬1은 그만큼 늦게 나감). ⚠️ **기본 배치를 바꾸면 `GameState.KEYBIND_VERSION` 올릴 것**
- ⚠️ `move()`/`dash()`가 `facing`도 바꿈 → 후퇴 직후 되돌릴 것
- AI 발판 길찾기 그룹: `"ai_jump_over"`, `"ai_danger_zone"` → `"ai_safe_spot"`. 기믹 위험 판정은 `can_process()`인 것만

## 맵 / UI

- 새 맵 필수: 바닥·벽(또는 링아웃)·`PlayerSpawn1/2`·`Camera2D`(`CameraRig.gd`)·`CombatHUD`, 목록 `GameState.MAPS`. **`Deco*` 노드는 맵 선택 미리보기 제외**. 맵 스킬은 클래시 안 탐
- **번화가 = 쓰레기 모으기 규칙**(2026-10-09, `Stage.trash_collect_mode`): 체력 0 → 쓰레기 절반(올림) 뿌리고 튕겨 나감 → 스폰 자리에서 깜박이며 2초 → 부활. 시간 끝에 쓰레기 많은 쪽 승, 같으면 무승부. 개수는 맵 스킬 `TrashBagThrowSkill`(한도 9999) — **이름과 달리 이제 "쓰레기 줍기"**(던지기 삭제, 범위 110px 안을 한 번에, 닿아서는 안 주움 `auto_pickup`), 뱃지는 빈 그림 `blank_icon` + 코드 숫자
- `Fade`는 씬의 **맨 마지막 자식**. 기준 해상도 1280x720
- 맵 전체 색보정 `maps/ScreenGrade.gd`(월드 z 3000, HUD 안 물듦) — 맵별 `.tres`는 `maps/grade/`, 자세한 건 `.claude/rules/maps.md`
- 폰트 주아체는 ⚠️ **기호 글리프가 거의 없음**(`◀ ▶ ● ○ · × ↑ ↓` → 코드로 그릴 것)

## 코드 스타일

- ⚠️ **빌더 `tools/build_playground.py`는 지금 돌리면 안 된다**(씬을 손으로 고침). 돌린다면 백업 + 손수정 값을 `PLATFORM_OVERRIDES`·`CROWN_POS`로 옮긴 뒤
- 바닥 y=280, 벽 ±960, 스프링 좌석 y=226, 지붕 y=-82, 중간 구름 y≈-228, 꼭대기 y=-418, 왕관(25, -472). 카메라 `min_y` -300(구름을 올리면 같이). **모든 발판은 원웨이**
- ⚠️ TODO: 점프력 변경 뒤 재실측 안 됨 — 중간→꼭대기 여유 ~3px
- 미끄럼틀 `PavilionLeft/Right`: **왼쪽만 판정**, 바디 넷(한 바디에 몰지 말 것)
- 그네 `Swing.gd`: 튕김 + `apply_hitstun` 필수. 스프링 `SpringJumpPad.gd`: 직전 낙하 속도로 튕김 + `cancel_landing_lag()`
- 왕관 `Crown.gd`: 닿으면 왕(`Crown.is_king()`), 넉백 피해에 떨어뜨림. **승리 조건은 안 건드림**, `pickup_delay` 0 금지. 그림 `진짜왕관.png`는 맵과 `CrownCutIn.tscn` 두 곳
- 모래 `SandPit.gd`: 발치 높이에만 둔화. `모래사장.png`(괄호 없음)는 쓰지 말 것

### 지하철 승강장 `maps/SubwayPlatform.tscn`

- 선로 바닥 y=300, 벽 ±560, 의자 발판 y=155(원웨이). **의자 위 = 열차 피난처**(의자 높이·열차 크기는 같이 계산), 의자는 트리에서 열차보다 먼저
- 열차 `SubwayTrain.gd`: 1~5칸, 그림을 잘라 조립(`SEAM_FRONT`/`SEAM_BACK`/`MIDDLE_DRIFT` — **그림을 바꾸면 재측정**)
- 조명 `CanvasModulate` + 형광등. 빛나는 물체는 unshaded. **가산 색은 CanvasModulate가 곱해지므로 조명을 바꾸면 다시 잡을 것**
- 먼 층 `DecoBackground`(CanvasGroup + `far_blur`), 앞 기둥 `ForegroundPillars.gd`. 역 이름판을 옮기면 `SignBand`·`SignBandOutline`도

## 스토리 에피소드 2 — 악플러 (2026-10-07, 러프)

사용자 대본을 그대로 깐 **뼈대**다. "대충 해봐 그러면 내가 살을 붙이지"라서 대사와 흐름만 맞춰 놨다.

| 장면 | 내용 | 비고 |
|---|---|---|
| `StoryScene13` | 경찰서 — 새 사건 + 사건 파일 + **도장 쾅**(`@stamp`) | 종이 그림은 **에피1 잼민이 것 돌려씀** |
| `StoryScene14` | 나레이션 — 동영상 플랫폼 출동 | 배경 없음(검은 화면) |
| `StoryScene15` | **댓글창** — 악플 하나에 **대댓글로 주고받는다** | `ui/story/CommentScreen.gd`로 **코드로 그림** |
| `StoryScene16` | 장소 카드 "악플러의 집 앞" | `LocationCard` |
| `StoryScene17` | 집 앞 — 문 열림 -> 도망 -> **전투** | 문 그림 3장(가운데 + 좌우 뒤집기) + 경찰 가운데 |
| 전투 | `maps/TrashRoom.tscn`(악플러의 집) 경찰 vs 악플러 | 어둠(`Blackout`)이 이미 있는 맵 |
| `StoryScene18` | 전투 뒤 — **빈 자리** | 뒷이야기 안 씀 |

`GameState.STORY_EPISODES`의 ep2에 `StoryScene13`을 꽂아서 일시정지 화면 목록에서 고를 수 있다.

**(임시) 메인 메뉴에서 숫자 `1`·`2`를 누르면 그 에피소드로 바로 들어간다**(`MainMenu.debug_episode_keys`).
⚠️ `set_input_as_handled()`를 **`start_story()`보다 먼저** 불러야 한다 — 씬이 갈리면 `get_viewport()`가 null이 된다.
에피소드 고르는 화면이 생기면 이 열쇠는 지울 것

### 후레쉬 `skills/FlashlightSkill.gd`

⚠️ **`Blackout`은 `CanvasModulate`라 `Light2D`를 못 덮는다.** 그래서 감마를 따로 만질 것 없이
`PointLight2D` 하나만 캐릭터에 붙이면 그 근처만 뚫린다 — 모니터 불빛이 이미 쓰던 방식이다.

- 빛 그림은 **코드로 만든다**(`GradientTexture2D` FILL_RADIAL) — 반지름·번짐을 인스펙터에서 바로 만지려고
- 바라보는 쪽 앞으로 `light_offset`만큼 내밀고, 몸을 돌리면 따라 돈다
- 5초 유지 / 쿨 5초(사용자 "모의"). **시야만 밝힌다 — 판정은 안 바뀐다**
- ⚠️ **아직 아무도 안 쓴다.** 경찰 2스킬은 `돌 던지기` 그대로다.
  **2스킬은 에피소드마다 달라진다**(사용자 결정, 2026-10-07) — 1화는 돌 던지기(잼민이 자전거를 멈추는 수단),
  2화는 후레쉬. 에피소드별로 스킬을 갈아 끼우는 장치는 **아직 안 만들었다**


#### 댓글창 `ui/story/CommentScreen.gd`

맨 위 악플(`root_comment`) 하나에 **답글(`replies`)이 들여쓰여 달린다**(2026-10-07 사용자 러프).
답글은 처음에 숨어 있고, 대사 사이에 `@show Screen/Column/Thread/ReplyN 0.3` 을 끼워 **한 줄씩 올린다**.

- ⚠️ **`@enter`를 쓰면 안 된다.** 답글은 `VBoxContainer` 안에 있는데 `@enter`는 `position`을 움직여서
  컨테이너 배치와 싸운다 — 줄끼리 겹쳐 그려진다(2026-10-07 겪음). 투명도만 건드리는 **`@show`**를 쓸 것
- 프로필 동그라미는 러프 그림대로 **`_draw()`로 직접 그린다**(`CommentScreen.Avatar`) — 그림 파일이 없다
- `villain_names`에 든 닉네임은 칸과 글자를 붉게 칠한다

#### 집 앞 장면의 배경

`악플러집배경.png`이 **세로(1075x1463)** 라 16:9에 그냥 채우면 70%가 잘린다.
-> **같은 그림을 좌우에 뒤집어 한 장씩 더 깐다**(`DoorLeft`/`DoorRight`, scale.x 음수).
가장자리가 밋밋한 벽이라 이어 붙인 자리가 안 보이고, 빌라 복도처럼 읽힌다. 배율 0.56.
경찰 일러는 **화면 한가운데**(2026-10-07 사용자: "대화할 때 캐릭터가 중앙에 보여야지").

### 아직 안 한 것

- **에피소드마다 2스킬 갈아 끼우기** — `StoryFadeScene`의 `battle_*`처럼 "이 전투에선 이 스킬" 식으로 넣으면 될 듯
- **악플러 AI가 체력 30% 이하에서 때리고 도망** — `AIController`에 없다
- **부스럭 소리 + 뒤 쓰레기가 움직이는 힌트 연출** — 소리와 흔들리는 노드가 필요하다
- 없는 그림: **악플러 사건 파일**, **악플러 서 있는 스토리 일러**(문 앞에서 말하는 장면), 동영상 플랫폼 화면 시안

## 영역 싸움 `combat/DomainClash.gd` (2026-10-07)

남의 영역에 갇힌 쪽이 **자기 영역 궁을 쓰면** 영역을 걸고 한 판 붙는다(사용자 설계).

| 결과 | 어떻게 되는가 |
|---|---|
| 영역 **주인**이 이김 | 영역 그대로 유지. 미니게임 동안 **남은 시간도 안 흐른다** |
| **도전자**가 이김 | 주인 영역이 깨지고 도전자 영역이 전개(궁 연출부터 다시) |

**어느 쪽이 져도 체력은 안 깎인다.** 먼저 편 쪽은 "상대 궁을 아무것도 못 하게 하고 뺏는" 이득을 이미 가져갔다.

- 미니게임은 **새로 안 만들었다** — 같은 슬롯 동시 사용 때 뜨는 `SkillClashPopup`(연타 대결)을 그대로 쓴다.
  거는 조건만 다르다(사용자: "기존 거 재탕하면 되지")
- 영역 궁이 갖춰야 할 것: `domain_owner()`, `break_domain()`, 도는 동안 `DomainClash.GROUP` 들고 있기.
  `is_domain()`은 **`break_domain()`이 있는지**로 가른다
- ⚠️ **시간이 안 흐르는 건 따로 구현한 게 아니다.** 팝업이 `get_tree().paused = true`를 걸고,
  영역 궁은 `process_mode`를 안 건드려서 `_process`가 통째로 쉰다 → `_left`가 저절로 안 준다.
  **영역 궁에 `PROCESS_MODE_ALWAYS`를 주면 이 약속이 깨진다**
- ⚠️ `apply_clash_damage()`를 **일부러 안 부른다**(그게 체력 깎는 곳). `punish_damage_number`도 꺼서 숫자를 안 띄운다
- ⚠️ `tree.paused = true`는 **`popup.start()` 보다 먼저** — 기존 `SkillClashManager`와 같은 순서다
- ⚠️ 내무반(`BarracksUltimate`)은 상대 궁을 `seal_ultimate("barracks")`로 막는데,
  **영역 궁만 안 막게** 예외를 뒀다. 안 그러면 갇힌 쪽이 도전 자체를 못 한다
- 실측(4가지 다 통과): 층간소음 먼저/내무반 먼저 x 주인 승/도전자 승. 거울전(둘 다 층간소음)도 확인.
  체력 `105/105 -> 105/105`, 주인이 이기면 남은 시간 `10.40 -> 10.40`
- 남은 흠: 궁을 누른 **직후 ~0.18초**(11프레임)는 멈추기 전이라 영역 시간이 그만큼 흐른다(10초짜리 미니게임 기준 2%)

### 헬스장 `maps/Gym.tscn` — 운동할지 방해할지

- 2층 발판 + 기구 셋(바벨 컬 = 기본공격력 / 스쿼트 랙 = 점프력 / 런닝머신 = 이동속도). 맵 스킬 `WorkoutSkill`: 운동 중 발 묶임, 맞음·때림·멀어짐 등이면 끊김, 스펙은 쌓는 족족 배수(`custom_data["gym_spec"]`)
- 공격력은 기본공격에만(`compute_basic_damage()`). `GymLayout.gd`는 자식 `_ready()`가 부모보다 먼저라는 것에 기대 스폰을 옮김. `muscle_arm`/`muscle_leg`
- 땅 y=280, 2층 y=100(이단 점프 한계 180px), 벽 ±604. TODO: 기구 그림·배경

#### 배경 타일 선 맞추기 (2026-10-07)

⚠️ **`헬스장바닥.png`·`헬스장벽면.png`·`헬스.png`은 전부 폭 2508px — 같은 원본에서 자른 조각이다.**
그래서 **셋이 같은 가로 매핑**(x -20 ~ 1740, 배율 0.701754)으로 그려져야 타일 선이 맞는다.

- 2층 바닥(`Floor2F/Slab`)이 `stretch_mode = TILE`이라 **원본 크기 1:1**로 깔려 있었다 → 1층 벽 선과 어긋났다.
  `expand_mode = IGNORE_SIZE` + **늘이기(SCALE)** 로 바꾸고 `offset_left/right`를 ±880(= 월드 -20~1740)에 맞췄다.
  세로는 46px로 눌리는데, 그 **눌린 모양이 바닥을 비스듬히 본 입체 효과**라 일부러 그대로 둔다(2026-10-06 사용자: "이거 좋아서 쓸만하겠다")
- `DecoBack`(체육관 안쪽 벽·1층 그림)의 시차를 **0.85 → 1**로 껐다. 바닥·땅은 시차가 없는 실제 지형이라,
  벽만 0.85로 움직이면 카메라가 움직일 때마다 타일 선이 어긋난다(±36px). **거리감은 창밖 야경(`DecoFar` 0.6)과 흐림 셰이더가 맡는다**
- 기구 크기(2026-10-07 사용자 요청 "키우기"): 스쿼트 랙 `0.118 → 0.17`, 바벨 거치대 `0.085 → 0.125`. **런닝머신은 그대로**(사용자: 괜찮다)
  - 기구는 `centered = false` + `offset.y = -그림높이`라 **밑면이 원점에 붙어 있다** — 배율만 키우면 바닥에 선 채로 커진다

#### 눈대중 조절 씬 `maps/GymSizeStudio.tscn` (2026-10-07)

F6으로 띄우면 **게임과 같은 화면**에 헬스장이 나오고, 키보드로 기구 크기·자리·2층 바닥을 고친 뒤
`Enter`로 **파일에 되적는다**(크기·바닥 -> `Gym.tscn`, 자리·뒤집기 -> `GymPlacements.tres`).
비교용으로 캐릭터 리그를 세워 줘서 사람 대비 기구가 얼마나 큰지 바로 보인다.

- `1`~`4` 고르기 / 화살표 옮기기 / `+`,`-` 크기 / `[`,`]` 2층 바닥 두께 / `F` 뒤집기 / `N` 다음 배치 / `C`,`V` 캐릭터 / `R` 되돌리기
- ⚠️ **`Gym.tscn`을 instantiate 하되 트리에 안 넣고 보이는 가지만 떼어 온다**(`KEEP`).
  루트에 `Stage.gd`가 있어서 트리에 넣는 순간 라운드가 시작된다. `_ready()`는 **트리에 들어갈 때** 도니까 이러면 전투 쪽은 안 돈다
- ⚠️ 떼어 올 때 **`owner`를 먼저 지운다** — 안 그러면 곧 free할 `Gym`이 주인으로 남는다
- ⚠️ **비교 캐릭터는 리그 씬만** 띄운다(`<이름>Rig.tscn`). 캐릭터 씬을 통째로 띄우면 `Fighter`가 돌아 떨어지고 입력을 먹는다.
  `BodyRig`는 부모가 `Fighter`가 아니면 가만히 서 있게 이미 되어 있다
- ⚠️ `.tscn` 되적기는 **이름 + 부모**로 덩어리를 찾는다 — `Slab`이 `Floor2F` 밑에도 `Ground` 밑에도 있다

#### 2층 바닥 타일 선 맞추기 — **끝냄** (2026-10-07)

빨간 선(2층 바닥 타일)과 파란 선(1층 벽 이음새)이 안 만난다는 지적 -> **바닥 그림을 새로 깔아 해결.**

⚠️ **1층 벽(`헬스.png`)과 2층 벽(`헬스장벽면.png`)의 이음새 x가 똑같다.** 둘 다 폭 2508px에
같은 가로 매핑(월드 -20~1740)이라, 그 자리에 세로선을 **수직으로** 그으면 위아래 벽선과 한 줄로 이어진다.

**이음새 자리(텍스처 2508px 기준)** — 두 벽에서 각각 재서 교차 확인한 값:

```
197  484  799  1044  1315  1570  1906  2180  2458
```

- 옛 그림(`헬스장바닥.png`)은 **원근으로 그려져 있어서**(소실점 tex x 1250 = 맵 한가운데) 선이 기울고
  간격이 193~266px로 들쭉날쭉이었다. 벽은 정면이라 절대 안 맞았다
- 사용자가 **선 없는 콘크리트**(`헬스장바닥쓰.png`, 2172x724)를 뽑아 왔고, 거기에 위 자리로 선을 그려
  `헬스장바닥_선맞춤.png`(2508x89)을 만들었다. 만드는 법:
  1. 새 질감을 폭 2508로 키우고 가운데 89줄을 자른다
  2. **옛 그림의 행별 중앙값으로 밝기를 입힌다** — 가로 이음새와 위아래 명암이 이걸로 그대로 살아난다
  3. 결을 55%로 죽인다(벽 그림이 납작한 만화체라 결이 세면 혼자 논다)
  4. 위 자리에 세로선(진하기 0.34, 굵기 1.6px 가우시안)
- 기울기를 살린 판도 같이 있다: `헬스장바닥_선맞춤_기울기.png`. 아랫변만 맞고 윗변은 어긋나니 **지금은 수직판을 쓴다**
- ⚠️ 그림을 갈아 끼울 때는 **`uid=`도 같이 바꿀 것**(Godot은 uid를 먼저 본다)

#### 층 넘나들기는 **화면 가장자리** 기준 (2026-10-07)

`GymWrap`이 맵 끝(`0`/`1720`)을 넘어가는 선으로 쓰고 있었다. **그런데 화면에 보이는 건 월드 `220~1500`뿐이다**
(카메라 고정, `follow_speed = 0`). 즉 **화면 밖 220px이 그대로 숨는 자리**였다 — 거기 서 있으면
상대가 보이지도 않고 때릴 수도 없었고, 넘어가려면 그 220px을 더 걸어야 했다.

-> `use_screen_edge = true`(기본). `edges()`가 **카메라의 보이는 범위**에서 매번 선을 다시 잰다:
  `화면 양끝 ± screen_margin(20)` = 지금 맵에선 `200 / 1520`. **몸(반지름 20)이 화면에서 사라지는 순간** 넘어간다
- `inset`은 `40 -> 90`. 나온 자리가 `1430`/`290`이라 **화면 안에서 나타난다**(가장자리에서 70px 안쪽)
- 배율이 변해도(`dynamic_zoom`) 따라가게 **매 프레임 다시 잰다**. 카메라가 없으면 `left_x`/`right_x`로 떨어진다
- 실측: 맵 한가운데(860)에서 왼쪽으로 **664px** 걸으면 2층 오른쪽(1430)에서 나온다. 숨을 수 있는 폭은 **20px**뿐

#### 런닝머신 · 운동 범위 (2026-10-07)

**런닝머신에서 운동해도 레일이 안 돌고 위에 올라선 것처럼 보이지도 않았다.**

| 문제 | 원인 | 고침 |
|---|---|---|
| 벨트가 안 돈다 | `belt_rect`가 **도형으로 그리던 시절 값**(`-74.9,-37,162.5,6.2`) — 그림 좌표로는 월드 **24x1px** | 그림 실측값 `Rect2(-511, -252, 1180, 43)`. `belt_gap/width/speed`도 기구 안쪽 좌표라 **배율만큼 키웠다**(88 / 13 / -640) |
| 기구 옆에 서 있기만 했다 | 설 자리가 없었다 | `snap_on_use` + `stand_offset`(0 = 한가운데). 운동을 켜면 **기구 한가운데로 끌어온다** |

**운동 범위**(2026-10-07 사용자: "어디부터 운동범위인지 모르겠거든?"):

- `show_range` -> 바닥에 **선 하나와 양 끝 턱**(굵기 4px). 기구 색(accent)이라 어느 기구 범위인지도 같이 읽히고,
  **범위 안에 사람이 들어오면 진해진다**(`range_idle_alpha` 0.85 -> `range_near_alpha` 1.0).
  ⚠️ accent가 파스텔이라 밝은 바닥에 묻혔다 -> 셋 다 **진한 색**으로 바꿨다(빨강 0.92,0.16,0.1 / 파랑 0.1,0.42,0.95 / 초록 0.06,0.68,0.18)
- `range_from_width` -> 범위를 **기구 폭 절반 + `range_margin`(25)** 로 구한다.
  지금: 바벨거치대 ±109 / 스쿼트랙 ±137 / 런닝머신 ±155
- ⚠️ `use_range_x`는 **월드 px**, `_draw()`는 **기구 안쪽 좌표**다. 배율로 나눠야 범위와 그림이 맞고,
  **가로·세로 배율이 달라서**(런닝머신 0.149 x 0.178) 굵기도 축마다 따로 나눠야 네모로 보인다
- ⚠️ 처음엔 **타원**으로 그렸는데 기구를 덮어서 지저분했다 -> 바닥 선으로 바꿨다

##### 배치표는 **1번을 기준으로 돌린 것** (2026-10-07)

사용자가 **1번 배치에서만** 눈으로 맞췄다. 그 셋을 **세 자리**로 삼고 나머지 5개는 그 자리를 돌린 것이다:

| 자리 | x | 층 |
|---|---|---|
| A 1층 왼쪽 | 429 | 621 |
| B 1층 오른쪽 | 1306 | 621 |
| C 2층 | 860 | 301 |

기구마다 **묻힌 깊이**가 달라서 y는 `층 + 깊이`로 넣었다 — 바벨 `-1` / 스쿼트 `+7` / 런닝머신 `+19.9`.

- **뒤집기는 "스쿼트가 1층 오른쪽(B)에 있을 때만"** — 원래 표에 적혀 있던 규칙 그대로라 `squat_flip`은 안 바뀌었다
- **런닝머신은 안 뒤집는다.** `face_dir = -1`로 조작판 쪽을 보게 고정돼 있어서, 뒤집으면 등지고 달린다
- 1번은 사용자가 맞춘 값 **그대로** 남아 있다. 다시 맞추면 이 표를 같은 규칙으로 다시 깔면 된다

##### 범위는 조절 씬에서 맞춘다 (2026-10-07)

`GymSizeStudio`에서 **`Tab`(또는 `T`)** 을 누르면 기구 대신 **범위 선**을 고치는 모드가 된다.
노란 테두리가 범위 네모를 감싸고, 화면 글씨도 범위 값으로 바뀐다.

| 키 | |
|---|---|
| `←→↑↓` | 범위 선 옮기기 (`range_offset`) |
| `+` `-` | 가로폭 (`range_margin` — 기구 반폭에 더하는 여유, 음수도 된다) |
| `[` `]` | 세로폭 (`use_range_y`) |
| `Enter` | `Gym.tscn`에 저장 |

- `range_center()` = `기구 원점 + (range_offset.x * 뒤집기, range_offset.y - sink())`.
  **세로 기준은 기구가 선 바닥**이라, 기구를 묻어도 범위가 같이 내려가지 않는다
- 뒤집힌 기구는 `range_offset.x`도 같이 뒤집힌다

##### ⚠️ 하지 말 것 — 기구 자리를 코드가 다시 계산하기

런닝머신 깊이를 자동으로 맞추려고 `GymLayout._place_from_table`에서 **y를 `층 높이 + sink()`로 다시 구했다.**
그 결과 **사용자가 눈으로 보고 하나하나 맞춘 배치표의 y가 라운드마다 통째로 덮였다**(2026-10-07, 사용자가 화냄).

**`GymPlacements.tres`의 자리는 사람이 맞춘 최종값이다. 그대로 넣기만 할 것.**
깊이가 안 맞으면 코드로 보정하지 말고 그 사실을 알리고 사용자가 고르게 한다.
(같은 이유로 조절 씬의 ↑↓도 자리를 그대로 옮긴다 — 다른 값으로 바꿔치기하지 않는다)

#### 넘어가는 자리 표시 `maps/GymWrapGate.gd` (2026-10-07)

층을 넘나들 수 있다는 **표시가 없어서 사람이 사라졌다 나타나는 게 버그처럼 보였다.**
맵 양 끝(1층·2층 네 군데)에 **어두운 통로 + 위로 훑는 화살표**를 그린다.

- ⚠️ **넘어가는 선은 `GymWrap.edges()`에게 물어본다.** 여기 따로 적어 두면 둘이 어긋나서
  "통로까지 갔는데 안 넘어가"가 된다
- ⚠️ **`z_index`를 건드리지 말 것.** 배경 `DecoBack`이 CanvasGroup z=0이라 `-1`을 주면 **그 뒤로 숨는다**(실제로 겪음).
  씬에서 `Ground` 뒤 · `Equipment` 앞에 놓여 있어 기본값이 곧 올바른 순서다
- ⚠️ 흐려지는 쪽은 **`draw_polygon`의 꼭짓점 색**으로 한 번에 그린다. 세로로 쪼개 칸마다 투명도를 주면
  칸 경계가 **줄무늬**로 드러난다(실측)
- 폭 112 / 진한 몫 0.55 / 화살표는 선에서 안쪽 56px. 화면은 선보다 20px 안쪽부터라 **그만큼 당겨 둬야** 안 잘린다

#### 2층 발판 윤곽선 (2026-10-07)

2층 바닥만 윤곽선이 없어서 **밟는 발판이 아니라 벽 무늬로 읽혔다.** `Floor2F` 밑에 `EdgeTop`/`EdgeBottom`
(`ColorRect`, 각 3px, `Color(0.098, 0.102, 0.11)`)을 깔았다. 굵기는 그 둘의 `offset`만 고치면 된다.

- 색은 그림의 윤곽선 실측값 `(25,26,28)`. 5px로 했다가 **두껍다고 해서 3px로 줄였다**(2026-10-07)
- `EdgeTop`이 월드 y 301~304 — **충돌면 윗변(301)이 곧 발 딛는 자리**라 선이 발밑에 깔린다
- 노드 순서상 `Slab`·`Collision` **뒤에** 와야 그림 위에 그려진다

#### 1층 배경 = `헬스장리마스터.png` (2026-10-07)

1층 배경을 `헬스.png`(2508x556) -> **`헬스장리마스터.png`(2172x724)** 로 갈았다.
리마스터는 **같은 그림의 0.866 축소판 + 위아래 검은 띠(위 121px)** 라, 좌표가 딱 떨어진다:

```
리마스터_y = 옛_y * (2172/2508) + 121        가로는 옛_x * 0.866 (오프셋 없음)
```

실측으로 확인: 옛 이음새 197,484,...,2458 -> 171,420,...,2128 과 정확히 일치.
**그래서 벽 이음새의 월드 x가 안 바뀌고, `헬스장바닥_선맞춤.png`을 그대로 쓴다.**

| 노드 | region_rect | scale |
|---|---|---|
| `DecoBack/Scenery1F` | `(0, 188.658, 2172, 335.911)` | `0.810313` (= 1760/2172) |
| `Ground/Slab` | `(0, 518.507, 2172, 84.005)` | `(0.810313, 1.271)` |

- ⚠️ `Ground/Slab`만 **세로를 1.271로 늘였다.** 그림에 바닥이 84px뿐이라 균등 배율이면 월드 689에서 끊기고,
  그 아래 월드 720(화면 맨 아래)까지 **Godot 기본 회색(76,76,76)이 그대로 보인다**(리마스터 이전부터 있던 구멍)
- 리마스터에선 덤벨 랙과 케이블 머신이 빠졌다. `헬스.png`는 이제 아무 데서도 안 쓴다

#### 운동 자세는 **캐릭터마다 따로** (2026-10-06)

운동 자세 아홉 장(컬 3 / 스쿼트 3 / 달리기 3)은 원래 `characters/gym/Gym*Pose.tscn` **한 벌을 전 캐릭터가 같이 썼다.**
`BodyRig._apply_pose_scene()`은 자세 씬에서 **자리와 각도만** 읽으므로(크기는 `rest_pose`만 읽는다),
같은 자리를 머리 큰 캐릭터에게 먹이면 원판이 얼굴을 덮는다. 그래서 캐릭터마다 한 벌씩 만들었다.

- 자리: `characters/<폴더>/gym/<이름>{Curl,Squat,Run}{칸}Pose.tscn` + 편집 씬 `<이름>{Curl,Squat,Run}Studio.tscn`
  - 열 명 x (자세 9 + 편집 씬 3) = **120개**. 리그마다 그 아홉 장이 `curl_down_pose`... 로 꽂혀 있다
  - 고치는 법: **편집 씬을 F6로 열면** 그 캐릭터가 운동한다 → `1/2/3`으로 한 장 크게 띄우고 → 끌어서 맞추고 → `S`로 그 자세 씬에 저장. 자세 씬을 F6로 열어도 짝인 편집 씬이 열린다(`PosePreview.alone_opens_scene`)
- **만드는 건 `tools/GymPoseGen.tscn`**(F6 또는 헤드리스로 실행). 공용 자세를 베껴 **그림만 그 캐릭터 것으로 갈아 끼운다**(자리·각도는 시작점으로 그대로 둔다)
  - ⚠️ **이미 있는 파일은 절대 안 덮어쓴다.** 캐릭터를 새로 넣고 다시 돌리면 **없는 것만** 생긴다 — 손으로 맞춰 둔 자세를 날리지 않으려고
  - ⚠️ 돌린 뒤 **리그 씬에 아홉 줄을 꽂는 건 따로 해야 한다**(`curl_down_pose = ExtResource(...)` ...). 생성기는 자세 파일만 만든다
  - `GameState.CHARACTER_RIGS`에 없는 리그는 생성기의 `EXTRA_RIGS`에 적는다(지금 주인공/경찰 하나)
- **실측: 리그들의 제자리는 거의 똑같다**(Body (1,1) / HandL (-27,4) / HandR (27,3) / FootL (-8,26) / FootR (14,27) / Head (-4~2,-32~-34)). 전부 `BodyRig.tscn`을 인스턴스해서 **그림과 배율만** 다르기 때문이다 — 그래서 캐릭터별로 손봐야 하는 건 "자리를 처음부터 다시"가 아니라 **그림 크기 차이만큼의 보정**이다
#### ⚠️ 장비(로켓·바퀴)를 낀 채 운동하면 **몸이 분리됐다** — 고침 (2026-10-06)

로켓을 신으면 머리·몸·손이 장비 단계 자리로 옮겨지고 거기에 **뜬 높이 16px**(`rocket_hover_height`)까지 더해진다.
그런데 운동 자세(`Gym*Pose.tscn`)에 적힌 자리는 **땅에 서 있을 때 기준**이라, 그냥 입히면
**자세에 적힌 조각만 땅으로 내려오고 자세에 없는 조각은 뜬 채로 남는다.**
컬은 머리를 `HeadView`(보기용)로 두고 `Head`를 안 건드려서 **머리만 16px 위에 떠 있었다**(실측: 머리 y -48 / 몸 y 3).

- 고친 법: `_gear_offset(part)`를 만들어 **자세를 장비 어긋남 위에 얹는다**(`_apply_pose_scene(..., gear_aware = true)`).
  장비 자리가 적힌 조각(머리·몸·손)은 그 어긋남을, 안 적힌 조각(발)은 **뜬 높이만** 쓴다 — 발까지 떠야 로켓이 따라온다(장비는 왼발 그림의 자식)
- ⚠️ `gear_aware`는 **컬·스쿼트에서만** 켠다. 방어·돌진 자세까지 켜면 엉뚱한 데서 떠오른다
- **장비 전용 자세 한 벌**도 둘 수 있다 — 리그의 `curl_*_pose_gear` / `squat_*_pose_gear`.
  **세 장이 다 채워져 있을 때만** 갈아탄다(한 장만 넣으면 섞여서 더 이상해진다). 비면 평소 자세를 쓴다
  - 편집 씬: `characters/<폴더>/gym/<이름>Rocket{Curl,Squat}Studio.tscn`. `GymCurlStudio.gd`의 `gear_stage`를
    `rocket`으로 두면 **로켓을 신고 떠 있는 채로** 자세를 고칠 수 있고, 저장도 `*_pose_gear` 칸으로 간다
  - **지금은 악플러만 뽑아 뒀다**(2026-10-06 사용자: "악플러로 기준 잡겠다"). 기준이 잡히면
    `tools/GymPoseGen.gd`의 `gear_characters`에 이름을 더해 다시 돌리면 나머지도 생긴다

#### 운동 얼굴 두 장 (2026-10-06)

운동 중 표정은 **힘줄 때 = 올라잇 / 그 외 = 힘든(입 벌린 것)** 두 장이다. 타이밍은 `BodyRig`가 정하므로
(`_curl_rising`이 바뀔 때 `_apply_base_head()`), **리그에 그림 두 장만 꽂으면 악플러와 똑같이 돈다.**

| 리그 export | 들어가는 얼굴 |
|---|---|
| `curl_face_rise` / `squat_face_move` | 올라잇 |
| `curl_face_fall` / `squat_face_rest` / `run_face` | 힘든(입 벌린 것) |

- 꽂은 캐릭터: 악플러·금쪽이·주정뱅이·지하철 아저씨·층간소음 빌런·일진
- **그림이 없어서 못 꽂은 캐릭터: 고양이 아주머니 · 황근출 해병 · 인베이전 · 주인공(경찰).** 그림이 나오면 리그에 두 줄만 더하면 된다
- 얼굴 그림이 평소 머리와 크기가 다르면 `curl_face_match_size`(기본 켬)가 **살색 높이**를 재서 맞춘다
- 바벨을 손 앞에 그릴지는 `curl_bar_in_front`(기본 끔 = 손이 봉 위). **금쪽이만 켜 뒀다**(2026-10-06 요청)

#### 변신 단계(핏줄·황금·바퀴·부스터) 편집 — **이미 캐릭터별이다**

`maps/workout/`의 편집 씬들은 처음부터 캐릭터별로 만들어져 있다. 루트의 **`character`** 를 바꾸면 그 캐릭터 몸으로 바뀌고,
조각을 끌어 놓는 순간 `.tres`에 **그 캐릭터·그 단계 자리로 바로 저장된다**(Ctrl+S 불필요).

| 씬 | 단계 | 저장되는 곳 |
|---|---|---|
| `Curl{Vein1,Vein3,Gold}Studio.tscn` | 핏줄 1·3스택 / 황금 손 | `CurlStage.tres` |
| `Squat{Vein1,Vein3,Gold}Studio.tscn` | 같은 것의 발 | `SquatStage.tres` |
| `Treadmill{Bike,Car,Rocket}Studio.tscn` | 자전거 바퀴 / 스포츠카 바퀴 / 로켓 신발 | `TreadmillGear.tres` |

- **장비 그림도 편집 씬에서 바꾼다**(2026-10-06): `GearL`에 새 그림을 끌어다 놓으면 `.tres`에 저장된다.
  예전엔 **로켓만** 저장돼서(`if stage == "rocket"`) 자전거·스포츠카 바퀴는 바꿔도 다시 열면 옛 그림으로 돌아갔다
  - ⚠️ **자전거·스포츠카 바퀴는 전 캐릭터가 같은 그림 한 장**(`bike_texture`/`car_texture`)이라 한 명한테서 바꾸면 모두 바뀐다.
    로켓 신발만 캐릭터별(`rocket_shoes` 사전)이다 — 자기 신발에 번개를 그린 그림이라서. 어느 쪽인지 **편집 씬 땅선 아래에 적어 둔다**
  - 로켓 신발 그림이 없는 캐릭터(층간소음 빌런·황근출 해병·인베이전·주인공)는 **맨발이 그대로 나온다** — 그림이 나오면 GearL에 끌어다 놓으면 된다
- **캐릭터마다 한 장씩도 뽑아 뒀다**(2026-10-06): `characters/<폴더>/gym/<이름>{Bike,Car,Rocket}Studio.tscn`.
  `character`가 그 캐릭터로 박혀 있을 뿐 원본과 같은 씬이라, **어느 쪽으로 열든 고친 자리는 같은 `.tres`의 그 캐릭터 칸**에 저장된다
  - 만드는 건 `tools/GymPoseGen.tscn`이 같이 한다. ⚠️ 뽑을 때 **프레임을 넘기면 안 된다** — 이 씬들은 `_process`에서
    "조각이 움직였나" 보고 `.tres`에 바로 저장하므로, 한 프레임이라도 돌면 기본값을 덮어써 버린다
  - 핏줄·황금 쪽(`Curl/Squat{Vein1,Vein3,Gold}Studio`)은 아직 원본 한 장뿐이다 — 필요하면 생성기의 `SOURCE_STAGES`에 줄만 더하면 된다
- `character`는 **고르는 목록**이다(`_validate_property`가 힌트를 넣어 준다). 목록은
  `RigReader.names()` = `GameState.CHARACTER_RIGS` + `RigReader.EXTRA_RIGS`(주인공/경찰) **한 곳**에서만 온다
  — 주인공(경찰)은 2026-10-06에 `EXTRA_RIGS`로 더했다(그 전엔 목록에서 빠져 있었다)

- ⚠️ 편집 씬에서 `S`로 저장할 때 `alone_opens_scene`을 **그 편집 씬 자신(`scene_file_path`)**으로 적는다. 예전엔 공용 `GymCurlStudio.tscn`으로 박혀 있어서, 캐릭터별 자세를 저장하면 F6가 엉뚱한 캐릭터로 끌려갔다

### 공사현장 `maps/CollapsingApartment.tscn`

- 부서지는 발판 4층(간격 170 = 이단 점프로만), 맵 스킬 `GroundPoundSkill`. **점프력이 바뀌면 다시 계산**

## 화면 흐름 / UI

- `ui/Disclaimer.tscn` → `TitleScreen` → `MainMenu`(스토리/대전/훈련장/가이드/설정). 대전: `RoomSettings` → `CharacterSelect` → `MapSelect` → 맵
- `GameState.gd`(오토로드)가 화면 사이 값을 들고 다님. ESC = 한 단계 뒤로, 대전·스토리 중엔 `PauseMenu`(`process_mode = ALWAYS`)
- `Fade`(검정 ColorRect)는 씬의 **맨 마지막 자식**
- 폰트 주아체 `fonts/Jua-Regular.ttf` — ⚠️ **기호 글리프가 거의 없다**(`◀ ▶ ● ○ · × ↑ ↓` 두부 → 코드로 그릴 것). 대화창은 나눔고딕
- **타이틀 구경 모드**(`game_mode == "attract"`): 랜덤 맵·AI 둘, HUD·컷인 등 없음. 떠날 때 `game_mode` "pvp" + 배율 복구. 로고는 `tools/make_title_logo.py`(**로고를 바꾸면 다시 돌릴 것**)
- 메인 메뉴: `<이름>Item`(판정 고정) > `Slide`(보이는 것만 이동). `Illust*`와 `Background*`는 index로 짝. 일러스트 파츠는 원본 캔버스 그대로 + `centered = false`, **큰 동작은 자세 그림 교체**
- 설정 > 조작 `ui/KeyboardMap.gd`(키 끌어 놓기 배정): ⚠️ `_input`에서 `get_local_mouse_position()` 금지 → `_local_of(event)`. ⚠️ **`refresh()`는 마지막에 `queue_redraw()`**. 저장 `GameState.rebind_action()` → `user://settings.cfg`. 마우스 확인은 사용자가
- 해상도: 기준 1280x720 + `canvas_items`(배치 숫자는 이 기준)
- 확인 창 `ConfirmPopup`: `_ask(문구, Callable)`, 두 갈래 `open_choice()`
- 방 설정 `RoomSettings`: 라운드·시간·쿨 배율·클래시/가드/대시 토글·상대(`vs_ai`). 버튼 연결은 `_ready()` 코드로
- 도감 `CharacterDex`(⚠️ TODO: 놀이터 설명이 옛 기믹). `FanTile.gd`(@tool) 네 점 모양 버튼
- 초상화: 크기·위치는 `ui/PortraitFrames.tscn`, 전부 `GameState.frame_portrait()` 경유. 스킬 로고 `Skill.icon`(투명 여백 잘라 넣기)

### 대전 진행

- `Stage._process()`가 양쪽 HP를 **한 번에** 판정(동시 KO = 무승부), 시간 초과는 HP 높은 쪽. 링아웃 `ring_out_y`
- 선수 판 위치: 기본 아래, `Stage.hud_panels_top`이면 위(놀이터). ⚠️ `panels_top_margin.x`를 76보다 작게 하면 일시정지 버튼에 깔림
- 지상/공중 조건은 스킬이 스스로 판단
- 카운트다운 중엔 컨트롤러 `is_active` false + `move(0)`(`set_physics_process(false)`는 미끄러짐)
- KO 연출 `Stage._play_knockout`(전 모드): 날려 보내지 않고 마지막 넉백대로 물리로 밀려남(`apply_hitstun`으로 멈춘 컨트롤러의 `move(0)`를 막음) + 화면 0.3배 슬로 2초(실제 시간) + 눈 X, 땅에 멈추면 `_lay_down_when_settled()`가 Visual만 발바닥 축으로 90도 눕힘. 화면 흔들림 없음. 디버그 격자: 대전 중 **G + '**(`maps/DebugGrid.gd`)

### 궁극기 컷인 `ui/UltimateCutIn.tscn`

- 기획 확정: 1.5초(장면 `cutin_duration` 우선), **연출 중 시간 정지**, 스킵 없음, 확정타 아님. `use_ultimate()` → 연출 → `fire_ultimate_now()`
- 장면은 `CharacterStats.ultimate_cutin_scene`, 파츠 흔들기 `ui/cutin/CutInAnimation.gd`. 있는 캐릭터: 주정뱅이·금쪽이·악플러·일진·경찰·지하철·고양이 아주머니(검은 고양이만). **궁 스킬에 `cutin_scene_for(fighter)`가 있으면 스탯보다 우선**(같은 캐릭터라도 궁이 갈릴 때). **캐릭터를 움직여 넣을 땐 리그(`<캐릭터>Rig.tscn`)를 쓸 것**
- 지하철 컷인: ⚠️ `Metro!.png` 무늬가 기울어 칸마다 `rotation = -0.0158` + `skew = 0.0158`(그림 바꾸면 재측정), 이동은 x만. 칸 수·틈을 바꾸면 `train_from_x`/`train_to_x`도. 선글라스 반짝은 `LensGlint.always_show`
- 금쪽이 컷인: 원래 머리 복원 → `set_action_face(true)` 순서. 경찰: 얼굴 두 장 크기·위치 같아야 함

### 스토리 모드

- 난이도는 에피소드마다 `StoryFadeScene`의 `battle_enemy_hp_scale`/`battle_enemy_damage_scale`/`battle_ai_skill` → `Stage._apply_story_handicap()`(⚠️ `stats`는 공유 Resource라 **`duplicate()` 후, `add_child` 전에**) / `_tune_story_ai()`
- 에피소드 `GameState.STORY_EPISODES`, 클리어 기록은 `clears_story` 켠 장면의 `_ready()`
- 장면 `ui/story/StoryScene1~11.tscn`, 전부 `StoryFadeScene.gd`. `Fade`는 맨 마지막 자식·알파 0, 장면 루트·대화창 `mouse_filter = 2`. 전환 BLACK/CROSSFADE
  - **스토리→대전:** `battle_*` → `_setup_battle()`(**GameState에 담는 코드는 여기에** — S 건너뛰기가 `_open_next()`를 우회). (임시) `S` 건너뛰기는 방어키와 겹침 → 방어 테스트 땐 `debug_story_skip_key` 끔
- 대화창 `ui/story/DialogueBox.tscn`: `이름|대사`, 명령 줄 `@show/@hide/@enter/@exit/@close/@waitkey/@pause/@stamp`
- **3번·11번 장면은 도장만 다른 같은 구조 — 새 사건은 복사해 문구·도장만 교체**. PSD를 고치면 PNG로도. 게임 글자는 "비비탄"으로 통일

### 살아 있는 컷신 `ui/story/SubwayVillainIdle.tscn` (2026-10-06)

지하철에 앉아 있는 지하철 아저씨 — **포토샵에서 쪼갠 여섯 장을 겹쳐 놓고 조각마다 따로 움직인다.**
여섯 장 모두 `1140x1380` **같은 캔버스**라 전부 같은 자리에 겹치면 원본이 된다(조각마다 자리를 잡을 필요가 없다).

| 조각 | 움직임 |
|---|---|
| 몸통 | 숨쉬기(허리를 축으로 세로만) |
| 단소 든 팔 | 위아래로 쾅 쾅 — 천천히 들었다 빠르게 내리꽂고 튄다. 친 순간 화면도 흔들린다 |
| 머리 + 턱 괸 팔 | 좌우로 **같은 박자**(턱을 괴고 있어 따로 놀면 안 된다) |
| 머리카락 | 머리를 `hair_lag`만큼 늦게 따라 흔들림(한쪽만) |

- ⚠️ **돌릴 축은 `offset = -축` + `position = 축`으로 잡는다.** Sprite2D는 centered를 끄면 왼쪽 위를
  중심으로 도는데, 머리카락을 그렇게 돌리면 화면 바깥을 축으로 빙 돈다
- 화면 채우기는 `Frame` 노드 하나의 배율·자리로만 한다(`fill_screen`/`focus_x`/`focus_y`/`zoom`).
  세로로 긴 그림이라 채우면 위아래가 잘리므로 **어디를 보여줄지는 `focus_y`가 정한다**(기본 430 = 머리~단소)
- 흔들림은 **`Frame`을 통째로** 흔든다 — 조각을 따로 흔들면 서로 어긋난다
- **스토리 장면에서 숫자 8을 누르면 뜨고, 다시 누르면 사라진다**(`StoryFadeScene.preview_key_scene`, 만들던 컷신 확인용). **숫자 9는 다음 컷**(`preview_key_scene_9`)이고, 다른 번호를 누르면 갈아 끼워진다.
  ⚠️ `Fade`(검은 가림막)가 장면의 마지막 자식이라, 미리보기는 **그보다 뒤에 붙여야** 전환 중에도 보인다

### 얼굴 클로즈업 컷 `ui/story/SubwayVillainSmirk.tscn` (2026-10-06)

얼굴로 다가가다가 **"쉬익" 하는 순간 배경이 한 프레임에 사라지고 얼굴만 남는다.** 그 뒤 이빨이 **삐싱** 반짝인다.

- ⚠️⚠️ **`_0005_Background.png`은 배경이 아니라 원본 통짜 그림이다** — 사람이 통째로 들어 있다.
  그 위에 씨익 웃는 얼굴을 얹으면 **얼굴이 두 개로 보인다**(2026-10-06 실측). 이 컷은 그래서 **배경 그림을 안 쓴다**.
  배경이 필요하면 `background_texture`에 **사람이 없는** 그림을 따로 넣을 것
  - 앉아 있는 컷(`SubwayVillainIdle`)은 그 위에 조각들을 덮어 가리므로 괜찮다. 다만 **조각을 크게 움직이면 밑의 원본이 비친다**
- ⚠️ **씨익 웃는 그림은 앉아 있는 컷의 머리와 안 맞는다**(실측 bbox: 씨익 (473,79)-(749,375) vs 머리 (419,109)-(639,323)) —
  더 크고 오른쪽으로 치우쳐 그려져 있어 몸에 얹으면 목이 어긋난다. 그래서 **따로 찍는 컷**이다
- 실측: 얼굴 `276x296px`, 화면 1280x720 → **`zoom` 2.17이면 얼굴이 세로로 딱 맞는다**. 지금은 2.55 → 3.15로 다가간다
- **쉬익**: `whoosh_at`(0.75초)에 배경색이 한 프레임에 바뀌고, 흰 번쩍임(`flash_strength` 0.75)과 속도선이 터진다.
  **서서히 바꾸면 "쉬익"이 아니라 "스르륵"이 된다** — 색은 한 프레임에 갈아 끼울 것
- **이빨 삐싱**은 `LensGlint`를 그대로 쓴다(선글라스 번쩍임과 같은 부품). 이빨 자리는 흰 픽셀 밀도를 재서 찾았다 — **원본 (600, 254)**
  - ⚠️ 얼굴 스프라이트의 **자식**으로 달아야 얼굴이 커질 때 같이 간다. `offset` 때문에 자식 좌표는 `이빨자리 - 축`이다
  - 스스로 도는 타이머는 꺼 두고(`interval_min/max` 9999) 이쪽에서 `blink_now()`로 터뜨린다
- **카메라 좌우 훑기는 뺐다**(2026-10-06 사용자 요청). 다가가기(push-in)만 남았다

### ⚠️ 그림을 갈아 끼울 땐 **uid도 같이** 바꾼다 (2026-10-06)

`.tscn`/`.tres`의 참조는 이렇게 생겼다:

```
[ext_resource type="Texture2D" uid="uid://cf5dlqlyj3jys" path="res://.../런닝머신(8~9).png" id="3_car"]
```

**Godot은 `uid`를 먼저 본다.** 경로만 새 그림으로 바꾸고 uid를 그대로 두면 **옛 그림이 그대로 나온다**(조용히).
새 uid는 그 그림의 `.png.import` 첫머리 `uid=` 줄에 있다. uid가 아예 없는 줄(생성기가 만든 씬 등)은 경로만 바꾸면 된다.

- 바퀴(스포츠카 단계)를 `런닝머신(8~9).png`(민 휠) -> `헬스장바퀴.png`(타이어 있는 버전)로 갈아 끼운 예:
  12개 파일(캐릭터별 `*CarStudio.tscn` 10 + 원본 스튜디오 + `TreadmillGear.tres`)에서 **경로와 uid를 같이** 바꿨다
- 캔버스 크기가 같으면(둘 다 1254x1254) 맞춰 둔 자리·배율이 안 흔들린다. **다른 크기 그림으로 바꾸면 단계 자리를 다시 봐야 한다**

### ⚠️ 헤드리스 검사가 **스크립트 오류를 놓친다**(2026-10-06에 실제로 겪음)

`load(path) == null`로만 보는 검사는 **파싱 오류를 못 잡는다** — 중복 함수처럼 컴파일이 깨져도
`load()`가 null이 아닌 걸 돌려줘서 "실패 0"으로 통과한다. 검사 출력에서 **`SCRIPT ERROR` / `Parse Error`를
같이 grep**할 것.

```
godot --headless --path . res://_chk.tscn 2>&1 | grep -iE ">>> |씬 [0-9]+ \||SCRIPT ERROR|Parse Error"
```

파일 하나만 빠르게 볼 땐 `godot --headless --check-only --script <경로>`(종료코드 0 = 정상).
⚠️ 단 이 방법은 **오토로드를 안 올린다** — `GameState`를 쓰는 스크립트는 "Identifier not found: GameState"가
뜨지만 **가짜 경보**다.

⚠️ **남이 만든 파일에 함수를 더할 땐 같은 이름이 이미 있는지 먼저 본다.** `_validate_property`를
`_get_property_list`만 찾아보고 없다고 단정했다가 중복으로 넣어 씬이 안 열렸다

## GDScript 코드 스타일

| 대상 | 규칙 | 예시 |
| --- | --- | --- |
| 클래스명 / 파일명 | PascalCase, 파일명 = class_name | `CharacterStats` |
| 함수 / 변수 | snake_case | `move_speed`, `take_damage()` |
| 상수 / enum 값 | ALL_CAPS_SNAKE_CASE | `MAX_HP` |
| 시그널 | 과거형 snake_case | `health_changed` |
| private 관례 | 언더스코어 접두사 | `_internal_cooldown` |

- `class_name`·`extends` → `@export` → 멤버 변수 → 생명주기 → 커스텀 함수. 씬과 스크립트는 같은 폴더에
- 주석은 한국어: public 함수/변수 위 `##` 한 줄, 복잡한 로직에만. 자명한 코드엔 주석 금지

```
res://
  GameState.gd  Timers.gd
  characters/   # Fighter.gd + BodyRig.gd + 캐릭터별(chokbeopsonyeon, akpeulleo, jujeongbaengi, catmom,
                #   subwayvillain, floornoise, gymbro, iljin, hwanggeunchul / 로스터 밖: police, dummy)
  skills/  combat/  controllers/  stats/  maps/  ui/(story/, cutin/)  tools/
```

## 참고

- 기획 미정은 임시값 + TODO
- `invalid UID` 경고 → 씬 uid를 `.import`의 uid로
- **결과가 확실하지 않으면 실행해서 확인할 것**(2026-10-09 사용자 — 예전 "확인 안 함" 규칙을 바꿈). 특히 **화면에 보이는 것**(배치·그림·흐림)은 창 모드로 띄워 `get_viewport().get_texture().get_image().save_png()` 스크린샷을 찍어 직접 본 뒤 보고. 뻔한 수정은 생략해도 됨
- Godot 실행 파일: `C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`(Steam판 4.7.2, console판 없음)
- **에디터 자동 다시 불러오기 플러그인 `addons/auto_reload_scenes`**(2026-10-09): 열린 씬의 `.tscn`이나 그 씬이 쓰는 `@tool` 스크립트가 밖에서 바뀌면 1초 안에 묻지 않고 다시 불러온다(Godot엔 씬 자동 반영 설정이 없고, "디스크가 더 최신" 창에서 **다시 저장**을 누르면 밖에서 고친 게 덮어써졌다). ⚠️ 그 씬의 저장 안 한 에디터 변경은 사라진다
- 헤드리스 테스트: 쓰이는 씬을 띄울 것(`--quit-after`만으론 파싱 에러 못 잡음). `extends SceneTree --script` 금지 → `extends Node` 임시 `.tscn`. 시간 기반은 `--fixed-fps 60`. `apply_physics()` 중복 호출 금지, 순간이동 직후 착지 랙 대기
