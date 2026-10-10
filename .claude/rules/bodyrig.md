---
paths:
  - "characters/BodyRig.*"
  - "characters/*Rig.tscn"
  - "characters/*/*Rig.tscn"
  - "characters/EyeBlink.gd"
  - "characters/LensGlint.gd"
  - "characters/SwirlEye.gd"
---

# 몸(BodyRig) 자세히

- 파일: 공용 `sprite/body/`, 전용 `sprite/<캐릭터>/몸/`(층간소음·캣맘·지하철은 폴더 바로 아래 `발.png`/`손.png`도)
- 회전 타격 `spin_hit_index`(-1 = 안 돔): 루트 `scale.x`에 cos — 다음 프레임 `_apply_pose` 첫머리에서 되돌릴 것, 최소 0.04
- 방어 자세 `set_guarding()`(손은 머리 앞 끝 x=25보다 앞, `guard_hand_deg` 음수)
- **머리 돌리기**: `head_turn_textures`(측면1→…→정면) + `head_turn_anchors`(머리 공의 중심x·중심y·지름) + `head_turn_faces_left`. 방향 전환 시 고개 먼저, 공격·스킬·방어·피격이 시작되면 즉시 끝냄
  - 액션 표정 전용 세트 `action_head_turn_*`(비우면 액션 표정 중엔 안 돎)
  - 몸통 돌리기 `body_turn_textures`: 도는 도중에만
- 눈 생동감(`Head`의 자식, 머리 그림 픽셀 좌표, 기본 얼굴일 때만): 깜빡임 `EyeBlink.gd`, 렌즈 반짝임 `LensGlint.gd`, 소용돌이 `SwirlEye.gd`, 눈빛 `EyeGlow.gd`. 특수 idle `idle_special`(안경 올리기·딸꾹질)
- 표정 결정은 `_apply_base_head()`
- 평타 하얀 궤적 `swing_trail`(기본 켬, `combat/SwingTrail.gd`): `ComboMeleeAttack._fire`가 스윙 직후 `play_swing_trail()`. 따라가는 점 = 발차기·드롭킥은 오른발, 무기는 손잡이에서 가장 먼 모서리, 맨손은 치는 주먹. **unshaded**(맵 조명에 안 어두워짐) + 가운데 하얀 심지(`core_ratio`), 꼬리 옅어짐 `fade_power`
- **공중 큰 휘두르기** `play_air_swing()` — 회전 때 뒷모습 `head_back_texture`(+`head_back_anchor`)·`body_back_texture`를 쓴다(있는 캐릭터: 주정뱅이·악플러·금쪽이(머리 `축법소년 뒷머리`)·지하철 아저씨(`지하철아저씨 뒷부분`·`지하철등뒤-Photoroom`)·고양이 아주머니). 뒷머리 앵커 = 정면 앵커 + (뒷머리 bbox 가운데 - 정면 bbox 가운데), 지름은 정면 그대로 — **그림 바꾸면 재측정**(`AIR_SWING_VARIANT` = 베기 길을 타되 값은 `air_swing_*` export, `_slash_entry()`가 고름 — SLASHES 표에 칸을 더하면 경관봉 난무 순서가 바뀌어서 따로 뺐다)
- **평타 스미어** `weapon_smear`(**기본 켬 = 전 캐릭터**, 2026-10-10, `combat/WeaponSmear.gd`): 하얀 궤적 대신 속이 찬 초승달 띠. **치는 조각 그림에서 색을 뽑는다** — 무기 타 = 무기 그림 / 맨손 타 = 주먹 / 발차기 = 발(사용자: "맨손은 맨손에, 발차기는 발에, 사탕 공격은 사탕 색"). 색은 `_weapon_smear_colors`(반대쪽 끝 → 끝 줄무늬 + 윤곽선색) 자동이라 그림을 바꿔도 재측정 불필요. 끝점은 무기 = 손잡이에서 가장 먼 모서리, 주먹·발 = 몸(리그 원점)에서 가장 먼 모서리(`_far_corner_from_rig`). 조명은 받는다. 층간소음 3타(아이 드롭킥)는 리그 밖이라 띠 없음. **굵기·진하기**(2026-10-10 "진하게, 굵게"): `weapon_smear_width` 1.8(조각 길이의 배수 — 몸 쪽으로 넓힘), `weapon_smear_saturation` 1.6·`weapon_smear_value` 0.88(`_deepen_smear_colors`), `WeaponSmear` 진하기 1.0·테두리 3px
