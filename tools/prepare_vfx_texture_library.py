"""Run skill's texture finishing, then build review previews and manifest."""
from pathlib import Path
import importlib.util
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art_source/vfx_textures'
OUT=ROOT/'001/art/vfx/textures'
PREVIEW=SOURCE/'previews'
PREVIEW.mkdir(parents=True,exist_ok=True)
skill=Path.home()/'.codex-cli/skills/apimart-vfx-image-gen/scripts/prepare_texture.py'
spec=importlib.util.spec_from_file_location('prepare_texture',skill)
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
names=['flame_tongue','flame_flow','water_splash','impact_flash','smoke','rune_mask']
labels=['01  FLAME TONGUE','02  FIRE FLOW / TILE X','03  WATER SPLASH',
        '04  IMPACT FLASH','05  SMOKE DENSITY','06  TIDE RUNE MASK']
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',24)
small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',17)
sheet=Image.new('RGB',(1800,1460),(17,23,32))
draw=ImageDraw.Draw(sheet)
draw.text((35,20),'NEZHA / VFX TEXTURE LIBRARY',font=font,fill=(235,218,171))
draw.text((35,55),'GPT-image-2 source plates | APIMart | RGBA + grayscale mask | dark and light background review',font=small,fill=(162,183,196))
records=[]
for idx,name in enumerate(names):
    result_path=SOURCE/'raw'/name/'result.json'
    if not result_path.exists():
        print('Pending: '+name)
        continue
    result=json.loads(result_path.read_text(encoding='utf-8'))
    metrics=module.prepare(result['files'][0],OUT/name,'glow' if name.startswith('flame') else 'mask',
                           name=='flame_flow',2048 if name=='flame_flow' else 1024,1024)
    # Keep QA records out of the engine asset folder.
    qa_path=OUT/f'{name}_qa.json'
    (SOURCE/f'{name}_qa.json').write_bytes(qa_path.read_bytes())
    qa_path.unlink()
    rgba=Image.open(OUT/f'{name}_rgba.png').convert('RGBA')
    x,y=(idx%3)*600,(idx//3)*680+100
    draw.text((x+25,y),labels[idx],font=font,fill=(236,230,211))
    for row,bg in enumerate([(10,15,23),(142,151,159)]):
        tile=Image.new('RGBA',(550,280),(*bg,255))
        shown=rgba.copy()
        shown.thumbnail((520,258),Image.Resampling.LANCZOS)
        tile.alpha_composite(shown,((550-shown.width)//2,(280-shown.height)//2))
        sheet.paste(tile.convert('RGB'),(x+25,y+40+row*290))
    draw.text((x+25,y+630),f'{rgba.width} x {rgba.height}  |  alpha 0..{metrics["alpha_max"]}',font=small,fill=(150,177,188))
    records.append(dict(name=name,task_id=result['task_id'],cost=result['cost'],
                        rgba='res://art/vfx/textures/'+name+'_rgba.png',mask='res://art/vfx/textures/'+name+'_mask.png',qa=metrics))
    if name=='flame_flow':
        tile=rgba.resize((768,384),Image.Resampling.LANCZOS)
        tiled=Image.new('RGBA',(2304,480),(10,15,23,255))
        for i in range(3):
            tiled.alpha_composite(tile,(i*768,50))
        td=ImageDraw.Draw(tiled)
        td.text((20,12),'3 x horizontal repeats / seams at x=768 and x=1536',font=font,fill='white')
        tiled.convert('RGB').save(PREVIEW/'flame_flow_tile_x.png')
sheet.save(PREVIEW/'texture_library_overview.png')
manifest=dict(model='gpt-image-2',provider='https://api.apimart.ai/v1',asset_count=len(records),
              total_reported_cost=sum(r['cost'] or 0 for r in records),assets=records)
(SOURCE/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'prepared':len(records),'total_reported_cost':manifest['total_reported_cost']}))
