# -*- coding: utf-8 -*-
"""绿幕抠图：art/raw/*.png -> art/sprites/*.png（透明背景 + 去绿边 + 裁剪留边）"""
import os
import sys
from PIL import Image

RAW = os.path.join(os.path.dirname(__file__), "raw")
OUT = os.path.join(os.path.dirname(__file__), "sprites")
os.makedirs(OUT, exist_ok=True)


def key_image(name: str) -> None:
    src = os.path.join(RAW, name)
    img = Image.open(src).convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            # 绿色主导 → 透明
            if g > 90 and g > r * 1.45 and g > b * 1.45:
                px[x, y] = (0, 0, 0, 0)
            elif g > 70 and g > r * 1.15 and g > b * 1.15:
                # 边缘半透明 + 去绿溢色
                spill = max(r, b)
                alpha = max(0, min(255, int(255 * (1.5 - g / max(spill, 1)))))
                px[x, y] = (r, spill, b, min(a, alpha))
            elif g > max(r, b):
                # 普通像素轻度去绿
                px[x, y] = (r, min(g, int(max(r, b) * 1.15)), b, a)
    # 裁剪到内容包围盒（留 8px 边）
    bbox = img.getbbox()
    if bbox:
        x0, y0, x1, y1 = bbox
        x0 = max(0, x0 - 8)
        y0 = max(0, y0 - 8)
        x1 = min(w, x1 + 8)
        y1 = min(h, y1 + 8)
        img = img.crop((x0, y0, x1, y1))
    dst = os.path.join(OUT, name)
    img.save(dst)
    print(f"{name}: {img.size[0]}x{img.size[1]} -> {dst}")


if __name__ == "__main__":
    names = sys.argv[1:] or [f for f in os.listdir(RAW) if f.endswith(".png")]
    for n in names:
        key_image(n)
