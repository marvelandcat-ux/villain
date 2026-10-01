# 트러블 메이커 (villain) — Godot 프로젝트 규칙

사이드뷰 대전 격투 게임 **"트러블 메이커"**(리포·폴더 `villain`, 빌드 `build/TroubleMaker/`). 기획 문서: https://claude.ai/code/artifact/661e48af-d8db-49c9-bc68-a9294790becb
전역 규칙(한국어 응답, 초보자 눈높이, 안전 규칙) 유지, 코드 스타일은 이 문서 우선 — **Godot/GDScript**(전역 CLAUDE.md의 Unity/C# 규칙 아님).

> 이 문서는 2026-10-01에 압축했다. 값의 변경 이력·옛 실측값·시뮬레이션 숫자는 뺐다 — 필요하면 git 이력(이 날짜 이전 `CLAUDE.md`).

## 프로젝트 정보

- 엔진 Godot 4.7.2(아래 "참고" 버전 규칙), Forward Plus, 3D 물리 Jolt(기본값 — 게임은 2D)
- 장르: 사이드뷰 대전 격투, 바운스어택류(넉백을 다시 잡아채는) 콤보 중심. 히트스턴 최소화, 지형·벽 기믹

## 핵심 아키텍처

**캐릭터 전용 `.gd`는 만들지 않는다** — 모든 캐릭터 씬 루트가 `characters/Fighter.gd`, 차이는 스탯(`.tres`) + 스킬 노드 조합뿐.

- `Fighter.gd`(`CharacterBody2D`): 이동/점프/중력, HP(`take_damage`/`heal`/`health_changed`), 스킬 슬롯(자식 `Skill1`/`Skill2`/`SkillUltimate`/`BasicAttack` 자동 연결), 자유 데이터 `custom_data`
- **버프·디버프는 직접 대입 금지** → `set_modifier(property, id, value)`/`clear_modifier(property, id)`(id별로 저장 후 곱함). 임시 효과 `apply_temp_multiplier(property, value, duration)`. `set()` 덮어쓰기는 겹친 디버프를 지운다
- 색조도 같은 방식: `set_tint(id, color, duration)`/`clear_tint(id)`. 피격 번쩍임 뒤엔 걸린 색조로 돌아감
- **캐릭터끼리 몸 충돌 없음**: `_ignore_other_fighters()`가 양방향 `add_collision_exception_with`. 레이어는 바닥·벽까지 영향이라 안 건드림. Area2D 판정은 그대로
- **공용 정적 헬퍼 — 다시 짜지 말 것:**
  - `combat/PhysicsQuery.gd`: `raycast_ignoring_fighters(ctx, from, to)` / `ground_y_below(ctx, from, probe, fallback_y)`
  - `Timers.gd`(루트): `after(owner, delay, cb)`(실제 시간 옵션 `real_time` 있음) / `self_destruct(target, lifetime)` — owner 자식 Timer로 예약
  - `Fighter.find_fighter_in_box(fighter, range_x, range_y, direction, back_tolerance := 20.0)`
  - `CrashBurst.spawn(parent, pos)`. 색·조각 수를 바꾸려면 `CrashBurst.new()` 후 **add_child 전에** 값을 채울 것
- `skills/Skill.gd`(`Node`): 쿨·`can_use()`/`use(fighter)`. 새 스킬은 상속 후 `_execute(fighter)`만 오버라이드
  - **궁극기는 라운드 시작 시 쿨을 물고 시작**(`start_on_cooldown`, 전 캐릭터 `SkillUltimate`). 라운드마다 `reload_current_scene()`이라 게임/라운드 구분 불필요(승수만 `GameState`)
  - `_ready()`를 오버라이드하는 스킬은 반드시 `super()`
  - 궁 쿨은 컷인이 끝난 뒤(`fire_ultimate_now()`)부터 돈다
  - **쿨은 전부 `effective_cooldown()`을 거칠 것**(`cooldown_override` > 0이면 그 값, x `attack_speed_multiplier`, x `GameState.cooldown_multiplier`). 사용처: `Skill.use()`/`cancel_use()`, `ComboMeleeAttack._resolve()`/`_effective_miss_cooldown()`, HUD `SkillCooldownIcon`, `LivingShadowSkill.use()`. `cooldown`을 직접 읽는 경로를 새로 만들면 그 경로만 배율이 안 먹는다
- **⚠️ 스킬에서 `Visual.scale`을 직접 트윈 금지 → `BodyRig.play_squash(배율)`**(리그는 왼쪽일 때 `scale.x` 음수라 양수 트윈하면 뒤집힘). 자기 자식 스프라이트 트윈은 무관
- `combat/Hitbox.gd`/`Hurtbox.gd`: Hurtbox(Fighter 자식 Area2D)가 피격 시 `take_damage()`, Hitbox는 겹치면 데미지(자기 자신 무시)
  - **허트박스는 머리 꼭대기까지**: 캐릭터 씬의 `HurtboxCollision`이 별도 `CapsuleShape2D_hurt`, 발끝 +30 고정·윗끝 = 머리 그림 꼭대기(높이 = 30 - 꼭대기, `position.y` = (30 + 꼭대기)/2; 금쪽이는 프로펠러 빼고). **머리 그림을 바꾸면 다시 잴 것.** 몸 충돌 캡슐은 그대로
  - `Hitbox.source_fighter`는 setter + `_has_source`로 주인 유무를 따로 기억(해제된 객체는 `== null`이 true라서). 주인 없는 히트박스(열차)도 동작해야 하므로 `is_instance_valid`만으로 막지 말 것
  - `Hitbox.pull_to_source`/`pull_strength`: 공격자 쪽으로 끌어당김(`VacuumSkill`)
  - `repeat_interval` > 0이면 겹친 동안 재타격(열차·담배 연기). 판정 껐다 켤 때 `clear_repeat_state()`
  - `hit_spark`로 히트박스별 스파크 끄기(지금 금쪽이 기본공격만 끔). `debris_enabled`/`debris_scene`(주정뱅이 술방울)
- **맵 피해는 `Fighter.take_map_damage()` 한 곳으로**. 분기는 `Hurtbox.take_hit()`(`source_fighter` 있으면 `take_damage()`, 없으면 `take_map_damage()`). 맵 피해는 방어를 깬다. `take_damage()`의 `ignore_guard`를 밖에서 true로 주지 말 것
- ⚠️ `take_damage`는 넉백을 기존 속도에 **더한다** → 정확한 속도가 필요하면 받은 뒤 `velocity`를 덮어쓸 것
- 이동을 가로채는 스킬: `Fighter.movement_override`에 자신 등록 + `get_move_velocity_x()`/`after_physics(fighter, delta)`(`DashSkill.gd`). 대시 속도보다 override가 이김
- `Fighter.is_feared`/`apply_fear(duration)`: 이동만 되고 공격·스킬 무시(지금 쓰는 캐릭터 없음)
- **슈퍼아머** `add_super_armor()`/`remove_super_armor()`/`has_super_armor()` — **개수로 셈, add/remove 짝 필수**. HP·반짝임·콤보 수·`damaged`는 들어가고 넉백·경직·구르기·잡기·기절 별은 막힘. 위로 띄우는 속도는 `apply_physics`가 자름. `blocks_debuff()`에 섞지 말 것. 사용처 `BackSuplexSkill.super_armor`
- `Hurtbox.fighter`는 `Node` 타입 — 받는 쪽은 `area.fighter as Fighter`로 확인. HP 있는 오브젝트는 `take_damage()`/`take_map_damage()`/`is_guarding`만 있으면 됨

### 함정 모음 (실제로 겪음)

- **Lambda capture:** `create_timer(t).timeout.connect(func(): 노드.x = ...)`는 노드가 먼저 사라지면 에러 → **그 노드의 자식 `Timer`로 예약**(`Timers.after`, `Fighter._after`). 짧은 `await create_timer().timeout` 한 번은 괜찮음
- **`Skill`은 `Node`라 좌표가 없다** → Skill 자식 Hitbox는 `hitbox.global_position = fighter.global_position + Vector2(range * fighter.facing, 0)`. 맵에 직접 붙이는 투사체는 무관
- **add_child 함정:** `add_child()`는 `_ready()`를 즉시 실행 — 그 뒤에 넣은 export는 `_ready()`에 안 보인다. 첫 `_physics_process`/`_process`(`_initialized`)로 미루거나 add_child 전에 대입. `Projectile` 수명 타이머는 그래서 `setup()`에서 시작
- **해제된 객체는 `== null`이 true** → `x != null and not is_instance_valid(x)`는 절대 참이 안 됨. 따로 불리언으로 기억할 것
- `Projectile`은 `source_fighter`의 Hurtbox/몸을 무시해야 함(판정을 키우거나 느리게 만들 때 재발 주의)
- **⚠️ `_draw()`에서 0이 될 수 있는 모양은 `draw_colored_polygon` 말고 `draw_primitive`로 조각내 그릴 것** — "triangulation failed"가 매 프레임 쏟아진다. 이 오류는 `--headless`에선 안 보임
- 그림/스크립트가 안 보이면 **Output 패널 파싱 에러부터**(스크립트가 떨어진 씬은 다른 `@tool`에서 placeholder 에러가 줄줄이)
- 새 `class_name`을 preload 타입으로 바로 붙이면 캐시 전 파싱 에러 → 무타입 + `preload`(`Fighter._shield`, `ChargeWind`, `CooldownPies` 등)
- Area2D 맵 기믹에서 `gravity`·`priority`·`monitoring`·`linear_damp`·`angular_damp` 변수명 금지(내장 프로퍼티)
- `.tscn`은 모든 노드 뒤에 `[connection]`. 노드를 손으로 끼울 땐 부모 속성 줄 **다음**에(헤더 바로 뒤면 부모 `position`이 딸려감)
- CollisionShape2D는 물리 바디의 **직계 자식**만 등록됨
- 씬 첫 프레임 delta가 크게 튐 — 시간 누적 연출엔 `minf(delta, 0.05)`
- 전체 화면 배경 Control은 클릭을 삼킨다 → 배경엔 `mouse_filter = 2`
- `set_input_as_handled()`는 `change_scene_to_file()` / 자기 `queue_free()` **전에**(후엔 `get_viewport()` null)
- GitHub Desktop이 브랜치 이동 시 작업을 stash에 치운 적 있음 — 뭔가 사라지면 `git stash list`부터
- PowerShell: 변수 이름 대소문자 무시(`$h` == `$H`)

## 전투 시스템

### 기본공격 `skills/ComboMeleeAttack.gd`(`MeleeAttack` 상속) — 전 캐릭터 3타 콤보

- `MeleeAttack.gd`: 캐릭터 앞 히트박스 on/off. 판정은 캐릭터 앞 40px의 30x30 상자
- 히트 확인식: 헛치면 예약 입력 버림 + `miss_cooldown` + 1타 리셋, 3타 성공 시 `cooldown`. 타별 값은 `combo_damage`/`combo_knockback` 배열(`damage`는 안 씀)
- **브롤할라식 `combat/AttackData.gd`**: `hits`에 .tres를 순서대로(길이 = 타 수, 마지막 = 마무리). 지금 금쪽이만, 비면 옛 배열. 판정 시각은 `BodyRig.strike_time(모션 길이, 회전)`이 계산(보통 40%, 회전은 `spin_end x spin_strike`)
- windup 0이면 `_fire()`가 물리 프레임 **두 번** 대기(한 번이면 area_entered가 안 남). **`attack_duration`을 바꾸면 `windup`(= duration x 0.4)도 맞출 것**
- **📌 3타 준비시간은 0.223초 고정(새 캐릭터도).** 옛 배열 캐릭터는 `finisher_windup` = 0.223이면 `_final_swing_duration()`이 3타 모션을 자동으로 늘림. 회전 타·발차기 타는 리그 `spin_duration`/`kick_duration`으로 맞출 것
- **확정 콤보:** `link_stun_margin` — 1·2타 명중 시 경직을 "다음 타 예비동작 + margin"으로 보장(`_hold_for_next_hit`). 1·2타 명중 시 상대 가로 속도를 지우고 이번 넉백만. 판정은 켜진 동안 캐릭터를 따라감. **넉백을 키우면 파고들기(`combo_lunge`)도 같이**
  - `combo_lunge`: `movement_override`로 예비동작 동안 이동, 판정은 도착 자리 기준. 데미지 비례 푸시백(`pushback_base`/`pushback_per_damage`)은 `v = sqrt(2 x HITSTUN_FRICTION x 거리)`로 역산. `lunge_follows_pushback`. "발 먼저" `lunge_time`/`lunge_foot_lead` + `BodyRig.play_lunge_step`
  - 공중에서 경직이 풀릴 때 가로 속도 유지 = `Fighter._launch_momentum`
- 드롭킥(`dropkick_finisher`)·발차기 코드는 공용에 남아 있음
- 회전 타격 `BodyRig.spin_hit_index`(-1 = 안 돔)/`spin_*`: 루트 `scale.x`에 cos를 곱함. ⚠️ 곱하기 전 값을 다음 프레임 `_apply_pose` 첫머리에서 되돌릴 것, 최소 0.04
- **그랩 후 회전 난무**(`spin_flurry_*`, 악플러): 판정은 바라보는 쪽 반원(돌아서면 `_apply_spin_shape()`가 갈아끼움). 도는 동안 `spin_wind`가 `JumpWind`를 접선 방향으로 뿌림 — 굵기 `spin_wind_width` 2.5 / `spin_wind_outline_px` 0.7(사용자 요청 "엄청 얇게"). `bonus_damage`는 안 붙음

### 3타(마무리) 날아가기 — `Fighter`의 `FINISHER_*` 상수

- 마무리 타: 가로 넉백 x `finisher_distance_scale`(1.25 — **속도 배수라 거리는 대략 제곱으로 늘어남**). `finisher_trail`이면 `_launch_finisher()`가 경직 설정과 상관없이(early return **앞**) `combat/LaunchTrail.gd`(충격 섬광·바람 줄기·C자 먼지)를 붙인다. 막힌 타엔 없음
- 발사: 속도 크기 = `speed x 1.15 x 체력 배율`, **`FINISHER_LAUNCH_ANGLE_DEG`(45도) 위로**, 최고 높이 `FINISHER_PEAK_PER_SCALE` x 체력 배율로 자름(`_finisher_up_cap`). 옆 속도만 `FINISHER_HORIZONTAL_SCALE`(1.3)배
- 날아가는 동안: 중력 `FINISHER_GRAVITY_SCALE`(0.45), 공중 옆 속도는 **비율로** 감속 `FINISHER_AIR_DRAG_RATE`(일정량이면 직각 포물선이 됨)
- **`FINISHER_TIME_SCALE`(1.5)**: 궤적은 그대로 시간만 줄임 — 속도 x배율, 중력·감속·마찰 x배율², 튕김 기준 속도 x배율, 안전 한도 /배율. **다른 `FINISHER_*`는 배율 1 기준 값**
- **기절 = 완전히 멈출 때까지**(`_finisher_flying`, `_update_finisher_flight()`가 `move_and_slide()` 직후 경직·구르기·기절 별을 붙잡음). 멈추면 `_end_finisher_flight()`. 안전 한도 `FINISHER_MAX_FLY_TIME`, 잡히거나 슈퍼아머면 즉시 끝
- **벽 튕김** `_try_finisher_wall_bounce()`: 부딪힌 가로 속도 x `FINISHER_WALL_BOUNCE`(1.0)로 반대로, **위아래 속도는 그대로**. 속도는 `move_and_slide()` **전에** 기억(`pre_vx`). `FINISHER_WALL_MIN_SPEED` 미만이면 안 튕김. `CrashBurst` + 흔들림, 추가 데미지 없음
- **땅 튕김**: 낙하 속도 x `FINISHER_GROUND_BOUNCE`(0.58 = 튕길 때마다 높이 1/3). 첫 착지는 옆 속도와 무관하게 튕기고(`_finisher_ground_bounces`) 옆 속도를 `_away_from_opponent()` x `_finisher_launch_vx` x `FINISHER_GROUND_KICK`(0.6)으로 덮어씀(제자리 통통 → 추가타 쉬움 방지). **두 번째부턴 안 민다**(영영 안 멈춤). 튕겨 떠오르는 순간은 구르기 착지로 안 침
- **날아가는 중 추가타**: `_rebound_finisher(hit_dir, vy_before)` — 옆 속도·기절 연장만, 위아래 속도는 맞기 전 값으로(다시 솟으면 연사가 발밑으로 지나감). 1·2타로 쳐도 안 멈춤(`_hold_for_next_hit()`이 `is_finisher_flying()`이면 건너뜀). 새 3타는 다시 45도
- **잡기 스킬은 `Fighter.cancel_finisher_flight()`를 먼저 부를 것**(안 하면 잡기 피해가 추가타로 쳐져 튕겨 나감)
- 판정 캡슐은 구르는 그림을 안 따라 돈다(미해결)
- 옛 배열 캐릭터는 3타 넉백이 작다 — 더 날리려면 `combo_knockback[2]`/`launch_stun`

### 클래시(같은 스킬 동시 사용 → 연타 대결)

- `combat/SkillClashManager.gd`: 같은 슬롯을 `match_window` 안에 쓰면 화면 정지 + `ui/SkillClashPopup.tscn`. 진 쪽 `Skill.cancel_use()`. `Stage.gd`가 심고 `"skill_clash_manager"` 그룹으로 찾음. **스킬1·2·궁만 — 기본공격·맵 스킬은 안 거침**. 방 설정에서 끄면 `request()`가 즉시 `on_win`
- 연출(`SkillClashPopup.gd` + `ClashBand.gd`): P1 노랑/P2 파랑 덩어리, **사선 경계선이 곧 게이지**. 얼굴은 `GameState.PORTRAITS`
  - 연타 키는 항상 기본공격(`mash_action_id`). 결착은 누른 횟수 많은 쪽(`_decide_by_presses`)
  - 연타 수치는 시뮬레이션으로 맞춘 값(복귀력이 크면 끝까지 못 밈). AI를 세게 하려면 AI 간격만
  - `ClashBand`는 `_draw()`. 두 덩어리는 가로 띠 조각 `draw_primitive` + 경계선 x를 `±pad`로 자름. `full_balance`(>1)까지 채움, `solid` 전환 시 `_solid_half_len`
  - 흔들림은 CanvasLayer `offset`도 같이(`ui_shake_ratio`). 띠는 위쪽(`band_center_ratio` 0.22 — 가운데면 대치 그림 가림)
  - 캐릭터 주먹 러시: 연타 1번 = 주먹 2방(`clash_punches_per_press`), 주먹은 각 손 쉬는 자리에서 출발, 잔상 `clash_ghost_*`(owner 없음), 러시 중 손 물건 숨김, `shove_amplitude` 0
  - 대치 중 리그 `process_mode = ALWAYS`(끝나면 INHERIT). `_pose_clash()` 기울기에 `facing` 부호를 곱할 것

### 이동·방어·대시

- `Fighter.jump()`: `is_on_floor()`로 지상/공중 구분. `max_air_jumps`·`air_jump_velocity`·`gravity`·`jump_velocity`는 **static var**(훈련장에서 변경, 영구 반영은 `DEFAULT_*`). `_air_jumps_left`는 `move_and_slide()` **뒤에** 채울 것
  - 이단 점프 전체 ≈ 216px. **점프·중력을 바꾸면 맵 발판 사다리(놀이터·지하철 의자·공사현장)를 같이 확인**
  - 낙하 중력 배수 `fall_gravity_multiplier`(지금 1.0 = 꺼짐, 경직 중엔 안 곱함). 낙하 높이↔속도 환산은 `_fall_gravity()`
  - 이동속도는 `stats/*.tres`의 `move_speed`
- **착지 경직**: `landing_lag_height` 이상 낙하면 `landing_lag_time` 동안 전부 막힘(`is_busy()` 포함) + `BodyRig.play_land_crouch` + `land_lag_squash`. 피격 낙하·`movement_override` 착지는 제외. 낙하 속도·공중점프 여부는 `move_and_slide()` **전에** 기억. 착지 즉시 튕기는 기믹은 `cancel_landing_lag()` 필수
  - 모든 스쿼시·스트레치는 발바닥(`squash_pivot_y` +30) 기준, `_squash_lift`로 더한 만큼만 뺐다 더함
- **대시**(이동키 두 번, `DOUBLE_TAP_WINDOW`): `dash_speed` x `dash_duration`(static) ≈ 112px, 쿨 2.5초. 스킬 아님, 공중 가능, 맞으면 끊김. 두 번째 탭 인정 시 탭 기록 삭제. 잔상은 `Visual` 복제 후 **스크립트를 뗄 것**
- **방어**(아래 키 누르는 순간): `combat/GuardShield.gd`, `guard_duration` 동안 데미지·넉백 0 → `guard_cooldown`. `take_damage`에서 `is_invincible`과 같은 자리 early return, 막은 양 `custom_data["guard_absorbed"]`
  - 디버프·그랩 차단, **궁극기 디버프만 관통** — 판정은 `Fighter.blocks_debuff(from_ultimate)` 한 곳. `set_modifier` 직접 호출(맵 기믹·자기 버프)은 검사 안 거침
  - 그랩은 `Fighter.can_be_grabbed()` 확인(`MouseGrab`, `BackSuplexSkill`, 카운터 자세도 여기)
  - 방어 중 이동·점프·공격 전부 막힘, 수평 속도 0. 아래 키가 발판 통과와 겹쳐서 `GUARD_CANCEL_WINDOW` 안 점프면 `cancel_guard(true)`로 쿨 환불
  - 자세 `BodyRig.set_guarding()`. 손은 머리 앞 끝(x=25)보다 앞(얼굴에 붙이려면 y를 올릴 것), `guard_hand_deg`는 음수
  - 막히면 "BLOCK" 팝업 + `blocked_attack_lock` 동안 기본공격 잠김 + 무기 빨강 깜빡임·안쪽 테두리(`BlockedOutline.gdshader`). 막힘 판정은 `Hitbox._try_hit()`에서 **한 번만**(`_is_blocked_by_guard()`)
  - 가드/대시 off는 `can_guard()`/`can_dash()` 맨 앞
- **쿨 파이 `combat/CooldownPies.gd`**: 캐릭터 등 뒤 작은 원(방어 하늘색 / 대시 라임), 먼저 시작한 쿨이 위 슬롯, unshaded라 맵 조명 무시. `guard_cooldown_ratio()`/`dash_cooldown_ratio()`. 타이틀에선 숨김
  - 기본공격이 막혀 잠긴 동안(`blocked_attack_ratio()`)은 같은 슬롯에 **빨간 X**(원 없음, 흰 테두리 동일) — 풀릴수록 빨강이 위에서 아래로 줄어듦(`_draw_cross`, 가로선 자르기 `_clip_below`)
- **플랫폼 내려가기**: 레이어를 끄지 말고 발판에 `add_collision_exception_with`, `DROP_THROUGH_DURATION` 뒤 복구. 발판 판별 `get_one_way_floor()`(공개). 예외는 **바디 전체** → 한 바디에 막힘 충돌을 섞지 말 것
- **올라갈 수 있는 발판은 `one_way_collision = true`**(밑에 끼어 눌림). 밑 공간 없는 장애물은 예외

### 이펙트

- 히트: `Fighter._flash_hit()` + `combat/HitSpark.tscn`(세기 = 데미지 / `SPARK_POWER_DAMAGE`, 1.5 이상이면 충격파, 막히면 파랗게). `start_progress`로 진행된 상태에서 시작 가능
- **히트스톱은 꺼져 있다** — `Hitbox.hitstop_time` 0(켜려면 0.022). 켜면 `Engine.time_scale` 사용, `repeat_interval` 판정은 제외, 이미 0.5 미만이면 안 걸음, 복귀 타이머 `ignore_time_scale = true`
- 착지 먼지 `combat/LandDust.gd`(20px 이상 낙하, 발 양옆 구름), 점프 바람 `combat/JumpWind.gd`(발밑, 뛴 방향 반대로 끌림, 흰색 + 옅은 테두리). 둘 다 **맵에 붙임**(캐릭터 자식이면 반전에 뒤집힘)
- 피격 움찔 `BodyRig.play_hit_flinch()`: 다른 자세 위에 더하기, **그림만 움직임**(물리로 띄우면 확정 콤보 깨짐). 구르기·슈퍼아머 중엔 없음
- 기절 별 `combat/StunStars.gd`: 맵에 붙여 따라감, 이미 있으면 `extend()`. 두 프레임은 합집합 bbox로 똑같이 자를 것

## 캐릭터 현황

캐릭터 씬의 `BasicAttack`/`Skill1`/`Skill2`/`SkillUltimate` 스크립트가 전부다. **빈 `skills/Skill.gd` = 쿨만 도는 껍데기(의도된 미구현).** 로스터는 `GameState.CHARACTERS`, 주인공만 `TRAINING_ONLY_CHARACTERS`.

| 캐릭터 | 기본공격 | 스킬1 (G) | 스킬2 (H) | 궁극기 (R) |
|---|---|---|---|---|
| 금쪽이(촉법소년) | 막대사탕 3타 | `DashSkill` 자전거 | `BBGunSkill` 비비탄 | `HealSkill` |
| 악플러 | 키보드(두 손) | `MouseGrabSkill` | `RageBuffSkill` 열등감 | `WeakenAuraUltimate` |
| 주정뱅이 | 술병 | `DrinkSkill` 술 스택 | `VomitSkill` 토 기둥 | `ScreamConeUltimate` 괴성 |
| 고양이 아주머니 | 3타 | `TunaThrowSkill` | `TunaPlaceSkill` | `CatHutUltimate` |
| 층간소음 청년 | 3타 | `AoeAttack` 기타 둔화 | `VacuumSkill` 흡입 | `DunkUltimate` |
| 지하철 아저씨 | 단소: 찌르기→발차기→회전 베기 | `TurnstileSkill` | `CounterSkill` | `TteokbokkiUltimate` |
| 헬스장 빌런 | 3타 | `LivingShadowSkill` | `BackSuplexSkill` | 빈 `Skill.gd` |
| 일진 | 주먹·주먹·가방 | `CigaretteSmokeSkill` | `ShoulderChargeSkill` | `IljinCrewUltimate`(등장만) |
| 주인공(경찰) | 맨손 잽 / 경봉 모드 | `TaserGunSkill` | `StoneThrowSkill` | `BatonModeUltimate` |

- **금쪽이 = 촉법소년의 표시 이름.** 표시 이름이 키라 바꿀 땐 전부: `GameState`(CHARACTERS·색·초상화·리그), `ChokbeopsonyeonStats.tres`, `CharacterSelect.tscn`, `CharacterDex.tscn`, `PortraitFrames.tscn` 노드, `Stage.knockout_characters`, `sprite/도감/전신/금쪽이.png`. 내부 이름은 그대로
- **새 캐릭터 크기 기준 = 악플러**(머리 ~53x52, 상한 55x55)
- **숨겨진 캐릭터 `GameState.HIDDEN_CHARACTERS`**(2026-10-01): 캐릭터 선택창에서 **aaddssww**를 치면 아래 칸 줄이 숨겨진 캐릭터 칸으로 바뀌고 다시 치면 원래대로(`CharacterSelect._input`/`_toggle_hidden_mode`, 칸은 `_build_hidden_tiles()`가 코드로 만들어 줄 가운데에). 경로 찾기는 `GameState.character_path()`, `training_characters()`·`character_name_for_path()`도 숨겨진 캐릭터를 포함. 타이틀 구경·도감엔 안 나옴
  - **황근출 해병** `characters/hwanggeunchul/`(그림 `sprite/황근출 해병/`, 팔 파일명 `황 근충 해병 팔.png`·정면 `환근출 해병 정면.png` 오타 그대로): 궁은 빈 껍데기(사용자 지시). **스킬2 `JjajangEatSkill`**(2026-10-01): 주머니에서 짜장면(리그 `EatBowl`, `play_eat_motion`/`_pose_eat`)을 꺼내 1초 먹고 잃은 체력의 30% 회복(씬 `heal_ratio`), 대신 대시 쿨이 먹을 때마다 +2초씩 쌓임(라운드 끝까지, `Fighter.dash_cooldown_bonus` → `effective_dash_cooldown()`, `custom_data["jjajang_eats"]`). 먹다 맞으면(`damaged`) 끊기고 회복·쿨 증가 없음, 쿨 15. ⚠️ `EatBowl` 순서는 씬의 `index="3"`으로 — `_ready()`에서 `move_child`하면 대시 잔상(`duplicate()`)이 자식 속성을 순서로 복사해 머리가 커진다. **스킬1 `DropkickSkill`**(2026-10-01): 무릎 꿇기 0.5초(슈퍼아머, 리그 `set_kneeling`/`kneel_*`) → 앞으로 300px 날아 차기(1뎀, 쿨 10) → 맞으면 `launch_finisher(..., shape)`로 첫 포물선만 옆 속도 x2·높이 x2·체공 x5(중력 = peak/airtime², 공중 감속 /airtime, 첫 땅 튕김에서 보통 3타 물리로 복귀), 헛치면 착지 후 1초 못 움직임. 기본공격(2026-10-01) = 1타 뒷손 잽 → 2타 앞손 잽(경찰 맨손 잽 재사용: `held_item_armed` false + `unarmed_thrust`) → 3타 **박치기**(리그 `unarmed_headbutt` — 엉덩이 축 `headbutt_pivot`으로 상체를 뒤로 젖혔다 앞 아래로 내리찍음, `_pose_headbutt()`; 로컬 좌표라 facing 부호 안 곱함). 수치는 악플러와 같은 배열(3/4/7, 파고들기 0/60/120, `finisher_windup` 0.223). 머리 돌리기 그림 전부 오른쪽, 얼굴이 검은 실루엣인 건 그림 그대로

### 금쪽이

- 자전거 `DashSkill`: 속도 = 이동속도 x `dash_speed_multiplier`(씬 1.7). 출발·돌진 중 뒷바퀴 자리에 `JumpWind`(`takeoff_wind`), `ChargeWind`(`wind_lines`, 맵에 붙여 따라감)는 꺼짐. 일찍 끝나면 `_end_dash()`가 `stop()`
  - 상대를 들이받아도 자기 피해 없음(`enemy_hit_self_damage` 0 — 0이면 `take_damage(0)` 대신 넉백·경직만 직접). 벽 자해는 그대로
  - 들이받으면 `combat/BikeWreck.gd`: 바퀴/안장/몸체 중 하나만 튀어 라운드 끝까지 남고 나머지는 `BodyRig.break_bike()`. 조각 그림은 원본 `자전거.png`와 **같은 캔버스**(자전거 그림을 바꾸면 조각도 다시). 바닥 닿음은 칠해진 부분의 볼록 껍질(`_hull_of`) + `topple_speed`로 눕힘. 그리기 순서는 z_index 대신 첫 캐릭터 앞으로 `move_child`
- 비비탄 `BBGunSkill` + `BodyRig._pose_gun()`: 주머니에서 꺼내기(`draw_time` 0.05 — 이게 지나야 첫 발, 0 금지) → 쏘기 → `aim_hold_time` → 넣기(`holster_time`). `play_gun_motion(전체, 꺼내는, 넣는)`
- 막대사탕 `attack_thrust`(2·3타는 `thrust2_*`/`thrust3_*` 따로). `HandRHold/Candy` rotation 45도 + 후리기 45도가 한 쌍. `attack_raise_deg` 음수. 사탕 z_index 없음. 끊어 치기 `attack_snap` + 잔상 `attack_smear`(리그 기준 변환으로 보간)

### 악플러

- `RageBuffSkill`: `duration` 동안 콤보 매 타 +`bonus_damage`(`compute_damage` 배율 전에) + 붉은 색조 + 액션 얼굴 + `play_head_shake()`
- `MouseGrab.gd`: 한 장 그림을 `region_rect`로 유선/물체 잘라 따로 그림(유선만 늘림). **그림을 다시 그리면 영역·중심선 상수 재측정.** 유선 시작점 = `BodyRig.get_hand_position()`
  - 포물선 처짐(`throw_drop_after` 이후 `throw_gravity`) — **실효 사거리는 중력이 정함. 속도를 바꾸면 중력은 배수의 제곱으로 같이.** 지면 닿으면 끝(법선 위인 면만, `fighters` 제외), 거리는 x 이동 거리 기준
  - 잡기는 `STATE_FLY` 전체, 되감기 중엔 없음. 크기 `mouse_length`/`coil_width`는 `new()` 후 `setup()` 전에
  - 팔 `play_cast_motion(젖히는 = throw_windup, 돌아오는)`, `set_reeling()`. `cast_windup_offset.y`는 -6보다 위로 금지
- 키보드 `HandRHold/Keyboard` z_index 1(2 이상이면 대시 잔상 키보드가 본체 앞에). 두 손 잡기 `attack_two_handed`: 총 회전각 120도 이하, `attack_grip_speed` 9 이상

### 주정뱅이

- 술 스택(`DrinkSkill.max_stacks` 3). 토 기둥 `VomitBeam`(Hitbox 상속, **맵에 붙여 입 위치에**): 길이·두께 = 기본 + 스택 x 증가분. 풀스택은 벽에서 반대편 벽까지(의도). 벽에 막히면 `region_rect` 가로를 자름
  - 그림은 스택별 4장 `sprite/주정뱅이/토사물모음/` — **파일 1~4 = 스택 0~3, 3스택은 `4스택진짜.png`**. `stack_textures` + `stack_body_rects`(기둥 몸통 영역 — 새 그림이면 재측정). 못 찾으면 warning + 숨김
  - 토 그림이 안 보이거나 옛 갈색이면 **스크립트 파싱 오류부터**
- 괴성 `ScreamConeUltimate` + `ScreamCone.tscn`: 부채꼴 판정, 빨간 부채꼴은 판정과 같은 점 배열. **데미지·입 위치·디버프는 캐릭터 씬 `SkillUltimate`, 범위·각도·연출은 `ScreamCone.tscn` 루트 — 한 값은 한 곳에만**
- 술병 타격: 마무리 3타에만 술방울(`LiquorSplash`, 스택 비례). **8타 맞히면 병이 깨짐**(`break_after_hits`, `swap_held_texture()` — 두 그림 캔버스 같아야 함, `꺠진소주병.png`는 임시). 유리 조각 `GlassShard`(볼록 껍질 착지, `tint`로 톤 맞춤)
- 술병 `HandRHold/Bottle` 제자리 값·`drink_hand_deg` 0은 **건드리지 말 것**. `play_drink_motion()`은 공격 위에 덮어씀
- 토 얼굴·술 머금은 얼굴 배율은 평소 머리와 보이는 높이가 같게 잰 값(그림 바꾸면 재측정)
- `AIController`는 원거리 판단에 `projectile_scene`과 `beam_scene`을 함께 본다
- 스킬 범위 미리보기 `characters/SkillRangePreview.gd`(@tool): 홀더를 옮기면 **`Apply Holders To Skill`** 후 씬 저장. 미리보기(`_scale_of`/`_whole_offset_of`)와 게임(`spawn_offset`/`scale_for`)은 같은 식 — 같이 고칠 것. 에디터에선 @tool 아닌 스크립트 메서드 호출 불가

### 지하철 아저씨

- 평타(`SubwayVillainRig.tscn`): 1타 두 손 찌르기(`grip_hit_index` 0) / 2타 발차기(`attack_kick_hit` 1) / 3타 한 바퀴 돌며 베기(`thrust3_*`, `spin_hit_index` 2, `spin_duration` 0.5 → 판정 0.5 x 0.62 x 0.72 ≈ 0.223 — **회전 값을 바꾸면 `finisher_windup`과 같이**). 단소 `attack_swing_deg` 46. `vault_jump` 점프 회전 연출
- **카운터 `CounterSkill`**: `stance_duration`(0.6) 자세 중 상대 공격(맵 피해 제외)을 맞으면 피해 없이 반격, 헛방이면 `whiff_lag`
  - 자세 `BodyRig.set_counter_stance()`: 두 손으로 단소를 얼굴 높이에서 앞 아래로 겨눔, z를 `attack_grip_hand_z`로. **자세 중 idle 몸짓 금지**
  - 반격: `Engine.time_scale` = `slow_scale` + 검은 막 → 상대 등 뒤 순간이동 → 선글라스 번쩍(`CounterFlash.gd`) → 3타 베기 → 데미지 + `launch_finisher`. 예약은 `Timers.after(..., real_time = true)`, 배속은 0.5 미만이면 안 건드림, `_exit_tree()`에서 복구
  - 가로채는 곳 두 군데, 둘 다 `Fighter.try_counter()`: ① `Hurtbox.take_hit()`(false 반환) ② `Fighter.take_damage()`(넉백 있는 피해만). 등록 슬롯 `Fighter.counter_stance`
  - AI는 상대 공격을 읽었을 때만 `_try_counter_stance()`
- 개찰구 `Turnstile.gd`: 그림 한 장(마주 보는 한 쌍)을 가운데서 반으로 잘라 두 장애물에 하나씩(`flap_dir`, add_child 전). **`visual_scale`과 `TurnstileSkill.spacing`은 같이(spacing = 817 x 배율).** 충돌은 40x45. `CABINET_X`/`BOTTOM_Y`는 그림 바꾸면 재측정
- `TteokbokkiUltimate`: 고정 시간 채널(기획은 "누르고 있는 동안" — 오픈 이슈)

### 일진

- `characters/iljin/`, 그림 `sprite/일진/`. 평소 가방 `HandL/BagIdle`, 3타에만 `HandRHold/Bag`(`weapon_on_final_hit`)
- 스킬1 담배 연기(입 앞, `start_busy`), 스킬2 어깨치기(둘 다 같은 `launch_speed`로 뜨고 상대만 기절, 가드면 안 뜸, 끝나면 `end_busy()`)
- ⚠️ **액션 표정 슬롯은 하나** — 표정 쓰는 스킬은 자기 얼굴을 직접 지정(`smoke_face`/`charge_face`)
- **궁 `IljinCrewUltimate`**(등장까지만, TODO: 공격·버프·퇴장): 친구(왼쪽)·여자친구(오른쪽)가 화면 기준 고정 위치에 등장
  - 패거리는 `IljinCrewMember`(CharacterBody2D) — **Fighter로 만들면 안 됨**(fighters 그룹 오인, 몸 충돌 꺼짐). 캐릭터와 몸 충돌은 끄고 가로로만 밀어냄(`_block_fighters()`, 매 물리 프레임 예외 훑기). 부른 일진 공격엔 `immune_source`로 면역, 주인 사라짐은 `_had_owner`로
  - 방향은 `Visual`에만, 피격 빨강은 `Visual.modulate`. idle 몸짓 끔
  - 친구 침: 파선 경고 → 침(`Spit.tscn`, 관통, "iljin_crew" 몸 통과) 반복. `aim()`은 `setup()` 다음. 빠른 투사체는 판정을 진행 방향으로 늘림(도형은 새로 만들어 끼움 — sub_resource 공유)
  - 여자친구: 좀비 걷기 + 발차기(`kick_windup` = 리그 duration x 0.4), 넉백 맞으면 `knockback_stun`(안 하면 걷기가 넉백을 덮음)

### 헬스장 빌런 / 고양이 아주머니 / 층간소음

- `DunkUltimate`: 상대 쪽 도약 후 착지 범위 공격(도약 중 `movement_override`)
- `AoeAttack`: 자신 중심 원형 + `slow_multiplier`/`slow_duration`

### 주인공(경찰) — 훈련장 전용

- 파츠 `sprite/storymode/경찰서/`, **`PoliceRig.tscn`이 정본**. 표시 이름 "주인공"은 `TRAINING_ONLY_CHARACTERS` 키 / `CHARACTER_COLORS` 키 / `PoliceStats.tres` 세 곳 일치. 이름 역조회는 `training_characters()`로
- 테이저건: 한 발, 맞으면 2초 기절(쿨 20). **기절은 총알이 아니라 스킬이 `connected` 신호로 건다**, 막히면 기절 없음
- 맨손/경봉: `BodyRig.weapon_switch` + `held_item_armed`. 경봉 중 데미지 x2(`set_modifier("attack_debuff_multiplier", "baton_mode", ...)`, `_exit_tree()`에서도 해제), 사거리 x1.35
  - 무기 숨기기는 던지기 처리보다 **뒤에**(순서 바꾸면 돌 던진 뒤 경봉이 되살아남)
  - 맨손: 1·2타 손 번갈아 잽(`jab_reach_x`는 도달 x **절대값** — 두 손 쉬는 자리가 달라서), 3타 어퍼컷(`unarmed_uppercut`, 고개·상체 기울기에 facing 부호, 발은 안 건드림)
- 바디 수플렉스(`BodySuplexSkill`) 스크립트는 남아 있음

## 몸(BodyRig) — `characters/BodyRig.tscn`/`.gd`

머리/몸/손/발 Sprite2D 조립 공용 몸, 캐릭터 씬 `Visual` 자리(이름 `Visual`이어야 `_flash_hit`·궁 연출 동작). 애니 파일 없이 코드로 걷기. 왼쪽 = `scale.x` 부호만 뒤집음. 제자리 값은 `_ready()`에서 씬 위치를 기억.

- 파일: 공용 `sprite/body/`, 전용 `sprite/<캐릭터>/몸/`(층간소음·캣맘·지하철은 폴더 바로 아래 `발.png`/`손.png`도 볼 것)
- 캐릭터별 머리는 `BodyRig.tscn` 씬 상속(`Head`만 덮어씀). 조각 위치는 **`BodyRig.tscn`을 직접** 열어 옮길 것
- **새 리그 배율은 눈대중 금지** — 실제 영역을 재서 역산(position = 목표중심 - (bbox중심 - 캔버스중심) x 배율)
- **손에 드는 무기는 `HandRHold`의 자식**(배율 1). 무기 `position` 오프셋은 그림 반길이보다 작게, 바꾸면 `attack_raise_deg`/`attack_swing_deg`도. `HandR`·`HandRHold`는 형제라 `modulate`를 둘 다
- 공격 모션 `play_attack_swing()`: 40~62%가 내려찍기. 손에 든 물건 각도 고정(`attack_hold_deg`)은 되돌린 것 — 다시 건드리지 말 것
- **머리 돌리기 그림**(금쪽이·악플러·주정뱅이·지하철·일진): `head_turn_textures`(측면1→…→마지막이 정면) + `head_turn_anchors`(각 **머리 공의 중심x·중심y·지름**) + `head_turn_faces_left`. idle 뒤돌아보기·방향 전환·회전 타격에 씀
  - 방향 전환 `head_turn_on_face`: 고개 먼저, 정면인 순간 몸 뒤집기. `Fighter.facing`은 즉시 바뀌므로 공격·스킬·방어·피격이 시작되면 `_face_turn_blocked()`로 즉시 끝냄
  - 회전 타격 `spin_uses_head_turn`: 뒤 반 바퀴는 뒤통수 `head_back_texture`(금쪽이만). `spin_back_flip + spin_back_show` < `spin_strike`
  - 앵커 재는 법(스크립트는 저장소에 없음): 알파 1/4 축소 → bbox 높이 22% 정사각형 열림 연산 → 무게중심·`2sqrt(넓이/pi)`. 프로펠러·턱 말고 머리 공만
  - 몸통 돌리기 `body_turn_textures`(금쪽이·악플러·주정뱅이·황근출): 도는 도중에만, 평소엔 정면 몸통. 캔버스가 다르면 `body_turn_match_height`, 왼쪽 보는 그림은 `body_turn_faces_left`. 영역은 `_opaque_rect_of()`(알파 절반 이상 — `get_used_rect()`는 알파 1짜리 점에도 늘어남)
  - 파일명 오타는 그대로 둠: `축법소년 픅면 2.png`, `금쪾이 몸 측면3.png`, `주정뱅잉 측면2.png`, `지하철 아저 씨측면 1.png`, `황근축 해병 몸 측면 3.png`
  - ⚠️ 주정뱅이 머리 `측면 3.png`이 몸통 그림으로 덮인 적 있음 — **머리/몸통 파일명이 비슷하니 덮어쓰기 전 내용을 볼 것**
- **표정**: 잠깐 표정 피격 > 토하기, 기본 머리 액션 > 취함 > 지침 > 맨정신(`_apply_base_head()`). `set_action_face`/`set_drunk_head`는 `_restore_head()`로 복귀. `hurt_head_scale` (0,0)이면 원래 배율. `_update_hp_face()`는 `take_damage`/`heal`/`ring_out` 세 군데 전부
- **눈 생동감**(전부 `Head`의 자식, 좌표는 머리 그림 픽셀, 기본 얼굴일 때만, 잔상엔 안 함):
  - 깜빡임 `EyeBlink.gd`: 금쪽이·층간소음·일진·일진 친구·여자친구·경찰
  - 렌즈 반짝임 `LensGlint.gd`(unshaded): 악플러(흰 렌즈라 흰 빛 + 하늘색 테두리)·캣맘·지하철
  - 소용돌이 `SwirlEye.gd`: 주정뱅이
  - 특수 idle `idle_special`: 1 안경 올리기(악플러, 왼손 z 잠깐 3) / 2 딸꾹질(주정뱅이, top_level Label)
- 대치 자세 `fight_stance`는 꺼짐(기능만)
- 악플러 기본 머리 `sprite/악플러/몸/악플러대가리.png`. **파일은 Godot 파일시스템 창에서 옮길 것**(탐색기로 옮기면 uid·참조 깨짐)
- ⚠️ 원본이 없고 `.godot/imported/*.ctex`에만 있던 적 있음 → offset 56부터 WebP로 추출, `.import` 두면 uid 유지
- TODO: 공격 모션 미완

### 그림 파일 교체 시

- 에디터 밖에서 PNG를 덮어쓰면 재임포트 안 됨 → `.png.import` 삭제 후 `godot --headless --editor --path <프로젝트> --quit`
- 배율은 `get_used_rect() x scale`이 예전과 같게, `centered`면 유효영역 중심 차이만큼 position 보정
- 흰 배경 제거는 **테두리 flood fill**(흰 머리카락 보호). 파츠는 알파 있는 PNG로 달라고 할 것
- "안 보인다"의 첫 원인은 지워진 파일을 가리키는 `ext_resource`. 경로를 바꿀 땐 낡은 `uid=`도 지우거나 `.import`의 uid로(Godot은 uid 우선)
- 그림 구석에 딴 게 묻어 있는지 확인(경찰 컷인 입이 허공에 뻐끔거린 적 있음)
- 썸네일 가장자리 한 줄이 흰색이면 칸 전체에 흰 띠

## 조작 / AI

- 기본 배치 — P1: 이동 A/D · 점프 W · 방어 S · 기본공격 F · 스킬1 G · 스킬2 H · 궁 R · 맵 스킬 E / P2: ←/→ · ↑ · ↓ · L · ; · ' · ] · [
  - 대시 = 이동키 두 번, 이단 점프 = 점프 두 번, 발판 내려가기 = 아래 누른 채 점프
  - ⚠️ **기본 배치를 바꾸면 `GameState.KEYBIND_VERSION`을 올릴 것**(안 올리면 저장 파일 있는 사람은 새 배치를 못 봄)
- `controllers/PlayerController.gd`(`player_index` 1/2 → `p1_*`/`p2_*`). Fighter는 사람/AI 구분 없음
- ⚠️ `Fighter.move()`/`dash()`가 `facing`도 바꿈 → 후퇴·뒤로 대시 직후 `facing`을 되돌릴 것
- **`controllers/AIController.gd`(규칙 기반)**: 기믹 피하기 → 상대 공격 읽기(`_update_threat`, `reaction_time` 뒤 방어/점프/대시) → 왕관 → 발판 길찾기 → 거리 싸움 → 스킬
  - 사거리는 기본공격 `range + 28`. 상대가 방어 중이거나 내 공격이 잠겼으면 안 침. 빈틈(`_target_vulnerable`)이면 파고듦. `bait_chance`
  - 원거리 캐릭터는 그 스킬이 준비됐을 때만 `ranged_distance`
  - **`_want_skill()`이 스킬 스크립트 이름별로 판단 — 새 스킬을 만들면 여기에 한 줄 추가**(없으면 "250px 안에서 가끔")
  - 발판 길찾기: StaticBody2D 직사각형 충돌을 1초마다 모아 그래프. 원웨이는 밑에서 뚫고, 내려갈 땐 `drop_through_platform()`. **스프링 좌석 위에선 점프 안 누름.** 기울어진 충돌 밑에 끼이면 `_update_stuck`/`_run_detour`(`_head_clear`는 광선 3줄)
  - 발 높이 방해물은 `"ai_jump_over"` 그룹 + `ai_obstacle_position()`
  - 위험 기믹: `is_dangerous()` + `"ai_danger_zone"` 그룹 → `"ai_safe_spot"`(`maps/AISafeSpot.gd`)로 피함. 열차 중엔 피난처를 벗어나는 회피 안 함, 방어 안 함(`_hazard_active()`)
  - `ClaudeAIController`(스토리)의 `guard_bias`는 방어 확률 배수. 스토리 AI는 `knows_follow_ups = false`(콤보 잇기·빈틈 파고들기·날아가는 상대 추격 안 함 — 한 대씩만)
  - `showcase`(타이틀 전용): 거리 벌리고 점프·대시하다 다가가 스킬이나 콤보 한 번. 화면 가장자리 `showcase_screen_margin` 밖으로 안 나감

## 맵

- 새 맵 필수: 바닥·벽(또는 링아웃 공간)·`PlayerSpawn1/2`·`Camera2D`(`maps/CameraRig.gd`)·`CombatHUD`. 목록은 `GameState.MAPS`에 한 줄
- **`Deco`로 시작하는 노드 = 맵 선택 미리보기에서 제외**(`Camera2D`/`CanvasLayer`도)
- `CameraRig`: `add_trauma()`는 순간 충격, 지속 진동은 `set_rumble(세기)`. `lock_ground_to_bottom`(놀이터만). `_apply_wall_limits()`가 벽 폭으로 최소 줌 강제. `start_pan()`/`view_scale`/`zoom_boost`는 타이틀용(static — 타이틀 `_exit_tree()`가 1로 되돌림)
- 배경이 지글거리면 밉맵: `.import`의 `mipmaps/generate=true` + 씬 루트 `texture_filter = 4` 둘 다
- `maps/ParallaxFollow.gd`(`factor` < 1 먼 층, > 1 앞 층) — 공용
- 맵 전용 스킬: `Stage.map_skill_scene`을 두 캐릭터에 붙임(`fighter.map_skill`), 공중에서 맵 스킬 키. 클래시 안 탐
  - `GroundPoundSkill`: 공중 급강하 → 착지 범위 데미지 + 밟은 발판에 `break_platform()` 있으면 부숨. 지상이면 쿨 환불
  - `BreakablePlatform`: 자식 `RespawnTimer`로 복구

### 놀이터 `maps/Playground.tscn` — 왕관 훔쳐서 달아나기

양 끝 스프링 시소 → 미끄럼틀 지붕 → 중간 구름 → 꼭대기 구름의 왕관, 가운데 그네(방해물), 모래사장.

- ⚠️ **빌더 `tools/build_playground.py`는 지금 돌리면 안 된다**(미끄럼틀 교체·왼쪽 판정을 씬에서 직접 고침). 돌린다면 씬 백업 + 손수정 값을 `PLATFORM_OVERRIDES`·`CROWN_POS` 등으로 옮긴 뒤
- 바닥 윗면 y=280, 벽 x=±960(충돌만), 스프링 좌석 y=226, 지붕 y=-82(±560), 중간 구름 y≈-228, 꼭대기 y=-418, 왕관 `Crown`(25, -472), 스폰 ±560. 카메라 `min_y` -300 / `max_y` 20(구름을 올리면 `min_y`도)
- **모든 층 발판·스프링 좌석은 원웨이.** 지면→지붕은 스프링 정점에서 공중점프로 닿는 설계
- ⚠️ TODO: 점프력 변경 뒤 재실측 안 됨 — 중간→꼭대기 여유가 ~3px라 왕관에 못 오를 수 있음(안 되면 꼭대기 구름을 내리거나 넓힐 것)
- 미끄럼틀(노드 이름 `PavilionLeft/Right`): **왼쪽만 판정**, 바디 넷(지붕·바는 원웨이, 기둥·판은 막힘) — 한 바디에 몰지 말 것
- **그네 `Swing.gd`**: 좌석에 대한 상대 속도 반대로 튕김 + `apply_hitstun` 필수(안 걸면 `move()`가 덮음). 거리는 속도보다 경직 시간이 정함. 데미지 0
- **스프링 `SpringJumpPad.gd`**: 직전 낙하 속도(`_prev_fall`)로 튕김, `cancel_landing_lag()`. 몸 중심이 판정 아래면 무시
- **왕관 `Crown.gd`**: 닿으면 왕(속도·공격력·모래 면역, `custom_data["playground_king"]`, `Crown.is_king()`), 넉백 있는 피해를 맞으면 떨어뜨림(`damaged` 신호). **승리 조건은 안 건드림.** `pickup_delay` 0 금지, `drop_grace`. 떨어진 왕관은 발판 통과해 지면까지. 옮길 땐 본체 `Crown`을. 그림 `진짜왕관.png`는 맵과 `CrownCutIn.tscn` 두 곳
- **모래 `SandPit.gd`**: 발치 높이에만 `set_modifier` 둔화. `모래사장.png`(괄호 없음)는 쓰지 말 것
- 울타리는 온전한 기둥 두 개 사이만 region으로 잘라 반복. 아파트 `a1`(간판)은 한 동만

### 지하철 승강장 `maps/SubwayPlatform.tscn`

- 승강장 바닥 없음 — 선로 바닥 y=300, 벽 ±560, 의자 발판 윗면 y=155(원웨이, 이단 점프 전용). **의자 위 = 열차 피난처**(의자 높이·열차 크기는 같이 계산). 의자는 트리에서 열차보다 먼저
- **열차 `SubwayTrain.gd`**: 1~5칸 랜덤(`min_cars`/`max_cars`) — 그림을 앞머리·가운데·뒷머리로 잘라 조각 생성(`SEAM_FRONT`/`SEAM_BACK`/`MIDDLE_DRIFT` — **그림을 바꾸면 재측정**). 판정 폭·`get_half_width()`·이동 거리가 칸 수를 따름. 창문 불빛(`window_lights`)은 꺼짐
- 조명: `CanvasModulate` (0.55, 0.58, 0.7) + 형광등 `PointLight2D`. 빛나는 물체는 unshaded(CanvasModulate까지 무시). **가산 색은 CanvasModulate가 곱해지므로 조명을 바꾸면 다시 잡을 것**
- 먼 층 `DecoBackground` = CanvasGroup + `far_blur.gdshader` + ParallaxFollow 0.8. 앞 층 기둥 `ForegroundPillars.gd`(반복용 `기둥_반복.png`, `tools/make_pillar_tile.py`)
- 형광등 `FluorescentLight`(아직 도형), 신문지 `WindNewspaper.gd`(`wind_speed` < 열차, 노드 scale 대신 `_look`), 전광판 `SubwaySignBoard.gd`(경고는 가운데 깜빡임)
- 벽 타일은 반복 대신 스프라이트 8장. 역 이름판을 옮기면 `SignBand`·`SignBandOutline`도
- TODO(기획): 열차 위 전투, 지하철 빌런 무리 연출

### 공사현장 `maps/CollapsingApartment.tscn`

- 부서지는 발판 4층(간격 170 = 이단 점프로만), 좌우 교차라 대각선 점프. 맵 스킬 = `GroundPoundSkill`. **점프력이 바뀌면 다시 계산**

## 화면 흐름 / UI

- 시작: `ui/Disclaimer.tscn` → `TitleScreen` → `MainMenu`(스토리 / 대전 / 훈련장 / 가이드 / 설정). 대전: `RoomSettings` → `CharacterSelect`(P1→P2) → `MapSelect` → 맵
- `GameState.gd`(오토로드)가 화면 사이 값을 들고 다님. 모든 화면 ESC = 한 단계 뒤로, 대전·스토리 중엔 일시정지(`PauseMenu`, `process_mode = ALWAYS`). 메인 메뉴 ESC = 게임 종료 확인
- `Fade`(검정 ColorRect)는 씬의 **맨 마지막 자식**
- 폰트: 주아체 `fonts/Jua-Regular.ttf` — ⚠️ **기호 글리프가 거의 없다**(`◀ ▶ ● ○ · × ↑ ↓` 두부). 대화창은 나눔고딕
- **타이틀 구경 모드**(`game_mode == "attract"`): 랜덤 맵·캐릭터 둘 다 AI, 카메라가 왼쪽에서 `pan_end`(3/4)까지 흐르고 끝나면 새 조합. HUD·카운트다운·클래시·컷인·왕관 컷인·데미지 숫자 없음. `ArenaViewport`(창 해상도) + `view_scale`/`zoom_boost`(1.5). 타이틀 AI는 약하게 + 스킬 쿨 `ai_cooldown_scale`. 떠날 때 `game_mode` "pvp", 브금 정지, 배율 복구
  - 로고 `ui/TitleLogo`: `tools/make_title_logo.py`가 선·채움·빛 세 장 생성(**로고를 바꾸면 다시 돌릴 것**, 판정 틀린 곳은 `FORCE_FILL`/`FORCE_EMPTY`)
- 메인 메뉴: `<이름>Item`(Button, 판정 고정) > `Slide`(보이는 것만 이동 — 판정까지 움직이면 호버 떨림). `Illust*`와 `Background*`는 index로 짝(일러스트 추가 시 배경도). 배경 위 `Scrim` + `LeftFade` 필수. 메뉴 글꼴 미정(TODO)
- 일러스트(파츠 분리): 파츠는 원본 캔버스 그대로(Trim 끔) → `centered = false` + `position = -축`, 감싼 Node2D가 축. 번호 작을수록 위 레이어. Control이 아니라 Sprite2D. **큰 동작은 파츠 회전보다 자세 그림 교체**
  - 잼민이 총 팔 축은 팔 단면 / 캣맘 `Post` 미리 켜지 말 것, 턱 고치면 원본에서 파생 3장 재생성 / 지하철 `danso_deg` 2도 이하, `hand_push` 1.0 이상
- 가이드 `ui/Guide.tscn`(조작 방법 + 도감, `FanTile`). `HowToPlay`는 설정과 같은 키보드 그림(`KeyboardMap`, `read_only`)
- **설정 > 조작 `ui/KeyboardMap.gd`**: 풀배열 키보드(숫자패드 `NUMPAD` 포함, 폭 `TOTAL_WIDTH_U` 23u)를 `_draw()`로 그리고 키를 끌어 놓아 배정(다른 조작이 있으면 자리 바꿈). 회색/1P 파랑/2P 빨강
  - 놓는 자리: 커서가 든 키 → 없으면 딱지와 가장 많이 겹친 키(`_drop_target`), 틈은 반 칸 안이면 가까운 키
  - ⚠️ `_input`에서 `get_local_mouse_position()` 금지(창 배율 어긋남) → `_local_of(event)`. 커서 자리는 `_process`에서 매 프레임 읽음. 놓기 신호 누락 대비 `_process` 감시(`_drag_held` 빗장 필수)
  - ⚠️ **`refresh()`는 마지막에 반드시 `queue_redraw()`**
  - 좌우 있는 키(Shift 등)는 `location`까지 저장, 배정 열쇠는 `"키코드:위치"`. 저장 `GameState.rebind_action()`/`reset_keybindings()` → `user://settings.cfg`
  - 진짜 마우스 클릭은 샌드박스에서 못 넣으니 최종 확인은 사용자가
- 해상도: 기준 화면 1280x720 + `canvas_items`(배치 숫자는 전부 이 기준), 기본 1920x1080. `_apply_window_size()`가 모니터와 비교. embed 실행에선 창 크기 안 바뀜
- 확인 창 `ConfirmPopup`: `_ask(문구, Callable)`. 왼쪽 위에 뜨면 `anchors_preset = 15`로. ESC 후 `set_input_as_handled()`
- **방 설정 `RoomSettings`**: 라운드·시간·쿨 배율 + 클래시·가드·대시 토글 + 상대(사람/컴퓨터 `vs_ai` → P2에 `AIController`). 프리셋 저장 `[room_presets]`(삭제 UI 없음, TODO). 버튼 연결은 `_ready()` 코드로
- 도감 `CharacterDex`: 별점은 표시 전용. ⚠️ TODO: 놀이터 설명이 옛 기믹
- `FanTile.gd`(@tool): `corners` 네 점 모양 버튼(캐릭터 선택·가이드). 추가 공식은 파일 맨 위 주석
- `ui/outline.gdshader`: ⚠️ 셰이더 사용자 함수 안에서 `TEXTURE`/`UV` 못 씀
- 초상화(정면): 배경 투명(테두리 flood fill), 크기·위치는 `ui/PortraitFrames.tscn`, 네 곳 모두 `GameState.frame_portrait()` 경유. 캣맘 초상화 = `sprite/body/면.png`
- 스킬 로고 HUD: `Skill.icon`(투명 여백을 잘라 넣을 것), 지금 주정뱅이·금쪽이만

### 대전 진행

- 라운드제: `Stage._process()`가 양쪽 HP를 **한 번에** 판정(동시 KO = 무승부), 시간 초과는 HP 높은 쪽. 승수 `GameState.p1/p2_round_wins`, 미달이면 `reload_current_scene()`. 링아웃 `ring_out_y`
- 카운트다운(`RoundStart`) 중엔 컨트롤러 `is_active` false + `move(0)` (`set_physics_process(false)`는 관성으로 미끄러짐)
- KO 연출 `Stage._play_knockout`: 전 캐릭터·전 모드(0.35배속 + 눈 X 표정 `ko_head_texture` + 빙글 날아감)
- `CombatHUD`: `update_round_info(p1_wins, p2_wins, time_left)`, 시간 제한 0이면 타이머 숨김

### 궁극기 컷인 `ui/UltimateCutIn.tscn`

- **기획 확정:** 전체 1.5초(줌인 0.25 / 컷인 1.0 / 복귀 0.25, 장면의 `cutin_duration`이 우선 — 잼민이 2.4, 경찰 1.3), **연출 중 시간 정지**(컷인만 ALWAYS), 스킵 없음, 확정타 아님
- `use_ultimate()` → 연출 → `fire_ultimate_now()`. 장면은 `CharacterStats.ultimate_cutin_scene`, 파츠 흔들기는 `ui/cutin/CutInAnimation.gd`. 괴성은 컷인에서 안 지름
- 컷인 있는 캐릭터: 주정뱅이·금쪽이·악플러·일진·경찰. **캐릭터를 움직여 넣을 땐 러프를 오려내지 말고 리그(`<캐릭터>Rig.tscn`)를 쓸 것**
- 금쪽이: 배경 한 장 + 리그 `Runner`. 3단계 전환은 원래 머리 복원 → `set_action_face(true)` 순서. `ShoutText` 등은 visible 켠 채 저장(게임은 `_reset()`이 숨김)
- 경찰: 얼굴 두 장(벌린 입/다문 입) 번갈아 — 크기·위치 같아야 함

### 스토리 모드

- 에피소드 `GameState.STORY_EPISODES`(지금 `ep1`만), 시작 `start_story(id)`, 클리어 기록은 `clears_story` 켠 장면(지금 `StoryScene11`)의 `_ready()`
- 장면 `ui/story/StoryScene1~11.tscn`, 전부 `StoryFadeScene.gd`(페이드인 → 머묾 → 페이드아웃 → `next_scene`)
  - `Fade`는 맨 마지막 자식 + 씬에선 알파 0. 나중에 나타날 노드는 `hide_on_start`, 등장은 `reveal`. 장면 루트·대화창은 `mouse_filter = 2`
  - 전환 `out_transition`: BLACK(다른 장면) / CROSSFADE(이어지는 흐름 — 스크린샷을 static 변수에)
  - **스토리→대전:** `battle_p1`/`battle_p2`/`battle_rounds`/`battle_time_limit` → `_setup_battle()`(**GameState에 뭘 담는 코드는 여기에** — S 건너뛰기가 `_open_next()`를 우회). 이기면 `battle_win_scene` → `GameState.story_next_scene`
  - (임시) `S` 건너뛰기 — S는 P1 방어키이기도 해서 방어 테스트 땐 맵 루트 `debug_story_skip_key`를 끌 것
- 대화창 `ui/story/DialogueBox.tscn`(형식 고정): `speaker`/`lines`, `이름|대사`, 넘기기 키는 `ADVANCE_KEYS` 한 곳. **명령 줄**: `@show/@hide 노드 [초]`, `@enter`, `@exit 노드 초 거리`, `@close`, `@waitkey`, `@pause 초`, `@stamp 노드 [초]`
- 재사용 부품: `LocationCard.tscn`(장소 카드), `DriftingClouds.gd`, `FlagWave.gdshader`, `StoryWalker.gd`, `RidingBy.gd`(씬 texture에 첫 장 지정), `PopUpLayer.gd`(시점은 `after` 신호 대기), `LeafBurst.gd`, `RockThrow.gd`(`rock_arc` 0이면 LINEAR 한 번), `RockHit.gd`, `RimGlow.gdshader`(`glow_width` ≤ 투명 여백)
- **3번·11번 장면은 도장만 다른 같은 구조 — 새 사건은 둘을 복사해 문구·도장만 교체.** 사건 파일 원본 PSD를 고치면 PNG로도 내보낼 것
- 구름 노드 순서 = 포토샵 역순. 게임 글자는 "비비탄"으로 통일
- 일시정지 메뉴 오른쪽 스토리 목록은 보여주기만, 미클리어는 자물쇠(`LockIcon.gd`). 설정은 위에 얹음(`overlay_mode`)

## 튜토리얼 `maps/Tutorial.tscn`(2026-10-01, 뼈대)

- 그림 `sprite/맵/튜토리얼/`: 하늘(`DecoSky` CanvasLayer -10 화면 꽉), 구름1~4(`DecoClouds`(ParallaxFollow 0.2)/`Spawner` = `maps/RandomCloudSpawner.gd` — 그림·크기·높이·속도 랜덤으로 왼쪽 밖에서 만들어 오른쪽으로 흘리고 나가면 지움), 산(`DecoMountains` 0.3, 4장 번갈아 반전)·숲(`DecoForest` 0.6, region 반복), `DecoBuildings`(양옆 막사, 국기 = `국기 1.png` 한 장 + `maps/FlagFlutter.gdshader`(깃대 `hoist_x` 오른쪽 천만 위아래로 출렁, 끝으로 갈수록 크게. 늘어진 깃발용은 `ui/story/FlagWave.gdshader`)), 땅 `군대 잔디.png`(배율 0.5 반복, 바닥 윗면 y=280. ⚠️ `texture_repeat`는 위아래로도 반복돼 윗변에 아랫줄 흙색이 한 줄 번진다 → `region_rect`를 투명한 윗부분 40px 아래부터 시작), 벽 ±1200
- 훈련 더미를 P1이 조작(stats 복제 후 `player_move_speed`). ESC = 메인 메뉴. 군인 설명은 TODO
- **교관 = 황근출 해병(옷 입은 버전)** `Instructor`(Node2D, scale.x -1로 왼쪽 봄) > `characters/hwanggeunchul/HwanggeunchulUniformRig.tscn`(황근출 리그 상속, `Body`만 `황근출 해병 몸 옷.png`로 — 배율은 맨몸 그림과 보이는 영역이 같게 역산, 몸통 돌리기도 옷 측면 2·3). Fighter 아닌 리그만 — 판정·조작 없음. 원점 y = 바닥 윗면 - 30
- **처음 켠 사람만** 타이틀 → 튜토리얼(`GameState.tutorial_seen`, settings.cfg `[progress]`, 들어올 때 저장). 메뉴 훈련장 버튼 = `ConfirmPopup.open_choice()` 두 갈래(훈련장 / 튜토리얼 다시, 둘째 버튼 = `alternate_chosen`, ESC = `cancelled`)

## 훈련장 `maps/TrainingGround.tscn`

- 물리값·게임 속도 슬라이더(패널은 코드 생성). static var는 게임 종료까지 유지 — 영구 반영은 `DEFAULT_*`, 이동속도는 `stats/*.tres`
- `Engine.time_scale`은 `_exit_tree`에서 1로 복구. 동작 테스트 `play_scratch()`/`play_lookback()`/`play_blink()`/`play_special()`. 충돌 보기 `maps/CollisionDebugView.gd`

## GDScript 코드 스타일

| 대상 | 규칙 | 예시 |
| --- | --- | --- |
| 클래스명 / 파일명 | PascalCase, 파일명 = class_name | `CharacterStats` |
| 함수 / 변수 | snake_case | `move_speed`, `take_damage()` |
| 상수 / enum 값 | ALL_CAPS_SNAKE_CASE | `MAX_HP` |
| 시그널 | 과거형 snake_case | `health_changed` |
| private 관례 | 언더스코어 접두사 | `_internal_cooldown` |

- `class_name`·`extends` 맨 위 → `@export` → 멤버 변수 → 생명주기 → 커스텀 함수
- 씬과 스크립트는 같은 폴더에 짝지어
- 주석은 한국어: public 함수/변수 위 `##` 한 줄, 복잡한 로직에만 한 줄. 자명한 코드엔 주석 금지

```
res://
  GameState.gd  Timers.gd
  characters/   # Fighter.gd + BodyRig.gd + 캐릭터별(chokbeopsonyeon, akpeulleo, jujeongbaengi, catmom,
                #   subwayvillain, floornoise, gymbro, iljin / 로스터 밖: police, dummy)
  skills/  combat/  controllers/  stats/  maps/  ui/(story/, cutin/)  tools/
```

## 참고

- 기획 오픈 이슈는 아티팩트 문서 "다음에 정할 것" 표. 확정 전엔 임시값 + TODO
- **엔진은 4.7.2로 통일**(`config/features` = "4.7"). `invalid UID` 경고는 씬 uid를 `.import`의 uid로
- **코드 수정 후 헤드리스 에러 확인은 기본적으로 안 한다(사용자 요청)** — "실행해서 확인해줘"일 때만
- Godot 실행 파일은 PC마다 다름 — 못 찾으면 `Godot*4.7*win64*console*.exe` 검색. 경로에 공백·괄호가 있으면 PowerShell에선 `& "<경로>" ...`
- 헤드리스 테스트:
  - `--editor --quit-after`로는 파싱 에러를 다 못 잡음 → 바꾼 스크립트가 쓰이는 씬을 띄울 것
  - `extends SceneTree` + `--script` 금지(오토로드 미초기화) → `extends Node` 스크립트를 임시 `.tscn`으로 감싸고 `add_child(load(맵).instantiate())`(`change_scene_to_file()` 금지)
  - 새 `class_name` 직후엔 `--headless --editor --quit-after 20`으로 클래스 캐시 갱신
  - 시간 기반 테스트는 `--fixed-fps 60`
  - 컨트롤러가 `apply_physics()`를 이미 부르므로 테스트에서 또 부르면 경직이 두 배 빨리 닳음. 순간이동 직후엔 착지 랙으로 스킬이 씹힘(60프레임 대기). 스킬은 클래시 대기창 뒤에 나감
