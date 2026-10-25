"""Make contact sheets of retarget diagnostics using bundled Pillow."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

OUT = Path("E:/godot_game_by_fable/_review/nezha_arp/animation")
files = sorted(OUT.glob("Motion_*_trial.png"))
sheet = Image.new("RGB", (1300, ((len(files) + 4) // 5) * 326), (30, 30, 30))
draw = ImageDraw.Draw(sheet)
font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 14)
for index, path in enumerate(files):
    x, y = (index % 5) * 260, (index // 5) * 326
    im = Image.open(path).convert("RGB")
    im.thumbnail((260, 292))
    sheet.paste(im, (x + (260 - im.width) // 2, y + 34))
    label = path.stem.removeprefix("Motion_").removesuffix("_trial").replace("_", " ")
    draw.text((x + 7, y + 9), label, fill="white", font=font)
sheet.save(OUT / "retarget_trials.jpg", quality=93)

clips = json.loads((OUT / "gameplay_clips.json").read_text())
sheet = Image.new("RGB", (1200, 4 * 366), (30, 30, 30))
draw = ImageDraw.Draw(sheet)
for index, (label, clip) in enumerate(clips.items()):
    choice = 3 if label == "Death" else 2 if label in ("Roll", "Jump", "UpwardThrust") else 1
    frame = clip["checked_frames"][choice]["frame"]
    path = "godot_" + label + ".png" if "source" in clip else label + "_" + str(frame) + ".png"
    im = Image.open(OUT / path).convert("RGB")
    im.thumbnail((300, 330))
    x, y = (index % 4) * 300, (index // 4) * 366
    sheet.paste(im, (x + (300 - im.width) // 2, y + 36))
    draw.text((x + 12, y + 11), label, fill="white", font=font)
sheet.save(OUT / "animation_review.jpg", quality=94)

sheet = Image.new("RGB", (1200, 400), (30, 35, 35))
draw = ImageDraw.Draw(sheet)
for index, label in enumerate(("Jump", "Fall", "Plunge")):
    im = Image.open(OUT / ("godot_" + label + ".png")).convert("RGB")
    im.thumbnail((400, 360))
    sheet.paste(im, (index * 400 + (400 - im.width) // 2, 40))
    draw.text((index * 400 + 15, 12), label, fill="white", font=font)
sheet.save(OUT / "airborne_review.jpg", quality=94)
