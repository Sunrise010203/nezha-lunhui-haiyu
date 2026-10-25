"""Assemble reviewed poses and projected reference-bone checks."""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path("E:/godot_game_by_fable/_review/nezha_arp")
font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 24)
for view in ("front", "side"):
    im = Image.open(OUT / ("rest_" + view + ".png")).convert("RGB")
    draw = ImageDraw.Draw(im)
    for bone in json.loads((OUT / ("skeleton_" + view + ".json")).read_text()):
        a, b = [tuple(p) for p in bone["points"]]
        draw.line((a, b), fill=(70, 235, 210), width=3)
        for x, y in (a, b):
            draw.ellipse((x - 4, y - 4, x + 4, y + 4), fill=(255, 228, 90))
    im.save(OUT / ("joint_alignment_" + view + ".png"))

poses = [
    ("Rest / aligned joints", "joint_alignment_front.png"),
    ("Raised arms", "arms_up_three_quarter.png"),
    ("Overhead arms", "arms_overhead_three_quarter.png"),
    ("Elbow flexion 90 deg", "elbows_bent_front.png"),
    ("Left knee flexion 95 deg", "knee_left_three_quarter.png"),
    ("Right knee flexion 95 deg", "knee_right_three_quarter.png"),
    ("Torso twist 45 deg", "torso_twist_three_quarter.png"),
    ("Full-body turn 90 deg", "turn_front.png"),
]
sheet = Image.new("RGB", (1600, 964), (35, 38, 40))
draw = ImageDraw.Draw(sheet)
for i, (label, path) in enumerate(poses):
    x, y = (i % 4) * 400, (i // 4) * 482
    im = Image.open(OUT / path).convert("RGB").resize((400, 440), Image.Resampling.LANCZOS)
    sheet.paste(im, (x, y + 42))
    draw.text((x + 10, y + 10), label, fill=(235, 237, 239), font=font)
sheet.save(OUT / "pose_review.jpg", quality=94)
print(OUT / "pose_review.jpg")
