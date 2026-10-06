---
paths:
  - "characters/catmom/**"
  - "sprite/고양이 아줌마/**"
  - "skills/Cat*.gd"
---

# 고양이 아주머니 (그림 폴더 `sprite/고양이 아줌마/` — 탐색기에서 `sprite/캣`을 바꾼 것)

- 본체 그림: 몸 = `고양이 아줌마 몸.png`(옛 `치마.png` 대체 — Body 배율·위치는 옛 보이는 영역에 맞춰 역산). 머리 돌리기 = `측면1`(띄어쓰기 없음) → `측면 2` → `측 면3`(오타 그대로) → `고양이아줌마정면.png`(전부 오른쪽 봄). 몸통 돌리기 = `몸 측면 2`·`몸 측면 3`
- 고양이 그림 `skills/CatSprite.gd`: `고양이들/`의 머리·몸·발·꼬리(전부 오른쪽을 봄)를 코드로 조립, 원점 = 발바닥. 파츠마다 `PARTS`의 BBOX를 `region_rect`로 잘라 목표 px로 배율 역산 — **그림을 바꾸면 BBOX 재측정**. 자세는 엎드림(큰 머리가 몸 앞 위, 앞발 = 가슴 밑·뒷발 = 엉덩이 밑). 꼬리는 BBOX만 잘라(`cropped_of`) `Line2D` STRETCH로 곡선에 늘림(점은 끝 → 뿌리 순서). `CatFollower.draw_face()`(선택 표시·집 간판)는 머리 그림. 망치는 아직 `_draw()` 임시
- 스킬1 `CatHouseSkill`: 무릎 꿇고 망치질 2초(슈퍼아머, 리그 `set_kneeling` + `set_hammering`) → `CatHouse`(원점 = 바닥 가운데, 자식 Hurtbox로 맞아 부서짐, 그림 `고양이집.png`(박스)를 `_draw()`로 아래부터 잘라 그림 — 가로 `house_width`, 판정·막는 몸은 `BOX_WALLS`(처마 뺌), 간판은 오른쪽 큰 면 가운데 `BOX_FRONT_CENTER`: **그림 바꾸면 BOX_* 재측정**. 다 지으면 `StaticBody2D`로 상대를 막고 지붕에 설 수 있음 — 지은 사람·모든 고양이는 통과(집 벽 = `cat_house_solids` 그룹, 고양이 `_ready`·집 `_add_solid` 양쪽에서 예외)). 다 지은 순간 1마리 + `spawn_interval`마다, 주인 고양이가 4마리면 건너뜀. **종류는 짓기 시작 때 선택으로 고정**
- 스킬2 `CatSelectSkill`: 검은→주황→흰 순환, `custom_data["cat_kind"]`, 머리 위 `CatFaceIcon`. `clashable()` false
- 고양이 `CatFollower`(그룹 `catmom_cats`): 자식 Hurtbox(꼬리 뺀 머리 원·몸통·발 두 개, 방향 바뀌면 x만 뒤집음, 주인은 `immune_source`). 넉백이면 `hurt_stun` 동안 밀려남 + 눈 감음(`CatSprite.eyes_closed`, 자리 `eye_offset`은 머리 그림 바꾸면 재측정) + 돌진 끊김. 죽으면 그룹에서 바로 뺌(집이 다음 고양이를 내도록). 이동은 가속(`walk_accel`). 몸 충돌은 캐릭터와 같은 캡슐(r20 h60). 점프는 땅에 `jump_ground_time` 이상 서 있어야(2단 점프 없음). 피해는 `owner.compute_damage` 경유, 판정은 공용 `_hitbox` 하나
  - 검은: 거리 유지(가까우면 뒤로), 쿨마다 돌진 = 웅크림(`CatSprite.pounce`) → 돌진 + 잔상 `_spawn_dash_ghost()`(복제 후 **스크립트 떼고** add_child)
  - 주황: 밟은 바닥 끝에서 끝까지 왕복(벽·`_floor_ahead()`에서만 되돌아섬, 점프 안 함, 쫓지 않음). 몸이 닿으면(`orange_touch_range`) 걸으면서 돌아 할퀴기(`paw_reach` + `_spawn_claw_marks()`)
  - 흰: 주인에게 가서 핥아 회복(체력 다 차 있으면 안 핥음, 색조 `cat_lick`, `CatSprite.nod_left`). 주인이 위면 점프, 아래면 **원웨이** 발판만 잠깐 통과
- 궁 `CatUltimate`(`cat_kind`별). 검은·흰은 `_swap_basic()`으로 평타 자리를 `CatPoopShot`으로 바꾸고 `_end_mode()`에서 복구
  - 흰(임시): `CatHeldWhite`를 들고 평타 = 앞 상자 할퀴기(맵에 붙인 짧은 `Hitbox`)
  - 검은: 똥 유탄 `CatPoopShell`(땅·벽 레이캐스트 또는 상대·상대 집 Hurtbox에 닿으면 원형 범위 피해, 자기·자기 집은 통과) 5발. 그림 `고양이들/고양이 똥.png`(`POOP_BBOX` — 그림 바꾸면 재측정), 터지면 `CatPoopBlast`(충격파 + 반지름 = 폭발 반지름인 범위 원). 낀 고양이 `CatHeldVisual`(분홍 똥꼬 표시는 사용자 요청으로 뺌)
  - 주황: 고양이 옷 — **라운드 끝까지**(시간 안 셈, 회복 없음). `custom_data["cat_suit"]`로 스킬1·2 봉인(궁은 `_mode`로, 맵 스킬은 허용), `set_modifier`(id `cat_suit`)로 평타 피해·`damage_taken_multiplier`(0.9)·`dash_cooldown_multiplier`(방어 쿨은 안 건드림)·`attack_speed_multiplier`. 평타: 리그 `unarmed_thrust`를 켜 1·2타 양손 잽, 3타는 평타 자식 `CatSuitCombo`(on_combo_swing/hit) — 두 손 머리 잡기(리그 `play_head_grab`) → 맞으면(3타 판정은 `sense_only`라 **피해는 꽂을 때** `_slam()`에서) 날아가기 끊고 `is_grabbed`로 손(`head_grab_point()`)에 붙여 머리 위로 넘겨 등 뒤 바닥에 꽂기(`play_head_throw`, 잡는 순간 슬로 0.3x 0.5초 실시간, 꽂은 뒤 `launch_finisher`로 등 뒤로 튕겨 날아가며 기절 — 값은 부모 콤보 3타 값 x `slam_launch_*_mult`). 3타 날아가기 이펙트(`finisher_trail`)는 옷 입는 동안 끔. 그림은 `고양이 아줌마 합체/`로 통째 갈아입음(리그 `set_head_outfit`·`set_body_outfit`, 손발은 텍스처만, 색조 없음). 머리 = `합체` → `합체 측면 1·2·3`(3이 정면), 몸통 = `합체 몸` + `몸 측면 2`(이 폴더 것, 이름에 합체 없음)·`합체 몸 측면 3`, 발 = `아줌맘 합체 발`(오타 그대로). 머리 공 앵커·배율·자리는 `suit_*` export — 그림 바꾸면 재측정
- `damage_reduction`은 `set_modifier`로 걸면 다 풀릴 때 1.0 = 완전 무효 → `damage_taken_multiplier`를 쓸 것. 방어·대시 배수는 쿨 길이가 아니라 도는 속도에 걸림
