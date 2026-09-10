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

# --- 배경 아파트 단지 ---
# (중심 x, 반폭, 지붕 y, 벽색, 창색, haze)
#
# **지붕 높이를 구름 발판과 안 겹치게 고른 것이 핵심이다.** 구름 발판은 흰색 + 검은 테두리라
# 밝은 베이지 벽면 위에 오면 대비가 죽는다. 그래서 구름과 가로로 겹치는 동은 지붕을 구름 **아래**로
# 낮추고, 구름보다 높이 솟는 동은 구름이 없는 바깥쪽(|x| > 750)에만 뒀다.
#   중간 구름: 왼쪽 x -425~-83 / 오른쪽 x 167~509, 세로 y -256~-167
#   꼭대기 구름: x -155~200, 세로 y -402~-340
APARTMENTS = [
    (-1090, 185, -480, "0.80, 0.82, 0.86", "0.68, 0.75, 0.82", 0.34),
    (-840, 150, -350, "0.88, 0.85, 0.78", "0.60, 0.70, 0.78", 0.22),
    (-600, 145, -255, "0.84, 0.86, 0.87", "0.58, 0.69, 0.77", 0.17),
    (-300, 160, -150, "0.90, 0.87, 0.79", "0.62, 0.72, 0.79", 0.10),   # 중간 구름L 아래
    (20, 175, -172, "0.86, 0.83, 0.77", "0.57, 0.68, 0.76", 0.10),     # 꼭대기 구름 훨씬 아래
    (330, 165, -148, "0.89, 0.88, 0.84", "0.60, 0.71, 0.78", 0.10),    # 중간 구름R 아래
    (650, 140, -265, "0.85, 0.81, 0.74", "0.58, 0.69, 0.77", 0.16),
    (940, 150, -390, "0.83, 0.85, 0.88", "0.62, 0.72, 0.80", 0.24),
    (1180, 180, -470, "0.80, 0.81, 0.85", "0.66, 0.74, 0.81", 0.33),
]
SKY_COLOR = "0.63, 0.81, 0.95, 1"

subs, plats = [], []


def platform(name, cx, top, half, kind):
    subs.append('[sub_resource type="RectangleShape2D" id="Shape_%s"]\nsize = Vector2(%g, %g)\n'
                % (name, half * 2, THICK))
    s = '[node name="%s" type="StaticBody2D" parent="."]\nposition = Vector2(%g, %g)\n\n' % (name, cx, top + THICK / 2)
    s += ('[node name="Collision" type="CollisionShape2D" parent="%s"]\nshape = SubResource("Shape_%s")\n'
          'one_way_collision = true\n\n' % (name, name))
    if kind == "roof":
        pass  # 지붕 그림은 `pavilion_sprites()`가 부모 Node2D에 따로 그린다(기둥과 투명도가 달라서)
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
    '[ext_resource type="Shader" path="res://maps/apartment.gdshader" id="17"]\n\n')

subs.append('[sub_resource type="RectangleShape2D" id="Shape_ground"]\nsize = Vector2(%g, 40)\n' % (HALF * 2))
subs.append('[sub_resource type="RectangleShape2D" id="Shape_wall"]\nsize = Vector2(40, 400)\n')
subs.append('[sub_resource type="RectangleShape2D" id="Shape_sand"]\nsize = Vector2(220, 40)\n')
subs.append('[sub_resource type="RectangleShape2D" id="Shape_crown"]\nsize = Vector2(56, 34)\n')

b = '[node name="Playground" type="Node2D"]\nscript = ExtResource("1")\nstage_width = %g\n\n' % (HALF * 2)
b += '[node name="DecoSky" type="Node2D" parent="."]\nz_index = -10\n\n'
b += pnode("Sky", "DecoSky", "0.63, 0.81, 0.95, 1", rect(-2200, -900, 2200, 285))
b += pnode("Dirt", "DecoSky", "0.42, 0.3, 0.19, 1", rect(-2200, 280, 2200, 900))
b += pnode("Sun", "DecoSky", "1, 0.93, 0.55, 1", ellipse(760, -560, 44, 44, 10))

# 아파트는 하늘(-10)보다 앞, 구름·나무·울타리(-8)보다 뒤.
# 장식 구름이 아파트 앞으로 지나가야 "구름이 더 멀리 있다"가 아니라 "아파트가 저 멀리 서 있다"로 읽힌다
b += '[node name="DecoCity" type="Node2D" parent="."]\nz_index = -9\n\n'
for i, (cx, half, roof, wall, win, haze) in enumerate(APARTMENTS):
    w, h = half * 2.0, GROUND - roof
    subs.append('[sub_resource type="ShaderMaterial" id="Mat_apt%d"]\nshader = ExtResource("17")\n'
                'shader_parameter/wall_color = Color(%s, 1)\n'
                'shader_parameter/window_color = Color(%s, 1)\n'
                'shader_parameter/ledge_color = Color(%s, 1)\n'
                'shader_parameter/column_w_px = %g\n'
                'shader_parameter/floor_h_px = 46.0\n'
                'shader_parameter/window_fill = Vector2(0.52, 0.42)\n'
                'shader_parameter/window_center_y = 0.44\n'
                'shader_parameter/ledge_h = 0.13\n'
                'shader_parameter/body_size = Vector2(%g, %g)\n'
                'shader_parameter/side_shade_w = 0.1\n'
                'shader_parameter/side_shade = 0.9\n'
                'shader_parameter/haze = %g\n'
                'shader_parameter/haze_color = Color(%s)\n'
                % (i, wall, win, wall, w / round(w / 62.0), w, h, haze, SKY_COLOR))
    # 폴리곤 로컬 좌표를 (0,0)~(w,h)로 두면 셰이더가 받는 좌표가 곧 "지붕 왼쪽 위에서 몇 px"이 된다
    b += ('[node name="Tower%d" type="Polygon2D" parent="DecoCity"]\nposition = Vector2(%g, %g)\n'
          'material = SubResource("Mat_apt%d")\ncolor = Color(1, 1, 1, 1)\npolygon = %s\n\n'
          % (i, cx - half, roof, i, rect(0, 0, w, h)))
    # 옥상 슬래브 + 물탱크. 이건 동마다 하나씩이라 폴리곤으로 찍어도 부담이 없다
    slab = "%s, 1" % wall
    b += pnode("Roof%d" % i, "DecoCity", slab, rect(cx - half - 9, roof - 11, cx + half + 9, roof))
    b += pnode("Tank%d" % i, "DecoCity", slab, rect(cx - 34, roof - 40, cx + 26, roof - 11))

# 단지 화단(생울타리). **흰 울타리를 살리려고 넣은 층이다** — 아파트 벽이 밝은 베이지라
# 그 위에 흰 울타리를 얹으면 그냥 묻혀서 안 보인다. 사이에 어두운 초록 띠를 깔아 대비를 만들고,
# 겸사겸사 동 밑동을 가려서 "건물이 저 뒤에 서 있다"는 깊이도 생긴다
j, x = 0, -1260
while x < 1260:
    b += pnode("Hedge%d" % j, "DecoCity", "0.20, 0.40, 0.23, 1", ellipse(x, 250, 64, 46, 12))
    x += 88
    j += 1
b += pnode("HedgeBase", "DecoCity", "0.20, 0.40, 0.23, 1", rect(-1300, 248, 1300, 285))

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
b += pnode("FenceRailTop", "DecoBack", "0.86, 0.88, 0.84, 1", rect(-940, 214, 940, 224))
b += pnode("FenceRailBottom", "DecoBack", "0.86, 0.88, 0.84, 1", rect(-940, 250, 940, 260))
i, x = 0, -936
while x < 940:
    b += pnode("FencePost%d" % i, "DecoBack", "0.86, 0.88, 0.84, 1", rect(x, 204, x + 11, 280))
    x += 58
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
      '[node name="CrownVisual" type="Sprite2D" parent="Crown"]\nscale = Vector2(0.04455, 0.04455)\n'
      'texture = ExtResource("5")\nregion_enabled = true\n'
      'region_rect = Rect2(163, 150, 1257, 746)\n\n') % (TOP_CX, TOP_Y - 28)

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
for i, (cx, half) in enumerate(SAND):
    bx = cx + (half * 0.45 if cx < 0 else -half * 0.45)
    b += pnode("Bucket%d" % i, "DecoGround", "0.95, 0.35, 0.3, 1",
               poly([(bx - 16, 278), (bx + 16, 278), (bx + 12, 254), (bx - 12, 254)]))
    b += pnode("BucketRim%d" % i, "DecoGround", "0.99, 0.55, 0.5, 1", rect(bx - 14, 250, bx + 14, 256))

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
      'script = ExtResource("3")\nmin_y = -300.0\nmax_y = 20.0\n\n'
      '[node name="CombatHUD" parent="." instance=ExtResource("2")]\n\n'
      '[node name="CrownCutIn" parent="." instance=ExtResource("10")]\n')

header = header.replace("SUBCOUNT", str(17 + len(subs)))
io.open("maps/Playground.tscn", "w", encoding="utf-8").write(header + "".join(subs) + "\n" + b)
print("OK Playground.tscn rebuilt")
print("  roof y=%g x=%g..%g / mid cloud y=%g / top cloud y=%g" % (
    ROOF_Y, PAV_CX - PAV_HALF, PAV_CX + PAV_HALF, MID_Y, TOP_Y))
