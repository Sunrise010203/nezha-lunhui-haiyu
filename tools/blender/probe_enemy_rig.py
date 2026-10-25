"""Probe the installed ARP empty rig and custom-bone binding interface."""
import json
import bpy

area = next(a for a in bpy.context.screen.areas if a.type == "VIEW_3D")
region = next(r for r in area.regions if r.type == "WINDOW")
with bpy.context.temp_override(area=area, region=region):
    bpy.ops.arp.append_arp(rig_preset="free")
    rig = bpy.context.active_object
    print("FREE_RIG", rig.name, dict(rig.items()))
    print("FREE_BONES", json.dumps({b.name: {"head": list(b.head_local), "tail": list(b.tail_local), "deform": b.use_deform, "props": str(dict(b.items()))} for b in rig.data.bones}))
    print("BIND_RNA", [(p.identifier, p.type) for p in bpy.ops.arp.bind_to_rig.get_rna_type().properties])
    bpy.ops.wm.save_as_mainfile(filepath="E:/godot_game_by_fable/_review/enemies_arp/arp_empty_template.blend", compress=True)
