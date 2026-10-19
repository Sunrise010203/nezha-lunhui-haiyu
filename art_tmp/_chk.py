
import os
import numpy as np
from PIL import Image
SRC = r"E:\godot_game_by_fable\art_tmp\nezha_bake"
for f in sorted(os.listdir(SRC)):
    p = os.path.join(SRC, f)
    im = Image.open(p)
    a = np.asarray(im.convert("RGB"), dtype=np.float32) / 255.0
    g = np.asarray(im.convert("L"), dtype=np.float32) / 255.0
    print(f, im.mode, im.size, os.path.getsize(p),
          "rgb mean", [round(float(v),3) for v in a.reshape(-1,3).mean(0)],
          "gray max", round(float(g.max()),3), "frac>0.5", round(float((g>0.5).mean()),4))
