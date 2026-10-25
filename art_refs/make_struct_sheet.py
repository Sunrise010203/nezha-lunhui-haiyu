# -*- coding: utf-8 -*-
"""把带时间戳的结构资产图改名成 {slug}.png，并拼一张 T18–T24 认领表。"""
import os
import re
from PIL import Image, ImageDraw, ImageFont

OUT = r"E:\godot_game_by_fable\art_assets"
FB = r"C:\Windows\Fonts\msyhbd.ttc"
FR = r"C:\Windows\Fonts\msyh.ttc"

ITEMS = [
    ("T18", "ch1_shaft_module", "柱身中段模块", "平口、无柱础无柱冠，任意高度拼接"),
    ("T19", "ch1_balustrade", "栏杆段", "横栏 + 两根短望柱，一端断裂"),
    ("T20", "ch1_baluster_post", "望柱（单根）", "方柱身 + 莲苞柱头"),
    ("T21", "ch1_step_block", "踏步模块", "两级踏步一体，边缘啃缺"),
    ("T22", "ch1_arch_frame", "拱券门框", "半圆拱 + 云龙浮雕带，中间开口"),
    ("T23", "ch1_rubble_cluster", "碎石簇", "3–5 块大小不一的石块堆"),
    ("T24", "ch1_barnacle_cluster", "藤壶簇", "藤壶/管虫壳群，可散布在表面"),
]

# 1) 改名
for _, slug, _, _ in ITEMS:
    pat = re.compile(r"^" + re.escape(slug) + r"_\d{8}_\d{6}_0\.png$")
    for f in os.listdir(OUT):
        if pat.match(f):
            src = os.path.join(OUT, f)
            dst = os.path.join(OUT, slug + ".png")
            if os.path.exists(dst):
                os.remove(src)
            else:
                os.rename(src, dst)
            break

# 2) 认领表
TILE, COLS, PAD, TOP, LBL = 360, 4, 14, 60, 66
rows = (len(ITEMS) + COLS - 1) // COLS
W = COLS * (TILE + PAD) + PAD
H = TOP + rows * (TILE + LBL) + PAD
canvas = Image.new("RGB", (W, H), (17, 20, 25))
d = ImageDraw.Draw(canvas)
d.text((PAD, 14), "结构资产参考图 T18–T24（Tripo 输入）", font=ImageFont.truetype(FB, 28), fill=(255, 255, 255))
for i, (code, slug, cn, note) in enumerate(ITEMS):
    p = os.path.join(OUT, slug + ".png")
    if not os.path.exists(p):
        print("MISSING", p)
        continue
    c, r = i % COLS, i // COLS
    x = PAD + c * (TILE + PAD)
    y = TOP + r * (TILE + LBL)
    im = Image.open(p).convert("RGB")
    im.thumbnail((TILE, TILE), Image.LANCZOS)
    cell = Image.new("RGB", (TILE, TILE), (232, 232, 230))
    cell.paste(im, ((TILE - im.width) // 2, (TILE - im.height) // 2))
    canvas.paste(cell, (x, y))
    d.text((x + 2, y + TILE + 6), code, font=ImageFont.truetype(FB, 20), fill=(255, 178, 64))
    d.text((x + 52, y + TILE + 6), cn, font=ImageFont.truetype(FR, 20), fill=(235, 240, 245))
    d.text((x + 52, y + TILE + 30), note, font=ImageFont.truetype(FR, 15), fill=(140, 155, 170))

sheet = os.path.join(OUT, "struct_sheet.png")
canvas.save(sheet)
print(sheet, canvas.size)
