"""Remove unused imported datablocks from the seven editable source files."""
from pathlib import Path
import bpy

root = Path('E:/godot_game_by_fable/art_source/enemies')
for path in sorted(root.glob('*_arp.blend')):
    bpy.ops.wm.open_mainfile(filepath=str(path))
    bpy.data.orphans_purge(do_recursive=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(path), compress=True)
    print('ENEMY_SOURCE_CLEAN', path.name, path.stat().st_size, flush=True)
