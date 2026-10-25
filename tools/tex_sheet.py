# -*- coding: utf-8 -*-
"""把抽出的 basecolor 贴图拼成联络表，用于认领 GLB 编号 ↔ 资产。"""
import os
from PIL import Image, ImageDraw, ImageFont

SRC = r"E:\godot_game_by_fable\game_assets\_tex_check"
OUT = r"E:\godot_game_by_fable\game_assets\_tex_sheet.png"
FB = r"C:\Windows\Fonts\msyhbd.ttc"

names = [f"{i}_0.png" for i in range(2, 16)] + ["001 (1)_0.png"]
names = [n for n in names if os.path.exists(os.path.join(SRC, n))]

TILE, COLS, PAD, TOP, LBL = 300, 5, 12, 54, 40
rows = (len(names) + COLS - 1) // COLS
W = COLS * (TILE + PAD) + PAD
H = TOP + rows * (TILE + LBL) + PAD
canvas = Image.new("RGB", (W, H), (18, 18, 20))
d = ImageDraw.Draw(canvas)
d.text((PAD, 12), "GLB basecolor 贴图 ↔ 资产认领表", font=ImageFont.truetype(FB, 26), fill=(255, 255, 255))
for i, n in enumerate(names):
    c, r = i % COLS, i // COLS
    x = PAD + c * (TILE + PAD)
    y = TOP + r * (TILE + LBL)
    im = Image.open(os.path.join(SRC, n)).convert("RGB")
    im.thumbnail((TILE, TILE), Image.LANCZOS)
    canvas.paste(im, (x + (TILE - im.width) // 2, y + (TILE - im.height) // 2))
    d.text((x + 2, y + TILE + 8), n.replace("_0.png", ".glb"), font=ImageFont.truetype(FB, 20), fill=(255, 190, 90))
canvas.save(OUT)
print(OUT, canvas.size)
