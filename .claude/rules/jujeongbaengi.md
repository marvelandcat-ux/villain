---
paths:
  - "characters/jujeongbaengi/**"
  - "sprite/주정뱅이/**"
  - "skills/DrinkSkill.gd"
  - "skills/Vomit*.gd"
  - "skills/ScreamCone*.gd"
  - "characters/SkillRangePreview.gd"
  - "combat/LiquorSplash.gd"
---

# 주정뱅이

- 술 스택(최대 3). 토 기둥 `VomitBeam`(Hitbox 상속, **맵에 붙여 입 위치에**), 길이·두께가 스택 비례, 벽에 막히면 `region_rect`를 자름
  - 그림 `sprite/주정뱅이/토사물모음/` — **파일 1~4 = 스택 0~3, 3스택은 `4스택진짜.png`**. 새 그림이면 `stack_body_rects` 재측정. 안 보이면 파싱 오류부터
- 괴성 `ScreamConeUltimate` + `ScreamCone.tscn`: **데미지·입 위치·디버프는 캐릭터 씬 `SkillUltimate`, 범위·각도·연출은 `ScreamCone.tscn` — 한 값은 한 곳에만**
- 술병: 3타에만 술방울, **8타 맞히면 병이 깨짐**(`swap_held_texture()` — 두 그림 캔버스 같아야 함). 술병 제자리 값·`drink_hand_deg` 0은 **건드리지 말 것**
- 토·술 머금은 얼굴 배율은 평소 머리와 높이를 맞춘 값(그림 바꾸면 재측정)
- 스킬 범위 미리보기 `characters/SkillRangePreview.gd`(@tool): 홀더를 옮기면 **`Apply Holders To Skill`** 후 저장. 미리보기와 게임 식은 같이 고칠 것
- 오타 파일명 그대로: `주정뱅잉 측면2.png`. ⚠️ 머리/몸통 파일명이 비슷 — 머리가 몸통으로 덮인 적 있음
- **평타 스미어**(2026-10-10): 리그 `weapon_smear = true` → 하얀 궤적 대신 `combat/WeaponSmear.gd`(속이 찬 초승달 띠). 띠 폭은 **병 전체**(끝점에서 가장 먼 모서리 ~ 끝점, `weapon_smear_inner` 0 — 2026-10-10 사용자). 색은 `BodyRig._weapon_smear_colors()`가 소주병 그림에서 반대쪽 끝 → 끝 순서로 자동으로 뽑는다(병목 초록 / 라벨 흰 / 바닥 초록, 테두리 = 윤곽선 검정). **병 그림을 바꿔도 다시 잴 필요 없음**. 깨진 병은 그 그림에서 다시 뽑는다
- **토하기 = 혈사포식**(2026-10-10): `VomitSkill.charge_time`(**지금 0 = 바로**, 2026-10-10 사용자 "딜레이 없이"; 0보다 크면 토 표정 + 움찔 뒤) 나가는 순간의 자리·방향으로 발사 → `VomitBeam`이 입에서 `extend_time`(0.12) 동안 뻗고(판정도 같이) → `wobble`로 두께 꿀렁(`active_duration` 0.09 = 처음의 0.3배) → **가운데로** 가늘어지며 사라짐(`fade_duration` 0.045). 모양은 매 프레임 `_apply_shape(뻗은 정도, 두께)` 한 곳. ⚠️ 예전엔 그림 윗변 고정으로 세로만 늘려 "위에서 내려오는" 것처럼 보였다
- **공중 큰 휘두르기**(2026-10-10): `BasicAttack.air_swing_enabled`(주정뱅이만 켬) — 공중에서 누른 평타가 앞쪽 반원(반지름 `air_swing_radius` 85 — 2026-10-10 70에서 키움, 중심 몸 (0,-12)) 한 방. 점프 한 번에 한 번, 맞으면 1타 취급(착지 후 2타로 이어짐), 빗맞으면 평소 헛발 쿨. 모션은 리그 `play_air_swing()` + `air_swing_*` — **승룡권처럼 아래→위로 올려치며 몸이 한 바퀴 돎**(`air_swing_spin`, 회전 타격 장치), 반대 손은 `air_swing_off_hand`(⚠️ `air_swing_arc`는 아래→위면 양수가 앞쪽, 위→아래면 음수가 앞쪽). 판정은 원래 모양을 맡아 두고 끝나면 `_end_air_swing()`이 되돌림
- 공중 휘두르기 회전은 **몸을 안 뒤집는다**(`air_swing_spin_flip` 끔, 2026-10-10): `BodyRig._apply_turn_no_flip` — 뒷모습 그림(`head_back_texture` = `몸/주정뱅이 뒷모습.png`, 앵커 (629,640,989) = 정면 앵커에서 bbox 차이만큼, **그림 바꾸면 재측정**)이 있으면 옆 → 비스듬히 → 정면(앞 45%) → 뒷모습(35%, 몸통은 평소 그림) → 옆. 반대쪽 옆모습은 없어 정면에서 뒤로 바로 넘어간다. **팔다리**는 방향 전환처럼 정면·뒷모습일수록 몸 가운데로 모인다(`_gather_turn_limbs`, `face_turn_limb_gather` 0.7) — 병 든 손만 `air_swing_weapon_gather`(0.3)만큼(휘두르기가 작아 보이지 않게)
- **술 머금은 얼굴도 고개를 돌린다**(2026-10-10): 리그 `drunk_head_turn_textures/_anchors/_faces_left`(0번 = `drunk_head_texture`) — `몸/주정뱅이 머리 술 먹금은 측면 1~3`(724px 캔버스) + `술머금은 정면`. 앵커는 임시 측정 도구(알파 1/4 → 높이 22% 열림 → 무게중심·지름)로 잰 뒤 **평소 세트에서 잰 값과 저장값의 차이 비율만큼 보정**(측면은 머리띠 끈 때문에 왼쪽으로 3% 치우쳐 재짐). 몸통 뒷모습 `body_back_texture` = `몸/주정뱅이 몸 뒷모습.png`(불투명 높이·바닥 가운데를 원래 몸통에 맞춤, `_set_body_image`)
- **3타 = 공중 휘두르기 모션**(`BasicAttack.final_air_motion`, 2026-10-10): 한 바퀴 돌며 크게 올려치기. 길이는 평소 마무리 길이(0.558)라 **판정 0.223은 그대로**, 판정 모양·날리기도 평소 3타. 실측 1·2·3타 0.12/0.35/0.73초 그대로
