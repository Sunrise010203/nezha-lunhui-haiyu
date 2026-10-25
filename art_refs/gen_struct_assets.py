# -*- coding: utf-8 -*-
"""补结构资产参考图：柱身中段 / 栏杆 / 望柱 / 踏步 / 拱券 / 碎石簇 / 藤壶簇（Tripo 用）。"""
import os
import subprocess
import time

PY = r"C:\Users\Sunrise\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe"
SKILL = r"C:\Users\Sunrise\.agents\skills\apimart-image-gen\scripts\apimart_image.py"
OUT = r"E:\godot_game_by_fable\art_assets"

COMMON = (
    "single isolated 3D game asset, one object only, centered, entire object visible in frame, "
    "three-quarter front view, plain seamless light warm-grey studio background, soft even lighting, "
    "subtle ambient occlusion, no cast shadow, no pedestal, no text, no UI, no extra props, "
    "stylized semi-realistic game art, hand-painted PBR, weathered surfaces, crisp readable silhouette"
)

ITEMS = [
    ("ch1_shaft_module", "3:4",
     "a plain fluted stone column shaft segment of an undersea Chinese palace: vertical fluting, "
     "flat parallel top and bottom ends, no base and no capital, uniform diameter, "
     "grey-green stone with barnacles, salt stains and one hairline crack"),
    ("ch1_balustrade", "1:1",
     "a stone balustrade railing segment of an undersea palace: a horizontal rail on two short carved posts, "
     "weathered grey-green stone, broken section at one end, barnacles and a bit of pink coral crust"),
    ("ch1_baluster_post", "3:4",
     "a single stone baluster post of an undersea palace railing: square shaft with a lotus-bud finial, "
     "weathered grey-green stone, barnacles and slight lean, isolated upright object"),
    ("ch1_step_block", "1:1",
     "a modular stone stair step block of an undersea palace: two wide low steps in one piece, "
     "chipped edges, worn tread, grey-green stone with salt crust and moss"),
    ("ch1_arch_frame", "1:1",
     "a stone arch doorway frame of an undersea Chinese palace: semicircular arch with dragon-cloud relief band "
     "and square jamb blocks, an empty opening in the middle, weathered grey-green stone with barnacles"),
    ("ch1_rubble_cluster", "1:1",
     "a cluster of broken stone rubble: a few angular blocks and slabs of different sizes piled in a low heap, "
     "weathered grey-green stone with barnacles and dark sediment"),
    ("ch1_barnacle_cluster", "1:1",
     "a cluster of barnacles and small tube worms on a patch of stone crust, pale grey and bone white shells, "
     "dense natural growth ready to scatter on surfaces"),
]

for slug, size, prompt in ITEMS:
    if os.path.exists(os.path.join(OUT, slug + ".png")):
        print(f"[SKIP] {slug}", flush=True)
        continue
    args = [PY, SKILL, COMMON + ", " + prompt,
            "--size", size, "--resolution", "1k", "--out", OUT, "--prefix", slug]
    for attempt in range(1, 7):
        t0 = time.time()
        r = subprocess.run(args)
        if r.returncode == 0:
            print(f"[OK] {slug} {time.time() - t0:.0f}s", flush=True)
            break
        print(f"[FAIL] {slug} attempt {attempt}", flush=True)
        time.sleep(10)
