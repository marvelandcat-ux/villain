# 맵 선택 지구본의 임시 표면 그림(대한민국 지도)을 만든다 — 2:1 등장방형(가로 = 경도 한 바퀴, 세로 = 위도).
# 한반도를 지구본 적도 한가운데에 크게 얹은 "한국 행성"이다. 레퍼런스(파란 바다 + 초록/노랑 땅 + 하늘색 구름 얼룩) 색감.
# 두 장으로 나눈다: 바다·구름(불투명, 2048x1024 지구 전체, 가로로 이어짐)과 땅(투명 배경).
# 땅은 펼쳐 확대해도 안 깨지게 **한반도 둘레만 잘라 고해상도(LAND_PX_PER_DEG)**로 따로 그린다(2026-10-06 사용자 요청)
# 실행: python tools/make_korea_globe.py  →  sprite/맵선택/korea_ocean.png, korea_land.png
# ⚠️ 아래 CENTER_LON/LAT·PX_PER_DEG를 바꾸면 ui/MapSelect.gd의 같은 이름 상수도 같이 바꿀 것(핀 자리 계산)
# ⚠️ LAND_BOX를 바꾸면 실행할 때 찍히는 land_rect를 ui/KoreaGlobe.gdshader의 land_rect 기본값에 옮길 것
import os
import random
from PIL import Image, ImageDraw, ImageFilter

W, H = 2048, 1024
SS = 2  # 2배로 그린 뒤 줄여서 가장자리를 부드럽게
CENTER_LON, CENTER_LAT = 127.5, 38.0  # 그림 한가운데(u 0.5, v 0.5)에 오는 경위도
PX_PER_DEG = 66.0  # 경위도 1도 = 몇 px (가로·세로 같게) — 키울수록 지구본 위 한반도가 커진다(너무 키우면 북쪽·제주가 공 가장자리에서 찌그러진다)
# 땅 그림이 덮는 범위(서쪽 경도, 동쪽 경도, 남쪽 위도, 북쪽 위도)와 해상도 — 펼쳐 4배 확대한 화면이 1도 ≈ 200px라 같게
LAND_BOX = (123.5, 132.5, 32.5, 43.0)
LAND_PX_PER_DEG = 200.0

OCEAN = (52, 112, 224)
OCEAN_DEEP = (40, 92, 200)
CLOUD = (150, 190, 250)
LAND = (40, 170, 110)
LAND_EDGE = (20, 110, 80)
LAND_HI = (245, 222, 90)
LAND_MID = (130, 205, 120)

# 한반도 테두리(대충, 경도·위도) — 북서 압록강 하구에서 시계 방향
PENINSULA = [
    (124.3, 40.0), (125.0, 40.5), (126.0, 41.4), (127.2, 41.5), (128.2, 41.4), (129.0, 42.0),
    (129.7, 42.4), (130.6, 42.3), (129.9, 41.0), (129.6, 40.8), (129.2, 40.6), (128.6, 40.0),
    (127.6, 39.7), (127.5, 39.3), (128.3, 38.6), (128.6, 38.0), (129.1, 37.4), (129.4, 36.8),
    (129.4, 36.0), (129.6, 35.8), (129.3, 35.3), (128.6, 35.0), (127.7, 34.7), (126.9, 34.4),
    (126.3, 34.4), (126.4, 34.9), (126.4, 35.6), (126.7, 36.0), (126.3, 36.6), (126.6, 37.0),
    (126.6, 37.5), (126.2, 37.8), (125.6, 37.7), (125.2, 38.0), (124.7, 38.1), (125.0, 38.6),
    (125.3, 39.4), (124.7, 39.6),
]
# 섬: (중심 경도, 위도, 가로 반지름 도, 세로 반지름 도)
ISLANDS = [
    (126.55, 33.38, 0.36, 0.16),  # 제주도
    (130.87, 37.50, 0.07, 0.06),  # 울릉도
    (131.87, 37.24, 0.03, 0.03),  # 독도
    (126.10, 34.70, 0.12, 0.08),  # 서남해 섬들(대충)
    (126.35, 37.45, 0.08, 0.06),  # 강화·영종(대충)
]


def to_px(lon, lat):
    x = W * 0.5 + (lon - CENTER_LON) * PX_PER_DEG
    y = H * 0.5 - (lat - CENTER_LAT) * PX_PER_DEG
    return x * SS, y * SS


def blob(draw, cx, cy, size, color, rng, parts=3):
    # 둥근 얼룩 — 타원 몇 개를 겹친다. 가로로 이어지게(지구본이 돌 때 이음매 없게) 양옆에도 그린다
    for _ in range(parts):
        ox = rng.uniform(-size, size)
        oy = rng.uniform(-size * 0.3, size * 0.3)
        rx = size * rng.uniform(0.6, 1.1)
        ry = size * rng.uniform(0.35, 0.55)
        for shift in (-W * SS, 0, W * SS):
            draw.ellipse([cx + ox - rx + shift, cy + oy - ry, cx + ox + rx + shift, cy + oy + ry], fill=color)


def main():
    rng = random.Random(7)
    img = Image.new("RGB", (W * SS, H * SS), OCEAN)
    d = ImageDraw.Draw(img)

    # 깊은 바다 얼룩
    for _ in range(40):
        blob(d, rng.uniform(0, W * SS), rng.uniform(0, H * SS), rng.uniform(60, 140) * SS, OCEAN_DEEP, rng)

    # 땅 모양(마스크)
    mask = Image.new("L", img.size, 0)
    md = ImageDraw.Draw(mask)
    md.polygon([to_px(lon, lat) for lon, lat in PENINSULA], fill=255)
    for lon, lat, rx, ry in ISLANDS:
        x0, y0 = to_px(lon - rx, lat + ry)
        x1, y1 = to_px(lon + rx, lat - ry)
        md.ellipse([x0, y0, x1, y1], fill=255)

    # 하늘색 구름 얼룩 — 바다가 돌아 땅 밑을 지나가므로 고르게 뿌린다
    kx0, ky0 = to_px(123.5, 43.5)
    kx1, ky1 = to_px(132.5, 32.5)
    for _ in range(80):
        blob(d, rng.uniform(0, W * SS), rng.uniform(0, H * SS), rng.uniform(25, 70) * SS, CLOUD, rng)

    land = make_land(rng, kx0, ky0, kx1, ky1)

    folder = os.path.join(os.path.dirname(__file__), "..", "sprite", "맵선택")
    os.makedirs(folder, exist_ok=True)
    out = os.path.join(folder, "korea_ocean.png")
    img.resize((W, H), Image.LANCZOS).save(out)
    print("saved", os.path.normpath(out))
    out = os.path.join(folder, "korea_land.png")
    land.save(out)
    print("saved", os.path.normpath(out), land.size)
    lon0, lon1, lat0, lat1 = LAND_BOX
    u0 = 0.5 + (lon0 - CENTER_LON) * PX_PER_DEG / W
    v0 = 0.5 - (lat1 - CENTER_LAT) * PX_PER_DEG / H
    print("land_rect = vec4(%.9f, %.9f, %.9f, %.9f)" % (u0, v0, (lon1 - lon0) * PX_PER_DEG / W, (lat1 - lat0) * PX_PER_DEG / H))


def make_land(rng, kx0, ky0, kx1, ky1):
    # 땅(투명 그림, LAND_BOX만): 테두리 → 초록 → 연두·노랑 얼룩(땅 안쪽만). 얼룩 자리·크기는 예전 저해상도 그림과 같은 도 단위
    lon0, lon1, lat0, lat1 = LAND_BOX
    k = LAND_PX_PER_DEG * SS  # 그리는 캔버스의 1도 = px
    size = (round((lon1 - lon0) * k), round((lat1 - lat0) * k))

    def at(lon, lat):
        return (lon - lon0) * k, (lat1 - lat) * k

    def deg_of(gx, gy):
        # 바다 그림(저해상도 x SS) 좌표 → 경위도
        return CENTER_LON + (gx / SS - W * 0.5) / PX_PER_DEG, CENTER_LAT - (gy / SS - H * 0.5) / PX_PER_DEG

    edge_w = 0.034 * k   # 테두리 두께(밖으로)
    inner_w = 0.025 * k  # 얼룩이 테두리에서 들어오는 폭
    outline = [at(lon, lat) for lon, lat in PENINSULA]
    ring = outline + [outline[0]]

    def shape_mask(grow):
        m = Image.new("L", size, 0)
        md = ImageDraw.Draw(m)
        md.polygon(outline, fill=255)
        for lon, lat, rx, ry in ISLANDS:
            x0, y0 = at(lon - rx, lat + ry)
            x1, y1 = at(lon + rx, lat - ry)
            if grow < 0 and min(x1 - x0, y1 - y0) < -grow * 2.5:
                continue
            md.ellipse([x0 - grow, y0 - grow, x1 + grow, y1 + grow], fill=255)
        if grow != 0:
            md.line(ring, fill=255 if grow > 0 else 0, width=round(abs(grow) * 2), joint="curve")
            for x, y in outline:
                r = abs(grow)
                md.ellipse([x - r, y - r, x + r, y + r], fill=255 if grow > 0 else 0)
        return m

    land = Image.new("RGBA", size, LAND_EDGE + (0,))
    land.paste(LAND_EDGE + (255,), (0, 0), shape_mask(edge_w))
    land.paste(LAND + (255,), (0, 0), shape_mask(0))
    patches = Image.new("RGB", size, LAND)
    pd = ImageDraw.Draw(patches)
    scale = k / (PX_PER_DEG * SS)
    for _ in range(260):
        lon, lat = deg_of(rng.uniform(kx0, kx1), rng.uniform(ky0, ky1))
        cx, cy = at(lon, lat)
        blob(pd, cx, cy, rng.uniform(6, 16) * SS * scale, LAND_MID if rng.random() < 0.5 else LAND_HI, rng, parts=2)
    land.paste(patches, (0, 0), shape_mask(-inner_w))
    return land.resize((size[0] // SS, size[1] // SS), Image.LANCZOS)


if __name__ == "__main__":
    main()
