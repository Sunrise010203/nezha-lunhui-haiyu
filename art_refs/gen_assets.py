# -*- coding: utf-8 -*-
"""批量生成 Tripo 用的"单体资产参考图"（浅灰底、单物体、居中、3-4 视角之一）。

用法: python gen_assets.py --group a|b|c
每张图走 1k 分辨率，串行调用 apimart skill，失败自动重试 4 次。
（网络抖动严重时改用 gen_assets2.py：带 12 次重试 + 任务台账）
"""
import argparse
import os
import subprocess
import time

PY = r"C:\Users\Sunrise\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe"
SKILL = r"C:\Users\Sunrise\.agents\skills\apimart-image-gen\scripts\apimart_image.py"
OUT = r"E:\godot_game_by_fable\art_assets"
os.makedirs(OUT, exist_ok=True)

COMMON = (
    "single isolated 3D game asset, one object only, centered, entire object visible in frame, "
    "three-quarter front view, plain seamless light warm-grey studio background, soft even lighting, "
    "subtle ambient occlusion, no cast shadow, no pedestal, no text, no UI, no extra props, "
    "stylized semi-realistic game art, hand-painted PBR, weathered surfaces, crisp readable silhouette"
)

A = [
    ("ch1_abyss_eye", "1:1",
     "a colossal abyssal eye creature head: one giant vertical-slit eyeball with layered stone eyelids, "
     "ringed by cracked red coral and a dozen curled tentacles, ancient sunken boss creature, teal and barnacled"),
    ("ch1_coral_fan", "1:1",
     "a large red coral fan cluster, flat branching fan-shaped coral with fine twigs, encrusted with barnacles"),
    ("ch1_pillar_dragon_capital", "3:4",
     "an ornate Chinese dragon-headed stone column capital, coiled dragon carving wrapping the top of a broken pillar, "
     "eroded stone with bronze inlay"),
    ("ch2_warden", "3:4",
     "a hulking Chinese bronze-and-iron jailer boss, heavy cast-iron armor with taotie beast-face motifs and lotus rivets, "
     "massive rectangular tower shield, faceless helm, organic barnacle growths on its back, heavy stance, "
     "dark iron with green patina and ember tones, no weapon"),
    ("ch2_skull_gate_ornament", "1:1",
     "an ornate bronze gate ornament: a crowned skull mounted on a rusted iron plate with scrollwork"),
]

B = [
    ("ch2_cage_bones", "1:1",
     "skeletonized prisoner remains laid out flat on a plain studio floor, seen from a low three-quarter angle: "
     "two skulls, a ribcage, scattered femurs and a rusted iron shackle with a short broken chain, "
     "the bones rest directly on the floor, open space all around"),
    ("ch2_bone_debris", "1:1",
     "a scattered pile of bleached bones, skulls, ribs and broken shackles on wet dark stone"),
    ("ch3_void_rock", "1:1",
     "a jagged floating obsidian rock fragment, angular eroded volcanic stone with faint cyan crystal veins"),
    ("ch3_dragon_ring_fitting", "1:1",
     "a small ornate bronze dragon-head ring fitting with a glowing cyan gem, ancient and weathered"),
    ("ch3_sea_eye_core", "1:1",
     "a giant organic eyeball core, dark pupil with a faint glowing rim, stone-like sclera, floating in a void"),
]

C = [
    ("ch4_whale_bone_arch", "1:1",
     "a massive whale rib bone arch segment, curved bleached ribs and vertebrae forming an arch, barnacles and sea grime"),
    ("ch4_chiwen", "1:1",
     "a dragon-fish guardian creature: dragon head with long whiskers, serpentine fish body with large translucent fins "
     "and a fan-shaped fish tail, no legs, ghostly pale-jade scales, swimming"),
    ("ch4_drowned_statue", "3:4",
     "a drowned official statue in flowing robes, jade-green stone, eroded, one arm missing, serene face"),
    ("ch4_coral_mutation", "1:1",
     "a twisted corrupted coral and fungal cluster, dark red spiked growths with faint ember glow"),
    ("ch4_bell_dragon_knob", "1:1",
     "an ornate bronze artifact: a coiled Chinese dragon clutching a glowing pearl, the dragon sits on a short "
     "octagonal bronze plinth with lotus engraving, museum artifact photograph, weathered green patina"),
]

GROUPS = {"a": A, "b": B, "c": C}


def run_one(slug, size, prompt):
    args = [PY, SKILL, COMMON + ", " + prompt,
            "--size", size, "--resolution", "1k", "--out", OUT, "--prefix", slug]
    for attempt in (1, 2, 3, 4):
        t0 = time.time()
        r = subprocess.run(args)
        if r.returncode == 0:
            print(f"[OK] {slug}  {time.time() - t0:.0f}s", flush=True)
            return True
        print(f"[FAIL] {slug} attempt {attempt} rc={r.returncode}", flush=True)
        time.sleep(8)
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--group", required=True, choices=list(GROUPS))
    a = ap.parse_args()
    ok = 0
    for slug, size, prompt in GROUPS[a.group]:
        if os.path.exists(os.path.join(OUT, slug + ".png")):
            print(f"[SKIP] {slug} exists", flush=True)
            ok += 1
            continue
        if run_one(slug, size, prompt):
            ok += 1
    print(f"GROUP {a.group} done: {ok}/{len(GROUPS[a.group])}", flush=True)


if __name__ == "__main__":
    main()
