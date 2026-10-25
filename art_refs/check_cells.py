# -*- coding: utf-8 -*-
"""核对：从联络表裁出 T04/T06/T12/T15 细胞图，确认表格用的是最新单体图。"""
import os
from PIL import Image

SHEET = r"E:\godot_game_by_fable\art_assets\contact_sheet_v2.png"
WAR = r"E:\godot_game_by_fable\art_assets\ch2_warden.png"
OUT = r"E:\godot_game_by_fable\art_assets\_check_cells.png"

TILE, COLS, PAD, LBL, TOP = 430, 4, 18, 62, 86
sheet = Image.open(SHEET).convert("RGB")
cells = []
for idx in (3, 5, 11, 14):  # T04, T06, T12, T15
    c, r = idx % COLS, idx // COLS
    x = PAD + c * (TILE + PAD)
    y = TOP + r * (TILE + LBL + PAD)
    cells.append(sheet.crop((x, y, x + TILE, y + TILE)).resize((260, 260)))
war = Image.open(WAR).convert("RGB")
war.thumbnail((260, 260))
canvas = Image.new("RGB", (4 * 270 + 10, 280), (20, 20, 20))
for i, cimg in enumerate(cells):
    canvas.paste(cimg, (10 + i * 270, 10))
canvas.save(OUT)
print(OUT)
