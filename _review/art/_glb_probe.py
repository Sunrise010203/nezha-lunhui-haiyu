import json, struct, sys, os

def read_glb(path):
    with open(path, 'rb') as f:
        data = f.read()
    magic, ver, length = struct.unpack_from('<4sII', data, 0)
    off = 12
    js = None
    while off < length:
        clen, ctype = struct.unpack_from('<II', data, off)
        off += 8
        chunk = data[off:off+clen]
        off += clen
        if ctype == 0x4E4F534A:  # JSON
            js = json.loads(chunk.decode('utf-8'))
        if ctype == 0x004E4942:
            break
    return js, len(data)

for path in sys.argv[1:]:
    try:
        js, size = read_glb(path)
    except Exception as e:
        print(path, 'ERR', e); continue
    meshes = js.get('meshes', [])
    prims = sum(len(m.get('primitives', [])) for m in meshes)
    accs = js.get('accessors', [])
    tris = 0
    for m in meshes:
        for p in m.get('primitives', []):
            if 'indices' in p:
                tris += accs[p['indices']].get('count', 0) // 3
            elif 'mode' not in p or p.get('mode') == 4:
                pos = p.get('attributes', {}).get('POSITION')
                if pos is not None:
                    tris += accs[pos].get('count', 0) // 3
    attrs = set()
    for m in meshes:
        for p in m.get('primitives', []):
            attrs.update(p.get('attributes', {}).keys())
    print('=' * 70)
    print(os.path.basename(path))
    print(f'  file={size/1e6:.2f}MB  nodes={len(js.get("nodes", []))}  meshes={len(meshes)} prims={prims} tris={tris}')
    print(f'  skins={len(js.get("skins", []))}  animations={len(js.get("animations", []))}  materials={len(js.get("materials", []))}  images={len(js.get("images", []))}  textures={len(js.get("textures", []))}')
    print(f'  attrs={sorted(attrs)}')
    print(f'  extensionsUsed={js.get("extensionsUsed", [])}')
    mats = js.get('materials', [])
    for i, mt in enumerate(mats[:3]):
        pbr = mt.get('pbrMetallicRoughness', {})
        print(f'  mat[{i}] name={mt.get("name","")} baseColorTex={"baseColorTexture" in pbr} baseColorFactor={pbr.get("baseColorFactor")} doubleSided={mt.get("doubleSided")}')
