# -*- coding: utf-8 -*-
"""抽检：把联络表里 T04/T06/T12/T15 四个格子放大并排，确认是重新生成的版本。"""
from PIL import Image
import time

SHEET = r"E:\godot_game_by_fable\art_assets\contact_sheet_v2.png"
OUT = r"E:\godot_game_by_fable\art_assets\_qa_cells_%s.png" % time.strftime("%H%M%S")
TILE, COLS, PAD, LBL, TOP = 430, 4, 18, 62, 86

sheet = Image.open(SHEET).convert("RGB")
cells = []
for idx in (3, 5, 11, 14):
    c, r = idx % COLS, idx // COLS
    x = PAD + c * (TILE + PAD)
    y = TOP + r * (TILE + LBL + PAD)
    cells.append(sheet.crop((x, y, x + TILE, y + TILE)).resize((300, 300)))

canvas = Image.new("RGB", (4 * 310 + 10, 320), (25, 25, 25))
for i, cimg in enumerate(cells):
    canvas.paste(cimg, (10 + i * 310, 10))
canvas.save(OUT)
print(OUT)
