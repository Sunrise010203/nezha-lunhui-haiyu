"""Poly Haven helper for the BlenderMCP addon (no shell-quoting needed).

Commands
    python polyhaven.py status
    python polyhaven.py enable
    python polyhaven.py categories hdris
    python polyhaven.py search models --category props
    python polyhaven.py hdri brown_photostudio_02 --res 1k      # persistent local library
    python polyhaven.py download Lantern_01 models --res 1k     # imports into the scene
    python polyhaven.py library

Why `hdri` does not use the addon's downloader:
    the addon loads the .hdr from a NamedTemporaryFile and never packs/repersists it,
    so the world breaks after restart. It also has no reliable "save as HDR" path.
    Here we fetch the original file straight from api.polyhaven.com into
    tools/blender/library/hdri/ and relink the world to that file.
"""
import argparse
import json
import os
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_ctl import BlenderClient  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
LIB = os.path.join(HERE, "library")
API = "https://api.polyhaven.com"
UA = "blender-mcp (local tool)"


def jprint(obj):
    print(json.dumps(obj, ensure_ascii=False, indent=1))


def http_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))


def http_download(url, dest):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    tmp = dest + ".part"
    with urllib.request.urlopen(req, timeout=300) as r, open(tmp, "wb") as f:
        total = 0
        while True:
            chunk = r.read(262144)
            if not chunk:
                break
            f.write(chunk)
            total += len(chunk)
    os.replace(tmp, dest)
    return total


def require(c, cmd, params=None):
    out = c.send(cmd, params or {})
    if isinstance(out, dict) and out.get("status") == "error":
        print("ERROR:", out.get("message"), file=sys.stderr)
        sys.exit(1)
    return out


def apply_hdri_code(path, strength=1.0):
    p = path.replace("\\", "\\\\")
    return f'''
import bpy
path = r"{p}"
img = bpy.data.images.load(path, check_existing=True)
w = bpy.data.worlds.get("HDRILib") or bpy.data.worlds.new("HDRILib")
w.use_nodes = True
nt = w.node_tree
nt.nodes.clear()
tc = nt.nodes.new("ShaderNodeTexCoord")
mp = nt.nodes.new("ShaderNodeMapping")
et = nt.nodes.new("ShaderNodeTexEnvironment")
et.image = img
bg = nt.nodes.new("ShaderNodeBackground")
out = nt.nodes.new("ShaderNodeOutputWorld")
nt.links.new(tc.outputs["Generated"], mp.inputs["Vector"])
nt.links.new(mp.outputs["Vector"], et.inputs["Vector"])
nt.links.new(et.outputs["Color"], bg.inputs["Color"])
nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
bg.inputs["Strength"].default_value = {float(strength)}
bpy.context.scene.world = w
img.pack()
print("HDRI_APPLIED", img.name, tuple(img.size), "packed=", bool(img.packed_file))
'''


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=9876)
    sub = ap.add_subparsers(dest="cmd", required=True)

    sub.add_parser("status")
    sub.add_parser("enable")
    sub.add_parser("library")

    p_cat = sub.add_parser("categories")
    p_cat.add_argument("asset_type", choices=["hdris", "textures", "models", "all"])

    p_search = sub.add_parser("search")
    p_search.add_argument("asset_type", choices=["hdris", "textures", "models", "all"])
    p_search.add_argument("--category", default=None)

    p_dl = sub.add_parser("download")
    p_dl.add_argument("asset_id")
    p_dl.add_argument("asset_type", choices=["textures", "models"])
    p_dl.add_argument("--res", default="1k")
    p_dl.add_argument("--fmt", default=None)

    p_hdri = sub.add_parser("hdri")
    p_hdri.add_argument("asset_id")
    p_hdri.add_argument("--res", default="1k")
    p_hdri.add_argument("--fmt", default="hdr", choices=["hdr", "exr"])
    p_hdri.add_argument("--strength", type=float, default=1.0)

    args = ap.parse_args()

    # ----- commands that need no Blender connection
    if args.cmd == "library":
        root = os.path.join(LIB, "hdri")
        if not os.path.isdir(root):
            print("no library yet:", root)
            return
        for name in sorted(os.listdir(root)):
            p = os.path.join(root, name)
            print(f"{os.path.getsize(p):>10}  {name}")

    if args.cmd == "hdri":
        files = http_json(f"{API}/files/{args.asset_id}")
        try:
            info = files["hdri"][args.res][args.fmt]
        except KeyError:
            avail = {k: list(v.keys()) for k, v in files.get("hdri", {}).items()}
            print("ERROR: resolution/format not available:", avail, file=sys.stderr)
            sys.exit(1)
        dest_dir = os.path.join(LIB, "hdri")
        os.makedirs(dest_dir, exist_ok=True)
        dest = os.path.join(dest_dir, f"{args.asset_id}_{args.res}.{args.fmt}")
        print(f"Downloading {info['url']} -> {dest}")
        size = http_download(info["url"], dest)
        print(f"Saved {size/1048576:.2f} MB")
        with open(dest, "rb") as f:
            head = f.read(16).decode("latin-1", "replace").strip()
        print("HEADER:", head)
        c = BlenderClient(port=args.port).connect()
        try:
            out = require(c, "execute_code", {"code": apply_hdri_code(dest, args.strength)})
            jprint(out.get("result", out))
        finally:
            c.close()
        return

    c = BlenderClient(port=args.port).connect()
    try:
        if args.cmd == "enable":
            require(c, "execute_code", {"code": "import bpy; bpy.context.scene.blendermcp_use_polyhaven = True; print('polyhaven flag =', bpy.context.scene.blendermcp_use_polyhaven)"})
            jprint(require(c, "get_polyhaven_status"))

        elif args.cmd == "status":
            jprint(require(c, "get_polyhaven_status"))

        elif args.cmd == "categories":
            jprint(require(c, "get_polyhaven_categories", {"asset_type": args.asset_type}))

        elif args.cmd == "search":
            params = {"asset_type": args.asset_type}
            if args.category:
                params["categories"] = args.category
            out = require(c, "search_polyhaven_assets", params)
            res = out.get("result", out)
            rows = [
                {
                    "id": aid,
                    "name": meta.get("name", aid),
                    "categories": (meta.get("categories") or [])[:3],
                }
                for aid, meta in res.get("assets", {}).items()
            ]
            jprint({"total_count": res.get("total_count"), "returned": len(rows), "assets": rows})

        elif args.cmd == "download":
            params = {"asset_id": args.asset_id, "asset_type": args.asset_type, "resolution": args.res}
            if args.fmt:
                params["file_format"] = args.fmt
            out = require(c, "download_polyhaven_asset", params)
            jprint(out.get("result", out))
    finally:
        c.close()


if __name__ == "__main__":
    main()
