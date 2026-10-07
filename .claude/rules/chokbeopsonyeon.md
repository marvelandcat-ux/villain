---
paths:
  - "characters/chokbeopsonyeon/**"
  - "sprite/금쪽이/**"
  - "skills/DashSkill.gd"
  - "skills/BBGunSkill.gd"
  - "skills/HealSkill.gd"
  - "combat/BikeWreck.gd"
---

# 금쪽이(촉법소년)

- **금쪽이 = 촉법소년의 표시 이름(키).** 바꿀 땐 전부: `GameState`(CHARACTERS·색·초상화·리그), `ChokbeopsonyeonStats.tres`, `CharacterSelect.tscn`, `CharacterDex.tscn`, `PortraitFrames.tscn`, `Stage.knockout_characters`, `sprite/도감/전신/금쪽이.png`
- **평타 판정은 금쪽이 기준이 전 캐릭터 기준** — 금쪽이 평타 값을 바꾸면 전 캐릭터 기준이 바뀐다. `AttackData` `hits`는 지금 금쪽이만 씀
- 자전거 `DashSkill`: 속도 = 이동속도 x `dash_speed_multiplier`. 상대를 들이받아도 자기 피해 없음(벽 자해는 있음). 스피드 라인 `wind_lines`(SpeedLines.gd, **몸을 따라감** — 길이 `follow_length`)는 켜고 뒷바퀴 바람 줄기 `takeoff_wind`만 끔(2026-10-07), 잔상 간격 `trail_interval` 0.07
  - 탈 때 리그 전체를 `ride_lift`(7px)만큼 올린다 — 바퀴 바닥(실측 리그 y≈36.8)이 콜라이더 바닥(+30) 아래로 묻혀서. **자전거 그림·`Bike` 자리를 바꾸면 다시 잴 것**
  - 들이받으면 `combat/BikeWreck.gd`: 조각 하나만 튀어 남고 나머지는 `break_bike()`. 조각 그림은 원본 `자전거.png`와 **같은 캔버스**(자전거 그림을 바꾸면 조각도 다시)
- 비비탄 `BBGunSkill`: 꺼내기(`draw_time`, 0 금지) → 쏘기 → 넣기. `play_gun_motion(전체, 꺼내는, 넣는)`. 방향은 **매 발 그때의 `facing`**(쏘는 중 돌아서면 돌아선 쪽으로 — 2026-10-07 요청)
- 막대사탕: `HandRHold/Candy` rotation 45도 + 후리기 45도가 한 쌍, `attack_raise_deg` 음수, 사탕 z_index 없음
- 허트박스 윗끝은 프로펠러 빼고 머리 꼭대기. 머리 앵커도 프로펠러 제외
- 컷인: 원래 머리 복원 → `set_action_face(true)` 순서
- 오타 파일명 그대로: `축법소년 픅면 2.png`, `금쪾이 몸 측면3.png`
