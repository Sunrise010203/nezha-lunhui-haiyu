from PIL import Image
import numpy as np
im = Image.open(r"E:/godot_game_by_fable/art_tmp/nezha_bake/nezha_albedo.png").convert("RGB")
a = np.asarray(im).astype(np.float32)/255.0
print("mean", a.reshape(-1,3).mean(0).round(3))
print("frac>0.5", (a.mean(2)>0.5).mean().round(3))
cols, counts = np.unique((a*255).astype(np.uint8).reshape(-1,3), axis=0, return_counts=True)
idx = np.argsort(-counts)[:10]
for i in idx:
    print(cols[i].tolist(), int(counts[i]))
