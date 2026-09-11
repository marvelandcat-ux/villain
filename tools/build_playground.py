# -*- coding: utf-8 -*-
import io, math, os
os.chdir(r"D:\11번 조동슬\힐끗광산\힐끗산광\villain")


def poly(pts):
    return "PackedVector2Array(" + ", ".join("%.1f, %.1f" % (a, b) for a, b in pts) + ")"


def rect(x0, y0, x1, y1):
    return poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)])


def ellipse(cx, cy, rx, ry, seg=16):
    return poly([(cx + rx * math.cos(2 * math.pi * i / seg),
                  cy + ry * math.sin(2 * math.pi * i / seg)) for i in range(seg)])


def pnode(name, parent, color, pg, z=None):
    s = '[node name="%s" type="Polygon2D" parent="%s"]\n' % (name, parent)
    if z is not None:
        s += "z_index = %d\n" % z
    return s + 'color = Color(%s)\npolygon = %s\n\n' % (color, pg)


HALF, GROUND = 960.0, 280.0
# 2026-09-10: 사용자가 편집기에서 구름 **그림**을 위로 크게 올려놨길래, 그 그림 위치에
# 발판(충돌)을 맞춰 넣었다. 아래 값은 옮겨진 그림에서 역산한 것이다 —
# 그림 윗면 + CLOUD_SINK = 발판 윗면
ROOF_Y, MID_Y, TOP_Y = -82.0, -252.0, -398.0
# 지붕 판정 폭은 그림(폭 407)보다 조금 좁게 잡아, 발판 끝이 지붕 처마 안쪽에 들어오게 한다
PAV_CX, PAV_HALF = 510.0, 195.0
SPRING_X = 680.0

# --- 정자 그림(`정자.png`) ---
## 알파 bbox. 캔버스 1254x1254의 가장자리 여백을 잘라낸 것
PAV_BBOX = (15, 17, 1224, 1126)
## 지붕 **가운데** 윗면이 bbox 위에서 몇 %(0~1) 지점인지. bbox 맨 위(0%)는 양끝이 치켜올라간
## 처마 끝이라 거길 기준으로 잡으면 캐릭터가 허공에 뜬다 — 가운데 20% 구간을 훑어서 잰 값을 쓴다
PAV_RIDGE_F = (54 - 17) / 1126.0
## 지붕 덩어리와 맨기둥을 가르는 텍스처 y. `PAV_POST_ALPHA`가 1보다 작을 때만 쓴다 —
## 350은 공포(브래킷)가 기둥 굵기까지 가늘어지는 지점이라, 알파가 바뀌는 이음매가
## "기둥이 지붕에 꽂히는 마디"로 보여서 티가 안 난다
PAV_CUT_Y = 350
## 기둥 투명도. **1.0이면 잘라 그리지 않고 한 장으로 그린다.**
## 원래는 "기둥은 흐릿하게만 보여서 게임상 사실상 없는 취급"이라 0.5였는데,
## 정자 그림을 넣고 보니 기둥이 얇고 사이가 넓어서 막는 것처럼 안 보였다 —
## 2026-09-10 사용자 판단으로 그냥 불투명하게 바꿨다(기둥에 충돌이 없다는 건 그대로)
PAV_POST_ALPHA = 1.0
# 구름은 이제 좌우 대칭이 아니다(사용자가 오른쪽 구름을 바깥으로 더 밀어놨다)
MID_LEFT_CX, MID_RIGHT_CX = -254.0, 338.0
TOP_CX = 22.0
MID_HALF, TOP_HALF = 130.0, 150.0
SAND = [(-220.0, 110.0), (220.0, 110.0)]
THICK = 20.0
# 모래사장 그림(`모래사장 (2).png`) 배치.
# 알파 bbox는 Rect2(53, 329, 2066, 165) — 가로로 12.5:1이나 되는 아주 납작한 그림이다.
SAND_BBOX = (53, 329, 2066, 165)
## 모래 윗면이 bbox 위에서 몇 %(0~1) 지점인지. 가운데 세로줄을 훑어 잰 값 —
## 이 줄이 지면(y=280)에 오도록 맞춰야 캐릭터가 모래를 밟고 선 것처럼 보이고,
## 빨간 나무틀은 땅에 묻힌 것처럼 아래로 내려간다
SAND_SURFACE_F = (364 - 329) / 165.0
## 화면상 그림 크기. 모래밭 판정이 220 폭이라 그보다 조금 넓게 잡아 턱이 보이게 한다.
## 높이는 원본 비율(19px)보다 키워야 나무결·모래알이 보인다 — 세로로 늘여 쓴다
SAND_W, SAND_H = 244.0, 30.0
# 구름 발판 그림 튜닝: 발판 폭 대비 그림 폭 배율 / 그림 폭 대비 그림 높이 / 발판 윗면과 겹치는 양(px)
CLOUD_WIDEN, CLOUD_ASPECT, CLOUD_SINK = 1.32, 0.26, 4.0
# 발판 종류 -> (ExtResource id, 알파 bbox x, y, w, h, 화면상 그림 크기).
# bbox로 잘라내야 캔버스 여백까지 세지 않아서 "그림 폭 = 발판 폭 x CLOUD_WIDEN"이 맞는다.
# 마지막 칸이 None이면 CLOUD_WIDEN/CLOUD_ASPECT로 자동 계산하고, (w, h)를 적으면 그 값을 그대로 쓴다 —
# 꼭대기 구름은 사용자가 편집기에서 직접 줄여놓은 크기라 자동 계산 대신 실측값을 박아둔다
CLOUDS = {
    "cloud_top": ("12", 71, 111, 1643, 687, (355.3, 62.4)),  # 구름1.png — 가운데가 봉긋, 왕관 받침
    "cloud_left": ("13", 99, 53, 1978, 622, None),           # 구름2.png — 가장 길고 납작한 모양
    "cloud_right": ("14", 34, 142, 1604, 662, None),         # 구름3.png — 왼쪽이 높고 오른쪽으로 흘러내림
}

# --- 편집기에서 손으로 맞춘 값 (2026-09-12) ---
# 사용자가 편집기에서 구름 콜리전·그림과 왕관을 직접 옮겨놨다. 아래 platform() 공식으로는 안 나오는 배치라
# **공식 대신 이 값을 그대로 박는다.** 이 표를 지우고 빌더를 다시 돌리면 편집기에서 맞춘 게 공식값으로 되돌아간다.
# 편집기에서 또 옮겼으면 그 씬의 값을 여기로 옮겨 적을 것 (구름 루트 위치는 여전히 *_CX / *_Y 공식을 쓴다)
# 이름 -> collision_pos: 콜리전 위치(루트 기준) / collision_size: 콜리전 크기 /
#        visual: (ExtResource id, 그림 위치, 그림 배율, region_rect)
# CloudMidRight는 구름3 대신 구름2(왼쪽 구름과 같은 그림)로 바꿨다 — 사용자 결정
PLATFORM_OVERRIDES = {
    "CloudMidLeft": {"collision_pos": (-6, 24), "collision_size": (260, 20),
        "visual": ("13", (4, 30.999994), (0.173509, 0.14346), (99, 53, 1978, 622))},  # 구름2.png
    "CloudMidRight": {"collision_pos": (16, 25), "collision_size": (260, 20),
        "visual": ("13", (13.000058, 13.000002), (0.137203, 0.143409), (99, 53, 1978, 622))},  # 구름2.png
    "CloudTop": {"collision_pos": (8, -22), "collision_size": (288, 16),
        "visual": ("12", (7.999996, -17.000004), (0.19698735, 0.1385736), (71, 111, 1643, 687))},  # 구름1.png
}
# 왕관 **본체** 위치와 그림 오프셋. 콜리전은 본체 원점에 둔다 —
# 자식만 옮기면 Crown.gd가 본체 기준으로 머리 위·바닥에 놓을 때 그만큼 떠버린다
CROWN_POS = (25, -472)
CROWN_VISUAL_OFFSET = (0, -1)


# --- 배경 아파트 단지 ---
# 그림 종류 -> (ExtResource id, 알파 bbox x, y, w, h)
APT_SPRITES = {
    "a1": ("19", 51, 38, 992, 1375),    # 아파트1동.png — 넓고 낮은 10층, "1동" 간판·현관 있음
    "a2": ("20", 282, 9, 468, 1513),    # 아파트2동.png — 제일 좁고 높은 20층
    "a3": ("21", 192, 12, 641, 1487),   # 아파트3동.png — 중간, 세로 줄무늬
}
# (그림 종류, 중심 x, 화면상 높이, haze)
#
# **지붕 높이를 구름 발판과 안 겹치게 고른 것이 핵심이다.** 구름 발판은 흰색 + 검은 테두리라
# 밝은 베이지 벽면 위에 오면 대비가 죽는다. 그래서 구름과 가로로 겹치는 동은 지붕을 구름 **아래**로
# 낮추고, 구름보다 높이 솟는 동은 구름이 없는 바깥쪽에만 뒀다. 아래 `check_apartments()`가 매번 검산한다.
#   중간 구름: 왼쪽 x -425~-83 / 오른쪽 x 167~509, 세로 y -256~-167
#   꼭대기 구름: x -155~200, 세로 y -402~-340
#
# **`a1`은 딱 한 동만 쓴다.** 그림에 "1동" 간판이 박혀 있어서 여러 번 쓰면 단지 안에 1동이 세 채가 된다.
# 나머지는 간판 없는 `a2`/`a3`로 채운다
APARTMENTS = [
    ("a2", -1120, 700, 0.30),
    ("a3", -860, 560, 0.24),
    ("a3", -580, 430, 0.16),
    ("a2", -300, 410, 0.10),   # 중간 구름L 아래
    ("a1", 40, 400, 0.10),     # 꼭대기 구름 아래 — 유일한 "1동"
    ("a3", 340, 420, 0.10),    # 중간 구름R 아래
    ("a2", 700, 500, 0.16),
    ("a3", 990, 660, 0.24),
    ("a2", 1230, 580, 0.30),
]
SKY_COLOR = "0.63, 0.81, 0.95, 1"
## 구름 발판이 차지하는 가로/세로 범위 (검산용)
CLOUD_ZONES = [(-425.0, -83.0, -167.0), (167.0, 509.0, -167.0), (-155.0, 200.0, -340.0)]

# --- 울타리 그림(`덜촘촘한울타리.png`) ---
## **이음매가 맞는 한 칸**. 그림 안에 기둥이 5개 있고 중심이 40 / 554 / 1085 / 1615 / 2136인데,
## **양 끝 기둥은 캔버스에 잘려 있어서**(폭 71, 안쪽 기둥은 73) 중심값을 믿을 수가 없다 —
## 그래서 온전히 찍힌 **안쪽 기둥 554와 1615**를 기준으로 자른다. 그 사이가 1061 = 530.5 x 2칸이다.
## 양 끝이 기둥 한가운데를 지나므로, 이어붙이면 반쪽 + 반쪽이 온전한 기둥 하나가 된다.
## **캔버스 통째로(0~2171) 붙이면 안 된다** — 잘린 기둥끼리 만나서 간격이 틀어진다
FENCE_REGION = (554, 54, 1061, 588)
## 화면에 그려질 울타리 높이(px). 캐릭터 키가 60px이라 그보다 조금 높게 잡아야 울타리로 읽힌다
FENCE_H = 84.0
## 울타리 아랫변이 놓일 y (지면과 같게)
FENCE_BOTTOM = GROUND
## 좌우로 이만큼까지 깔아둔다. 벽이 ±960이지만 카메라가 더 바깥까지 비출 수 있어 넉넉히 잡는다
FENCE_SPAN = 1360.0

def check_apartments():
    """아파트 지붕이 구름 발판을 가리지 않는지 검산한다.

    구름은 흰색 + 검은 테두리라 밝은 벽면 위에 오면 테두리만 남고 뭉개진다.
    높이를 손으로 고르는 값이라, 한 번 어긋나면 눈으로는 잘 안 보이면서 발판만 안 읽히게 된다
    """
    bad = []
    for kind, cx, vis_h, _haze in APARTMENTS:
        _id, _bx, _by, bw, bh = APT_SPRITES[kind]
        half = bw * (vis_h / bh) * 0.5
        roof = GROUND - vis_h
        for zx0, zx1, floor_y in CLOUD_ZONES:
            if cx - half < zx1 and cx + half > zx0 and roof < floor_y:
                bad.append("  x=%g(폭 %.0f) 지붕 %.0f 이 구름구역 %g~%g(아랫변 %g)을 침범"
                           % (cx, half * 2, roof, zx0, zx1, floor_y))
    if bad:
        print("!! 아파트가 구름 발판을 가림:")
        for line in bad:
            print(line)
    else:
        print("  아파트 9동 전부 구름 발판을 안 가림 (검산 통과)")


subs, plats = [], []


def platform(name, cx, top, half, kind):
    # 편집기에서 손으로 맞춘 값이 있으면 공식 대신 그걸 쓴다 (PLATFORM_OVERRIDES 설명 참고)
    ov = PLATFORM_OVERRIDES.get(name, {})
    cw, ch = ov.get("collision_size", (half * 2, THICK))
    subs.append('[sub_resource type="RectangleShape2D" id="Shape_%s"]\nsize = Vector2(%g, %g)\n'
                % (name, cw, ch))
    s = '[node name="%s" type="StaticBody2D" parent="."]\nposition = Vector2(%g, %g)\n\n' % (name, cx, top + THICK / 2)
    cpos = ov.get("collision_pos")
    s += ('[node name="Collision" type="CollisionShape2D" parent="%s"]\n%sshape = SubResource("Shape_%s")\n'
          'one_way_collision = true\n\n' % (name, ('position = Vector2(%g, %g)\n' % cpos) if cpos else '', name))
    if kind == "roof":
        pass  # 지붕 그림은 `pavilion_sprites()`가 부모 Node2D에 따로 그린다(기둥과 투명도가 달라서)
    elif "visual" in ov:
        ext_id, (vx, vy), (sx, sy), (bx, by, bw, bh) = ov["visual"]
        s += ('[node name="Visual" type="Sprite2D" parent="%s"]\nposition = Vector2(%g, %g)\n'
              'scale = Vector2(%g, %g)\ntexture = ExtResource("%s")\n'
              'region_enabled = true\nregion_rect = Rect2(%g, %g, %g, %g)\n\n'
              % (name, vx, vy, sx, sy, ext_id, bx, by, bw, bh))
    else:
        ext_id, bx, by, bw, bh, fixed = CLOUDS[kind]
        if fixed:
            vis_w, vis_h = fixed
        else:
            vis_w = half * 2 * CLOUD_WIDEN
            # **세로는 원본 비율을 따르지 않고 목표 높이로 맞춘다.** 구름 세 장의 원본 비율이
            # 2.39 / 3.18 / 2.42로 제각각이라, 같은 배율을 쓰면 발판마다 구름 두께가 눈에 띄게 달라진다.
            # 게다가 원본 비율 그대로면 폭 260짜리 구름이 높이 109px이 되어, 층 간격 170px을
            # 거의 다 잡아먹고 위아래 구름이 서로 닿는다
            vis_h = vis_w * CLOUD_ASPECT
        sx, sy = vis_w / bw, vis_h / bh
        # 그림 윗면을 발판 윗면에 맞춘다(살짝 겹쳐서 발이 구름에 파묻히게).
        # 노드 원점이 발판 윗면보다 THICK/2 아래라 그만큼 되돌려 계산한다
        s += ('[node name="Visual" type="Sprite2D" parent="%s"]\nposition = Vector2(0, %.1f)\n'
              'scale = Vector2(%.6f, %.6f)\ntexture = ExtResource("%s")\n'
              'region_enabled = true\nregion_rect = Rect2(%g, %g, %g, %g)\n\n'
              % (name, -THICK / 2 + vis_h / 2 - CLOUD_SINK, sx, sy, ext_id, bx, by, bw, bh))
    plats.append(s)


header = (
    '[gd_scene load_steps=SUBCOUNT format=3]\n\n'
    '[ext_resource type="Script" path="res://maps/Stage.gd" id="1"]\n'
    '[ext_resource type="PackedScene" path="res://ui/CombatHUD.tscn" id="2"]\n'
    '[ext_resource type="Script" path="res://maps/CameraRig.gd" id="3"]\n'
    '[ext_resource type="PackedScene" path="res://maps/SpringRide.tscn" id="4"]\n'
    '[ext_resource type="Texture2D" path="res://sprite/\ub9f5/\ub180\uc774\ud130/\uc9c4\uc9dc\uc655\uad00.png" id="5"]\n'
    '[ext_resource type="Texture2D" path="res://sprite/\ub9f5/\ub180\uc774\ud130/\ud30c\ub780\uc2dc\uc18c.png" id="7"]\n'
    '[ext_resource type="Script" path="res://maps/SandPit.gd" id="8"]\n'
    '[ext_resource type="Script" path="res://maps/Crown.gd" id="9"]\n'
    '[ext_resource type="PackedScene" path="res://ui/CrownCutIn.tscn" id="10"]\n'
    '[ext_resource type="PackedScene" path="res://maps/Swing.tscn" id="11"]\n'
    '[ext_resource type="Texture2D" path="res://sprite/맵/놀이터/구름1.png" id="12"]\n'
    '[ext_resource type="Texture2D" path="res://sprite/맵/놀이터/구름2.png" id="13"]\n'
    '[ext_resource type="Texture2D" path="res://sprite/맵/놀이터/구름3.png" id="14"]\n'
    '[ext_resource type="Texture2D" path="res://sprite/맵/놀이터/모래사장 (2).png" id="15"]\n'
    '[ext_resource type="Texture2D" path="res://sprite/맵/놀이터/정자.png" id="16"]\n'
    '[ext_resource type="Texture2D" path="res://sprite/맵/놀이터/덜촘촘한울타리.png" id="18"]\n'
    '[ext_resource type="Texture2D" path="res://sprite/맵/놀이터/아파트1동.png" id="19"]\n'
    '[ext_resource type="Texture2D" path="res://sprite/맵/놀이터/아파트2동.png" id="20"]\n'
    '[ext_resource type="Texture2D" path="res://sprite/맵/놀이터/아파트3동.png" id="21"]\n\n')

subs.append('[sub_resource type="RectangleShape2D" id="Shape_ground"]\nsize = Vector2(%g, 40)\n' % (HALF * 2))
subs.append('[sub_resource type="RectangleShape2D" id="Shape_wall"]\nsize = Vector2(40, 400)\n')
subs.append('[sub_resource type="RectangleShape2D" id="Shape_sand"]\nsize = Vector2(220, 40)\n')
subs.append('[sub_resource type="RectangleShape2D" id="Shape_crown"]\nsize = Vector2(56, 34)\n')

# texture_filter = 4 는 "Linear with Mipmaps".
# **이걸 안 켜면 그림에 밉맵을 만들어놔도 안 쓴다** — 캔버스 기본 필터는 밉맵을 안 보기 때문이다.
# 이 맵의 그림은 전부 1000~2000px 원본을 84~700px로 줄여 그려서(울타리는 0.14배!),
# 밉맵 없이는 카메라가 조금만 움직여도 철망·창문 격자가 프레임마다 지글거린다.
# 루트에 걸어두면 CanvasItem 자식들이 전부 물려받는다(HUD·컷인은 CanvasLayer라 안 물려받고 기본값 유지)
b = ('[node name="Playground" type="Node2D"]\ntexture_filter = 4\n'
     'script = ExtResource("1")\nstage_width = %g\n\n' % (HALF * 2))
b += '[node name="DecoSky" type="Node2D" parent="."]\nz_index = -10\n\n'
b += pnode("Sky", "DecoSky", "0.63, 0.81, 0.95, 1", rect(-2200, -900, 2200, 285))
b += pnode("Dirt", "DecoSky", "0.42, 0.3, 0.19, 1", rect(-2200, 280, 2200, 900))
b += pnode("Sun", "DecoSky", "1, 0.93, 0.55, 1", ellipse(760, -560, 44, 44, 10))

# 아파트는 하늘(-10)보다 앞, 구름·나무·울타리(-8)보다 뒤.
# 장식 구름이 아파트 앞으로 지나가야 "구름이 더 멀리 있다"가 아니라 "아파트가 저 멀리 서 있다"로 읽힌다
b += '[node name="DecoCity" type="Node2D" parent="."]\nz_index = -9\n\n'
for i, (kind, cx, vis_h, haze) in enumerate(APARTMENTS):
    ext_id, bx, by, bw, bh = APT_SPRITES[kind]
    sc = vis_h / bh
    vis_w = bw * sc
    roof = GROUND - vis_h
    b += ('[node name="Tower%d" type="Sprite2D" parent="DecoCity"]\nposition = Vector2(%g, %.1f)\n'
          'scale = Vector2(%.6f, %.6f)\ntexture = ExtResource("%s")\n'
          'region_enabled = true\nregion_rect = Rect2(%g, %g, %g, %g)\n\n'
          % (i, cx, roof + vis_h * 0.5, sc, sc, ext_id, bx, by, bw, bh))
    # **원경 흐리기.** modulate는 곱셈이라 그림을 밝게(하늘색 쪽으로) 못 만든다.
    # 대신 하늘과 **똑같은 색** 판을 그 동 위에만 덮는다 — 하늘 위에서는 같은 색이라 안 보이고,
    # 건물 위에서만 색이 옅어져서 멀리 있는 것처럼 물러난다
    if haze > 0.0:
        b += pnode("Haze%d" % i, "DecoCity", "%s, %g" % (SKY_COLOR.rsplit(",", 1)[0], haze),
                   rect(cx - vis_w * 0.5, roof, cx + vis_w * 0.5, GROUND))

# **생울타리는 2026-09-10에 뺐다.** 원래는 흰 울타리가 밝은 아파트 벽에 묻혀서, 사이에 어두운 초록 띠를
# 깔아 대비를 만들려고 넣은 층이었다. 그런데 울타리를 초록 철망 그림(`울타리.png`)으로 바꾸고 나니
# **철망이 뚫려 있어서 뒤의 생울타리가 그대로 비쳐, 울타리 전체가 초록 판때기로 보였다.**
# 이제 울타리 자체가 어두운 초록이라 대비도 필요 없다 — 철망 너머로 아파트가 보이는 게 맞는 그림이다

b += '[node name="DecoBack" type="Node2D" parent="."]\nz_index = -8\n\n'
for i, (cx, cy, sc) in enumerate([(-700, -520, 0.9), (-330, -620, 0.7), (430, -560, 1.0), (830, -430, 0.65)]):
    for j, (dx, dy, rx, ry) in enumerate([(-46, 6, 46, 26), (0, -10, 52, 34), (48, 4, 42, 24)]):
        b += pnode("SkyCloud%d_%d" % (i, j), "DecoBack", "0.99, 0.99, 1, 0.9",
                   ellipse(cx + dx * sc, cy + dy * sc, rx * sc, ry * sc))
for i, x in enumerate([-934, -868, 880, 940]):
    b += pnode("TreeTrunk%d" % i, "DecoBack", "0.42, 0.29, 0.18, 1", rect(x - 9, -150, x + 9, 285))
    leaf = "0.29, 0.55, 0.27, 1" if i % 2 == 0 else "0.34, 0.62, 0.31, 1"
    for j, (dx, dy, r) in enumerate([(-34, -6, 44), (0, -46, 50), (34, -2, 42)]):
        b += pnode("TreeLeaf%d_%d" % (i, j), "DecoBack", leaf, ellipse(x + dx, -150 + dy, r, r, 12))
# 초록 철망 울타리. 한 칸(기둥 4칸)씩 잘라 옆으로 이어붙인다
frx, fry, frw, frh = FENCE_REGION
fence_scale = FENCE_H / frh
tile_w = frw * fence_scale
i, x = 0, -FENCE_SPAN
while x < FENCE_SPAN:
    b += ('[node name="FenceTile%d" type="Sprite2D" parent="DecoBack"]\nposition = Vector2(%.2f, %.2f)\n'
          'scale = Vector2(%.6f, %.6f)\ntexture = ExtResource("18")\n'
          'region_enabled = true\nregion_rect = Rect2(%g, %g, %g, %g)\n\n'
          % (i, x + tile_w * 0.5, FENCE_BOTTOM - FENCE_H * 0.5,
             fence_scale, fence_scale, frx, fry, frw, frh))
    x += tile_w
    i += 1

def pavilion_sprites(parent, cx):
    """정자 그림을 붙인다.

    `PAV_POST_ALPHA`가 1이면 `Visual` 한 장, 1보다 작으면 지붕(불투명)/기둥(반투명)
    **두 조각으로 잘라** 붙인다 — 통째로 반투명하게 하면 진짜 발판인 지붕까지 없는 것처럼 보이기 때문.
    """
    bx, by, bw, bh = PAV_BBOX
    # "지붕 가운데 윗면 -> ROOF_Y" 와 "그림 맨 아래 -> 지면" 두 조건이 크기와 위치를 동시에 정한다
    vis_h = (GROUND - ROOF_Y) / (1.0 - PAV_RIDGE_F)
    sc = vis_h / bh
    top = ROOF_Y - PAV_RIDGE_F * vis_h          # 그림 맨 위(치켜올라간 처마 끝)의 y
    if PAV_POST_ALPHA >= 1.0:
        pieces = [("Visual", by, bh, top + bh * sc * 0.5, 1.0)]
    else:
        roof_h = PAV_CUT_Y - by
        post_h = bh - roof_h
        pieces = [("Roof", by, roof_h, top + roof_h * sc * 0.5, 1.0),
                  ("Posts", PAV_CUT_Y, post_h, top + (roof_h + post_h * 0.5) * sc, PAV_POST_ALPHA)]
    out = ""
    for tag, ry, rh, cy, alpha in pieces:
        out += '[node name="%s" type="Sprite2D" parent="%s"]\nposition = Vector2(%g, %.2f)\n' % (tag, parent, cx, cy)
        if alpha < 1.0:
            out += "modulate = Color(1, 1, 1, %g)\n" % alpha
        out += ('scale = Vector2(%.6f, %.6f)\ntexture = ExtResource("16")\n'
                'region_enabled = true\nregion_rect = Rect2(%g, %g, %g, %g)\n\n' % (sc, sc, bx, ry, bw, rh))
    return out


for side in (-1, 1):
    cx = PAV_CX * side
    nm = "PavilionLeft" if side < 0 else "PavilionRight"
    b += '[node name="%s" type="Node2D" parent="."]\nz_index = -1\n\n' % nm
    b += pavilion_sprites(nm, cx)
    platform(nm + "Roof", cx, ROOF_Y, PAV_HALF, "roof")

platform("CloudMidLeft", MID_LEFT_CX, MID_Y, MID_HALF, "cloud_left")
platform("CloudMidRight", MID_RIGHT_CX, MID_Y, MID_HALF, "cloud_right")
platform("CloudTop", TOP_CX, TOP_Y, TOP_HALF, "cloud_top")
for p in plats:
    b += p

b += ('[node name="Crown" type="Area2D" parent="."]\nz_index = 20\nposition = Vector2(%g, %g)\n'
      'script = ExtResource("9")\n\n'
      '[node name="CrownCollision" type="CollisionShape2D" parent="Crown"]\nshape = SubResource("Shape_crown")\n\n'
      # 진짜왕관.png의 알파 bbox는 캔버스 정중앙이 아니다(+23, +10). region으로 잘라내면
      # Sprite2D가 그 조각을 중심에 놓아주므로, 왕관이 판정 상자 한가운데에 정확히 앉는다
      '[node name="CrownVisual" type="Sprite2D" parent="Crown"]\n%sscale = Vector2(0.04455, 0.04455)\n'
      'texture = ExtResource("5")\nregion_enabled = true\n'
      'region_rect = Rect2(163, 150, 1257, 746)\n\n') % (
      CROWN_POS[0], CROWN_POS[1],
      ('position = Vector2(%g, %g)\n' % CROWN_VISUAL_OFFSET) if CROWN_VISUAL_OFFSET != (0.0, 0.0) else '')

b += '[node name="SpringRideLeft" parent="." instance=ExtResource("4")]\nposition = Vector2(%g, 0)\n\n' % (-SPRING_X)
b += '[node name="SpringRideRight" parent="." instance=ExtResource("4")]\nposition = Vector2(%g, 0)\n\n' % SPRING_X
b += ('[node name="Sprite" parent="SpringRideRight/Visual" index="0"]\n'
      'position = Vector2(-28.29, -81.16)\nscale = Vector2(0.078261, 0.078261)\n'
      'texture = ExtResource("7")\nregion_rect = Rect2(173, 17, 1142, 1056)\n\n')

b += '[node name="Ground" type="StaticBody2D" parent="."]\nposition = Vector2(0, 300)\n\n'
b += '[node name="GroundCollision" type="CollisionShape2D" parent="Ground"]\nshape = SubResource("Shape_ground")\n\n'
b += pnode("GroundVisual", "Ground", "0.52, 0.38, 0.24, 1", rect(-HALF, -20, HALF, 20))
b += pnode("GrassVisual", "Ground", "0.45, 0.68, 0.33, 1", rect(-HALF, -20, HALF, -10))
for i, (cx, half) in enumerate(SAND):
    # `Ground` 노드가 y=300에 있으므로 지면 윗면은 로컬 y=-20이다.
    # 그림의 "모래 윗면" 줄이 거기 오도록 중심을 역산한다
    sbx, sby, sbw, sbh = SAND_BBOX
    center_y = -20.0 + SAND_H * (0.5 - SAND_SURFACE_F)
    b += ('[node name="SandVisual%d" type="Sprite2D" parent="Ground"]\nposition = Vector2(%g, %.2f)\n'
          'scale = Vector2(%.6f, %.6f)\ntexture = ExtResource("15")\n'
          'region_enabled = true\nregion_rect = Rect2(%g, %g, %g, %g)\n\n'
          % (i, cx, center_y, SAND_W / sbw, SAND_H / sbh, sbx, sby, sbw, sbh))

b += '[node name="DecoGround" type="Node2D" parent="."]\n\n'
j = 0
for x in range(-930, 940, 46):
    if any(abs(x - cx) < half + 10 for cx, half in SAND) or abs(x) < 120:
        continue
    b += pnode("Tuft%d" % j, "DecoGround", "0.36, 0.6, 0.27, 1", poly([(x, 280), (x + 5, 262), (x + 10, 280)]))
    j += 1
# 모래통 위 빨간 양동이(Bucket*/BucketRim*)는 2026-09-11 사용자 요청으로 뺐다

for i, (cx, half) in enumerate(SAND):
    b += ('[node name="SandPit%d" type="Area2D" parent="."]\nposition = Vector2(%g, 276)\n'
          'script = ExtResource("8")\n\n' % (i, cx))
    b += '[node name="Collision" type="CollisionShape2D" parent="SandPit%d"]\nshape = SubResource("Shape_sand")\n\n' % i

b += '[node name="Swing" parent="." instance=ExtResource("11")]\nposition = Vector2(0, %g)\n\n' % GROUND

# 맵 밖으로 못 나가게 막는 벽. **그림 없이 충돌만 둔다**(사용자 요청) —
# 예전에는 초록 기둥(`Visual` Polygon2D)을 세워놨는데, 놀이터 울타리·나무가 이미 경계를 그리고 있어서
# 그 위에 벽까지 그리면 "여기가 끝"이 두 번 겹쳐 보였다. 편집기에서는 CollisionShape2D가 보이므로
# 위치를 만지는 데는 지장이 없다
for nm, x in (("LeftWall", -HALF), ("RightWall", HALF)):
    b += '[node name="%s" type="StaticBody2D" parent="."]\nposition = Vector2(%g, 100)\n\n' % (nm, x)
    b += '[node name="Collision" type="CollisionShape2D" parent="%s"]\nshape = SubResource("Shape_wall")\n\n' % nm

b += ('[node name="PlayerSpawn1" type="Marker2D" parent="."]\nposition = Vector2(-560, 240)\n\n'
      '[node name="PlayerSpawn2" type="Marker2D" parent="."]\nposition = Vector2(560, 240)\n\n'
      '[node name="Camera2D" type="Camera2D" parent="."]\nposition = Vector2(0, 20)\n'
      # lock_ground_to_bottom: 멀리 볼수록 아래 흙이 두꺼워지던 걸 막는다(흙은 화면 아래 56px로 고정)
      'script = ExtResource("3")\nmin_y = -300.0\nmax_y = 20.0\n'
      'lock_ground_to_bottom = true\nground_y = 280.0\nground_margin_px = 56.0\n\n'
      '[node name="CombatHUD" parent="." instance=ExtResource("2")]\n\n'
      '[node name="CrownCutIn" parent="." instance=ExtResource("10")]\n')

check_apartments()
header = header.replace("SUBCOUNT", str(21 + len(subs)))
io.open("maps/Playground.tscn", "w", encoding="utf-8").write(header + "".join(subs) + "\n" + b)
print("OK Playground.tscn rebuilt")
print("  roof y=%g x=%g..%g / mid cloud y=%g / top cloud y=%g" % (
    ROOF_Y, PAV_CX - PAV_HALF, PAV_CX + PAV_HALF, MID_Y, TOP_Y))
