# 트러블 메이커 (villain) — Godot 프로젝트 규칙

사이드뷰 대전 격투 게임 **"트러블 메이커"**(리포·폴더 `villain`, 빌드 `build/TroubleMaker/`). 기획 문서: https://claude.ai/code/artifact/661e48af-d8db-49c9-bc68-a9294790becb
전역 규칙(한국어 응답, 초보자 눈높이, 안전 규칙) 유지, 코드 스타일은 이 문서 우선 — **Godot/GDScript**(전역 CLAUDE.md의 Unity/C# 규칙 아님).

> 2026-10-03에 다시 압축했다(날짜·변경 이력·코드에 있는 세부 수치는 뺌). 옛 내용은 git 이력의 `CLAUDE.md`.

## 프로젝트 정보

- 엔진 Godot 4.7.2, Forward Plus, 3D 물리 Jolt(기본값 — 게임은 2D)
- 사이드뷰 대전 격투, 바운스어택류(넉백을 다시 잡아채는) 콤보 중심. 히트스턴 최소화, 지형·벽 기믹

## 핵심 아키텍처

**캐릭터 전용 `.gd`는 만들지 않는다** — 모든 캐릭터 씬 루트가 `characters/Fighter.gd`, 차이는 스탯(`.tres`) + 스킬 노드 조합뿐.

- `Fighter.gd`(`CharacterBody2D`): 이동/점프/중력, HP(`take_damage`/`heal`/`health_changed`), 스킬 슬롯(자식 `Skill1`/`Skill2`/`SkillUltimate`/`BasicAttack` 자동 연결), 자유 데이터 `custom_data`
- **버프·디버프는 직접 대입 금지** → `set_modifier(property, id, value)`/`clear_modifier(property, id)`(id별 저장 후 곱함), 임시 `apply_temp_multiplier(property, value, duration)`. `set()`은 겹친 디버프를 지운다
- 색조도 같은 방식 `set_tint(id, color, duration)`/`clear_tint(id)`
- **캐릭터끼리 몸 충돌 없음**: `_ignore_other_fighters()`가 양방향 `add_collision_exception_with`(레이어는 바닥·벽까지 영향이라 안 건드림). Area2D 판정은 그대로
- **공용 정적 헬퍼 — 다시 짜지 말 것:**
  - `combat/PhysicsQuery.gd`: `raycast_ignoring_fighters(ctx, from, to)` / `ground_y_below(ctx, from, probe, fallback_y)`
  - `Timers.gd`: `after(owner, delay, cb)`(`real_time` 옵션) / `self_destruct(target, lifetime)` — owner 자식 Timer로 예약
  - `Fighter.find_fighter_in_box(fighter, range_x, range_y, direction, back_tolerance := 20.0)`
  - `CrashBurst.spawn(parent, pos)`. 색·조각 수는 `CrashBurst.new()` 후 **add_child 전에**
- `skills/Skill.gd`(`Node`): 쿨·`can_use()`/`use(fighter)`. 새 스킬은 상속 후 `_execute(fighter)`만 오버라이드
  - 궁극기는 라운드 시작 시 쿨을 물고 시작(`start_on_cooldown`). 라운드마다 `reload_current_scene()`(승수만 `GameState`)
  - `_ready()` 오버라이드 시 반드시 `super()`. 궁 쿨은 컷인 뒤(`fire_ultimate_now()`)부터
  - **쿨은 전부 `effective_cooldown()`을 거칠 것**(`cooldown_override` > 0이면 그 값 x `attack_speed_multiplier` x `GameState.cooldown_multiplier`). `cooldown`을 직접 읽는 경로를 새로 만들면 그 경로만 배율이 안 먹는다
  - 스킬2를 잠깐 갈아끼우려면 `Fighter.swap_skill_2(skill)`(원래 스킬 반환, `skill_slots_changed` → HUD가 다시 묶음)
  - 궁극기 봉인 `seal_ultimate(id)`/`unseal_ultimate(id)`/`is_ultimate_sealed()`(`use_ultimate()` 맨 앞에서 막음)
- **⚠️ 스킬에서 `Visual.scale` 직접 트윈 금지 → `BodyRig.play_squash(배율)`**(왼쪽일 때 `scale.x` 음수)
- `combat/Hitbox.gd`/`Hurtbox.gd`: Hurtbox(Fighter 자식 Area2D)가 피격 시 `take_damage()`, Hitbox는 겹치면 데미지(자기 자신 무시)
  - **허트박스는 머리 꼭대기까지**: `HurtboxCollision`(별도 `CapsuleShape2D_hurt`) 발끝 +30, 윗끝 = 머리 그림 꼭대기(높이 = 30 - 꼭대기, `position.y` = (30 + 꼭대기)/2, 금쪽이는 프로펠러 빼고). **머리 그림을 바꾸면 다시 잴 것**
  - `source_fighter`는 setter + `_has_source`로 주인 유무 기억. 주인 없는 히트박스(열차)도 동작해야 하므로 `is_instance_valid`만으로 막지 말 것
  - `pull_to_source`/`pull_strength`(끌어당김), `repeat_interval` > 0이면 겹친 동안 재타격(껐다 켤 때 `clear_repeat_state()`), `hit_spark`, `debris_enabled`/`debris_scene`, `sense_only`(피해 없이 `connected`만)
- **맵 피해는 `Fighter.take_map_damage()` 한 곳으로**(분기는 `Hurtbox.take_hit()`, 방어를 깸). `take_damage()`의 `ignore_guard`를 밖에서 true로 주지 말 것
- ⚠️ `take_damage`는 넉백을 기존 속도에 **더한다** → 정확한 속도가 필요하면 받은 뒤 `velocity`를 덮어쓸 것
- 이동을 가로채는 스킬: `Fighter.movement_override`에 자신 등록 + `get_move_velocity_x()`/`after_physics(fighter, delta)`(`DashSkill.gd`). 대시 가로채기는 `Fighter.dash_override`
- 잡기는 `is_grabbed = true`면 `apply_physics`가 중력·이동을 건너뜀 → 스킬이 `global_position`을 직접 옮김. 잡기 전 `can_be_grabbed()`·`cancel_finisher_flight()`
- `is_feared`/`apply_fear()`: 이동만 되고 공격·스킬 무시(지금 쓰는 캐릭터 없음)
- **슈퍼아머** `add_super_armor()`/`remove_super_armor()`/`has_super_armor()` — **개수로 셈, 짝 필수**. HP·반짝임·`damaged`는 들어가고 넉백·경직·구르기·잡기·기절 별은 막힘. `blocks_debuff()`에 섞지 말 것
- `Hurtbox.fighter`는 `Node` — `area.fighter as Fighter`로 확인. HP 있는 오브젝트는 `take_damage()`/`take_map_damage()`/`is_guarding`만 있으면 됨

### 함정 모음 (실제로 겪음)

- **Lambda capture:** `create_timer(t).timeout.connect(func(): 노드.x = ...)`는 노드가 먼저 사라지면 에러 → **그 노드의 자식 `Timer`로**(`Timers.after`, `Fighter._after`). 짧은 `await create_timer().timeout` 한 번은 괜찮음
- **`Skill`은 `Node`라 좌표가 없다** → Skill 자식 Hitbox는 `fighter.global_position + Vector2(range * fighter.facing, 0)`로 직접 옮김
- **add_child 함정:** `add_child()`는 `_ready()`를 즉시 실행 — 그 뒤 넣은 값은 `_ready()`에 안 보인다. add_child 전에 대입하거나 첫 `_process`로 미룰 것(`Projectile` 수명은 `setup()`에서)
- **해제된 객체는 `== null`이 true** → 주인 유무는 따로 불리언으로 기억
- `take_hit()`을 직접 부르는 노드를 새로 만들면 `_has_source` 검사 필수(지금은 `Hitbox`만 부름). `Projectile`은 `source_fighter`의 Hurtbox/몸을 무시해야 함
- **⚠️ `_draw()`에서 0이 될 수 있는 모양은 `draw_colored_polygon` 말고 `draw_primitive`로** — "triangulation failed"가 매 프레임(`--headless`에선 안 보임)
- 그림/스크립트가 안 보이면 **Output 패널 파싱 에러부터**
- 새 `class_name`을 preload 타입으로 바로 붙이면 캐시 전 파싱 에러 → 무타입 + `preload`
- Area2D 맵 기믹에서 `gravity`·`priority`·`monitoring`·`linear_damp`·`angular_damp` 변수명 금지
- `.tscn`은 모든 노드 뒤에 `[connection]`. 노드를 손으로 끼울 땐 부모 속성 줄 **다음**에
- CollisionShape2D는 물리 바디의 **직계 자식**만 등록됨
- 씬 첫 프레임 delta가 튐 — 시간 누적 연출엔 `minf(delta, 0.05)`
- 전체 화면 배경 Control은 클릭을 삼킨다 → `mouse_filter = 2`
- `set_input_as_handled()`는 `change_scene_to_file()`/자기 `queue_free()` **전에**
- `duplicate()`는 기본으로 신호까지 복사 → 판정 복제는 `DUPLICATE_SCRIPTS | DUPLICATE_GROUPS`. 잔상은 `Visual` 복제 후 **스크립트를 뗄 것**
- 판정 모양을 명중 콜백 안에서 바꿀 땐 `set_deferred("shape", …)`
- 셰이더: 사용자 함수 안에서 `TEXTURE`/`UV` 못 씀. **`COLOR`를 덮어쓸 땐 처음 `COLOR`를 곱할 것**(안 곱하면 그 파츠만 색조가 빠짐). CanvasGroup은 `modulate`가 두 번 곱해짐 → 어둡게는 `self_modulate`. Polygon2D는 `vertex_colors`가 있으면 `color` 무시
- GitHub Desktop이 브랜치 이동 시 작업을 stash에 치운 적 있음 — 뭔가 사라지면 `git stash list`부터
- PowerShell: 변수 이름 대소문자 무시. Bash 도구 heredoc 속 python에선 `\` 줄끝이 먹힐 수 있음

## 전투 시스템

### 기본공격 `skills/ComboMeleeAttack.gd`(`MeleeAttack` 상속) — 전 캐릭터 3타 콤보

- 판정은 캐릭터 앞 40px의 30x30 상자. 헛치면 예약 입력 버림 + `miss_cooldown` + 1타 리셋, 3타 성공 시 `cooldown`. 타별 값은 `combo_damage`/`combo_knockback` 배열
- 브롤할라식 `combat/AttackData.gd`: `hits`에 .tres 순서대로(지금 금쪽이만, 비면 옛 배열). 판정 시각은 `BodyRig.strike_time()`(보통 40%)
- windup 0이면 `_fire()`가 물리 프레임 **두 번** 대기. **`attack_duration`을 바꾸면 `windup`(= duration x 0.4)도**
- **📌 3타 준비시간은 0.223초 고정(새 캐릭터도).** 옛 배열은 `finisher_windup` = 0.223이면 3타 모션이 자동으로 늘어남. 회전·발차기 타는 리그 `spin_duration`/`kick_duration`으로 맞출 것
- **확정 콤보** `link_stun_margin`: 1·2타 명중 시 경직을 "다음 타 예비동작 + margin"으로 보장(`_hold_for_next_hit`), 상대 가로 속도를 지우고 이번 넉백만. **넉백을 키우면 파고들기(`combo_lunge`)도 같이**
  - `combo_lunge`: 예비동작 동안 이동, 판정은 도착 자리 기준. 푸시백은 `v = sqrt(2 x HITSTUN_FRICTION x 거리)`로 역산
  - 공중에서 경직이 풀릴 때 가로 속도 유지 = `_launch_momentum`
- 회전 타격 `BodyRig.spin_hit_index`(-1 = 안 돔): 루트 `scale.x`에 cos를 곱함 — ⚠️ 다음 프레임 `_apply_pose` 첫머리에서 되돌릴 것, 최소 0.04
- 그랩 후 회전 난무(`spin_flurry_*`, 악플러): 판정은 바라보는 쪽 반원, `spin_wind` 바람은 "엄청 얇게"(사용자 요청)

### 3타(마무리) 날아가기 — `Fighter.launch_finisher()` + `FINISHER_*` 상수

- 발사: 45도 위로(`FINISHER_LAUNCH_ANGLE_DEG`), 최고 높이 `FINISHER_PEAK_PER_SCALE` x 체력 배율로 자름. 옆 속도만 `FINISHER_HORIZONTAL_SCALE`배. `finisher_distance_scale`은 **속도 배수라 거리는 대략 제곱**
- `shape` 딕셔너리(`speed`/`peak`/`airtime` 배수)로 첫 포물선만 바꿀 수 있음(드롭킥·내무반 내려찍기). 중력 = peak/airtime², 공중 감속 /airtime
- 날아가는 동안 중력 `FINISHER_GRAVITY_SCALE`, 공중 옆 속도는 **비율로** 감속
- **`FINISHER_TIME_SCALE`**: 궤적은 그대로 시간만 줄임(속도 x배율, 중력·감속·마찰 x배율²). 다른 `FINISHER_*`는 배율 1 기준 값
- **기절 = 완전히 멈출 때까지**(`_finisher_flying`, `_update_finisher_flight()`). 안전 한도 `FINISHER_MAX_FLY_TIME`, 잡히거나 슈퍼아머면 즉시 끝
- 벽 튕김 `_try_finisher_wall_bounce()`: 가로만 반대로, 위아래 그대로. 속도는 `move_and_slide()` **전에** 기억(`pre_vx`)
- 땅 튕김: 첫 착지는 무조건 튕기고 옆 속도를 상대 반대쪽으로 덮어씀(`FINISHER_GROUND_KICK`), **두 번째부턴 안 민다**
- 날아가는 중 추가타 `_rebound_finisher()`: 옆 속도·기절 연장만. 1·2타로 쳐도 안 멈춤
- **잡기 스킬은 `cancel_finisher_flight()`를 먼저**(안 하면 잡기 피해가 추가타로 쳐져 튕겨 나감)
- 판정 캡슐은 구르는 그림을 안 따라 돈다(미해결). `finisher_trail`이면 `combat/LaunchTrail.gd`

### 클래시(같은 스킬 동시 사용 → 연타 대결)

- `combat/SkillClashManager.gd`(`Stage.gd`가 심음, `"skill_clash_manager"` 그룹): 같은 슬롯을 `match_window` 안에 쓰면 화면 정지 + `ui/SkillClashPopup.tscn`, 진 쪽 `cancel_use()`. **스킬1·2·궁만**. 방 설정에서 끄면 즉시 `on_win`
- 연출 `SkillClashPopup.gd` + `ClashBand.gd`: 사선 경계선이 곧 게이지, 연타 키는 기본공격, 결착은 누른 횟수. 연타 수치는 시뮬레이션 값(AI를 세게 하려면 AI 간격만)
  - `ClashBand`는 가로 띠 조각 `draw_primitive`. 띠는 위쪽(`band_center_ratio`)
  - 주먹 러시: 연타 1번 = 주먹 2방, 잔상 owner 없음. 대치 중 리그 `process_mode = ALWAYS`, `_pose_clash()` 기울기에 `facing` 부호

### 이동·방어·대시

- `jump()`: `max_air_jumps`·`air_jump_velocity`·`gravity`·`jump_velocity`는 **static var**(영구 반영은 `DEFAULT_*`). `_air_jumps_left`는 `move_and_slide()` **뒤에**
  - 이단 점프 전체 ≈ 216px. **점프·중력을 바꾸면 맵 발판 사다리(놀이터·지하철 의자·공사현장·헬스장)를 같이 확인**. 이동속도는 `stats/*.tres`의 `move_speed`
- **착지 경직**: `landing_lag_height` 이상 낙하면 전부 막힘. 피격 낙하·`movement_override` 착지는 제외. 착지 즉시 튕기는 기믹은 `cancel_landing_lag()` 필수. 스쿼시는 발바닥(+30) 기준
- **대시**(이동키 두 번): ≈ 112px, 쿨 2.5초(`effective_dash_cooldown()` — `dash_cooldown_bonus` 포함), 맞으면 끊김
- **방어**(아래 키 누르는 순간, `combat/GuardShield.gd`): `guard_duration` 동안 데미지·넉백 0 → `guard_cooldown`
  - 디버프·그랩 차단, **궁극기 디버프만 관통**(`blocks_debuff(from_ultimate)` 한 곳). `set_modifier` 직접 호출은 검사 안 거침
  - 방어 중 이동·점프·공격 전부 막힘. `GUARD_CANCEL_WINDOW` 안 점프면 `cancel_guard(true)`로 쿨 환불(발판 통과와 키가 겹쳐서)
  - 자세 `BodyRig.set_guarding()`(손은 머리 앞 끝 x=25보다 앞, `guard_hand_deg` 음수)
  - 막히면 "BLOCK" + `blocked_attack_lock` 동안 기본공격 잠김 + 무기 빨강(`BlockedOutline.gdshader`). 막힘 판정은 `Hitbox._try_hit()`에서 **한 번만**
  - 가드/대시 off는 `can_guard()`/`can_dash()` 맨 앞
- 쿨 파이 `combat/CooldownPies.gd`: 등 뒤 작은 원(방어 하늘색/대시 라임), 기본공격 잠김은 빨간 X. 타이틀에선 숨김
- **발판 내려가기**: 레이어를 끄지 말고 발판에 `add_collision_exception_with`. 예외는 **바디 전체** → 한 바디에 막힘 충돌을 섞지 말 것. 올라갈 수 있는 발판은 `one_way_collision = true`

### 이펙트

- 히트: `_flash_hit()` + `combat/HitSpark.tscn`(세기 = 데미지 / `SPARK_POWER_DAMAGE`, 막히면 파랗게)
- **히트스톱은 꺼져 있다**(`Hitbox.hitstop_time` 0). 켜면 `Engine.time_scale`, 복귀 타이머 `ignore_time_scale = true`
- 착지 먼지 `LandDust.gd`, 점프 바람 `JumpWind.gd`(`setup(방향, 공중)`), 돌진 바람 `skills/ChargeWind.gd` — 전부 **맵에 붙임**(캐릭터 자식이면 반전에 뒤집힘)
- 피격 움찔 `play_hit_flinch()`: **그림만 움직임**(물리로 띄우면 확정 콤보 깨짐)
- 기절 별 `StunStars.spawn(fighter, 시간)`: 맵에 붙여 따라감, 이미 있으면 `extend()`

## 캐릭터 현황

캐릭터 씬의 `BasicAttack`/`Skill1`/`Skill2`/`SkillUltimate` 스크립트가 전부다. **빈 `skills/Skill.gd` = 의도된 미구현.** 로스터 `GameState.CHARACTERS`, 주인공만 `TRAINING_ONLY_CHARACTERS`, 숨겨진 캐릭터 `HIDDEN_CHARACTERS`.

| 캐릭터 | 기본공격 | 스킬1 (G) | 스킬2 (H) | 궁극기 (R) |
|---|---|---|---|---|
| 금쪽이(촉법소년) | 막대사탕 3타 | `DashSkill` 자전거 | `BBGunSkill` 비비탄 | `HealSkill` |
| 악플러 | 키보드(두 손) | `MouseGrabSkill` | `RageBuffSkill` 열등감 | `WeakenAuraUltimate` |
| 주정뱅이 | 술병 | `DrinkSkill` 술 스택 | `VomitSkill` 토 기둥 | `ScreamConeUltimate` 괴성 |
| 고양이 아주머니 | 3타 | `TunaThrowSkill` | `TunaPlaceSkill` | `CatHutUltimate` |
| 층간소음 청년 | 3타 | `AoeAttack` 기타 둔화 | `VacuumSkill` 흡입 | `DunkUltimate` |
| 지하철 아저씨 | 단소: 찌르기→발차기→회전 베기 | `TurnstileSkill` | `CounterSkill` | `DualInstrumentUltimate` 쌍 악기 |
| 헬스장 빌런 | 3타 | `LivingShadowSkill` | `BackSuplexSkill` | 빈 `Skill.gd` |
| 일진 | 주먹·주먹·가방 | `CigaretteSmokeSkill` | `ShoulderChargeSkill` | `IljinCrewUltimate`(등장만) |
| 주인공(경찰) | 맨손 잽 / 경봉 모드 | `TaserGunSkill` | `StoneThrowSkill` | `BatonModeUltimate` |
| 황근출 해병(숨김) | 잽·잽·박치기 | `DropkickSkill` | `JjajangEatSkill`(내무반 안: `BarracksSlamSkill`) | `BarracksUltimate` 내무반 |

- **금쪽이 = 촉법소년의 표시 이름.** 표시 이름이 키라 바꿀 땐 전부: `GameState`(CHARACTERS·색·초상화·리그), `ChokbeopsonyeonStats.tres`, `CharacterSelect.tscn`, `CharacterDex.tscn`, `PortraitFrames.tscn`, `Stage.knockout_characters`, `sprite/도감/전신/금쪽이.png`
- 새 캐릭터 크기 기준 = 악플러(머리 ~53x52, 상한 55x55)
- **캐릭터를 추가하면 `GameState.CHARACTERS`와 `CHARACTER_RIGS` 둘 다**(선택창 전신 미리보기·맵 선택·VS 화면이 봄)
- 숨겨진 캐릭터: 선택창에서 **aaddssww** → 아래 줄이 숨겨진 칸으로(`_toggle_hidden_mode`). 경로 `GameState.character_path()`. 타이틀 구경·도감엔 안 나옴

### 황근출 해병 `characters/hwanggeunchul/`

- 그림 `sprite/황근출 해병/`(오타 파일명 그대로: `황 근충 해병 팔.png`, `환근출 해병 정면.png`, `황근축 해병 몸 측면 3.png`). **기본 몸 = 옷 입은 버전**(`HwanggeunchulUniformRig.tscn` — 캐릭터 씬 `Visual`·`GameState` 리그·튜토리얼 교관 공용)
- 기본공격: 뒷손 잽 → 앞손 잽(경찰 맨손 잽 재사용) → 박치기(`unarmed_headbutt`, `_pose_headbutt()`, 로컬 좌표라 facing 부호 안 곱함). 수치 = 악플러 배열
- 스킬1 `DropkickSkill`: 무릎 꿇기(슈퍼아머, `set_kneeling`) → 300px 날아 차기 → 맞으면 `launch_finisher(…, shape)`(옆 x2·높이 x2·체공 x5), 헛치면 착지 후 1초 못 움직임(쓰는 내내 점프도 막음 — `Fighter.jump()`가 `movement_override.blocks_jump()`를 봄)
- 스킬2 `JjajangEatSkill`: 1초 먹고 잃은 체력 30% 회복, 먹을 때마다 대시 쿨 +2초(라운드 끝까지, `dash_cooldown_bonus`), 맞으면 끊김. ⚠️ `EatBowl` 순서는 씬의 `index="3"`으로 — `_ready()`에서 `move_child`하면 대시 잔상이 자식 속성을 순서로 복사해 머리가 커진다
- **궁 `BarracksUltimate`**: 옷 벗어 던짐(`get_body_outfit()`/`set_body_outfit()`, 맨몸 값 `bare_body_*`) → 원래 맵이 깨져 떨어짐(`combat/ScreenShatter.gd`, 못 찍으면 암전) → 두 캐릭터를 내무반으로 옮겨 15초 → 같은 연출로 복귀(까만 동안 다시 입음)
  - 내무반은 맵 위 `arena_offset`(0,-6000)에 그때 생성: 그림 `궁극기/군대 집.webp` 배율 0.75(작을수록 캐릭터가 크게 보임, 앞 층은 `size_scale`로 같이 맞춰짐), 바닥 = 그림 y 790, **천장 = 그림 y 85**(`ceiling_image_y`), 벽은 그림 끝 20px 안. 그동안 맵 루트 CanvasItem·`Deco*` CanvasLayer를 숨기고 **`process_mode` DISABLED로 멈춤**(카메라 제외 — 열차 흔들림·소리·충돌이 내무반에 안 새게, AI `_hazard_active()`도 `can_process()` 아닌 기믹은 무시). 카메라 `CameraRig.enter_arena(rect, 보는 곳, close_zoom)`/`leave_arena()`(`arena_close_zoom` 1.2 = 방 전체 배율의 1.2배까지만 당김, `arena_look_up` 120 = 두 캐릭터 가운데보다 위를 비춤), CameraRig가 없는 훈련장은 `_enter_plain_camera()`가 평범한 Camera2D를 직접 옮김. 도는 동안 `can_use()` false(`_running`)
  - 창문 `maps/BarracksWindows.gd`(배경 Sprite2D의 자식 — 좌표 = 배경 그림 픽셀): 그림 속 창문 두 개 자리(`window_rects`)에 `창문.webp`를 꼭 맞게(가로세로 따로) 덮고, 유리 칸마다 `창문 배경.webp`를 `region_rect`로 잘라 parallax 0.75로 밀림(칸 밖으로 안 삐져나옴). 배경·창문 그림을 바꾸면 `window_rects`·`window_frame`·`window_panes` 재측정
  - 앞 층 `maps/BarracksForeground.gd`: 침대·관물대 뒷모습 두 쌍, parallax 1.3 + `foreground_blur` + 어둡게, 위아래는 매 프레임 **카메라 화면 바닥 기준**(`*_show` ≈ 1/3), 캐릭터가 뒤면 반투명, z 60
  - 진입 동안 둘 다 무적·busy. 쓴 순간~복귀까지 **상대 궁극기 봉인**
  - 내무반 동안 눈에서 **빨간 빛**: 리그 `Head/EyeGlow`(`characters/EyeGlow.gd`, @tool, 색은 `HwanggeunchulRig.tscn`에서 덮어씀, 인스펙터 `preview`)
  - **내무반 동안 스킬2 = `BarracksSlamSkill`**(씬 노드 `BarracksSkill2`, `_swap_skill_2()`가 끼우고 나올 때 `abort()` 후 복구, 들어갈 때 쿨 0, 쿨 15): 500px 순간 돌진(잔상·바람, 지나간 구간으로 판정, 헛방 경직 없음) → 방어 풀고 잡아 두 손 번쩍(`set_lift_pose`, 상대 `is_grabbed`로 250px 위로, 8뎀) → 상대 위 100px로 순간이동 → 내려찍기(`set_stomp_pose`, 22뎀) → 땅에 꽂히는 순간 `launch_finisher`(드롭킥의 높이·체공 2배). 화면 슬로모션: 들어 올리는 동안 `lift_time_scale` 0.45, 내려찍은 뒤 땅에 꽂힐 때까지 `stomp_time_scale` 0.25(`_set_slow`/`_clear_slow`, 이미 0.5 밑이면 안 건드림, `_exit_tree`에서 복구)

### 금쪽이

- 자전거 `DashSkill`: 속도 = 이동속도 x `dash_speed_multiplier`. 상대를 들이받아도 자기 피해 없음(벽 자해는 있음)
  - 들이받으면 `combat/BikeWreck.gd`: 조각 하나만 튀어 남고 나머지는 `break_bike()`. 조각 그림은 원본 `자전거.png`와 **같은 캔버스**(자전거 그림을 바꾸면 조각도 다시)
- 비비탄 `BBGunSkill`: 꺼내기(`draw_time`, 0 금지) → 쏘기 → 넣기. `play_gun_motion(전체, 꺼내는, 넣는)`
- 막대사탕: `HandRHold/Candy` rotation 45도 + 후리기 45도가 한 쌍, `attack_raise_deg` 음수, 사탕 z_index 없음

### 악플러

- `RageBuffSkill`: 콤보 매 타 +`bonus_damage` + 붉은 색조 + 액션 얼굴(전용 머리 돌리기 세트) + `play_head_shake()`
- `MouseGrab.gd`: 한 장 그림을 `region_rect`로 유선/물체 잘라 그림(**그림을 다시 그리면 영역·중심선 상수 재측정**). **실효 사거리는 중력이 정함 — 속도를 바꾸면 중력은 배수의 제곱으로**. 크기 값은 `new()` 후 `setup()` 전에. `cast_windup_offset.y`는 -6보다 위로 금지
- 키보드 z_index 1(2 이상이면 대시 잔상 키보드가 본체 앞에). 두 손 잡기: 총 회전각 120도 이하, `attack_grip_speed` 9 이상

### 주정뱅이

- 술 스택(최대 3). 토 기둥 `VomitBeam`(Hitbox 상속, **맵에 붙여 입 위치에**), 길이·두께가 스택 비례, 벽에 막히면 `region_rect`를 자름
  - 그림 `sprite/주정뱅이/토사물모음/` — **파일 1~4 = 스택 0~3, 3스택은 `4스택진짜.png`**. 새 그림이면 `stack_body_rects` 재측정. 안 보이면 파싱 오류부터
- 괴성 `ScreamConeUltimate` + `ScreamCone.tscn`: **데미지·입 위치·디버프는 캐릭터 씬 `SkillUltimate`, 범위·각도·연출은 `ScreamCone.tscn` — 한 값은 한 곳에만**
- 술병: 3타에만 술방울, **8타 맞히면 병이 깨짐**(`swap_held_texture()` — 두 그림 캔버스 같아야 함). 술병 제자리 값·`drink_hand_deg` 0은 **건드리지 말 것**
- 토·술 머금은 얼굴 배율은 평소 머리와 높이를 맞춘 값(그림 바꾸면 재측정)
- 스킬 범위 미리보기 `characters/SkillRangePreview.gd`(@tool): 홀더를 옮기면 **`Apply Holders To Skill`** 후 저장. 미리보기와 게임 식은 같이 고칠 것

### 지하철 아저씨

- 평타: 두 손 찌르기 / 발차기 / 한 바퀴 돌며 베기(`spin_duration` 0.5 → 판정 ≈ 0.223 — **회전 값을 바꾸면 `finisher_windup`과 같이**)
- **카운터 `CounterSkill`**: 자세 중 상대 공격(맵 피해 제외)을 맞으면 반격, 헛방이면 `whiff_lag`. **자세 중 idle 몸짓 금지**
  - 반격: 슬로(`Timers.after(..., real_time = true)`, `_exit_tree()`에서 복구) → 등 뒤 순간이동 → 베기 → `launch_finisher`. **필중** — 맞을 때까지 둘 다 묶음(`_lock`/`_unlock`), 신호가 안 오면 허트박스에 직접 `_try_hit`. 명중 신호에서 먼저 풀어야 `launch_finisher`가 안 막힘
  - 가로채는 곳 둘 다 `Fighter.try_counter()`: `Hurtbox.take_hit()` / `take_damage()`(넉백 있는 피해만). 등록 슬롯 `counter_stance`
- 개찰구 `Turnstile.gd`: 그림 한 장을 반으로 잘라 둘에. **`visual_scale`과 `TurnstileSkill.spacing`은 같이(spacing = 817 x 배율)**. `CABINET_X`/`BOTTOM_Y`는 그림 바꾸면 재측정
- **궁 `DualInstrumentUltimate`**(쌍 악기): 15초 동안 왼손 리코더, 기본공격 x1.5. 대시 = 뒤로 물러났다 내지르는 돌진(`dash_override` → `take_over_dash()`, `_process`에서 보면 한 프레임 늦어 튐)
  - 돌진 판정은 `sense_only`로 X자 자국(`combat/SlashMark.tscn`, **맞은 몸의 자식**, z 62)만 새기고 끝나면 터지며 `burst_damage`. 방어·무적이면 자국 없음(`connected`는 막힌 타에도 뜸)
  - 폭발 판정 = 돌진 판정 복제 — ⚠️ `DUPLICATE_SCRIPTS | DUPLICATE_GROUPS`, ⚠️ 복제본 `sense_only` 끌 것, 한 프레임만 켜면 겹침 누락 → `burst_hitbox_time`. 트리에서 빠질 땐 터뜨리지 말고 지움
  - 리그 `HandLHold`(왼손 물건걸이, `held_item_l_armed`). `_pose_dual()`은 **`_pose_guard`보다 먼저**. 쌍 악기 동안 두 악기·왼손 z를 머리 앞으로. 단소 세계각 = 손 각도 - 53.4

### 일진

- 평소 가방 `HandL/BagIdle`, 3타에만 `HandRHold/Bag`. 담배 연기(입 앞) / 어깨치기(같은 `launch_speed`로 뜨고 상대만 기절, 가드면 안 뜸)
- ⚠️ **액션 표정 슬롯은 하나** — 표정 쓰는 스킬은 자기 얼굴을 직접 지정
- **궁 `IljinCrewUltimate`**(등장까지만, TODO 공격·버프·퇴장): 친구·여자친구가 화면 기준 고정 위치에
  - 패거리 `IljinCrewMember`(CharacterBody2D) — **Fighter로 만들면 안 됨**. 캐릭터와 몸 충돌 끄고 가로로만 밀어냄. 부른 일진 공격엔 `immune_source`로 면역
  - 친구 침(`Spit.tscn`): `aim()`은 `setup()` 다음, 빠른 투사체는 판정을 진행 방향으로 늘림(도형은 새로 만들어 — sub_resource 공유). 여자친구: 넉백 맞으면 `knockback_stun`

### 헬스장 빌런 / 고양이 아주머니 / 층간소음

- `DunkUltimate`: 상대 쪽 도약 후 착지 범위 공격. `AoeAttack`: 자신 중심 원형 + 둔화

### 주인공(경찰) — 훈련장 전용

- **`PoliceRig.tscn`이 정본**. 표시 이름 "주인공"은 `TRAINING_ONLY_CHARACTERS`·`CHARACTER_COLORS` 키·`PoliceStats.tres` 세 곳 일치
- 테이저건: 맞으면 2초 기절 — **기절은 스킬이 `connected` 신호로 건다**, 막히면 없음
- 맨손/경봉(`weapon_switch` + `held_item_armed`): 경봉 중 데미지 x2(`set_modifier`, `_exit_tree()`에서도 해제). 무기 숨기기는 던지기 처리보다 **뒤에**. 맨손 `jab_reach_x`는 도달 x **절대값**
- **경봉 평타 "개 패듯이"**(`armed_flurry_enabled`, 경찰만): 내려찍기 → 올려베기 + 띄우기 → 맞으면 3초 동안 누르는 족족 부채꼴 판정
  - ⚠️ 판정 껐다 켜기 재타격은 이 간격에선 안 됨 → `repeat_interval` 9999 + 누를 때마다 `clear_repeat_state()`. ⚠️ `_hold_in_flurry()`가 끌어당김(띄우기를 올리면 `armed_flurry_hold_y`·`armed_flurry_origin`도). 난무 중엔 `start_busy` 금지
  - 모션 `BodyRig.SLASHES` 표 + `play_weapon_slash()`. 경봉 그림은 손에서 -38도 → 손 각도 = 원하는 각도 + 38. 1·2타 `BluntImpact` + 그 두 타에만 히트스톱

## 몸(BodyRig) — `characters/BodyRig.tscn`/`.gd`

머리/몸/손/발 Sprite2D 조립 공용 몸, 캐릭터 씬 `Visual` 자리(이름이 `Visual`이어야 함). 코드로 걷기. 왼쪽 = `scale.x` 부호만 뒤집음. 제자리 값은 `_ready()`에서 기억.

- 파일: 공용 `sprite/body/`, 전용 `sprite/<캐릭터>/몸/`(층간소음·캣맘·지하철은 폴더 바로 아래 `발.png`/`손.png`도)
- 캐릭터별 머리는 `BodyRig.tscn` 씬 상속. 조각 위치는 **`BodyRig.tscn`을 직접** 열어 옮길 것
- **새 리그 배율은 눈대중 금지** — 실제 영역을 재서 역산(position = 목표중심 - (bbox중심 - 캔버스중심) x 배율)
- **손에 드는 무기는 `HandRHold`의 자식**(배율 1, 오프셋은 그림 반길이보다 작게). `HandR`·`HandRHold`는 형제라 `modulate`를 둘 다
- 자세는 `_xxx_target`/`_xxx_blend` + `set_xxx(on)` + `_pose_xxx()` 꼴(무릎 꿇기·두 손 번쩍·내려찍기 등). **로컬 좌표로 돌리는 자세엔 facing 부호를 곱하지 말 것.** 새 자세는 `_face_turn_blocked()`·대치 자세 조건에도 넣을 것
- 손에 든 물건 각도 고정(`attack_hold_deg`)은 되돌린 것 — 다시 건드리지 말 것
- **머리 돌리기 그림**: `head_turn_textures`(측면1→…→정면) + `head_turn_anchors`(**머리 공의 중심x·중심y·지름**) + `head_turn_faces_left`. 방향 전환 시 고개 먼저, 공격·스킬·방어·피격이 시작되면 즉시 끝냄
  - 앵커 재는 법: 알파 1/4 축소 → bbox 높이 22% 정사각형 열림 연산 → 무게중심·`2sqrt(넓이/pi)`. 프로펠러·턱 말고 머리 공만
  - 액션 표정 전용 세트 `action_head_turn_*`(비우면 액션 표정 중엔 안 돎)
  - 몸통 돌리기 `body_turn_textures`: 도는 도중에만. 영역은 `_opaque_rect_of()`(알파 절반 이상 — `get_used_rect()`는 알파 1짜리 점에도 늘어남)
  - 파일명 오타 그대로: `축법소년 픅면 2.png`, `금쪾이 몸 측면3.png`, `주정뱅잉 측면2.png`, `지하철 아저 씨측면 1.png`. ⚠️ **머리/몸통 파일명이 비슷하니 덮어쓰기 전 내용을 볼 것**(주정뱅이 머리가 몸통으로 덮인 적 있음)
- **표정 우선순위**: 피격 > 토하기 / 액션 > 취함 > 지침 > 맨정신(`_apply_base_head()`). `_update_hp_face()`는 `take_damage`/`heal`/`ring_out` 세 군데
- 눈 생동감(`Head`의 자식, 머리 그림 픽셀 좌표, 기본 얼굴일 때만): 깜빡임 `EyeBlink.gd`, 렌즈 반짝임 `LensGlint.gd`, 소용돌이 `SwirlEye.gd`, 눈빛 `EyeGlow.gd`. 특수 idle `idle_special`(안경 올리기·딸꾹질)
- **파일은 Godot 파일시스템 창에서 옮길 것**(탐색기로 옮기면 uid·참조 깨짐). 원본이 `.godot/imported/*.ctex`에만 있으면 offset 56부터 WebP로 추출

### 그림 파일 교체 시

- 에디터 밖에서 덮어쓰면 재임포트 안 됨 → `.import` 삭제 후 `godot --headless --editor --path <프로젝트> --quit`
- 배율은 보이는 영역 x scale이 예전과 같게, `centered`면 중심 차이만큼 position 보정
- 흰 배경 제거는 **테두리 flood fill**. 파츠는 알파 있는 PNG로 달라고 할 것
- "안 보인다"의 첫 원인은 지워진 파일을 가리키는 `ext_resource`. 경로를 바꿀 땐 낡은 `uid=`도 지우거나 `.import`의 uid로
- 그림 구석에 딴 게 묻어 있는지, 썸네일 가장자리 한 줄이 흰색인지 확인

## 조작 / AI

- 기본 배치 — P1: A/D · 점프 W · 방어 S · 기본공격 F · 스킬1 G · 스킬2 H · 궁 R · 맵 스킬 E / P2: ←/→ · ↑ · ↓ · L · ; · ' · ] · [. 대시 = 이동키 두 번, 발판 내려가기 = 아래 누른 채 점프
  - ⚠️ **기본 배치를 바꾸면 `GameState.KEYBIND_VERSION`을 올릴 것**
- `controllers/PlayerController.gd`(`player_index` 1/2). Fighter는 사람/AI 구분 없음
- ⚠️ `move()`/`dash()`가 `facing`도 바꿈 → 후퇴·뒤로 대시 직후 되돌릴 것(스킬은 `after_physics`에서 매 프레임 되돌림)
- **`controllers/AIController.gd`**: 기믹 피하기 → 상대 공격 읽기 → 왕관 → 발판 길찾기 → 거리 싸움 → 스킬
  - **`_want_skill()`이 스킬 스크립트 이름별로 판단 — 새 스킬을 만들면 여기에 한 줄 추가**. 스킬에 `ai_wants_use(fighter, target)`가 있으면 그걸 씀
  - 발판 길찾기: StaticBody2D 직사각형 충돌을 1초마다 모아 그래프. **스프링 좌석 위에선 점프 안 누름**. 발 높이 방해물 `"ai_jump_over"` 그룹, 위험 기믹 `"ai_danger_zone"` → `"ai_safe_spot"`
  - 스토리 AI(`ClaudeAIController`) `knows_follow_ups = false`(한 대씩만). `showcase`(타이틀 전용)

## 맵

- 새 맵 필수: 바닥·벽(또는 링아웃 공간)·`PlayerSpawn1/2`·`Camera2D`(`maps/CameraRig.gd`)·`CombatHUD`. 목록 `GameState.MAPS`
- **`Deco`로 시작하는 노드 = 맵 선택 미리보기에서 제외**
- `CameraRig`: `add_trauma()` 순간 충격, `set_rumble()` 지속 진동. `_apply_wall_limits()`가 벽 폭으로 최소 줌 강제. `view_scale`/`zoom_boost`는 타이틀용 static
- 배경이 지글거리면 `.import`의 `mipmaps/generate=true` + 씬 루트 `texture_filter = 4` 둘 다
- `maps/ParallaxFollow.gd`(`factor` < 1 먼 층, > 1 앞 층). 앞 층 흐림은 `maps/foreground_blur.gdshader`, 먼 층은 `far_blur.gdshader`
- 맵 전용 스킬 `Stage.map_skill_scene`(클래시 안 탐): `GroundPoundSkill`(지상이면 쿨 환불, 발판 `break_platform()`), `WorkoutSkill`

### 놀이터 `maps/Playground.tscn` — 왕관 훔쳐서 달아나기

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

### 헬스장 `maps/Gym.tscn` — 운동할지 방해할지

- 2층 발판 + 기구 셋(바벨 컬 = 기본공격력 / 스쿼트 랙 = 점프력 / 런닝머신 = 이동속도). 맵 스킬 `WorkoutSkill`: 운동 중 발 묶임, 맞음·때림·멀어짐 등이면 끊김, 스펙은 쌓는 족족 배수(`custom_data["gym_spec"]`)
- 공격력은 기본공격에만(`compute_basic_damage()`). `GymLayout.gd`는 자식 `_ready()`가 부모보다 먼저라는 것에 기대 스폰을 옮김. `muscle_arm`/`muscle_leg`
- 땅 y=280, 2층 y=100(이단 점프 한계 180px), 벽 ±604. TODO: 운동 모션·기구 그림·배경

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
- 장면은 `CharacterStats.ultimate_cutin_scene`, 파츠 흔들기 `ui/cutin/CutInAnimation.gd`. 있는 캐릭터: 주정뱅이·금쪽이·악플러·일진·경찰·지하철. **캐릭터를 움직여 넣을 땐 리그(`<캐릭터>Rig.tscn`)를 쓸 것**
- 지하철 컷인: ⚠️ `Metro!.png` 무늬가 기울어 칸마다 `rotation = -0.0158` + `skew = 0.0158`(그림 바꾸면 재측정), 이동은 x만. 칸 수·틈을 바꾸면 `train_from_x`/`train_to_x`도. 선글라스 반짝은 `LensGlint.always_show`
- 금쪽이 컷인: 원래 머리 복원 → `set_action_face(true)` 순서. 경찰: 얼굴 두 장 크기·위치 같아야 함

### 스토리 모드

- 난이도는 에피소드마다 `StoryFadeScene`의 `battle_enemy_hp_scale`/`battle_enemy_damage_scale`/`battle_ai_skill` → `Stage._apply_story_handicap()`(⚠️ `stats`는 공유 Resource라 **`duplicate()` 후, `add_child` 전에**) / `_tune_story_ai()`
- 에피소드 `GameState.STORY_EPISODES`, 클리어 기록은 `clears_story` 켠 장면의 `_ready()`
- 장면 `ui/story/StoryScene1~11.tscn`, 전부 `StoryFadeScene.gd`. `Fade`는 맨 마지막 자식·알파 0, 장면 루트·대화창 `mouse_filter = 2`. 전환 BLACK/CROSSFADE
  - **스토리→대전:** `battle_*` → `_setup_battle()`(**GameState에 담는 코드는 여기에** — S 건너뛰기가 `_open_next()`를 우회). (임시) `S` 건너뛰기는 방어키와 겹침 → 방어 테스트 땐 `debug_story_skip_key` 끔
- 대화창 `ui/story/DialogueBox.tscn`: `이름|대사`, 명령 줄 `@show/@hide/@enter/@exit/@close/@waitkey/@pause/@stamp`
- **3번·11번 장면은 도장만 다른 같은 구조 — 새 사건은 복사해 문구·도장만 교체**. PSD를 고치면 PNG로도. 게임 글자는 "비비탄"으로 통일

## 튜토리얼 `maps/Tutorial.tscn`(뼈대)

- 배경 `sprite/맵/튜토리얼/`(하늘·구름 `RandomCloudSpawner.gd`·산·숲·막사·국기 `FlagFlutter.gdshader`). 땅 ⚠️ `texture_repeat`는 위아래로도 반복 → `region_rect`를 투명한 윗부분 아래부터. 바닥 y=280, 벽 ±1200
- 훈련 더미를 P1이 조작. **교관 = 황근출(옷 입은 리그만, Fighter 아님)** `Instructor`(scale.x -1)
- **처음 켠 사람만** 타이틀 → 튜토리얼(`GameState.tutorial_seen`). 메뉴 훈련장 버튼 = 훈련장 / 튜토리얼 다시
- 말풍선 `maps/SpeechBubble.gd`(@tool, 전부 `_draw()`): **원점 = 꼬리 끝 = 가리키는 곳**. 교관 자식으로 붙이면 글자가 뒤집혀 맵 직속. `say(text, hint)`(BBCode 가능), `finish_typing()`, `close()`. 폰트 강한육군 Bold — **모든 `*_font_size` 슬롯 지정**(빼면 `[b]`가 16px). ⚠️ "썌"는 글리프 없음 → "쌔"
- 대사 `Tutorial.gd`: 교관 500px 안에 들면 시작, **스페이스로 한 줄씩**(행동 판정 아님), 강조 `_em()` = 빨간 굵게. 대사 중엔 카메라를 교관 ±450px로 clamp. TODO: 이동·점프 다음 조작 설명

## 훈련장 `maps/TrainingGround.tscn`

- 물리값·게임 속도 슬라이더(static var — 영구 반영은 `DEFAULT_*`), 모든 스킬 쿨 0. `Engine.time_scale`은 `_exit_tree`에서 복구. 충돌 보기 `CollisionDebugView.gd`, 바닥 눈금자 `FloorRuler.gd`

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

- 기획 오픈 이슈는 아티팩트 문서 "다음에 정할 것" 표. 확정 전엔 임시값 + TODO
- **엔진은 4.7.2로 통일**(`config/features` = "4.7"). `invalid UID` 경고는 씬 uid를 `.import`의 uid로
- **코드 수정 후 헤드리스 에러 확인은 안 한다(사용자 요청)** — "실행해서 확인해줘"일 때만
- Godot 실행 파일은 PC마다 다름 — `Godot*4.7*win64*console*.exe` 검색, PowerShell에선 `& "<경로>" ...`
- 헤드리스 테스트: `--editor --quit-after`로는 파싱 에러를 다 못 잡음 → 쓰이는 씬을 띄울 것. `extends SceneTree` + `--script` 금지(오토로드 미초기화) → `extends Node` 임시 `.tscn`에서 `add_child(load(맵).instantiate())`. 새 `class_name` 직후 `--headless --editor --quit-after 20`. 시간 기반은 `--fixed-fps 60`. 테스트에서 `apply_physics()`를 또 부르면 경직이 두 배로 닳음, 순간이동 직후 착지 랙(60프레임 대기), 스킬은 클래시 대기창 뒤에 나감
