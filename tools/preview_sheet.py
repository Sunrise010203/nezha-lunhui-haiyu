# -*- coding: utf-8 -*-
"""把 Godot 渲染的 GLB 预览拼成联络表。"""
import os
from PIL import Image, ImageDraw, ImageFont

SRC = r"E:\godot_game_by_fable\game_assets\_previews"
OUT = r"E:\godot_game_by_fable\game_assets\_glb_sheet.png"
FB = r"C:\Windows\Fonts\msyhbd.ttc"

names = sorted([f for f in os.listdir(SRC) if f.endswith(".png")],
               key=lambda s: (0, int(s[:-4])) if s[:-4].isdigit() else (1, 0))

TILE, COLS, PAD, TOP, LBL = 300, 5, 10, 50, 34
rows = (len(names) + COLS - 1) // COLS
W = COLS * (TILE + PAD) + PAD
H = TOP + rows * (TILE + LBL) + PAD
canvas = Image.new("RGB", (W, H), (16, 17, 19))
d = ImageDraw.Draw(canvas)
d.text((PAD, 12), "Tripo 资产 · 减面后渲染对照（57k tris / 件）", font=ImageFont.truetype(FB, 24), fill=(255, 255, 255))
for i, n in enumerate(names):
    c, r = i % COLS, i // COLS
    x = PAD + c * (TILE + PAD)
    y = TOP + r * (TILE + LBL)
    im = Image.open(os.path.join(SRC, n)).convert("RGB")
    im.thumbnail((TILE, TILE), Image.LANCZOS)
    canvas.paste(im, (x, y))
    d.text((x + 2, y + TILE + 6), n.replace(".png", ".glb"), font=ImageFont.truetype(FB, 19), fill=(255, 196, 96))
canvas.save(OUT)
print(OUT, canvas.size)
