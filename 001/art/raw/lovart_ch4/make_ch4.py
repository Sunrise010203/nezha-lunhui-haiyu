import os
import shutil
from PIL import Image

SRC = r"E:/godot_game_by_fable/001/art/raw/lovart_ch4/lovart_d65c35844d11.png"
OUT = r"E:/godot_game_by_fable/001/art/backdrop_ch4.png"
RAW = r"E:/godot_game_by_fable/001/art/backdrop_ch4_raw.png"

TW, TH = 2688, 1152
TARGET = TW / TH

assert os.path.exists(SRC), "source missing"
assert not os.path.exists(OUT), "refusing to overwrite " + OUT

# 1) keep the untouched original-size version for future re-cropping
shutil.copy2(SRC, RAW)

im = Image.open(SRC).convert("RGB")
src_size = im.size
w, h = im.size
cur = w / h

# 2) center-crop to the exact 2688x1152 aspect, then resize
if cur > TARGET + 1e-6:
    nw = round(h * TARGET)
    left = (w - nw) // 2
    im = im.crop((left, 0, left + nw, h))
elif cur < TARGET - 1e-6:
    nh = round(w / TARGET)
    top = (h - nh) // 2
    im = im.crop((0, top, w, top + nh))

cropped_size = im.size
im = im.resize((TW, TH), Image.LANCZOS)
im.save(OUT, "PNG", optimize=True)

print("source      :", SRC, src_size, os.path.getsize(SRC))
print("raw copy    :", RAW, os.path.getsize(RAW))
print("cropped     :", cropped_size)
print("final       :", OUT, im.size, os.path.getsize(OUT))
print("final_under_8MB:", os.path.getsize(OUT) < 8 * 1024 * 1024)
