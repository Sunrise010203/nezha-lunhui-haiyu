"""Assemble captured game views, deformation tests and joint overlays for handoff."""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path('E:/godot_game_by_fable')
OUT = ROOT / '_review/bosses_arp'
FONT = 'C:/Windows/Fonts/msyh.ttc'
NAMES = {'01': '归墟之喉', '02': '棘狱守卫', '03': '封印之瞳',
         '04': '归墟海眼·巨瞳', '05': '潮心·螭吻', '06': '守卫重锤'}


def text(draw, xy, value, size=22, fill='#e1e8ec'):
    draw.text(xy, value, font=ImageFont.truetype(FONT, size), fill=fill)


def canvas(title, subtitle, columns, rows, width, height):
    im = Image.new('RGB', (columns * width + 32, rows * height + 135), '#151d25')
    draw = ImageDraw.Draw(im)
    text(draw, (24, 16), title, 32)
    text(draw, (24, 65), subtitle, 18, '#9eafbb')
    return im


items = [
    ('game_maw_rest.png', '01 归墟之喉 · 俯冲蓄力'),
    ('game_warden_rest.png', '02 + 06 棘狱守卫 · 右手持锤'),
    ('game_sea_eye_rest.png', '03 封印之瞳 · 三核阶段'),
    ('game_sea_eye_p2.png', '04 归墟海眼 · 巨瞳阶段'),
    ('game_chiwen_rest.png', '05 潮心·螭吻'),
    ('game_chiwen_core.png', '05 螭吻 · P3 潮心显形'),
]
im = canvas('Boss 模型部署预览', 'Godot 4.6.3 实际加载与渲染 / 2026-10-21', 2, 3, 640, 495)
for i, (filename, label) in enumerate(items):
    x, y = 16 + i % 2 * 640, 115 + i // 2 * 495
    im.paste(Image.open(OUT / filename).convert('RGB').resize((624, 439)), (x, y))
    text(ImageDraw.Draw(im), (x + 10, y + 448), label, 21)
im.save(OUT / 'boss_deployment_overview.jpg', quality=94)

im = canvas('基础变形检查', 'Blender ARP 源文件 / 非人形使用对应附肢与躯干测试；武器保持刚性', 4, 6, 280, 355)
for row, (code, name) in enumerate(NAMES.items()):
    for col, (clip, label) in enumerate([('Rest', '静止'), ('QA_Raise', '抬手 / 附肢'), ('QA_Bend', '弯腿 / 附肢'), ('QA_Turn', '转体')]):
        x, y = 16 + col * 280, 115 + row * 355
        im.paste(Image.open(OUT / f'{code}_{clip}_front.png').convert('RGB').resize((264, 297)), (x, y))
        text(ImageDraw.Draw(im), (x + 4, y + 303), f'{code} {name} · {label}', 14)
im.save(OUT / 'boss_deformation_checks.jpg', quality=94)

im = canvas('骨骼关节对齐复核', '正面与侧面参考骨架投影 / 青色线为参考关节，不是成品网格的一部分', 6, 2, 320, 420)
for col, (code, name) in enumerate(NAMES.items()):
    data = json.loads((OUT / (code + '_motion.json')).read_text())
    for row, view in enumerate(['front', 'side']):
        tile = Image.open(OUT / f'{code}_Rest_{view}.png').convert('RGB')
        draw = ImageDraw.Draw(tile)
        for bone in data['joint_screen'][view]:
            a, b = [tuple(p) for p in bone['points']]
            draw.line([a, b], fill='#36eadf', width=3)
            for x, y in (a, b):
                draw.ellipse((x - 3, y - 3, x + 3, y + 3), fill='#e6fff5')
        x, y = 16 + col * 320, 115 + row * 420
        im.paste(tile.resize((304, 342)), (x, y))
        text(ImageDraw.Draw(im), (x + 5, y + 350), f'{code} {name}', 17)
        text(ImageDraw.Draw(im), (x + 5, y + 378), '正面' if view == 'front' else '侧面', 16, '#9eafbb')
im.save(OUT / 'boss_joint_alignment.jpg', quality=94)

items = [('game_warden_raise.png', '蓄力抬锤'), ('game_warden_impact.png', '落锤姿态')]
im = canvas('守卫重锤动作复核', '刚性肩甲 + 手部武器骨 / 落锤与现有状态机伤害帧同步', 2, 1, 640, 500)
for i, (filename, label) in enumerate(items):
    x, y = 16 + i * 640, 115
    im.paste(Image.open(OUT / filename).convert('RGB').resize((624, 439)), (x, y))
    text(ImageDraw.Draw(im), (x + 10, y + 449), label, 22)
im.save(OUT / 'warden_slam_checks.jpg', quality=94)
print('BOSS_REVIEW_SHEETS_COMPLETE')
