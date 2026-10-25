"""Build compact contact sheets for the supplied enemy batch."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

OUT = Path("E:/godot_game_by_fable/_review/enemies_arp")
font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 20)
sheet = Image.new("RGB", (1600, 780), (35, 38, 40))
draw = ImageDraw.Draw(sheet)
for i in range(8):
    x, y = i % 4 * 400, i // 4 * 390
    code = f"{i + 1:03d}"
    for j, view in enumerate(("front", "side")):
        path = OUT / (code + "_" + view + ".png")
        if path.exists():
            im = Image.open(path).convert("RGB")
            im.thumbnail((200, 348))
            sheet.paste(im, (x + j * 200 + (200 - im.width) // 2, y + 36))
    draw.text((x + 12, y + 8), code + "    front / side", fill="white", font=font)
sheet.save(OUT / "source_review.jpg", quality=94)

labels = ['Rest', 'Move', 'Windup', 'Attack', 'QA_Raise', 'QA_Bend', 'QA_Turn']
for view in ('front', 'side'):
    sheet = Image.new('RGB', (350 * len(labels), 350 * 8), (35, 38, 40))
    draw = ImageDraw.Draw(sheet)
    for i in range(8):
        code = f'{i + 1:03d}'
        for j, label in enumerate(labels):
            path = OUT / f'{code}_{label}_{view}.png'
            if path.exists():
                im = Image.open(path).convert('RGB')
                im.thumbnail((345, 312))
                sheet.paste(im, (j * 350 + (350 - im.width) // 2, i * 350 + 32))
            draw.text((j * 350 + 10, i * 350 + 4), code + ' ' + label, fill='white', font=font)
    sheet.save(OUT / ('motion_review_' + view + '.jpg'), quality=94)

labels = ['Idle', 'Move', 'Windup', 'Attack']
sheet = Image.new('RGB', (480 * 4, 320 * 8), (20, 25, 28))
draw = ImageDraw.Draw(sheet)
for i in range(8):
    code = f'{i + 1:03d}'
    for j, label in enumerate(labels):
        path = OUT / f'godot_{code}_{label}.png'
        if path.exists():
            im = Image.open(path).convert('RGB')
            im.thumbnail((480, 290))
            sheet.paste(im, (j * 480 + (480 - im.width) // 2, i * 320 + 28))
        draw.text((j * 480 + 12, i * 320 + 4), code + ' ' + label, fill='white', font=font)
sheet.save(OUT / 'godot_motion_review.jpg', quality=94)

names = ['001 Crawler', '002 Shooter', '003 Divider', '004 Guard', '005 Turret', '006 Wraith', '007 Bomber', '008 Spawnling']
sheet = Image.new('RGB', (350 * 8, 390), (25, 30, 33))
draw = ImageDraw.Draw(sheet)
for i, name in enumerate(names):
    im = Image.open(OUT / f'godot_{i + 1:03d}_Idle.png').convert('RGB')
    im = im.crop((315, 140, 945, 770))
    im.thumbnail((350, 350))
    sheet.paste(im, (i * 350, 36))
    draw.text((i * 350 + 15, 8), name, fill='white', font=font)
sheet.save(OUT / 'game_lineup.jpg', quality=94)

sheet = Image.new('RGB', (320 * 8, 400), (35, 38, 40))
draw = ImageDraw.Draw(sheet)
for i in range(8):
    code = f'{i + 1:03d}'
    im = Image.open(OUT / f'{code}_Rest_front.png').convert('RGB')
    overlay = ImageDraw.Draw(im)
    data = json.loads((OUT / f'{code}_motion.json').read_text())
    for bone in data['reference_bones']['front']:
        a, b = bone['points']
        overlay.line((tuple(a), tuple(b)), fill=(90, 255, 180), width=3)
        for x, y in (a, b):
            overlay.ellipse((x - 3, y - 3, x + 3, y + 3), fill=(255, 225, 100))
    im.thumbnail((320, 360))
    sheet.paste(im, (i * 320, 36))
    draw.text((i * 320 + 12, 8), names[i], fill='white', font=font)
sheet.save(OUT / 'joint_alignment.jpg', quality=94)
