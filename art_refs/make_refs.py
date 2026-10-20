# -*- coding: utf-8 -*-
"""Build palette board + annotated layout sheets + contact sheet for the
scene reference images. Pure Pillow, no external assets.

Run:
  python make_refs.py
"""
from __future__ import annotations

import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONT_CN = r"C:\Windows\Fonts\msyh.ttc"
FONT_CN_BD = r"C:\Windows\Fonts\msyhbd.ttc"

BG = (8, 11, 15)
PANEL = (17, 22, 28)
BORDER = (42, 50, 60)
TEXT = (232, 238, 244)
DIM = (150, 162, 175)

_font_cache: dict[tuple[str, int], ImageFont.FreeTypeFont] = {}


def F(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    key = ("b" if bold else "r", size)
    if key not in _font_cache:
        _font_cache[key] = ImageFont.truetype(FONT_CN_BD if bold else FONT_CN, size)
    return _font_cache[key]


def rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def lum(c: tuple[int, int, int]) -> float:
    return (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255.0


CHAPTERS = [
    {
        "id": "ch1",
        "file": "ch1_corridor_20261020_130544_0.png",
        "no": "第一章",
        "name": "东海 · 碎潮回廊",
        "sub": "DRAGON PALACE OUTER CORRIDOR",
        "main": [("主色 60%", "#0B3A42", "深海青光"), ("次色 30%", "#2A4652", "石蓝灰"), ("强调 10%", "#E8B45A", "暖金")],
        "extra": [("#4FE8FF", "灵青"), ("#5FE08C", "回春绿")],
        "objects": [
            ("玩家出生 / 空走道（左三分之一）", 0.245, 0.700),
            ("断口（跳跃难点），走道带断裂", 0.530, 0.755),
            ("中景断柱群（近层框景）", 0.215, 0.350),
            ("远景龙宫残殿剪影（大气透视）", 0.435, 0.400),
            ("Boss「归墟之喉」巨眼（右后景）", 0.730, 0.450),
            ("水面光 / 天顶主光", 0.520, 0.120),
            ("暖金灯笼（可交互语义点）", 0.072, 0.660),
            ("水面与倒影（前景底带）", 0.500, 0.930),
        ],
    },
    {
        "id": "ch2",
        "file": "ch2_prison_20261020_130649_0.png",
        "no": "第二章",
        "name": "龙宫深狱",
        "sub": "DEEP-SEA PRISON",
        "main": [("主色 60%", "#1D2328", "铁灰"), ("次色 30%", "#5C2A26", "锈红"), ("强调 10%", "#FF7A2F", "烬橙")],
        "extra": [("#B8912F", "朽金"), ("#A6432A", "狱火")],
        "objects": [
            ("玩家（走道中段偏左）", 0.330, 0.665),
            ("悬吊铁笼（第一视觉锚点）", 0.430, 0.220),
            ("铁门 + 骷髅门饰（近层框景）", 0.155, 0.330),
            ("断桥 / 塌陷段（跳跃难点）", 0.690, 0.700),
            ("Boss「棘狱守卫」剪影（炉火逆光）", 0.830, 0.500),
            ("炉火 / 烬光源（下打光）", 0.585, 0.885),
            ("下层深渊（掉出即死区）", 0.290, 0.930),
        ],
    },
    {
        "id": "ch3",
        "file": "ch3_void_20261020_130658_0.png",
        "no": "第三章",
        "name": "归墟虚空「海眼」",
        "sub": "THE VOID OF GUIXU",
        "main": [("主色 60%", "#06040D", "虚空黑紫"), ("次色 30%", "#241A35", "冷紫石"), ("强调 10%", "#7FF0E0", "珍珠青")],
        "extra": [("#A06AE0", "归墟紫"), ("#4FE8FF", "灵青")],
        "objects": [
            ("玩家（左侧悬空平台）", 0.230, 0.630),
            ("铜环摆荡锚点（玩法核心）", 0.600, 0.780),
            ("海眼巨涡（背景主体）", 0.495, 0.310),
            ("悬浮封印石板（远景剪影）", 0.880, 0.250),
            ("断台 / 摆荡落点（右侧）", 0.790, 0.790),
            ("垂直光柱（纵深分层）", 0.290, 0.560),
            ("归墟虚空（无地面，坠落死亡）", 0.500, 0.960),
        ],
    },
    {
        "id": "ch4",
        "file": "ch4_hall_20261020_130705_0.png",
        "no": "第四章",
        "name": "龙骨沉殿「潮心」",
        "sub": "SUNKEN HALL OF WHALE BONES",
        "main": [("主色 60%", "#2E6B5B", "玉青"), ("次色 30%", "#E8E2CF", "骨白"), ("强调 10%", "#B8912F", "朽金")],
        "extra": [("#4FD6B0", "潮纹玉绿"), ("#FF4A32", "危险红")],
        "objects": [
            ("玩家（左侧开阔平台）", 0.205, 0.730),
            ("鲸骨拱 / 椎骨天顶（上限框）", 0.400, 0.120),
            ("天顶破口冷白光柱（主光）", 0.510, 0.300),
            ("Boss「潮心 · 螭吻」剪影（光柱中）", 0.530, 0.450),
            ("潮纹碑（玉绿符文，可交互）", 0.856, 0.545),
            ("骨白雕像 / 沉钟（中景地标）", 0.640, 0.660),
            ("潮脉水流（下半引导线）", 0.720, 0.760),
            ("水面 / 前景倒影", 0.450, 0.950),
        ],
    },
]

SEMANTIC = [
    ("危险 / 伤害", "#FF4A32"),
    ("奖励 / 可拾取", "#F2C14E"),
    ("路径 / 可交互", "#4FE8FF"),
    ("治疗", "#5FE08C"),
]


def rounded(draw: ImageDraw.ImageDraw, box, r, fill=None, outline=None, width=1):
    draw.rounded_rectangle(box, radius=r, fill=fill, outline=outline, width=width)


def text(draw, xy, s, size, color=TEXT, bold=False, anchor="la"):
    draw.text(xy, s, font=F(size, bold), fill=color, anchor=anchor)


# ---------------------------------------------------------------- palette board
def palette_board(path: str):
    W, H = 1920, 1400
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)

    # header
    d.rectangle([0, 0, W, 6], fill=rgb("#4FE8FF"))
    text(d, (72, 62), "哪吒 · 轮回海域", 54, TEXT, True)
    text(d, (72, 132), "场景参考图 · 画风与配色规范", 30, rgb("#8FDDE8"))
    text(d, (72, 178), "2.5D 横版动作（Godot 4.6 / 1920×1080）　·　画风：深海青铜 × 霓虹符文　·　渲染：半写实 3D + Toon 阶跃 + 冷色轮廓光", 22, DIM)
    d.line([72, 224, W - 72, 224], fill=BORDER, width=2)

    bw, bh = 856, 452
    x0, y0 = 72, 252
    gx, gy = 64, 40
    for i, ch in enumerate(CHAPTERS):
        cx = x0 + (i % 2) * (bw + gx)
        cy = y0 + (i // 2) * (bh + gy)
        rounded(d, [cx, cy, cx + bw, cy + bh], 18, fill=PANEL, outline=BORDER, width=2)
        accent = rgb(ch["main"][2][1])
        d.rectangle([cx, cy, cx + 8, cy + bh], fill=accent)
        text(d, (cx + 32, cy + 26), ch["no"] + "　" + ch["name"], 32, TEXT, True)
        text(d, (cx + 32, cy + 72), ch["sub"], 17, DIM)

        tw, th = 248, 118
        for j, (role, hx, cname) in enumerate(ch["main"]):
            tx = cx + 32 + j * (tw + 16)
            ty = cy + 112
            c = rgb(hx)
            rounded(d, [tx, ty, tx + tw, ty + th], 10, fill=c)
            tc = (10, 12, 16) if lum(c) > 0.55 else (245, 245, 245)
            text(d, (tx + 14, ty + 12), role, 17, tc, True)
            text(d, (tx + 14, ty + th - 40), hx.upper(), 22, tc, True)
            text(d, (tx + 14, ty + th - 76), cname, 15, tc)

        # extra accents
        for j, (hx, nm) in enumerate(ch["extra"]):
            ex = cx + 32 + j * 168
            ey = cy + 252
            c = rgb(hx)
            d.rectangle([ex, ey, ex + 40, ey + 40], fill=c)
            text(d, (ex + 52, ey + 1), nm, 17, TEXT)
            text(d, (ex + 52, ey + 22), hx.upper(), 14, DIM)

        # mini composition note
        note = {
            "ch1": "光：水面冷光自上而下　构图：走道带 62–82%，Boss 巨眼在右后景 1/3",
            "ch2": "光：炉火自下而上反打　构图：吊笼占上三分点，守卫剪影压右下",
            "ch3": "光：只有边缘光与光柱　构图：海眼居中偏上，摆荡环落在下方黄金分割",
            "ch4": "光：破口冷白主光 + 玉青补光　构图：骨拱做上限，螭吻占中心，潮脉做引导线",
        }[ch["id"]]
        text(d, (cx + 32, cy + 320), note, 16, rgb("#B9C6D2"))
        # luminance ladder
        text(d, (cx + 32, cy + 356), "明度阶梯：背景 8–18% ／ 中景 25–40% ／ 玩法面 45–65% ／ 关键物 75–90%", 15, DIM)
        text(d, (cx + 32, cy + 386), "自发光只给：力量 / 危险 / 可交互；装饰 emission ≤ 0.35；同屏发光 ≤ 3 色", 15, DIM)

    # semantic row
    sy = H - 150
    d.line([72, sy - 22, W - 72, sy - 22], fill=BORDER, width=2)
    text(d, (72, sy - 2), "全章共用语义色（颜色即玩法语言，不许挪用）", 22, TEXT, True)
    for j, (nm, hx) in enumerate(SEMANTIC):
        ex = 72 + j * 330
        ey = sy + 44
        c = rgb(hx)
        rounded(d, [ex, ey, ex + 56, ey + 40], 6, fill=c)
        text(d, (ex + 70, ey + 4), nm, 18, TEXT)
        text(d, (ex + 70, ey + 27), hx.upper(), 14, DIM)
    text(d, (W - 72, sy + 52), "60 / 30 / 10　·　剪影优先　·　三秒一景（每 8–12m 一个视觉锚点）", 18, rgb("#8FDDE8"), anchor="ra")

    img.save(path)
    return path


# ------------------------------------------------------------ layout sheets
def dashed(d: ImageDraw.ImageDraw, box, color, width=2, dash=14, gap=10):
    x1, y1, x2, y2 = box
    for x in range(int(x1), int(x2), dash + gap):
        d.line([x, y1, min(x + dash, x2), y1], fill=color, width=width)
        d.line([x, y2, min(x + dash, x2), y2], fill=color, width=width)
    for y in range(int(y1), int(y2), dash + gap):
        d.line([x1, y, x1, min(y + dash, y2)], fill=color, width=width)
        d.line([x2, y, x2, min(y + dash, y2)], fill=color, width=width)


def corner_box(d, box, color, L=46, width=4):
    x1, y1, x2, y2 = box
    for (ax, ay, dx, dy) in ((x1, y1, 1, 1), (x2, y1, -1, 1), (x1, y2, 1, -1), (x2, y2, -1, -1)):
        d.line([ax, ay, ax + dx * L, ay], fill=color, width=width)
        d.line([ax, ay, ax, ay + dy * L], fill=color, width=width)


def layout_sheet(ch, path_out):
    src = Image.open(os.path.join(HERE, ch["file"])).convert("RGB")
    IW, IH = 1920, 1080
    src = src.resize((IW, IH), Image.LANCZOS)
    legend_h = 320
    W, H = IW, IH + legend_h
    img = Image.new("RGB", (W, H), BG)
    img.paste(src, (0, 0))
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)

    CY = (79, 232, 255, 235)
    AM = (242, 193, 78, 235)
    GR = (255, 255, 255, 34)

    # 10% grid
    for i in range(1, 10):
        x = IW * i / 10
        d.line([x, 0, x, IH], fill=(255, 255, 255, 18), width=1)
    for i in range(1, 10):
        y = IH * i / 10
        d.line([0, y, IW, y], fill=(255, 255, 255, 18), width=1)
    # rule of thirds
    for i in (1, 2):
        x = IW * i / 3
        d.line([x, 0, x, IH], fill=(255, 255, 255, 60), width=2)
        y = IH * i / 3
        d.line([0, y, IW, y], fill=(255, 255, 255, 60), width=2)

    # playfield band
    band = [0, IH * 0.62, IW, IH * 0.82]
    d.rectangle(band, fill=(120, 255, 180, 22))
    d.line([0, band[1], IW, band[1]], fill=(120, 255, 180, 150), width=3)
    d.line([0, band[3], IW, band[3]], fill=(120, 255, 180, 150), width=3)
    text(d, (IW - 28, band[1] + 10), "玩法带 62%–82%（平台面 / 可站立地面）", 28, (150, 255, 200, 255), True, anchor="ra")

    # player zone
    pz = [IW * 0.05, IH * 0.58, IW * 0.31, IH * 0.84]
    corner_box(d, pz, CY)
    text(d, (pz[0] + 8, pz[1] - 40), "玩家区 5–31%", 28, CY, True)

    # goal zone
    gz = [IW * 0.65, IH * 0.48, IW * 0.96, IH * 0.86]
    corner_box(d, gz, AM)
    text(d, (gz[0] + 12, gz[3] - 40), "出口 / 竞技场 / Boss  65–96%", 26, AM, True)

    # safe area
    dashed(d, [IW * 0.04, IH * 0.04, IW * 0.96, IH * 0.96], (255, 255, 255, 70))

    # title chip
    text(d, (40, 34), ch["no"] + "　" + ch["name"], 46, (255, 255, 255, 255), True)
    text(d, (42, 92), "场景参考 · 构图标注（坐标为画面百分比，原点左上）", 24, (200, 210, 220, 235))

    # markers
    for idx, (nm, px, py) in enumerate(ch["objects"], start=1):
        mx, my = IW * px, IH * py
        r = 26
        d.ellipse([mx - r, my - r, mx + r, my + r], fill=(10, 14, 18, 215), outline=(255, 255, 255, 240), width=3)
        text(d, (mx, my - 1), str(idx), 26, (255, 255, 255, 255), True, anchor="mm")
        # crosshair
        d.line([mx - r - 18, my, mx - r - 4, my], fill=(255, 255, 255, 200), width=2)
        d.line([mx + r + 4, my, mx + r + 18, my], fill=(255, 255, 255, 200), width=2)
        d.line([mx, my - r - 18, mx, my - r - 4], fill=(255, 255, 255, 200), width=2)
        d.line([mx, my + r + 4, mx, my + r + 18], fill=(255, 255, 255, 200), width=2)

    img = Image.alpha_composite(img.convert("RGBA"), ov).convert("RGB")
    d2 = ImageDraw.Draw(img)

    # legend strip
    ly = IH + 24
    d2.rectangle([0, IH, W, H], fill=BG)
    d2.line([0, IH, W, IH], fill=BORDER, width=2)
    cols, rowh = 2, 40
    colw = (W - 96) // cols
    for i, (nm, px, py) in enumerate(ch["objects"]):
        cx = 48 + (i % cols) * colw
        cy = ly + (i // cols) * rowh
        text(d2, (cx, cy), f"{i + 1:02d}", 25, rgb("#8FDDE8"), True)
        text(d2, (cx + 48, cy + 2), nm, 22, TEXT)
        text(d2, (cx + colw - 28, cy + 3), f"{int(px * 100)}%, {int(py * 100)}%", 20, rgb("#F2C14E"), anchor="ra")
    text(d2, (48, H - 34), "网格 10% × 10%　·　白线为三分线　·　虚线为 UI 安全区（5% inset）", 17, DIM)

    img.save(path_out)
    return path_out


# ------------------------------------------------------------ contact sheet
def contact_sheet(path_out):
    tw, th = 940, 529
    gap = 20
    W = tw * 2 + gap * 3
    H = 96 + th * 2 + gap * 3 + 26
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, 6], fill=rgb("#4FE8FF"))
    text(d, (gap + 8, 34), "四章场景参考图 · 对比（同一机位 / 同一画风 / 不同色相）", 32, TEXT, True)
    for i, ch in enumerate(CHAPTERS):
        x = gap + (i % 2) * (tw + gap)
        y = 96 + (i // 2) * (th + gap)
        im = Image.open(os.path.join(HERE, ch["file"])).convert("RGB").resize((tw, th), Image.LANCZOS)
        img.paste(im, (x, y))
        d.rectangle([x, y, x + tw, y + th], outline=BORDER, width=2)
        chip = ch["no"] + "　" + ch["name"]
        f = F(24, True)
        bb = d.textbbox((0, 0), chip, font=f)
        d.rectangle([x + 12, y + th - 12 - (bb[3] - bb[1]) - 20, x + 12 + bb[2] + 28, y + th - 12], fill=(8, 11, 15))
        text(d, (x + 26, y + th - 12 - (bb[3] - bb[1]) - 12), chip, 24, TEXT, True, anchor="ls")
    img.save(path_out)
    return path_out


def main():
    print(palette_board(os.path.join(HERE, "palette_board.png")))
    for ch in CHAPTERS:
        out = os.path.join(HERE, f"layout_{ch['id']}.png")
        print(layout_sheet(ch, out))
    print(contact_sheet(os.path.join(HERE, "contact_sheet.png")))


if __name__ == "__main__":
    main()
