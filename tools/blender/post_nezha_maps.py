
import os
import numpy as np
from PIL import Image, ImageFilter

SRC = r"E:\godot_game_by_fable\art_tmp\nezha_bake"
DST = r"E:\godot_game_by_fable\001\art\textures\nezha"
PREV = r"E:\godot_game_by_fable\art_tmp\preview"
os.makedirs(DST, exist_ok=True); os.makedirs(PREV, exist_ok=True)

def load(name, mode="RGB"):
    im = Image.open(os.path.join(SRC, name)).convert(mode)
    return np.asarray(im, dtype=np.float32) / 255.0

alb_srgb = load("nezha_albedo.png")
cov = load("nezha_coverage.png", "L")
ao = load("nezha_ao.png", "L")
cur = load("nezha_curvature.png", "L")
nrm = load("nezha_normal.png")

def srgb_to_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)

alb = srgb_to_lin(alb_srgb)
covm = (cov > 0.5).astype(np.float32)
print("coverage", round(float(covm.mean()), 4))

LEGEND = [
    ((1.000, 1.000, 1.000), dict(name="white", rough=0.70, metal=0.00, skin=0.00, silk=0.00)),
    ((0.847, 0.617, 0.120), dict(name="gold",  rough=0.22, metal=1.00, skin=0.00, silk=0.00)),
    ((0.701, 0.100, 0.070), dict(name="red",   rough=0.34, metal=0.00, skin=0.00, silk=1.00)),
    ((0.050, 0.040, 0.050), dict(name="black", rough=0.32, metal=0.00, skin=0.00, silk=0.00)),
    ((0.552, 0.060, 0.050), dict(name="dred",  rough=0.75, metal=0.00, skin=0.00, silk=0.20)),
    ((0.922, 0.723, 0.597), dict(name="skin",  rough=0.48, metal=0.00, skin=1.00, silk=0.00)),
    ((0.922, 0.888, 0.839), dict(name="pale",  rough=0.55, metal=0.00, skin=0.60, silk=0.00)),
    ((0.150, 0.060, 0.050), dict(name="leath", rough=0.62, metal=0.00, skin=0.00, silk=0.00)),
]
cols = np.array([c for c, _ in LEGEND], dtype=np.float32)
d = ((alb.reshape(-1, 3)[:, None, :] - cols[None, :, :]) ** 2).sum(axis=2)
idx = d.argmin(axis=1).reshape(alb.shape[:2])
tot = float(covm.sum())
fr = {LEGEND[i][1]["name"]: round(float(((idx == i) & (covm > 0.5)).sum()) / max(tot, 1), 4) for i in range(len(LEGEND))}
print("region share (inside UV):", fr)

rough = np.zeros_like(ao); metal = np.zeros_like(ao); skin = np.zeros_like(ao); silk = np.zeros_like(ao)
for i, (_, p) in enumerate(LEGEND):
    m = idx == i
    rough[m] = p["rough"]; metal[m] = p["metal"]; skin[m] = p["skin"]; silk[m] = p["silk"]

# 混天绫丝绸：用几何级 material-id mask 覆盖（颜色分类在重烘 albedo 后会漂移）
silk_geo = load("nezha_silkmask.png", "L")
silk = np.where(silk_geo > 0.5, 1.0, silk)
skin = np.where(silk_geo > 0.5, 0.0, skin)
rough = np.where(silk_geo > 0.5, 0.30, rough)
print("silk geo share", round(float((silk_geo > 0.5).mean()), 4))

cur = np.clip(cur, 0, 1)
rough = np.clip(rough + (0.5 - cur) * 0.18, 0.05, 1.0)
rng = np.random.default_rng(7)
rough = np.clip(rough + rng.normal(0, 0.012, ao.shape).astype(np.float32), 0.05, 1.0)

orm = np.stack([np.where(covm > 0.5, ao, 1.0), rough * covm + (1 - covm) * 0.5, metal * covm], axis=2)
u8 = lambda a: (np.clip(a, 0, 1) * 255.0 + 0.5).astype(np.uint8)
Image.fromarray(u8(orm), "RGB").save(os.path.join(DST, "nezha_orm.png"))

mask = np.stack([silk * covm, skin * covm, covm], axis=2)
Image.fromarray(u8(mask), "RGB").save(os.path.join(DST, "nezha_mask.png"))

thick = Image.fromarray(u8(1.0 - ao), "L").filter(ImageFilter.GaussianBlur(6))
thick = np.clip(np.asarray(thick, dtype=np.float32) / 255.0 * 1.35, 0, 1) * covm
Image.fromarray(u8(thick), "L").save(os.path.join(DST, "nezha_thickness.png"))
Image.fromarray(u8(cur * covm), "L").save(os.path.join(DST, "nezha_curvature.png"))
Image.fromarray(u8(alb_srgb), "RGB").save(os.path.join(DST, "nezha_albedo.png"))
Image.fromarray(u8(nrm), "RGB").save(os.path.join(DST, "nezha_normal.png"))

n = nrm * 2.0 - 1.0
ins = covm > 0.5
print("normal inside mean", [round(float(v), 3) for v in n[ins].mean(0)],
      "avg tilt deg", round(float(np.degrees(np.arccos(np.clip(n[ins][:, 2], -1, 1))).mean()), 2))
print("ao inside mean", round(float(ao[ins].mean()), 3))

sheet = Image.new("RGB", (5 * 320, 320), (20, 20, 20))
for i, f in enumerate(["nezha_albedo.png", "nezha_normal.png", "nezha_orm.png", "nezha_mask.png", "nezha_curvature.png"]):
    im = Image.open(os.path.join(DST, f)).convert("RGB").resize((320, 320), Image.LANCZOS)
    sheet.paste(im, (i * 320, 0))
sheet.save(os.path.join(PREV, "maps.png"))
print("files:", sorted(os.listdir(DST)))
