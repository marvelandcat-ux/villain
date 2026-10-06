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
