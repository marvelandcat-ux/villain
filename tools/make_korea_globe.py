# 맵 선택 지구본의 임시 표면 그림(대한민국 지도)을 만든다 — 2:1 등장방형(가로 = 경도 한 바퀴, 세로 = 위도).
# 한반도를 지구본 적도 한가운데에 크게 얹은 "한국 행성"이다. 레퍼런스(파란 바다 + 초록/노랑 땅 + 하늘색 구름 얼룩) 색감.
# **바다만 돈다**(2026-10-06 사용자 요청) → 두 장으로 나눈다: 바다·구름(불투명, 가로로 이어짐)과 땅(투명 배경, 고정)
# 실행: python tools/make_korea_globe.py  →  sprite/맵선택/korea_ocean.png, korea_land.png
# ⚠️ 아래 CENTER_LON/LAT·PX_PER_DEG를 바꾸면 ui/MapSelect.gd의 같은 이름 상수도 같이 바꿀 것(핀 자리 계산)
import os
import random
from PIL import Image, ImageDraw, ImageFilter

W, H = 2048, 1024
SS = 2  # 2배로 그린 뒤 줄여서 가장자리를 부드럽게
CENTER_LON, CENTER_LAT = 127.5, 38.0  # 그림 한가운데(u 0.5, v 0.5)에 오는 경위도
PX_PER_DEG = 60.0  # 경위도 1도 = 몇 px (가로·세로 같게)

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

    # 땅(따로 투명 그림): 테두리(조금 크게) → 초록 → 연두·노랑 얼룩(땅 안쪽만)
    ocean = img
    img = Image.new("RGBA", ocean.size, LAND_EDGE + (0,))
    edge = mask.filter(ImageFilter.MaxFilter(9))
    img.paste(LAND_EDGE + (255,), (0, 0), edge)
    img.paste(LAND + (255,), (0, 0), mask)
    patches = Image.new("RGB", img.size, LAND)
    pd = ImageDraw.Draw(patches)
    for _ in range(260):
        cx = rng.uniform(kx0, kx1)
        cy = rng.uniform(ky0, ky1)
        blob(pd, cx, cy, rng.uniform(6, 16) * SS, LAND_MID if rng.random() < 0.5 else LAND_HI, rng, parts=2)
    inner = mask.filter(ImageFilter.MinFilter(7))
    img.paste(patches, (0, 0), inner)

    folder = os.path.join(os.path.dirname(__file__), "..", "sprite", "맵선택")
    os.makedirs(folder, exist_ok=True)
    for name, pic in (("korea_ocean.png", ocean), ("korea_land.png", img)):
        out = os.path.join(folder, name)
        pic.resize((W, H), Image.LANCZOS).save(out)
        print("saved", os.path.normpath(out))


if __name__ == "__main__":
    main()
