"""Read-only probe: Blender version, add-on state, rigging-relevant setup."""
import addon_utils
import bpy

out = {}
out["blender"] = bpy.app.version_string
out["python"] = bpy.app.version
mods = [m.__name__ for m in addon_utils.modules()]
out["arp_mods"] = [m for m in mods if "auto_rig" in m.lower() or "rig_pro" in m.lower()]
out["enabled_arp"] = [
    n for n in (bpy.context.preferences.addons.keys() if hasattr(bpy.context.preferences.addons, "keys") else [])
    if "rig" in n.lower()
]
out["addons_enabled"] = sorted(bpy.context.preferences.addons.keys())
out["scripts_paths"] = [p for p in bpy.utils.script_paths()]
out["addon_dir"] = bpy.utils.user_resource("SCRIPTS", path="addons", create=False)
out["ext_dir"] = bpy.utils.user_resource("EXTENSIONS", create=False)
out["objects"] = [(o.name, o.type) for o in bpy.data.objects]
try:
    out["units"] = (bpy.context.scene.unit_settings.system, bpy.context.scene.unit_settings.scale_length)
except Exception as e:
    out["units_err"] = str(e)
print("PROBE_JSON=" + __import__("json").dumps(out, ensure_ascii=False))
