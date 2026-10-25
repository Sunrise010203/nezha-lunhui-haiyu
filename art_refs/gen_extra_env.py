# -*- coding: utf-8 -*-
"""补两件环境资产参考图：石灯笼、柱础/柱身模块（Tripo 用）。"""
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
    ("ch1_stone_lantern", "3:4",
     "a Chinese stone lantern for an undersea dragon palace: square light chamber with bronze openwork panels, "
     "curved pagoda roof with upturned eaves, lotus-carved base and a slim square shaft, "
     "weathered grey-green stone with barnacles and coral crusts, warm light glowing from inside the chamber"),
    ("ch1_pillar_module", "3:4",
     "a modular Chinese palace stone column module: square plinth base carved with lotus petals, "
     "fluted cylindrical shaft section banded by two bronze rings, broken eroded top edge, "
     "grey-green stone with barnacles, salt stains and fine cracks"),
]

for slug, size, prompt in ITEMS:
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
