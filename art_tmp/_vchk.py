
import numpy as np, os
from PIL import Image
for n in ["_A.png","_B.png","_C.png"]:
    p = os.path.join(r"E:\godot_game_by_fable\art_tmp", n)
    a = np.asarray(Image.open(p).convert("RGB"), dtype=np.float32)/255.0
    print(n, "mean", [round(float(v),3) for v in a.reshape(-1,3).mean(0)], "max", round(float(a.max()),3))
