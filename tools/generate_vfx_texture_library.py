"""Invoke the installed APIMart VFX skill with at most two concurrent requests."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SKILL = Path.home()/'.codex-cli/skills/apimart-vfx-image-gen/scripts/generate.py'
NAMES = ['flame_tongue','flame_flow','water_splash','impact_flash','smoke','rune_mask']

def generate(name):
    out = ROOT/'art_source/vfx_textures/raw'/name
    cmd = [sys.executable,str(SKILL),'--out',str(out)]
    if (out/'task.json').exists():
        cmd += ['--resume']
    else:
        cmd += ['--prompt-file',str(ROOT/'art_source/vfx_textures/prompts'/f'{name}.txt'),
                '--size','2:1' if name=='flame_flow' else '1:1','--resolution','2k']
    print('START '+name,flush=True)
    result = subprocess.run(cmd)
    print(f'FINISH {name}: {result.returncode}',flush=True)
    return result.returncode

with ThreadPoolExecutor(max_workers=2) as pool:
    results = list(pool.map(generate,NAMES))
sys.exit(1 if any(results) else 0)
